# libpng4cj C ABI Surfaces

The initial ABI milestone adds a macOS arm64 preview C surface alongside the
existing native Cangjie package. It does not replace the package coordinate or
change the normal `cjpm build` static-library output.

Build and verify:

```sh
./tools/test_abi_preview.sh
```

The generated directory contains:

- `libpng4cj_preview.dylib`: direct Cangjie `@C` implementation
- `include/libpng4cj_preview.h`: preview API contract
- `include/png.h`: frozen simplified `png_image` memory/file/stdio ABI header
- `abi-consumer`: standalone C consumption proof
- `png-image-memory-consumer`: strict C11 `png_image` consumption proof
- `png-image-file-stdio-consumer`: strict C11 file and `FILE*` proof
- `png-classic-stateless-consumer`: strict C11 classic utility proof

The v1 preview supports signature checks and caller-owned RGBA8 decode,
including Adam7 input and explicit 16-to-8 scaling. All public ABI functions
are implemented directly in Cangjie. The decoder reports the required buffer
size before the caller supplies storage, and Cangjie exceptions are converted
to deterministic status and message outputs.

A C process must initialize the Cangjie runtime before calling a Cangjie
dynamic library. The standalone consumer demonstrates the toolchain-required
`InitCJRuntime`, `LoadCJLibraryWithInit`, call, and `FiniCJRuntime` lifecycle;
that host bootstrap is not a libpng4cj C implementation layer.

The simplified-memory milestone adds the upstream-compatible LP64 `png_image`
layout, the memory subset of its format/geometry macros and diagnostic fields,
and the exact memory symbol names and signatures:

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
`abi/symbols/libpng4cj-png-image-memory-v1.txt`, with the file/stdio extension
in `abi/symbols/libpng4cj-png-image-file-stdio-v1.txt`. The C11 proof statically
checks the LP64 104-byte structure and every field offset before exercising
lifecycle, formats, malformed input, limits, read/write ownership, and relocated
loading. It also proves non-sRGB begin facts and distinct linear output when the
16-bit-sRGB assumption is enabled.

The file and stdio milestone adds four simplified entry points:

- `png_image_begin_read_from_file`
- `png_image_begin_read_from_stdio`
- `png_image_write_to_file`
- `png_image_write_to_stdio`

The implementation keeps PNG parsing, format conversion, opaque ownership,
limits, diagnostics, and encoding in Cangjie. A narrow libc FFI performs only
`FILE*` open/read/write/flush/close/remove operations. Caller-supplied streams
remain caller-owned; named-file operations own their stream, flush and close
writes, and remove an incomplete output after failure. The same memory ABI
format, flag, background, signed-stride, colormap, and Adam7 behavior is reused.

The file/stdio symbols are frozen separately in
`abi/symbols/libpng4cj-png-image-file-stdio-v1.txt`. The strict consumer proves
file and caller-owned stdio read/write, caller reuse and close, malformed/open/
read/write failures, incomplete-file removal, exact symbols, and relocated
loading.

The classic stateless milestone adds the first callback-free utility cluster:

- `png_access_version_number`
- `png_sig_cmp`
- `png_get_uint_32`, `png_get_uint_16`, and `png_get_int_32`
- `png_save_uint_32`, `png_save_int_32`, and `png_save_uint_16`

The declarations use the frozen libpng integer and byte-pointer types, and the
exact symbols are listed in `abi/symbols/libpng4cj-classic-stateless-v1.txt`.
The strict consumer freezes every function-pointer signature and compares
signature ranges, signed edge behavior, and big-endian read/write vectors with
the libpng `1.6.58` source algorithms, including its `INT32_MIN` read result.

These surfaces are not yet the complete libpng16 drop-in ABI, a portable
release, or an LTS artifact. Raw callback and allocator crossings, remaining
public symbols, and non-macOS ABI packaging remain outside this checkpoint.
