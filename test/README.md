# Tests

`consumer/` is a standalone Cangjie project that consumes libpng4cj through a
path dependency, links the external system zlib at the executable boundary,
and proves the public `import libpng4cj.*` package root.

Library unit tests remain under `src/tests/`, matching the current `cjpm test`
package-discovery model.

`abi_consumer/` contains strict C11 consumers for both the preview facade and
the exact `png_image` memory ABI. `./tools/test_abi_preview.sh` builds the
Cangjie dylib, checks both frozen symbol manifests, compiles the consumers with
warnings as errors, runs direct/linear/colormap read and write coverage, and
checks colorspace and untagged-16-bit flags before replaying both executables
after relocating the dylib.
