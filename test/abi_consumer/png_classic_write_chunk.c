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

typedef struct write_context {
    unsigned char *bytes;
    size_t capacity;
    size_t size;
    int calls;
    int flush_calls;
    int ok;
    png_structp expected_handle;
} write_context;

typedef struct allocator_context {
    int allocations;
    int frees;
    int ok;
    png_structp expected_handle;
} allocator_context;

static uint32_t read_u32be(const unsigned char *bytes) {
    return ((uint32_t)bytes[0] << 24) |
        ((uint32_t)bytes[1] << 16) |
        ((uint32_t)bytes[2] << 8) |
        (uint32_t)bytes[3];
}

static void returning_error(png_structp png_ptr, png_const_charp message) {
    (void)png_ptr;
    (void)message;
}

static void expected_error(png_structp png_ptr, png_const_charp message) {
    int *expected = png_get_error_ptr(png_ptr);
    if (expected != NULL && *expected == 83 && message != NULL &&
        strcmp(message,
            "png_write_chunk_end: declared length not satisfied") == 0) {
        _Exit(83);
    }
    if (expected != NULL && *expected == 84 && message != NULL &&
        strcmp(message,
            "png_write_chunk_data: declared length exceeded") == 0) {
        _Exit(84);
    }
    _Exit(90);
}

static png_voidp tracked_malloc(
    png_structp png_ptr, png_alloc_size_t size
) {
    allocator_context *context = png_get_mem_ptr(png_ptr);
    if (context == NULL || size == 0u ||
        (context->expected_handle != NULL &&
            context->expected_handle != png_ptr)) {
        if (context != NULL) context->ok = 0;
        return NULL;
    }
    ++context->allocations;
    return malloc(size);
}

static void tracked_free(png_structp png_ptr, png_voidp memory) {
    allocator_context *context = png_get_mem_ptr(png_ptr);
    if (context == NULL || memory == NULL ||
        (context->expected_handle != NULL &&
            context->expected_handle != png_ptr)) {
        if (context != NULL) context->ok = 0;
        return;
    }
    ++context->frees;
    free(memory);
}

static void replacement_write(
    png_structp png_ptr, png_bytep data, size_t length
) {
    (void)png_ptr;
    (void)data;
    (void)length;
    _Exit(91);
}

static void memory_write(
    png_structp png_ptr, png_bytep data, size_t length
) {
    write_context *context = png_get_io_ptr(png_ptr);
    png_uint_32 state = png_get_io_state(png_ptr);
    png_uint_32 location = state & PNG_IO_MASK_LOC;
    if (context == NULL || context->expected_handle != png_ptr ||
        data == NULL || length > context->capacity - context->size ||
        (state & PNG_IO_MASK_OP) != PNG_IO_WRITING ||
        (location != PNG_IO_SIGNATURE && location != PNG_IO_CHUNK_HDR &&
            location != PNG_IO_CHUNK_DATA && location != PNG_IO_CHUNK_CRC)) {
        if (context != NULL) context->ok = 0;
        png_error(png_ptr, "Write Error");
        return;
    }
    if (location == PNG_IO_SIGNATURE) {
        if (png_get_io_chunk_type(png_ptr) != 0u) context->ok = 0;
    } else if (png_get_io_chunk_type(png_ptr) == 0u) {
        context->ok = 0;
    }
    png_set_write_fn(png_ptr, context, replacement_write, NULL);
    png_set_error_fn(png_ptr, NULL, NULL, NULL);
    png_set_mem_fn(png_ptr, NULL, NULL, NULL);
    memcpy(context->bytes + context->size, data, length);
    context->size += length;
    ++context->calls;
}

