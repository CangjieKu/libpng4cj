# libpng 1.6.58 Porting Map

The first translation pass keeps upstream ownership boundaries recognizable.
Refactoring for a more idiomatic Cangjie API happens only after behavior parity.

| Upstream source | libpng4cj owner | Scope |
| --- | --- | --- |
| `png.c` | `runtime/` and `checksum/` | version, signature, CRC, shared runtime helpers |
| `pngerror.c` | `runtime/error` | warnings, fatal errors, longjmp bridge contract |
| `pngmem.c` | `runtime/memory` | allocation policy and user allocators |
| `pngread.c` | `read/decoder` | high-level read lifecycle |
| `pngrio.c` | `read/io` | default and custom read callbacks |
| `pngrutil.c` | `read/chunks` | chunk parsing, validation, IDAT utilities |
| `pngrtran.c` | `transform/read` | read-side pixel transformations |
| `pngpread.c` | `read/progressive` | progressive state and callbacks |
| `pngwrite.c` | `write/encoder` | high-level write lifecycle |
| `pngwio.c` | `write/io` | default and custom write callbacks |
| `pngwutil.c` | `write/chunks` | chunk emission, filtering, compression |
| `pngwtran.c` | `transform/write` | write-side transformations |
| `pngget.c` | `info/get` | metadata getters |
| `pngset.c` | `info/set` | metadata setters and validation |
| `pngtrans.c` | `transform/common` | shared transform configuration |
| `arm/`, `intel/`, `mips/`, `powerpc/`, `riscv/`, `loongarch/` | `backend/` | optional architecture acceleration |
| `png.h`, `pngconf.h`, generated `pnglibconf.h` | `compat/include` | public C API and configuration surface |
| `scripts/symbols.def` | `compat/symbols` | exported-symbol baseline |

## Compatibility Rule

The native Cangjie facade may be smaller and safer, but the `libpng16`
compatibility surface must preserve upstream default-config behavior. Cangjie
exceptions must be converted before control returns across the C ABI.

## Implemented Read Foundation

LP-S002 maps the first parts of `png.c`, `pngerror.c`, and `pngrutil.c` into:

- `png_error.cj`: stable error categories and byte offsets
- `png_chunk.cj`: owned read session, user limits, chunk framing, and CRC gate
- `png_ihdr.cj`: IHDR model, field validation, and row-byte derivation

The default limits currently match the vendored prebuilt libpng configuration:
8,000,000 bytes per chunk and 1,000,000 pixels per image dimension. The
architecture-specific transformed-row allocation gate remains later work.

## Implemented Non-Interlaced Rows

LP-S003 extends the first parts of `pngread.c`, `pngrutil.c`, and `pngrtran.c`
through these Cangjie-owned files:

- `png_zlib.cj`: direct FFI to external zlib `uncompress2`, with exact output
  length and consumed-input checks
- `png_filter.cj`: None, Sub, Up, Average, and Paeth reversal
- `png_decode.cj`: PLTE ordering checks, consecutive IDAT collection, IEND
  finalization, bounded inflate, and copy-owned non-interlaced raw rows

The decoder returns packed file-format rows. It does not yet expand palettes or
sub-byte samples, swap 16-bit channels, apply transparency/background/gamma
transforms, execute Adam7, expose progressive IO, or claim full read parity.
Compressed and inflated data default to separate 256,000,000-byte limits.
