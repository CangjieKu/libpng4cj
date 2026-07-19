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
    int mutate_limits;
    int mutated;
} read_context;

static void returning_error(png_structp png_ptr, png_const_charp message) {
    (void)png_ptr;
    (void)message;
}

static void expected_limit_error(
    png_structp png_ptr, png_const_charp message
) {
    int *expected = png_get_error_ptr(png_ptr);
    if (expected != NULL && *expected == 81 && message != NULL &&
        strcmp(message, "IHDR dimensions exceed configured limits") == 0) {
        _Exit(81);
    }
    if (expected != NULL && *expected == 82 && message != NULL &&
        strcmp(message, "PNG chunk exceeds configured memory limit") == 0) {
        _Exit(82);
    }
    _Exit(90);
}

static void read_memory(
    png_structp png_ptr, png_bytep output, size_t length
) {
    read_context *context = png_get_io_ptr(png_ptr);
    if (context == NULL || output == NULL ||
        context->offset > context->size ||
        length > context->size - context->offset) {
        if (context != NULL) context->ok = 0;
        png_error(png_ptr, "Read Error");
        return;
    }
    if (context->mutate_limits != 0 && context->mutated == 0) {
        png_set_user_limits(png_ptr, 1u, 1u);
        png_set_chunk_malloc_max(png_ptr, (png_alloc_size_t)1u);
        context->mutated = 1;
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
    void (*user_fn)(png_structp, png_uint_32, png_uint_32) =
        png_set_user_limits;
    void (*malloc_fn)(png_structp, png_alloc_size_t) =
        png_set_chunk_malloc_max;
    return user_fn != NULL && malloc_fn != NULL;
}

static int lifecycle_test(const unsigned char *bytes, size_t size) {
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (png_ptr == NULL || info_ptr == NULL) {
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }

    int defaults_ok = png_get_user_width_max(png_ptr) == 1000000u &&
        png_get_user_height_max(png_ptr) == 1000000u &&
        png_get_chunk_malloc_max(png_ptr) ==
            (png_alloc_size_t)8000000u;
    png_set_user_limits(png_ptr, 77u, 88u);
    png_set_chunk_malloc_max(png_ptr, (png_alloc_size_t)1234u);
    int replacement_ok = png_get_user_width_max(png_ptr) == 77u &&
        png_get_user_height_max(png_ptr) == 88u &&
        png_get_chunk_malloc_max(png_ptr) == (png_alloc_size_t)1234u;
    png_set_chunk_malloc_max(png_ptr, (png_alloc_size_t)0u);
    int unlimited_ok = png_get_chunk_malloc_max(png_ptr) ==
        (png_alloc_size_t)SIZE_MAX;

    png_set_user_limits(png_ptr, UINT32_MAX, UINT32_MAX);
    png_set_chunk_malloc_max(png_ptr, (png_alloc_size_t)8000000u);
    int maximum_ok = png_get_user_width_max(png_ptr) == UINT32_MAX &&
        png_get_user_height_max(png_ptr) == UINT32_MAX;
    read_context read = {bytes, size, 0u, 1, 1, 0};
    png_set_read_fn(png_ptr, &read, read_memory);
    png_read_info(png_ptr, info_ptr);
    int snapshot_ok = read.ok != 0 && read.offset == size &&
        read.mutated != 0 && png_get_image_width(png_ptr, info_ptr) == 32u &&
        png_get_image_height(png_ptr, info_ptr) == 32u &&
        png_get_user_width_max(png_ptr) == 1u &&
        png_get_user_height_max(png_ptr) == 1u &&
        png_get_chunk_malloc_max(png_ptr) == (png_alloc_size_t)1u;

    png_structp stale = png_ptr;
    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    png_set_user_limits(NULL, 1u, 1u);
    png_set_chunk_malloc_max(NULL, (png_alloc_size_t)1u);
    png_set_user_limits(stale, 2u, 3u);
    png_set_chunk_malloc_max(stale, (png_alloc_size_t)4u);
    int stale_ok = png_ptr == NULL && info_ptr == NULL &&
        png_get_user_width_max(stale) == 0u &&
        png_get_user_height_max(stale) == 0u &&
        png_get_chunk_malloc_max(stale) == (png_alloc_size_t)0u;
    if (!(defaults_ok && replacement_ok && unlimited_ok && maximum_ok &&
        snapshot_ok && stale_ok)) {
        fprintf(stderr,
            "owner limit mismatch defaults=%d replacement=%d unlimited=%d "
            "maximum=%d snapshot=%d stale=%d offset=%zu/%zu\n",
            defaults_ok, replacement_ok, unlimited_ok, maximum_ok,
            snapshot_ok, stale_ok, read.offset, size);
    }
    return defaults_ok && replacement_ok && unlimited_ok && maximum_ok &&
        snapshot_ok && stale_ok;
}

static int run_limit_failure(
    const char *dylib,
    const char *mode,
    const unsigned char *bytes,
    size_t size
) {
    runtime_params_storage params;
    memset(&params, 0, sizeof(params));
    if (InitCJRuntime(&params) != 0) return 10;
    if (LoadCJLibraryWithInit(dylib) != 0) {
        (void)FiniCJRuntime();
        return 10;
    }
    int expected = strcmp(mode, "dimension-limit") == 0 ? 81 : 82;
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, &expected, expected_limit_error, NULL
    );
    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (png_ptr == NULL || info_ptr == NULL) {
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        (void)FiniCJRuntime();
        return 11;
    }
    read_context read = {bytes, size, 0u, 1, 0, 0};
    png_set_read_fn(png_ptr, &read, read_memory);
    if (expected == 81) {
        png_set_user_limits(png_ptr, 31u, 32u);
    } else {
        png_set_chunk_malloc_max(png_ptr, (png_alloc_size_t)12u);
    }
    png_read_info(png_ptr, info_ptr);
    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    (void)FiniCJRuntime();
    return 12;
}

int main(int argc, char **argv) {
    if (argc == 4) {
        size_t size = 0u;
        unsigned char *bytes = read_file(argv[3], &size);
        if (bytes == NULL) return 2;
        int result = run_limit_failure(argv[1], argv[2], bytes, size);
        free(bytes);
        return result;
    }
    if (argc != 3) {
        fprintf(stderr, "usage: %s DYLIB [MODE] PNG\n", argv[0]);
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
    int fini_ok = runtime_ok && FiniCJRuntime() == 0;
    int ok = runtime_ok && load_ok && signature_ok && lifecycle_ok && fini_ok;
    printf("libpng4cj classic owner read limits consumer: %s\n",
        ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
