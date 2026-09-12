#!/usr/bin/env bash
set -euo pipefail

# Build TPK package for TerraMaster TOS6/TOS7 on Linux / macOS
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="${1:-$SCRIPT_DIR/../FileBrowserQuantumTOS}"
OUT_DIR="${2:-$SCRIPT_DIR/..}"
RELEASE_TAG="${3:-beta}"

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
    else
        python3 -c "import hashlib, sys; print(hashlib.md5(open(sys.argv[1],'rb').read()).hexdigest())" "$1"
    fi
}

# ---- Locate Go >= 1.27.0 -----------------------------------------------------
# Приоритет: go из PATH → $GO_127_ROOT/bin/go → /usr/local/go/bin/go
# Переопределить путь можно переменной окружения GO_127_ROOT.
GO_127_ROOT="${GO_127_ROOT:-}"

find_go() {
    # 1) go из PATH — но проверим версию
    if command -v go >/dev/null 2>&1; then
        local v
        v="$(go version 2>/dev/null || true)"
        if [[ "$v" =~ go1\.(2[7-9]|[3-9][0-9]) ]]; then
            echo "$(command -v go)"
            return 0
        fi
    fi
    # 2) явный GO_127_ROOT
    if [ -n "$GO_127_ROOT" ] && [ -x "$GO_127_ROOT/bin/go" ]; then
        echo "$GO_127_ROOT/bin/go"
        return 0
    fi
    # 3) стандартные места для Linux/macOS
    for c in /usr/local/go/bin/go /opt/go/bin/go "$HOME/go/bin/go"; do
        if [ -x "$c" ]; then
            local v
            v="$("$c" version 2>/dev/null || true)"
            if [[ "$v" =~ go1\.(2[7-9]|[3-9][0-9]) ]]; then
                echo "$c"
                return 0
            fi
        fi
    done
    return 1
}

GO_BIN="$(find_go || true)"
if [ -z "$GO_BIN" ]; then
    echo "Error: Go >= 1.27.0 not found. Install it or set GO_127_ROOT." >&2
    exit 1
fi
echo "Using go: $GO_BIN"

# Убедимся, что tarmake соберётся именно этим Go, а не случайным toolchain.
# GOTOOLCHAIN=local запрещает go автоматически скачивать другой toolchain.
export GOTOOLCHAIN=local
export GOROOT="$(cd "$(dirname "$GO_BIN")/.." && pwd)"

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

# tarmake собирается и запускается выбранным Go.
"$GO_BIN" run ./tarmake "$PKG_DIR" "$TAR_PATH"

echo "==> Compressing with xz -9e..."
xz -9e -c "$TAR_PATH" > "$XZ_PATH"
rm -f "$TAR_PATH"

PAYLOAD_MD5="$(get_md5 "$XZ_PATH")"
echo "payload.tar.xz: $(wc -c < "$XZ_PATH") bytes (md5: $PAYLOAD_MD5)"

echo "==> Assembling .tpk..."
CONFIG_FILE="$PKG_DIR/config.ini"
VERSION="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
ID="$(grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
PLATFORM="$(grep -o '"platform"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"

HEADER_JSON=$(python3 -c '
import json, sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    cfg = json.load(f)

cfg["md5"] = sys.argv[2]
print(json.dumps(cfg, separators=(",", ":"), ensure_ascii=False))
' "$CONFIG_FILE" "$PAYLOAD_MD5" 2>/dev/null || cat <<EOF
{"id":"$ID","md5":"$PAYLOAD_MD5","icon":"/images/icons/FileBrowserQuantum.png","path":"/FileBrowserQuantum/","name":"FileBrowser Quantum","publisher":"OutkastM","exec":true,"open_path":false,"resize":true,"maxmin":true,"state":false,"type":"iframe","help":"/FileBrowserQuantum/","version":"$VERSION","recommend":false,"beta":false,"category":"Utilities","depend":[],"relation":null,"platform":"$PLATFORM","low_version":"6.0.420","reset":true,"official":"/FileBrowserQuantum/"}
EOF
)

if [ "${#HEADER_JSON}" -gt 2048 ]; then
    echo "Error: JSON header too large: ${#HEADER_JSON} > 2048" >&2
    exit 1
fi

LANG_FILE="$PKG_DIR/FileBrowserQuantum.lang"
LANG_SIZE=$(wc -c < "$LANG_FILE")
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

# Assemble binary
python3 -c '
import sys

header_str = sys.argv[1].encode("utf-8")
lang_path = sys.argv[2]
payload_path = sys.argv[3]
out_path = sys.argv[4]

with open(lang_path, "rb") as f:
    lang_bytes = f.read()
with open(payload_path, "rb") as f:
    payload_bytes = f.read()

with open(out_path, "wb") as f:
    f.write(header_str)
    f.write(b"\x00" * (2048 - len(header_str)))
    f.write(lang_bytes)
    f.write(b"\x00" * (8192 - len(lang_bytes)))
    f.write(payload_bytes)
' "$HEADER_JSON" "$LANG_FILE" "$XZ_PATH" "$TPK_OUT"

echo "==> Successfully created: $TPK_OUT ($(wc -c < "$TPK_OUT") bytes)"