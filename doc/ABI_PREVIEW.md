# libpng4cj C ABI Surfaces

LP-S008A adds a macOS arm64 preview C surface alongside the existing native
Cangjie package. It does not replace the package coordinate or change the
normal `cjpm build` static-library output.

Build and verify:

```sh
./tools/test_abi_preview.sh
```

The generated directory contains:

- `libpng4cj_preview.dylib`: direct Cangjie `@C` implementation
- `include/libpng4cj_preview.h`: preview API contract
- `include/png.h`: frozen simplified `png_image` memory ABI header
- `abi-consumer`: standalone C consumption proof
- `png-image-memory-consumer`: strict C11 `png_image` consumption proof

The v1 preview supports signature checks and caller-owned RGBA8 decode,
including Adam7 input and explicit 16-to-8 scaling. All public ABI functions
are implemented directly in Cangjie. The decoder reports the required buffer
size before the caller supplies storage, and Cangjie exceptions are converted
to deterministic status and message outputs.

A C process must initialize the Cangjie runtime before calling a Cangjie
dynamic library. The standalone consumer demonstrates the toolchain-required
`InitCJRuntime`, `LoadCJLibraryWithInit`, call, and `FiniCJRuntime` lifecycle;
that host bootstrap is not a libpng4cj C implementation layer.

LP-S008B adds the upstream-compatible LP64 `png_image` layout, the simplified
memory subset of its format/geometry macros and diagnostic fields, and the
exact memory symbol names and signatures:

- `png_image_begin_read_from_memory`
- `png_image_finish_read`
- `png_image_free`
- `png_image_write_to_memory`

The begin/finish path retains one Cangjie-owned decode state behind
`png_image::opaque`, decodes pixels exactly once, and clears the handle on
finish or free. The current memory surface covers common direct 8-bit, linear
UInt16, and RGB-family color-map formats, signed component strides, solid or
caller-buffer background composition, associated-alpha reads, Adam7 input,
and direct/linear/color-map memory writing. Size-only writes return the exact
encoded byte count and undersized writes update that count without reporting a
PNG error.

Begin-read derives `PNG_IMAGE_FLAG_COLORSPACE_NOT_sRGB` from the frozen
libpng cICP/mDCV/sRGB/cHRM precedence. Linear reads honor
`PNG_IMAGE_FLAG_16BIT_sRGB` for untagged 16-bit input, and writes preserve the
requested sRGB/non-sRGB metadata shape. Exact gamma-aware direct 8-bit and
color-map pixel conversion remains outside this checkpoint.

The exact exported symbol sets are frozen in
`abi/symbols/libpng4cj-preview-v1.txt` and
`abi/symbols/libpng4cj-png-image-memory-v1.txt`. The C11 proof statically checks
the LP64 104-byte structure and every field offset before exercising lifecycle,
formats, malformed input, limits, read/write ownership, and relocated loading.
It also proves non-sRGB begin facts and distinct linear output when the
16-bit-sRGB assumption is enabled.

These surfaces are not yet the complete libpng16 drop-in ABI, a portable
release, or an LTS artifact. C `FILE*`/stdio entry points, raw callback and
allocator crossings, remaining public symbols, and non-macOS ABI packaging
remain outside this checkpoint.
