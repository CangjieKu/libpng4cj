#include <png.h>

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int64_t InitCJRuntime(void *params);
extern int64_t LoadCJLibraryWithInit(const char *path);
extern int64_t FiniCJRuntime(void);

typedef struct read_context {
    const unsigned char *bytes;
    size_t size;
    size_t offset;
    int ok;
} read_context;

typedef struct allocation_context {
    size_t allocations;
    size_t frees;
} allocation_context;

static void returning_error(png_structp png_ptr, png_const_charp message) {
    (void)png_ptr;
    (void)message;
}

static void read_memory(
    png_structp png_ptr, png_bytep output, size_t length
) {
    read_context *context = png_get_io_ptr(png_ptr);
    if (context == NULL || output == NULL ||
        length > context->size - context->offset) {
        if (context != NULL) context->ok = 0;
        png_error(png_ptr, "Read Error");
        return;
    }
    memcpy(output, context->bytes + context->offset, length);
    context->offset += length;
}

static png_voidp counted_malloc(
    png_structp png_ptr, png_alloc_size_t size
) {
    allocation_context *context = png_get_mem_ptr(png_ptr);
    if (context != NULL) context->allocations += 1u;
    return malloc(size);
}

static void counted_free(png_structp png_ptr, png_voidp pointer) {
    allocation_context *context = png_get_mem_ptr(png_ptr);
    if (context != NULL) context->frees += 1u;
    free(pointer);
}

static unsigned char *read_file(const char *path, size_t *size_out) {
    FILE *file = fopen(path, "rb");
    if (file == NULL || fseek(file, 0, SEEK_END) != 0) {
        if (file != NULL) fclose(file);
        return NULL;
    }
    long length = ftell(file);
    if (length <= 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return NULL;
    }
    unsigned char *bytes = malloc((size_t)length);
    if (bytes == NULL ||
        fread(bytes, 1u, (size_t)length, file) != (size_t)length) {
        free(bytes);
        fclose(file);
        return NULL;
    }
    fclose(file);
    *size_out = (size_t)length;
    return bytes;
}

static png_uint_32 read_u32(const unsigned char *bytes) {
    return ((png_uint_32)bytes[0] << 24) |
        ((png_uint_32)bytes[1] << 16) |
        ((png_uint_32)bytes[2] << 8) |
        (png_uint_32)bytes[3];
}

static void write_u32(unsigned char *bytes, png_uint_32 value) {
    bytes[0] = (unsigned char)(value >> 24);
    bytes[1] = (unsigned char)(value >> 16);
    bytes[2] = (unsigned char)(value >> 8);
    bytes[3] = (unsigned char)value;
}

static png_uint_32 crc32_bytes(
    const unsigned char *bytes, size_t length
) {
    png_uint_32 crc = 0xffffffffu;
    for (size_t index = 0u; index < length; index += 1u) {
        crc ^= bytes[index];
        for (int bit = 0; bit < 8; bit += 1) {
            crc = (crc >> 1) ^
                (0xedb88320u & (png_uint_32)-(int)(crc & 1u));
        }
    }
    return crc ^ 0xffffffffu;
}

static int replace_chunk(
    unsigned char *bytes,
    size_t size,
    const char type[4],
    const unsigned char *payload,
    size_t payload_size
) {
    size_t offset = 8u;
    while (offset + 12u <= size) {
        png_uint_32 length = read_u32(bytes + offset);
        size_t chunk_size = (size_t)length + 12u;
        if (chunk_size > size - offset) return 0;
        if ((size_t)length == payload_size &&
            memcmp(bytes + offset + 4u, type, 4u) == 0) {
            memcpy(bytes + offset + 8u, payload, payload_size);
            write_u32(
                bytes + offset + 8u + payload_size,
                crc32_bytes(bytes + offset + 4u, payload_size + 4u)
            );
            return 1;
        }
        offset += chunk_size;
    }
    return 0;
}

