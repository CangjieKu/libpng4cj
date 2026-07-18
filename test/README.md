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
plus relocated execution.
