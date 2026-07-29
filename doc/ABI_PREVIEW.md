# C ABI Surfaces

[English](ABI_PREVIEW.md) | [简体中文](zh-CN/C_ABI.md)

libpng4cj provides a preview C ABI implemented directly by Cangjie `@C`
exports. It is intended for early integration and compatibility work. It is not
yet a complete replacement for `libpng16`.

## Build And Test

On macOS arm64:

```sh
./tools/test_abi_preview.sh
```

The output directory contains the dynamic library, public headers, symbol
receipts, and strict C11 consumer binaries. The suite checks both the original
output location and relocation-sensitive loading from a copied directory.

## Exported Surface

The manifests currently cover `134/258` default public libpng symbols. Five
additional `png4cj_*` preview extension symbols are exported and are not
counted against the upstream total.

Supported groups include:

- five `png4cj_*` preview discovery and RGBA8 decode functions
- eight simplified `png_image` memory, file, and stdio functions
- classic version, signature, endian, and grayscale-palette utilities
- read and write owner creation and destruction
- error, warning, allocator, and IO callback contexts
- user dimensions and per-chunk allocation limits
- `png_read_info`, source-packed row delivery, and `png_read_end`
- IHDR, scalar, fixed, floating, physical, color, text, ICC, and extended
  metadata getters
- write callbacks, signature emission, one-shot and streamed raw chunks, CRC,
  flush, and stdio output

Exact symbol membership is defined by files under [`abi/symbols/`](../abi/symbols/).

## Headers

[`abi/include/png.h`](../abi/include/png.h) exposes the supported libpng-shaped
types, macros, structures, and function declarations. It intentionally does
not present itself as a complete upstream header.

[`abi/include/libpng4cj_preview.h`](../abi/include/libpng4cj_preview.h) exposes
the small `png4cj_*` preview API.

Consumers should compile against the headers shipped with the same libpng4cj
build as the dynamic library.

## Runtime Lifecycle

A native C consumer must initialize the Cangjie runtime before loading and
calling the library. The verified lifecycle is:

1. `InitCJRuntime`
2. `LoadCJLibraryWithInit`
3. call the libpng4cj exports
4. release all libpng4cj owners and buffers
5. `FiniCJRuntime`

The consumer examples under [`test/abi_consumer/`](../test/abi_consumer/)
demonstrate the complete sequence.

## Ownership Rules

- `png_struct` and `png_info` values are opaque Cangjie-owned handles.
- destroy functions invalidate the handle and write NULL through the supplied
  pointer where required by the compatible API.
- caller-provided read, write, error, memory, and stdio contexts remain owned by
  the caller.
- memory returned by the classic allocation surface must be released through
  the matching libpng4cj free path.
- borrowed metadata pointers remain valid only while their owning info object
  remains live and unchanged.
- callback dispatch occurs outside the internal registry lock.

## Error Boundary

Cangjie exceptions do not cross the C ABI. Recoverable operations report their
documented return value or image error state. Fatal classic `png_error` paths
terminate when no compatible non-local-jump boundary is available.

The preview does not claim complete `setjmp`/`longjmp` compatibility.

## Platform Status

The complete dynamic-library, symbol, consumer, and relocation receipt is
currently available for macOS arm64. Other platforms may use the native
Cangjie API, but no portable C ABI artifact is claimed until a platform-specific
build and consumer receipt is added.

## Open Compatibility Areas

- the remaining `124` default public symbols
- complete classic transform setters and transformed row timing
- full progressive and user-callback C trampolines
- exact upstream `setjmp`/`longjmp` behavior
- canonical `libpng16` naming, installation, and package metadata
- non-macOS C ABI artifacts and receipts