static int signatures_are_exact(void) {
    png_uint_32 (*valid_fn)(png_const_structp, png_const_infop,
        png_uint_32) = png_get_valid;
    png_uint_32 (*ppm_fn)(png_const_structp, png_const_infop) =
        png_get_pixels_per_meter;
    png_uint_32 (*xppm_fn)(png_const_structp, png_const_infop) =
        png_get_x_pixels_per_meter;
    png_uint_32 (*yppm_fn)(png_const_structp, png_const_infop) =
        png_get_y_pixels_per_meter;
    png_fixed_point (*aspect_fn)(png_const_structp, png_const_infop) =
        png_get_pixel_aspect_ratio_fixed;
    png_const_bytep (*signature_fn)(png_const_structp, png_const_infop) =
        png_get_signature;
    png_int_32 (*x_pixel_fn)(png_const_structp, png_const_infop) =
        png_get_x_offset_pixels;
    png_int_32 (*y_pixel_fn)(png_const_structp, png_const_infop) =
        png_get_y_offset_pixels;
    png_int_32 (*x_micron_fn)(png_const_structp, png_const_infop) =
        png_get_x_offset_microns;
    png_int_32 (*y_micron_fn)(png_const_structp, png_const_infop) =
        png_get_y_offset_microns;
    png_uint_32 (*ppi_fn)(png_const_structp, png_const_infop) =
        png_get_pixels_per_inch;
    png_uint_32 (*xppi_fn)(png_const_structp, png_const_infop) =
        png_get_x_pixels_per_inch;
    png_uint_32 (*yppi_fn)(png_const_structp, png_const_infop) =
        png_get_y_pixels_per_inch;
    png_fixed_point (*x_inches_fn)(png_const_structp, png_const_infop) =
        png_get_x_offset_inches_fixed;
    png_fixed_point (*y_inches_fn)(png_const_structp, png_const_infop) =
        png_get_y_offset_inches_fixed;
    png_uint_32 (*dpi_fn)(png_const_structp, png_const_infop,
        png_uint_32 *, png_uint_32 *, int *) = png_get_pHYs_dpi;
    return valid_fn != NULL && ppm_fn != NULL && xppm_fn != NULL &&
        yppm_fn != NULL && aspect_fn != NULL && signature_fn != NULL &&
        x_pixel_fn != NULL && y_pixel_fn != NULL && x_micron_fn != NULL &&
        y_micron_fn != NULL && ppi_fn != NULL && xppi_fn != NULL &&
        yppi_fn != NULL && x_inches_fn != NULL && y_inches_fn != NULL &&
        dpi_fn != NULL;
}

static int begin_decode(
    const unsigned char *bytes,
    size_t size,
    allocation_context *allocation,
    read_context *read,
    png_structp *png_out,
    png_infop *info_out
) {
    png_structp png_ptr = png_create_read_struct_2(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL,
        allocation, counted_malloc, counted_free
    );
    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (png_ptr == NULL || info_ptr == NULL) {
        if (png_ptr != NULL) png_destroy_read_struct(&png_ptr, NULL, NULL);
        return 0;
    }
    read->bytes = bytes;
    read->size = size;
    read->offset = 0u;
    read->ok = 1;
    png_set_read_fn(png_ptr, read, read_memory);
    png_read_info(png_ptr, info_ptr);
    if (read->ok == 0 || read->offset != size) {
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }
    *png_out = png_ptr;
    *info_out = info_ptr;
    return 1;
}

static int finish_decode(
    png_structp *png_ptr,
    png_infop *info_ptr,
    allocation_context *allocation
) {
    png_destroy_read_struct(png_ptr, info_ptr, NULL);
    return *png_ptr == NULL && *info_ptr == NULL &&
        allocation->allocations == allocation->frees;
}

static int signature_is_png(png_const_bytep signature) {
    static const unsigned char expected[8] = {
        137u, 80u, 78u, 71u, 13u, 10u, 26u, 10u
    };
    return signature != NULL && memcmp(signature, expected, 8u) == 0;
}

