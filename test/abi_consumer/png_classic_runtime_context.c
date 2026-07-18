#include "png.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int InitCJRuntime(void *params);
extern int LoadCJLibraryWithInit(const char *path);
extern int FiniCJRuntime(void);

typedef union runtime_params_storage {
    max_align_t alignment;
    unsigned char bytes[4096];
} runtime_params_storage;

typedef struct read_context {
    const unsigned char *bytes;
    size_t size;
    size_t offset;
    int ok;
} read_context;

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
    png_uint_32 (*cache_fn)(png_const_structp) = png_get_chunk_cache_max;
    png_alloc_size_t (*malloc_fn)(png_const_structp) =
        png_get_chunk_malloc_max;
    size_t (*buffer_fn)(png_const_structp) =
        png_get_compression_buffer_size;
    png_byte (*pass_fn)(png_const_structp) = png_get_current_pass_number;
    png_uint_32 (*row_fn)(png_const_structp) = png_get_current_row_number;
    png_uint_32 (*chunk_fn)(png_const_structp) = png_get_io_chunk_type;
    png_uint_32 (*state_fn)(png_const_structp) = png_get_io_state;
    int (*palette_fn)(png_const_structp, png_const_infop) =
        png_get_palette_max;
    png_voidp (*progressive_fn)(png_const_structp) =
        png_get_progressive_ptr;
    png_byte (*gray_fn)(png_const_structp) = png_get_rgb_to_gray_status;
    png_voidp (*chunk_ptr_fn)(png_const_structp) = png_get_user_chunk_ptr;
    png_uint_32 (*height_fn)(png_const_structp) = png_get_user_height_max;
    png_voidp (*transform_fn)(png_const_structp) =
        png_get_user_transform_ptr;
    png_uint_32 (*width_fn)(png_const_structp) = png_get_user_width_max;
    return cache_fn != NULL && malloc_fn != NULL && buffer_fn != NULL &&
        pass_fn != NULL && row_fn != NULL && chunk_fn != NULL &&
        state_fn != NULL && palette_fn != NULL && progressive_fn != NULL &&
        gray_fn != NULL && chunk_ptr_fn != NULL && height_fn != NULL &&
        transform_fn != NULL && width_fn != NULL;
}

static int fresh_defaults(png_structp png_ptr, png_infop info_ptr) {
    return png_get_chunk_cache_max(png_ptr) == 1000u &&
        png_get_chunk_malloc_max(png_ptr) == (png_alloc_size_t)8000000u &&
        png_get_compression_buffer_size(png_ptr) == (size_t)8192u &&
        png_get_current_pass_number(png_ptr) == 0u &&
        png_get_current_row_number(png_ptr) == 0u &&
        png_get_io_chunk_type(png_ptr) == 0u &&
        png_get_io_state(png_ptr) == PNG_IO_NONE &&
        png_get_palette_max(png_ptr, info_ptr) == 0 &&
        png_get_progressive_ptr(png_ptr) == NULL &&
        png_get_rgb_to_gray_status(png_ptr) == 0u &&
        png_get_user_chunk_ptr(png_ptr) == NULL &&
        png_get_user_height_max(png_ptr) == 1000000u &&
        png_get_user_transform_ptr(png_ptr) == NULL &&
        png_get_user_width_max(png_ptr) == 1000000u;
}

