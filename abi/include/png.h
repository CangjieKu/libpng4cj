#ifndef LIBPNG4CJ_PNG_IMAGE_H
#define LIBPNG4CJ_PNG_IMAGE_H

/* Frozen libpng 1.6.58 simplified and classic API subset.
 * This is not the complete upstream png.h. The stateful surface currently
 * covers opaque read/info ownership, caller-context retention, warning/error
 * callback invocation, fatal fallback termination, custom-allocation
 * ownership, custom/stdio read-info input, and core IHDR getters. Longjmp and
 * row IO are not yet implemented.
 */

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PNG_IMAGE_VERSION 1u
#define PNG_IMAGE_WARNING 1u
#define PNG_IMAGE_ERROR 2u
#define PNG_IMAGE_FAILED(image) ((((image).warning_or_error) & 0x03u) > 1u)
#define PNG_LIBPNG_VER 10658
#define PNG_LIBPNG_VER_STRING "1.6.58"

#define PNG_COLOR_MASK_PALETTE 1
#define PNG_COLOR_MASK_COLOR 2
#define PNG_COLOR_MASK_ALPHA 4
#define PNG_COLOR_TYPE_GRAY 0
#define PNG_COLOR_TYPE_PALETTE \
    (PNG_COLOR_MASK_COLOR | PNG_COLOR_MASK_PALETTE)
#define PNG_COLOR_TYPE_RGB PNG_COLOR_MASK_COLOR
#define PNG_COLOR_TYPE_RGB_ALPHA \
    (PNG_COLOR_MASK_COLOR | PNG_COLOR_MASK_ALPHA)
#define PNG_COLOR_TYPE_GRAY_ALPHA PNG_COLOR_MASK_ALPHA
#define PNG_COLOR_TYPE_RGBA PNG_COLOR_TYPE_RGB_ALPHA
#define PNG_COLOR_TYPE_GA PNG_COLOR_TYPE_GRAY_ALPHA
#define PNG_COMPRESSION_TYPE_BASE 0
#define PNG_COMPRESSION_TYPE_DEFAULT PNG_COMPRESSION_TYPE_BASE
#define PNG_FILTER_TYPE_BASE 0
#define PNG_FILTER_TYPE_DEFAULT PNG_FILTER_TYPE_BASE
#define PNG_INTERLACE_NONE 0
#define PNG_INTERLACE_ADAM7 1
#define PNG_INTERLACE_LAST 2

typedef uint8_t png_byte;
typedef png_byte *png_bytep;
typedef const png_byte *png_const_bytep;
typedef uint16_t png_uint_16;
typedef uint32_t png_uint_32;
typedef int32_t png_int_32;
typedef char png_char;
typedef png_char *png_charp;
typedef const png_char *png_const_charp;
typedef void *png_voidp;
typedef const void *png_const_voidp;
typedef size_t png_alloc_size_t;

typedef struct png_struct_def png_struct;
typedef const png_struct *png_const_structp;
typedef png_struct *png_structp;
typedef png_struct **png_structpp;
typedef struct png_info_def png_info;
typedef png_info *png_infop;
typedef const png_info *png_const_infop;
typedef png_info **png_infopp;

typedef void (*png_error_ptr)(png_structp, png_const_charp);
typedef png_voidp (*png_malloc_ptr)(png_structp, png_alloc_size_t);
typedef void (*png_free_ptr)(png_structp, png_voidp);
typedef void (*png_rw_ptr)(png_structp, png_bytep, size_t);

typedef void *png_controlp;
typedef struct png_image {
    png_controlp opaque;
    uint32_t version;
    uint32_t width;
    uint32_t height;
    uint32_t format;
    uint32_t flags;
    uint32_t colormap_entries;
    uint32_t warning_or_error;
    char message[64];
} png_image, *png_imagep;

typedef struct png_color {
    uint8_t red;
    uint8_t green;
    uint8_t blue;
} png_color, *png_colorp;
typedef const png_color *png_const_colorp;

#define PNG_FORMAT_FLAG_ALPHA 0x01u
#define PNG_FORMAT_FLAG_COLOR 0x02u
#define PNG_FORMAT_FLAG_LINEAR 0x04u
#define PNG_FORMAT_FLAG_COLORMAP 0x08u
#define PNG_FORMAT_FLAG_BGR 0x10u
#define PNG_FORMAT_FLAG_AFIRST 0x20u
#define PNG_FORMAT_FLAG_ASSOCIATED_ALPHA 0x40u

