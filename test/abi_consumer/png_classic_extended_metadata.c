#include <png.h>

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int64_t InitCJRuntime(void *params);
extern int64_t LoadCJLibraryWithInit(const char *path);
extern int64_t FiniCJRuntime(void);

_Static_assert(sizeof(png_sPLT_entry) == 10u, "png_sPLT_entry size");
_Static_assert(offsetof(png_sPLT_entry, frequency) == 8u,
    "png_sPLT_entry frequency offset");
_Static_assert(sizeof(png_sPLT_t) == 32u, "png_sPLT_t size");
_Static_assert(offsetof(png_sPLT_t, name) == 0u, "png_sPLT_t name offset");
_Static_assert(offsetof(png_sPLT_t, depth) == 8u, "png_sPLT_t depth offset");
_Static_assert(offsetof(png_sPLT_t, entries) == 16u,
    "png_sPLT_t entries offset");
_Static_assert(offsetof(png_sPLT_t, nentries) == 24u,
    "png_sPLT_t nentries offset");
_Static_assert(sizeof(png_text) == 56u, "png_text size");
_Static_assert(offsetof(png_text, key) == 8u, "png_text key offset");
_Static_assert(offsetof(png_text, text) == 16u, "png_text text offset");
_Static_assert(offsetof(png_text, text_length) == 24u,
    "png_text text_length offset");
_Static_assert(offsetof(png_text, itxt_length) == 32u,
    "png_text itxt_length offset");
_Static_assert(offsetof(png_text, lang) == 40u, "png_text lang offset");
_Static_assert(offsetof(png_text, lang_key) == 48u,
    "png_text lang_key offset");
_Static_assert(sizeof(png_time) == 8u, "png_time size");
_Static_assert(offsetof(png_time, month) == 2u, "png_time month offset");
_Static_assert(offsetof(png_time, second) == 6u, "png_time second offset");
_Static_assert(sizeof(png_unknown_chunk) == 32u, "png_unknown_chunk size");
_Static_assert(offsetof(png_unknown_chunk, data) == 8u,
    "png_unknown_chunk data offset");
_Static_assert(offsetof(png_unknown_chunk, size) == 16u,
    "png_unknown_chunk size offset");
_Static_assert(offsetof(png_unknown_chunk, location) == 24u,
    "png_unknown_chunk location offset");

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

typedef struct diagnostic_context {
    int warning_count;
    char last_warning[128];
} diagnostic_context;

static void returning_error(png_structp png_ptr, png_const_charp message) {
    (void)png_ptr;
    (void)message;
}

static void fatal_scal_error(png_structp png_ptr, png_const_charp message) {
    (void)png_ptr;
    if (message != NULL &&
        strcmp(message, "fixed point overflow in sCAL height") == 0) {
        _Exit(75);
    }
    _Exit(76);
}

