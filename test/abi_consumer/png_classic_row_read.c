#include <libpng4cj_preview.h>
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
    void (*row_fn)(png_structp, png_bytep, png_bytep) = png_read_row;
    void (*rows_fn)(png_structp, png_bytepp, png_bytepp, png_uint_32) =
        png_read_rows;
    void (*image_fn)(png_structp, png_bytepp) = png_read_image;
    void (*end_fn)(png_structp, png_infop) = png_read_end;
    return row_fn != NULL && rows_fn != NULL && image_fn != NULL &&
        end_fn != NULL;
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

static png_bytepp allocate_rows(
    png_uint_32 height, size_t rowbytes, png_bytep *storage_out
) {
    if (height == 0u || rowbytes == 0u ||
        (size_t)height > SIZE_MAX / rowbytes) return NULL;
    png_bytep storage = calloc((size_t)height, rowbytes);
    png_bytepp rows = calloc((size_t)height, sizeof(*rows));
    if (storage == NULL || rows == NULL) {
        free(storage);
        free(rows);
        return NULL;
    }
    for (png_uint_32 i = 0u; i < height; ++i) {
        rows[i] = storage + (size_t)i * rowbytes;
    }
    *storage_out = storage;
    return rows;
}

static int read_complete_image(
    const unsigned char *bytes,
    size_t size,
    png_bytep *storage_out,
    png_uint_32 *width_out,
    png_uint_32 *height_out,
    size_t *rowbytes_out
) {
    read_context context;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(bytes, size, &context, &png_ptr, &info_ptr)) return 0;
    png_uint_32 width = png_get_image_width(png_ptr, info_ptr);
    png_uint_32 height = png_get_image_height(png_ptr, info_ptr);
    size_t rowbytes = png_get_rowbytes(png_ptr, info_ptr);
    png_bytep storage = NULL;
    png_bytepp rows = allocate_rows(height, rowbytes, &storage);
    if (rows == NULL) {
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }
    png_read_image(png_ptr, rows);
    png_read_end(png_ptr, info_ptr);
    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    free(rows);
    *storage_out = storage;
    *width_out = width;
    *height_out = height;
    *rowbytes_out = rowbytes;
    return png_ptr == NULL && info_ptr == NULL;
}

static int test_gray_row_forms(
    const unsigned char *bytes, size_t size
) {
    png_bytep expected = NULL;
    png_uint_32 width = 0u;
    png_uint_32 height = 0u;
    size_t rowbytes = 0u;
    if (!read_complete_image(
            bytes, size, &expected, &width, &height, &rowbytes
        ) || width != 32u || height != 32u || rowbytes != 4u) {
        free(expected);
        return 0;
    }

    read_context context;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    png_infop end_info = NULL;
    if (!begin_decode(bytes, size, &context, &png_ptr, &info_ptr)) {
        free(expected);
        return 0;
    }
    end_info = png_create_info_struct(png_ptr);
    if (end_info == NULL) {
        free(expected);
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }

    unsigned char row0[4] = {0};
    unsigned char display0[4] = {0};
    png_read_row(png_ptr, row0, display0);
    int ok = memcmp(row0, expected, rowbytes) == 0 &&
        memcmp(display0, expected, rowbytes) == 0;

    unsigned char row1[4] = {0};
    unsigned char row2[4] = {0};
    png_bytep two_rows[2] = {row1, row2};
    png_read_rows(png_ptr, two_rows, NULL, 2u);
    ok = ok && memcmp(row1, expected + rowbytes, rowbytes) == 0 &&
        memcmp(row2, expected + 2u * rowbytes, rowbytes) == 0;

    png_read_rows(png_ptr, NULL, NULL, 5u);
    unsigned char row3[4] = {0};
    png_read_row(png_ptr, row3, NULL);
    ok = ok && memcmp(row3, expected + 3u * rowbytes, rowbytes) == 0;

    png_read_row(png_ptr, NULL, NULL);
    unsigned char display5[4] = {0};
    png_read_row(png_ptr, NULL, display5);
    ok = ok && memcmp(display5, expected + 5u * rowbytes, rowbytes) == 0;

    png_uint_32 remaining = height - 6u;
    png_bytep remaining_storage = NULL;
    png_bytepp remaining_rows = allocate_rows(
        remaining, rowbytes, &remaining_storage
    );
    if (remaining_rows == NULL) ok = 0;
    if (remaining_rows != NULL) {
        png_read_rows(png_ptr, remaining_rows, NULL, remaining);
        ok = ok && memcmp(
            remaining_storage, expected + 6u * rowbytes,
            (size_t)remaining * rowbytes
        ) == 0;
    }
    png_read_end(png_ptr, end_info);

    png_structp stale_png = png_ptr;
    png_destroy_read_struct(&png_ptr, &info_ptr, &end_info);
    unsigned char sentinel[4] = {9u, 8u, 7u, 6u};
    png_read_row(stale_png, sentinel, NULL);
    png_read_end(stale_png, NULL);
    ok = ok && png_ptr == NULL && info_ptr == NULL && end_info == NULL &&
        sentinel[0] == 9u && sentinel[1] == 8u &&
        sentinel[2] == 7u && sentinel[3] == 6u;

    free(remaining_rows);
    free(remaining_storage);
    free(expected);
    return ok;
}

