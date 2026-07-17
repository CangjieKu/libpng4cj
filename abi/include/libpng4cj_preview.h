#ifndef LIBPNG4CJ_PREVIEW_H
#define LIBPNG4CJ_PREVIEW_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PNG4CJ_PREVIEW_ABI_VERSION 1u

typedef enum png4cj_status {
    PNG4CJ_STATUS_OK = 0,
    PNG4CJ_STATUS_INVALID_ARGUMENT = 1,
    PNG4CJ_STATUS_BUFFER_TOO_SMALL = 2,
    PNG4CJ_STATUS_DECODE_ERROR = 3,
    PNG4CJ_STATUS_INTERNAL_ERROR = 4,
    PNG4CJ_STATUS_UNSUPPORTED = 5,
    PNG4CJ_STATUS_RUNTIME_UNAVAILABLE = 6,
    PNG4CJ_STATUS_OUT_OF_MEMORY = 7
} png4cj_status;

typedef enum png4cj_capability {
    PNG4CJ_CAP_SIGNATURE = UINT64_C(1) << 0,
    PNG4CJ_CAP_DECODE_RGBA8 = UINT64_C(1) << 1,
    PNG4CJ_CAP_ADAM7 = UINT64_C(1) << 2,
    PNG4CJ_CAP_SCALE_16_TO_8 = UINT64_C(1) << 3
} png4cj_capability;

uint32_t png4cj_preview_abi_version(void);
uint64_t png4cj_capabilities(void);

png4cj_status png4cj_libpng_version(
    uint8_t *output,
    size_t output_capacity,
    size_t *required
);

png4cj_status png4cj_check_signature(
    const uint8_t *input,
    size_t input_size,
    int32_t *is_png,
    uint8_t *message,
    size_t message_capacity
);

png4cj_status png4cj_decode_rgba8(
    const uint8_t *input,
    size_t input_size,
    uint8_t *output,
    size_t output_capacity,
    uint32_t *width,
    uint32_t *height,
    size_t *stride,
    size_t *required,
    int32_t *error_kind,
    int64_t *error_offset,
    uint8_t *message,
    size_t message_capacity
);

#ifdef __cplusplus
}
#endif

#endif