static void record_warning(png_structp png_ptr, png_const_charp message) {
    diagnostic_context *context = png_get_error_ptr(png_ptr);
    if (context == NULL) return;
    context->warning_count += 1;
    if (message == NULL) {
        context->last_warning[0] = '\0';
    } else {
        (void)snprintf(
            context->last_warning, sizeof(context->last_warning), "%s", message
        );
    }
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
    diagnostic_context *diagnostic,
    png_error_ptr error_fn,
    allocation_context *allocation,
    read_context *read,
    png_structp *png_out,
    png_infop *info_out
) {
    png_structp png_ptr = png_create_read_struct_2(
        PNG_LIBPNG_VER_STRING, diagnostic, error_fn, record_warning,
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

static int signatures_are_exact(void) {
    png_uint_32 (*xyz_fn)(png_const_structp, png_const_infop,
        double *, double *, double *, double *, double *, double *,
        double *, double *, double *) = png_get_cHRM_XYZ;
    png_uint_32 (*xyz_fixed_fn)(png_const_structp, png_const_infop,
        png_fixed_point *, png_fixed_point *, png_fixed_point *,
        png_fixed_point *, png_fixed_point *, png_fixed_point *,
        png_fixed_point *, png_fixed_point *, png_fixed_point *) =
        png_get_cHRM_XYZ_fixed;
    png_uint_32 (*exif_fn)(png_const_structp, png_infop, png_bytep *) =
        png_get_eXIf;
    png_uint_32 (*exif1_fn)(png_const_structp, png_const_infop,
        png_uint_32 *, png_bytep *) = png_get_eXIf_1;
    png_uint_32 (*hist_fn)(png_const_structp, png_infop, png_uint_16 **) =
        png_get_hIST;
    png_uint_32 (*iccp_fn)(png_const_structp, png_infop, png_charpp,
        int *, png_bytepp, png_uint_32 *) = png_get_iCCP;
    png_uint_32 (*pcal_fn)(png_const_structp, png_infop, png_charp *,
        png_int_32 *, png_int_32 *, int *, int *, png_charp *, png_charpp *) =
        png_get_pCAL;
    png_bytepp (*rows_fn)(png_const_structp, png_const_infop) = png_get_rows;
    png_uint_32 (*scal_fn)(png_const_structp, png_const_infop,
        int *, double *, double *) = png_get_sCAL;
    png_uint_32 (*scal_fixed_fn)(png_const_structp, png_const_infop,
        int *, png_fixed_point *, png_fixed_point *) = png_get_sCAL_fixed;
    png_uint_32 (*scal_s_fn)(png_const_structp, png_const_infop,
        int *, png_charpp, png_charpp) = png_get_sCAL_s;
    int (*splt_fn)(png_const_structp, png_infop, png_sPLT_tpp) = png_get_sPLT;
    png_uint_32 (*time_fn)(png_const_structp, png_infop, png_timep *) =
        png_get_tIME;
    int (*text_fn)(png_const_structp, png_infop, png_textp *, int *) =
        png_get_text;
    int (*unknown_fn)(png_const_structp, png_infop, png_unknown_chunkpp) =
        png_get_unknown_chunks;
    return xyz_fn != NULL && xyz_fixed_fn != NULL && exif_fn != NULL &&
        exif1_fn != NULL && hist_fn != NULL && iccp_fn != NULL &&
        pcal_fn != NULL && rows_fn != NULL && scal_fn != NULL &&
        scal_fixed_fn != NULL && scal_s_fn != NULL && splt_fn != NULL &&
        time_fn != NULL && text_fn != NULL && unknown_fn != NULL;
}

static int test_extended_metadata(
    const unsigned char *bytes, size_t size
) {
    allocation_context allocation = {0u, 0u};
    diagnostic_context diagnostic = {0, {0}};
    read_context read;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(
            bytes, size, &diagnostic, returning_error,
            &allocation, &read, &png_ptr, &info_ptr
        )) return 0;

    png_fixed_point fixed[9] = {0};
    double xyz[9] = {0.0};
    int ok = png_get_cHRM_XYZ_fixed(
        png_ptr, info_ptr,
        &fixed[0], &fixed[1], &fixed[2],
        &fixed[3], &fixed[4], &fixed[5],
        &fixed[6], &fixed[7], &fixed[8]
    ) == PNG_INFO_cHRM && fixed[0] == 41239 && fixed[1] == 21264 &&
        fixed[2] == 1933 && fixed[3] == 35759 && fixed[4] == 71517 &&
        fixed[5] == 11920 && fixed[6] == 18048 && fixed[7] == 7219 &&
        fixed[8] == 95053 && png_get_cHRM_XYZ(
            png_ptr, info_ptr,
            &xyz[0], &xyz[1], &xyz[2],
            &xyz[3], &xyz[4], &xyz[5],
            &xyz[6], &xyz[7], &xyz[8]
        ) == PNG_INFO_cHRM && close_double(xyz[0], 0.41239, 1e-12) &&
        close_double(xyz[1], 0.21264, 1e-12) &&
        close_double(xyz[2], 0.01933, 1e-12) &&
        close_double(xyz[3], 0.35759, 1e-12) &&
        close_double(xyz[4], 0.71517, 1e-12) &&
        close_double(xyz[5], 0.11920, 1e-12) &&
        close_double(xyz[6], 0.18048, 1e-12) &&
        close_double(xyz[7], 0.07219, 1e-12) &&
        close_double(xyz[8], 0.95053, 1e-12) &&
        png_get_cHRM_XYZ_fixed(
            png_ptr, info_ptr, NULL, NULL, NULL, NULL, NULL,
            NULL, NULL, NULL, NULL
        ) == PNG_INFO_cHRM;

    png_charp purpose = NULL, units = NULL;
    png_charpp parameters = NULL;
    png_int_32 x0 = -1, x1 = -1;
    int equation = -1, count = -1;
    ok = ok && png_get_pCAL(
        png_ptr, info_ptr, &purpose, &x0, &x1, &equation,
        &count, &units, &parameters
    ) == PNG_INFO_pCAL && purpose != NULL && units != NULL &&
        parameters != NULL && strcmp(purpose, "bogus units") == 0 &&
        x0 == 0 && x1 == 65535 && equation == 0 && count == 2 &&
        strcmp(units, "foo/bar") == 0 &&
        strcmp(parameters[0], "1.0e0") == 0 &&
        strcmp(parameters[1], "65.535e3") == 0;
    png_charp purpose_again = NULL, units_again = NULL;
    png_charpp parameters_again = NULL;
    ok = ok && png_get_pCAL(
        png_ptr, info_ptr, &purpose_again, &x0, &x1, &equation,
        &count, &units_again, &parameters_again
    ) == PNG_INFO_pCAL && purpose_again == purpose && units_again == units &&
        parameters_again == parameters && parameters_again[0] == parameters[0];

    int scale_unit = -1;
    png_charp width_text = NULL, height_text = NULL;
    double width = -1.0, height = -1.0;
    ok = ok && png_get_sCAL_s(
        png_ptr, info_ptr, &scale_unit, &width_text, &height_text
    ) == PNG_INFO_sCAL && scale_unit == PNG_SCALE_METER &&
        width_text != NULL && height_text != NULL &&
        strcmp(width_text, "23467E-92") == 0 &&
        strcmp(height_text, "31416E6") == 0 && png_get_sCAL(
            png_ptr, info_ptr, &scale_unit, &width, &height
        ) == PNG_INFO_sCAL && scale_unit == PNG_SCALE_METER &&
        width > 0.0 && width < 1e-87 &&
        close_double(height, 31416000000.0, 0.0001);
    png_charp width_again = NULL, height_again = NULL;
    ok = ok && png_get_sCAL_s(
        png_ptr, info_ptr, &scale_unit, &width_again, &height_again
    ) == PNG_INFO_sCAL && width_again == width_text &&
        height_again == height_text &&
        png_get_sCAL(png_ptr, info_ptr, NULL, &width, &height) == 0u &&
        png_get_sCAL_s(png_ptr, info_ptr, &scale_unit, NULL, &height_again) == 0u;

    png_timep modification = NULL, modification_again = NULL;
    ok = ok && png_get_tIME(
        png_ptr, info_ptr, &modification
    ) == PNG_INFO_tIME && modification != NULL &&
        modification->year == 1996u && modification->month == 6u &&
        modification->day == 7u && modification->hour == 17u &&
        modification->minute == 58u && modification->second == 8u &&
        png_get_tIME(png_ptr, info_ptr, &modification_again) == PNG_INFO_tIME &&
        modification_again == modification;

    png_textp text = NULL, text_again = NULL;
    int text_count = -1, text_count_again = -1;
    ok = ok && png_get_text(
        png_ptr, info_ptr, &text, &text_count
    ) == 1 && text_count == 1 && text != NULL &&
        text[0].compression == PNG_TEXT_COMPRESSION_NONE &&
        strcmp(text[0].key, "Title") == 0 &&
        strcmp(text[0].text, "PNG") == 0 && text[0].text_length == 3u &&
        text[0].itxt_length == 0u && text[0].lang == NULL &&
        text[0].lang_key == NULL && png_get_text(
            png_ptr, info_ptr, &text_again, &text_count_again
        ) == 1 && text_again == text && text_count_again == text_count;

    png_uint_32 exif_length = 77u;
    png_bytep exif = (png_bytep)(uintptr_t)1u;
    ok = ok && png_get_eXIf_1(
        png_ptr, info_ptr, &exif_length, &exif
    ) == 0u && exif_length == 77u && exif == (png_bytep)(uintptr_t)1u &&
        png_get_eXIf(png_ptr, info_ptr, &exif) == 0u &&
        exif == (png_bytep)(uintptr_t)1u && diagnostic.warning_count == 1 &&
        strcmp(diagnostic.last_warning,
            "png_get_eXIf does not work; use png_get_eXIf_1") == 0;

    png_uint_16 *histogram = (png_uint_16 *)(uintptr_t)1u;
    png_charp profile_name = (png_charp)(uintptr_t)1u;
    png_bytep profile = (png_bytep)(uintptr_t)1u;
    png_uint_32 profile_length = 99u;
    int compression = 99;
    png_sPLT_tp palettes = (png_sPLT_tp)(uintptr_t)1u;
    png_unknown_chunkp unknowns = (png_unknown_chunkp)(uintptr_t)1u;
    ok = ok && png_get_hIST(png_ptr, info_ptr, &histogram) == 0u &&
        histogram == (png_uint_16 *)(uintptr_t)1u && png_get_iCCP(
            png_ptr, info_ptr, &profile_name, &compression,
            &profile, &profile_length
        ) == 0u && profile_name == (png_charp)(uintptr_t)1u &&
        profile == (png_bytep)(uintptr_t)1u && profile_length == 99u &&
        compression == 99 && png_get_sPLT(
            png_ptr, info_ptr, &palettes
        ) == 0 && palettes == NULL && png_get_unknown_chunks(
            png_ptr, info_ptr, &unknowns
        ) == 0 && unknowns == NULL && png_get_rows(png_ptr, info_ptr) == NULL;

    if (!ok) {
        fprintf(stderr,
            "extended metadata mismatch warnings=%d text=%d/%d "
            "exif=%u/%u rows=%p alloc=%zu/%zu\n",
            diagnostic.warning_count, text_count, text_count_again,
            png_get_eXIf_1(png_ptr, info_ptr, &exif_length, &exif),
            exif_length, (void *)png_get_rows(png_ptr, info_ptr),
            allocation.allocations, allocation.frees);
    }
    return finish_decode(&png_ptr, &info_ptr, &allocation) && ok;
}

static int test_absent_and_lifecycle(
    const unsigned char *plain,
    size_t plain_size,
    const unsigned char *extended,
    size_t extended_size
) {
    allocation_context first_allocation = {0u, 0u};
    allocation_context second_allocation = {0u, 0u};
    diagnostic_context first_diagnostic = {0, {0}};
    diagnostic_context second_diagnostic = {0, {0}};
    read_context first_read, second_read;
    png_structp first = NULL, second = NULL;
    png_infop first_info = NULL, spare_info = NULL, second_info = NULL;
    if (!begin_decode(
            plain, plain_size, &first_diagnostic, returning_error,
            &first_allocation, &first_read, &first, &first_info
        )) return 0;
    spare_info = png_create_info_struct(first);
    if (!begin_decode(
            extended, extended_size, &second_diagnostic, returning_error,
            &second_allocation, &second_read, &second, &second_info
        ) || spare_info == NULL) {
        png_destroy_read_struct(&first, &first_info, &spare_info);
        png_destroy_read_struct(&second, &second_info, NULL);
        return 0;
    }

    png_charp purpose = (png_charp)(uintptr_t)1u;
    png_int_32 x0 = 91, x1 = 92;
    int equation = 93, count = 94;
    png_charp units = (png_charp)(uintptr_t)1u;
    png_charpp parameters = (png_charpp)(uintptr_t)1u;
    int absent_ok = png_get_pCAL(
        first, first_info, &purpose, &x0, &x1, &equation,
        &count, &units, &parameters
    ) == 0u && purpose == (png_charp)(uintptr_t)1u && x0 == 91 &&
        x1 == 92 && equation == 93 && count == 94;
    int spare_ok = png_get_pCAL(
        first, spare_info, &purpose, &x0, &x1, &equation,
        &count, &units, &parameters
    ) == 0u;
    int wrong_owner_ok = png_get_pCAL(
        second, first_info, &purpose, &x0, &x1, &equation,
        &count, &units, &parameters
    ) == 0u;
    int text_count = 99;
    int absent_text_ok = png_get_text(
        first, first_info, NULL, &text_count
    ) == 0 && text_count == 0;

    png_structp stale = second;
    png_infop stale_info = second_info;
    png_destroy_read_struct(&second, &second_info, NULL);
    int stale_ok = png_get_pCAL(
        stale, stale_info, &purpose, &x0, &x1, &equation,
        &count, &units, &parameters
    ) == 0u && png_get_rows(stale, stale_info) == NULL;
    int second_destroy_ok = second == NULL && second_info == NULL &&
        second_allocation.allocations == second_allocation.frees;
    png_destroy_read_struct(&first, &first_info, &spare_info);
    int first_destroy_ok = first == NULL && first_info == NULL &&
        spare_info == NULL &&
        first_allocation.allocations == first_allocation.frees;
    int ok = absent_ok && spare_ok && wrong_owner_ok && absent_text_ok &&
        stale_ok && second_destroy_ok && first_destroy_ok;
    if (!ok) {
        fprintf(stderr,
            "lifecycle absent=%d spare=%d wrong=%d text=%d stale=%d "
            "destroy=%d,%d alloc=%zu/%zu,%zu/%zu\n",
            absent_ok, spare_ok, wrong_owner_ok, absent_text_ok, stale_ok,
            first_destroy_ok, second_destroy_ok,
            first_allocation.allocations, first_allocation.frees,
            second_allocation.allocations, second_allocation.frees);
    }
    return ok;
}

static int run_scal_overflow(
    const char *dylib, const char *png_path
) {
    size_t size = 0u;
    unsigned char *bytes = read_file(png_path, &size);
    if (bytes == NULL) return 10;
    max_align_t runtime_params[64];
    memset(runtime_params, 0, sizeof(runtime_params));
    if (InitCJRuntime(runtime_params) != 0 ||
        LoadCJLibraryWithInit(dylib) != 0) return 11;
    allocation_context allocation = {0u, 0u};
    diagnostic_context diagnostic = {0, {0}};
    read_context read;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(
            bytes, size, &diagnostic, fatal_scal_error,
            &allocation, &read, &png_ptr, &info_ptr
        )) return 12;
    int unit = -1;
    png_fixed_point width = -1, height = -1;
    (void)png_get_sCAL_fixed(
        png_ptr, info_ptr, &unit, &width, &height
    );
    return 13;
}

