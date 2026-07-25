#include "png.h"

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

static int signatures_are_exact(void) {
    int (*buffer_fn)(char *, png_const_timep) =
        png_convert_to_rfc1123_buffer;
    png_const_charp (*owner_fn)(png_structrp, png_const_timep) =
        png_convert_to_rfc1123;
    return buffer_fn != NULL && owner_fn != NULL;
}

static int buffer_null_out_returns_zero(void) {
    png_time value = {2026, 7, 25, 9, 30, 45};
    return png_convert_to_rfc1123_buffer(NULL, &value) == 0;
}

static int buffer_null_ptime_returns_zero(void) {
    char output[29];
    memset(output, 0x11, sizeof(output));
    return png_convert_to_rfc1123_buffer(output, NULL) == 0;
}

static int buffer_formats_valid_date(void) {
    png_time value = {2023, 4, 15, 12, 34, 56};
    char output[29];
    memset(output, 0, sizeof(output));
    if (png_convert_to_rfc1123_buffer(output, &value) != 1) return 0;
    return strcmp(output, "15 Apr 2023 12:34:56 +0000") == 0;
}

static int buffer_formats_single_digit_day_and_year(void) {
    png_time value = {1, 1, 1, 0, 0, 0};
    char output[29];
    memset(output, 0, sizeof(output));
    if (png_convert_to_rfc1123_buffer(output, &value) != 1) return 0;
    return strcmp(output, "1 Jan 1 00:00:00 +0000") == 0;
}

static int buffer_output_is_exactly_29_bytes(void) {
    png_time value = {2026, 7, 25, 9, 30, 45};
    unsigned char output[29];
    memset(output, 0, sizeof(output));
    if (png_convert_to_rfc1123_buffer((char *)output, &value) != 1) return 0;
    return output[20] == ' ' && output[21] == '+' && output[22] == '0' &&
        output[23] == '0' && output[24] == '0' && output[25] == '0' &&
        output[26] == '\0' && output[27] == '\0' && output[28] == '\0';
}

static int buffer_rejects_year_overflow(void) {
    png_time value = {10000, 1, 1, 0, 0, 0};
    char output[29];
    memset(output, 0, sizeof(output));
    return png_convert_to_rfc1123_buffer(output, &value) == 0;
}

static int buffer_rejects_month_zero(void) {
    png_time value = {2026, 0, 1, 0, 0, 0};
    char output[29];
    memset(output, 0, sizeof(output));
    return png_convert_to_rfc1123_buffer(output, &value) == 0;
}

static int buffer_rejects_month_overflow(void) {
    png_time value = {2026, 13, 1, 0, 0, 0};
    char output[29];
    memset(output, 0, sizeof(output));
    return png_convert_to_rfc1123_buffer(output, &value) == 0;
}

static int buffer_rejects_day_zero(void) {
    png_time value = {2026, 1, 0, 0, 0, 0};
    char output[29];
    memset(output, 0, sizeof(output));
    return png_convert_to_rfc1123_buffer(output, &value) == 0;
}

static int buffer_rejects_day_overflow(void) {
    png_time value = {2026, 1, 32, 0, 0, 0};
    char output[29];
    memset(output, 0, sizeof(output));
    return png_convert_to_rfc1123_buffer(output, &value) == 0;
}

static int buffer_rejects_hour_overflow(void) {
    png_time value = {2026, 1, 1, 24, 0, 0};
    char output[29];
    memset(output, 0, sizeof(output));
    return png_convert_to_rfc1123_buffer(output, &value) == 0;
}

static int buffer_rejects_minute_overflow(void) {
    png_time value = {2026, 1, 1, 0, 60, 0};
    char output[29];
    memset(output, 0, sizeof(output));
    return png_convert_to_rfc1123_buffer(output, &value) == 0;
}

static int buffer_accepts_leap_second(void) {
    png_time value = {2016, 12, 31, 23, 59, 60};
    char output[29];
    memset(output, 0, sizeof(output));
    if (png_convert_to_rfc1123_buffer(output, &value) != 1) return 0;
    return strcmp(output, "31 Dec 2016 23:59:60 +0000") == 0;
}

