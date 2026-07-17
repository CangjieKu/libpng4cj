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
quantization, packing/packswap, byte swap, and user callbacks were outside the
LP-S004E packet; later sections record their current status.

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
swap, and user callbacks were outside the LP-S004F packet; later sections
record their current status.

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

cHRM-derived default coefficients were outside LP-S004H and are now connected
through LP-S004BL. Gamma linearization and lookup tables, background/alpha
composition, warning callbacks, transformed metadata
projection, quantization, packing/packswap, byte swap, and user callbacks were
outside the LP-S004H packet; later sections record their current status.

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
  gray-to-RGB, scale16, strip16, quantize, and expand16 in frozen execution
  order
- quantize enablement, mode, full-color palette lookup, and Indexed remap are
  snapshotted before row initialization and returned through copy-owned accessors
- initialization is one-shot, marks row state initialized, and therefore makes
  subsequent setters fail through the translated `png_rtran_ok` lifecycle

The initializer ledger entries remain partial: later packets connected
background and alpha-mode optimization, Gamma, cHRM-derived RGB coefficients,
and palette initialization, while complete row dispatch and transformed info
projection still remain open.

## Implemented Initialized Non-Gamma Read Pipeline

LP-S004AF adds `png_initialized_read_pipeline.cj` as the first combined row and
decoded-image entry over the translated initialization snapshot. LP-S004AG,
LP-S004AH, LP-S004AI, and LP-S004AJ extend the same entry through the translated
late-channel stages:

- one-shot initialization retains an immutable copy of the fixed RGB-to-gray
  policy, coefficients, and accepted-custom-coefficient status
- source-shaped `pngDoRgbToGray` converts 8-bit RGB/RGBA into Gray/GA and
  network-order 16-bit RGB/RGBA into Gray/GA with exact row-info updates
- equal RGB samples are preserved exactly, alpha bytes remain in place, and
  `hadNonGrayPixels` records whether weighted conversion was required
- `RequireGray` rejects the first nongray pixel while `Convert` returns the
  transformed row and status
- `applyInitializedPngReadStages` composes Expand, Strip Alpha, RGB-to-gray,
  Gray-to-RGB, Scale/Strip16, Quantize, Expand16, Invert Mono, Invert Alpha,
  Unshift, Unpack, BGR, Filler/Add Alpha, and Swap Alpha in frozen runtime order
- late-channel state is lifecycle-gated and copied into the immutable one-shot
  initialization snapshot, including significant-bit values and low-16-bit
  filler value/placement
- Invert Mono precedes Invert Alpha, Invert Alpha precedes Unshift, Unpack
  grows sub-byte Gray/Indexed rows before BGR, BGR exchanges red/blue before
  filler growth, filler precedes Swap Alpha, plain filler does not become
  semantic alpha, and added alpha swaps between leading/trailing positions
  without changing the filler-stage color-type contract
- `transformPngRowsInitialized` applies the same snapshot to every decoded
  non-interlaced row, aggregates nongray status, enforces transformed-byte
  limits, and returns copy-owned rows

The public entry covers the currently translated non-gamma stage set. Gamma,
background composition, C ABI/raw-pointer user transforms, Adam7 execution,
and progressive input remain outside this combined path.

## Implemented Read Packing Setter And Initialized Unpack

LP-S004AJ connects the direct packed-row body to translated read state:

- `setPacking()` requires a known IHDR and enables only for 1/2/4-bit source
  rows, matching the read-side branch of `pngtrans.c::png_set_packing`
- 8/16-bit and color-only IHDR markers accept the setter without fabricating an
  active packing stage
- the immutable initialization snapshot places Unpack after Unshift and before
  BGR without changing existing stage ordinal values
- initialized Gray and Indexed rows retain raw sample values while bit depth,
  pixel depth, and row bytes grow exactly to one byte per sample
- disabled and unsupported rows stay copy-owned, malformed rows fail before
  stage selection, and whole-image transformed-byte limits include unpack growth
- `projectPngReadTransformInfo` now projects active packing to 8-bit row shape

PackSwap is connected by LP-S004AK, read-side byte swap by LP-S004AL, and
palette-index diagnosis by LP-S004AM. User callbacks, write packing,
gamma/background, Adam7, progressive IO, C ABI, and release packaging remain
separate work.

## Implemented Read PackSwap Setter And Initialized Stage

LP-S004AK translates `pngtrans.c::png_set_packswap` and
`pngtrans.c::png_do_packswap` into read state and direct row execution:

- `setPackSwap()` requires a known IHDR and enables only for source bit depths
  1, 2, or 4
- `pngDoPackSwap()` reverses the order of 1-bit samples, 2-bit groups, or
  4-bit nibbles independently in every stored byte
- complete final bytes are transformed, so unused padding bits follow the same
  lookup-table semantics as the frozen C implementation
- width, bit depth, color type, channels, pixel depth, and row bytes remain
  unchanged; transformed, disabled, and unsupported results are copy-owned
- malformed row lengths fail before stage selection or support checks
- immutable initialization places PackSwap after BGR and before Filler
- when Packing is also enabled, the earlier Unpack stage raises bit depth to 8
  and PackSwap becomes a validated no-op without changing the unpacked result
- whole-image initialized execution uses the same stage and existing final-row
  transformed-byte limit

Palette-index diagnostics and read-side byte swap are connected by LP-S004AM
and LP-S004AL. The native read user callback is connected later by LP-S004AN;
write-side PackSwap, gamma/background, Adam7, progressive IO, C ABI, and release
packaging remain separate work.

## Implemented Read Byte Swap Setter And Initialized Stage

LP-S004AL translates `pngtrans.c::png_set_swap` and
`pngtrans.c::png_do_swap` into read state and direct row execution:

- `setSwap()` requires a known IHDR and enables only for source bit depth 16
- `pngDoSwap()` exchanges every adjacent high/low byte pair across the complete
  stored row, independent of color type or channel count
- width, bit depth, color type, channels, pixel depth, and row bytes remain
  unchanged; transformed, disabled, empty, and unsupported results are
  copy-owned
- malformed row lengths fail before stage selection or bit-depth checks
- immutable initialization appends Byte Swap after Filler and Swap Alpha and
  before the user-transform stage connected by LP-S004AN
- added alpha is moved first by Swap Alpha, then every resulting 16-bit
  component has its two bytes exchanged
- when Scale16 or Strip16 runs first, output depth is already 8 and Byte Swap
  becomes a validated copy-owned no-op
- whole-image initialized execution uses the same stage and existing final-row
  transformed-byte limit

The native read callback is connected by LP-S004AN. C ABI callback trampolines,
write-side byte swap, palette-expansion zero-fill compatibility, benign-error
callback delivery, gamma/background, Adam7, progressive IO, and release
packaging remain separate work.

## Implemented Invalid Palette Index Diagnostic Stage

