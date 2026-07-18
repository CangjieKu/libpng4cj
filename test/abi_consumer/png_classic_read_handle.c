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
static int allocator_calls = 0;
static png_structp expected_png_ptr = NULL;
static void *expected_error_ptr = NULL;
static const char *expected_message = NULL;
static volatile sig_atomic_t fatal_return_called = 0;

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
    (void)png_ptr;
    ++allocator_calls;
    return malloc(size);
}

static void test_free(png_structp png_ptr, png_voidp memory) {
    (void)png_ptr;
    ++allocator_calls;
    free(memory);
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
    void (*warning_fn)(png_const_structp, png_const_charp) = png_warning;
    void (*error_api)(png_const_structp, png_const_charp) = png_error;
    return create_fn != NULL && create2_fn != NULL && info_fn != NULL &&
        destroy_info_fn != NULL && destroy_read_fn != NULL &&
        set_error_fn != NULL && get_error_fn != NULL && set_mem_fn != NULL &&
        get_mem_fn != NULL && warning_fn != NULL && error_api != NULL;
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
    int mem_context = 44;
    int updated_mem_context = 55;
    png_structp png_ptr = png_create_read_struct_2(
        PNG_LIBPNG_VER_STRING,
        &error_context,
        test_error,
        test_warning,
        &mem_context,
        test_malloc,
        test_free
    );
    if (png_ptr == NULL || png_get_error_ptr(png_ptr) != &error_context ||
        png_get_mem_ptr(png_ptr) != &mem_context) return 0;

    png_set_mem_fn(png_ptr, &updated_mem_context, test_malloc, test_free);
    if (png_get_mem_ptr(png_ptr) != &updated_mem_context) return 0;

    png_infop info = png_create_info_struct(png_ptr);
    png_infop end_info = png_create_info_struct(png_ptr);
    if (info == NULL || end_info == NULL) return 0;
    png_destroy_read_struct(&png_ptr, &info, &end_info);
    return png_ptr == NULL && info == NULL && end_info == NULL &&
        allocator_calls == 0 && primary_warning_calls == 0 &&
        replacement_warning_calls == 0;
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
        test_warning_callbacks();
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
            );
    }
    if (!ok) return 4;
    printf("libpng4cj classic read handle and error ABI: PASS\n");
    return 0;
}