static int test_upstream_oracles(
    const unsigned char *bytes, size_t size
) {
    allocation_context allocation = {0u, 0u};
    read_context read;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(
            bytes, size, &allocation, &read, &png_ptr, &info_ptr
        )) return 0;

    png_const_bytep signature = png_get_signature(png_ptr, info_ptr);
    png_const_bytep signature_again = png_get_signature(png_ptr, info_ptr);
    png_uint_32 dpi_x = 999u, dpi_y = 999u;
    int unit = 99;
    png_uint_32 raw_x = 999u;
    png_uint_32 valid = png_get_valid(png_ptr, info_ptr, 0x000fffffu);
    int ok = valid == 0x000e4fa7u &&
        png_get_valid(png_ptr, info_ptr, PNG_INFO_IDAT) == 0u &&
        png_get_pixels_per_meter(png_ptr, info_ptr) == 2835u &&
        png_get_x_pixels_per_meter(png_ptr, info_ptr) == 2835u &&
        png_get_y_pixels_per_meter(png_ptr, info_ptr) == 2835u &&
        png_get_pixel_aspect_ratio_fixed(png_ptr, info_ptr) == 100000 &&
        png_get_x_offset_pixels(png_ptr, info_ptr) == 0 &&
        png_get_y_offset_pixels(png_ptr, info_ptr) == 0 &&
        png_get_x_offset_microns(png_ptr, info_ptr) == -10 &&
        png_get_y_offset_microns(png_ptr, info_ptr) == 20 &&
        png_get_x_offset_inches_fixed(png_ptr, info_ptr) == -39 &&
        png_get_y_offset_inches_fixed(png_ptr, info_ptr) == 79 &&
        png_get_pixels_per_inch(png_ptr, info_ptr) == 72u &&
        png_get_x_pixels_per_inch(png_ptr, info_ptr) == 72u &&
        png_get_y_pixels_per_inch(png_ptr, info_ptr) == 72u &&
        png_get_pHYs_dpi(
            png_ptr, info_ptr, &dpi_x, &dpi_y, &unit
        ) == PNG_INFO_pHYs && dpi_x == 72u && dpi_y == 72u && unit == 1 &&
        png_get_pHYs_dpi(
            png_ptr, info_ptr, &raw_x, NULL, NULL
        ) == PNG_INFO_pHYs && raw_x == 2835u &&
        png_get_pHYs_dpi(png_ptr, info_ptr, NULL, NULL, NULL) == 0u &&
        signature_is_png(signature) && signature_again == signature;

    if (!ok) {
        fprintf(stderr,
            "oracle mismatch valid=%08x ppm=%u,%u,%u aspect=%d "
            "offset=%d,%d,%d,%d inches=%d,%d ppi=%u,%u,%u "
            "dpi=%u,%u,%d signature=%d stable=%d\n",
            valid,
            png_get_pixels_per_meter(png_ptr, info_ptr),
            png_get_x_pixels_per_meter(png_ptr, info_ptr),
            png_get_y_pixels_per_meter(png_ptr, info_ptr),
            png_get_pixel_aspect_ratio_fixed(png_ptr, info_ptr),
            png_get_x_offset_pixels(png_ptr, info_ptr),
            png_get_y_offset_pixels(png_ptr, info_ptr),
            png_get_x_offset_microns(png_ptr, info_ptr),
            png_get_y_offset_microns(png_ptr, info_ptr),
            png_get_x_offset_inches_fixed(png_ptr, info_ptr),
            png_get_y_offset_inches_fixed(png_ptr, info_ptr),
            png_get_pixels_per_inch(png_ptr, info_ptr),
            png_get_x_pixels_per_inch(png_ptr, info_ptr),
            png_get_y_pixels_per_inch(png_ptr, info_ptr),
            dpi_x, dpi_y, unit, signature_is_png(signature),
            signature_again == signature);
    }

    return finish_decode(&png_ptr, &info_ptr, &allocation) && ok;
}

