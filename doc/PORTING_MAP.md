# libpng 1.6.58 Porting Status

[English](PORTING_MAP.md) | [简体中文](zh-CN/PORTING_STATUS.md)

libpng4cj follows the ownership boundaries of libpng `1.6.58` while exposing a
Cangjie-native API. The upstream source is vendored as a fixed reference and is
not linked into the Cangjie implementation.

## Source Mapping

| Upstream source | Cangjie responsibility |
| --- | --- |
| `png.c`, `pngerror.c`, `pngmem.c` | runtime, errors, signatures, checksums, memory contracts |
| `pngread.c`, `pngrio.c`, `pngrutil.c` | read lifecycle, IO, chunks, inflate, metadata |
| `pngrtran.c`, `pngtrans.c` | read transforms and shared transform state |
| `pngpread.c` | progressive read lifecycle |
| `pngwrite.c`, `pngwio.c`, `pngwutil.c` | write lifecycle, IO, filtering, deflate, chunk emission |
| `pngwtran.c` | write transforms |
| `pngget.c`, `pngset.c` | metadata getters, setters, and validation |
| `png.h`, `pngconf.h`, `pnglibconf.h` | public C ABI declarations and configuration boundary |
| `scripts/symbols.def` | exported-symbol comparison baseline |

## Implemented Native Surface

- signature, endian, CRC, chunk framing, validation, and configurable limits
- non-interlaced and Adam7 decoding
- incremental progressive reading
- read filters and the complete `pngrtran.c` function inventory
- gamma, background composition, alpha, palette, packing, quantization, and
  channel transforms
- standard and extended PNG metadata
- non-interlaced and Adam7 encoding
- row-at-a-time and callback-driven streaming output
- complete `pngwtran.c` function inventory
- simplified direct, linear, and colormap image APIs

## ABI Surface

The C ABI is built from direct Cangjie `@C` exports. It currently manifests
`180/258` default public libpng symbols, including simplified image operations,
classic read ownership, IO, row delivery, read transforms, metadata getters and
safe setters, memory and error callbacks, limits, and write lifecycle/output.

See [C ABI Surfaces](ABI_PREVIEW.md) for the supported contract and explicit
limits. The exact supported and remaining sets are checked by
`tools/check_abi_coverage.sh`.

## Alignment Evidence

- [Read-transform alignment](PNG_RTRAN_TRANSLATION_LEDGER.md)
- [Write-transform alignment](PNG_WTRAN_TRANSLATION_LEDGER.md)
- [Frozen upstream inventories](upstream/)
- [Compatibility and dependency matrix](COMPATIBILITY_AND_DEPENDENCY_MATRIX.md)