static int buffer_rejects_second_overflow(void) {
    png_time value = {2026, 1, 1, 0, 0, 61};
    char output[29];
    memset(output, 0, sizeof(output));
    return png_convert_to_rfc1123_buffer(output, &value) == 0;
}

static int buffer_iterates_all_months(void) {
    static const char *expected[12] = {
        "1 Jan 2026 00:00:00 +0000",
        "1 Feb 2026 00:00:00 +0000",
        "1 Mar 2026 00:00:00 +0000",
        "1 Apr 2026 00:00:00 +0000",
        "1 May 2026 00:00:00 +0000",
        "1 Jun 2026 00:00:00 +0000",
        "1 Jul 2026 00:00:00 +0000",
        "1 Aug 2026 00:00:00 +0000",
        "1 Sep 2026 00:00:00 +0000",
        "1 Oct 2026 00:00:00 +0000",
        "1 Nov 2026 00:00:00 +0000",
        "1 Dec 2026 00:00:00 +0000"
    };
    int month = 1;
    while (month <= 12) {
        png_time value = {2026, (png_byte)month, 1, 0, 0, 0};
        char output[29];
        memset(output, 0, sizeof(output));
        if (png_convert_to_rfc1123_buffer(output, &value) != 1) return 0;
        if (strcmp(output, expected[month - 1]) != 0) return 0;
        month += 1;
    }
    return 1;
}

static void returning_error(png_structp png_ptr, png_const_charp message) {
    (void)png_ptr;
    (void)message;
}

static int owner_null_png_returns_null(void) {
    png_time value = {2026, 7, 25, 9, 30, 45};
    return png_convert_to_rfc1123(NULL, &value) == NULL;
}

static int owner_formats_valid_date(void) {
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    if (png_ptr == NULL) return 0;
    png_time value = {2023, 4, 15, 12, 34, 56};
    png_const_charp result = png_convert_to_rfc1123(png_ptr, &value);
    int ok = result != NULL &&
        strcmp(result, "15 Apr 2023 12:34:56 +0000") == 0;
    png_destroy_read_struct(&png_ptr, NULL, NULL);
    return ok;
}

static int owner_null_ptime_returns_null(void) {
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    if (png_ptr == NULL) return 0;
    png_const_charp result = png_convert_to_rfc1123(png_ptr, NULL);
    int ok = result == NULL;
    png_destroy_read_struct(&png_ptr, NULL, NULL);
    return ok;
}

static int owner_rejects_invalid_input(void) {
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    if (png_ptr == NULL) return 0;
    png_time value = {10000, 1, 1, 0, 0, 0};
    png_const_charp result = png_convert_to_rfc1123(png_ptr, &value);
    int ok = result == NULL;
    png_destroy_read_struct(&png_ptr, NULL, NULL);
    return ok;
}

