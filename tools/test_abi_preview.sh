#!/bin/sh

set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
OUT=${1:-"$ROOT/target/abi-preview/macos-arm64"}
EXPECTED="$ROOT/abi/symbols/libpng4cj-preview-v1.txt"
ACTUAL="$OUT/libpng4cj-preview-v1.actual.txt"
PNG_IMAGE_EXPECTED="$ROOT/abi/symbols/libpng4cj-png-image-memory-v1.txt"
PNG_IMAGE_ACTUAL="$OUT/libpng4cj-png-image-memory-v1.actual.txt"
PNG_IMAGE_FILE_STDIO_EXPECTED="$ROOT/abi/symbols/libpng4cj-png-image-file-stdio-v1.txt"
PNG_IMAGE_FILE_STDIO_ACTUAL="$OUT/libpng4cj-png-image-file-stdio-v1.actual.txt"
CLASSIC_STATELESS_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-stateless-v1.txt"
CLASSIC_STATELESS_ACTUAL="$OUT/libpng4cj-classic-stateless-v1.actual.txt"
CLASSIC_READ_HANDLE_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-read-handle-v1.txt"
CLASSIC_READ_HANDLE_ACTUAL="$OUT/libpng4cj-classic-read-handle-v1.actual.txt"
CLASSIC_ERROR_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-error-v1.txt"
CLASSIC_ERROR_ACTUAL="$OUT/libpng4cj-classic-error-v1.actual.txt"
CLASSIC_MEMORY_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-memory-v1.txt"
CLASSIC_MEMORY_ACTUAL="$OUT/libpng4cj-classic-memory-v1.actual.txt"
CLASSIC_READ_IO_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-read-io-v1.txt"
CLASSIC_READ_IO_ACTUAL="$OUT/libpng4cj-classic-read-io-v1.actual.txt"
CLASSIC_CORE_INFO_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-core-info-v1.txt"
CLASSIC_CORE_INFO_ACTUAL="$OUT/libpng4cj-classic-core-info-v1.actual.txt"
CLASSIC_ROW_READ_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-row-read-v1.txt"
CLASSIC_ROW_READ_ACTUAL="$OUT/libpng4cj-classic-row-read-v1.actual.txt"
CLASSIC_METADATA_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-metadata-v1.txt"
CLASSIC_METADATA_ACTUAL="$OUT/libpng4cj-classic-metadata-v1.actual.txt"
CLASSIC_EASY_ACCESS_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-easy-access-v1.txt"
CLASSIC_EASY_ACCESS_ACTUAL="$OUT/libpng4cj-classic-easy-access-v1.actual.txt"
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
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_image_begin_read_from_file" || \
        $3 == "_png_image_begin_read_from_stdio" || \
        $3 == "_png_image_write_to_file" || \
        $3 == "_png_image_write_to_stdio") { sub(/^_/, "", $3); print $3 }' | \
    sort > "$PNG_IMAGE_FILE_STDIO_ACTUAL"
diff -u "$PNG_IMAGE_FILE_STDIO_EXPECTED" "$PNG_IMAGE_FILE_STDIO_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_access_version_number" || \
        $3 == "_png_sig_cmp" || $3 == "_png_get_uint_32" || \
        $3 == "_png_get_uint_16" || $3 == "_png_get_int_32" || \
        $3 == "_png_save_uint_32" || $3 == "_png_save_int_32" || \
        $3 == "_png_save_uint_16") { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_STATELESS_ACTUAL"
diff -u "$CLASSIC_STATELESS_EXPECTED" "$CLASSIC_STATELESS_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_create_read_struct" || \
        $3 == "_png_create_read_struct_2" || \
        $3 == "_png_create_info_struct" || \
        $3 == "_png_destroy_info_struct" || \
        $3 == "_png_destroy_read_struct" || \
        $3 == "_png_set_error_fn" || $3 == "_png_get_error_ptr" || \
        $3 == "_png_set_mem_fn" || $3 == "_png_get_mem_ptr") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_READ_HANDLE_ACTUAL"