static int lifecycle_test(const unsigned char *bytes, size_t size) {
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    png_infop info_ptr = png_create_info_struct(png_ptr);
    png_infop spare_info = png_create_info_struct(png_ptr);
    png_structp other_png = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    png_infop other_info = png_create_info_struct(other_png);
    if (png_ptr == NULL || info_ptr == NULL || spare_info == NULL ||
        other_png == NULL || other_info == NULL) {
        png_destroy_read_struct(&png_ptr, &info_ptr, &spare_info);
        png_destroy_read_struct(&other_png, &other_info, NULL);
        return 0;
    }

    int defaults_ok = fresh_defaults(png_ptr, info_ptr) &&
        fresh_defaults(other_png, other_info) &&
        png_get_palette_max(png_ptr, NULL) == -1 &&
        png_get_palette_max(png_ptr, other_info) == -1 &&
        png_get_palette_max(other_png, info_ptr) == -1;
    read_context read = {bytes, size, 0u, 1};
    png_set_read_fn(png_ptr, &read, read_memory);
    png_read_info(png_ptr, info_ptr);
    size_t row_bytes = png_get_rowbytes(png_ptr, info_ptr);
    unsigned char *row = malloc(row_bytes == 0u ? 1u : row_bytes);
    if (row == NULL) {
        png_destroy_read_struct(&png_ptr, &info_ptr, &spare_info);
        png_destroy_read_struct(&other_png, &other_info, NULL);
        return 0;
    }
    int pre_row_ok = read.ok != 0 && read.offset == size &&
        png_get_current_row_number(png_ptr) == 0u &&
        png_get_current_pass_number(png_ptr) == 0u &&
        png_get_io_state(png_ptr) == PNG_IO_NONE &&
        png_get_io_chunk_type(png_ptr) == 0u &&
        png_get_palette_max(png_ptr, spare_info) == 0;
    png_read_row(png_ptr, row, NULL);
    int row_ok = png_get_current_row_number(png_ptr) == 1u &&
        png_get_current_pass_number(png_ptr) == 0u;
    free(row);

    png_structp stale = png_ptr;
    png_infop stale_info = info_ptr;
    png_destroy_read_struct(&png_ptr, &info_ptr, &spare_info);
    png_destroy_read_struct(&other_png, &other_info, NULL);
    int destroy_ok = png_ptr == NULL && info_ptr == NULL &&
        spare_info == NULL && other_png == NULL && other_info == NULL;
    int stale_ok = png_get_chunk_cache_max(stale) == 0u &&
        png_get_chunk_malloc_max(stale) == 0u &&
        png_get_compression_buffer_size(stale) == 0u &&
        png_get_current_pass_number(stale) == 8u &&
        png_get_current_row_number(stale) == UINT32_MAX &&
        png_get_io_chunk_type(stale) == 0u &&
        png_get_io_state(stale) == 0u &&
        png_get_palette_max(stale, stale_info) == -1 &&
        png_get_progressive_ptr(stale) == NULL &&
        png_get_rgb_to_gray_status(stale) == 0u &&
        png_get_user_chunk_ptr(stale) == NULL &&
        png_get_user_height_max(stale) == 0u &&
        png_get_user_transform_ptr(stale) == NULL &&
        png_get_user_width_max(stale) == 0u;
    if (!(defaults_ok && pre_row_ok && row_ok && destroy_ok && stale_ok)) {
        fprintf(stderr,
            "runtime getter mismatch defaults=%d pre=%d row=%d "
            "destroy=%d stale=%d rowbytes=%zu offset=%zu/%zu\n",
            defaults_ok, pre_row_ok, row_ok, destroy_ok, stale_ok,
            row_bytes, read.offset, size);
    }
    return defaults_ok && pre_row_ok && row_ok && destroy_ok && stale_ok;
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: %s DYLIB PNG\n", argv[0]);
        return 2;
    }
    size_t size = 0u;
    unsigned char *bytes = read_file(argv[2], &size);
    if (bytes == NULL) return 2;
    runtime_params_storage params;
    memset(&params, 0, sizeof(params));
    int runtime_ok = InitCJRuntime(&params) == 0;
    int load_ok = runtime_ok && LoadCJLibraryWithInit(argv[1]) == 0;
    int signature_ok = load_ok && signatures_are_exact();
    int lifecycle_ok = signature_ok && lifecycle_test(bytes, size);
    free(bytes);
    int null_ok = lifecycle_ok &&
        png_get_current_row_number(NULL) == UINT32_MAX &&
        png_get_current_pass_number(NULL) == 8u &&
        png_get_palette_max(NULL, NULL) == -1;
    int fini_ok = null_ok && FiniCJRuntime() == 0;
    int ok = runtime_ok && load_ok && signature_ok && lifecycle_ok &&
        null_ok && fini_ok;
    if (!ok) {
        fprintf(stderr,
            "stages runtime=%d load=%d signatures=%d lifecycle=%d "
            "null=%d fini=%d\n",
            runtime_ok, load_ok, signature_ok, lifecycle_ok, null_ok, fini_ok);
    }
    printf("libpng4cj classic runtime/context consumer: %s\n",
        ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
