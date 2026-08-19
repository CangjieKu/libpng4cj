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
CLASSIC_SCALAR_METADATA_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-scalar-metadata-v1.txt"
CLASSIC_SCALAR_METADATA_ACTUAL="$OUT/libpng4cj-classic-scalar-metadata-v1.actual.txt"
CLASSIC_EXTENDED_METADATA_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-extended-metadata-v1.txt"
CLASSIC_EXTENDED_METADATA_ACTUAL="$OUT/libpng4cj-classic-extended-metadata-v1.actual.txt"
CLASSIC_RUNTIME_CONTEXT_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-runtime-context-v1.txt"
CLASSIC_RUNTIME_CONTEXT_ACTUAL="$OUT/libpng4cj-classic-runtime-context-v1.actual.txt"
CLASSIC_OWNER_LIMITS_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-owner-read-limits-v1.txt"
CLASSIC_OWNER_LIMITS_ACTUAL="$OUT/libpng4cj-classic-owner-read-limits-v1.actual.txt"
CLASSIC_READ_TRANSFORM_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-read-transform-v1.txt"
CLASSIC_READ_TRANSFORM_ACTUAL="$OUT/libpng4cj-classic-read-transform-v1.actual.txt"
CLASSIC_WRITE_CHUNK_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-write-chunk-v1.txt"
CLASSIC_WRITE_CHUNK_ACTUAL="$OUT/libpng4cj-classic-write-chunk-v1.actual.txt"
CLASSIC_WRITE_LIFECYCLE_EXPECTED="$ROOT/abi/symbols/libpng4cj-classic-write-lifecycle-v1.txt"
CLASSIC_WRITE_LIFECYCLE_ACTUAL="$OUT/libpng4cj-classic-write-lifecycle-v1.actual.txt"
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
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_build_grayscale_palette" || \
        $3 == "_png_get_cHRM" || $3 == "_png_get_cICP" || \
        $3 == "_png_get_cLLI" || $3 == "_png_get_cLLI_fixed" || \
        $3 == "_png_get_copyright" || $3 == "_png_get_gAMA" || \
        $3 == "_png_get_header_ver" || \
        $3 == "_png_get_header_version" || \
        $3 == "_png_get_libpng_ver" || $3 == "_png_get_mDCV" || \
        $3 == "_png_get_mDCV_fixed" || $3 == "_png_get_oFFs" || \
        $3 == "_png_get_pixel_aspect_ratio" || \
        $3 == "_png_get_uint_31" || \
        $3 == "_png_get_x_offset_inches" || \
        $3 == "_png_get_y_offset_inches") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_SCALAR_METADATA_ACTUAL"
diff -u "$CLASSIC_SCALAR_METADATA_EXPECTED" "$CLASSIC_SCALAR_METADATA_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_get_cHRM_XYZ" || \
        $3 == "_png_get_cHRM_XYZ_fixed" || $3 == "_png_get_eXIf" || \
        $3 == "_png_get_eXIf_1" || $3 == "_png_get_hIST" || \
        $3 == "_png_get_iCCP" || $3 == "_png_get_pCAL" || \
        $3 == "_png_get_rows" || $3 == "_png_get_sCAL" || \
        $3 == "_png_get_sCAL_fixed" || $3 == "_png_get_sCAL_s" || \
        $3 == "_png_get_sPLT" || $3 == "_png_get_tIME" || \
        $3 == "_png_get_text" || $3 == "_png_get_unknown_chunks") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_EXTENDED_METADATA_ACTUAL"
diff -u "$CLASSIC_EXTENDED_METADATA_EXPECTED" "$CLASSIC_EXTENDED_METADATA_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_get_chunk_cache_max" || \
        $3 == "_png_get_chunk_malloc_max" || \
        $3 == "_png_get_compression_buffer_size" || \
        $3 == "_png_get_current_pass_number" || \
        $3 == "_png_get_current_row_number" || \
        $3 == "_png_get_io_chunk_type" || $3 == "_png_get_io_state" || \
        $3 == "_png_get_palette_max" || \
        $3 == "_png_get_progressive_ptr" || \
        $3 == "_png_get_rgb_to_gray_status" || \
        $3 == "_png_get_user_chunk_ptr" || \
        $3 == "_png_get_user_height_max" || \
        $3 == "_png_get_user_transform_ptr" || \
        $3 == "_png_get_user_width_max") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_RUNTIME_CONTEXT_ACTUAL"