#define PNG_FORMAT_GRAY 0u
#define PNG_FORMAT_GA PNG_FORMAT_FLAG_ALPHA
#define PNG_FORMAT_AG (PNG_FORMAT_GA | PNG_FORMAT_FLAG_AFIRST)
#define PNG_FORMAT_RGB PNG_FORMAT_FLAG_COLOR
#define PNG_FORMAT_BGR (PNG_FORMAT_FLAG_COLOR | PNG_FORMAT_FLAG_BGR)
#define PNG_FORMAT_RGBA (PNG_FORMAT_RGB | PNG_FORMAT_FLAG_ALPHA)
#define PNG_FORMAT_ARGB (PNG_FORMAT_RGBA | PNG_FORMAT_FLAG_AFIRST)
#define PNG_FORMAT_BGRA (PNG_FORMAT_BGR | PNG_FORMAT_FLAG_ALPHA)
#define PNG_FORMAT_ABGR (PNG_FORMAT_BGRA | PNG_FORMAT_FLAG_AFIRST)
#define PNG_FORMAT_LINEAR_Y PNG_FORMAT_FLAG_LINEAR
#define PNG_FORMAT_LINEAR_Y_ALPHA (PNG_FORMAT_FLAG_LINEAR | PNG_FORMAT_FLAG_ALPHA)
#define PNG_FORMAT_LINEAR_RGB (PNG_FORMAT_FLAG_LINEAR | PNG_FORMAT_FLAG_COLOR)
#define PNG_FORMAT_LINEAR_RGB_ALPHA \
    (PNG_FORMAT_FLAG_LINEAR | PNG_FORMAT_FLAG_COLOR | PNG_FORMAT_FLAG_ALPHA)
#define PNG_FORMAT_RGB_COLORMAP (PNG_FORMAT_RGB | PNG_FORMAT_FLAG_COLORMAP)
#define PNG_FORMAT_BGR_COLORMAP (PNG_FORMAT_BGR | PNG_FORMAT_FLAG_COLORMAP)
#define PNG_FORMAT_RGBA_COLORMAP (PNG_FORMAT_RGBA | PNG_FORMAT_FLAG_COLORMAP)
#define PNG_FORMAT_ARGB_COLORMAP (PNG_FORMAT_ARGB | PNG_FORMAT_FLAG_COLORMAP)
#define PNG_FORMAT_BGRA_COLORMAP (PNG_FORMAT_BGRA | PNG_FORMAT_FLAG_COLORMAP)
#define PNG_FORMAT_ABGR_COLORMAP (PNG_FORMAT_ABGR | PNG_FORMAT_FLAG_COLORMAP)

#define PNG_IMAGE_SAMPLE_CHANNELS(format) \
    (((format) & (PNG_FORMAT_FLAG_COLOR | PNG_FORMAT_FLAG_ALPHA)) + 1u)
#define PNG_IMAGE_SAMPLE_COMPONENT_SIZE(format) \
    ((((format) & PNG_FORMAT_FLAG_LINEAR) >> 2) + 1u)
#define PNG_IMAGE_SAMPLE_SIZE(format) \
    (PNG_IMAGE_SAMPLE_CHANNELS(format) * PNG_IMAGE_SAMPLE_COMPONENT_SIZE(format))
#define PNG_IMAGE_MAXIMUM_COLORMAP_COMPONENTS(format) \
    (PNG_IMAGE_SAMPLE_CHANNELS(format) * 256u)
#define PNG_IMAGE_PIXEL_(test, format) \
    (((format) & PNG_FORMAT_FLAG_COLORMAP) ? 1u : test(format))
#define PNG_IMAGE_PIXEL_CHANNELS(format) \
    PNG_IMAGE_PIXEL_(PNG_IMAGE_SAMPLE_CHANNELS, format)
#define PNG_IMAGE_PIXEL_COMPONENT_SIZE(format) \
    PNG_IMAGE_PIXEL_(PNG_IMAGE_SAMPLE_COMPONENT_SIZE, format)
#define PNG_IMAGE_PIXEL_SIZE(format) PNG_IMAGE_PIXEL_(PNG_IMAGE_SAMPLE_SIZE, format)
#define PNG_IMAGE_ROW_STRIDE(image) \
    (PNG_IMAGE_PIXEL_CHANNELS((image).format) * (image).width)
#define PNG_IMAGE_BUFFER_SIZE(image, row_stride) \
    (PNG_IMAGE_PIXEL_COMPONENT_SIZE((image).format) * (image).height * (row_stride))
#define PNG_IMAGE_SIZE(image) PNG_IMAGE_BUFFER_SIZE(image, PNG_IMAGE_ROW_STRIDE(image))
#define PNG_IMAGE_COLORMAP_SIZE(image) \
    (PNG_IMAGE_SAMPLE_SIZE((image).format) * (image).colormap_entries)