LP-S004AM translates `pngset.c::png_set_check_for_invalid_index` and
`pngtrans.c::png_do_check_palette_indexes` into immutable read diagnosis:

- checking is enabled by default; positive/true enables it and zero, negative,
  or false disables it
- 1/2/4-bit rows scan only the logical width, excluding low padding bits in the
  final byte; 8-bit rows scan one index byte per pixel
- the direct body preserves row bytes and row information while accumulating
  the maximum observed index across rows
- scanning is skipped when the row is not Indexed, the retained PLTE is empty,
  or the PLTE already fills the complete bit-depth index domain
- initialization snapshots the retained PLTE count and appends ordinal `17`
  without renumbering prior stages
- combined execution places Palette Index Check after Unpack and before BGR;
  initialized row and whole-image results report the maximum and whether it is
  outside the retained PLTE
- malformed rows fail before diagnostic argument checks, and all returned rows
  are copy-owned

The read-end benign-error callback, zero-filled palette expansion for invalid
indexes, write-side index diagnosis, gamma/background, Adam7, progressive IO,
C ABI, and release packaging remain separate work. The native read user
transform is connected by LP-S004AN.

## Implemented Native Read User Transform Registration And Stage

LP-S004AN establishes the native Cangjie portion of
`png_set_read_user_transform_fn`, `png_set_user_transform_info`, the
user-transform branch of `png_read_transform_info`, and the final read row hook.
LP-S004BP completes the native registration behavior:

- typed `setReadUserTransform(callback)` and no-argument
  `setReadUserTransform()` both unconditionally enable the user-transform stage
- the no-argument form represents an explicitly registered null callback as
  identity execution rather than an absent transform
- `setUserTransformInfo` stores optional byte-sized output depth/channels;
  zero preserves callback-returned row information and nonzero values override
  it after callback execution
- initialization freezes all unrelated transform state but retains a live user
  registration, allowing callback enablement or replacement after initialization
- dynamic stage inspection appends ordinal `18` without renumbering prior stages
- `projectPngReadTransformInfo` projects configured nonzero depth/channels only
  while registration is enabled, including explicit no-callback registration
- combined execution places User Transform after Byte Swap, supplies immutable
  zero-based row/pass context, and gives the callback a copy-owned row
- callback output is copy-owned; configured shape overrides are applied before
  exact final row-byte validation and transformed-byte limiting
- replacement during one whole-image row is observed by the following row;
  replacing a callback with the no-argument form restores identity execution
- direct execution can supply an explicit context, while the current
  non-interlaced whole-image path uses pass `0`

The native setter row is translated. The C ABI callback trampoline and raw
`user_transform_ptr` are not present. Write callbacks, Adam7/progressive pass
execution, C ABI export, and release packaging remain separate work.

## Implemented Floating RGB To Gray Facade

LP-S004AO translates `png_set_rgb_to_gray` and its `png_fixed` dependency into
the existing read-transform state:

- `setRgbToGray` accepts `Float64` red/green weights and delegates converted
  signed fixed-point values to `setRgbToGrayFixed`
- `pngFixedFromFloat64` applies exact `floor(100000 * value + 0.5)` semantics
- non-finite values and converted values outside signed 32-bit range fail
  before transform state changes
- negative converted coefficients retain the historical defaults, while
  nonnegative pairs whose sum exceeds `100000` are ignored by the existing
  fixed setter
- valid floating calls preserve the fixed setter's IHDR lifecycle,
  Indexed-expand selection, policy, initialization snapshot, and row behavior

The direct C ABI floating setter wrapper, warning callback delivery,
gamma-aware RGB-to-gray branches, background/alpha mode, and release packaging
remain separate work.

## Implemented Gamma Threshold Fixed Substrate

LP-S004AP translates the first frozen gamma substrate:

- `pngMulDivFixed` mirrors the default floating-arithmetic `png_muldiv` branch
  for signed 32-bit inputs and output
- `pngGammaSignificant` preserves the strict
  `PNG_FP_1 +/- PNG_GAMMA_THRESHOLD_FIXED` boundary
- `pngGammaThreshold` multiplies screen/file gamma on the 100000 scale and
  forces correction when multiply/divide fails
- divide-by-zero, positive overflow, negative overflow, zero products,
  reciprocal products, and exact significance edges are covered directly

This packet does not add gamma setter state, file-gamma precedence, table
generation, gamma-aware RGB-to-gray, pixel-row correction, background/alpha
mode, or C ABI wrappers.

## Implemented File Gamma Resolution

LP-S004AQ translates the frozen fixed reciprocal and file-gamma precedence:

- `pngReciprocalFixed` calculates `100000 * 100000 / value` through the
  accepted multiply/divide substrate and returns zero on divide/overflow
  failure
- immutable `PngFileGammaSources` carries explicit file, chunk, default, and
  screen gamma values without exposing mutable read state
- `pngResolveFileGamma` returns the first nonzero explicit, chunk, or default
  value, then reciprocal screen gamma, then zero
- lower-priority values are not evaluated once a higher-priority source wins
- signed nonzero behavior, reciprocal rounding/failure, every precedence
  branch, zero state, and input immutability are covered directly

This packet does not add gamma setters, read-state mutation,
`png_init_gamma_values`, tables, pixel-row correction, background/alpha mode,
or C ABI wrappers.

## Implemented Gamma Value Initialization

LP-S004AR translates `png_init_gamma_values` without opening mutable read state:

- `pngInitGammaValues` resolves file gamma through the AQ precedence helper
- positive file and screen values evaluate the AP gamma threshold
- positive file with absent/nonpositive screen derives exact reciprocal screen
  gamma without enabling correction
- nonpositive resolved file resets file and screen gamma to `PNG_FP_1`
- immutable `PngGammaValues` exposes resolved file gamma, screen gamma, and the
  correction-required decision
- threshold overflow, reciprocal fallback/failure, signed nonpositive input,
  every branch, and source immutability are covered directly

This packet does not add gamma setters, read-state mutation, gamma tables,
pixel-row correction, background/alpha mode, or C ABI wrappers.

## Implemented Fixed Gamma Setter State

LP-S004AS translates `png_set_gamma_fixed` and its immediate validation helpers:

- sRGB `-1/-100000` and old-Mac `-2/-50000` aliases map to the frozen
  screen/file constants by role
- `pngGammaSupported` preserves the inclusive `1000..10000000` range
- `setGammaFixed` participates in the existing pre-row lifecycle without an
  IHDR requirement
- invalid nonpositive file/screen inputs retain separate application-error facts
- unsupported translated values retain a warning fact and reject the call
- only accepted calls replace file/screen gamma; failed calls preserve prior
  state

Floating conversion, callback delivery, gamma tables, row correction,
background/alpha mode, and C ABI wrappers remain separate. A later section
records the initialization snapshot integration.

## Implemented Floating Gamma Setter Facade

LP-S004AT translates `convert_gamma_value` and floating `png_set_gamma`:

