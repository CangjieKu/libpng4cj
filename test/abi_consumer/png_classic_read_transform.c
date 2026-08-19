#include "png.h"

#include <stddef.h>
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

static int begin_decode(
    const unsigned char *bytes,
    size_t size,
    read_context *context,
    png_structp *png_out,
    png_infop *info_out
) {
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (png_ptr == NULL || info_ptr == NULL) {
        if (png_ptr != NULL) png_destroy_read_struct(&png_ptr, NULL, NULL);
        return 0;
    }
    context->bytes = bytes;
    context->size = size;
    context->offset = 0u;
    context->ok = 1;
    png_set_read_fn(png_ptr, context, read_memory);
    png_read_info(png_ptr, info_ptr);
    if (context->ok == 0 || context->offset != size) {
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }
    *png_out = png_ptr;
    *info_out = info_ptr;
    return 1;
}

static int consume_rows(
    png_structp png_ptr, png_infop info_ptr, size_t expected_rowbytes
) {
    png_uint_32 height = png_get_image_height(png_ptr, info_ptr);
    size_t rowbytes = png_get_rowbytes(png_ptr, info_ptr);
    if (height != 32u || rowbytes != expected_rowbytes ||
        height > SIZE_MAX / rowbytes) return 0;
    png_bytep storage = calloc((size_t)height, rowbytes);
    png_bytepp rows = calloc((size_t)height, sizeof(*rows));
    if (storage == NULL || rows == NULL) {
        free(storage);
        free(rows);
        return 0;
    }
    for (png_uint_32 i = 0u; i < height; ++i) {
        rows[i] = storage + (size_t)i * rowbytes;
    }
    png_read_image(png_ptr, rows);
    int nonzero = 0;
    for (size_t i = 0u; i < (size_t)height * rowbytes; ++i) {
        if (storage[i] != 0u) {
            nonzero = 1;
            break;
        }
    }
    png_read_end(png_ptr, info_ptr);
    free(rows);
    free(storage);
    return nonzero;
}

static int test_palette_expand(const unsigned char *bytes, size_t size) {
    read_context context;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(bytes, size, &context, &png_ptr, &info_ptr)) return 0;
    int ok = png_get_bit_depth(png_ptr, info_ptr) == 4u &&
        png_get_color_type(png_ptr, info_ptr) == 3u &&
        png_get_rowbytes(png_ptr, info_ptr) == 16u;
    png_set_palette_to_rgb(png_ptr);
    png_read_update_info(png_ptr, info_ptr);
    ok = ok && png_get_bit_depth(png_ptr, info_ptr) == 8u &&
        png_get_color_type(png_ptr, info_ptr) == 2u &&
        png_get_channels(png_ptr, info_ptr) == 3u &&
        consume_rows(png_ptr, info_ptr, 96u);
    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    return ok && png_ptr == NULL && info_ptr == NULL;
}

static int test_gray_expand(const unsigned char *bytes, size_t size) {
    read_context context;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(bytes, size, &context, &png_ptr, &info_ptr)) return 0;
    png_set_expand_gray_1_2_4_to_8(png_ptr);
    png_start_read_image(png_ptr);
    int ok = png_get_bit_depth(png_ptr, info_ptr) == 8u &&
        png_get_color_type(png_ptr, info_ptr) == 0u &&
        png_get_channels(png_ptr, info_ptr) == 1u &&
        consume_rows(png_ptr, info_ptr, 32u);
    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    return ok;
}

static int test_strip_16_alpha(const unsigned char *bytes, size_t size) {
    read_context context;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(bytes, size, &context, &png_ptr, &info_ptr)) return 0;
    png_set_strip_16(png_ptr);
    png_set_strip_alpha(png_ptr);
    png_read_update_info(png_ptr, info_ptr);
    int ok = png_get_bit_depth(png_ptr, info_ptr) == 8u &&
        png_get_color_type(png_ptr, info_ptr) == 0u &&
        png_get_channels(png_ptr, info_ptr) == 1u &&
        consume_rows(png_ptr, info_ptr, 32u);
    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    return ok;
}

static int test_rgb_to_gray(const unsigned char *bytes, size_t size) {
    read_context context;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(bytes, size, &context, &png_ptr, &info_ptr)) return 0;
    png_set_rgb_to_gray_fixed(
        png_ptr, PNG_ERROR_ACTION_WARN,
        PNG_RGB_TO_GRAY_DEFAULT, PNG_RGB_TO_GRAY_DEFAULT
    );
    png_read_update_info(png_ptr, info_ptr);
    int ok = png_get_bit_depth(png_ptr, info_ptr) == 8u &&
        png_get_color_type(png_ptr, info_ptr) == 0u &&
        png_get_channels(png_ptr, info_ptr) == 1u &&
        consume_rows(png_ptr, info_ptr, 32u);
    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    return ok;
}

static int signatures_are_exact(void) {
    void (*expand_fn)(png_structp) = png_set_expand;
    void (*palette_fn)(png_structp) = png_set_palette_to_rgb;
    void (*gray_fn)(png_structp) = png_set_gray_to_rgb;
    void (*update_fn)(png_structp, png_infop) = png_read_update_info;
    void (*start_fn)(png_structp) = png_start_read_image;
    return expand_fn != NULL && palette_fn != NULL && gray_fn != NULL &&
        update_fn != NULL && start_fn != NULL;
}

int main(int argc, char **argv) {
    if (argc != 6) {
        fprintf(
            stderr,
            "usage: %s DYLIB PALETTE GRAY1 GRAY_ALPHA16 RGB8\n",
            argv[0]
        );
        return 2;
    }
    size_t sizes[4] = {0u, 0u, 0u, 0u};
    unsigned char *inputs[4] = {
        read_file(argv[2], &sizes[0]),
        read_file(argv[3], &sizes[1]),
        read_file(argv[4], &sizes[2]),
        read_file(argv[5], &sizes[3])
    };
    if (inputs[0] == NULL || inputs[1] == NULL ||
        inputs[2] == NULL || inputs[3] == NULL) {
        for (int i = 0; i < 4; ++i) free(inputs[i]);
        return 2;
    }

    runtime_params_storage runtime_params;
    memset(&runtime_params, 0, sizeof(runtime_params));
    int ok = InitCJRuntime(runtime_params.bytes) == 0 &&
        LoadCJLibraryWithInit(argv[1]) == 0 && signatures_are_exact() &&
        test_palette_expand(inputs[0], sizes[0]) &&
        test_gray_expand(inputs[1], sizes[1]) &&
        test_strip_16_alpha(inputs[2], sizes[2]) &&
        test_rgb_to_gray(inputs[3], sizes[3]);

    png_set_expand(NULL);
    png_read_update_info(NULL, NULL);
    for (int i = 0; i < 4; ++i) free(inputs[i]);
    if (FiniCJRuntime() != 0) ok = 0;
    if (!ok) return 4;
    printf("libpng4cj classic read-transform ABI: PASS\n");
    return 0;
}
