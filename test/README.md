# Tests

`consumer/` is a standalone Cangjie project that consumes libpng4cj through a
path dependency, links the external system zlib at the executable boundary,
and proves the public `import libpng4cj.*` package root.

Library unit tests remain under `src/tests/`, matching the current `cjpm test`
package-discovery model.

`abi_consumer/` contains strict C11 consumers for the preview facade and the
exact simplified `png_image` memory/file/stdio ABI. `./tools/test_abi_preview.sh`
builds the Cangjie dylib, checks all frozen symbol manifests, compiles the
consumers with warnings as errors, runs direct/linear/colormap memory coverage,
file and caller-owned `FILE*` read/write and failure cleanup, checks colorspace
and untagged-16-bit flags, invokes warning callbacks with callback-side context
lookup, proves callback-owned/default/returning fatal paths in separate
processes, and replays every executable after relocating the dylib.