- positive values below `128` are multiplied by `PNG_FP_1`
- other finite values remain already-fixed or negative flag-shaped inputs
- nearest rounding uses `floor(value + 0.5)` and preserves `-1/-2` exactly
- NaN, infinities, and signed-32-bit overflow fail before state mutation
- both arguments convert before delegation into `setGammaFixed`
- fixed lifecycle, flag/range validation, diagnostics, and failure isolation are
  reused unchanged

Gamma tables, row correction, callback delivery, background/alpha mode, and C
ABI wrappers remain separate. A later section records the initialization
snapshot integration.

## Implemented State-Driven Gamma Initialization Snapshot

LP-S004AU connects accepted gamma setter state and retained gAMA metadata to
the existing immutable initializer:

- explicit configured file and screen gamma are snapshotted before row
  initialization
- retained gAMA is converted from its validated UInt31 representation into the
  chunk-gamma source
- absent explicit/chunk/default values remain zero before one call to
  `pngInitGammaValues`
- explicit file gamma preserves frozen precedence over retained gAMA
- `PngReadTransformInitialization` exposes configuration/chunk facts, resolved
  file/screen values, correction status, and a copy of `PngGammaValues`
- rejected setter state does not become configured state, and post-initialized
  setter calls cannot change the snapshot
- existing row-stage ordinals remain unchanged and no executable Gamma stage
  is fabricated before table generation exists

Gamma tables, `png_do_gamma`, gamma-aware RGB-to-gray, background/alpha mode,
palette mutation, callback delivery, and C ABI wrappers remain separate.

## Implemented 8-Bit Gamma Correction And Table Substrate

LP-S004AV translates the frozen floating-arithmetic 8-bit correction path:

- `pngGamma8BitCorrect` preserves exact zero/255 endpoints
- interior samples use frozen `pow` scaling and `floor(... + 0.5)` rounding
- `PngGamma8BitTable` owns exactly 256 entries and returns cloned table arrays
- insignificant gamma uses direct identity filling
- significant gamma applies the scalar correction to every entry
- exhaustive identity and table/scalar equivalence tests cover all 256 values

LP-S004AV alone did not attach this substrate to read initialization. LP-S004AW
below adds the bounded 8-bit attachment; 16-bit tables, `png_do_gamma`,
gamma-aware RGB-to-gray row arithmetic, background/alpha mode, and C ABI
wrappers remain separate.

## Implemented Initialized 8-Bit Gamma Table Snapshot

LP-S004AW translates frozen `png_reciprocal2` and the 8-bit branch of
`png_build_gamma_table`:

- direct correction uses exact reciprocal2 nearest rounding
- zero input or signed-32-bit reciprocal2 overflow returns zero
- optional file-to-linear and linear-to-screen tables support later
  gamma-aware RGB-to-gray execution
- unknown screen gamma preserves the frozen identity direct correction and
  file-gamma linear-to-screen fallback
- read initialization retains copy-owned table snapshots only when correction
  or linear RGB-to-gray processing needs them
- existing row-stage ordinals remain unchanged

LP-S004AW itself retained tables without executable row gamma. LP-S004AX below
adds the bounded packed/8-bit row path; gamma-aware RGB-to-gray row arithmetic,
16-bit tables, background/alpha mode, and C ABI wrappers remain separate.

## Implemented Packed And 8-Bit Gamma Row Body

LP-S004AX translates the non-16-bit branches of frozen `png_do_gamma`:

- 8-bit Gray, GrayAlpha, RGB, and RGBA correct color samples only
- alpha bytes remain unchanged
- 2-bit and 4-bit grayscale preserve frozen sample replication, corrected
  high-bit masking, repacking, and final-byte padding behavior
- 1-bit grayscale remains a copy-owned no-op, matching the absent upstream
  branch
- palette and 16-bit rows remain bounded no-ops in this packet
- initialized Gamma dispatch is suppressed when palette initialization or
  RGB-to-gray owns gamma processing
- Gamma executes after Gray-to-RGB and before 16-to-8 reduction while retaining
  all previous stable stage identities

The 16-bit `png_do_gamma` branches, segmented tables, and gamma-aware
RGB-to-gray row arithmetic remain separate.

## Implemented 16-Bit Direct Gamma Table Substrate

LP-S004AY translates the frozen floating-arithmetic 16-bit correction and
`png_build_16bit_table` helpers from `png.c`:

- `pngGamma16BitCorrect` preserves exact zero/65535 endpoints and frozen
  nearest `pow` rounding for interior samples
- `PngGamma16BitTable` retains `1 << (8 - shift)` segments of 256 entries for
  every valid shift from `0` through `8`
- lookup selects a segment from the retained low input bits and an entry from
  the high byte, matching the frozen table topology
- significant gamma uses direct full-range scaling; insignificant gamma uses
  exact identity scaling over the compressed input domain
- segment and complete-table access are deep-copy owned
- exhaustive shift-zero scalar equivalence, shift-four segment equivalence,
  identity scaling, monotonicity, ownership, and invalid-shift behavior are
  covered directly

These helpers are outside the 45-function `pngrtran.c` inventory. The
16-to-8 specialization, gamma-shift selection, initialized 16-bit table
snapshot, 16-bit `png_do_gamma`, and gamma-aware RGB-to-gray remain separate.

## Implemented Initialized 16-Bit Gamma Table Snapshot

LP-S004AZ translates the remaining 16-bit branch of frozen
`png_build_gamma_table` before row execution:

- `pngBuildGamma16To8Table` preserves the 255 corrected boundary calculations,
  compressed-domain rescaling, lower-output filling, and final 65535 fill
- `pngResolveGamma16BitShift` selects maximum RGB or grayscale sBIT precision,
  applies the frozen 11-bit input floor for Scale16/Strip16, and clamps to 8
- direct correction uses the direct segmented builder unless later reduction
  selects the reciprocal-correction 16-to-8 specialization
- optional RGB-to-gray support retains direct, file-to-linear, and
  linear-to-screen segmented tables with one shared shift
- `PngReadTransformInitialization` owns and exposes the complete table group;
  post-return access remains deep-copy isolated
- 16-bit snapshots do not yet add a Gamma stage, so the existing row pipeline
  cannot claim correction before the row body is translated
- exhaustive compressed-domain 16-to-8 proof, shift boundaries, direct versus
  reduction selection, initialized ownership, linear tables, and consumer use
  are covered directly

The ledger remains `30 translated / 9 partial / 6 pending` at this snapshot
checkpoint. The next section records 16-bit row execution.

## Implemented 16-Bit Gamma Row Body

LP-S004BA completes the frozen 16-bit branches of `png_do_gamma`:

- Gray, GrayAlpha, RGB, and RGBA read each color component in PNG network order
- segmented direct or reduction-specialized tables correct only color samples
- corrected UInt16 values are written back high byte first
- GrayAlpha and RGBA alpha pairs remain byte-for-byte unchanged
- initialized Gamma executes after Gray-to-RGB and before Scale16/Strip16
- reduction-specialized outputs are expanded 8-bit levels, so the following
  Scale16 step recovers the selected byte exactly
