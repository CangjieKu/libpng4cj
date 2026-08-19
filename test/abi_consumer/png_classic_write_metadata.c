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

typedef struct memory_stream {
    unsigned char bytes[131072];
    size_t size;
    size_t offset;
    int ok;
} memory_stream;

static void returning_error(png_structp png_ptr, png_const_charp message) {
    (void)png_ptr;
    (void)message;
}

static void write_memory(
    png_structp png_ptr, png_bytep data, size_t length
) {
    memory_stream *stream = (memory_stream *)png_get_io_ptr(png_ptr);
    if (stream == NULL || data == NULL || length > sizeof(stream->bytes) - stream->size) {
        if (stream != NULL) stream->ok = 0;
        png_error(png_ptr, "metadata output overflow");
        return;
    }
    memcpy(stream->bytes + stream->size, data, length);
    stream->size += length;
}

static void read_memory(
    png_structp png_ptr, png_bytep data, size_t length
) {
    memory_stream *stream = (memory_stream *)png_get_io_ptr(png_ptr);
    if (stream == NULL || data == NULL || length > stream->size - stream->offset) {
        if (stream != NULL) stream->ok = 0;
        png_error(png_ptr, "metadata input underflow");
        return;
    }
    memcpy(data, stream->bytes + stream->offset, length);
    stream->offset += length;
}

static int encode_metadata(memory_stream *stream) {
    static const png_byte row0[2] = {0u, 1u};
    static const png_byte row1[2] = {1u, 0u};
    png_byte *rows[2] = {(png_byte *)row0, (png_byte *)row1};
    png_color palette[2] = {{12u, 34u, 56u}, {210u, 180u, 90u}};
    png_uint_16 histogram[2] = {11u, 29u};
    png_byte alpha[2] = {255u, 96u};
    png_color_16 background = {1u, 0u, 0u, 0u, 0u};
    png_color_8 significant = {8u, 7u, 6u, 1u, 1u};
    png_time first_time = {2025u, 1u, 2u, 3u, 4u, 5u};
    png_time final_time = {2026u, 8u, 19u, 10u, 30u, 45u};
    png_byte exif[8] = {'I', 'I', 42u, 0u, 8u, 0u, 0u, 0u};
    png_structp png_ptr = png_create_write_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (png_ptr == NULL || info_ptr == NULL) {
        png_destroy_write_struct(&png_ptr, &info_ptr);
        return 0;
    }
    stream->size = 0u;
    stream->offset = 0u;
    stream->ok = 1;
    png_set_write_fn(png_ptr, stream, write_memory, NULL);
    png_structp other_png = png_create_write_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    png_infop other_info = png_create_info_struct(other_png);
    if (other_png == NULL || other_info == NULL) {
        png_destroy_write_struct(&other_png, &other_info);
        png_destroy_write_struct(&png_ptr, &info_ptr);
        return 0;
    }
    png_set_gAMA_fixed(png_ptr, other_info, 12345);
    png_destroy_write_struct(&other_png, &other_info);
    png_set_IHDR(
        png_ptr, info_ptr, 2u, 2u, 8, PNG_COLOR_TYPE_PALETTE,
        PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE
    );
    png_set_PLTE(png_ptr, info_ptr, palette, 2);
    png_set_bKGD(png_ptr, info_ptr, &background);
    png_set_cHRM_fixed(
        png_ptr, info_ptr,
        31270, 32900, 64000, 33000, 30000, 60000, 15000, 6000
    );
    png_set_cICP(png_ptr, info_ptr, 1u, 13u, 0u, 1u);
    png_set_cLLI_fixed(png_ptr, info_ptr, 10000u, 4000u);
    png_set_eXIf_1(png_ptr, info_ptr, sizeof(exif), exif);
    png_set_gAMA_fixed(png_ptr, info_ptr, 50000);
    png_set_gAMA_fixed(png_ptr, info_ptr, 45455);
    png_set_hIST(png_ptr, info_ptr, histogram);
    png_set_mDCV_fixed(
        png_ptr, info_ptr,
        31270, 32900, 64000, 33000, 30000, 60000, 15000, 6000,
        1000000u, 500u
    );
    png_set_oFFs(png_ptr, info_ptr, -17, 23, PNG_OFFSET_MICROMETER);
    png_set_pHYs(png_ptr, info_ptr, 3000u, 4000u, PNG_RESOLUTION_METER);
    png_set_pHYs(png_ptr, info_ptr, 3780u, 3780u, PNG_RESOLUTION_METER);
    png_set_sBIT(png_ptr, info_ptr, &significant);
    png_set_sRGB(png_ptr, info_ptr, 1);
    png_set_tIME(png_ptr, info_ptr, &first_time);
    png_set_tIME(png_ptr, info_ptr, &final_time);
    png_set_tRNS(png_ptr, info_ptr, alpha, 2, NULL);
    png_write_info(png_ptr, info_ptr);
    png_set_gAMA_fixed(png_ptr, info_ptr, 33333);
    png_write_image(png_ptr, rows);
    png_write_end(png_ptr, info_ptr);
    int ok = stream->ok != 0 && stream->size > 100u;
    png_structp stale_png = png_ptr;
    png_infop stale_info = info_ptr;
    png_destroy_write_struct(&png_ptr, &info_ptr);
    png_set_gAMA_fixed(NULL, NULL, 100000);
    png_set_gAMA_fixed(stale_png, stale_info, 100000);
    return ok && png_ptr == NULL && info_ptr == NULL &&
        other_png == NULL && other_info == NULL;
}

