#include <png.h>

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int64_t InitCJRuntime(void *params);
extern int64_t LoadCJLibraryWithInit(const char *path);
extern int64_t FiniCJRuntime(void);

_Static_assert(sizeof(png_color) == 3u, "png_color layout");
_Static_assert(sizeof(png_color_8) == 5u, "png_color_8 layout");
_Static_assert(sizeof(png_color_16) == 10u, "png_color_16 layout");
_Static_assert(offsetof(png_color_16, red) == 2u, "png_color_16 red");
_Static_assert(offsetof(png_color_16, gray) == 8u, "png_color_16 gray");

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

static void returning_error(
    png_structp png_ptr, png_const_charp message
) {
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

static int signatures_are_exact(void) {
    png_uint_32 (*gamma_fn)(png_const_structp, png_const_infop,
        png_fixed_point *) = png_get_gAMA_fixed;
    png_uint_32 (*chrm_fn)(png_const_structp, png_const_infop,
        png_fixed_point *, png_fixed_point *, png_fixed_point *,
        png_fixed_point *, png_fixed_point *, png_fixed_point *,
        png_fixed_point *, png_fixed_point *) = png_get_cHRM_fixed;
    png_uint_32 (*srgb_fn)(png_const_structp, png_const_infop, int *) =
        png_get_sRGB;
    png_uint_32 (*sbit_fn)(png_const_structp, png_infop, png_color_8p *) =
        png_get_sBIT;
    png_uint_32 (*background_fn)(png_const_structp, png_infop,
        png_color_16p *) = png_get_bKGD;
    png_uint_32 (*phys_fn)(png_const_structp, png_const_infop,
        png_uint_32 *, png_uint_32 *, int *) = png_get_pHYs;
    png_uint_32 (*palette_fn)(png_const_structp, png_infop, png_colorp *,
        int *) = png_get_PLTE;
    png_uint_32 (*trans_fn)(png_const_structp, png_infop, png_bytep *,
        int *, png_color_16p *) = png_get_tRNS;
    return gamma_fn != NULL && chrm_fn != NULL && srgb_fn != NULL &&
        sbit_fn != NULL && background_fn != NULL && phys_fn != NULL &&
        palette_fn != NULL && trans_fn != NULL;
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

static int test_fixed_metadata(
    const unsigned char *bytes, size_t size
) {
    allocation_context allocation = {0u, 0u};
    read_context read;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(
            bytes, size, &allocation, &read, &png_ptr, &info_ptr
        )) return 0;

    png_fixed_point gamma = -1;
    png_fixed_point wx = -1, wy = -1, rx = -1, ry = -1;
    png_fixed_point gx = -1, gy = -1, bx = -1, by = -1;
    int intent = -1;
    png_color_8p sig_bit = NULL;
    png_color_8p sig_bit_again = NULL;
    png_color_16p background = NULL;
    png_uint_32 resolution_x = 0u, resolution_y = 0u;
    int unit = -1;

    int ok = png_get_gAMA_fixed(png_ptr, info_ptr, &gamma) == PNG_INFO_gAMA &&
        gamma == 45455 &&
        png_get_gAMA_fixed(png_ptr, info_ptr, NULL) == PNG_INFO_gAMA &&
        png_get_cHRM_fixed(
            png_ptr, info_ptr, &wx, &wy, &rx, &ry,
            &gx, &gy, &bx, &by
        ) == PNG_INFO_cHRM &&
        wx == 31270 && wy == 32900 && rx == 64000 && ry == 33000 &&
        gx == 30000 && gy == 60000 && bx == 15000 && by == 6000 &&
        png_get_sRGB(png_ptr, info_ptr, &intent) == PNG_INFO_sRGB &&
        intent == 1 &&
        png_get_sBIT(png_ptr, info_ptr, &sig_bit) == PNG_INFO_sBIT &&
        sig_bit != NULL && sig_bit->red == 5u && sig_bit->green == 5u &&
        sig_bit->blue == 5u && sig_bit->gray == 0u && sig_bit->alpha == 5u &&
        png_get_sBIT(png_ptr, info_ptr, &sig_bit_again) == PNG_INFO_sBIT &&
        sig_bit_again == sig_bit &&
        png_get_bKGD(png_ptr, info_ptr, &background) == PNG_INFO_bKGD &&
        background != NULL && background->index == 0u &&
        background->red == 224u && background->green == 224u &&
        background->blue == 128u && background->gray == 0u &&
        png_get_pHYs(
            png_ptr, info_ptr, &resolution_x, &resolution_y, &unit
        ) == PNG_INFO_pHYs && resolution_x == 2835u &&
        resolution_y == 2835u && unit == 1;

    png_colorp palette = (png_colorp)(uintptr_t)1u;
    int palette_count = 77;
    png_bytep alpha = (png_bytep)(uintptr_t)1u;
    int alpha_count = 88;
    png_color_16p trans_color = (png_color_16p)(uintptr_t)1u;
    ok = ok && png_get_PLTE(
        png_ptr, info_ptr, &palette, &palette_count
    ) == 0u && palette == (png_colorp)(uintptr_t)1u &&
        palette_count == 77 && png_get_tRNS(
            png_ptr, info_ptr, &alpha, &alpha_count, &trans_color
        ) == 0u && alpha == (png_bytep)(uintptr_t)1u && alpha_count == 88 &&
        trans_color == (png_color_16p)(uintptr_t)1u;

    return finish_decode(&png_ptr, &info_ptr, &allocation) && ok;
}

static int test_palette_metadata(
    const unsigned char *bytes, size_t size
) {
    allocation_context allocation = {0u, 0u};
    read_context read;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(
            bytes, size, &allocation, &read, &png_ptr, &info_ptr
        )) return 0;

    png_colorp palette = NULL;
    png_colorp palette_again = NULL;
    int palette_count = -1;
    png_bytep alpha = NULL;
    png_bytep alpha_again = NULL;
    int alpha_count = -1;
    png_color_16p trans_color = NULL;
    png_color_16p color_only = NULL;
    png_color_16p background = NULL;

    int ok = png_get_PLTE(
        png_ptr, info_ptr, &palette, &palette_count
    ) == PNG_INFO_PLTE && palette != NULL && palette_count == 245 &&
        palette[0].red == 255u && palette[0].green == 255u &&
        palette[0].blue == 255u && png_get_PLTE(
            png_ptr, info_ptr, &palette_again, NULL
        ) == PNG_INFO_PLTE && palette_again == palette &&
        png_get_tRNS(
            png_ptr, info_ptr, &alpha, &alpha_count, &trans_color
        ) == PNG_INFO_tRNS && alpha != NULL && alpha_count == 1 &&
        alpha[0] == 0u && trans_color != NULL &&
        png_get_tRNS(
            png_ptr, info_ptr, &alpha_again, NULL, NULL
        ) == PNG_INFO_tRNS && alpha_again == alpha &&
        png_get_tRNS(
            png_ptr, info_ptr, NULL, NULL, &color_only
        ) == 0u && color_only == trans_color &&
        png_get_bKGD(png_ptr, info_ptr, &background) == PNG_INFO_bKGD &&
        background != NULL && background->red == 255u &&
        background->green == 255u && background->blue == 255u;

    return finish_decode(&png_ptr, &info_ptr, &allocation) && ok;
}

