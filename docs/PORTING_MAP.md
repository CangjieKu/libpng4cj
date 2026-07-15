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

The LP-S003 decoder entry returns packed file-format rows. By itself it does not
expand palettes or sub-byte samples, swap 16-bit channels, apply
transparency/background/gamma transforms, execute Adam7, expose progressive IO,
or claim full read parity. Compressed and inflated data default to separate
256,000,000-byte limits.

## Implemented First Read Transforms

LP-S004A maps the first palette and expansion parts of `pngrutil.c`,
`pngrtran.c`, `pngget.c`, and `pngset.c` into:

- `png_metadata.cj`: copy-owned PLTE/tRNS state, strict chunk contracts, palette
  access, and implicit opaque palette alpha
- `png_transform.cj`: 1/2/4-bit sample unpacking and copy-owned RGBA8 rows for
  every PNG color type at bit depths up to 8
- `png_decode.cj`: metadata retention alongside the existing packed raw rows

The RGBA8 convenience path expands palette entries, grayscale samples, and
tRNS color keys while preserving existing grayscale-alpha and truecolor-alpha
values. A separate 256,000,000-byte transformed-output limit prevents packed
inputs from expanding without a caller-visible bound.

LP-S004A is not the complete `pngrtran.c` surface. At that checkpoint the
16-bit path, gamma/background/color-space handling, alpha composition,
channel/filler and user transforms, remaining standard metadata, unknown
chunks, Adam7, and progressive reading remained later packets.

## Implemented Bit-Depth Conversion

LP-S004B extends `png_transform.cj` with a copy-owned RGBA16 surface and the
three libpng-aligned bit-depth operations:

- 8-to-16 expansion uses byte replication, exactly `value * 257`
- 16-to-8 `Strip` retains the high byte and discards the low byte
- 16-to-8 `Scale` uses the exact `(value * 255 + 32895) >> 16` formula

`decodePngRgba16NonInterlaced` returns host-numeric `Array<UInt16>` channels;
PNG network byte order is consumed only at the packed-row transform boundary.
All source color types are supported, including exact 16-bit grayscale/RGB
tRNS matching and 8-bit palette/alpha expansion to full UInt16 range.

The overloads accepting `Png16To8Mode` make 16-bit reduction explicit. Existing
RGBA8 overloads without a mode still reject 16-bit source images, so callers do
not lose precision through an implicit default. RGBA16 output is charged at
eight bytes per pixel against the transformed-output limit.

## Implemented Fixed Color And Display Metadata

LP-S004C extends the `pngrutil.c`, `pngget.c`, and `pngset.c` translation with
immutable native representations for:

- gAMA file gamma as PNG fixed-point UInt32
- cHRM signed fixed-point white/red/green/blue chromaticities
- sRGB rendering intent without replacing simultaneously present gAMA/cHRM
- source-depth-validated sBIT channel significance
- source-color-aware bKGD samples, including indexed palette expansion
- pHYs pixels-per-unit values and the frozen upstream unit byte

All six chunks are unique and pre-IDAT. gAMA, cHRM, sRGB, and sBIT additionally
precede PLTE; indexed bKGD requires PLTE first. Metadata is retained unchanged
through packed, RGBA8, and RGBA16 result surfaces. This packet deliberately
does not apply gamma precedence, gamma correction, or background composition.

Gamma/background transforms, alpha composition, channel/filler and user
transforms, compressed/text/time metadata, unknown chunks, Adam7, and
progressive reading remained later packets at that checkpoint.

## Implemented Compressed Text Time And Unknown Metadata

LP-S004D extends `pngrutil.c`, `png.c`, `pngget.c`, and `pngset.c` translation
through `png_extended_metadata.cj` and the shared decode/zlib layers:

- iCCP uses bounded unknown-length zlib inflate and validates the declared
  profile length, ICC header, PNG color-space compatibility, forbidden profile
  classes, PCS encoding, and tag-table ranges
- tEXt, zTXt, and iTXt retain copy-owned byte arrays without Latin-1/UTF-8
  conversion or normalization; compressed forms require complete zlib input
