#!/usr/bin/env bash
set -euo pipefail

# Build TPK package for TerraMaster TOS6/TOS7 on Linux / macOS
#
# Usage: build_tpk.sh [PKG_DIR] [OUT_DIR] [RELEASE_TAG] [FFMPEG_DIR]
#   PKG_DIR     package tree (default: ../FileBrowserQuantumTOS, relative to tools/)
#   OUT_DIR     where to put the .tpk (default: repo root)
#   RELEASE_TAG version suffix in the filename (default: beta; '' = none)
#   FFMPEG_DIR  dir with static ffmpeg/ffprobe (linux x86_64). When set, the
#               ffmpeg variant is staged: bin/ffmpeg/{ffmpeg,ffprobe} (mode 0744)
#               are added, integrations.media.ffmpegPath written into
#               bin/filebrowser.yml and FILEBROWSER_FFMPEG_PATH + auto-restart
#               injected into init.d/service. The original tree is never modified.
#               Pass e.g. RELEASE_TAG 'beta-ffmpeg' together with it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="${1:-$SCRIPT_DIR/../FileBrowserQuantumTOS}"
OUT_DIR="${2:-$SCRIPT_DIR/..}"
RELEASE_TAG="${3:-beta}"
FFMPEG_DIR="${4:-${FFMPEG_DIR:-}}"

cd "$SCRIPT_DIR"

if [ ! -d "$PKG_DIR" ]; then
    echo "Error: Package directory not found: $PKG_DIR" >&2
    exit 1
fi

BUILD_DIR="$SCRIPT_DIR/_build"
mkdir -p "$BUILD_DIR"

trap 'rm -rf "$BUILD_DIR"' EXIT

get_md5() {
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$1" | awk '{print $1}'
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q "$1"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import hashlib, sys; print(hashlib.md5(open(sys.argv[1],'rb').read()).hexdigest())" "$1"
    elif command -v python >/dev/null 2>&1; then
        python -c "import hashlib, sys; print(hashlib.md5(open(sys.argv[1],'rb').read()).hexdigest())" "$1"
    else
        echo "Error: no md5 tool found (install coreutils or python)" >&2
        exit 1
    fi
}

# ---- Optional ffmpeg staging ----------------------------------------------------
# Copy the tree, add bin/ffmpeg/{ffmpeg,ffprobe} and patch filebrowser.yml and
# init.d/service. PkgDir (and the repo tree) stay untouched.
if [ -n "$FFMPEG_DIR" ]; then
    FFMPEG_DIR="$(cd "$FFMPEG_DIR" && pwd)"
    FF_BIN="$FFMPEG_DIR/ffmpeg"
    FP_BIN="$FFMPEG_DIR/ffprobe"
    if [ ! -f "$FF_BIN" ]; then
        echo "Error: ffmpeg binary not found in FFMPEG_DIR: $FF_BIN" >&2
        exit 1
    fi
    if [ ! -f "$FP_BIN" ]; then
        echo "Error: ffprobe binary not found in FFMPEG_DIR: $FP_BIN" >&2
        exit 1
    fi

    STAGING="$BUILD_DIR/pkg-ffmpeg"
    mkdir -p "$STAGING"
    cp -a "$PKG_DIR"/. "$STAGING"/

    FF_PROG_DIR="$STAGING/bin/ffmpeg"
    mkdir -p "$FF_PROG_DIR"
    cp -f "$FF_BIN" "$FF_PROG_DIR/ffmpeg"
    cp -f "$FP_BIN" "$FF_PROG_DIR/ffprobe"
    chmod 0744 "$FF_PROG_DIR/ffmpeg" "$FF_PROG_DIR/ffprobe"

    # integrations.media.ffmpegPath in staging config (path on the NAS after install)
    YAML="$STAGING/bin/filebrowser.yml"
    if grep -q '^integrations:' "$YAML"; then
        echo "WARN: staging filebrowser.yml already has 'integrations:' - ffmpegPath not added automatically"
    else
        # Trim trailing blank/whitespace-only lines (same as PowerShell TrimEnd) so
        # the result is byte-identical to the build_tpk.ps1 output.
        awk '
            { lines[NR] = $0 }
            END {
                n = NR
                while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
                for (i = 1; i <= n; i++) print lines[i]
                printf "\nintegrations:\n  media:\n    ffmpegPath: /usr/local/FileBrowserQuantum/bin/ffmpeg\n"
            }
        ' "$YAML" > "$YAML.tmp"
        mv "$YAML.tmp" "$YAML"
    fi

    # FILEBROWSER_FFMPEG_PATH env + auto-restart in init.d/service: env is read at
    # daemon start before ffmpeg init and works even on upgrade over an old config
    # (which the package does not overwrite). Auto-restart makes install/upgrade
    # apply the new ffmpeg without a manual "service reload".
    SVC="$STAGING/init.d/service"
    if grep -q 'FILEBROWSER_FFMPEG_PATH' "$SVC"; then
        echo "WARN: staging init.d/service already contains FILEBROWSER_FFMPEG_PATH"
    else
        awk '$0 == "MOD_NAME=FileBrowserQuantum" {
                 print;
                 print "export FILEBROWSER_FFMPEG_PATH=/usr/local/${MOD_NAME}/bin/ffmpeg";
                 next
             }
             { print }' "$SVC" > "$SVC.tmp"
        mv "$SVC.tmp" "$SVC"
    fi
    if ! grep -q 'restarting to apply installed package' "$SVC"; then
        LINE="$(grep -n 'check_already_running' "$SVC" | tail -n 1 | cut -d: -f1 || true)"
        if [ -n "$LINE" ]; then
            INDENT="$(sed -n "${LINE}p" "$SVC" | sed -n 's/^\([[:space:]]*\).*/\1/p')"
            TAB="$(printf '\t')"
            BLOCK="${INDENT}# Existing daemon (e.g. from a previous install) is restarted here so the
