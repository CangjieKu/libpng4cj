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

static void uint31_error(png_structp png_ptr, png_const_charp message) {
    int *context = png_get_error_ptr(png_ptr);
    if (context != NULL && *context == 31 && message != NULL &&
        strcmp(message, "PNG unsigned integer out of range") == 0) {
        _Exit(73);
    }
    _Exit(74);
}

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

static int close_double(double actual, double expected, double epsilon) {
    double difference = actual - expected;
    if (difference < 0.0) difference = -difference;
    return difference <= epsilon;
}

static int close_float(float actual, float expected, float epsilon) {
    float difference = actual - expected;
    if (difference < 0.0f) difference = -difference;
    return difference <= epsilon;
}

static int signatures_are_exact(void) {
    png_uint_32 (*gamma_fn)(png_const_structp, png_const_infop, double *) =
        png_get_gAMA;
    png_uint_32 (*chrm_fn)(png_const_structp, png_const_infop,
        double *, double *, double *, double *, double *, double *,
        double *, double *) = png_get_cHRM;
    float (*aspect_fn)(png_const_structp, png_const_infop) =
        png_get_pixel_aspect_ratio;
    float (*x_inches_fn)(png_const_structp, png_const_infop) =
        png_get_x_offset_inches;
    float (*y_inches_fn)(png_const_structp, png_const_infop) =
        png_get_y_offset_inches;
    png_const_charp (*copyright_fn)(png_const_structp) = png_get_copyright;
    png_const_charp (*header_fn)(png_const_structp) = png_get_header_ver;
    png_const_charp (*header_version_fn)(png_const_structp) =
        png_get_header_version;
    png_const_charp (*libpng_fn)(png_const_structp) = png_get_libpng_ver;
    png_uint_32 (*uint31_fn)(png_const_structp, png_const_bytep) =
        png_get_uint_31;
    void (*gray_fn)(int, png_colorp) = png_build_grayscale_palette;
    png_uint_32 (*offset_fn)(png_const_structp, png_const_infop,
        png_int_32 *, png_int_32 *, int *) = png_get_oFFs;
    png_uint_32 (*cicp_fn)(png_const_structp, png_const_infop,
        png_bytep, png_bytep, png_bytep, png_bytep) = png_get_cICP;
    png_uint_32 (*clli_fixed_fn)(png_const_structp, png_const_infop,
        png_uint_32 *, png_uint_32 *) = png_get_cLLI_fixed;
    png_uint_32 (*clli_fn)(png_const_structp, png_const_infop,
        double *, double *) = png_get_cLLI;
    png_uint_32 (*mdcv_fixed_fn)(png_const_structp, png_const_infop,
        png_fixed_point *, png_fixed_point *, png_fixed_point *,
        png_fixed_point *, png_fixed_point *, png_fixed_point *,
        png_fixed_point *, png_fixed_point *, png_uint_32 *, png_uint_32 *) =
        png_get_mDCV_fixed;
    png_uint_32 (*mdcv_fn)(png_const_structp, png_const_infop,
        double *, double *, double *, double *, double *, double *,
        double *, double *, double *, double *) = png_get_mDCV;
    return gamma_fn != NULL && chrm_fn != NULL && aspect_fn != NULL &&
        x_inches_fn != NULL && y_inches_fn != NULL && copyright_fn != NULL &&
        header_fn != NULL && header_version_fn != NULL && libpng_fn != NULL &&
        uint31_fn != NULL && gray_fn != NULL && offset_fn != NULL &&
        cicp_fn != NULL && clli_fixed_fn != NULL && clli_fn != NULL &&
        mdcv_fixed_fn != NULL && mdcv_fn != NULL;
}

static int test_stateless_and_strings(void) {
    const png_byte maximum[] = {0x7f, 0xff, 0xff, 0xff};
    png_color palette[256];
    memset(palette, 0xa5, sizeof(palette));
    png_build_grayscale_palette(2, palette);
    int ok = png_get_uint_31(NULL, maximum) == 0x7fffffffu &&
        palette[0].red == 0u && palette[0].green == 0u &&
        palette[0].blue == 0u && palette[1].red == 0x55u &&
        palette[2].green == 0xaau && palette[3].blue == 0xffu;

    memset(palette, 0xa5, sizeof(palette));
    png_build_grayscale_palette(3, palette);
    ok = ok && palette[0].red == 0xa5u && palette[255].blue == 0xa5u;

    png_const_charp copyright = png_get_copyright(NULL);
    png_const_charp header = png_get_header_ver(NULL);
    png_const_charp header_again = png_get_header_ver(NULL);
    png_const_charp long_header = png_get_header_version(NULL);
    png_const_charp library = png_get_libpng_ver(NULL);
    return ok && copyright != NULL && header != NULL && long_header != NULL &&
        library != NULL && header == header_again && header == library &&
        strcmp(header, "1.6.58") == 0 &&
        strcmp(long_header, " libpng version 1.6.58\n\n") == 0 &&
        strcmp(copyright,
            "\nlibpng version 1.6.58\n"
            "Copyright (c) 2018-2026 Cosmin Truta\n"
            "Copyright (c) 1998-2002,2004,2006-2018 Glenn Randers-Pehrson\n"
            "Copyright (c) 1996-1997 Andreas Dilger\n"
            "Copyright (c) 1995-1996 Guy Eric Schalnat, Group 42, Inc.\n"
        ) == 0;
}