#define PNG_IMAGE_FLAG_COLORSPACE_NOT_sRGB 0x01u
#define PNG_IMAGE_FLAG_FAST 0x02u
#define PNG_IMAGE_FLAG_16BIT_sRGB 0x04u

png_uint_32 png_access_version_number(void);
int png_sig_cmp(png_const_bytep sig, size_t start, size_t num_to_check);
png_uint_32 png_get_uint_32(png_const_bytep buf);
png_uint_16 png_get_uint_16(png_const_bytep buf);
png_int_32 png_get_int_32(png_const_bytep buf);
void png_save_uint_32(png_bytep buf, png_uint_32 i);
void png_save_int_32(png_bytep buf, png_int_32 i);
void png_save_uint_16(png_bytep buf, unsigned int i);

png_structp png_create_read_struct(
    png_const_charp user_png_ver,
    png_voidp error_ptr,
    png_error_ptr error_fn,
    png_error_ptr warn_fn
);
png_structp png_create_read_struct_2(
    png_const_charp user_png_ver,
    png_voidp error_ptr,
    png_error_ptr error_fn,
    png_error_ptr warn_fn,
    png_voidp mem_ptr,
    png_malloc_ptr malloc_fn,
    png_free_ptr free_fn
);
png_infop png_create_info_struct(png_const_structp png_ptr);
void png_destroy_info_struct(
    png_const_structp png_ptr,
    png_infopp info_ptr_ptr
);
void png_destroy_read_struct(
    png_structpp png_ptr_ptr,
    png_infopp info_ptr_ptr,
    png_infopp end_info_ptr_ptr
);
void png_set_error_fn(
    png_structp png_ptr,
    png_voidp error_ptr,
    png_error_ptr error_fn,
    png_error_ptr warning_fn
);
png_voidp png_get_error_ptr(png_const_structp png_ptr);
void png_set_mem_fn(
    png_structp png_ptr,
    png_voidp mem_ptr,
    png_malloc_ptr malloc_fn,
    png_free_ptr free_fn
);
png_voidp png_get_mem_ptr(png_const_structp png_ptr);
void png_init_io(png_structp png_ptr, FILE *fp);
void png_set_read_fn(
    png_structp png_ptr,
    png_voidp io_ptr,
    png_rw_ptr read_data_fn
);
png_voidp png_get_io_ptr(png_const_structp png_ptr);
void png_set_sig_bytes(png_structp png_ptr, int num_bytes);
void png_read_info(png_structp png_ptr, png_infop info_ptr);
size_t png_get_rowbytes(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_byte png_get_channels(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_uint_32 png_get_image_width(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_uint_32 png_get_image_height(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_byte png_get_bit_depth(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_byte png_get_color_type(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_byte png_get_filter_type(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_byte png_get_interlace_type(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_byte png_get_compression_type(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_uint_32 png_get_IHDR(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_uint_32 *width,
    png_uint_32 *height,
    int *bit_depth,
    int *color_type,
    int *interlace_method,
    int *compression_method,
    int *filter_method
);
png_voidp png_malloc(
    png_const_structp png_ptr,
    png_alloc_size_t size
);
png_voidp png_calloc(
    png_const_structp png_ptr,
    png_alloc_size_t size
);
png_voidp png_malloc_warn(
    png_const_structp png_ptr,
    png_alloc_size_t size
);
png_voidp png_malloc_default(
    png_const_structp png_ptr,
    png_alloc_size_t size
);
void png_free(png_const_structp png_ptr, png_voidp ptr);
void png_free_default(png_const_structp png_ptr, png_voidp ptr);
void png_warning(
    png_const_structp png_ptr,
    png_const_charp warning_message
);
_Noreturn void png_error(
    png_const_structp png_ptr,
    png_const_charp error_message
);

int png_image_begin_read_from_memory(
    png_imagep image,
    const void *memory,
    size_t size
);
int png_image_begin_read_from_file(png_imagep image, const char *file_name);
int png_image_begin_read_from_stdio(png_imagep image, FILE *file);
int png_image_finish_read(
    png_imagep image,
    png_const_colorp background,
    void *buffer,
    int32_t row_stride,
    void *colormap
);
void png_image_free(png_imagep image);
int png_image_write_to_memory(
    png_imagep image,
    void *memory,
    size_t *memory_bytes,
    int convert_to_8bit,
    const void *buffer,
    int32_t row_stride,
    const void *colormap
);
int png_image_write_to_file(
    png_imagep image,
    const char *file_name,
    int convert_to_8bit,
    const void *buffer,
    int32_t row_stride,
    const void *colormap
);
int png_image_write_to_stdio(
    png_imagep image,
    FILE *file,
    int convert_to_8bit,
    const void *buffer,
    int32_t row_stride,
    const void *colormap
);

#ifdef __cplusplus
}
#endif

#endif
