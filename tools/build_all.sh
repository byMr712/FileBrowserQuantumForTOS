#!/usr/bin/env bash
set -euo pipefail

# Builds BOTH TPK variants in one call: base and ffmpeg.
#   base:   ...-<BASE_RELEASE_TAG>-<platform>.tpk
#   ffmpeg: ...-<FFMPEG_RELEASE_TAG>-<platform>.tpk
# If tools/ffmpeg/ has no static ffmpeg/ffprobe, they are downloaded once
# automatically via tools/fetch_ffmpeg.sh (John Van Sickle static builds,
# linux x86_64, GPLv3). No manual steps besides Go and xz.
#
# The version in filenames and the .tpk header comes from config.ini.
# Each build uses its own staging copy - the FileBrowserQuantumTOS/ tree is
# never modified.
#
# Env overrides:
#   PKG_DIR              package tree (default: ../FileBrowserQuantumTOS)
#   OUT_DIR              output dir (default: repo root)
#   BASE_RELEASE_TAG     default: beta
#   FFMPEG_RELEASE_TAG   default: beta-ffmpeg
#   FFMPEG_DIR           use own ffmpeg/ffprobe dir (no auto-download)
#   SKIP_FFMPEG_FETCH=1  do not auto-download; require existing binaries
#   KEEP_GOING=1         continue with the ffmpeg variant even if base failed
#
# Example:
#   bash tools/build_all.sh
#   # -> FileBrowserQuantum_TOS7_TOS6_2.1.0.0-beta-x86_64.tpk
#   # -> FileBrowserQuantum_TOS7_TOS6_2.1.0.0-beta-ffmpeg-x86_64.tpk

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PKG_DIR="${PKG_DIR:-$SCRIPT_DIR/../FileBrowserQuantumTOS}"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/..}"
BASE_RELEASE_TAG="${BASE_RELEASE_TAG:-beta}"
FFMPEG_RELEASE_TAG="${FFMPEG_RELEASE_TAG:-beta-ffmpeg}"
FFMPEG_DIR="${FFMPEG_DIR:-}"
SKIP_FFMPEG_FETCH="${SKIP_FFMPEG_FETCH:-0}"
KEEP_GOING="${KEEP_GOING:-0}"

BUILD_TPK="$SCRIPT_DIR/build_tpk.sh"
FETCH_FFMPEG="$SCRIPT_DIR/fetch_ffmpeg.sh"

if [ ! -d "$PKG_DIR" ]; then
    echo "Error: Package directory not found: $PKG_DIR" >&2
    exit 1
fi

CONFIG_FILE="$PKG_DIR/config.ini"
ID="$(grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
VERSION="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
PLATFORM="$(grep -o '"platform"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)"
if [ -z "$ID" ] || [ -z "$VERSION" ] || [ -z "$PLATFORM" ]; then
    echo "Error: config.ini must contain id/version/platform (id=$ID version=$VERSION platform=$PLATFORM)" >&2
    exit 1
fi

# ---- 1. Ensure static ffmpeg/ffprobe -------------------------------------------
FF_TOP_DIR="${FFMPEG_DIR:-$SCRIPT_DIR/ffmpeg}"
FF_BIN="$FF_TOP_DIR/ffmpeg"
FP_BIN="$FF_TOP_DIR/ffprobe"

if [ ! -f "$FF_BIN" ] || [ ! -f "$FP_BIN" ]; then
    if [ "$SKIP_FFMPEG_FETCH" = "1" ] || [ -n "$FFMPEG_DIR" ]; then
        echo "Error: ffmpeg/ffprobe not found in $FF_TOP_DIR. Run tools/fetch_ffmpeg.sh first (or pass FFMPEG_DIR=<dir>)." >&2
        exit 1
    fi
    echo "==> ffmpeg/ffprobe not found in tools/ffmpeg/ - downloading static builds (one time, ~160 MB) ..."
    bash "$FETCH_FFMPEG"
    if [ ! -f "$FF_BIN" ] || [ ! -f "$FP_BIN" ]; then
        echo "Error: fetch_ffmpeg.sh finished but ffmpeg/ffprobe are still missing in $FF_TOP_DIR. Check network access and retry." >&2
        exit 1
    fi
fi
echo "Using ffmpeg binaries from: $FF_TOP_DIR"

# ---- 2. Build both variants ------------------------------------------------------
build_variant() {
    local name="$1" tag="$2" ffmpeg_dir="$3"
    echo ""
    echo "===== Building $name ====="
    if [ -n "$ffmpeg_dir" ]; then
        bash "$BUILD_TPK" "$PKG_DIR" "$OUT_DIR" "$tag" "$ffmpeg_dir"
    else
        bash "$BUILD_TPK" "$PKG_DIR" "$OUT_DIR" "$tag"
    fi
}

set +e
build_variant "base (no ffmpeg)" "$BASE_RELEASE_TAG" ""
BASE_OK=$?
set -e
if [ "$BASE_OK" -ne 0 ] && [ "$KEEP_GOING" != "1" ]; then
    echo "Base build failed. Aborting (use KEEP_GOING=1 to also try the ffmpeg variant)." >&2
    exit 1
fi

set +e
build_variant "ffmpeg variant" "$FFMPEG_RELEASE_TAG" "$FF_TOP_DIR"
FF_OK=$?
set -e

# ---- 3. Summary ---------------------------------------------------------------------
out_root="$(cd "$OUT_DIR" && pwd)"
tpk_base="$out_root/${ID}_TOS7_TOS6_${VERSION}-${BASE_RELEASE_TAG}-${PLATFORM}.tpk"
tpk_ff="$out_root/${ID}_TOS7_TOS6_${VERSION}-${FFMPEG_RELEASE_TAG}-${PLATFORM}.tpk"

echo ""
echo "===== Build summary (version from config.ini: $VERSION) ====="
for i in 0 1; do
    if [ "$i" -eq 0 ]; then
        label="base"
        path="$tpk_base"
        ok="$BASE_OK"
    else
        label="ffmpeg"
        path="$tpk_ff"
        ok="$FF_OK"
    fi
    if [ "$ok" = "0" ] && [ -f "$path" ]; then
        echo "  [OK]    $label : $path ($(wc -c < "$path") bytes)"
    else
        echo "  [FAIL]  $label : $path"
    fi
done

if [ "$BASE_OK" -ne 0 ] || [ "$FF_OK" -ne 0 ]; then
    exit 1
fi