static int owner_reuses_buffer_across_calls(void) {
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    if (png_ptr == NULL) return 0;
    png_time first = {2023, 4, 15, 12, 34, 56};
    png_const_charp first_result = png_convert_to_rfc1123(png_ptr, &first);
    int ok = first_result != NULL &&
        strcmp(first_result, "15 Apr 2023 12:34:56 +0000") == 0;
    if (ok) {
        png_time second = {2026, 7, 25, 9, 30, 45};
        png_const_charp second_result = png_convert_to_rfc1123(
            png_ptr, &second
        );
        ok = second_result != NULL &&
            strcmp(second_result, "25 Jul 2026 09:30:45 +0000") == 0;
    }
    png_destroy_read_struct(&png_ptr, NULL, NULL);
    return ok;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s DYLIB\n", argv[0]);
        return 2;
    }
    runtime_params_storage params;
    memset(&params, 0, sizeof(params));
    int runtime_ok = InitCJRuntime(&params) == 0;
    int load_ok = runtime_ok && LoadCJLibraryWithInit(argv[1]) == 0;
    int signature_ok = load_ok && signatures_are_exact();
    int buffer_null_out_ok = signature_ok &&
        buffer_null_out_returns_zero();
    int buffer_null_ptime_ok = buffer_null_out_ok &&
        buffer_null_ptime_returns_zero();
    int buffer_valid_ok = buffer_null_ptime_ok &&
        buffer_formats_valid_date();
    int buffer_unpadded_ok = buffer_valid_ok &&
        buffer_formats_single_digit_day_and_year();
    int buffer_29_ok = buffer_unpadded_ok &&
        buffer_output_is_exactly_29_bytes();
    int buffer_year_ok = buffer_29_ok &&
        buffer_rejects_year_overflow();
    int buffer_month_zero_ok = buffer_year_ok &&
        buffer_rejects_month_zero();
    int buffer_month_over_ok = buffer_month_zero_ok &&
        buffer_rejects_month_overflow();
    int buffer_day_zero_ok = buffer_month_over_ok &&
        buffer_rejects_day_zero();
    int buffer_day_over_ok = buffer_day_zero_ok &&
        buffer_rejects_day_overflow();
    int buffer_hour_ok = buffer_day_over_ok &&
        buffer_rejects_hour_overflow();
    int buffer_minute_ok = buffer_hour_ok &&
        buffer_rejects_minute_overflow();
    int buffer_leap_ok = buffer_minute_ok &&
        buffer_accepts_leap_second();
    int buffer_second_ok = buffer_leap_ok &&
        buffer_rejects_second_overflow();
    int buffer_months_ok = buffer_second_ok &&
        buffer_iterates_all_months();
    int owner_null_ok = buffer_months_ok &&
        owner_null_png_returns_null();
    int owner_valid_ok = owner_null_ok &&
        owner_formats_valid_date();
    int owner_null_ptime_ok = owner_valid_ok &&
        owner_null_ptime_returns_null();
    int owner_invalid_ok = owner_null_ptime_ok &&
        owner_rejects_invalid_input();
    int owner_reuse_ok = owner_invalid_ok &&
        owner_reuses_buffer_across_calls();
    int fini_ok = owner_reuse_ok && FiniCJRuntime() == 0;
    int ok = runtime_ok && load_ok && signature_ok && buffer_null_out_ok &&
        buffer_null_ptime_ok && buffer_valid_ok && buffer_unpadded_ok &&
        buffer_29_ok && buffer_year_ok && buffer_month_zero_ok &&
        buffer_month_over_ok && buffer_day_zero_ok && buffer_day_over_ok &&
        buffer_hour_ok && buffer_minute_ok && buffer_leap_ok &&
        buffer_second_ok && buffer_months_ok && owner_null_ok &&
        owner_valid_ok && owner_null_ptime_ok && owner_invalid_ok &&
        owner_reuse_ok && fini_ok;
    if (!ok) {
        fprintf(stderr,
            "time conversion stages runtime=%d load=%d signatures=%d "
            "buf_null_out=%d buf_null_ptime=%d buf_valid=%d "
            "buf_unpadded=%d buf_29=%d buf_year=%d buf_month0=%d "
            "buf_month_over=%d buf_day0=%d buf_day_over=%d buf_hour=%d "
            "buf_minute=%d buf_leap=%d buf_second=%d buf_months=%d "
            "owner_null=%d owner_valid=%d owner_null_ptime=%d "
            "owner_invalid=%d owner_reuse=%d fini=%d\n",
            runtime_ok, load_ok, signature_ok, buffer_null_out_ok,
            buffer_null_ptime_ok, buffer_valid_ok, buffer_unpadded_ok,
            buffer_29_ok, buffer_year_ok, buffer_month_zero_ok,
            buffer_month_over_ok, buffer_day_zero_ok, buffer_day_over_ok,
            buffer_hour_ok, buffer_minute_ok, buffer_leap_ok,
            buffer_second_ok, buffer_months_ok, owner_null_ok,
            owner_valid_ok, owner_null_ptime_ok, owner_invalid_ok,
            owner_reuse_ok, fini_ok);
    }
    printf("libpng4cj classic time conversion consumer: %s\n",
        ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
