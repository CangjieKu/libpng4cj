#!/bin/sh

set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
OUT=${1:-"$ROOT/target/abi-preview/macos-arm64"}
RUNTIME_DIR=${CANGJIE_HOME:-}/runtime/lib/darwin_aarch64_cjnative

if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
    printf '%s\n' 'libpng4cj ABI preview: only macOS arm64 is currently supported' >&2
    exit 2
fi
if [ -z "${CANGJIE_HOME:-}" ] || [ ! -d "$RUNTIME_DIR" ]; then
    printf '%s\n' 'libpng4cj ABI preview: CANGJIE_HOME runtime is unavailable' >&2
    exit 2
fi

mkdir -p "$OUT/include"
rm -f "$OUT/libpng4cj_cj.dylib"

cjc -p "$ROOT/src" \
    --no-sub-pkg \
    --output-type=dylib \
    --set-runtime-rpath \
    --link-options "-install_name @rpath/libpng4cj_preview.dylib" \
    -Woff unused \
    -lz \
    -o "$OUT/libpng4cj_preview.dylib"

cp "$ROOT/abi/include/libpng4cj_preview.h" "$OUT/include/"
cp "$ROOT/abi/include/png.h" "$OUT/include/"
printf 'libpng4cj ABI preview built at %s\n' "$OUT"
