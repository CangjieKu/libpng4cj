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
processes, custom allocator ownership and replacement, and replays every
executable after relocating the dylib. The classic consumer also covers custom
read callback replacement and context lookup, signature-prefix continuation,
caller-owned stdio input, complete read-info decode retention, and isolated
truncated/excessive-prefix/oversized-chunk fatal paths. A separate core-info
consumer verifies exact getter signatures, info ownership, failure-side output
preservation, packed grayscale and Adam7 IHDR facts, and destroyed-handle
invalidation. The row-read consumer verifies exact row/read-end signatures,
packed raw row/display/array delivery, no-destination wrapper behavior, Adam7
whole-image parity, early read-end sealing, stale handles, and original plus
relocated execution. The metadata consumer freezes the eight fixed/core getter
signatures and `PNG_INFO_*` values, compares vendored upstream sample values,
checks stable PLTE/tRNS/sBIT/bKGD pointers, indexed and non-indexed tRNS output
combinations, wrong-owner/spare/stale handles, allocator balance, and original
plus relocated execution. The easy-access consumer freezes sixteen exact
signatures, compares get-valid, pHYs/oFFs fixed conversions, dpi, and signature
values with an independent libpng 1.6.58 oracle, verifies primary-info versus
post-IDAT visibility, mutates chunk payloads with valid CRCs for unit gates,
and repeats ownership, allocator, original, and relocated checks.
The scalar-metadata consumer freezes seventeen floating/scalar getter, version
string, 31-bit read, and grayscale-palette signatures; compares gAMA/cHRM/oFFs/
cICP/cLLI/mDCV values with the vendored upstream sample; verifies output-null
rules, immutable process-lifetime strings, invalid grayscale depth, the
out-of-range `png_get_uint_31` fatal callback boundary, absent and wrong-owner
preservation, stale handles, allocator balance, and original plus relocated
execution.

The extended-metadata consumer freezes fifteen cHRM XYZ, pCAL/sCAL, text/time,
eXIf, iCCP, hIST, sPLT, unknown-chunk, and rows getter signatures plus exact
LP64 structure layouts. It compares vendored `pngtest.png` values with a
libpng 1.6.58 oracle, verifies primary-info filtering for post-IDAT text/eXIf,
checks stable info-owned pointer trees, reproduces the sCAL fixed-point overflow
fatal boundary, and repeats absent, wrong-owner, spare, stale, allocator,
original, and relocated checks.

The runtime/context consumer freezes all fourteen remaining classic getter
signatures; verifies frozen 1.6.58 read-owner defaults, NULL registration
contexts, row cursor movement, pass/IO/palette status, null and stale handles,
and original plus relocated execution without claiming the held setter or
progressive/write registration surfaces.
