# pngwtran.c Translation Ledger

Frozen source: `vendor/libpng-1.6.58/pngwtran.c` at upstream commit
`3061454d980de7d53608f594194cfac722721d2a`.

Regenerate the exact top-level function inventory with:

```sh
sh ./tools/update-pngwtran-inventory.sh
```

The generated inventory is
`doc/upstream/libpng-1.6.58-pngwtran-functions.tsv`. The generator asserts the
frozen count of five functions, so source drift fails visibly.

Status meanings:

- `translated`: the default-config row behavior and its place in the write
  pipeline are implemented under a traceable Cangjie anchor and covered by tests
- `partial`: useful behavior exists, but one or more default-config branches or
  ordering rules are missing
- `pending`: no honest translated body exists

| Line | Upstream function | Cangjie anchor | Status | Verification | Remaining boundary |
| ---: | --- | --- | --- | --- | --- |
| 24 | `png_do_pack` | `pngWritePack` in `src/png_write_transform.cj` | translated | `PngWriteTransformTestSuite.packsOneTwoAndFourBitRowsBeforeBothWriteModes`; standalone consumer indexed write | Native 1/2/4-bit packing and row-shape updates are covered; classic C ABI setter/state wiring remains separate |
| 171 | `png_do_shift` | `pngWriteShift` and `repeatWriteSample` in `src/png_write_transform.cj` | translated | packed grayscale and 8/16-bit multi-channel write-transform tests | Frozen packed masks, component selection, sample repetition, and network-order 16-bit output are present; classic C ABI setter/state wiring remains separate |
| 309 | `png_do_write_swap_alpha` | `pngWriteSwapAlpha` in `src/png_write_transform.cj` | translated | 8-bit GA and 16-bit RGBA write-order tests | GA/RGBA alpha-first input is converted to alpha-last PNG order; classic C ABI setter/state wiring remains separate |
| 403 | `png_do_write_invert_alpha` | `pngDoReadInvertAlpha` reused by `applyInitializedPngWriteTransforms` | translated | 8-bit GA and 16-bit RGBA write-order tests | The row operation is direction-independent and covers GA/RGBA 8/16-bit alpha complement; classic C ABI setter/state wiring remains separate |
| 500 | `png_do_write_transformations` | `PngWriteTransformInitialization` and `applyInitializedPngWriteTransforms` in `src/png_write_transform.cj` | translated | canonical-stage, whole-image, Adam7, row writer, custom sink, user callback, and standalone consumer tests | The frozen default order is preserved across user transform, filler strip, packswap, pack, byte swap, shift, alpha swap/invert, BGR, and invert-mono; complete classic write API/state parity remains separate |

## Current Result

The frozen `pngwtran.c` inventory is `5/5 translated`, `0/5 partial`, and
`0/5 pending` for the native Cangjie write pipeline. This count describes the
five top-level functions in `pngwtran.c`; it does not claim that every public
classic write setter or `png_struct` state API is exported through the C ABI.

Several dispatcher dependencies are implemented in shared transform modules
because upstream also owns them outside `pngwtran.c`: filler stripping,
packswap, 16-bit byte swap, BGR, and monochrome inversion. Their execution order
is still accounted for by the `png_do_write_transformations` row above.

## Translation Rule

Future write-side work should update this ledger only when behavior in the
frozen five-function source changes or a claimed anchor is replaced. Public C
ABI coverage belongs to the symbol manifests and ABI guide, not to this
function-body count.
