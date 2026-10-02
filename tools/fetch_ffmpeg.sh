#!/usr/bin/env bash
set -euo pipefail

# Downloads and extracts static ffmpeg/ffprobe (linux x86_64, glibc) for building
# the -ffmpeg TPK variant. Uses John Van Sickle's official static builds
# (https://johnvansickle.com/ffmpeg/) - they work on TOS6/TOS7.
# Only the two binaries ffmpeg and ffprobe are kept in tools/ffmpeg/
# (this folder is in .gitignore). Binaries are GPLv3 (see NOTICE).
#
# Env overrides:
#   FFMPEG_URL     - URL of the static build archive
#   FFMPEG_OUT_DIR - where to put ffmpeg/ffprobe (default: tools/ffmpeg/)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

URL="${FFMPEG_URL:-https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz}"
OUT_DIR="${FFMPEG_OUT_DIR:-$SCRIPT_DIR/ffmpeg}"

mkdir -p "$OUT_DIR"

ARCHIVE="$OUT_DIR/ffmpeg-release-amd64-static.tar.xz"
EXTRACT="$OUT_DIR/_extract"

if command -v curl >/dev/null 2>&1; then
    echo "Downloading ffmpeg static build (linux x86_64, glibc) via curl ..."
    curl -fL --retry 3 -o "$ARCHIVE" "$URL"
elif command -v wget >/dev/null 2>&1; then
    echo "Downloading ffmpeg static build (linux x86_64, glibc) via wget ..."
    wget -q --show-progress -O "$ARCHIVE" "$URL"
else
    echo "Error: neither curl nor wget found - install one of them" >&2
    exit 1
fi

echo "Extracting..."
rm -rf "$EXTRACT"
mkdir -p "$EXTRACT"
tar -xf "$ARCHIVE" -C "$EXTRACT"

SRC_DIR="$(find "$EXTRACT" -type f -name ffmpeg -exec dirname {} \; | head -n 1)"
if [ -z "$SRC_DIR" ]; then
    echo "Error: ffmpeg binary not found in archive" >&2
    exit 1
fi

for name in ffmpeg ffprobe; do
    if [ ! -f "$SRC_DIR/$name" ]; then
        echo "Error: $name not found in static build ($SRC_DIR)" >&2
        exit 1
    fi
    cp -f "$SRC_DIR/$name" "$OUT_DIR/$name"
    echo "  $name -> $OUT_DIR/$name ($(wc -c < "$SRC_DIR/$name") bytes)"
done

rm -rf "$EXTRACT"
rm -f "$ARCHIVE"

echo "Done. ffmpeg/ffprobe ready in $OUT_DIR"