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
- `png-classic-read-handle-consumer`: strict C11 read/info lifecycle and
  warning/error callback boundary proof
- `png-classic-core-info-consumer`: strict C11 IHDR/scalar getter proof
- `png-classic-row-read-consumer`: strict C11 raw row/image/read-end proof

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

The first stateful classic milestone adds opaque caller-held read and info
handles:

- `png_create_read_struct` and `png_create_read_struct_2`
- `png_create_info_struct`
- `png_destroy_info_struct` and `png_destroy_read_struct`
- `png_set_error_fn` and `png_get_error_ptr`
- `png_set_mem_fn` and `png_get_mem_ptr`

The handles are native tokens backed by a mutex-protected Cangjie registry.
Read creation accepts libpng-compatible `1.6.*` version strings, info handles
retain their creating read handle, and destruction writes NULL through every
successfully released pointer-to-pointer argument. Caller error and memory
contexts can be replaced and read back without transferring ownership. The
exact nine-symbol set is frozen in
`abi/symbols/libpng4cj-classic-read-handle-v1.txt`.

The strict lifecycle consumer covers incompatible versions, null inputs,
independent info destruction, two-info cascade destruction, context updates,
exact function-pointer declarations, and original/relocated loading.

The classic error milestone adds direct Cangjie `png_warning` and `png_error`
exports, frozen in `abi/symbols/libpng4cj-classic-error-v1.txt`. Callback
addresses are snapshotted under the registry mutex and invoked after releasing
the lock, allowing callback-side context lookup and later replacement. Missing
warning callbacks use the default `libpng warning:` stderr diagnostic. Fatal
errors invoke the current error callback first, then use the default
`libpng error:` diagnostic and process termination if the callback is absent
or returns. The strict consumer proves all three fatal outcomes in independent
processes so a terminating path cannot corrupt the main acceptance process.

The classic memory milestone adds direct Cangjie exports for `png_malloc`,
`png_calloc`, `png_malloc_warn`, `png_free`, `png_malloc_default`, and
`png_free_default`, frozen in
`abi/symbols/libpng4cj-classic-memory-v1.txt`. `png_create_read_struct_2`
invokes the configured allocator through a temporary live creation context and
returns the allocator-owned block as the opaque read handle. Info handles and
explicit allocations use the current allocator; later `png_set_mem_fn` calls
affect future allocations, while already-created objects retain the allocator
snapshot that owns their release. Default allocation APIs bypass user
callbacks.

For the frozen macOS arm64 default configuration, the strict consumer verifies
the upstream `png_struct` and `png_info` requests at 1224 and 352 bytes. It also
proves callback-side `png_get_mem_ptr`, zero-filled calloc, allocator-family
matching after replacement, creation and warn-return allocation failure,
fatal allocation failure in an isolated process, duplicate-free suppression,
and original/relocated loading.

The classic read-IO milestone adds direct Cangjie exports for `png_init_io`,
`png_set_read_fn`, `png_get_io_ptr`, `png_set_sig_bytes`, and `png_read_info`,
frozen in `abi/symbols/libpng4cj-classic-read-io-v1.txt`. Custom callbacks are
snapshotted under the registry mutex and invoked after unlock, so the callback
can recover its current context through `png_get_io_ptr`. NULL read callbacks
select caller-owned stdio input. Signature-prefix counts preserve the upstream
negative-to-zero, `0..8`, and fatal `>8` behavior.

The current `png_read_info` bridge requests exact signature and chunk-framing
lengths through the selected input, captures through IEND, validates and
decodes with the existing Cangjie PNG pipeline, and retains the decoded state
on the classic read handle for later getter and row APIs. The strict consumer
proves custom callback replacement, callback-side context lookup, four-byte
signature prefix continuation, stdio input, truncated and excessive-prefix
fatal paths, pre-allocation oversized-chunk rejection, exact symbols/signatures,
and original/relocated loading.

The classic core-info milestone adds `png_get_IHDR`, `png_get_rowbytes`,
`png_get_channels`, and the seven easy-access IHDR scalar getters, frozen in
`abi/symbols/libpng4cj-classic-core-info-v1.txt`. Header facts are visible only
through the exact live `png_info` populated by `png_read_info`; null, unknown,
wrong-owner, pre-read, other-info, and destroyed handles return zero. Failed
`png_get_IHDR` calls preserve caller outputs, successful calls accept any
nullable output combination, and packed grayscale plus Adam7 RGBA facts pass
strict C11 original/relocated proof.

The classic row-read milestone adds `png_read_row`, `png_read_rows`,
`png_read_image`, and `png_read_end`, frozen in
`abi/symbols/libpng4cj-classic-row-read-v1.txt`. Row and row-array calls
consume retained raw source-packed rows sequentially; NULL row/display
destinations follow the wrapper's call behavior, and whole-image delivery
copies final reconstructed Adam7 rows. Read-end seals remaining retained rows
and accepts NULL or an owner-matched live info handle. The strict consumer
checks packed 1-bit grayscale row, display, array, and no-destination behavior;
Adam7 RGBA complete-image parity; early read-end sealing; stale-handle no-op;
exact symbols/signatures; and original/relocated loading.

These surfaces are not yet the complete libpng16 drop-in ABI, a portable
release, or an LTS artifact. Setjmp/longjmp, transformed rows, Adam7
pass-progress/display combination, exact callback/cursor timing, broader
read-end metadata/write state, remaining callback families and public symbols,
and non-macOS ABI packaging remain outside this checkpoint.
