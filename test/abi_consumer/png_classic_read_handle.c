#include <png.h>

#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

extern int64_t InitCJRuntime(void *params);
extern int64_t LoadCJLibraryWithInit(const char *path);
extern int64_t FiniCJRuntime(void);

static int callback_ok = 1;
static int primary_warning_calls = 0;
static int replacement_warning_calls = 0;
static int allocator_warning_calls = 0;
static png_structp expected_png_ptr = NULL;
static void *expected_error_ptr = NULL;
static const char *expected_message = NULL;
static volatile sig_atomic_t fatal_return_called = 0;

enum {
    EXPECTED_PNG_STRUCT_SIZE = 1224,
    EXPECTED_PNG_INFO_SIZE = 352,
    ALLOCATION_RECORD_CAPACITY = 16
};

typedef union allocation_header {
    struct {
        uint64_t magic;
        int family;
    } fields;
    max_align_t alignment;
} allocation_header;

typedef struct allocator_context {
    int family;
    int ok;
    int fail_next;
    int allocation_calls;
    int allocation_successes;
    int free_calls;
    size_t sizes[ALLOCATION_RECORD_CAPACITY];
    png_structp expected_handle;
} allocator_context;

static const uint64_t ALLOCATION_MAGIC = UINT64_C(0x4c50303038470001);

static void test_error(png_structp png_ptr, png_const_charp message) {
    (void)png_ptr;
    (void)message;
}

static void test_warning(png_structp png_ptr, png_const_charp message) {
    if (png_ptr != expected_png_ptr || message == NULL ||
        strcmp(message, expected_message) != 0 ||
        png_get_error_ptr(png_ptr) != expected_error_ptr) {
        callback_ok = 0;
    }
    ++primary_warning_calls;
}

static void replacement_warning(
    png_structp png_ptr,
    png_const_charp message
) {
    if (png_ptr != expected_png_ptr || message == NULL ||
        strcmp(message, expected_message) != 0 ||
        png_get_error_ptr(png_ptr) != expected_error_ptr) {
        callback_ok = 0;
    }
    ++replacement_warning_calls;
}

static void fatal_exit_error(
    png_structp png_ptr,
    png_const_charp message
) {
    if (png_ptr == expected_png_ptr && message != NULL &&
        strcmp(message, expected_message) == 0 &&
        png_get_error_ptr(png_ptr) == expected_error_ptr) {
        _Exit(73);
    }
    _Exit(74);
}

static void fatal_return_error(
    png_structp png_ptr,
    png_const_charp message
) {
    if (png_ptr == expected_png_ptr && message != NULL &&
        strcmp(message, expected_message) == 0 &&
        png_get_error_ptr(png_ptr) == expected_error_ptr) {
        fatal_return_called = 1;
    }
}

static void fatal_abort_handler(int signal_number) {
    if (signal_number != SIGABRT) _Exit(78);
    _Exit(fatal_return_called != 0 ? 75 : 77);
}

static png_voidp test_malloc(png_structp png_ptr, png_alloc_size_t size) {
    allocator_context *context = png_get_mem_ptr(png_ptr);
    if (context == NULL || context->family == 0 ||
        (context->expected_handle != NULL &&
            png_ptr != context->expected_handle)) {
        if (context != NULL) context->ok = 0;
        return NULL;
    }
    if (context->allocation_calls < ALLOCATION_RECORD_CAPACITY) {
        context->sizes[context->allocation_calls] = size;
    } else {
        context->ok = 0;
    }
    ++context->allocation_calls;
    if (context->fail_next != 0) {
        context->fail_next = 0;
        return NULL;
    }
    allocation_header *header = malloc(sizeof(*header) + size);
    if (header == NULL) return NULL;
    header->fields.magic = ALLOCATION_MAGIC;
    header->fields.family = context->family;
    ++context->allocation_successes;
    return header + 1;
}