diff -u "$CLASSIC_RUNTIME_CONTEXT_EXPECTED" "$CLASSIC_RUNTIME_CONTEXT_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_set_chunk_malloc_max" || \
        $3 == "_png_set_user_limits") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_OWNER_LIMITS_ACTUAL"
diff -u "$CLASSIC_OWNER_LIMITS_EXPECTED" "$CLASSIC_OWNER_LIMITS_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_read_update_info" || \
        $3 == "_png_set_background" || \
        $3 == "_png_set_background_fixed" || \
        $3 == "_png_set_check_for_invalid_index" || \
        $3 == "_png_set_expand" || $3 == "_png_set_expand_16" || \
        $3 == "_png_set_expand_gray_1_2_4_to_8" || \
        $3 == "_png_set_gamma" || $3 == "_png_set_gamma_fixed" || \
        $3 == "_png_set_gray_to_rgb" || \
        $3 == "_png_set_palette_to_rgb" || \
        $3 == "_png_set_rgb_to_gray" || \
        $3 == "_png_set_rgb_to_gray_fixed" || \
        $3 == "_png_set_scale_16" || $3 == "_png_set_strip_16" || \
        $3 == "_png_set_strip_alpha" || \
        $3 == "_png_set_tRNS_to_alpha" || \
        $3 == "_png_start_read_image") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_READ_TRANSFORM_ACTUAL"
diff -u "$CLASSIC_READ_TRANSFORM_EXPECTED" "$CLASSIC_READ_TRANSFORM_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_create_write_struct" || \
        $3 == "_png_create_write_struct_2" || \
        $3 == "_png_destroy_write_struct" || \
        $3 == "_png_set_write_fn" || $3 == "_png_write_sig" || \
        $3 == "_png_write_chunk" || $3 == "_png_write_chunk_start" || \
        $3 == "_png_write_chunk_data" || \
        $3 == "_png_write_chunk_end" || $3 == "_png_write_flush") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_WRITE_CHUNK_ACTUAL"
diff -u "$CLASSIC_WRITE_CHUNK_EXPECTED" "$CLASSIC_WRITE_CHUNK_ACTUAL"
nm -gU "$OUT/libpng4cj_preview.dylib" | \
    awk '$2 == "T" && ($3 == "_png_set_IHDR" || \
        $3 == "_png_set_PLTE" || \
        $3 == "_png_set_compression_buffer_size" || \
        $3 == "_png_set_compression_level" || \
        $3 == "_png_set_compression_mem_level" || \
        $3 == "_png_set_compression_method" || \
        $3 == "_png_set_compression_strategy" || \
        $3 == "_png_set_compression_window_bits" || \
        $3 == "_png_set_filter" || $3 == "_png_write_end" || \
        $3 == "_png_write_image" || $3 == "_png_write_info" || \
        $3 == "_png_write_row" || $3 == "_png_write_rows") \
        { sub(/^_/, "", $3); print $3 }' | \
    sort > "$CLASSIC_WRITE_LIFECYCLE_ACTUAL"
diff -u "$CLASSIC_WRITE_LIFECYCLE_EXPECTED" "$CLASSIC_WRITE_LIFECYCLE_ACTUAL"

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

cc "$ROOT/test/abi_consumer/png_classic_scalar_metadata.c" \
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
    -o "$OUT/png-classic-scalar-metadata-consumer"

"$OUT/png-classic-scalar-metadata-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/vendor/libpng-1.6.58/pngtest.png" \
    "$ROOT/test/fixtures/pngsuite/ibasn0g01.png"
if "$OUT/png-classic-scalar-metadata-consumer" \
    "$OUT/libpng4cj_preview.dylib" uint31-overflow