static void memory_flush(png_structp png_ptr) {
    write_context *context = png_get_io_ptr(png_ptr);
    if (context == NULL || context->expected_handle != png_ptr ||
        (png_get_io_state(png_ptr) & PNG_IO_MASK_OP) != PNG_IO_WRITING) {
        if (context != NULL) context->ok = 0;
        return;
    }
    ++context->flush_calls;
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

static int replay_chunks(png_structp png_ptr,
    const unsigned char *source, size_t source_size) {
    if (source_size < 20u) return 0;
    png_write_sig(png_ptr);
    png_write_sig(png_ptr);
    size_t offset = 8u;
    int streamed = 0;
    while (offset <= source_size - 12u) {
        uint32_t length = read_u32be(source + offset);
        size_t total = (size_t)length + 12u;
        if (total > source_size - offset) return 0;
        const png_bytep type = (png_bytep)(source + offset + 4u);
        const png_bytep data = (png_bytep)(source + offset + 8u);
        if (streamed == 0 && length > 1u) {
            size_t first = (size_t)length / 2u;
            png_write_chunk_start(png_ptr, type, length);
            png_write_chunk_data(png_ptr, data, first);
            png_write_chunk_data(png_ptr, data + first,
                (size_t)length - first);
            png_write_chunk_end(png_ptr);
            streamed = 1;
        } else {
            png_write_chunk(png_ptr, type, data, length);
        }
        offset += total;
    }
    png_write_flush(png_ptr);
    return streamed != 0 && offset == source_size;
}

static int signatures_are_exact(void) {
    png_structp (*create_fn)(png_const_charp, png_voidp, png_error_ptr,
        png_error_ptr) = png_create_write_struct;
    png_structp (*create2_fn)(png_const_charp, png_voidp, png_error_ptr,
        png_error_ptr, png_voidp, png_malloc_ptr, png_free_ptr) =
        png_create_write_struct_2;
    void (*destroy_fn)(png_structpp, png_infopp) = png_destroy_write_struct;
    void (*set_fn)(png_structp, png_voidp, png_rw_ptr, png_flush_ptr) =
        png_set_write_fn;
    void (*sig_fn)(png_structp) = png_write_sig;
    void (*chunk_fn)(png_structp, png_const_bytep, png_const_bytep, size_t) =
        png_write_chunk;
    void (*start_fn)(png_structp, png_const_bytep, png_uint_32) =
        png_write_chunk_start;
    void (*data_fn)(png_structp, png_const_bytep, size_t) =
        png_write_chunk_data;
    void (*end_fn)(png_structp) = png_write_chunk_end;
    void (*flush_fn)(png_structp) = png_write_flush;
    return create_fn != NULL && create2_fn != NULL && destroy_fn != NULL &&
        set_fn != NULL && sig_fn != NULL && chunk_fn != NULL &&
        start_fn != NULL && data_fn != NULL && end_fn != NULL &&
        flush_fn != NULL;
}

static int custom_write_test(
    const unsigned char *source, size_t source_size
) {
    allocator_context allocator = {0, 0, 1, NULL};
    png_structp png_ptr = png_create_write_struct_2(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL,
        &allocator, tracked_malloc, tracked_free
    );
    if (png_ptr == NULL) return 0;
    allocator.expected_handle = png_ptr;
    png_infop info_ptr = png_create_info_struct(png_ptr);
    unsigned char *output = malloc(source_size);
    if (info_ptr == NULL || output == NULL) {
        free(output);
        png_destroy_write_struct(&png_ptr, &info_ptr);
        return 0;
    }
    write_context context = {
        output, source_size, 0u, 0, 0, 1, png_ptr
    };
    png_set_error_fn(png_ptr, &context, returning_error, NULL);
    png_set_write_fn(png_ptr, &context, memory_write, memory_flush);
    int io_ok = png_get_io_ptr(png_ptr) == &context;
    int replay_ok = replay_chunks(png_ptr, source, source_size);
    int bytes_ok = context.size == source_size &&
        memcmp(output, source, source_size) == 0;
    int callback_freeze_ok = png_get_error_ptr(png_ptr) == &context &&
        png_get_mem_ptr(png_ptr) == &allocator;
    png_structp stale = png_ptr;
    png_destroy_write_struct(&png_ptr, &info_ptr);
    png_write_sig(stale);
    int lifecycle_ok = png_ptr == NULL && info_ptr == NULL &&
        allocator.ok != 0 && allocator.allocations == allocator.frees &&
        allocator.allocations >= 2 && png_get_io_ptr(stale) == NULL;
    int ok = io_ok && replay_ok && bytes_ok && callback_freeze_ok &&
        context.ok != 0 &&
        context.calls > 0 && context.flush_calls == 1 && lifecycle_ok;
    if (!ok) {
        fprintf(stderr,
            "custom write mismatch io=%d replay=%d bytes=%d freeze=%d context=%d "
            "calls=%d flush=%d alloc=%d/%d lifecycle=%d size=%zu/%zu\n",
            io_ok, replay_ok, bytes_ok, callback_freeze_ok, context.ok,
            context.calls,
            context.flush_calls, allocator.allocations, allocator.frees,
            lifecycle_ok, context.size, source_size);
    }
    free(output);
    return ok;
}

static int active_chunk_destroy_test(void) {
    unsigned char output[16] = {0};
    write_context context = {
        output, sizeof(output), 0u, 0, 0, 1, NULL
    };
    png_structp png_ptr = png_create_write_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (png_ptr == NULL || info_ptr == NULL) {
        png_destroy_write_struct(&png_ptr, &info_ptr);
        return 0;
    }
    context.expected_handle = png_ptr;
    png_set_write_fn(png_ptr, &context, memory_write, NULL);
    static const png_byte type[4] = {'I', 'E', 'N', 'D'};
    png_write_chunk_start(png_ptr, type, 0u);
    png_destroy_write_struct(&png_ptr, &info_ptr);
    int preserved = png_ptr != NULL && info_ptr != NULL;
    png_write_chunk_end(png_ptr);
    png_destroy_write_struct(&png_ptr, &info_ptr);
    return preserved && png_ptr == NULL && info_ptr == NULL &&
        context.ok != 0 && context.size == 12u;
}

static int stdio_write_test(
    const unsigned char *source, size_t source_size
) {
    FILE *file = tmpfile();
    png_structp png_ptr = png_create_write_struct(
        PNG_LIBPNG_VER_STRING, NULL, returning_error, NULL
    );
    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (file == NULL || png_ptr == NULL || info_ptr == NULL) {
        if (file != NULL) fclose(file);
        png_destroy_write_struct(&png_ptr, &info_ptr);
        return 0;
    }
    png_init_io(png_ptr, file);
    int replay_ok = replay_chunks(png_ptr, source, source_size);
    unsigned char *output = malloc(source_size);
    int bytes_ok = output != NULL && fseek(file, 0, SEEK_SET) == 0 &&
        fread(output, 1u, source_size, file) == source_size &&
        memcmp(output, source, source_size) == 0;
    png_destroy_write_struct(&png_ptr, &info_ptr);
    int ok = replay_ok && bytes_ok && png_ptr == NULL && info_ptr == NULL &&
        fclose(file) == 0;
    free(output);
    return ok;
}

static int run_failure(const char *dylib, const char *mode) {
    runtime_params_storage params;
    memset(&params, 0, sizeof(params));
    if (InitCJRuntime(&params) != 0) return 10;
    if (LoadCJLibraryWithInit(dylib) != 0) {
        (void)FiniCJRuntime();
        return 10;
    }
    int expected = strcmp(mode, "short-chunk") == 0 ? 83 : 84;
    unsigned char output[32] = {0};
    write_context context = {
        output, sizeof(output), 0u, 0, 0, 1, NULL
    };
    png_structp png_ptr = png_create_write_struct(
        PNG_LIBPNG_VER_STRING, &expected, expected_error, NULL
    );
    if (png_ptr == NULL) return 11;
    context.expected_handle = png_ptr;
    png_set_write_fn(png_ptr, &context, memory_write, NULL);
    static const png_byte type[4] = {'t', 'E', 'S', 'T'};
    static const png_byte data[2] = {1u, 2u};
    png_write_chunk_start(png_ptr, type, 2u);
    if (expected == 83) {
        png_write_chunk_data(png_ptr, data, 1u);
        png_write_chunk_end(png_ptr);
    } else {
        png_write_chunk_data(png_ptr, data, 2u);
        png_write_chunk_data(png_ptr, data, 1u);
    }
    png_destroy_write_struct(&png_ptr, NULL);
    (void)FiniCJRuntime();
    return 12;
}

int main(int argc, char **argv) {
    if (argc == 3 && (strcmp(argv[2], "short-chunk") == 0 ||
        strcmp(argv[2], "long-chunk") == 0)) {
        return run_failure(argv[1], argv[2]);
    }
    if (argc != 3) {
        fprintf(stderr, "usage: %s DYLIB PNG\n", argv[0]);
        return 2;
    }
    size_t source_size = 0u;
    unsigned char *source = read_file(argv[2], &source_size);
    if (source == NULL) return 2;
    runtime_params_storage params;
    memset(&params, 0, sizeof(params));
    int runtime_ok = InitCJRuntime(&params) == 0;
    int load_ok = runtime_ok && LoadCJLibraryWithInit(argv[1]) == 0;
    int signature_ok = load_ok && signatures_are_exact();
    int custom_ok = signature_ok && custom_write_test(source, source_size);
    int active_destroy_ok = custom_ok && active_chunk_destroy_test();
    int stdio_ok = active_destroy_ok &&
        stdio_write_test(source, source_size);
    free(source);
    int fini_ok = runtime_ok && FiniCJRuntime() == 0;
    int ok = runtime_ok && load_ok && signature_ok && custom_ok &&
        active_destroy_ok && stdio_ok && fini_ok;
    printf("libpng4cj classic write chunk consumer: %s\n",
        ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