static void test_free(png_structp png_ptr, png_voidp memory) {
    allocator_context *context = png_get_mem_ptr(png_ptr);
    allocation_header *header = (allocation_header *)memory - 1;
    if (context == NULL || context->family == 0 ||
        (context->expected_handle != NULL &&
            png_ptr != context->expected_handle) ||
        header->fields.magic != ALLOCATION_MAGIC ||
        header->fields.family != context->family) {
        if (context != NULL) context->ok = 0;
        return;
    }
    header->fields.magic = 0;
    ++context->free_calls;
    free(header);
}

static void allocator_warning(
    png_structp png_ptr,
    png_const_charp message
) {
    allocator_context *context = png_get_mem_ptr(png_ptr);
    if (context == NULL || message == NULL ||
        strcmp(message, "Out of memory") != 0) {
        callback_ok = 0;
    }
    ++allocator_warning_calls;
}

static int test_signatures(void) {
    png_structp (*create_fn)(png_const_charp, png_voidp, png_error_ptr,
        png_error_ptr) = png_create_read_struct;
    png_structp (*create2_fn)(png_const_charp, png_voidp, png_error_ptr,
        png_error_ptr, png_voidp, png_malloc_ptr, png_free_ptr) =
        png_create_read_struct_2;
    png_infop (*info_fn)(png_const_structp) = png_create_info_struct;
    void (*destroy_info_fn)(png_const_structp, png_infopp) =
        png_destroy_info_struct;
    void (*destroy_read_fn)(png_structpp, png_infopp, png_infopp) =
        png_destroy_read_struct;
    void (*set_error_fn)(png_structp, png_voidp, png_error_ptr,
        png_error_ptr) = png_set_error_fn;
    png_voidp (*get_error_fn)(png_const_structp) = png_get_error_ptr;
    void (*set_mem_fn)(png_structp, png_voidp, png_malloc_ptr, png_free_ptr) =
        png_set_mem_fn;
    png_voidp (*get_mem_fn)(png_const_structp) = png_get_mem_ptr;
    png_voidp (*malloc_fn)(png_const_structp, png_alloc_size_t) = png_malloc;
    png_voidp (*calloc_fn)(png_const_structp, png_alloc_size_t) = png_calloc;
    png_voidp (*malloc_warn_fn)(png_const_structp, png_alloc_size_t) =
        png_malloc_warn;
    png_voidp (*malloc_default_fn)(png_const_structp, png_alloc_size_t) =
        png_malloc_default;
    void (*free_fn)(png_const_structp, png_voidp) = png_free;
    void (*free_default_fn)(png_const_structp, png_voidp) = png_free_default;
    void (*warning_fn)(png_const_structp, png_const_charp) = png_warning;
    void (*error_api)(png_const_structp, png_const_charp) = png_error;
    return create_fn != NULL && create2_fn != NULL && info_fn != NULL &&
        destroy_info_fn != NULL && destroy_read_fn != NULL &&
        set_error_fn != NULL && get_error_fn != NULL && set_mem_fn != NULL &&
        get_mem_fn != NULL && malloc_fn != NULL && calloc_fn != NULL &&
        malloc_warn_fn != NULL && malloc_default_fn != NULL &&
        free_fn != NULL && free_default_fn != NULL && warning_fn != NULL &&
        error_api != NULL;
}

static int test_versions(void) {
    png_structp null_version = png_create_read_struct(
        NULL, NULL, NULL, NULL
    );
    png_structp empty_version = png_create_read_struct(
        "", NULL, NULL, NULL
    );
    png_structp major_version = png_create_read_struct(
        "1", NULL, NULL, NULL
    );
    png_structp old_version = png_create_read_struct(
        "1.5.99", NULL, NULL, NULL
    );
    png_structp short_version = png_create_read_struct(
        "1.6", NULL, NULL, NULL
    );
    png_structp compatible = png_create_read_struct(
        "1.6.0", NULL, NULL, NULL
    );
    if (compatible != NULL) {
        png_destroy_read_struct(&compatible, NULL, NULL);
    }
    return null_version == NULL && empty_version == NULL &&
        major_version == NULL && old_version == NULL && short_version == NULL &&
        compatible == NULL;
}