static int test_unit_gates(
    const unsigned char *source, size_t size
) {
    unsigned char *bytes = malloc(size);
    if (bytes == NULL) return 0;
    memcpy(bytes, source, size);
    const unsigned char phys[9] = {
        0u, 0u, 1u, 44u, 0u, 0u, 1u, 144u, 0u
    };
    const unsigned char offset[9] = {
        255u, 255u, 255u, 249u, 0u, 0u, 0u, 9u, 0u
    };
    if (!replace_chunk(bytes, size, "pHYs", phys, sizeof(phys)) ||
        !replace_chunk(bytes, size, "oFFs", offset, sizeof(offset))) {
        free(bytes);
        return 0;
    }

    allocation_context allocation = {0u, 0u};
    read_context read;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(
            bytes, size, &allocation, &read, &png_ptr, &info_ptr
        )) {
        free(bytes);
        return 0;
    }
    png_uint_32 x = 999u, y = 999u;
    int unit = 99;
    int ok = png_get_pixels_per_meter(png_ptr, info_ptr) == 0u &&
        png_get_x_pixels_per_meter(png_ptr, info_ptr) == 0u &&
        png_get_y_pixels_per_meter(png_ptr, info_ptr) == 0u &&
        png_get_pixel_aspect_ratio_fixed(png_ptr, info_ptr) == 133333 &&
        png_get_pixels_per_inch(png_ptr, info_ptr) == 0u &&
        png_get_x_offset_pixels(png_ptr, info_ptr) == -7 &&
        png_get_y_offset_pixels(png_ptr, info_ptr) == 9 &&
        png_get_x_offset_microns(png_ptr, info_ptr) == 0 &&
        png_get_y_offset_microns(png_ptr, info_ptr) == 0 &&
        png_get_x_offset_inches_fixed(png_ptr, info_ptr) == 0 &&
        png_get_y_offset_inches_fixed(png_ptr, info_ptr) == 0 &&
        png_get_pHYs_dpi(
            png_ptr, info_ptr, &x, &y, &unit
        ) == PNG_INFO_pHYs && x == 300u && y == 400u && unit == 0;
    if (!ok) {
        fprintf(stderr,
            "unit mismatch ppm=%u,%u,%u aspect=%d offset=%d,%d,%d,%d "
            "inches=%d,%d dpi=%u,%u,%d\n",
            png_get_pixels_per_meter(png_ptr, info_ptr),
            png_get_x_pixels_per_meter(png_ptr, info_ptr),
            png_get_y_pixels_per_meter(png_ptr, info_ptr),
            png_get_pixel_aspect_ratio_fixed(png_ptr, info_ptr),
            png_get_x_offset_pixels(png_ptr, info_ptr),
            png_get_y_offset_pixels(png_ptr, info_ptr),
            png_get_x_offset_microns(png_ptr, info_ptr),
            png_get_y_offset_microns(png_ptr, info_ptr),
            png_get_x_offset_inches_fixed(png_ptr, info_ptr),
            png_get_y_offset_inches_fixed(png_ptr, info_ptr), x, y, unit);
    }
    ok = finish_decode(&png_ptr, &info_ptr, &allocation) && ok;
    free(bytes);
    return ok;
}

static int test_full_uint32_dpi_domain(
    const unsigned char *source, size_t size
) {
    unsigned char *bytes = malloc(size);
    if (bytes == NULL) return 0;
    memcpy(bytes, source, size);
    const unsigned char phys[9] = {
        255u, 255u, 255u, 255u, 255u, 255u, 255u, 255u, 1u
    };
    if (!replace_chunk(bytes, size, "pHYs", phys, sizeof(phys))) {
        free(bytes);
        return 0;
    }

    allocation_context allocation = {0u, 0u};
    read_context read;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(
            bytes, size, &allocation, &read, &png_ptr, &info_ptr
        )) {
        free(bytes);
        return 0;
    }
    png_uint_32 x = 0u, y = 0u;
    int unit = 0;
    int ok = png_get_x_pixels_per_meter(png_ptr, info_ptr) == 0xffffffffu &&
        png_get_y_pixels_per_meter(png_ptr, info_ptr) == 0xffffffffu &&
        png_get_pixels_per_inch(png_ptr, info_ptr) == 0u &&
        png_get_x_pixels_per_inch(png_ptr, info_ptr) == 0u &&
        png_get_y_pixels_per_inch(png_ptr, info_ptr) == 0u &&
        png_get_pixel_aspect_ratio_fixed(png_ptr, info_ptr) == 0 &&
        png_get_pHYs_dpi(
            png_ptr, info_ptr, &x, &y, &unit
        ) == PNG_INFO_pHYs && x == 109092169u && y == 109092169u &&
        unit == 1;
    if (!ok) {
        fprintf(stderr,
            "uint32 dpi mismatch ppm=%u,%u ppi=%u,%u,%u aspect=%d "
            "dpi=%u,%u,%d\n",
            png_get_x_pixels_per_meter(png_ptr, info_ptr),
            png_get_y_pixels_per_meter(png_ptr, info_ptr),
            png_get_pixels_per_inch(png_ptr, info_ptr),
            png_get_x_pixels_per_inch(png_ptr, info_ptr),
            png_get_y_pixels_per_inch(png_ptr, info_ptr),
            png_get_pixel_aspect_ratio_fixed(png_ptr, info_ptr), x, y, unit);
    }
    ok = finish_decode(&png_ptr, &info_ptr, &allocation) && ok;
    free(bytes);
    return ok;
}