then
    uint31_status=0
else
    uint31_status=$?
fi
[ "$uint31_status" -eq 73 ] || {
    printf '%s\n' "png_get_uint_31 overflow exit=$uint31_status, expected=73" >&2
    exit 1
}

cc "$ROOT/test/abi_consumer/png_classic_extended_metadata.c" \
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
    -o "$OUT/png-classic-extended-metadata-consumer"

"$OUT/png-classic-extended-metadata-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/vendor/libpng-1.6.58/pngtest.png" \
    "$ROOT/test/fixtures/pngsuite/ibasn0g01.png"
if "$OUT/png-classic-extended-metadata-consumer" \
    "$OUT/libpng4cj_preview.dylib" scal-overflow \
    "$ROOT/vendor/libpng-1.6.58/pngtest.png"
then
    scal_status=0
else
    scal_status=$?
fi
[ "$scal_status" -eq 75 ] || {
    printf '%s\n' "png_get_sCAL_fixed overflow exit=$scal_status, expected=75" >&2
    exit 1
}

cc "$ROOT/test/abi_consumer/png_classic_runtime_context.c" \
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
    -o "$OUT/png-classic-runtime-context-consumer"

"$OUT/png-classic-runtime-context-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png"

cc "$ROOT/test/abi_consumer/png_classic_owner_read_limits.c" \
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
    -o "$OUT/png-classic-owner-read-limits-consumer"

"$OUT/png-classic-owner-read-limits-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png"
if "$OUT/png-classic-owner-read-limits-consumer" \
    "$OUT/libpng4cj_preview.dylib" dimension-limit \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png"
then
    dimension_limit_status=0
else
    dimension_limit_status=$?
fi
[ "$dimension_limit_status" -eq 81 ] || {
    printf '%s\n' \
        "png_set_user_limits exit=$dimension_limit_status, expected=81" >&2
    exit 1
}
if "$OUT/png-classic-owner-read-limits-consumer" \
    "$OUT/libpng4cj_preview.dylib" chunk-limit \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png"
then
    chunk_limit_status=0
else
    chunk_limit_status=$?
fi
[ "$chunk_limit_status" -eq 82 ] || {
    printf '%s\n' \
        "png_set_chunk_malloc_max exit=$chunk_limit_status, expected=82" >&2
    exit 1
}

cc "$ROOT/test/abi_consumer/png_classic_read_transform.c" \
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
    -o "$OUT/png-classic-read-transform-consumer"

"$OUT/png-classic-read-transform-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn3p04.png" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png" \
    "$ROOT/test/fixtures/pngsuite/basn4a16.png" \
    "$ROOT/test/fixtures/pngsuite/basn2c08.png"

cc "$ROOT/test/abi_consumer/png_classic_write_chunk.c" \
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
    -o "$OUT/png-classic-write-chunk-consumer"

"$OUT/png-classic-write-chunk-consumer" \
    "$OUT/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png"
if "$OUT/png-classic-write-chunk-consumer" \
    "$OUT/libpng4cj_preview.dylib" short-chunk
then
    short_chunk_status=0
else
    short_chunk_status=$?
fi
[ "$short_chunk_status" -eq 83 ] || {
    printf '%s\n' \
        "png_write_chunk_end exit=$short_chunk_status, expected=83" >&2
    exit 1
}
if "$OUT/png-classic-write-chunk-consumer" \
    "$OUT/libpng4cj_preview.dylib" long-chunk
then
    long_chunk_status=0
else
    long_chunk_status=$?
fi
[ "$long_chunk_status" -eq 84 ] || {
    printf '%s\n' \
        "png_write_chunk_data exit=$long_chunk_status, expected=84" >&2
    exit 1
}

cc "$ROOT/test/abi_consumer/png_classic_write_lifecycle.c" \
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
    -o "$OUT/png-classic-write-lifecycle-consumer"