diff -u "$CLASSIC_READ_HANDLE_EXPECTED" "$CLASSIC_READ_HANDLE_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_error" || $3 == "_png_warning") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_ERROR_ACTUAL"
diff -u "$CLASSIC_ERROR_EXPECTED" "$CLASSIC_ERROR_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_malloc" || $3 == "_png_calloc" || \
        $3 == "_png_malloc_warn" || $3 == "_png_free" || \
        $3 == "_png_malloc_default" || $3 == "_png_free_default") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_MEMORY_ACTUAL"
diff -u "$CLASSIC_MEMORY_EXPECTED" "$CLASSIC_MEMORY_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_init_io" || \
        $3 == "_png_set_read_fn" || $3 == "_png_get_io_ptr" || \
        $3 == "_png_set_sig_bytes" || $3 == "_png_read_info") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_READ_IO_ACTUAL"
diff -u "$CLASSIC_READ_IO_EXPECTED" "$CLASSIC_READ_IO_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_get_IHDR" || \
        $3 == "_png_get_bit_depth" || $3 == "_png_get_channels" || \
        $3 == "_png_get_color_type" || \
        $3 == "_png_get_compression_type" || \
        $3 == "_png_get_filter_type" || \
        $3 == "_png_get_image_height" || \
        $3 == "_png_get_image_width" || \
        $3 == "_png_get_interlace_type" || \
        $3 == "_png_get_rowbytes") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_CORE_INFO_ACTUAL"
diff -u "$CLASSIC_CORE_INFO_EXPECTED" "$CLASSIC_CORE_INFO_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_read_end" || \
        $3 == "_png_read_image" || $3 == "_png_read_row" || \
        $3 == "_png_read_rows") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_ROW_READ_ACTUAL"
diff -u "$CLASSIC_ROW_READ_EXPECTED" "$CLASSIC_ROW_READ_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_get_PLTE" || \
        $3 == "_png_get_bKGD" || $3 == "_png_get_cHRM_fixed" || \
        $3 == "_png_get_gAMA_fixed" || $3 == "_png_get_pHYs" || \
        $3 == "_png_get_sBIT" || $3 == "_png_get_sRGB" || \
        $3 == "_png_get_tRNS") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_METADATA_ACTUAL"
diff -u "$CLASSIC_METADATA_EXPECTED" "$CLASSIC_METADATA_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_get_pHYs_dpi" || \
        $3 == "_png_get_pixel_aspect_ratio_fixed" || \
        $3 == "_png_get_pixels_per_inch" || \
        $3 == "_png_get_pixels_per_meter" || \
        $3 == "_png_get_signature" || $3 == "_png_get_valid" || \
        $3 == "_png_get_x_offset_inches_fixed" || \
        $3 == "_png_get_x_offset_microns" || \
        $3 == "_png_get_x_offset_pixels" || \
        $3 == "_png_get_x_pixels_per_inch" || \
        $3 == "_png_get_x_pixels_per_meter" || \
        $3 == "_png_get_y_offset_inches_fixed" || \
        $3 == "_png_get_y_offset_microns" || \
        $3 == "_png_get_y_offset_pixels" || \
        $3 == "_png_get_y_pixels_per_inch" || \
        $3 == "_png_get_y_pixels_per_meter") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_EASY_ACCESS_ACTUAL"
diff -u "$CLASSIC_EASY_ACCESS_EXPECTED" "$CLASSIC_EASY_ACCESS_ACTUAL"

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

cc "$ROOT/test/abi_consumer/png_image_file_stdio.c" \
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
    -o "$OUT/png-image-file-stdio-consumer"

"$OUT/png-image-file-stdio-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/ibasn6a08.png" \
    "$OUT/png-image-file-output.png" \
    "$OUT/png-image-stdio-output.png" \
    "$OUT/png-image-malformed.bin" \
    "$OUT/missing/png.png"

cc "$ROOT/test/abi_consumer/png_classic_stateless.c" \
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
    -o "$OUT/png-classic-stateless-consumer"

"$OUT/png-classic-stateless-consumer" "$OUT/libpng4cj_preview.dylib"

