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

static void read_memory(
    png_structp png_ptr,
    png_bytep output,
    size_t length
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
    size_t (*rowbytes_fn)(png_const_structp, png_const_infop) =
        png_get_rowbytes;
    png_byte (*channels_fn)(png_const_structp, png_const_infop) =
        png_get_channels;
    png_uint_32 (*width_fn)(png_const_structp, png_const_infop) =
        png_get_image_width;
    png_uint_32 (*height_fn)(png_const_structp, png_const_infop) =
        png_get_image_height;
    png_byte (*depth_fn)(png_const_structp, png_const_infop) =
        png_get_bit_depth;
    png_byte (*color_fn)(png_const_structp, png_const_infop) =
        png_get_color_type;
    png_byte (*filter_fn)(png_const_structp, png_const_infop) =
        png_get_filter_type;
    png_byte (*interlace_fn)(png_const_structp, png_const_infop) =
        png_get_interlace_type;
    png_byte (*compression_fn)(png_const_structp, png_const_infop) =
        png_get_compression_type;
    png_uint_32 (*ihdr_fn)(png_const_structp, png_const_infop,
        png_uint_32 *, png_uint_32 *, int *, int *, int *, int *, int *) =
        png_get_IHDR;
    return rowbytes_fn != NULL && channels_fn != NULL && width_fn != NULL &&
        height_fn != NULL && depth_fn != NULL && color_fn != NULL &&
        filter_fn != NULL && interlace_fn != NULL && compression_fn != NULL &&
        ihdr_fn != NULL;
}

static int scalars_are_zero(
    png_const_structp png_ptr,
    png_const_infop info_ptr
) {
    return png_get_rowbytes(png_ptr, info_ptr) == 0u &&
        png_get_channels(png_ptr, info_ptr) == 0u &&
        png_get_image_width(png_ptr, info_ptr) == 0u &&
        png_get_image_height(png_ptr, info_ptr) == 0u &&
        png_get_bit_depth(png_ptr, info_ptr) == 0u &&
        png_get_color_type(png_ptr, info_ptr) == 0u &&
        png_get_filter_type(png_ptr, info_ptr) == 0u &&
        png_get_interlace_type(png_ptr, info_ptr) == 0u &&
        png_get_compression_type(png_ptr, info_ptr) == 0u;
}

static int ihdr_failure_preserves_outputs(
    png_const_structp png_ptr,
    png_const_infop info_ptr
) {
    png_uint_32 width = 101u;
    png_uint_32 height = 102u;
    int depth = 103;
    int color = 104;
    int interlace = 105;
    int compression = 106;
    int filter = 107;
    return png_get_IHDR(
            png_ptr, info_ptr, &width, &height, &depth, &color,
            &interlace, &compression, &filter
        ) == 0u &&
        width == 101u && height == 102u && depth == 103 && color == 104 &&
        interlace == 105 && compression == 106 && filter == 107;
}

static int facts_match(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_uint_32 expected_width,
    png_uint_32 expected_height,
    int expected_depth,
    int expected_color,
    int expected_interlace,
    png_byte expected_channels,
    size_t expected_rowbytes
) {
    png_uint_32 width = 0u;
    png_uint_32 height = 0u;
    int depth = -1;
    int color = -1;
    int interlace = -1;
    int compression = -1;
    int filter = -1;
    if (png_get_IHDR(
            png_ptr, info_ptr, &width, &height, &depth, &color,
            &interlace, &compression, &filter
        ) != 1u) return 0;
    return width == expected_width && height == expected_height &&
        depth == expected_depth && color == expected_color &&
        interlace == expected_interlace &&
        compression == PNG_COMPRESSION_TYPE_BASE &&
        filter == PNG_FILTER_TYPE_BASE &&
        png_get_image_width(png_ptr, info_ptr) == expected_width &&
        png_get_image_height(png_ptr, info_ptr) == expected_height &&
        png_get_bit_depth(png_ptr, info_ptr) == (png_byte)expected_depth &&
        png_get_color_type(png_ptr, info_ptr) == (png_byte)expected_color &&
        png_get_interlace_type(png_ptr, info_ptr) ==
            (png_byte)expected_interlace &&
        png_get_compression_type(png_ptr, info_ptr) ==
            PNG_COMPRESSION_TYPE_BASE &&
        png_get_filter_type(png_ptr, info_ptr) == PNG_FILTER_TYPE_BASE &&
        png_get_channels(png_ptr, info_ptr) == expected_channels &&
        png_get_rowbytes(png_ptr, info_ptr) == expected_rowbytes &&
        png_get_IHDR(
            png_ptr, info_ptr, NULL, NULL, NULL, NULL, NULL, NULL, NULL
        ) == 1u;
}