int main(int argc, char **argv) {
    if (argc == 4 && strcmp(argv[2], "scal-overflow") == 0) {
        return run_scal_overflow(argv[1], argv[3]);
    }
    if (argc != 4) {
        fprintf(stderr, "usage: %s DYLIB PNGTEST_PNG PLAIN_PNG\n", argv[0]);
        return 2;
    }
    size_t extended_size = 0u, plain_size = 0u;
    unsigned char *extended = read_file(argv[2], &extended_size);
    unsigned char *plain = read_file(argv[3], &plain_size);
    if (extended == NULL || plain == NULL) {
        free(extended);
        free(plain);
        return 2;
    }

    max_align_t runtime_params[64];
    memset(runtime_params, 0, sizeof(runtime_params));
    int runtime_ok = InitCJRuntime(runtime_params) == 0;
    int load_ok = runtime_ok && LoadCJLibraryWithInit(argv[1]) == 0;
    int signature_ok = load_ok && signatures_are_exact();
    int metadata_ok = signature_ok && test_extended_metadata(
        extended, extended_size
    );
    int lifecycle_ok = metadata_ok && test_absent_and_lifecycle(
        plain, plain_size, extended, extended_size
    );
    free(extended);
    free(plain);
    int fini_ok = lifecycle_ok && FiniCJRuntime() == 0;
    int ok = runtime_ok && load_ok && signature_ok && metadata_ok &&
        lifecycle_ok && fini_ok;
    if (!ok) {
        fprintf(stderr,
            "stages runtime=%d load=%d signatures=%d metadata=%d "
            "lifecycle=%d fini=%d\n",
            runtime_ok, load_ok, signature_ok, metadata_ok,
            lifecycle_ok, fini_ok);
    }
    printf("libpng4cj classic extended metadata consumer: %s\n",
        ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
