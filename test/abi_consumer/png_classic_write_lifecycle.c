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

typedef struct memory_output {
    unsigned char *bytes;
    size_t capacity;
    size_t size;
    int flushes;
    int ok;
} memory_output;

typedef struct memory_input {
    const unsigned char *bytes;
    size_t size;
    size_t offset;
    int ok;
} memory_input;

static void returning_error(png_structp png_ptr, png_const_charp message) {
    (void)png_ptr;
    (void)message;
}

static void write_memory(
    png_structp png_ptr, png_bytep data, size_t length
) {
    memory_output *output = (memory_output *)png_get_io_ptr(png_ptr);
    if (output == NULL || data == NULL || length > output->capacity - output->size) {
        if (output != NULL) output->ok = 0;
        png_error(png_ptr, "write lifecycle output overflow");
        return;
    }
    memcpy(output->bytes + output->size, data, length);
    output->size += length;
}

static void flush_memory(png_structp png_ptr) {
    memory_output *output = (memory_output *)png_get_io_ptr(png_ptr);
    if (output == NULL) {
        png_error(png_ptr, "write lifecycle flush without output");
        return;
    }
    ++output->flushes;
}

static void read_memory(
    png_structp png_ptr, png_bytep data, size_t length
) {
    memory_input *input = (memory_input *)png_get_io_ptr(png_ptr);
    if (input == NULL || data == NULL || length > input->size - input->offset) {
        if (input != NULL) input->ok = 0;
        png_error(png_ptr, "read lifecycle input underflow");
        return;
    }
    memcpy(data, input->bytes + input->offset, length);
    input->offset += length;
}

static int encode_indexed(
    unsigned char *bytes,
    size_t capacity,
    int mode,
    int compression_level,
    size_t *size_out
) {
    static const png_byte palette_bytes[6] = {
        20u, 40u, 60u, 220u, 180u, 40u
    };
    static const png_byte row0[2] = {0u, 1u};
    static const png_byte row1[2] = {1u, 0u};
    png_byte *rows[2] = {(png_byte *)row0, (png_byte *)row1};
    memory_output output = {bytes, capacity, 0u, 0, 1};
    png_structp png_ptr = png_create_write_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (png_ptr == NULL || info_ptr == NULL) {
        png_destroy_write_struct(&png_ptr, &info_ptr);
        return 0;
    }
    png_set_write_fn(png_ptr, &output, write_memory, flush_memory);
    png_set_compression_level(png_ptr, compression_level);
    png_set_compression_mem_level(png_ptr, 8);
    png_set_compression_window_bits(png_ptr, 15);
    png_set_compression_method(png_ptr, 8);
    png_set_compression_strategy(png_ptr, 0);
    png_set_compression_buffer_size(png_ptr, 32768u);
    png_set_filter(png_ptr, 0, 0x08);
    png_set_IHDR(
        png_ptr, info_ptr, 2u, 2u, 8, PNG_COLOR_TYPE_PALETTE,
        PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE
    );
    png_color palette[2] = {
        {palette_bytes[0], palette_bytes[1], palette_bytes[2]},
        {palette_bytes[3], palette_bytes[4], palette_bytes[5]}
    };
    png_set_PLTE(png_ptr, info_ptr, palette, 2);
    png_write_info(png_ptr, info_ptr);
    if (mode == 0) {
        png_write_rows(png_ptr, rows, 2u);
    } else if (mode == 1) {
        png_write_row(png_ptr, row0);
        png_write_row(png_ptr, row1);
    } else {
        png_write_image(png_ptr, rows);
    }
    png_write_end(png_ptr, info_ptr);
    int ok = output.ok != 0 && output.size > 0u && output.flushes > 0;
    if (ok) *size_out = output.size;
    png_destroy_write_struct(&png_ptr, &info_ptr);
    return ok && png_ptr == NULL && info_ptr == NULL;
}

static int verify_indexed(
    const unsigned char *bytes, size_t size
) {
    memory_input input = {bytes, size, 0u, 1};
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (png_ptr == NULL || info_ptr == NULL) {
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }
    png_set_read_fn(png_ptr, &input, read_memory);
    png_read_info(png_ptr, info_ptr);
    size_t rowbytes = png_get_rowbytes(png_ptr, info_ptr);
    png_byte rows_storage[4] = {0u, 0u, 0u, 0u};
    png_byte *rows[2] = {rows_storage, rows_storage + 2};
    png_read_image(png_ptr, rows);
    png_read_end(png_ptr, info_ptr);
    int ok = input.ok != 0 && input.offset == size &&
        png_get_image_width(png_ptr, info_ptr) == 2u &&
        png_get_image_height(png_ptr, info_ptr) == 2u &&
        png_get_color_type(png_ptr, info_ptr) == PNG_COLOR_TYPE_PALETTE &&
        rowbytes == 2u && memcmp(rows_storage, "\0\1\1\0", 4u) == 0;
    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    return ok && png_ptr == NULL && info_ptr == NULL;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s DYLIB\n", argv[0]);
        return 2;
    }
    runtime_params_storage params;
    memset(&params, 0, sizeof(params));
    if (InitCJRuntime(&params) != 0 || LoadCJLibraryWithInit(argv[1]) != 0) {
        return 10;
    }
    unsigned char first[65536];
    unsigned char second[65536];
    size_t first_size = 0u;
    size_t second_size = 0u;
    int rows_ok = encode_indexed(first, sizeof(first), 0, 0, &first_size);
    int row_ok = encode_indexed(second, sizeof(second), 1, 9, &second_size);
    int image_ok = verify_indexed(first, first_size) &&
        verify_indexed(second, second_size);
    int controls_observable = first_size != second_size ||
        memcmp(first, second, first_size < second_size ? first_size : second_size) != 0;
    int fini_ok = FiniCJRuntime() == 0;
    int ok = rows_ok && row_ok && image_ok && controls_observable && fini_ok;
    printf("libpng4cj classic write lifecycle consumer: %s\n",
        ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