- tIME retains one validated seven-byte modification timestamp, including the
  PNG/libpng leap-second value of 60
- `PngUnknownChunkPolicy` exposes discard, retain-ancillary, and retain-all
  behavior while preserving each retained chunk's type, payload, safe-to-copy
  bit, and after-IHDR/after-PLTE/after-IDAT location

Compressed metadata output is bounded by `PngReadLimits.maxChunkBytes`, matching
the frozen reader's single application-level decompression limit. Recognized
text and time chunks after IDAT close the consecutive-IDAT sequence. All new
metadata is propagated through packed, RGBA8, and RGBA16 result surfaces.

This packet does not apply ICC profiles, gamma, or backgrounds, and does not
retain eXIf, sPLT, hIST, oFFs, pCAL, or sCAL as recognized standard metadata.
Advanced transforms, Adam7, progressive reading, write support, and C ABI
compatibility remain later work.

## Implemented Late Channel Transforms

LP-S004E maps the first low-coupling tail of `png_do_read_transformations` and
the shared `pngtrans.c` channel operations into `png_channel_transform.cj`:

- `InvertMonochrome` affects grayscale-family source color channels without
  changing alpha
- `InvertAlpha` and `SwapAlpha` operate only when source alpha or tRNS gives
  the PNG semantic alpha
- `Bgr` exchanges red and blue channels
- selected operations always execute in frozen upstream order:
  invert monochrome, invert alpha, BGR, then swap alpha

`PngRgba8Rows` and `PngRgba16Rows` now report `PngRgbaLayout` as `RGBA`,
`BGRA`, `ARGB`, or `ABGR`. Existing transform/decode calls select no channel
operations and therefore remain `RGBA`. Explicit transform-array overloads
apply operations while each already bounded output row is being created, so
the packet does not add a second full transformed-image allocation.

sBIT unshift, strip-alpha/filler, RGB-to-gray, gamma/background/alpha-mode,
quantization, packing/packswap, byte swap, and user callbacks remain later
LP-S004 work.

## Implemented Row Shapes

LP-S004F adds a generalized copy-owned output surface in
`png_row_shape_transform.cj` for the strip-alpha and filler stages of
`png_do_read_transformations`:

- opaque output is naturally three-channel `RGB` or `BGR`
- source or tRNS-derived alpha is retained unless strip-alpha is selected
- filler-before/filler-after adds a non-alpha `X` channel only after alpha has
  been stripped or when no semantic alpha exists
- add-alpha-before/add-alpha-after uses the same value position but records a
  semantic alpha layout
- invert-alpha precedes filler, so newly added alpha is not inverted; swap-alpha
  follows filler, so newly added alpha participates while plain filler does not
- UInt16 output uses the full filler value, while 8-bit and explicit 16-to-8
  output use its low byte, matching the frozen upstream row depth at that stage

The result reports an explicit `RGB`, `BGR`, `RGBA`, `BGRA`, `ARGB`, `ABGR`,
`RGBX`, `BGRX`, `XRGB`, or `XBGR` layout and charges the transformed-output
limit using the final three- or four-channel shape. Existing fixed RGBA8/RGBA16
convenience APIs remain unchanged.

RGB-to-gray, gamma/background/alpha-mode, quantization, packing/packswap, byte
swap, and user callbacks remain later LP-S004 work.

## Implemented RGB-to-Gray Fixed Core

LP-S004H maps the fixed-coefficient core of `png_do_rgb_to_gray` and its public
configuration behavior into `png_rgb_to_gray_transform.cj`:

- the historical default uses red `6968`, green `23434`, and blue `2366` on
  libpng's `32768` fixed-point scale
- custom red and green weights use the public `100000` scale, truncate during
  conversion to the internal scale, and leave blue as the exact remainder
- valid custom weights report `customCoefficientsAccepted = true`; negative or
  over-sum weights retain the historical coefficients and report `false`,
  matching the nonfatal ignore branch of `png_set_rgb_to_gray_fixed` while the
  warning callback surface remains deferred
- 8-bit nongray pixels truncate the weighted sum; UInt16 pixels add `16384`
  before the final shift and therefore match upstream rounding