- malformed rows fail before lookup; transformed and disabled rows remain
  copy-owned
- direct, reduction, alpha, order, whole-image, and consumer behavior are
  covered directly

The `png_do_gamma` ledger row is now translated and the ledger advances to
`31 translated / 8 partial / 6 pending`. Gamma-aware RGB-to-gray remains open.

## Implemented Gamma-Aware RGB-To-Gray Row Arithmetic

LP-S004BB completes the frozen gamma-table branches of
`pngrtran.c::png_do_rgb_to_gray`:

- initialized 8/16-bit RGB and RGBA rows use retained file-to-linear and
  linear-to-screen tables
- nongray detection compares original RGB values before table lookup
- unequal samples use the frozen fixed coefficients with `+16384` rounding in
  linear space, then map through the from-linear table
- equal samples use the direct file-to-screen table when the gamma-aware branch
  is active
- alpha bytes and PNG network-order UInt16 encoding remain unchanged
- direct initialized rows, strict-policy mismatch, copy ownership, whole-image
  execution, malformed rows, and standalone consumer use are covered

The `png_do_rgb_to_gray` row remains translated and the ledger remains
`31 translated / 8 partial / 6 pending`.

## Implemented Background Setter State

LP-S004BC translates frozen `png_set_background_fixed` and
`png_set_background` before background initialization or row composition:

- `PngBackground` is a public immutable `png_color_16`-shaped value with
  copy construction
- `PngBackgroundGammaCode` preserves Unknown/Screen/File/Unique identities
- accepted fixed calls select Compose and Strip Alpha, clear Encode Alpha and
  Optimize Alpha, retain background gamma and expansion state, and replace the
  previous accepted background atomically
- Unknown gamma records a nonfatal diagnostic without replacing prior state
- floating gamma uses the frozen `floor(100000 * value + 0.5)` conversion and
  rejects nonfinite or signed-32-bit overflow before mutation
- lifecycle rejection, repeated calls, getters, consumer use, and state
  stability are covered directly

The two setter rows advance to translated and the ledger becomes
`33 translated / 8 partial / 4 pending`. `png_do_compose` and alpha-mode
setters remain separate.

## Implemented Background Initialization Snapshot

LP-S004BD extends the still-partial palette, RGB, and read initializer rows:

- immutable initialization retains the configured background color, gamma code,
  gamma value, and effective Compose/background-expand decisions
- palette and non-palette inputs without effective alpha/transparency cancel
  Compose plus background expansion like the frozen initializer
- binary/partial palette transparency, color-key tRNS, and inherent alpha keep
  Compose selected
- palette background indexes resolve through retained PLTE when normal Expand
  and Background Expand are both selected
- 1/2/4-bit grayscale background samples scale by `0xff`, `0x55`, or `0x11`
  and populate gray/R/G/B snapshot values
- Strip Alpha is withheld from the early stage sequence while effective Compose
  remains selected, preserving the frozen post-compose order
- invalid palette indexes fail before row initialization and permit a corrected
  retry; snapshots remain independent of retained metadata getter copies

The three initializer rows remain partial and the ledger stays
`33 translated / 8 partial / 4 pending`. Row composition, alpha-mode state,
and remaining initializer branches are separate.

## Implemented Background Depth And Gamma Initialization

LP-S004BE extends the same still-partial initializer rows through the complete
non-palette Compose preparation immediately preceding `png_do_compose`:

- Expand16 with a non-expanded background and non-16-bit input applies the
  exact rounded `PNG_DIV257` reduction before composition
- Scale/Strip 16-to-8 with a non-expanded background and 16-bit input applies
  the frozen UInt16 `value * 257` normalization
- Background Expand bypasses both depth-normalization branches
- immutable original, linear, and screen background snapshots retain index and
  gray/R/G/B values independently
- Screen/File/Unique modes derive the frozen correction-to-linear `g` and
  correction-to-screen `gs` values through reciprocal/reciprocal2 helpers
- 8-bit and 16-bit gray/color backgrounds use the translated scalar correction
  bodies, with gray backgrounds synchronizing all color channels
- effective gamma code becomes Screen after non-palette correction while the
  configured code/value remain available
- Compose independently requests linear gamma tables, including the Unique
  background-gamma case; palette inputs prepare tables without mutating PLTE
- identity gamma, canceled Compose, ownership, lifecycle, and consumer behavior
  remain bounded and explicit

The ledger remains `33 translated / 8 partial / 4 pending`. Actual row/palette
composition, alpha-mode state, and the remaining initializer branches stay open.

## Implemented Non-Palette Background Composition

LP-S004BF translates the complete row-local `png_do_compose` switch:

- packed 1/2/4-bit grayscale replaces exact tRNS keys without touching final
  padding bits; 2/4-bit surviving samples use the direct Gamma table
- 8/16-bit Gray and RGB replace exact color keys with screen-background values
  and directly Gamma-correct every surviving color sample when tables exist
- 8/16-bit GrayAlpha and RGBA preserve alpha bytes, select transparent,
  partial, and opaque branches, and use exact libpng no-division composition
- Gamma-aware partial alpha converts file samples to linear, composes against
  the linear background, and converts back to screen Gamma
- UInt16 input and output remain in PNG network byte order
- initialized execution places Compose before standalone Gamma and adds an
  explicit post-Compose Strip Alpha stage without changing older ordinals

`png_do_compose` is translated and the ledger advances to
`34 translated / 8 partial / 3 pending`. Palette composition/mutation,
alpha-mode encoding/optimization, and remaining initializer/dispatcher work
stay separate.

## Implemented Palette Background Composition Initialization

LP-S004BG translates the Indexed initialization-time PLTE/tRNS branches that
precede row execution:

- initialization owns an effective palette and retained alpha-prefix snapshot
  independently from source metadata and accessor copies
- transparent entries become the effective screen background; partial-alpha
  entries use exact byte composition; opaque and implicit-tail entries survive
  unchanged when no Gamma correction is required
- Gamma-aware composition resolves direct, to-linear, and from-linear tables
  once, composes partial entries against the linear background, and directly
  corrects opaque entries
- Background Screen, File, and Unique modes derive 8-bit screen/linear colors
  even when the source Indexed bit depth is 1/2/4
- Gamma-only Indexed input directly corrects PLTE without adding a row Gamma
  stage
- Expanded Indexed RGB-to-gray keeps PLTE uncorrected so the gamma-aware
  RGB-to-gray stage owns the single linearization path
- completed palette composition cancels row Compose; Expand consumes the
  effective PLTE and original tRNS prefix before Strip Alpha, while non-Expand
  projection exposes the same effective palette and clears transparency
- malformed palette and alpha-prefix snapshots fail before mutation