"$OUT/png-classic-write-lifecycle-consumer" \
    "$OUT/libpng4cj_preview.dylib"

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
cp "$OUT/png-classic-scalar-metadata-consumer" "$RELOCATED/"
cp "$OUT/png-classic-extended-metadata-consumer" "$RELOCATED/"
cp "$OUT/png-classic-runtime-context-consumer" "$RELOCATED/"
cp "$OUT/png-classic-owner-read-limits-consumer" "$RELOCATED/"
cp "$OUT/png-classic-read-transform-consumer" "$RELOCATED/"
cp "$OUT/png-classic-write-chunk-consumer" "$RELOCATED/"
cp "$OUT/png-classic-write-lifecycle-consumer" "$RELOCATED/"
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
"$RELOCATED/png-classic-scalar-metadata-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/vendor/libpng-1.6.58/pngtest.png" \
    "$ROOT/test/fixtures/pngsuite/ibasn0g01.png"
if "$RELOCATED/png-classic-scalar-metadata-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" uint31-overflow
then
    uint31_status=0
else
    uint31_status=$?
fi
[ "$uint31_status" -eq 73 ] || {
    printf '%s\n' "relocated png_get_uint_31 overflow exit=$uint31_status, expected=73" >&2
    exit 1
}
"$RELOCATED/png-classic-extended-metadata-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/vendor/libpng-1.6.58/pngtest.png" \
    "$ROOT/test/fixtures/pngsuite/ibasn0g01.png"
if "$RELOCATED/png-classic-extended-metadata-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" scal-overflow \
    "$ROOT/vendor/libpng-1.6.58/pngtest.png"
then
    scal_status=0
else
    scal_status=$?
fi
[ "$scal_status" -eq 75 ] || {
    printf '%s\n' \
        "relocated png_get_sCAL_fixed overflow exit=$scal_status, expected=75" >&2
    exit 1
}
"$RELOCATED/png-classic-runtime-context-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png"
"$RELOCATED/png-classic-owner-read-limits-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png"
if "$RELOCATED/png-classic-owner-read-limits-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" dimension-limit \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png"
then
    relocated_dimension_limit_status=0
else
    relocated_dimension_limit_status=$?
fi
[ "$relocated_dimension_limit_status" -eq 81 ] || {
    printf '%s\n' \
        "relocated png_set_user_limits exit=$relocated_dimension_limit_status, expected=81" >&2
    exit 1
}
if "$RELOCATED/png-classic-owner-read-limits-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" chunk-limit \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png"
then
    relocated_chunk_limit_status=0
else
    relocated_chunk_limit_status=$?
fi
[ "$relocated_chunk_limit_status" -eq 82 ] || {
    printf '%s\n' \
        "relocated png_set_chunk_malloc_max exit=$relocated_chunk_limit_status, expected=82" >&2
    exit 1
}
"$RELOCATED/png-classic-read-transform-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn3p04.png" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png" \
    "$ROOT/test/fixtures/pngsuite/basn4a16.png" \
    "$ROOT/test/fixtures/pngsuite/basn2c08.png"
"$RELOCATED/png-classic-write-chunk-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" \
    "$ROOT/test/fixtures/pngsuite/basn0g01.png"
if "$RELOCATED/png-classic-write-chunk-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" short-chunk
then
    relocated_short_chunk_status=0
else
    relocated_short_chunk_status=$?
fi
[ "$relocated_short_chunk_status" -eq 83 ] || {
    printf '%s\n' \
        "relocated png_write_chunk_end exit=$relocated_short_chunk_status, expected=83" >&2
    exit 1
}
if "$RELOCATED/png-classic-write-chunk-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib" long-chunk
then
    relocated_long_chunk_status=0
else
    relocated_long_chunk_status=$?
fi
[ "$relocated_long_chunk_status" -eq 84 ] || {
    printf '%s\n' \
        "relocated png_write_chunk_data exit=$relocated_long_chunk_status, expected=84" >&2
    exit 1
}
"$RELOCATED/png-classic-write-lifecycle-consumer" \
    "$RELOCATED/libpng4cj_preview.dylib"
printf '%s\n' 'libpng4cj ABI preview consumer: PASS'
