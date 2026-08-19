#ifndef LIBPNG4CJ_PNG_IMAGE_H
#define LIBPNG4CJ_PNG_IMAGE_H

/* Frozen libpng 1.6.58 simplified and classic API subset.
 * This is not the complete upstream png.h. The stateful surface currently
 * covers opaque read/write/info ownership, caller-context retention, warning/error
 * callback invocation, fatal fallback termination, custom-allocation
 * ownership, custom/stdio read-info input, core IHDR and fixed metadata getters,
 * raw row delivery, read-end sealing, retained and extended metadata getters,
 * validity, fixed physical conversions, and signature access. Longjmp and
 * transformed/pass-progress row IO and high-level classic writing are not yet
 * implemented. The write subset includes exact signature and raw chunk output.
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
#define PNG_IO_NONE 0x0000u
#define PNG_IO_READING 0x0001u
#define PNG_IO_WRITING 0x0002u
#define PNG_IO_SIGNATURE 0x0010u
#define PNG_IO_CHUNK_HDR 0x0020u
#define PNG_IO_CHUNK_DATA 0x0040u
#define PNG_IO_CHUNK_CRC 0x0080u
#define PNG_IO_MASK_OP 0x000fu
#define PNG_IO_MASK_LOC 0x00f0u
#define PNG_INTERLACE_ADAM7 1
#define PNG_INTERLACE_LAST 2

typedef uint8_t png_byte;
typedef png_byte *png_bytep;
typedef png_bytep *png_bytepp;
typedef const png_byte *png_const_bytep;
typedef uint16_t png_uint_16;
typedef uint32_t png_uint_32;
typedef int32_t png_int_32;
typedef png_int_32 png_fixed_point;
typedef char png_char;
typedef png_char *png_charp;
typedef png_charp *png_charpp;
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
typedef void (*png_flush_ptr)(png_structp);

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

typedef struct png_color_16_struct {
    png_byte index;
    png_uint_16 red;
    png_uint_16 green;
    png_uint_16 blue;
    png_uint_16 gray;
} png_color_16, *png_color_16p;
typedef const png_color_16 *png_const_color_16p;

typedef struct png_color_8_struct {
    png_byte red;
    png_byte green;
    png_byte blue;
    png_byte gray;
    png_byte alpha;
} png_color_8, *png_color_8p;

typedef struct png_sPLT_entry_struct {
    png_uint_16 red;
    png_uint_16 green;
    png_uint_16 blue;
    png_uint_16 alpha;
    png_uint_16 frequency;
} png_sPLT_entry, *png_sPLT_entryp;

typedef struct png_sPLT_struct {
    png_charp name;
    png_byte depth;
    png_sPLT_entryp entries;
    png_int_32 nentries;
} png_sPLT_t, *png_sPLT_tp;
typedef png_sPLT_tp *png_sPLT_tpp;

typedef struct png_text_struct {
    int compression;
    png_charp key;
    png_charp text;
    size_t text_length;
    size_t itxt_length;
    png_charp lang;
    png_charp lang_key;
} png_text, *png_textp;

typedef struct png_time_struct {
    png_uint_16 year;
    png_byte month;
    png_byte day;
    png_byte hour;
    png_byte minute;
    png_byte second;
} png_time, *png_timep;

typedef struct png_unknown_chunk_t {
    png_byte name[5];
    png_bytep data;
    size_t size;
    png_byte location;
} png_unknown_chunk, *png_unknown_chunkp;
typedef png_unknown_chunkp *png_unknown_chunkpp;

#define PNG_INFO_gAMA 0x0001u
#define PNG_INFO_sBIT 0x0002u
#define PNG_INFO_cHRM 0x0004u
#define PNG_INFO_PLTE 0x0008u
#define PNG_INFO_tRNS 0x0010u
#define PNG_INFO_bKGD 0x0020u
#define PNG_INFO_hIST 0x0040u
#define PNG_INFO_pHYs 0x0080u
#define PNG_INFO_oFFs 0x0100u
#define PNG_INFO_tIME 0x0200u
#define PNG_INFO_pCAL 0x0400u
#define PNG_INFO_sRGB 0x0800u
#define PNG_INFO_iCCP 0x1000u
#define PNG_INFO_sPLT 0x2000u
#define PNG_INFO_sCAL 0x4000u
#define PNG_INFO_IDAT 0x8000u
#define PNG_INFO_eXIf 0x10000u
#define PNG_INFO_cICP 0x20000u
#define PNG_INFO_cLLI 0x40000u
#define PNG_INFO_mDCV 0x80000u

#define PNG_RESOLUTION_UNKNOWN 0
#define PNG_RESOLUTION_METER 1
#define PNG_OFFSET_PIXEL 0
#define PNG_OFFSET_MICROMETER 1
#define PNG_SCALE_UNKNOWN 0
#define PNG_SCALE_METER 1
#define PNG_SCALE_RADIAN 2
#define PNG_HAVE_IHDR 0x01
#define PNG_HAVE_PLTE 0x02
#define PNG_AFTER_IDAT 0x08
#define PNG_TEXT_COMPRESSION_NONE -1
#define PNG_TEXT_COMPRESSION_zTXt 0
#define PNG_ITXT_COMPRESSION_NONE 1
#define PNG_ITXT_COMPRESSION_zTXt 2

#define PNG_ERROR_ACTION_NONE 1
#define PNG_ERROR_ACTION_WARN 2
#define PNG_ERROR_ACTION_ERROR 3
#define PNG_RGB_TO_GRAY_DEFAULT (-1)
#define PNG_FILLER_BEFORE 0
#define PNG_FILLER_AFTER 1
#define PNG_BACKGROUND_GAMMA_UNKNOWN 0
#define PNG_BACKGROUND_GAMMA_SCREEN 1
#define PNG_BACKGROUND_GAMMA_FILE 2
#define PNG_BACKGROUND_GAMMA_UNIQUE 3

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
png_uint_32 png_get_uint_31(
    png_const_structp png_ptr,
    png_const_bytep buf
);
void png_save_uint_32(png_bytep buf, png_uint_32 i);
void png_save_int_32(png_bytep buf, png_int_32 i);
void png_save_uint_16(png_bytep buf, unsigned int i);
void png_build_grayscale_palette(int bit_depth, png_colorp palette);
png_const_charp png_get_copyright(png_const_structp png_ptr);
png_const_charp png_get_header_ver(png_const_structp png_ptr);
png_const_charp png_get_header_version(png_const_structp png_ptr);
png_const_charp png_get_libpng_ver(png_const_structp png_ptr);

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
png_structp png_create_write_struct(
    png_const_charp user_png_ver,
    png_voidp error_ptr,
    png_error_ptr error_fn,
    png_error_ptr warn_fn
);
png_structp png_create_write_struct_2(
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
void png_destroy_write_struct(
    png_structpp png_ptr_ptr,
    png_infopp info_ptr_ptr
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
void png_set_write_fn(
    png_structp png_ptr,
    png_voidp io_ptr,
    png_rw_ptr write_data_fn,
    png_flush_ptr output_flush_fn
);
png_voidp png_get_io_ptr(png_const_structp png_ptr);
void png_write_sig(png_structp png_ptr);
void png_write_chunk(
    png_structp png_ptr,
    png_const_bytep chunk_name,
    png_const_bytep data,
    size_t length
);
void png_write_chunk_start(
    png_structp png_ptr,
    png_const_bytep chunk_name,
    png_uint_32 length
);
void png_write_chunk_data(
    png_structp png_ptr,
    png_const_bytep data,
    size_t length
);
void png_write_chunk_end(png_structp png_ptr);
void png_write_flush(png_structp png_ptr);
void png_set_sig_bytes(png_structp png_ptr, int num_bytes);
void png_read_info(png_structp png_ptr, png_infop info_ptr);
void png_set_expand(png_structp png_ptr);
void png_set_expand_gray_1_2_4_to_8(png_structp png_ptr);
void png_set_palette_to_rgb(png_structp png_ptr);
void png_set_tRNS_to_alpha(png_structp png_ptr);
void png_set_expand_16(png_structp png_ptr);
void png_set_gray_to_rgb(png_structp png_ptr);
void png_set_rgb_to_gray(
    png_structp png_ptr,
    int error_action,
    double red,
    double green
);
void png_set_rgb_to_gray_fixed(
    png_structp png_ptr,
    int error_action,
    png_fixed_point red,
    png_fixed_point green
);
void png_set_strip_alpha(png_structp png_ptr);
void png_set_scale_16(png_structp png_ptr);
void png_set_strip_16(png_structp png_ptr);
void png_set_gamma(
    png_structp png_ptr,
    double screen_gamma,
    double file_gamma
);
void png_set_gamma_fixed(
    png_structp png_ptr,
    png_fixed_point screen_gamma,
    png_fixed_point file_gamma
);
void png_set_background(
    png_structp png_ptr,
    png_const_color_16p background_color,
    int background_gamma_code,
    int need_expand,
    double background_gamma
);
void png_set_background_fixed(
    png_structp png_ptr,
    png_const_color_16p background_color,
    int background_gamma_code,
    int need_expand,
    png_fixed_point background_gamma
);
void png_set_check_for_invalid_index(png_structp png_ptr, int allowed);
void png_start_read_image(png_structp png_ptr);
void png_read_update_info(png_structp png_ptr, png_infop info_ptr);
void png_read_rows(
    png_structp png_ptr,
    png_bytepp row,
    png_bytepp display_row,
    png_uint_32 num_rows
);
void png_read_row(
    png_structp png_ptr,
    png_bytep row,
    png_bytep display_row
);
void png_read_image(png_structp png_ptr, png_bytepp image);
void png_read_end(png_structp png_ptr, png_infop info_ptr);
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
png_uint_32 png_get_valid(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_uint_32 flag
);
png_uint_32 png_get_pixels_per_meter(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_uint_32 png_get_x_pixels_per_meter(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_uint_32 png_get_y_pixels_per_meter(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_fixed_point png_get_pixel_aspect_ratio_fixed(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
float png_get_pixel_aspect_ratio(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_int_32 png_get_x_offset_pixels(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_int_32 png_get_y_offset_pixels(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_int_32 png_get_x_offset_microns(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_int_32 png_get_y_offset_microns(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_const_bytep png_get_signature(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_uint_32 png_get_pixels_per_inch(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_uint_32 png_get_x_pixels_per_inch(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_uint_32 png_get_y_pixels_per_inch(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_fixed_point png_get_x_offset_inches_fixed(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_fixed_point png_get_y_offset_inches_fixed(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
float png_get_x_offset_inches(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
float png_get_y_offset_inches(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_uint_32 png_get_pHYs_dpi(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_uint_32 *res_x,
    png_uint_32 *res_y,
    int *unit_type
);
png_uint_32 png_get_gAMA_fixed(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_fixed_point *file_gamma
);
png_uint_32 png_get_gAMA(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    double *file_gamma
);
png_uint_32 png_get_cHRM_fixed(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_fixed_point *white_x,
    png_fixed_point *white_y,
    png_fixed_point *red_x,
    png_fixed_point *red_y,
    png_fixed_point *green_x,
    png_fixed_point *green_y,
    png_fixed_point *blue_x,
    png_fixed_point *blue_y
);
png_uint_32 png_get_cHRM(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    double *white_x,
    double *white_y,
    double *red_x,
    double *red_y,
    double *green_x,
    double *green_y,
    double *blue_x,
    double *blue_y
);
png_uint_32 png_get_cHRM_XYZ(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    double *red_X,
    double *red_Y,
    double *red_Z,
    double *green_X,
    double *green_Y,
    double *green_Z,
    double *blue_X,
    double *blue_Y,
    double *blue_Z
);
png_uint_32 png_get_cHRM_XYZ_fixed(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_fixed_point *red_X,
    png_fixed_point *red_Y,
    png_fixed_point *red_Z,
    png_fixed_point *green_X,
    png_fixed_point *green_Y,
    png_fixed_point *green_Z,
    png_fixed_point *blue_X,
    png_fixed_point *blue_Y,
    png_fixed_point *blue_Z
);
png_uint_32 png_get_oFFs(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_int_32 *offset_x,
    png_int_32 *offset_y,
    int *unit_type
);
png_uint_32 png_get_cICP(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_bytep color_primaries,
    png_bytep transfer_function,
    png_bytep matrix_coefficients,
    png_bytep full_range_flag
);
png_uint_32 png_get_cLLI_fixed(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_uint_32 *maximum_content_light_level,
    png_uint_32 *maximum_frame_average_light_level
);
png_uint_32 png_get_cLLI(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    double *maximum_content_light_level,
    double *maximum_frame_average_light_level
);
png_uint_32 png_get_mDCV_fixed(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_fixed_point *white_x,
    png_fixed_point *white_y,
    png_fixed_point *red_x,
    png_fixed_point *red_y,
    png_fixed_point *green_x,
    png_fixed_point *green_y,
    png_fixed_point *blue_x,
    png_fixed_point *blue_y,
    png_uint_32 *maximum_display_luminance,
    png_uint_32 *minimum_display_luminance
);
png_uint_32 png_get_mDCV(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    double *white_x,
    double *white_y,
    double *red_x,
    double *red_y,
    double *green_x,
    double *green_y,
    double *blue_x,
    double *blue_y,
    double *maximum_display_luminance,
    double *minimum_display_luminance
);
png_uint_32 png_get_sRGB(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    int *file_srgb_intent
);
png_uint_32 png_get_sBIT(
    png_const_structp png_ptr,
    png_infop info_ptr,
    png_color_8p *sig_bit
);
png_uint_32 png_get_bKGD(
    png_const_structp png_ptr,
    png_infop info_ptr,
    png_color_16p *background
);
png_uint_32 png_get_pHYs(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_uint_32 *res_x,
    png_uint_32 *res_y,
    int *unit_type
);
png_uint_32 png_get_PLTE(
    png_const_structp png_ptr,
    png_infop info_ptr,
    png_colorp *palette,
    int *num_palette
);
png_uint_32 png_get_tRNS(
    png_const_structp png_ptr,
    png_infop info_ptr,
    png_bytep *trans_alpha,
    int *num_trans,
    png_color_16p *trans_color
);
png_uint_32 png_get_eXIf(
    png_const_structp png_ptr,
    png_infop info_ptr,
    png_bytep *exif
);
png_uint_32 png_get_eXIf_1(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    png_uint_32 *num_exif,
    png_bytep *exif
);
png_uint_32 png_get_hIST(
    png_const_structp png_ptr,
    png_infop info_ptr,
    png_uint_16 **hist
);
png_uint_32 png_get_iCCP(
    png_const_structp png_ptr,
    png_infop info_ptr,
    png_charpp name,
    int *compression_type,
    png_bytepp profile,
    png_uint_32 *profile_length
);
png_uint_32 png_get_pCAL(
    png_const_structp png_ptr,
    png_infop info_ptr,
    png_charp *purpose,
    png_int_32 *x0,
    png_int_32 *x1,
    int *equation_type,
    int *parameter_count,
    png_charp *units,
    png_charpp *parameters
);
png_bytepp png_get_rows(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_uint_32 png_get_sCAL(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    int *unit,
    double *width,
    double *height
);
png_uint_32 png_get_sCAL_fixed(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    int *unit,
    png_fixed_point *width,
    png_fixed_point *height
);
png_uint_32 png_get_sCAL_s(
    png_const_structp png_ptr,
    png_const_infop info_ptr,
    int *unit,
    png_charpp width,
    png_charpp height
);
int png_get_sPLT(
    png_const_structp png_ptr,
    png_infop info_ptr,
    png_sPLT_tpp entries
);
png_uint_32 png_get_tIME(
    png_const_structp png_ptr,
    png_infop info_ptr,
    png_timep *modification_time
);
int png_get_text(
    png_const_structp png_ptr,
    png_infop info_ptr,
    png_textp *text,
    int *text_count
);
int png_get_unknown_chunks(
    png_const_structp png_ptr,
    png_infop info_ptr,
    png_unknown_chunkpp entries
);
void png_set_user_limits(
    png_structp png_ptr,
    png_uint_32 user_width_max,
    png_uint_32 user_height_max
);
void png_set_chunk_malloc_max(
    png_structp png_ptr,
    png_alloc_size_t user_chunk_malloc_max
);
png_uint_32 png_get_chunk_cache_max(png_const_structp png_ptr);
png_alloc_size_t png_get_chunk_malloc_max(png_const_structp png_ptr);
size_t png_get_compression_buffer_size(png_const_structp png_ptr);
png_byte png_get_current_pass_number(png_const_structp png_ptr);
png_uint_32 png_get_current_row_number(png_const_structp png_ptr);
png_uint_32 png_get_io_chunk_type(png_const_structp png_ptr);
png_uint_32 png_get_io_state(png_const_structp png_ptr);
int png_get_palette_max(
    png_const_structp png_ptr,
    png_const_infop info_ptr
);
png_voidp png_get_progressive_ptr(png_const_structp png_ptr);
png_byte png_get_rgb_to_gray_status(png_const_structp png_ptr);
png_voidp png_get_user_chunk_ptr(png_const_structp png_ptr);
png_uint_32 png_get_user_height_max(png_const_structp png_ptr);
png_voidp png_get_user_transform_ptr(png_const_structp png_ptr);
png_uint_32 png_get_user_width_max(png_const_structp png_ptr);
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
