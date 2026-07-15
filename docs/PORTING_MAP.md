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