static int test_absent_and_lifecycle(
    const unsigned char *plain,
    size_t plain_size,
    const unsigned char *fixed,
    size_t fixed_size
) {
    allocation_context first_allocation = {0u, 0u};
    allocation_context second_allocation = {0u, 0u};
    read_context first_read;
    read_context second_read;
    png_structp first = NULL, second = NULL;
    png_infop first_info = NULL, spare_info = NULL, second_info = NULL;
    if (!begin_decode(
            plain, plain_size, &first_allocation, &first_read,
            &first, &first_info
        )) return 0;
    spare_info = png_create_info_struct(first);
    if (!begin_decode(
            fixed, fixed_size, &second_allocation, &second_read,
            &second, &second_info
        ) || spare_info == NULL) {
        png_destroy_read_struct(&first, &first_info, &spare_info);
        png_destroy_read_struct(&second, &second_info, NULL);
        return 0;
    }

    png_uint_32 x = 777u, y = 888u;
    int unit = 99;
    int ok = png_get_pixels_per_meter(first, first_info) == 0u &&
        png_get_x_offset_microns(first, first_info) == 0 &&
        png_get_pHYs_dpi(
            first, first_info, &x, &y, &unit
        ) == 0u && x == 777u && y == 888u && unit == 99 &&
        png_get_signature(first, first_info) != NULL &&
        png_get_valid(first, spare_info, 0xffffffffu) == 0u &&
        png_get_signature(first, spare_info) == NULL &&
        png_get_valid(second, first_info, 0xffffffffu) == 0u &&
        png_get_signature(second, first_info) == NULL;

    png_structp stale = first;
    png_infop stale_info = first_info;
    png_destroy_read_struct(&first, &first_info, &spare_info);
    ok = ok && png_get_valid(stale, stale_info, 0xffffffffu) == 0u &&
        png_get_signature(stale, stale_info) == NULL && first == NULL &&
        first_info == NULL && spare_info == NULL &&
        first_allocation.allocations == first_allocation.frees;
    ok = finish_decode(&second, &second_info, &second_allocation) && ok;
    return ok;
}

static int test_palette_validity(
    const unsigned char *bytes, size_t size
) {
    allocation_context allocation = {0u, 0u};
    read_context read;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(
            bytes, size, &allocation, &read, &png_ptr, &info_ptr
        )) return 0;
    int ok = png_get_valid(
        png_ptr, info_ptr, PNG_INFO_PLTE | PNG_INFO_tRNS
    ) == (PNG_INFO_PLTE | PNG_INFO_tRNS);
    return finish_decode(&png_ptr, &info_ptr, &allocation) && ok;
}

int main(int argc, char **argv) {
    if (argc != 5) {
        fprintf(stderr, "usage: %s DYLIB FIXED_PNG PLAIN_PNG PALETTE_PNG\n",
            argv[0]);
        return 2;
    }
    size_t fixed_size = 0u, plain_size = 0u, palette_size = 0u;
    unsigned char *fixed = read_file(argv[2], &fixed_size);
    unsigned char *plain = read_file(argv[3], &plain_size);
    unsigned char *palette = read_file(argv[4], &palette_size);
    if (fixed == NULL || plain == NULL || palette == NULL) {
        free(fixed);
        free(plain);
        free(palette);
        return 2;
    }

    max_align_t runtime_params[64];
    memset(runtime_params, 0, sizeof(runtime_params));
    int runtime_ok = InitCJRuntime(runtime_params) == 0;
    int load_ok = runtime_ok && LoadCJLibraryWithInit(argv[1]) == 0;
    int signature_ok = load_ok && signatures_are_exact();
    int oracle_ok = signature_ok && test_upstream_oracles(fixed, fixed_size);
    int unit_ok = oracle_ok && test_unit_gates(fixed, fixed_size);
    int uint32_dpi_ok = unit_ok &&
        test_full_uint32_dpi_domain(fixed, fixed_size);
    int lifecycle_ok = uint32_dpi_ok && test_absent_and_lifecycle(
        plain, plain_size, fixed, fixed_size
    );
    int palette_ok = lifecycle_ok &&
        test_palette_validity(palette, palette_size);
    int ok = runtime_ok && load_ok && signature_ok && oracle_ok && unit_ok &&
        uint32_dpi_ok && lifecycle_ok && palette_ok;
    if (!ok) {
        fprintf(stderr,
            "stages runtime=%d load=%d signatures=%d oracle=%d unit=%d "
            "uint32-dpi=%d lifecycle=%d palette=%d\n",
            runtime_ok, load_ok, signature_ok, oracle_ok, unit_ok,
            uint32_dpi_ok, lifecycle_ok, palette_ok);
    }

    free(fixed);
    free(plain);
    free(palette);
    if (FiniCJRuntime() != 0) ok = 0;
    if (!ok) return 4;
    printf("libpng4cj classic easy-access ABI: PASS\n");
    return 0;
}