cc "$ROOT/test/abi_consumer/png_classic_read_handle.c" \
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
    -o "$OUT/png-classic-read-handle-consumer"

"$OUT/png-classic-read-handle-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png"

cc "$ROOT/test/abi_consumer/png_classic_core_info.c" \
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
    -o "$OUT/png-classic-core-info-consumer"

"$OUT/png-classic-core-info-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png" \
    "$ROOT/test/fixtures/pngsuite/ibasn6a08.png"

cc "$ROOT/test/abi_consumer/png_classic_row_read.c" \
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
    -o "$OUT/png-classic-row-read-consumer"

"$OUT/png-classic-row-read-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png" \
    "$ROOT/test/fixtures/pngsuite/ibasn6a08.png"

cc "$ROOT/test/abi_consumer/png_classic_metadata.c" \
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
    -o "$OUT/png-classic-metadata-consumer"

"$OUT/png-classic-metadata-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/vendor/libpng-1.6.58/pngtest.png" \
    "$ROOT/vendor/libpng-1.6.58/contrib/pngsuite/ftbwn3p08.png" \
    "$ROOT/vendor/libpng-1.6.58/contrib/pngsuite/ftbrn2c08.png"

cc "$ROOT/test/abi_consumer/png_classic_easy_access.c" \
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
    -o "$OUT/png-classic-easy-access-consumer"

"$OUT/png-classic-easy-access-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/vendor/libpng-1.6.58/pngtest.png" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png" \
    "$ROOT/vendor/libpng-1.6.58/contrib/pngsuite/ftbwn3p08.png"

cp "$OUT/abi-consumer" "$RELOCATED/"
cp "$OUT/libpng4cj_preview.dylib" "$RELOCATED/"
cp "$OUT/png-image-memory-consumer" "$RELOCATED/"
cp "$OUT/png-image-file-stdio-consumer" "$RELOCATED/"
cp "$OUT/png-classic-stateless-consumer" "$RELOCATED/"
cp "$OUT/png-classic-read-handle-consumer" "$RELOCATED/"
cp "$OUT/png-classic-core-info-consumer" "$RELOCATED/"
cp "$OUT/png-classic-row-read-consumer" "$RELOCATED/"
cp "$OUT/png-classic-metadata-consumer" "$RELOCATED/"
cp "$OUT/png-classic-easy-access-consumer" "$RELOCATED/"
"$RELOCATED/abi-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/ibasn0g01.png"
"$RELOCATED/png-image-memory-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/ibasn0g01.png" \
    "$ROOT/test/fixtures/pngsuite/ibasn6a16.png" \
    "$ROOT/test/fixtures/pngsuite/basn3p04.png"
"$RELOCATED/png-image-file-stdio-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/ibasn6a08.png" \
    "$RELOCATED/png-image-file-output.png" \
    "$RELOCATED/png-image-stdio-output.png" \
    "$RELOCATED/png-image-malformed.bin" \
    "$RELOCATED/missing/png.png"
"$RELOCATED/png-classic-stateless-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib"
"$RELOCATED/png-classic-read-handle-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png"
"$RELOCATED/png-classic-core-info-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png" \
    "$ROOT/test/fixtures/pngsuite/ibasn6a08.png"
"$RELOCATED/png-classic-row-read-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png" \
    "$ROOT/test/fixtures/pngsuite/ibasn6a08.png"
"$RELOCATED/png-classic-metadata-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/vendor/libpng-1.6.58/pngtest.png" \
    "$ROOT/vendor/libpng-1.6.58/contrib/pngsuite/ftbwn3p08.png" \
    "$ROOT/vendor/libpng-1.6.58/contrib/pngsuite/ftbrn2c08.png"
"$RELOCATED/png-classic-easy-access-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/vendor/libpng-1.6.58/pngtest.png" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png" \
    "$ROOT/vendor/libpng-1.6.58/contrib/pngsuite/ftbwn3p08.png"
printf '%s\n' 'libpng4cj ABI preview consumer: PASS'