static int verify_metadata(memory_stream *stream) {
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (png_ptr == NULL || info_ptr == NULL) {
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }
    stream->offset = 0u;
    png_set_read_fn(png_ptr, stream, read_memory);
    png_read_info(png_ptr, info_ptr);

    png_color_16 *background = NULL;
    png_fixed_point white_x = 0, white_y = 0, red_x = 0, red_y = 0;
    png_fixed_point green_x = 0, green_y = 0, blue_x = 0, blue_y = 0;
    png_byte primaries = 0, transfer = 0, matrix = 255, full = 0;
    png_uint_32 max_cll = 0, max_fall = 0;
    png_uint_32 exif_size = 0;
    png_bytep exif = NULL;
    png_fixed_point gamma = 0;
    png_uint_16 *histogram = NULL;
    png_uint_32 max_lum = 0, min_lum = 0;
    png_int_32 offset_x = 0, offset_y = 0;
    int offset_unit = -1;
    png_uint_32 resolution_x = 0, resolution_y = 0;
    int resolution_unit = -1;
    png_color_8 *significant = NULL;
    int intent = -1;
    png_time *time = NULL;
    png_bytep alpha = NULL;
    int alpha_count = 0;
    png_color_16 *transparent_color = NULL;

    int ok = png_get_bKGD(png_ptr, info_ptr, &background) == PNG_INFO_bKGD &&
        background != NULL && background->index == 1u;
    ok = ok && png_get_cHRM_fixed(
        png_ptr, info_ptr, &white_x, &white_y, &red_x, &red_y,
        &green_x, &green_y, &blue_x, &blue_y
    ) == PNG_INFO_cHRM && white_x == 31270 && white_y == 32900 &&
        red_x == 64000 && green_y == 60000 && blue_y == 6000;
    ok = ok && png_get_cICP(
        png_ptr, info_ptr, &primaries, &transfer, &matrix, &full
    ) == PNG_INFO_cICP && primaries == 1u && transfer == 13u &&
        matrix == 0u && full == 1u;
    ok = ok && png_get_cLLI_fixed(
        png_ptr, info_ptr, &max_cll, &max_fall
    ) == PNG_INFO_cLLI && max_cll == 10000u && max_fall == 4000u;
    ok = ok && png_get_eXIf_1(
        png_ptr, info_ptr, &exif_size, &exif
    ) == PNG_INFO_eXIf && exif_size == 8u && exif != NULL &&
        memcmp(exif, "II*\0\10\0\0\0", 8u) == 0;
    ok = ok && png_get_gAMA_fixed(
        png_ptr, info_ptr, &gamma
    ) == PNG_INFO_gAMA && gamma == 45455;
    ok = ok && png_get_hIST(
        png_ptr, info_ptr, &histogram
    ) == PNG_INFO_hIST && histogram != NULL &&
        histogram[0] == 11u && histogram[1] == 29u;
    ok = ok && png_get_mDCV_fixed(
        png_ptr, info_ptr, &white_x, &white_y, &red_x, &red_y,
        &green_x, &green_y, &blue_x, &blue_y, &max_lum, &min_lum
    ) == PNG_INFO_mDCV && max_lum == 1000000u && min_lum == 500u;
    ok = ok && png_get_oFFs(
        png_ptr, info_ptr, &offset_x, &offset_y, &offset_unit
    ) == PNG_INFO_oFFs && offset_x == -17 && offset_y == 23 &&
        offset_unit == PNG_OFFSET_MICROMETER;
    ok = ok && png_get_pHYs(
        png_ptr, info_ptr, &resolution_x, &resolution_y, &resolution_unit
    ) == PNG_INFO_pHYs && resolution_x == 3780u && resolution_y == 3780u &&
        resolution_unit == PNG_RESOLUTION_METER;
    ok = ok && png_get_sBIT(
        png_ptr, info_ptr, &significant
    ) == PNG_INFO_sBIT && significant != NULL && significant->red == 8u &&
        significant->green == 7u && significant->blue == 6u;
    ok = ok && png_get_sRGB(
        png_ptr, info_ptr, &intent
    ) == PNG_INFO_sRGB && intent == 1;
    ok = ok && png_get_tIME(
        png_ptr, info_ptr, &time
    ) == PNG_INFO_tIME && time != NULL && time->year == 2026u &&
        time->month == 8u && time->day == 19u && time->second == 45u;
    ok = ok && png_get_tRNS(
        png_ptr, info_ptr, &alpha, &alpha_count, &transparent_color
    ) == PNG_INFO_tRNS && alpha != NULL && alpha_count == 2 &&
        alpha[0] == 255u && alpha[1] == 96u;

    png_byte rows_storage[4] = {0u, 0u, 0u, 0u};
    png_byte *rows[2] = {rows_storage, rows_storage + 2};
    png_read_image(png_ptr, rows);
    png_read_end(png_ptr, info_ptr);
    ok = ok && stream->ok != 0 && stream->offset == stream->size &&
        memcmp(rows_storage, "\0\1\1\0", 4u) == 0;
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
    memory_stream stream;
    memset(&stream, 0, sizeof(stream));
    int ok = encode_metadata(&stream) && verify_metadata(&stream);
    int fini_ok = FiniCJRuntime() == 0;
    printf("libpng4cj classic write metadata consumer: %s\n",
        ok && fini_ok ? "PASS" : "FAIL");
    return ok && fini_ok ? 0 : 1;
}