static int test_adam7_image(
    const unsigned char *bytes, size_t size
) {
    png_bytep raw = NULL;
    png_uint_32 width = 0u;
    png_uint_32 height = 0u;
    size_t rowbytes = 0u;
    if (!read_complete_image(
            bytes, size, &raw, &width, &height, &rowbytes
        ) || width != 32u || height != 32u || rowbytes != 128u) {
        free(raw);
        return 0;
    }

    size_t required = 0u;
    size_t stride = 0u;
    uint32_t preview_width = 0u;
    uint32_t preview_height = 0u;
    int32_t error_kind = -1;
    int64_t error_offset = -1;
    uint8_t message[128] = {0};
    png4cj_status status = png4cj_decode_rgba8(
        bytes, size, NULL, 0u, &preview_width, &preview_height, &stride,
        &required, &error_kind, &error_offset, message, sizeof(message)
    );
    if (status != PNG4CJ_STATUS_BUFFER_TOO_SMALL ||
        required != (size_t)height * rowbytes || stride != rowbytes) {
        free(raw);
        return 0;
    }
    unsigned char *expected = malloc(required);
    if (expected == NULL) {
        free(raw);
        return 0;
    }
    status = png4cj_decode_rgba8(
        bytes, size, expected, required, &preview_width, &preview_height,
        &stride, &required, &error_kind, &error_offset, message,
        sizeof(message)
    );
    int ok = status == PNG4CJ_STATUS_OK && preview_width == width &&
        preview_height == height && stride == rowbytes &&
        memcmp(raw, expected, required) == 0;
    free(expected);
    free(raw);
    return ok;
}

static int test_read_end_drains(
    const unsigned char *bytes, size_t size
) {
    read_context context;
    png_structp png_ptr = NULL;
    png_infop info_ptr = NULL;
    if (!begin_decode(bytes, size, &context, &png_ptr, &info_ptr)) return 0;
    size_t rowbytes = png_get_rowbytes(png_ptr, info_ptr);
    unsigned char *first = calloc(1u, rowbytes);
    if (first == NULL) {
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }
    png_read_row(png_ptr, first, NULL);
    png_read_end(png_ptr, NULL);
    png_read_end(png_ptr, info_ptr);
    free(first);
    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    return png_ptr == NULL && info_ptr == NULL;
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "usage: %s DYLIB GRAY_PNG ADAM7_RGBA_PNG\n", argv[0]);
        return 2;
    }
    size_t gray_size = 0u;
    size_t adam7_size = 0u;
    unsigned char *gray = read_file(argv[2], &gray_size);
    unsigned char *adam7 = read_file(argv[3], &adam7_size);
    if (gray == NULL || adam7 == NULL) {
        free(gray);
        free(adam7);
        return 2;
    }

    max_align_t runtime_params[64];
    memset(runtime_params, 0, sizeof(runtime_params));
    unsigned char unknown_row[4] = {1u, 2u, 3u, 4u};
    int ok = InitCJRuntime(runtime_params) == 0 &&
        LoadCJLibraryWithInit(argv[1]) == 0 && signatures_are_exact();
    png_read_row(NULL, unknown_row, NULL);
    png_read_rows(NULL, NULL, NULL, 1u);
    png_read_image(NULL, NULL);
    png_read_end(NULL, NULL);
    png_read_row((png_structp)(uintptr_t)1u, unknown_row, NULL);
    png_read_end((png_structp)(uintptr_t)1u, NULL);
    ok = ok && unknown_row[0] == 1u && unknown_row[1] == 2u &&
        unknown_row[2] == 3u && unknown_row[3] == 4u &&
        test_gray_row_forms(gray, gray_size) &&
        test_adam7_image(adam7, adam7_size) &&
        test_read_end_drains(gray, gray_size);

    free(gray);
    free(adam7);
    if (FiniCJRuntime() != 0) ok = 0;
    if (!ok) return 4;
    printf("libpng4cj classic row/read-end ABI: PASS\n");
    return 0;
}
