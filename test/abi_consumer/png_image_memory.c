#include <png.h>

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int64_t InitCJRuntime(void *params);
extern int64_t LoadCJLibraryWithInit(const char *path);
extern int64_t FiniCJRuntime(void);

_Static_assert(sizeof(png_image) == 104, "png_image LP64 size mismatch");
_Static_assert(offsetof(png_image, opaque) == 0, "png_image opaque offset");
_Static_assert(offsetof(png_image, version) == 8, "png_image version offset");
_Static_assert(offsetof(png_image, width) == 12, "png_image width offset");
_Static_assert(offsetof(png_image, height) == 16, "png_image height offset");
_Static_assert(offsetof(png_image, format) == 20, "png_image format offset");
_Static_assert(offsetof(png_image, flags) == 24, "png_image flags offset");
_Static_assert(offsetof(png_image, colormap_entries) == 28, "png_image colormap offset");
_Static_assert(offsetof(png_image, warning_or_error) == 32, "png_image status offset");
_Static_assert(offsetof(png_image, message) == 36, "png_image message offset");
_Static_assert(sizeof(png_color) == 3, "png_color size mismatch");

typedef struct owned_bytes {
    uint8_t *data;
    size_t size;
} owned_bytes;

static const uint8_t non_srgb_png[] = {
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
    0xde, 0x00, 0x00, 0x00, 0x20, 0x63, 0x48, 0x52,
    0x4d, 0x00, 0x00, 0x7a, 0x26, 0x00, 0x00, 0x80,
    0x84, 0x00, 0x00, 0xfa, 0x00, 0x00, 0x00, 0x80,
    0xe8, 0x00, 0x00, 0x75, 0x30, 0x00, 0x00, 0xea,
    0x60, 0x00, 0x00, 0x75, 0x30, 0x00, 0x00, 0x27,
    0x10, 0xb0, 0x17, 0x6a, 0x79, 0x00, 0x00, 0x00,
    0x0c, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63,
    0x68, 0x70, 0x50, 0x00, 0x00, 0x02, 0x24, 0x00,
    0xe1, 0xab, 0x59, 0x62, 0x27, 0x00, 0x00, 0x00,
    0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60,
    0x82
};

static const uint8_t untagged_rgba16_png[] = {
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x10, 0x06, 0x00, 0x00, 0x00, 0x4f, 0x85, 0x18,
    0xca, 0x00, 0x00, 0x00, 0x11, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9c, 0x63, 0x68, 0x60, 0x70, 0x60,
    0x50, 0x60, 0xf8, 0xff, 0x1f, 0x00, 0x09, 0x06,
    0x02, 0xdf, 0x8c, 0xd2, 0x40, 0x19, 0x00, 0x00,
    0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42,
    0x60, 0x82
};

static owned_bytes read_file(const char *path) {
    owned_bytes out = {NULL, 0};
    FILE *file = fopen(path, "rb");
    if (file == NULL || fseek(file, 0, SEEK_END) != 0) {
        if (file != NULL) fclose(file);
        return out;
    }
    long length = ftell(file);
    if (length <= 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return out;
    }
    out.data = (uint8_t *)malloc((size_t)length);
    if (out.data == NULL || fread(out.data, 1, (size_t)length, file) != (size_t)length) {
        free(out.data);
        out.data = NULL;
        fclose(file);
        return out;
    }
    fclose(file);
    out.size = (size_t)length;
    return out;
}

static int fail_image(const char *label, const png_image *image) {
    fprintf(
        stderr,
        "%s failed: status=%u message=%s\n",
        label,
        image == NULL ? 0u : image->warning_or_error,
        image == NULL ? "" : image->message
    );
    return 0;
}

static int begin_image(png_image *image, const owned_bytes *input, const char *label) {
    memset(image, 0, sizeof(*image));
    image->version = PNG_IMAGE_VERSION;
    if (!png_image_begin_read_from_memory(image, input->data, input->size)) {
        return fail_image(label, image);
    }
    if (image->opaque == NULL || image->width == 0 || image->height == 0) {
        return fail_image(label, image);
    }
    return 1;
}