The three initializer/info/dispatcher ledger rows remain partial because
alpha-mode Encode/Optimize behavior, full metadata projection, and remaining
dispatch branches are still open. The total remains
`34 translated / 8 partial / 3 pending`.

## Implemented Alpha-Mode Setter State

LP-S004BH translates `png_set_alpha_mode_fixed` and its floating facade:

- `PngAlphaMode` preserves PNG, Associated, Optimized, and Broken identities
- fixed output Gamma translates screen-role sentinels and rejects unsupported
  values before state mutation
- the first successful call stores reciprocal default file Gamma; later calls
  update screen Gamma without replacing that default
- Associated forces linear output; Optimized selects non-opaque linear
  treatment; Broken selects alpha encoding
- premultiplying modes configure a zero-valued File-Gamma background and
  Compose without enabling Background Expand
- PNG mode clears Encode/Optimize while retaining an existing background
- premultiply-after-background conflict, floating conversion failures, and late
  lifecycle calls preserve prior state
- immutable read initialization consumes default/screen Gamma and snapshots
  alpha-mode, Encode, Optimize, Compose, and background facts

The pending `png_do_encode_alpha` body and optimized palette arithmetic remain
separate packets. The ledger advances to
`36 translated / 8 partial / 1 pending`.

## Implemented Encode-Alpha Row Body

LP-S004BI translates `png_do_encode_alpha` and its initialized dispatch:

- 8-bit GA/RGBA rows encode only the final alpha byte through the from-linear
  table
- 16-bit GA/RGBA rows preserve big-endian component storage while replacing
  only the final alpha sample
- grayscale/color bytes, row topology, and row size remain unchanged
- malformed rows fail before stage selection and unsupported rows return owned
  copies
- initialization cancels ineffective Encode/Optimize state for near-linear
  screen Gamma or alpha that does not survive
- effective Encode Alpha executes after Compose/Gamma/post-Compose Strip Alpha
  and before Scale/Strip 16-to-8
- whole-image execution retains the existing transformed-byte limit

This moves the last pending `pngrtran.c` function to translated. The ledger is
now `37 translated / 8 partial / 0 pending`; partial rows still track remaining
initializer, info-projection, callback/C ABI, and dispatcher fidelity.

## Implemented Alpha Initializer Optimization Parity

LP-S004BJ closes the remaining Alpha Optimize/Encode initialization branches:

- Indexed tRNS is classified as opaque, binary-only transparency, or partial
  alpha before effective alpha-mode decisions are frozen
- opaque and binary-only inputs cancel effective Encode/Optimize while
  retaining the caller's setter intent independently
- insignificant screen Gamma cancels both effective flags for palette and
  inherent-alpha inputs
- partial palette alpha keeps effective Optimize and uses the frozen
  `round(component * alpha / 255)` arithmetic in linear space
- transparent palette entries become black, opaque entries receive direct
  Gamma correction, and source PLTE/tRNS remains copy-owned and unchanged
- Expanded Indexed rows retain associated alpha beside the premultiplied RGB;
  non-Expand consumers share the same effective palette snapshot
- whole-image and standalone consumer paths exercise the same initialized
  result

`png_init_rgb_transformations` now has all frozen cancellation and sub-byte
background-expansion branches under tests and advances to translated. Palette
and complete read initialization remain partial for their other deferred
branches, so the ledger becomes `38 translated / 7 partial / 0 pending`.

## Implemented Palette tRNS Invert Initialization

LP-S004BK closes the final frozen branch in
`png_init_palette_transformations`:

- Background Expand plus Expand without Expand-tRNS inverts each retained tRNS
  byte before palette composition
- inversion applies only to the copy-owned effective alpha-prefix snapshot;
  source metadata and implicit opaque tail entries remain unchanged
- transparent, partial, and opaque values use exact `255 - alpha` behavior
- the inverted prefix feeds the already-translated encoded/linear palette
  composition paths and whole-image output
- ordinary Expand-tRNS retains the original prefix for row-stage alpha handling
- Expand/non-Expand snapshots, malformed-prefix validation, ownership, and
  standalone consumer use remain covered

All frozen branches of `png_init_palette_transformations` are now traceable, so
the row advances to translated. The ledger becomes
`39 translated / 6 partial / 0 pending`.

## Implemented cHRM RGB-to-Gray Coefficient Initialization

LP-S004BL translates `png.c::png_set_rgb_coefficients` as consumed by
`pngrtran.c::png_init_read_transformations`:

- accepted explicit fixed/floating setter coefficients remain authoritative
- valid retained cHRM reference-white and primary chromaticities are solved into
  normalized red, green, and blue Y contributions on the `32768` scale
- nearest rounding preserves the frozen largest-component correction when the
  three independently rounded coefficients sum to `32767` or `32769`
- sRGB metadata intentionally keeps the historical REC 709 defaults, matching
  upstream colorspace precedence
- absent, out-of-range, singular, negative-scale, and otherwise unusable cHRM
  values fall back to `6968/23434/2366`
- immutable initialization, 8-bit row execution, whole-image execution,
  explicit setter precedence, and standalone consumer use are covered

The complete read dispatcher remains open, so `png_init_read_transformations`
stays partial and the ledger remains `39 translated / 6 partial / 0 pending`.

## Implemented Background-Aware Gray-to-RGB Dispatch

LP-S004BM closes the remaining default-config topology shared by
`png_init_read_transformations` and `png_do_read_transformations`:

- Background Expand on Grayscale/Grayscale Alpha marks the effective
  background gray
- Compose with Gray-to-RGB and equal red/green/blue background values also
  marks it gray and synchronizes the gray component from red
- non-gray backgrounds run Gray-to-RGB before Compose so composition can use
  distinct RGB background components
- gray backgrounds retain grayscale through Compose and optional Expand16,
  then run Gray-to-RGB afterward
- the two positions are mutually exclusive in the immutable stage list and
  the row/whole-image dispatcher
- direct 8/16-bit output topology, stage order, lifecycle, ownership, and
  standalone consumer use are covered

The native initializer and all 23 frozen read-stage positions are now
traceable. Both inventoried rows advance to translated, so the ledger becomes
`41 translated / 4 partial / 0 pending`; C ABI trampolines remain a separate
program boundary.

## Implemented Direct Invert-Monochrome Row Body

LP-S004AI adds `png_invert_mono_transform.cj` as the direct translation of
`pngtrans.c::png_do_invert` and connects it before Invert Alpha:

- Grayscale rows at 1/2/4/8/16-bit invert every stored byte exactly, including
  packed-row padding bits in the final byte
- Grayscale Alpha 8-bit rows invert only the gray byte in each pair
- Grayscale Alpha 16-bit rows invert both network-order gray bytes while
  retaining both alpha bytes
- row information is unchanged, transformed/disabled/unsupported rows are
  copy-owned, and malformed rows fail before support checks
- `setInvertMono()` follows the translated lifecycle and immutable snapshot
  pattern
