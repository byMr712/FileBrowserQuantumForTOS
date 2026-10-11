#!/usr/bin/env bash
set -euo pipefail

# Builds the FileBrowser Quantum application from the upstream sources
# (frontend + backend) and puts the resulting linux/amd64 binary into the
# package tree, ready for tools/build_all.sh.
#
#   1) Applies upstream source fixes (idempotent). The main one is i18n:
#        import.meta.glob('./!(en).json')  ->  import.meta.glob('./*.json')
#      Since v2.1.1 the frontend is built with Vite 8 (rolldown), which does not
#      support the extglob "!(...)". The pattern silently becomes an empty map,
#      the locale chunks never reach the binary and the UI is ALWAYS English.
#   2) Builds the frontend (Vue 3 + Vite) into backend/internal/web/embed.
#   3) Builds the backend (Go, linux/amd64, CGO off) and copies the binary to
#      FileBrowserQuantumTOS/bin/program/filebrowserquantum.
#   4) Verifies the result: locale chunks in the frontend build, and the version
#      string inside the binary.
#
# The version is never hardcoded - it comes from FileBrowserQuantumTOS/version,
# the app version is "<version>-<VERSION_SUFFIX>" (default "beta").
# Then package everything: bash tools/build_all.sh
#
# Env overrides:
#   SOURCES_DIR      sources dir        (default: ../sources)
#   PKG_DIR          package tree       (default: ../FileBrowserQuantumTOS)
#   VERSION_SUFFIX   app version suffix (default: beta; empty = no suffix)
#   GO_ROOT          Go root, e.g. /usr/local/go (default: go from PATH)
#   GO_TOOLCHAIN     GOTOOLCHAIN value  (default: untouched)
#   NPM              npm command        (default: npm)
#   FORCE_INSTALL=1  always run npm install
#   SKIP_FRONTEND=1  do not rebuild the frontend
#   SKIP_BACKEND=1   do not rebuild the backend
#   PATCH_ONLY=1     only apply the source fixes and exit
#
# Example:
#   bash tools/build_app.sh
#   bash tools/build_all.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SOURCES_DIR="${SOURCES_DIR:-$SCRIPT_DIR/../sources}"
PKG_DIR="${PKG_DIR:-$SCRIPT_DIR/../FileBrowserQuantumTOS}"
VERSION_SUFFIX="${VERSION_SUFFIX-beta}"
GO_ROOT="${GO_ROOT:-}"
GO_TOOLCHAIN="${GO_TOOLCHAIN:-}"
NPM="${NPM:-npm}"
FORCE_INSTALL="${FORCE_INSTALL:-0}"
SKIP_FRONTEND="${SKIP_FRONTEND:-0}"
SKIP_BACKEND="${SKIP_BACKEND:-0}"
PATCH_ONLY="${PATCH_ONLY:-0}"

MIN_LOCALE_CHUNKS=20
LOCALE_RE='^(virtual_intlify-i18n-[0-9]+|ar|bg|cz|de|el|es|fr|he|hu|it|ja|ko|nl|nl-be|pl|pt|pt-br|ro|ru|sk|sv-se|tr|ua|zh-cn|zh-tw)-.*\.js(\.gz)?$'

head_line() { echo; echo "==> $1"; }
ok_line() { echo "    $1"; }

[ -d "$SOURCES_DIR" ] || { echo "Error: sources dir not found: $SOURCES_DIR" >&2; exit 1; }
[ -d "$PKG_DIR" ] || { echo "Error: package tree not found: $PKG_DIR" >&2; exit 1; }
SOURCES_DIR="$(cd "$SOURCES_DIR" && pwd)"
PKG_DIR="$(cd "$PKG_DIR" && pwd)"

FRONTEND_DIR="$SOURCES_DIR/frontend"
BACKEND_DIR="$SOURCES_DIR/backend"
EMBED_DIR="$BACKEND_DIR/internal/web/embed"
DIST_DIR="$BACKEND_DIR/internal/web/dist"
I18N_FILE="$FRONTEND_DIR/src/i18n/index.ts"
VERSION_FILE="$PKG_DIR/version"
BINARY_OUT="$PKG_DIR/bin/program/filebrowserquantum"

# --- 1) upstream source fixes ------------------------------------------------------
head_line "Applying upstream source fixes"

[ -f "$I18N_FILE" ] || { echo "Error: i18n source not found: $I18N_FILE" >&2; exit 1; }

if grep -qF "'./*.json'" "$I18N_FILE"; then
    ok_line "i18n already fixed ('./*.json')"
elif grep -qF "'./!(en).json'" "$I18N_FILE"; then
    sed "s|'\./!(en)\.json'|'./*.json'|" "$I18N_FILE" > "$I18N_FILE.tmp"
    mv "$I18N_FILE.tmp" "$I18N_FILE"
    ok_line "i18n patched: './!(en).json' -> './*.json'"
else
    echo "Error: cannot patch i18n: neither './*.json' nor './!(en).json' found in" >&2
    echo "  $I18N_FILE" >&2
    echo "Upstream probably changed this file; check the locales import.meta.glob(...) pattern." >&2
    exit 1
fi

if [ "$PATCH_ONLY" = "1" ]; then
    ok_line "PATCH_ONLY: skipping frontend/backend build."
    exit 0