${INDENT}# newly installed ffmpeg binaries and FILEBROWSER_FFMPEG_PATH take effect
${INDENT}# automatically right after install - no manual \"service reload\" needed.
${INDENT}_findPID
${INDENT}if [[ -n \"\$PID\" ]]; then
${INDENT}${TAB}echo \"\$(date +\"%d/%m/%y %T\") Existing daemon detected, restarting to apply installed package\" >> \"\$LOGFILE\" 2>&1
${INDENT}${TAB}stop
${INDENT}fi
"
            awk -v n="$LINE" -v block="$BLOCK" 'NR == n { printf "%s", block } { print }' "$SVC" > "$SVC.tmp"
            mv "$SVC.tmp" "$SVC"
        else
            echo "WARN: init.d/service has no 'check_already_running' - auto-restart not added"
        fi
    fi

    echo "FFmpeg staging: $STAGING (bin/ffmpeg/{ffmpeg,ffprobe} added, filebrowser.yml and init.d/service patched)"
    PKG_DIR="$STAGING"
fi

# ---- Locate Go >= 1.27.0 -----------------------------------------------------
# Collect candidate Go installations (PATH first, then GO_127_ROOT, then common
# locations). tarmake is built with the first candidate that actually compiles -
# a broken stdlib install is skipped automatically.
GO_127_ROOT="${GO_127_ROOT:-}"

GO_CANDIDATES=()
if command -v go >/dev/null 2>&1; then
    GO_CANDIDATES+=("$(command -v go)")
fi
if [ -n "$GO_127_ROOT" ] && [ -x "$GO_127_ROOT/bin/go" ]; then
    GO_CANDIDATES+=("$GO_127_ROOT/bin/go")
fi
for c in /usr/local/go/bin/go /opt/go/bin/go "$HOME/go/bin/go"; do
    [ -x "$c" ] && GO_CANDIDATES+=("$c")
done

echo "==> Regenerating INFO..."
INFO_FILE="$PKG_DIR/INFO"
> "$INFO_FILE"

find "$PKG_DIR" -mindepth 1 | sort | while read -r item; do
    rel="${item#$PKG_DIR/}"
    base="$(basename "$item")"
    if [ "$rel" = "INFO" ] || [ "$rel" = "config.ini" ] || [[ "$base" == .* ]]; then
        continue
    fi
    if [ -d "$item" ]; then
        echo "1:folder:${rel}:" >> "$INFO_FILE"
    else
        fmd5="$(get_md5 "$item")"
        echo "1:file:${rel}:${fmd5}" >> "$INFO_FILE"
    fi
done

echo "INFO regenerated: $(wc -c < "$INFO_FILE") bytes"

echo "==> Building payload.tar with tarmake..."
TAR_PATH="$BUILD_DIR/payload.tar"
XZ_PATH="$BUILD_DIR/payload.tar.xz"

# Try every Go >= 1.27.0 candidate until `go run ./tarmake` succeeds.
# GOTOOLCHAIN=local forbids go from auto-downloading another toolchain.
build_tarmake() {
    local go_bin="$1"
    local goroot
    goroot="$(cd "$(dirname "$go_bin")/.." && pwd)"
    echo "Trying tarmake with: $go_bin (GOROOT=$goroot)"
    GOROOT="$goroot" GOTOOLCHAIN=local "$go_bin" run ./tarmake "$PKG_DIR" "$TAR_PATH"
}

GO_BIN=""
TAR_OK=0
for c in "${GO_CANDIDATES[@]}"; do
    v="$("$c" version 2>/dev/null || true)"
    if [[ ! "$v" =~ go1\.(2[7-9]|[3-9][0-9]) ]]; then
        continue
    fi
    rm -f "$TAR_PATH"
    if build_tarmake "$c"; then
        TAR_OK=1
        GO_BIN="$c"
        break
    fi
    echo "  (tarmake failed with $c - skipping it and trying the next Go candidate)"
done

if [ "$TAR_OK" -ne 1 ] || [ ! -f "$TAR_PATH" ]; then
    echo "Error: tarmake could not be built with any Go >= 1.27.0 found. Install Go or set GO_127_ROOT." >&2
    exit 1
fi
echo "tarmake built with: $GO_BIN"

echo "==> Compressing with xz -9e..."
XZ_BIN="$(command -v xz || true)"
if [ -z "$XZ_BIN" ]; then
    echo "Error: xz not found in PATH. Install it (apt install xz-utils / brew install xz)" >&2
    exit 1
fi
echo "Using xz: $XZ_BIN"
"$XZ_BIN" -9e -c "$TAR_PATH" > "$XZ_PATH"
rm -f "$TAR_PATH"

PAYLOAD_MD5="$(get_md5 "$XZ_PATH")"
echo "payload.tar.xz: $(wc -c < "$XZ_PATH") bytes (md5: $PAYLOAD_MD5)"

echo "==> Assembling .tpk..."
CONFIG_FILE="$PKG_DIR/config.ini"
VERSION="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
ID="$(grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
PLATFORM="$(grep -o '"platform"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"

# Header JSON via python (if any), otherwise the known-fields fallback below.
PY="$(command -v python3 || command -v python || true)"
HEADER_JSON=""
if [ -n "$PY" ]; then
    HEADER_JSON="$("$PY" -c '
import json, sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    cfg = json.load(f)

cfg["md5"] = sys.argv[2]
print(json.dumps(cfg, separators=(",", ":"), ensure_ascii=False))
' "$CONFIG_FILE" "$PAYLOAD_MD5" 2>/dev/null || true)"
fi
if [ -z "$HEADER_JSON" ]; then
    if [ -z "$ID" ] || [ -z "$PLATFORM" ] || [ -z "$VERSION" ]; then
        echo "Error: cannot parse id/version/platform from config.ini (and python3 is unavailable)" >&2
        exit 1
    fi
    HEADER_JSON="{\"id\":\"$ID\",\"md5\":\"$PAYLOAD_MD5\",\"icon\":\"/images/icons/FileBrowserQuantum.png\",\"path\":\"/FileBrowserQuantum/\",\"name\":\"FileBrowser Quantum\",\"publisher\":\"OutkastM\",\"exec\":true,\"open_path\":false,\"resize\":true,\"maxmin\":true,\"state\":false,\"type\":\"iframe\",\"help\":\"/FileBrowserQuantum/\",\"version\":\"$VERSION\",\"recommend\":false,\"beta\":false,\"category\":\"Utilities\",\"depend\":[],\"relation\":null,\"platform\":\"$PLATFORM\",\"low_version\":\"6.0.420\",\"reset\":true,\"official\":\"/FileBrowserQuantum/\"}"
fi

HEADER_FILE="$BUILD_DIR/header.json"
printf '%s' "$HEADER_JSON" > "$HEADER_FILE"
HEADER_BYTES="$(wc -c < "$HEADER_FILE")"
if [ "$HEADER_BYTES" -gt 2048 ]; then
    echo "Error: JSON header too large: $HEADER_BYTES > 2048" >&2
    exit 1
fi

LANG_FILE="$PKG_DIR/FileBrowserQuantum.lang"
LANG_SIZE="$(wc -c < "$LANG_FILE")"
if [ "$LANG_SIZE" -gt 8192 ]; then
    echo "Error: .lang file too large: $LANG_SIZE > 8192" >&2
    exit 1
fi

if [ -n "$RELEASE_TAG" ]; then
    VER_PART="${VERSION}-${RELEASE_TAG}"
else
    VER_PART="${VERSION}"
fi

TPK_OUT="$OUT_DIR/${ID}_TOS7_TOS6_${VER_PART}-${PLATFORM}.tpk"

# Assemble binary: header + zero-pad to 2048, lang + zero-pad to 8192, payload.
rm -f "$TPK_OUT"
{
    cat "$HEADER_FILE"
    head -c "$((2048 - HEADER_BYTES))" /dev/zero
    cat "$LANG_FILE"
    head -c "$((8192 - LANG_SIZE))" /dev/zero
    cat "$XZ_PATH"
} > "$TPK_OUT"

echo "==> Successfully created: $TPK_OUT ($(wc -c < "$TPK_OUT") bytes)"