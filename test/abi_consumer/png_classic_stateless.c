#include <png.h>

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

extern int64_t InitCJRuntime(void *params);
extern int64_t LoadCJLibraryWithInit(const char *path);
extern int64_t FiniCJRuntime(void);

_Static_assert(sizeof(png_byte) == 1, "png_byte width");
_Static_assert(sizeof(png_uint_16) == 2, "png_uint_16 width");
_Static_assert(sizeof(png_uint_32) == 4, "png_uint_32 width");
_Static_assert(sizeof(png_int_32) == 4, "png_int_32 width");

static const png_byte upstream_signature[8] = {
    137, 80, 78, 71, 13, 10, 26, 10
};

static int upstream_sig_cmp(
    png_const_bytep sig,
    size_t start,
    size_t num_to_check
) {
    if (num_to_check > 8) num_to_check = 8;
    else if (num_to_check < 1) return -1;
    if (start > 7) return -1;
    if (start + num_to_check > 8) num_to_check = 8 - start;
    return memcmp(sig + start, upstream_signature + start, num_to_check);
}

static png_uint_32 upstream_get_uint_32(png_const_bytep buf) {
    return ((png_uint_32)buf[0] << 24) |
        ((png_uint_32)buf[1] << 16) |
        ((png_uint_32)buf[2] << 8) |
        (png_uint_32)buf[3];
}

static png_int_32 upstream_get_int_32(png_const_bytep buf) {
    png_uint_32 value = upstream_get_uint_32(buf);
    if ((value & UINT32_C(0x80000000)) == 0) return (png_int_32)value;
    value = (value ^ UINT32_C(0xffffffff)) + 1u;
    if ((value & UINT32_C(0x80000000)) == 0) return -(png_int_32)value;
    return 0;
}

static int same_sign(int left, int right) {
    return (left == 0 && right == 0) || (left < 0 && right < 0) ||
        (left > 0 && right > 0);
}

static int test_signatures(void) {
    png_byte exact[8];
    memcpy(exact, upstream_signature, sizeof(exact));
    png_byte lower[8];
    png_byte higher[8];
    memcpy(lower, exact, sizeof(lower));
    memcpy(higher, exact, sizeof(higher));
    lower[3] = 0;
    higher[5] = 255;

    static const size_t starts[] = {0, 1, 7, 8, 9};
    static const size_t counts[] = {0, 1, 2, 8, 9, 64};
    png_const_bytep vectors[] = {exact, lower, higher};
    for (size_t v = 0; v < sizeof(vectors) / sizeof(vectors[0]); ++v) {
        for (size_t s = 0; s < sizeof(starts) / sizeof(starts[0]); ++s) {
            for (size_t c = 0; c < sizeof(counts) / sizeof(counts[0]); ++c) {
                int expected = upstream_sig_cmp(vectors[v], starts[s], counts[c]);
                int actual = png_sig_cmp(vectors[v], starts[s], counts[c]);
                if (!same_sign(actual, expected)) return 0;
            }
        }
    }
    return 1;
}

static int test_reads(void) {
    static const png_byte unsigned_vectors[][4] = {
        {0x00, 0x00, 0x00, 0x00},
        {0x12, 0x34, 0x56, 0x78},
        {0xff, 0xff, 0xff, 0xff},
        {0x80, 0x00, 0x00, 0x00}
    };
    for (size_t i = 0; i < sizeof(unsigned_vectors) / sizeof(unsigned_vectors[0]); ++i) {
        if (png_get_uint_32(unsigned_vectors[i]) !=
            upstream_get_uint_32(unsigned_vectors[i])) return 0;
        if (png_get_int_32(unsigned_vectors[i]) !=
            upstream_get_int_32(unsigned_vectors[i])) return 0;
    }
    const png_byte negative_limit[] = {0x80, 0x00, 0x00, 0x01};
    const png_byte minus_one[] = {0xff, 0xff, 0xff, 0xff};
    const png_byte uint16_value[] = {0xab, 0xcd};
    return png_get_int_32(negative_limit) == INT32_C(-2147483647) &&
        png_get_int_32(minus_one) == -1 &&
        png_get_uint_16(uint16_value) == UINT16_C(0xabcd);
}

static int test_writes(void) {
    png_byte bytes[4] = {0, 0, 0, 0};
    png_save_uint_32(bytes, UINT32_C(0x12345678));
    if (memcmp(bytes, (png_byte[]){0x12, 0x34, 0x56, 0x78}, 4) != 0) return 0;
    png_save_int_32(bytes, INT32_C(-2147483647));
    if (memcmp(bytes, (png_byte[]){0x80, 0x00, 0x00, 0x01}, 4) != 0) return 0;
    png_save_int_32(bytes, INT32_MIN);
    if (memcmp(bytes, (png_byte[]){0x80, 0x00, 0x00, 0x00}, 4) != 0) return 0;
    png_save_uint_16(bytes, 0x123456u);
    return bytes[0] == 0x34 && bytes[1] == 0x56;
}

int main(int argc, char **argv) {
    png_uint_32 (*version_fn)(void) = png_access_version_number;
    int (*signature_fn)(png_const_bytep, size_t, size_t) = png_sig_cmp;
    png_uint_32 (*read32_fn)(png_const_bytep) = png_get_uint_32;
    png_uint_16 (*read16_fn)(png_const_bytep) = png_get_uint_16;
    png_int_32 (*read_int32_fn)(png_const_bytep) = png_get_int_32;
    void (*write32_fn)(png_bytep, png_uint_32) = png_save_uint_32;
    void (*write_int32_fn)(png_bytep, png_int_32) = png_save_int_32;
    void (*write16_fn)(png_bytep, unsigned int) = png_save_uint_16;
    if (argc != 2) {
        fprintf(stderr, "usage: %s DYLIB\n", argv[0]);
        return 2;
    }
    max_align_t runtime_params[64];
    memset(runtime_params, 0, sizeof(runtime_params));
    if (InitCJRuntime(runtime_params) != 0 ||
        LoadCJLibraryWithInit(argv[1]) != 0) {
        fprintf(stderr, "failed to initialize Cangjie runtime\n");
        return 3;
    }
    int ok = version_fn() == PNG_LIBPNG_VER && signature_fn != NULL &&
        read32_fn != NULL && read16_fn != NULL && read_int32_fn != NULL &&
        write32_fn != NULL && write_int32_fn != NULL && write16_fn != NULL &&
        test_signatures() && test_reads() && test_writes();
    if (FiniCJRuntime() != 0) ok = 0;
    if (!ok) return 4;
    printf("libpng4cj classic stateless ABI: PASS\n");
    return 0;
}