static int decode_and_check(
    const unsigned char *bytes,
    size_t size,
    png_uint_32 expected_width,
    png_uint_32 expected_height,
    int expected_depth,
    int expected_color,
    int expected_interlace,
    png_byte expected_channels,
    size_t expected_rowbytes
) {
    read_context context = {
        .bytes = bytes,
        .size = size,
        .ok = 1
    };
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, NULL, NULL, NULL
    );
    png_infop info_ptr = png_create_info_struct(png_ptr);
    png_infop spare_ptr = png_create_info_struct(png_ptr);
    png_structp other_png = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, NULL, NULL, NULL
    );
    png_infop other_info = png_create_info_struct(other_png);
    if (png_ptr == NULL || info_ptr == NULL || spare_ptr == NULL ||
        other_png == NULL || other_info == NULL) {
        if (png_ptr != NULL) {
            png_destroy_read_struct(&png_ptr, &info_ptr, &spare_ptr);
        }
        if (other_png != NULL) {
            png_destroy_read_struct(&other_png, &other_info, NULL);
        }
        return 0;
    }

    int ok = scalars_are_zero(png_ptr, info_ptr) &&
        ihdr_failure_preserves_outputs(png_ptr, info_ptr) &&
        scalars_are_zero(png_ptr, other_info) &&
        ihdr_failure_preserves_outputs(png_ptr, other_info) &&
        scalars_are_zero(other_png, info_ptr) &&
        ihdr_failure_preserves_outputs(other_png, info_ptr);
    png_set_read_fn(png_ptr, &context, read_memory);
    png_read_info(png_ptr, info_ptr);
    ok = ok && context.ok != 0 && context.offset == size &&
        facts_match(
            png_ptr, info_ptr, expected_width, expected_height,
            expected_depth, expected_color, expected_interlace,
            expected_channels, expected_rowbytes
        ) &&
        scalars_are_zero(png_ptr, spare_ptr) &&
        ihdr_failure_preserves_outputs(png_ptr, spare_ptr) &&
        scalars_are_zero(other_png, info_ptr);

    png_infop stale_info = info_ptr;
    png_destroy_info_struct(png_ptr, &info_ptr);
    ok = ok && info_ptr == NULL && scalars_are_zero(png_ptr, stale_info) &&
        ihdr_failure_preserves_outputs(png_ptr, stale_info);
    png_destroy_read_struct(&png_ptr, &spare_ptr, NULL);
    png_destroy_read_struct(&other_png, &other_info, NULL);
    return ok && png_ptr == NULL && spare_ptr == NULL &&
        other_png == NULL && other_info == NULL;
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
    int ok = InitCJRuntime(runtime_params) == 0 &&
        LoadCJLibraryWithInit(argv[1]) == 0 && signatures_are_exact() &&
        scalars_are_zero(NULL, NULL) &&
        ihdr_failure_preserves_outputs(NULL, NULL) &&
        scalars_are_zero(
            (png_const_structp)(uintptr_t)1u,
            (png_const_infop)(uintptr_t)2u
        ) && ihdr_failure_preserves_outputs(
            (png_const_structp)(uintptr_t)1u,
            (png_const_infop)(uintptr_t)2u
        ) &&
        decode_and_check(
            gray, gray_size, 32u, 32u, 1, PNG_COLOR_TYPE_GRAY,
            PNG_INTERLACE_NONE, 1u, 4u
        ) &&
        decode_and_check(
            adam7, adam7_size, 32u, 32u, 8, PNG_COLOR_TYPE_RGB_ALPHA,
            PNG_INTERLACE_ADAM7, 4u, 128u
        );
    free(gray);
    free(adam7);
    if (FiniCJRuntime() != 0) ok = 0;
    if (!ok) return 4;
    printf("libpng4cj classic core info getters ABI: PASS\n");
    return 0;
}