static int test_truecolor_transparency(
    const unsigned char *bytes, size_t size
) {
    allocation_context allocation = {0u, 0u};
    read_context read;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(
            bytes, size, &allocation, &read, &png_ptr, &info_ptr
        )) return 0;

    png_bytep alpha = (png_bytep)(uintptr_t)1u;
    int count = -1;
    png_color_16p color = NULL;
    int ok = png_get_tRNS(
        png_ptr, info_ptr, &alpha, &count, &color
    ) == PNG_INFO_tRNS && alpha == NULL && count == 1 && color != NULL &&
        color->red == 255u && color->green == 255u &&
        color->blue == 255u && color->gray == 0u;

    alpha = (png_bytep)(uintptr_t)1u;
    ok = ok && png_get_tRNS(
        png_ptr, info_ptr, &alpha, NULL, NULL
    ) == 0u && alpha == NULL && png_get_tRNS(
        png_ptr, info_ptr, NULL, &count, NULL
    ) == PNG_INFO_tRNS && count == 1;

    return finish_decode(&png_ptr, &info_ptr, &allocation) && ok;
}

static int test_lifecycle_preserves_outputs(
    const unsigned char *bytes, size_t size
) {
    allocation_context first_allocation = {0u, 0u};
    allocation_context second_allocation = {0u, 0u};
    read_context first_read;
    read_context second_read;
    png_structp first = NULL, second = NULL;
    png_infop first_info = NULL, spare_info = NULL, second_info = NULL;
    if (!begin_decode(
            bytes, size, &first_allocation, &first_read, &first, &first_info
        )) return 0;
    spare_info = png_create_info_struct(first);
    if (!begin_decode(
            bytes, size, &second_allocation, &second_read, &second, &second_info
        ) || spare_info == NULL) {
        png_destroy_read_struct(&first, &first_info, &spare_info);
        png_destroy_read_struct(&second, &second_info, NULL);
        return 0;
    }

    png_fixed_point sentinel = 12345;
    int ok = png_get_gAMA_fixed(first, spare_info, &sentinel) == 0u &&
        sentinel == 12345 &&
        png_get_gAMA_fixed(second, first_info, &sentinel) == 0u &&
        sentinel == 12345 && png_get_gAMA_fixed(NULL, first_info, &sentinel) == 0u;
    png_structp stale = first;
    png_infop stale_info = first_info;
    png_destroy_read_struct(&first, &first_info, &spare_info);
    ok = ok && png_get_gAMA_fixed(stale, stale_info, &sentinel) == 0u &&
        sentinel == 12345 && first == NULL && first_info == NULL &&
        spare_info == NULL && first_allocation.allocations == first_allocation.frees;
    ok = finish_decode(&second, &second_info, &second_allocation) && ok;
    return ok;
}

int main(int argc, char **argv) {
    if (argc != 5) {
        fprintf(stderr, "usage: %s DYLIB FIXED_PNG PALETTE_PNG RGB_PNG\n", argv[0]);
        return 2;
    }
    size_t fixed_size = 0u, palette_size = 0u, rgb_size = 0u;
    unsigned char *fixed = read_file(argv[2], &fixed_size);
    unsigned char *palette = read_file(argv[3], &palette_size);
    unsigned char *rgb = read_file(argv[4], &rgb_size);
    if (fixed == NULL || palette == NULL || rgb == NULL) {
        free(fixed);
        free(palette);
        free(rgb);
        return 2;
    }

    max_align_t runtime_params[64];
    memset(runtime_params, 0, sizeof(runtime_params));
    int ok = InitCJRuntime(runtime_params) == 0 &&
        LoadCJLibraryWithInit(argv[1]) == 0 && signatures_are_exact() &&
        test_fixed_metadata(fixed, fixed_size) &&
        test_palette_metadata(palette, palette_size) &&
        test_truecolor_transparency(rgb, rgb_size) &&
        test_lifecycle_preserves_outputs(fixed, fixed_size);

    free(fixed);
    free(palette);
    free(rgb);
    if (FiniCJRuntime() != 0) ok = 0;
    if (!ok) return 4;
    printf("libpng4cj classic metadata ABI: PASS\n");
    return 0;
}