- initialized row and whole-image execution place Invert Mono after Expand16
  and before Invert Alpha and Unshift

The LP-S004AI packet did not add pack/packswap, byte swap, user callbacks,
gamma/background, Adam7, progressive IO, write behavior, or C ABI surfaces;
later sections record the current PackSwap status.

## Implemented Direct BGR Row Body

LP-S004AH adds `png_bgr_transform.cj` as the direct translation of
`pngtrans.c::png_do_bgr` and connects it to the initialized read path:

- natural Truecolor and Truecolor Alpha rows exchange red and blue while alpha
  stays in place
- 8-bit rows exchange one byte per component; 16-bit rows exchange complete
  high/low byte pairs without converting PNG network order
- width, bit depth, color type, channels, pixel depth, and row bytes remain
  unchanged
- transformed, disabled, and unsupported rows are copy-owned; malformed row
  lengths fail before support checks
- `setBgr()` follows the translated `png_rtran_ok` lifecycle and initialization
  snapshots the enabled bit before placing BGR after Unshift and before Filler
- whole-image initialized transformation uses the same stage and retains the
  existing transformed-byte limit

The LP-S004AH packet did not add invert-mono, pack/packswap, byte swap, user
callbacks, gamma/background, Adam7, progressive IO, write behavior, or C ABI
surfaces; later sections record the current PackSwap status.

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

## Implemented Complete Read Transform Info Projection

LP-S004M established `png_read_transform_info.cj`; LP-S004BN completes the
frozen default-config translation of `png_read_transform_info`:

- `PngReadTransformInfo` exposes projected width, height, bit depth, color
  type, channels, pixel depth, row bytes, remaining tRNS count, synchronized
  palette, effective background, and initialized file Gamma
- indexed Expand projects to RGB or RGBA at 8-bit depth based on retained
  post-initialization tRNS count, including all-opaque palette tRNS
- non-palette Expand raises sub-byte gray to 8 bits and adds alpha only when
  effective tRNS expansion remains enabled
- Expand and either early or post-Compose Strip Alpha clear projected tRNS
  state
- Scale16 or Strip16 project 16-bit input to 8 bits; Expand16 can subsequently
  project non-palette 8-bit output back to 16 bits
- Gray-to-RGB projection precedes RGB-to-gray exactly as in the frozen info
  function, even though the runtime row dispatcher orders those stages
  differently
- plain filler after Strip Alpha increments channels without changing color
  type; Add Alpha increments channels and changes Gray/RGB to GA/RGBA
- quantize, packing, and configured user-transform overrides retain frozen
  ordering, with user depth/channels applied last
- final channels and bit depth determine pixel depth and PNG row bytes

The default-config ledger entry is translated. Native `png_info` mutation, C
ABI structure compatibility, and callback trampolines remain separate work.

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

## Implemented Direct Alpha Invert And Swap Row Bodies

LP-S004O adds `png_alpha_transform.cj` as the direct translation of
`png_do_read_invert_alpha` and `png_do_read_swap_alpha`:

- `pngDoReadInvertAlpha` preserves G/RGB bytes and complements only the alpha
  byte or the two network-order alpha bytes in GA/RGBA rows
- `pngDoReadSwapAlpha` converts `GA -> AG`, `RGBA -> ARGB`,
  `GGAA -> AAGG`, and `RRGGBBAA -> AARRGGBB`
- 16-bit components remain byte pairs in PNG network order; the direct path
  does not convert them into host-numeric UInt16 values
- both bodies return copy-owned rows with unchanged row info and safely no-op
  for non-alpha color types or bit depths outside 8/16
- malformed row lengths fail before byte access
- `applySelectedPngAlphaTransforms` consumes only the existing `InvertAlpha`
  and `SwapAlpha` selections and fixes their relative execution order as
  Invert Alpha before Swap Alpha regardless of caller array order or duplicates

The narrow adapter deliberately skips the intervening unshift, BGR, and filler
stages. It does not translate the corresponding remaining setter state or
claim the complete `png_do_read_transformations` dispatcher.

## Implemented Direct Strip Channel Row Body

LP-S004AE adds `png_strip_channel_transform.cj` as the direct translation of
`pngtrans.c::png_do_strip_channel` and connects its read-side use:

- 8-bit and network-order 16-bit rows can remove the first or last component
  from runtime channel counts two and four
- two-channel rows shrink to one channel and four-channel rows shrink to three
- alpha-bearing Gray/RGB color types lose their alpha bit; filler-shaped Gray
  or RGB color types remain unchanged
- width and bit depth remain stable while channels, pixel depth, and row bytes
  shrink exactly
- output and no-op rows are copy-owned, and malformed rows fail before
  supported/unsupported branching
- `applyInitializedPngStripAlphaStage` always removes the final channel,
  matching read-transform order before later Swap Alpha
- one-shot initialization suppresses effective tRNS expansion under Strip
  Alpha, while inherent GA/RGBA alpha is removed by the direct body

The adapter does not execute Expand automatically, compose filler or Swap
Alpha, or claim the complete stateful row dispatcher.

## Implemented Direct Read Filler Row Body

LP-S004P adds `png_filler_transform.cj` as the direct translation of
`png_do_read_filler` and extends `PngReadRowInfo` with an explicit transformed
channel-count constructor:

- source Gray/RGB color type remains unchanged while runtime channels expand
  from 1 to 2 or 3 to 4
- 8-bit rows become `G -> GX/XG` and `RGB -> RGBX/XRGB`
- 16-bit network-byte rows become `GG -> GGXX/XXGG` and
  `RRGGBB -> RRGGBBXX/XXRRGGBB`
- 8-bit filler uses only the low UInt32 byte; 16-bit filler uses the low
  16 bits in high-byte/low-byte network order
- output width and bit depth remain unchanged while channels, pixel depth, and
  row bytes increase exactly
- output is copy-owned because Cangjie arrays cannot grow in place
- alpha-bearing, indexed, packed-depth, and already-expanded rows safely no-op
- malformed row lengths fail before source bytes are read
- `applyPngReadFillerTransform` maps `FillerBefore`, `FillerAfter`,
  `AlphaBefore`, and `AlphaAfter` to the direct row body

The narrow adapter does not execute an earlier Strip Alpha stage. Add-alpha
color-type projection remains a separate `png_read_transform_info` concern;
setter state, BGR/swap-alpha composition, and complete dispatch are deferred.

## Implemented Direct Packed-Row Unpack

LP-S004R adds `png_unpack_transform.cj` as the direct translation of
`png_do_unpack`:

- legal 1/2/4-bit grayscale and palette rows expand to one byte per stored
  sample without scaling the sample value
- each branch computes the same final source byte and initial bit shift as the
  frozen C body, then reads and writes from the row end toward the start
- partial final packed bytes therefore preserve the exact upstream alignment
- width and color type remain unchanged, channels remain one, bit depth becomes
  8, pixel depth becomes 8, and row bytes become width