static int test_direct_and_lifecycle(const owned_bytes *input) {
    png_image image;
    if (!begin_image(&image, input, "direct-begin")) return 0;

    void *owned = image.opaque;
    if (png_image_begin_read_from_memory(&image, input->data, input->size) != 0 ||
        image.opaque != owned || !PNG_IMAGE_FAILED(image)) {
        png_image_free(&image);
        return fail_image("repeat-begin", &image);
    }
    png_image_free(&image);
    if (image.opaque != NULL) return fail_image("free", &image);
    png_image_free(&image);

    if (!begin_image(&image, input, "direct-positive-begin")) return 0;
    image.format = PNG_FORMAT_RGBA;
    const uint32_t stride = PNG_IMAGE_ROW_STRIDE(image);
    const size_t size = PNG_IMAGE_SIZE(image);
    uint8_t *positive = (uint8_t *)calloc(1, size);
    if (positive == NULL || !png_image_finish_read(&image, NULL, positive, 0, NULL)) {
        free(positive);
        return fail_image("direct-positive-finish", &image);
    }
    if (image.opaque != NULL || PNG_IMAGE_FAILED(image)) {
        free(positive);
        return fail_image("direct-positive-state", &image);
    }

    if (!begin_image(&image, input, "direct-negative-begin")) {
        free(positive);
        return 0;
    }
    image.format = PNG_FORMAT_RGBA;
    uint8_t *negative = (uint8_t *)calloc(1, size);
    if (negative == NULL || !png_image_finish_read(
            &image, NULL, negative, -(int32_t)stride, NULL
        )) {
        free(negative);
        free(positive);
        return fail_image("direct-negative-finish", &image);
    }
    int rows_match = memcmp(
        positive,
        negative + (size_t)(image.height - 1u) * stride,
        stride
    ) == 0;
    free(negative);
    if (!rows_match) {
        free(positive);
        fprintf(stderr, "negative stride top row mismatch\n");
        return 0;
    }

    if (!begin_image(&image, input, "background-begin")) {
        free(positive);
        return 0;
    }
    image.format = PNG_FORMAT_RGB;
    png_color white = {255, 255, 255};
    size_t rgb_size = PNG_IMAGE_SIZE(image);
    uint8_t *rgb = (uint8_t *)calloc(1, rgb_size);
    if (rgb == NULL || !png_image_finish_read(&image, &white, rgb, 0, NULL)) {
        free(rgb);
        free(positive);
        return fail_image("background-finish", &image);
    }
    free(rgb);

    png_image write_image;
    memset(&write_image, 0, sizeof(write_image));
    write_image.version = PNG_IMAGE_VERSION;
    write_image.width = image.width;
    write_image.height = image.height;
    write_image.format = PNG_FORMAT_RGBA;
    size_t encoded_size = 0;
    if (!png_image_write_to_memory(
            &write_image, NULL, &encoded_size, 0, positive, (int32_t)stride, NULL
        ) || encoded_size == 0) {
        free(positive);
        return fail_image("direct-write-size", &write_image);
    }
    uint8_t *encoded = (uint8_t *)malloc(encoded_size);
    if (encoded == NULL) {
        free(positive);
        return 0;
    }
    size_t too_small = encoded_size - 1;
    if (png_image_write_to_memory(
            &write_image, encoded, &too_small, 0, positive, (int32_t)stride, NULL
        ) != 0 || too_small != encoded_size || PNG_IMAGE_FAILED(write_image)) {
        free(encoded);
        free(positive);
        return fail_image("direct-write-small", &write_image);
    }
    size_t capacity = encoded_size;
    if (!png_image_write_to_memory(
            &write_image, encoded, &capacity, 0, positive, (int32_t)stride, NULL
        ) || capacity != encoded_size) {
        free(encoded);
        free(positive);
        return fail_image("direct-write-fill", &write_image);
    }
    owned_bytes encoded_input = {encoded, encoded_size};
    if (!begin_image(&image, &encoded_input, "direct-write-readback")) {
        free(encoded);
        free(positive);
        return 0;
    }
    png_image_free(&image);
    free(encoded);
    free(positive);
    return 1;
}