static int test_default_lifecycle(void) {
    int first_context = 11;
    int second_context = 22;
    png_infop null_info = NULL;
    png_set_error_fn(NULL, NULL, NULL, NULL);
    png_set_mem_fn(NULL, NULL, NULL, NULL);
    png_destroy_info_struct(NULL, &null_info);
    if (png_create_info_struct(NULL) != NULL ||
        png_get_error_ptr(NULL) != NULL || png_get_mem_ptr(NULL) != NULL) {
        return 0;
    }

    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, &first_context, test_error, test_warning
    );
    if (png_ptr == NULL || png_get_error_ptr(png_ptr) != &first_context ||
        png_get_mem_ptr(png_ptr) != NULL) return 0;

    png_set_error_fn(png_ptr, &second_context, test_error, test_warning);
    if (png_get_error_ptr(png_ptr) != &second_context) return 0;

    png_infop first = png_create_info_struct(png_ptr);
    png_infop second = png_create_info_struct(png_ptr);
    if (first == NULL || second == NULL || first == second) return 0;
    unsigned char *plain = png_malloc(png_ptr, 9u);
    unsigned char *zeroed = png_calloc(png_ptr, 13u);
    unsigned char *default_memory = png_malloc_default(png_ptr, 7u);
    if (plain == NULL || zeroed == NULL || default_memory == NULL) return 0;
    for (size_t i = 0; i < 13u; ++i) {
        if (zeroed[i] != 0u) return 0;
    }
    png_free(png_ptr, plain);
    png_free(png_ptr, plain);
    png_free(png_ptr, zeroed);
    png_free_default(png_ptr, default_memory);
    png_destroy_info_struct(png_ptr, &first);
    if (first != NULL || second == NULL) return 0;

    png_destroy_read_struct(&png_ptr, &second, NULL);
    if (png_ptr != NULL || second != NULL) return 0;
    png_destroy_read_struct(&png_ptr, &second, NULL);
    png_destroy_info_struct(NULL, &second);
    return primary_warning_calls == 0 && replacement_warning_calls == 0;
}

static int test_context_lifecycle(void) {
    int error_context = 33;
    allocator_context first_allocator = {
        .family = 44,
        .ok = 1
    };
    allocator_context second_allocator = {
        .family = 55,
        .ok = 1
    };
    png_structp png_ptr = png_create_read_struct_2(
        PNG_LIBPNG_VER_STRING,
        &error_context,
        test_error,
        allocator_warning,
        &first_allocator,
        test_malloc,
        test_free
    );
    if (png_ptr == NULL || png_get_error_ptr(png_ptr) != &error_context ||
        png_get_mem_ptr(png_ptr) != &first_allocator) return 0;
    first_allocator.expected_handle = png_ptr;
    if (first_allocator.allocation_calls != 1 ||
        first_allocator.allocation_successes != 1 ||
        first_allocator.sizes[0] != EXPECTED_PNG_STRUCT_SIZE) return 0;

    png_infop first_info = png_create_info_struct(png_ptr);
    unsigned char *first_memory = png_malloc(png_ptr, 17u);
    if (first_info == NULL || first_memory == NULL ||
        first_allocator.allocation_calls != 3 ||
        first_allocator.sizes[1] != EXPECTED_PNG_INFO_SIZE ||
        first_allocator.sizes[2] != 17u) return 0;

    png_set_mem_fn(
        png_ptr, &second_allocator, test_malloc, test_free
    );
    second_allocator.expected_handle = png_ptr;
    if (png_get_mem_ptr(png_ptr) != &second_allocator) return 0;

    png_infop second_info = png_create_info_struct(png_ptr);
    unsigned char *second_memory = png_calloc(png_ptr, 23u);
    if (second_info == NULL || second_memory == NULL ||
        second_allocator.allocation_calls != 2 ||
        second_allocator.sizes[0] != EXPECTED_PNG_INFO_SIZE ||
        second_allocator.sizes[1] != 23u) return 0;
    for (size_t i = 0; i < 23u; ++i) {
        if (second_memory[i] != 0u) return 0;
    }

    int first_calls_before_default = first_allocator.allocation_calls;
    int second_calls_before_default = second_allocator.allocation_calls;
    void *default_memory = png_malloc_default(png_ptr, 31u);
    if (default_memory == NULL ||
        first_allocator.allocation_calls != first_calls_before_default ||
        second_allocator.allocation_calls != second_calls_before_default) {
        return 0;
    }
    png_free_default(png_ptr, default_memory);

    second_allocator.fail_next = 1;
    if (png_malloc_warn(png_ptr, 29u) != NULL ||
        allocator_warning_calls != 1 ||
        second_allocator.allocation_calls != 3 ||
        second_allocator.allocation_successes != 2) return 0;

    png_free(png_ptr, first_memory);
    png_free(png_ptr, first_memory);
    png_free(png_ptr, second_memory);
    png_destroy_info_struct(png_ptr, &first_info);
    png_destroy_read_struct(&png_ptr, &second_info, NULL);
    return png_ptr == NULL && first_info == NULL && second_info == NULL &&
        callback_ok && first_allocator.ok && second_allocator.ok &&
        first_allocator.allocation_successes == 3 &&
        first_allocator.free_calls == 3 &&
        second_allocator.allocation_successes == 2 &&
        second_allocator.free_calls == 2 &&
        primary_warning_calls == 0 && replacement_warning_calls == 0;
}