- equal RGB values are preserved exactly and do not set nongray status
- `Convert` returns transformed rows with `hadNonGrayPixels`; `RequireGray`
  rejects nongray input with `RgbToGrayMismatch`
- source and tRNS-derived alpha survive unless strip-alpha removes them
- generalized output reports `G`, `GA`, `AG`, `GX`, or `XG`, with final limits
  charged against the actual one- or two-channel shape
- conversion executes before explicit 16-to-8 reduction, inversion, sBIT
  unshift, filler/add-alpha, and alpha swap; BGR is a grayscale no-op

Palette, grayscale-family, native 8-bit, native UInt16, and explicit Strip/Scale
inputs share the same output contract. Retained metadata remains unchanged.

cHRM-derived default coefficients, gamma linearization and lookup tables,
background/alpha composition, warning callbacks, and transformed metadata
projection remain later LP-S004 work, along with quantization, packing/packswap,
byte swap, and user callbacks.

## Translation-First Realignment

LP-S004I adds `tools/update-pngrtran-inventory.sh`, the generated
`libpng-1.6.58-pngrtran-functions.tsv`, and
`PNG_RTRAN_TRANSLATION_LEDGER.md`. The inventory freezes 45 top-level
`pngrtran.c` functions with source lines and fails if the count drifts.

The first structural realignment covers:

- `png_set_rgb_to_gray_fixed` as `pngSetRgbToGrayFixed`, including fixed-point
  truncation and nonfatal ignore behavior for invalid custom coefficients
- the non-gamma 8-bit and 16-bit branches of `png_do_rgb_to_gray` as
  `pngDoRgbToGray8` and `pngDoRgbToGray16`
- explicit separation between translated row behavior and still-partial
  setter/state/metadata/compile-guard parity

Future transform packets should advance entries in the translation ledger and
prove them against the frozen source before Cangjie-specific optimization.

## Implemented Read Transform State

LP-S004J adds `png_read_transform_state.cj` as the first translated
`png_struct`-shaped read-transform state carrier:

- `png_rtran_ok` rejects setters after row initialization, rejects
  IHDR-dependent setters before the header, and enables explicit
  detect-uninitialized state on success
- Scale and Strip retain independent bits while the existing Scale mode wins
  when both are selected, matching frozen transform order
- strip-alpha projects to `PngRowShapeTransform`
- expand, palette-to-RGB, gray-depth expansion, tRNS-to-alpha, expand-16, and
  gray-to-RGB preserve their exact overlapping upstream bit semantics
- stateful fixed RGB-to-gray configuration requires IHDR and requests expand
  for indexed input before projecting to the existing translated row core

Application error/warning callbacks, transformed IHDR projection, direct C ABI
setters, and the complete stateful `png_do_read_transformations` dispatcher
remain later translation work.

## Implemented Non-Gamma Read Initialization

LP-S004K adds `png_read_transform_init.cj` as the bounded stateful anchor for
the non-gamma portions of the three read initializer functions:

- palette initialization ignores all-opaque tRNS entries, distinguishes binary
  transparency from partial alpha, and follows the post-Strip-Alpha effective
  tRNS state
- RGB initialization separates inherent GA/RGBA alpha from grayscale/RGB tRNS
- pre-compose Strip Alpha cancels `PNG_EXPAND_tRNS` and effective tRNS input
  without rewriting the source color-type classification
- the initialization result exposes expand, strip-alpha, RGB-to-gray,
  gray-to-RGB, scale16, strip16, and expand16 in frozen execution order
- initialization is one-shot, marks row state initialized, and therefore makes
  subsequent setters fail through the translated `png_rtran_ok` lifecycle

The initializer ledger entries remain partial: background and alpha-mode
optimization, palette mutation, gamma, cHRM-derived RGB coefficients,
transformed info projection, and complete row dispatch are still absent.

## Implemented Direct Gray-To-RGB Row Body

LP-S004L adds `png_gray_to_rgb_transform.cj` as the direct non-gamma
translation of `png_do_gray_to_rgb`:

- `PngReadRowInfo` carries width, bit depth, color type, channels, pixel depth,
  and row bytes at the current transform stage