static int test_linear(const owned_bytes *input) {
    png_image image;
    if (!begin_image(&image, input, "associated8-begin")) return 0;
    image.format = PNG_FORMAT_RGBA | PNG_FORMAT_FLAG_ASSOCIATED_ALPHA;
    size_t associated_size = PNG_IMAGE_SIZE(image);
    uint8_t *associated = (uint8_t *)calloc(1, associated_size);
    if (associated == NULL || !png_image_finish_read(
            &image, NULL, associated, 0, NULL
        )) {
        free(associated);
        return fail_image("associated8-finish", &image);
    }
    for (size_t offset = 0; offset < associated_size; offset += 4) {
        if (associated[offset] > associated[offset + 3] ||
            associated[offset + 1] > associated[offset + 3] ||
            associated[offset + 2] > associated[offset + 3]) {
            free(associated);
            fprintf(stderr, "associated8 color exceeds alpha\n");
            return 0;
        }
    }
    free(associated);

    if (!begin_image(&image, input, "target-background-begin")) return 0;
    image.format = PNG_FORMAT_RGB;
    size_t target_size = PNG_IMAGE_SIZE(image);
    uint8_t *target_background = (uint8_t *)malloc(target_size);
    if (target_background == NULL) return 0;
    memset(target_background, 173, target_size);
    if (!png_image_finish_read(&image, NULL, target_background, 0, NULL)) {
        free(target_background);
        return fail_image("target-background-finish", &image);
    }
    free(target_background);

    if (!begin_image(&image, input, "linear-begin")) return 0;
    image.format = PNG_FORMAT_LINEAR_RGB_ALPHA | PNG_FORMAT_FLAG_ASSOCIATED_ALPHA;
    const uint32_t stride = PNG_IMAGE_ROW_STRIDE(image);
    const size_t size = PNG_IMAGE_SIZE(image);
    uint16_t *pixels = (uint16_t *)calloc(1, size);
    if (pixels == NULL || !png_image_finish_read(
            &image, NULL, pixels, -(int32_t)stride, NULL
        )) {
        free(pixels);
        return fail_image("linear-finish", &image);
    }
    free(pixels);

    uint16_t source[] = {
        0xffff, 0x0000, 0x0000, 0xffff,
        0x0000, 0xffff, 0x0000, 0x8000
    };
    png_image write_image;
    memset(&write_image, 0, sizeof(write_image));
    write_image.version = PNG_IMAGE_VERSION;
    write_image.width = 2;
    write_image.height = 1;
    write_image.format = PNG_FORMAT_LINEAR_RGB_ALPHA;
    size_t encoded_size = 0;
    if (!png_image_write_to_memory(
            &write_image, NULL, &encoded_size, 1, source, 0, NULL
        ) || encoded_size == 0) {
        return fail_image("linear-write-size", &write_image);
    }
    uint8_t *encoded = (uint8_t *)malloc(encoded_size);
    size_t capacity = encoded_size;
    int ok = encoded != NULL && png_image_write_to_memory(
        &write_image, encoded, &capacity, 1, source, 0, NULL
    );
    free(encoded);
    return ok ? 1 : fail_image("linear-write-fill", &write_image);
}

static int test_color_flags(void) {
    owned_bytes tagged = {
        (uint8_t *)(uintptr_t)non_srgb_png,
        sizeof(non_srgb_png)
    };
    png_image image;
    if (!begin_image(&image, &tagged, "colorspace-begin")) return 0;
    if ((image.flags & PNG_IMAGE_FLAG_COLORSPACE_NOT_sRGB) == 0) {
        png_image_free(&image);
        return fail_image("colorspace-flag", &image);
    }
    png_image_free(&image);

    owned_bytes untagged = {
        (uint8_t *)(uintptr_t)untagged_rgba16_png,
        sizeof(untagged_rgba16_png)
    };
    uint16_t linear_default[4] = {0, 0, 0, 0};
    uint16_t linear_srgb[4] = {0, 0, 0, 0};
    if (!begin_image(&image, &untagged, "linear-default-begin")) return 0;
    image.format = PNG_FORMAT_LINEAR_RGB_ALPHA;
    if (!png_image_finish_read(&image, NULL, linear_default, 0, NULL)) {
        return fail_image("linear-default-finish", &image);
    }
    if (!begin_image(&image, &untagged, "linear-srgb-begin")) return 0;
    image.format = PNG_FORMAT_LINEAR_RGB_ALPHA;
    image.flags |= PNG_IMAGE_FLAG_16BIT_sRGB;
    if (!png_image_finish_read(&image, NULL, linear_srgb, 0, NULL)) {
        return fail_image("linear-srgb-finish", &image);
    }
    if (linear_default[0] != 0x8000u || linear_srgb[0] >= linear_default[0] ||
        memcmp(linear_default, linear_srgb, sizeof(linear_default)) == 0) {
        fprintf(stderr, "16-bit sRGB assumption did not change linear output\n");
        return 0;
    }
    return 1;
}