- output is copy-owned because Cangjie arrays cannot grow in place
- bit depth at least 8, unsupported packed color/depth shapes, source-channel
  mismatch, and zero-width rows safely no-op after row-length validation
- malformed packed row lengths fail before source bytes are read

The direct body does not scale grayscale values or expand palette entries to
RGB. LP-S004AJ provides read-side `png_set_packing` state and bounded
initialized dispatch. LP-S004AK now provides PackSwap; write packing and the
complete dispatcher remain separate work.

## Implemented Direct Palette Expansion

LP-S004S adds `png_palette_expand_transform.cj` as the direct translation of
`png_do_expand_palette`:

- legal 1/2/4/8-bit Indexed rows expand through retained PLTE entries
- packed indexes use the already direct reverse unpack formulas before palette
  growth
- output growth walks source indexes and destination bytes from the row end
- no retained palette alpha produces 8-bit RGB output
- one or more retained tRNS alpha entries produce RGBA, with `0xff` used for
  palette indexes beyond the retained alpha count
- width remains unchanged while bit depth, color type, channels, pixel depth,
  and row bytes update exactly
- output is copy-owned and malformed rows, invalid palettes/transparency, and
  out-of-range indexes fail explicitly
- unsupported color/depth/channel shapes and zero width safely no-op after
  row-length validation

The direct body does not translate non-palette `png_do_expand`, mutate the
retained palette, use the upstream NEON riffled-palette path, execute Expand16,
or claim the complete row dispatcher.

## Implemented Direct Non-Palette Expansion

LP-S004T adds `png_nonpalette_expand_transform.cj` as the direct translation of
non-palette `png_do_expand`:

- legal packed 1/2/4-bit Gray values replicate to exact 8-bit bit patterns
- packed Gray transparency keys use the same source mask and replication factor
- absent transparency is represented independently from a zero-valued key
- Gray 8/16 rows grow to GA and RGB 8/16 rows grow to RGBA when a key exists
- every growing branch walks source and destination from the row end
- 16-bit comparisons and output remain in PNG network-byte order
- transparent alpha is zero and opaque alpha is all-ones at the active depth
- width remains unchanged while color type, channels, pixel depth, and row bytes
  update exactly
- transformed and no-op rows are copy-owned, and malformed row lengths fail
  before component reads

LP-S004AD connects both direct expansion bodies to one bounded initialized
Expand stage:

- one-shot initialization snapshots a copy-owned PLTE and only the effective
  palette-alpha prefix that survives Strip Alpha
- non-palette initialization snapshots immutable Gray or RGB color-key state
- Indexed rows dispatch to `pngDoExpandPalette`; all other rows dispatch to
  `pngDoExpand`
- `png_set_palette_to_rgb` retains the frozen shared tRNS expansion bits, so
  palette alpha is suppressed only when effective transparency is stripped
- disabled and unsupported rows remain validated copy-owned no-ops
- source metadata and post-initialization setter isolation remain unchanged

The adapter does not mutate palette state, execute preceding or following
stages automatically, or claim the complete row dispatcher.

## Implemented Direct Expand16

LP-S004U adds `png_expand16_transform.cj` as the direct translation of
`png_do_expand_16`:

- every byte in an 8-bit non-palette runtime row is copied backward into an
  equal high/low byte pair
- width, color type, and current runtime channels remain unchanged
- bit depth becomes 16, pixel depth becomes `channels * 16`, and row bytes
  double exactly
- current runtime channels are retained even when they differ from the source
  color-type default after an earlier shape-changing transform
- transformed and no-op rows are copy-owned
- Indexed, non-8-bit, zero-channel, and zero-width rows safely no-op after
  row-length validation

LP-S004AC connects the direct body to the bounded initialized Expand16 stage:

- disabled initialization returns a validated copy-owned no-op row
- enabled initialization delegates to `pngDoExpand16`
- Scale16 and Strip16 can reduce a 16-bit row before Expand16 replicates the
  resulting 8-bit bytes back into network-order 16-bit pairs
- full-color Quantize changes RGB/RGBA to Indexed before Expand16, so the direct
  body's Indexed no-op gate preserves the quantized bytes and row info
- malformed rows fail before disabled, transformed, or Indexed no-op behavior

The adapter does not execute preceding stages automatically or claim the
complete row dispatcher.

## Implemented Direct Quantize

LP-S004V adds `png_quantize_transform.cj` as the direct translation of
`png_do_quantize`:

- 8-bit RGB and RGBA rows use the frozen 5/5/5 cell formula and an exact
  32768-entry palette lookup
- RGBA alpha is skipped during lookup exactly like upstream
- RGB/RGBA rows shrink forward to one Indexed byte per pixel
- output width and bit depth remain unchanged while color type becomes Indexed,
  channels become one, pixel depth becomes eight, and row bytes become width
- 8-bit Indexed rows remap every stored index through a complete 256-entry table
- Indexed remapping preserves all row-info fields
- empty lookups represent absent pointers; nonempty malformed lengths fail
  before lookup
- transformed and no-op rows are copy-owned, and malformed row lengths fail
  before lookup validation

LP-S004AA connects the direct body to one bounded initialized stage:

- `PngReadTransformInitialization` owns frozen copies of the generated
  32768-entry palette lookup and 256-entry index remap
- `ReadStageQuantize` is ordered after Strip16 and before Expand16 exactly like
  frozen `png_do_read_transformations`
- `applyInitializedPngQuantizeStage` chooses the already-generated tables from
  the initialization snapshot and delegates row behavior to `pngDoQuantize`
- disabled stages, unsupported row topology, and accessor readback remain
  copy-owned; malformed rows still fail before lookup validation
- post-initialization setter rejection cannot mutate the frozen mode or tables

The bounded adapter does not build or reduce palettes, mutate retained PLTE,
project transformed info, or claim the complete row dispatcher.

LP-S004AB connects the initialized quantize payload to the bounded transformed
info projection:

- initialization snapshots the reduced or selected palette and its active count
  alongside the already-frozen lookup/remap tables
- disabled quantize preserves the source PLTE, while enabled quantize replaces
  the projected PLTE with a copy-owned palette from the initialization snapshot
- `PngReadTransformInfo` exposes palette presence, count, copy-owned bytes, and
  range-checked RGB entry access without mutating `PngReadMetadata`
- after Gray-to-RGB and RGB-to-gray projection, only 8-bit RGB/RGBA with a
  materialized full-color lookup becomes Indexed
- a resulting Indexed topology blocks the following Expand16 projection exactly
  like the frozen upstream info function
- non-full RGB topology and gray topology remain unchanged, while non-full
  Indexed rows retain Indexed topology with the synchronized reduced palette

At that historical checkpoint the ledger remained partial. LP-S004BN later
completed Gamma/background, filler/add-alpha, pack, active user-transform, and
metadata synchronization; native allocation-warning fallback and C ABI remain
separate work.

