#include "libpng4cj_preview.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int64_t InitCJRuntime(void *params);
extern int64_t LoadCJLibraryWithInit(const char *path);
extern int64_t FiniCJRuntime(void);

static uint8_t *read_file(const char *path, size_t *size) {
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        return NULL;
    }
    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return NULL;
    }
    long length = ftell(file);
    if (length <= 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return NULL;
    }
    uint8_t *bytes = (uint8_t *)malloc((size_t)length);
    if (bytes == NULL || fread(bytes, 1, (size_t)length, file) != (size_t)length) {
        free(bytes);
        fclose(file);
        return NULL;
    }
    fclose(file);
    *size = (size_t)length;
    return bytes;
}

static const char *status_name(png4cj_status status) {
    switch (status) {
        case PNG4CJ_STATUS_OK: return "OK";
        case PNG4CJ_STATUS_INVALID_ARGUMENT: return "INVALID_ARGUMENT";
        case PNG4CJ_STATUS_BUFFER_TOO_SMALL: return "BUFFER_TOO_SMALL";
        case PNG4CJ_STATUS_DECODE_ERROR: return "DECODE_ERROR";
        case PNG4CJ_STATUS_INTERNAL_ERROR: return "INTERNAL_ERROR";
        default: return "OTHER";
    }
}

static int require_status(
    png4cj_status actual,
    png4cj_status expected,
    const char *label,
    const uint8_t *message
) {
    if (actual != expected) {
        fprintf(
            stderr,
            "%s: expected %s, got %s: %s\n",
            label,
            status_name(expected),
            status_name(actual),
            message == NULL ? "" : (const char *)message
        );
        return 0;
    }
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: %s CANGJIE_DYLIB PNG_FILE\n", argv[0]);
        return 2;
    }
    max_align_t runtime_params[64];
    memset(runtime_params, 0, sizeof(runtime_params));
    if (InitCJRuntime(runtime_params) != 0 || LoadCJLibraryWithInit(argv[1]) != 0) {
        fprintf(stderr, "failed to initialize the Cangjie library runtime\n");
        return 3;
    }
    int result = 0;
    if (png4cj_preview_abi_version() != PNG4CJ_PREVIEW_ABI_VERSION) {
        fprintf(stderr, "ABI version mismatch\n");
        result = 4;
        goto cleanup;
    }
    uint8_t version[16] = {0};
    size_t version_required = 0;
    if (!require_status(
            png4cj_libpng_version(version, sizeof(version), &version_required),
            PNG4CJ_STATUS_OK,
            "version",
            NULL
        ) || strcmp((const char *)version, "1.6.58") != 0 ||
        version_required != strlen("1.6.58") + 1) {
        fprintf(stderr, "upstream version mismatch\n");
        result = 5;
        goto cleanup;
    }
    uint64_t capabilities = png4cj_capabilities();
    if ((capabilities & PNG4CJ_CAP_DECODE_RGBA8) == 0 ||
        (capabilities & PNG4CJ_CAP_ADAM7) == 0) {
        fprintf(stderr, "required preview capabilities are absent\n");
        result = 6;
        goto cleanup;
    }

    size_t input_size = 0;
    uint8_t *input = read_file(argv[2], &input_size);
    if (input == NULL) {
        fprintf(stderr, "failed to read %s\n", argv[2]);
        result = 7;
        goto cleanup;
    }
    uint8_t message[512] = {0};
    int32_t is_png = 0;
    if (!require_status(
            png4cj_check_signature(
                input, input_size, &is_png, message, sizeof(message)
            ),
            PNG4CJ_STATUS_OK,
            "signature",
            message
        ) ||
        !is_png) {
        free(input);
        result = 8;
        goto cleanup;
    }

    uint32_t width = 0;
    uint32_t height = 0;
    size_t stride = 0;
    size_t image_size = 0;
    int32_t error_kind = -1;
    int64_t error_offset = -1;
    png4cj_status size_status = png4cj_decode_rgba8(
        input, input_size, NULL, 0, &width, &height, &stride, &image_size,
        &error_kind, &error_offset, message, sizeof(message)
    );
    if (!require_status(
            size_status, PNG4CJ_STATUS_BUFFER_TOO_SMALL, "decode-size", message
        ) || width == 0 || height == 0 || stride != (size_t)width * 4 ||
        image_size != stride * height) {
        free(input);
        result = 9;
        goto cleanup;
    }
    uint8_t *image = (uint8_t *)malloc(image_size);
    if (image == NULL || !require_status(
            png4cj_decode_rgba8(
                input, input_size, image, image_size, &width, &height, &stride,
                &image_size, &error_kind, &error_offset, message,
                sizeof(message)
            ),
            PNG4CJ_STATUS_OK,
            "decode",
            message
        )) {
        free(image);
        free(input);
        result = 10;
        goto cleanup;
    }
    printf(
        "libpng4cj-preview abi=%u upstream=%s image=%ux%u stride=%zu bytes=%zu\n",
        png4cj_preview_abi_version(),
        version,
        width,
        height,
        stride,
        image_size
    );
    free(image);

    const uint8_t malformed[] = {0, 1, 2, 3, 4, 5, 6, 7};
    memset(message, 0, sizeof(message));
    png4cj_status malformed_status = png4cj_decode_rgba8(
        malformed, sizeof(malformed), NULL, 0, &width, &height, &stride,
        &image_size, &error_kind, &error_offset, message, sizeof(message)
    );
    if (!require_status(
            malformed_status, PNG4CJ_STATUS_DECODE_ERROR, "malformed", message
        ) || message[0] == '\0') {
        free(input);
        result = 11;
        goto cleanup;
    }

    free(input);
cleanup:
    if (FiniCJRuntime() != 0 && result == 0) {
        result = 12;
    }
    return result;
}