static int run_uint31_overflow(const char *dylib) {
    max_align_t runtime_params[64];
    memset(runtime_params, 0, sizeof(runtime_params));
    if (InitCJRuntime(runtime_params) != 0 ||
        LoadCJLibraryWithInit(dylib) != 0) return 10;
    int context = 31;
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, &context, uint31_error, NULL
    );
    if (png_ptr == NULL) return 11;
    const png_byte overflow[] = {0x80, 0x00, 0x00, 0x00};
    (void)png_get_uint_31(png_ptr, overflow);
    return 12;
}

static int test_scalar_metadata(
    const unsigned char *bytes, size_t size
) {
    allocation_context allocation = {0u, 0u};
    read_context read;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(
            bytes, size, &allocation, &read, &png_ptr, &info_ptr
        )) return 0;

    double gamma = -1.0;
    double wx = -1.0, wy = -1.0, rx = -1.0, ry = -1.0;
    double gx = -1.0, gy = -1.0, bx = -1.0, by = -1.0;
    png_int_32 offset_x = 99, offset_y = 99;
    int offset_unit = 99;
    png_byte primaries = 99u, transfer = 99u, matrix = 99u, full = 99u;
    png_uint_32 max_cll = 0u, max_fall = 0u;
    double max_cll_float = -1.0, max_fall_float = -1.0;
    png_fixed_point mwx = -1, mwy = -1, mrx = -1, mry = -1;
    png_fixed_point mgx = -1, mgy = -1, mbx = -1, mby = -1;
    png_uint_32 max_dl = 0u, min_dl = 0u;
    double mwx_float = -1.0, mwy_float = -1.0;
    double mrx_float = -1.0, mry_float = -1.0;
    double mgx_float = -1.0, mgy_float = -1.0;
    double mbx_float = -1.0, mby_float = -1.0;
    double max_dl_float = -1.0, min_dl_float = -1.0;

    int ok = png_get_gAMA(png_ptr, info_ptr, &gamma) == PNG_INFO_gAMA &&
        close_double(gamma, 0.45455, 0.000000001) &&
        png_get_gAMA(png_ptr, info_ptr, NULL) == PNG_INFO_gAMA &&
        png_get_cHRM(
            png_ptr, info_ptr, &wx, &wy, &rx, &ry, &gx, &gy, &bx, &by
        ) == PNG_INFO_cHRM && close_double(wx, 0.31270, 0.000000001) &&
        close_double(wy, 0.32900, 0.000000001) &&
        close_double(rx, 0.64000, 0.000000001) &&
        close_double(ry, 0.33000, 0.000000001) &&
        close_double(gx, 0.30000, 0.000000001) &&
        close_double(gy, 0.60000, 0.000000001) &&
        close_double(bx, 0.15000, 0.000000001) &&
        close_double(by, 0.06000, 0.000000001) &&
        close_float(
            png_get_pixel_aspect_ratio(png_ptr, info_ptr), 1.0f, 0.000001f
        ) && png_get_oFFs(
            png_ptr, info_ptr, &offset_x, &offset_y, &offset_unit
        ) == PNG_INFO_oFFs && offset_x == -10 && offset_y == 20 &&
        offset_unit == PNG_OFFSET_MICROMETER && close_float(
            png_get_x_offset_inches(png_ptr, info_ptr),
            -0.0003937f, 0.00000001f
        ) && close_float(
            png_get_y_offset_inches(png_ptr, info_ptr),
            0.0007874f, 0.00000001f
        ) && png_get_cICP(
            png_ptr, info_ptr, &primaries, &transfer, &matrix, &full
        ) == PNG_INFO_cICP && primaries == 1u && transfer == 13u &&
        matrix == 0u && full == 1u && png_get_cLLI_fixed(
            png_ptr, info_ptr, &max_cll, &max_fall
        ) == PNG_INFO_cLLI && max_cll == 3000000u &&
        max_fall == 200000u && png_get_cLLI(
            png_ptr, info_ptr, &max_cll_float, &max_fall_float
        ) == PNG_INFO_cLLI && close_double(max_cll_float, 300.0, 0.0000001) &&
        close_double(max_fall_float, 20.0, 0.0000001) &&
        png_get_mDCV_fixed(
            png_ptr, info_ptr, &mwx, &mwy, &mrx, &mry,
            &mgx, &mgy, &mbx, &mby, &max_dl, &min_dl
        ) == PNG_INFO_mDCV && mwx == 17284 && mwy == 17926 &&
        mrx == 36734 && mry == 13264 && mgx == 7980 && mgy == 42020 &&
        mbx == 1830 && mby == 4 && max_dl == 800000u && min_dl == 10000u &&
        png_get_mDCV(
            png_ptr, info_ptr, &mwx_float, &mwy_float,
            &mrx_float, &mry_float, &mgx_float, &mgy_float,
            &mbx_float, &mby_float, &max_dl_float, &min_dl_float
        ) == PNG_INFO_mDCV && close_double(mwx_float, 0.17284, 0.000000001) &&
        close_double(mwy_float, 0.17926, 0.000000001) &&
        close_double(mrx_float, 0.36734, 0.000000001) &&
        close_double(mry_float, 0.13264, 0.000000001) &&
        close_double(mgx_float, 0.07980, 0.000000001) &&
        close_double(mgy_float, 0.42020, 0.000000001) &&
        close_double(mbx_float, 0.01830, 0.000000001) &&
        close_double(mby_float, 0.00004, 0.000000001) &&
        close_double(max_dl_float, 80.0, 0.0000001) &&
        close_double(min_dl_float, 1.0, 0.0000001);

    png_byte sentinel = 77u;
    ok = ok && png_get_cICP(
        png_ptr, info_ptr, &sentinel, NULL, &sentinel, &sentinel
    ) == 0u && sentinel == 77u;
    offset_x = 88;
    ok = ok && png_get_oFFs(
        png_ptr, info_ptr, &offset_x, NULL, &offset_unit
    ) == 0u && offset_x == 88 && png_get_cLLI_fixed(
        png_ptr, info_ptr, NULL, NULL
    ) == PNG_INFO_cLLI && png_get_mDCV_fixed(
        png_ptr, info_ptr, NULL, NULL, NULL, NULL, NULL, NULL,
        NULL, NULL, NULL, NULL
    ) == PNG_INFO_mDCV;

    return finish_decode(&png_ptr, &info_ptr, &allocation) && ok;
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

    double sentinel = 123.0;
    int absent_ok = png_get_gAMA(first, first_info, &sentinel) == 0u &&
        sentinel == 123.0;
    int spare_owner_ok = png_get_gAMA(first, spare_info, &sentinel) == 0u &&
        sentinel == 123.0;
    int wrong_owner_ok = png_get_gAMA(second, first_info, &sentinel) == 0u &&
        sentinel == 123.0;

    png_structp stale = second;
    png_infop stale_info = second_info;
    png_destroy_read_struct(&second, &second_info, NULL);
    int stale_ok = png_get_gAMA(stale, stale_info, &sentinel) == 0u &&
        sentinel == 123.0;
    int second_destroy_ok = second == NULL && second_info == NULL &&
        second_allocation.allocations == second_allocation.frees;
    png_destroy_read_struct(&first, &first_info, &spare_info);
    int first_destroy_ok = first == NULL && first_info == NULL &&
        spare_info == NULL &&
        first_allocation.allocations == first_allocation.frees;
    int ok = absent_ok && spare_owner_ok && wrong_owner_ok && stale_ok &&
        second_destroy_ok && first_destroy_ok;
    if (!ok) {
        fprintf(stderr,
            "lifecycle absent=%d spare-owner=%d wrong-owner=%d stale=%d "
            "second-destroy=%d second-alloc=%zu/%zu first-destroy=%d "
            "first-alloc=%zu/%zu\n",
            absent_ok, spare_owner_ok, wrong_owner_ok, stale_ok,
            second_destroy_ok, second_allocation.allocations,
            second_allocation.frees, first_destroy_ok,
            first_allocation.allocations, first_allocation.frees);
    }
    return ok;
}

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[2], "uint31-overflow") == 0) {
        return run_uint31_overflow(argv[1]);
    }
    if (argc != 4) {
        fprintf(stderr, "usage: %s DYLIB FIXED_PNG PLAIN_PNG\n", argv[0]);
        return 2;
    }
    size_t fixed_size = 0u, plain_size = 0u;
    unsigned char *fixed = read_file(argv[2], &fixed_size);
    unsigned char *plain = read_file(argv[3], &plain_size);
    if (fixed == NULL || plain == NULL) {
        free(fixed);
        free(plain);
        return 2;
    }

    max_align_t runtime_params[64];
    memset(runtime_params, 0, sizeof(runtime_params));
    int runtime_ok = InitCJRuntime(runtime_params) == 0;
    int load_ok = runtime_ok && LoadCJLibraryWithInit(argv[1]) == 0;
    int signature_ok = load_ok && signatures_are_exact();
    int stateless_ok = signature_ok && test_stateless_and_strings();
    int metadata_ok = stateless_ok && test_scalar_metadata(fixed, fixed_size);
    int lifecycle_ok = metadata_ok && test_absent_and_lifecycle(
        plain, plain_size, fixed, fixed_size
    );
    int ok = runtime_ok && load_ok && signature_ok && stateless_ok &&
        metadata_ok && lifecycle_ok;
    if (!ok) {
        fprintf(stderr,
            "stages runtime=%d load=%d signatures=%d stateless=%d "
            "metadata=%d lifecycle=%d\n",
            runtime_ok, load_ok, signature_ok, stateless_ok,
            metadata_ok, lifecycle_ok);
    }

    free(fixed);
    free(plain);
    if (FiniCJRuntime() != 0) ok = 0;
    if (!ok) return 4;
    printf("libpng4cj classic scalar metadata ABI: PASS\n");
    return 0;
}