static int test_creation_allocation_failure(void) {
    int error_context = 56;
    allocator_context allocator = {
        .family = 57,
        .ok = 1,
        .fail_next = 1
    };
    png_structp png_ptr = png_create_read_struct_2(
        PNG_LIBPNG_VER_STRING,
        &error_context,
        test_error,
        allocator_warning,
        &allocator,
        test_malloc,
        test_free
    );
    return png_ptr == NULL && allocator.ok &&
        allocator.allocation_calls == 1 &&
        allocator.sizes[0] == EXPECTED_PNG_STRUCT_SIZE &&
        allocator.allocation_successes == 0 && allocator.free_calls == 0 &&
        allocator_warning_calls == 2;
}

static int test_warning_callbacks(void) {
    int first_context = 61;
    int second_context = 62;
    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, &first_context, test_error, test_warning
    );
    if (png_ptr == NULL) return 0;

    expected_png_ptr = png_ptr;
    expected_error_ptr = &first_context;
    expected_message = "first warning";
    png_warning(png_ptr, expected_message);
    if (!callback_ok || primary_warning_calls != 1 ||
        replacement_warning_calls != 0) return 0;

    png_set_error_fn(
        png_ptr, &second_context, test_error, replacement_warning
    );
    expected_error_ptr = &second_context;
    expected_message = "replacement warning";
    png_warning(png_ptr, expected_message);
    if (!callback_ok || primary_warning_calls != 1 ||
        replacement_warning_calls != 1) return 0;

    png_destroy_read_struct(&png_ptr, NULL, NULL);
    expected_png_ptr = NULL;
    expected_error_ptr = NULL;
    expected_message = NULL;
    return png_ptr == NULL;
}

static int run_child_mode(const char *dylib, const char *mode) {
    max_align_t runtime_params[64];
    memset(runtime_params, 0, sizeof(runtime_params));
    if (InitCJRuntime(runtime_params) != 0 ||
        LoadCJLibraryWithInit(dylib) != 0) return 10;

    int context = 71;
    png_error_ptr error_fn = NULL;
    if (strcmp(mode, "fatal-exit") == 0) {
        error_fn = fatal_exit_error;
    } else if (strcmp(mode, "fatal-return") == 0) {
        error_fn = fatal_return_error;
        if (signal(SIGABRT, fatal_abort_handler) == SIG_ERR) return 11;
    } else if (strcmp(mode, "fatal-default") == 0) {
        if (signal(SIGABRT, fatal_abort_handler) == SIG_ERR) return 11;
    } else if (strcmp(mode, "warning-default") == 0) {
        png_warning(NULL, "default warning");
        return FiniCJRuntime() == 0 ? 79 : 14;
    } else if (strcmp(mode, "malloc-fatal") == 0) {
        if (signal(SIGABRT, fatal_abort_handler) == SIG_ERR) return 11;
        allocator_context allocator = {
            .family = 81,
            .ok = 1
        };
        png_structp png_ptr = png_create_read_struct_2(
            PNG_LIBPNG_VER_STRING,
            &context,
            fatal_return_error,
            NULL,
            &allocator,
            test_malloc,
            test_free
        );
        if (png_ptr == NULL) return 13;
        allocator.expected_handle = png_ptr;
        allocator.fail_next = 1;
        expected_png_ptr = png_ptr;
        expected_error_ptr = &context;
        expected_message = "Out of memory";
        (void)png_malloc(png_ptr, 41u);
        return 15;
    } else {
        return 12;
    }

    png_structp png_ptr = png_create_read_struct(
        PNG_LIBPNG_VER_STRING, &context, error_fn, NULL
    );
    if (png_ptr == NULL) return 13;
    expected_png_ptr = png_ptr;
    expected_error_ptr = &context;
    expected_message = mode;
    png_error(png_ptr, expected_message);
}

