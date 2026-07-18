#include <png.h>

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int64_t InitCJRuntime(void *params);
extern int64_t LoadCJLibraryWithInit(const char *path);
extern int64_t FiniCJRuntime(void);

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

static void init_image(png_image *image) {
    memset(image, 0, sizeof(*image));
    image->version = PNG_IMAGE_VERSION;
}

static int finish_rgba(png_image *image, uint8_t **pixels, size_t *size) {
    image->format = PNG_FORMAT_RGBA;
    *size = PNG_IMAGE_SIZE(*image);
    *pixels = (uint8_t *)calloc(1, *size);
    if (*pixels == NULL ||
        !png_image_finish_read(image, NULL, *pixels, 0, NULL)) {
        free(*pixels);
        *pixels = NULL;
        return fail_image("finish-rgba", image);
    }
    return 1;
}

static int test_file_read(const char *input_path) {
    png_image image;
    init_image(&image);
    if (!png_image_begin_read_from_file(&image, input_path) ||
        image.opaque == NULL || image.width == 0 || image.height == 0) {
        return fail_image("file-read-begin", &image);
    }
    uint8_t *pixels = NULL;
    size_t size = 0;
    int ok = finish_rgba(&image, &pixels, &size) && size > 0;
    free(pixels);
    return ok;
}

static int test_stdio_read(const char *input_path) {
    FILE *file = fopen(input_path, "rb");
    if (file == NULL) return 0;
    png_image image;
    init_image(&image);
    if (!png_image_begin_read_from_stdio(&image, file)) {
        fclose(file);
        return fail_image("stdio-read-begin", &image);
    }
    uint8_t *pixels = NULL;
    size_t size = 0;
    int ok = finish_rgba(&image, &pixels, &size) && size > 0;
    free(pixels);
    if (fclose(file) != 0) ok = 0;
    return ok;
}

static void init_write_image(png_image *image) {
    init_image(image);
    image->width = 2;
    image->height = 1;
    image->format = PNG_FORMAT_RGBA;
}

static int verify_written_file(const char *path, const uint8_t *expected) {
    png_image image;
    init_image(&image);
    if (!png_image_begin_read_from_file(&image, path) ||
        image.width != 2 || image.height != 1) {
        return fail_image("verify-written-begin", &image);
    }
    uint8_t *pixels = NULL;
    size_t size = 0;
    int ok = finish_rgba(&image, &pixels, &size) && size == 8 &&
        memcmp(pixels, expected, 8) == 0;
    free(pixels);
    return ok;
}

static int test_file_write(const char *path) {
    static const uint8_t pixels[8] = {
        0x10, 0x20, 0x30, 0xff, 0xa0, 0xb0, 0xc0, 0x80
    };
    png_image image;
    init_write_image(&image);
    if (!png_image_write_to_file(&image, path, 0, pixels, 0, NULL)) {
        return fail_image("file-write", &image);
    }
    return verify_written_file(path, pixels);
}

static int test_stdio_write(const char *path) {
    static const uint8_t pixels[8] = {
        0x01, 0x02, 0x03, 0xff, 0xf0, 0xe0, 0xd0, 0x40
    };
    FILE *file = fopen(path, "wb+");
    if (file == NULL) return 0;
    png_image write_image;
    init_write_image(&write_image);
    if (!png_image_write_to_stdio(
            &write_image, file, 0, pixels, 0, NULL
        ) || fflush(file) != 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return fail_image("stdio-write", &write_image);
    }

    png_image read_image;
    init_image(&read_image);
    if (!png_image_begin_read_from_stdio(&read_image, file)) {
        fclose(file);
        return fail_image("stdio-write-readback-begin", &read_image);
    }
    uint8_t *decoded = NULL;
    size_t size = 0;
    int ok = finish_rgba(&read_image, &decoded, &size) && size == 8 &&
        memcmp(decoded, pixels, 8) == 0;
    free(decoded);
    if (fclose(file) != 0) ok = 0;
    return ok;
}

static int write_malformed(const char *path) {
    static const uint8_t malformed[8] = {0, 1, 2, 3, 4, 5, 6, 7};
    FILE *file = fopen(path, "wb");
    if (file == NULL) return 0;
    int ok = fwrite(malformed, 1, sizeof(malformed), file) == sizeof(malformed);
    if (fclose(file) != 0) ok = 0;
    return ok;
}