fi

VERSION="$(tr -d ' \t\r\n' < "$VERSION_FILE")"
[ -n "$VERSION" ] || { echo "Error: empty version file: $VERSION_FILE" >&2; exit 1; }
if [ -n "$VERSION_SUFFIX" ]; then APP_VERSION="$VERSION-$VERSION_SUFFIX"; else APP_VERSION="$VERSION"; fi

echo
echo "    package version : $VERSION"
echo "    app version     : $APP_VERSION"

# --- 2) frontend -------------------------------------------------------------------
if [ "$SKIP_FRONTEND" != "1" ]; then
    head_line "Building frontend (Vue 3 + Vite)"

    [ -f "$FRONTEND_DIR/package.json" ] || { echo "Error: frontend sources not found: $FRONTEND_DIR" >&2; exit 1; }

    if [ "$FORCE_INSTALL" = "1" ] || [ ! -d "$FRONTEND_DIR/node_modules" ]; then
        echo "    $NPM install --no-audit --no-fund"
        ( cd "$FRONTEND_DIR" && "$NPM" install --no-audit --no-fund )
    else
        ok_line "node_modules present (FORCE_INSTALL=1 to reinstall)"
    fi

    # npm script "build" uses rm -rf/cp -r (Unix) - use build:docker (plain vite build)
    # and lay the result out ourselves so Windows and Linux behave the same.
    echo "    $NPM run build:docker"
    ( cd "$FRONTEND_DIR" && "$NPM" run build:docker )

    [ -d "$DIST_DIR" ] || { echo "Error: frontend build produced no dist dir: $DIST_DIR" >&2; exit 1; }
    mkdir -p "$EMBED_DIR"
    rm -rf "${EMBED_DIR:?}/"*
    cp -R "$DIST_DIR/." "$EMBED_DIR/"

    # Without the i18n fix there are no locale chunks and the UI is English-only.
    [ -d "$EMBED_DIR/assets" ] || { echo "Error: no assets dir in the frontend build: $EMBED_DIR/assets" >&2; exit 1; }
    LOCALE_COUNT="$( (ls -1 "$EMBED_DIR/assets" || true) | grep -cE "$LOCALE_RE" || true )"
    ok_line "locale chunks in the frontend build: $LOCALE_COUNT"
    if [ "$LOCALE_COUNT" -lt "$MIN_LOCALE_CHUNKS" ]; then
        echo "Error: frontend build contains only $LOCALE_COUNT locale chunk(s), expected >= $MIN_LOCALE_CHUNKS." >&2
        echo "The i18n import.meta.glob pattern is probably broken again (Vite 8 / rolldown does" >&2
        echo "not support extglob '!(...)'), so the UI would be English-only. Check: $I18N_FILE" >&2
        exit 1
    fi
fi

# --- 3) backend --------------------------------------------------------------------
if [ "$SKIP_BACKEND" != "1" ]; then
    head_line "Building backend (Go, linux/amd64)"

    [ -f "$BACKEND_DIR/go.mod" ] || { echo "Error: backend sources not found: $BACKEND_DIR" >&2; exit 1; }

    GO_BIN="go"
    if [ -n "$GO_ROOT" ]; then
        export GOROOT="$GO_ROOT"
        export PATH="$GO_ROOT/bin:$PATH"
        GO_BIN="$GO_ROOT/bin/go"
    fi
    if [ -n "$GO_TOOLCHAIN" ]; then
        export GOTOOLCHAIN="$GO_TOOLCHAIN"
    fi

    LDFLAGS="-w -s -X github.com/gtsteffaniak/filebrowser/backend/internal/version.Version=$APP_VERSION"
    echo "    GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags \"$LDFLAGS\" -o filebrowserquantum ."
    ( cd "$BACKEND_DIR" && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 "$GO_BIN" build -trimpath -ldflags "$LDFLAGS" -o filebrowserquantum . )

    BUILT_BINARY="$BACKEND_DIR/filebrowserquantum"
    [ -f "$BUILT_BINARY" ] || { echo "Error: backend build produced no binary: $BUILT_BINARY" >&2; exit 1; }
    mkdir -p "$(dirname "$BINARY_OUT")"
    cp -f "$BUILT_BINARY" "$BINARY_OUT"
    ok_line "binary -> $BINARY_OUT"

    if ! grep -aqF "$APP_VERSION" "$BINARY_OUT"; then
        echo "Error: version string '$APP_VERSION' not found inside the binary - the build is wrong." >&2
        exit 1
    fi
    ASSET_COUNT="$(grep -ao '\.js\.gz' "$BINARY_OUT" | wc -l | tr -d ' ')"
    ok_line "binary reports version $APP_VERSION; embedded .js.gz assets: $ASSET_COUNT"
fi

# --- summary -----------------------------------------------------------------------
head_line "Done"
echo "    app version : $APP_VERSION"
if [ "$SKIP_FRONTEND" != "1" ]; then echo "    frontend    : $EMBED_DIR"; fi
if [ "$SKIP_BACKEND" != "1" ]; then echo "    binary      : $BINARY_OUT"; fi
echo
echo "Next: bash tools/build_all.sh"