static int file_contains(const char *path, const char *needle) {
    if (needle == NULL) return 1;
    FILE *file = fopen(path, "rb");
    if (file == NULL || fseek(file, 0, SEEK_END) != 0) {
        if (file != NULL) fclose(file);
        return 0;
    }
    long size = ftell(file);
    if (size < 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return 0;
    }
    char *bytes = malloc((size_t)size + 1u);
    if (bytes == NULL) {
        fclose(file);
        return 0;
    }
    size_t read_size = fread(bytes, 1u, (size_t)size, file);
    bytes[read_size] = '\0';
    int found = read_size == (size_t)size && strstr(bytes, needle) != NULL;
    free(bytes);
    fclose(file);
    return found;
}

static int spawn_child_mode(
    const char *self,
    const char *dylib,
    const char *mode,
    int expected_exit,
    const char *expected_stderr
) {
    char stderr_path[] = "/tmp/libpng4cj-classic-error.XXXXXX";
    int stderr_fd = mkstemp(stderr_path);
    if (stderr_fd < 0) return 0;
    close(stderr_fd);

    posix_spawn_file_actions_t actions;
    if (posix_spawn_file_actions_init(&actions) != 0) {
        remove(stderr_path);
        return 0;
    }
    if (posix_spawn_file_actions_addopen(
            &actions,
            STDERR_FILENO,
            stderr_path,
            O_WRONLY | O_TRUNC,
            0600
        ) != 0) {
        posix_spawn_file_actions_destroy(&actions);
        remove(stderr_path);
        return 0;
    }

    pid_t pid = 0;
    char *child_argv[] = {
        (char *)self, (char *)dylib, (char *)mode, NULL
    };
    int spawn_result = posix_spawn(
        &pid, self, &actions, NULL, child_argv, environ
    );
    posix_spawn_file_actions_destroy(&actions);
    if (spawn_result != 0) {
        remove(stderr_path);
        return 0;
    }
    int status = 0;
    int waited = waitpid(pid, &status, 0) == pid;
    int ok = waited && WIFEXITED(status) &&
        WEXITSTATUS(status) == expected_exit &&
        file_contains(stderr_path, expected_stderr);
    remove(stderr_path);
    return ok;
}

int main(int argc, char **argv) {
    if (argc == 3) return run_child_mode(argv[1], argv[2]);
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
    int ok = test_signatures() && test_versions() &&
        test_default_lifecycle() && test_context_lifecycle() &&
        test_creation_allocation_failure() && test_warning_callbacks();
    if (FiniCJRuntime() != 0) ok = 0;
    if (ok) {
        ok = spawn_child_mode(
                argv[0], argv[1], "warning-default", 79,
                "libpng warning: default warning"
            ) &&
            spawn_child_mode(
                argv[0], argv[1], "fatal-exit", 73, NULL
            ) &&
            spawn_child_mode(
                argv[0], argv[1], "fatal-return", 75,
                "libpng error: fatal-return"
            ) &&
            spawn_child_mode(
                argv[0], argv[1], "fatal-default", 77,
                "libpng error: fatal-default"
            ) &&
            spawn_child_mode(
                argv[0], argv[1], "malloc-fatal", 75,
                "libpng error: Out of memory"
            );
    }
    if (!ok) return 4;
    printf("libpng4cj classic read handle and error ABI: PASS\n");
    return 0;
}