static int test_colormap(const owned_bytes *input) {
    png_image image;
    if (!begin_image(&image, input, "colormap-begin")) return 0;
    image.format = PNG_FORMAT_RGBA_COLORMAP;
    size_t pixel_size = PNG_IMAGE_SIZE(image);
    size_t map_size = PNG_IMAGE_COLORMAP_SIZE(image);
    uint8_t *pixels = (uint8_t *)calloc(1, pixel_size);
    uint8_t *map = (uint8_t *)calloc(1, map_size);
    if (pixels == NULL || map == NULL || !png_image_finish_read(
            &image, NULL, pixels, 0, map
        ) || image.colormap_entries == 0 || image.colormap_entries > 256) {
        free(map);
        free(pixels);
        return fail_image("colormap-finish", &image);
    }
    free(map);
    free(pixels);

    uint8_t source[] = {0, 1};
    uint8_t table[] = {255, 0, 0, 255, 0, 0, 255, 128};
    png_image write_image;
    memset(&write_image, 0, sizeof(write_image));
    write_image.version = PNG_IMAGE_VERSION;
    write_image.width = 2;
    write_image.height = 1;
    write_image.format = PNG_FORMAT_RGBA_COLORMAP;
    write_image.colormap_entries = 2;
    size_t encoded_size = 0;
    if (!png_image_write_to_memory(
            &write_image, NULL, &encoded_size, 0, source, 0, table
        ) || encoded_size == 0) {
        return fail_image("colormap-write-size", &write_image);
    }
    uint8_t *encoded = (uint8_t *)malloc(encoded_size);
    size_t capacity = encoded_size;
    int ok = encoded != NULL && png_image_write_to_memory(
        &write_image, encoded, &capacity, 0, source, 0, table
    );
    free(encoded);
    return ok ? 1 : fail_image("colormap-write-fill", &write_image);
}

static int test_failures(const owned_bytes *valid) {
    const uint8_t malformed[] = {0, 1, 2, 3, 4, 5, 6, 7};
    png_image image;
    memset(&image, 0, sizeof(image));
    image.version = PNG_IMAGE_VERSION;
    if (png_image_begin_read_from_memory(&image, malformed, sizeof(malformed)) != 0 ||
        !PNG_IMAGE_FAILED(image) || image.message[0] == '\0') {
        return fail_image("malformed", &image);
    }

    memset(&image, 0, sizeof(image));
    image.version = PNG_IMAGE_VERSION + 1u;
    if (png_image_begin_read_from_memory(&image, valid->data, valid->size) != 0 ||
        !PNG_IMAGE_FAILED(image)) {
        return fail_image("version", &image);
    }

    memset(&image, 0, sizeof(image));
    image.version = PNG_IMAGE_VERSION;
    if (png_image_begin_read_from_memory(
            &image, valid->data, (size_t)268435457u
        ) != 0 || !PNG_IMAGE_FAILED(image)) {
        return fail_image("limit", &image);
    }
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 5) {
        fprintf(stderr, "usage: %s CANGJIE_DYLIB DIRECT_PNG LINEAR_PNG COLORMAP_PNG\n", argv[0]);
        return 2;
    }
    max_align_t runtime_params[64];
    memset(runtime_params, 0, sizeof(runtime_params));
    if (InitCJRuntime(runtime_params) != 0 || LoadCJLibraryWithInit(argv[1]) != 0) {
        fprintf(stderr, "failed to initialize Cangjie runtime\n");
        return 3;
    }
    owned_bytes direct = read_file(argv[2]);
    owned_bytes linear = read_file(argv[3]);
    owned_bytes colormap = read_file(argv[4]);
    int ok = direct.data != NULL && linear.data != NULL && colormap.data != NULL &&
        test_direct_and_lifecycle(&direct) &&
        test_linear(&linear) &&
        test_color_flags() &&
        test_colormap(&colormap) &&
        test_failures(&direct);
    free(colormap.data);
    free(linear.data);
    free(direct.data);
    if (FiniCJRuntime() != 0) ok = 0;
    if (!ok) return 4;
    printf("libpng4cj png_image memory ABI: PASS\n");
    return 0;
}