static int file_absent(const char *path) {
    FILE *file = fopen(path, "rb");
    if (file == NULL) return 1;
    fclose(file);
    return 0;
}

static int test_failures(
    const char *valid_path,
    const char *malformed_path,
    const char *missing_path
) {
    if (!write_malformed(malformed_path)) return 0;
    png_image image;
    init_image(&image);
    if (png_image_begin_read_from_file(&image, malformed_path) != 0 ||
        !PNG_IMAGE_FAILED(image) || image.message[0] == '\0') {
        return fail_image("malformed-file", &image);
    }

    FILE *malformed = fopen(malformed_path, "rb");
    if (malformed == NULL) return 0;
    init_image(&image);
    int malformed_ok =
        png_image_begin_read_from_stdio(&image, malformed) == 0 &&
        PNG_IMAGE_FAILED(image) && image.message[0] != '\0';
    if (fclose(malformed) != 0) malformed_ok = 0;
    if (!malformed_ok) return fail_image("malformed-stdio", &image);

    FILE *write_only = fopen(malformed_path, "wb");
    if (write_only == NULL) return 0;
    init_image(&image);
    int read_error_ok =
        png_image_begin_read_from_stdio(&image, write_only) == 0 &&
        PNG_IMAGE_FAILED(image) && image.message[0] != '\0';
    if (fclose(write_only) != 0) read_error_ok = 0;
    if (!read_error_ok) return fail_image("stdio-read-error", &image);

    init_image(&image);
    if (png_image_begin_read_from_file(&image, missing_path) != 0 ||
        !PNG_IMAGE_FAILED(image)) {
        return fail_image("missing-file", &image);
    }

    init_image(&image);
    if (png_image_begin_read_from_stdio(&image, NULL) != 0 ||
        !PNG_IMAGE_FAILED(image)) {
        return fail_image("null-stdio", &image);
    }

    static const uint8_t pixels[8] = {
        0, 0, 0, 0xff, 0xff, 0xff, 0xff, 0xff
    };
    init_write_image(&image);
    image.format = 0x80000000u;
    if (png_image_write_to_file(
            &image, malformed_path, 0, pixels, 0, NULL
        ) != 0 || !PNG_IMAGE_FAILED(image) || !file_absent(malformed_path)) {
        return fail_image("failed-write-removes-file", &image);
    }

    init_write_image(&image);
    if (png_image_write_to_stdio(&image, NULL, 0, pixels, 0, NULL) != 0 ||
        !PNG_IMAGE_FAILED(image)) {
        return fail_image("null-write-stdio", &image);
    }

    FILE *read_only = fopen(valid_path, "rb");
    if (read_only == NULL) return 0;
    init_write_image(&image);
    int write_error_ok =
        png_image_write_to_stdio(&image, read_only, 0, pixels, 0, NULL) == 0 &&
        PNG_IMAGE_FAILED(image) && image.message[0] != '\0';
    if (fclose(read_only) != 0) write_error_ok = 0;
    if (!write_error_ok) return fail_image("stdio-write-error", &image);

    init_write_image(&image);
    if (png_image_write_to_file(
            &image, missing_path, 0, pixels, 0, NULL
        ) != 0 || !PNG_IMAGE_FAILED(image)) {
        return fail_image("missing-write-file", &image);
    }
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 7) {
        fprintf(
            stderr,
            "usage: %s DYLIB INPUT FILE_OUT STDIO_OUT MALFORMED MISSING\n",
            argv[0]
        );
        return 2;
    }
    max_align_t runtime_params[64];
    memset(runtime_params, 0, sizeof(runtime_params));
    if (InitCJRuntime(runtime_params) != 0 ||
        LoadCJLibraryWithInit(argv[1]) != 0) {
        fprintf(stderr, "failed to initialize Cangjie runtime\n");
        return 3;
    }
    int ok = test_file_read(argv[2]) && test_stdio_read(argv[2]) &&
        test_file_write(argv[3]) && test_stdio_write(argv[4]) &&
        test_failures(argv[2], argv[5], argv[6]);
    if (FiniCJRuntime() != 0) ok = 0;
    if (!ok) return 4;
    printf("libpng4cj png_image file/stdio ABI: PASS\n");
    return 0;
}