## Implemented Quantize Setter State Floor

LP-S004W extends `PngReadTransformState` with the bounded state topology of
`png_set_quantize`:

- `setQuantize` preserves the existing `png_rtran_ok(..., 0)` lifecycle gate
- `PngQuantizeMode` distinguishes palette remapping from full-color lookup
- accepted calls retain a copy-owned RGB byte palette, declared count, and
  maximum-color limit
- every non-full call constructs all 256 identity remap entries, including
  index `255`, and replaces the prior managed remap state
- full-color mode remains explicit while exposing no fabricated index remap
- malformed palettes and requests that require palette reduction fail before
  quantize state mutation

This state floor does not translate histogram sorting, palette reduction or
mutation, median-cut/closest-color selection, initialized row dispatch, or
transformed-info projection.

## Implemented Full Quantize Palette Lookup

LP-S004X adds `png_quantize_lookup.cj` for the no-reduction full-color branch of
`png_set_quantize`:

- accepted full calls generate exactly 32768 5/5/5 RGB cells
- palette components are reduced to their high five bits before distance work
- each cell uses the frozen `dmax + dr + dg + db` distance formula
- lookup entries change only for a strictly smaller distance, preserving the
  first palette entry on equal-distance ties
- generated lookup results are copy-owned and replaced by later full calls
- switching to non-full mode clears the full lookup and installs the complete
  256-entry identity remap instead
- failed lifecycle and reduction calls preserve the prior generated lookup

The lookup is available as explicit state but is not yet connected to the
initialized row dispatcher or transformed-info projection. Palette reduction
is described by the next bounded branch.

## Implemented Histogram Quantize Reduction

LP-S004Y adds `png_quantize_reduction.cj` and a histogram-bearing `setQuantize`
overload for the `num_palette > maximum_colors` branch:

- palette indexes are bubble-sorted by descending UInt16 histogram count using
  the frozen strict comparison and early-stop rule
- equal-frequency entries retain their original order
- full mode preserves the upstream palette relocation topology before building
  the reduced 32768-entry lookup
- non-full mode starts with all 256 identity entries, mirrors palette swaps in
  the original-index remap, and then resolves every discarded entry
- discarded colors use the frozen Manhattan RGB distance against retained
  colors and keep retained index zero on equal-distance ties
- the managed implementation mutates an owned palette clone, leaving caller
  palette and histogram arrays unchanged
- malformed or absent reduction histograms fail before quantize state mutation

The separate no-histogram closest-pair branch is described by the next bounded
packet. Allocation-warning fallback, initialized dispatcher, and
transformed-info projection remain open.

## Implemented Closest-Pair Quantize Reduction

LP-S004Z adds `png_quantize_closest_reduction.cj` for reduction without a
histogram:

- identity `index_to_palette` and `palette_to_index` maps track original
  identities separately from current palette positions
- active color pairs are bucketed by Manhattan RGB distance
- each round starts with distance window 96 and widens it by 96 until useful
  pairs are available
- bucket lists are processed in reverse pair-enumeration order to preserve the
  upstream linked-list head-insertion topology
- pairs whose identities were eliminated earlier in the same pass are skipped
- even active counts eliminate the right identity; odd counts eliminate the
  left identity
- the last active palette slot is copied into the eliminated position and both
  direction maps are updated exactly
- non-full mode rewrites every affected original-index remap before map updates;
  full mode builds its lookup from the final reduced palette
- caller palette ownership and failed setter lifecycle state remain unchanged

LP-S004BQ closes the native allocation-warning retry boundary with a bounded,
quantize-specific managed diagnostic:

- `PngQuantizeAllocationFaultPlan` deterministically fails pair-node admission
  after a configured number of successful admissions
- an interrupted bucket-build attempt is discarded before any palette,
  identity-map, remap, or lookup mutation
- recovery increases the frozen distance window by `96` and retries from the
  unchanged working snapshot
- recovered non-full remap and full lookup results retain the existing exact
  odd/even elimination and reverse-bucket ordering
- successful setters expose allocation warning/retry counts; a later ordinary
  setter replacement resets both facts
- exhausted bounded retries raise `ALLOCATION_FAILURE` before prepared state
  publication, preserving the last accepted quantize snapshot
- initialized row dispatch, transformed-info projection, whole-image use, and
  standalone consumer use consume the recovered state unchanged

This diagnostic does not claim recovery from actual managed-runtime OOM.
Generic allocators, user allocation callbacks, and the C ABI remain separate.
With this branch the generated `pngrtran.c` inventory reaches
`45 translated / 0 partial / 0 pending`.

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

LP-S004Q adds `png_unshift_transform.cj` as the direct source-row translation of
`png_do_unshift`:

- `PngSignificantBits` is converted into source-shaped G, GA, RGB, or RGBA
  shift arrays from the current row color type
- non-positive and at-least-bit-depth shifts normalize to zero exactly at the
  row body boundary
- packed 2-bit grayscale applies the upstream `>> 1` plus `0x55` byte mask
- packed 4-bit grayscale applies the upstream shift-dependent repeated-nibble
  mask across every row byte, including final padding bits
- 8-bit components shift byte-by-byte with exact channel cycling
- 16-bit components are reconstructed and written back in PNG network order
- row information is unchanged, and transformed or no-op rows are copy-owned
- palette, 1-bit, unsupported-depth, source-channel mismatch, and all-zero
  shift plans safely no-op after row-length validation
- `applySelectedPngUnshiftTransform` is a narrow adapter over the existing
  `UnshiftSignificantBits` selection

The direct adapter does not perform palette initialization mutation or compose
byte swap, filler, and the complete `png_do_read_transformations` path.

RGB-to-gray, gamma/background/alpha-mode, quantization, packing/packswap, byte
swap, and user callbacks were outside that direct adapter packet; later
sections record their current status.

## Implemented Read CRC Action Policy

LP-S004BO translates `pngrtran.c::png_set_crc_action` into
`PngCrcAction` and `PngReadSession.setCrcAction`:

- `DEFAULT`, `ERROR_QUIT`, `WARN_DISCARD`, `WARN_USE`, `QUIET_USE`, and
  `NO_CHANGE` retain the frozen numeric identities `0..5`
- critical and ancillary actions are replaced independently
- the defaults remain critical error/quit and ancillary warn/discard
- critical `WARN_DISCARD` records a warning fact and falls back to error/quit
- accepted corrupt chunks expose `PngChunk.crcValid = false`
- session counters expose warning, quiet-use, and discarded-chunk facts
- discarded ancillary chunks are consumed without becoming decoder input
- chunk framing, size, type, and IHDR-order validation still fail before CRC
  policy can accept or discard data

`decodePngNonInterlaced` also accepts explicit critical and ancillary actions
for the native high-level read path. Native warning/error callbacks, write-side
CRC policy, and the C ABI remain separate work.
