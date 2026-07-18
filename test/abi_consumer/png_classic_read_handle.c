#include <png.h>

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int64_t InitCJRuntime(void *params);
extern int64_t LoadCJLibraryWithInit(const char *path);
extern int64_t FiniCJRuntime(void);

static int callback_calls = 0;
static int allocator_calls = 0;

static void test_error(png_structp png_ptr, png_const_charp message) {
    (void)png_ptr;
    (void)message;
    ++callback_calls;
}

static void test_warning(png_structp png_ptr, png_const_charp message) {
    (void)png_ptr;
    (void)message;
    ++callback_calls;
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
    return create_fn != NULL && create2_fn != NULL && info_fn != NULL &&
        destroy_info_fn != NULL && destroy_read_fn != NULL &&
        set_error_fn != NULL && get_error_fn != NULL && set_mem_fn != NULL &&
        get_mem_fn != NULL;
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
    return callback_calls == 0;
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
        allocator_calls == 0 && callback_calls == 0;
}

int main(int argc, char **argv) {
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
        test_default_lifecycle() && test_context_lifecycle();
    if (FiniCJRuntime() != 0) ok = 0;
    if (!ok) return 4;
    printf("libpng4cj classic read handle ABI: PASS\n");
    return 0;
}