- 8-bit grayscale expands `G -> RGB`, and grayscale-alpha expands
  `GA -> RGBA`
- 16-bit network-byte rows expand `GG -> RRGGBB` and
  `GGAA -> RRGGBBAA` without converting sample byte order
- sub-byte and already-color rows retain the upstream no-op behavior
- output rows are copy-owned because Cangjie arrays cannot be expanded in
  place; malformed row lengths fail before transformation
- `applyInitializedPngGrayToRgbStage` applies the body only when the frozen
  initialization contains `GrayToRgb`

The direct function is now translated, but the complete stateful dispatcher
remains partial. The narrow adapter does not execute preceding tRNS expansion,
strip-alpha, background composition, gamma, or later row transforms.

## Implemented Non-Gamma Transform Info Projection

LP-S004M adds `png_read_transform_info.cj` as a bounded translation of
`png_read_transform_info`:

- `PngReadTransformInfo` exposes projected width, height, bit depth, color
  type, channels, pixel depth, row bytes, and remaining tRNS state
- indexed Expand projects to RGB or RGBA at 8-bit depth based on retained
  post-initialization tRNS count, including all-opaque palette tRNS
- non-palette Expand raises sub-byte gray to 8 bits and adds alpha only when
  effective tRNS expansion remains enabled
- Expand and Strip Alpha clear projected tRNS state
- Scale16 or Strip16 project 16-bit input to 8 bits; Expand16 can subsequently
  project non-palette 8-bit output back to 16 bits
- Gray-to-RGB projection precedes RGB-to-gray exactly as in the frozen info
  function, even though the runtime row dispatcher orders those stages
  differently
- final color type determines channels, pixel depth, and PNG row bytes

The ledger entry remains partial. Palette byte synchronization,
gamma/file-gamma, background, filler/add-alpha, quantize, pack, user-transform,
and complete metadata projection are still deferred.

## Implemented Direct Scale16 And Strip16 Row Bodies

LP-S004N adds `png_16_to_8_transform.cj` as the direct translation of
`png_do_scale_16_to_8` and `png_do_chop`:

- input rows retain PNG network-byte component order and are validated against
  the current `PngReadRowInfo` before any pair is read
- `pngDoScale16To8` applies `(V * 255 + 32895) >> 16` to every G, GA, RGB, or
  RGBA component
- `pngDoChop` retains every component high byte and discards the low byte
- both bodies return copy-owned rows because Cangjie arrays cannot shrink in
  place and preserve copy-owned no-op behavior when bit depth is not 16
- output row info retains width and color type while setting bit depth to 8,
  pixel depth to `8 * channels`, and row bytes to `width * channels`
- `applyInitializedPng16To8Stages` executes Scale before Strip; when both are
  selected, Scale changes bit depth to 8 and the following Chop is a no-op,
  matching the frozen dispatcher precedence

The direct bodies do not implement Expand16, gamma/background, quantize, byte
swap, user transforms, or the complete stateful row dispatcher.

## Implemented Significant-Bit Unshift

LP-S004G extends `png_channel_transform.cj` and the generalized row-shape path
with the `PNG_SHIFT` stage represented by explicit
`UnshiftSignificantBits` selection:

- retained sBIT values right-shift each color channel independently
- absent sBIT and values equal to or wider than the current component depth are
  no-ops, matching `png_do_unshift`
- source or tRNS-derived alpha shifts only while it remains semantic output;
  stripped alpha, plain filler, and newly added alpha do not shift
- the frozen order is invert monochrome, invert alpha, sBIT unshift, BGR,
  filler/add-alpha, then alpha swap
- expanded palette colors use palette sBIT values
- UInt16 output applies the shift at 16-bit depth, while explicit Strip/Scale
  output reduces to 8 bits before applying the 8-bit shift

The fixed RGBA convenience results and generalized RGB/RGBA/X results share the
same shift resolver. Retained sBIT metadata remains unchanged.

RGB-to-gray, gamma/background/alpha-mode, quantization, packing/packswap, byte
swap, and user callbacks remain later LP-S004 work.
