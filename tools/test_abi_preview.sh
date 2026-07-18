#!/bin/sh

set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
OUT=${1:-"$ROOT/target/abi-preview/macos-arm64"}
EXPECTED="$ROOT/abi/symbols/libpng4cj-preview-v1.txt"
ACTUAL="$OUT/libpng4cj-preview-v1.actual.txt"
PNG_IMAGE_EXPECTED="$ROOT/abi/symbols/libpng4cj-png-image-memory-v1.txt"
PNG_IMAGE_ACTUAL="$OUT/libpng4cj-png-image-memory-v1.actual.txt"
RELOCATED=$(mktemp -d "${TMPDIR:-/tmp}/libpng4cj-abi-preview.XXXXXX")

trap 'rm -rf "$RELOCATED"' EXIT HUP INT TERM

"$ROOT/tools/build_abi_preview.sh" "$OUT"

nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && $3 ~ /^_png4cj_/ { sub(/^_/, "", $3); print $3 }' | \
    sort > "$ACTUAL"
diff -u "$EXPECTED" "$ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_image_begin_read_from_memory" || \
        $3 == "_png_image_finish_read" || $3 == "_png_image_free" || \
        $3 == "_png_image_write_to_memory") { sub(/^_/, "", $3); print $3 }' | \
    sort > "$PNG_IMAGE_ACTUAL"
diff -u "$PNG_IMAGE_EXPECTED" "$PNG_IMAGE_ACTUAL"

cc "$ROOT/test/abi_consumer/main.c" \
    -std=c11 \
    -Wall \
    -Wextra \
    -Werror \
    -I"$ROOT/abi/include" \
    -L"$OUT" \
    -lpng4cj_preview \
    -L"${CANGJIE_HOME}/runtime/lib/darwin_aarch64_cjnative" \
    -lcangjie-runtime \
    -lpthread \
    -Wl,-rpath,@loader_path \
    -Wl,-rpath,"${CANGJIE_HOME}/runtime/lib/darwin_aarch64_cjnative" \
    -o "$OUT/abi-consumer"

"$OUT/abi-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/ibasn0g01.png"

cc "$ROOT/test/abi_consumer/png_image_memory.c" \
    -std=c11 \
    -Wall \
    -Wextra \
    -Werror \
    -I"$ROOT/abi/include" \
    -L"$OUT" \
    -lpng4cj_preview \
    -L"${CANGJIE_HOME}/runtime/lib/darwin_aarch64_cjnative" \
    -lcangjie-runtime \
    -lpthread \
    -Wl,-rpath,@loader_path \
    -Wl,-rpath,"${CANGJIE_HOME}/runtime/lib/darwin_aarch64_cjnative" \
    -o "$OUT/png-image-memory-consumer"

"$OUT/png-image-memory-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/ibasn0g01.png" \
    "$ROOT/test/fixtures/pngsuite/ibasn6a16.png" \
    "$ROOT/test/fixtures/pngsuite/basn3p04.png"

cp "$OUT/abi-consumer" "$RELOCATED/"
cp "$OUT/libpng4cj_preview.dylib" "$RELOCATED/"
cp "$OUT/png-image-memory-consumer" "$RELOCATED/"
"$RELOCATED/abi-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/ibasn0g01.png"
"$RELOCATED/png-image-memory-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/ibasn0g01.png" \
    "$ROOT/test/fixtures/pngsuite/ibasn6a16.png" \
    "$ROOT/test/fixtures/pngsuite/basn3p04.png"
printf '%s\n' 'libpng4cj ABI preview consumer: PASS'
