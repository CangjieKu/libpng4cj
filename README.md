# libpng4cj

libpng4cj is a full-port program for libpng `1.6.58`, implemented primarily in
Cangjie. It targets two eventual surfaces:

- a native Cangjie package named `libpng4cj`
- a compatible `libpng16` artifact for existing C and C++ consumers

The current `0.1.0` development line contains PNG signature/endian/CRC32
primitives, a bounded in-memory chunk reader, strictly validated IHDR/PLTE/tRNS
handling, a non-interlaced raw-row decoder, RGBA8/RGBA16 transformed surfaces,
and the first fixed and compressed metadata layers. It is not yet a complete
PNG decoder or a replacement for libpng.

## Build

```sh
cjpm build
cjpm test
sh ./tools/update-upstream-baseline.sh
cd test/consumer && cjpm run
```

## Use

```toml
[package]
link-option = "-lz"

[dependencies]
libpng4cj = { git = "https://gitcode.com/cinyu/libpng4cj.git" }
```

```cangjie
import libpng4cj.*

let valid = isPngSignature(PNG_SIGNATURE)
```

The public package root is `libpng4cj`; consumers do not need a repeated
module/package prefix. libpng4cj is currently a static library backed by the
system zlib, so the final executable declares `-lz` at its link step.

## Current Baseline

- upstream version: `1.6.58`
- upstream tag: `v1.6.58`
- upstream commit: `3061454d980de7d53608f594194cfac722721d2a`
- vendored reference: `vendor/libpng-1.6.58/`

The vendored C source is retained as licensed translation reference and as the
oracle-test source. Production implementation code belongs directly under
`src/`; `src/tests/` contains the unit tests discovered by `cjpm test`, while
`test/` contains standalone consumer and acceptance projects.

## Current Read Surface

- Cangjie-owned `PngReadSession` with cloned input, explicit cursor, limits,
  and close state
- complete chunk framing with 31-bit length, type, truncation, and CRC checks
- IHDR-first and unique-IHDR enforcement
- libpng-aligned color type, bit depth, compression, filter, interlace, and
  default dimension-limit validation
- channel, pixel-depth, and packed row-byte derivation without pixel allocation
- consecutive IDAT collection with configurable compressed and inflated limits
- direct Cangjie FFI to the external zlib `uncompress2` API with exact output
  and consumed-input validation
- reversal of all five PNG adaptive row filters
- copy-owned raw rows for non-interlaced grayscale, truecolor, indexed,
  grayscale-alpha, and truecolor-alpha inputs, including packed bit depths
- copy-owned PLTE and tRNS metadata with color-type, length, uniqueness, and
  ordering validation
- `decodePngRgba8NonInterlaced` expansion for grayscale, truecolor, indexed,
  grayscale-alpha, and truecolor-alpha inputs at bit depths up to 8
- palette alpha and grayscale/RGB color-key transparency expansion
- separate configurable transformed-output byte limit
- copy-owned `Array<UInt16>` RGBA16 rows for every PNG color type
- libpng-aligned 8-to-16 channel expansion by `value * 257`
- explicit `Strip` and `Scale` modes for 16-to-8 conversion; the original
  no-policy RGBA8 entry still rejects 16-bit input
- immutable gAMA, cHRM, sRGB, sBIT, bKGD, and pHYs metadata retained across
  packed, RGBA8, and RGBA16 results with strict length, value, order, and
  uniqueness validation
- bounded unknown-length zlib inflate for iCCP, zTXt, and compressed iTXt with
  complete compressed-input consumption and the configured chunk-byte limit
- immutable iCCP profile, byte-owned tEXt/zTXt/iTXt entries, and validated tIME
  metadata retained across packed, RGBA8, and RGBA16 results
- explicit unknown-chunk policies for discard, retain ancillary, and retain
  all, preserving chunk type, payload, and after-IHDR/after-PLTE/after-IDAT
  location
- explicit late channel transforms for invert-monochrome, invert-alpha, BGR,
  sBIT unshift, and swap-alpha in frozen upstream order across RGBA8 and RGBA16
  rows, with final `RGBA`, `BGRA`, `ARGB`, or `ABGR` layout reported on the
  result
- generalized copy-owned pixel rows with natural `RGB`/`BGR` or alpha-bearing
  layouts, explicit strip-alpha, and filler/add-alpha before or after color
  channels across 8-bit, 16-bit, and explicit 16-to-8 output
- final transformed-output limiting based on the selected three- or
  four-channel row shape; 8-bit filler uses the low byte of its UInt16 value,
  matching the frozen upstream transform order
- direct `pngDoUnpack` source-row translation expands legal 1/2/4-bit
  grayscale and palette values to one byte each with exact reverse traversal,
  partial-byte alignment, copy ownership, and row-info growth to 8-bit samples
- direct `pngDoExpandPalette` translates legal 1/2/4/8-bit palette rows to
  RGB or RGBA with reverse growth, retained PLTE lookup, partial tRNS alpha
  defaulting, copy ownership, and exact output row information
- direct `pngDoExpand` translates packed Gray replication plus Gray/RGB
  8/16-bit tRNS color-key alpha growth with explicit absent-key state, reverse
  traversal, PNG network order, copy ownership, and exact row information
- `applyInitializedPngExpandStage` snapshots and applies copy-owned PLTE and
  effective palette-alpha data for Indexed rows or immutable Gray/RGB color
  keys for non-Indexed rows; Strip Alpha suppresses only effective tRNS while
  preserving upstream palette-to-RGB setter alias behavior
- direct `pngDoStripChannel` translates 8/16-bit first- or last-channel removal
  for two- and four-channel runtime rows with exact color-type/row-info updates;
  initialized Strip Alpha uses the last-channel path after effective tRNS
  expansion has already been suppressed
- direct `pngDoExpand16` replicates every 8-bit non-palette runtime row byte
  into a 16-bit high/low pair with reverse growth, retained color type/current
  channels, copy ownership, and exact row-information updates;
  `applyInitializedPngExpand16Stage` gates it after Scale/Strip and Quantize
- direct `pngDoQuantize` translates 8-bit RGB/RGBA through the frozen 5/5/5
  32768-entry palette lookup and remaps Indexed rows through a complete
  256-entry safety table with copy ownership and exact row-information updates
- explicit `UnshiftSignificantBits` applies retained sBIT precision per color
  and surviving semantic-alpha channel after inversion and before BGR,
  filler/add-alpha, and alpha swap; palette, UInt16, and reduced output use the
  component depth present at that stage
- direct `pngDoUnshift` source-row translation covers packed 2/4-bit grayscale,
  8-bit and network-order 16-bit G/GA/RGB/RGBA channel cycling with unchanged
  row information, copy ownership, and a narrow existing-selection adapter
- explicit RGB-to-gray output with the historical libpng fixed coefficients,
  caller-supplied red/green weights on the 100000 scale, or floating-point
  weights converted through exact `floor(100000 * value + 0.5)` semantics;
  `Convert` and `RequireGray` policy, a result-level nongray status, and
  explicit reporting of whether custom coefficients were accepted;
  upstream-style out-of-range custom weights retain the historical defaults
- frozen-default signed fixed-point multiply/divide plus direct gamma
  significance/threshold evaluation with exact `100000 +/- 5000` boundaries
  and correction forced on divide or signed-32-bit overflow failure
- fixed-point reciprocal plus immutable file-gamma resolution with exact
  explicit, chunk, default, reciprocal-screen, and zero precedence
- copy-owned `G`, `GA`, `AG`, `GX`, and `XG` rows across native 8-bit, native
  UInt16, and explicit Strip/Scale 16-to-8 output; conversion preserves alpha,
  equal RGB samples, frozen transform order, and final one/two-channel limits
- Cangjie-owned `PngReadTransformState` translating `png_rtran_ok` lifecycle
  gates plus the simple scale/strip/expand/gray setter bits; state projections
  reuse the existing 16-to-8, row-shape, and RGB-to-gray row implementations
- bounded `PngReadTransformState.setQuantize` state translation with explicit
  palette-remap/full-color modes, copy-owned palette/count limits, and a fresh
  complete 256-entry identity remap on every accepted non-full setter call
- full-color quantize state now materializes the frozen 32768-entry 5/5/5
  palette lookup with exact distance ordering, deterministic first-entry tie
  retention, copy ownership, repeated-call replacement, and non-full clearing
- histogram-backed quantize reduction preserves descending frequency selection,
  full/non-full palette relocation, complete original-index remapping, and
  first-closest retained-color ties while keeping caller arrays copy-owned
- no-histogram quantize reduction preserves 96-step Manhattan distance buckets,
  reverse head-insertion pair order, stale-pair rejection, odd/even elimination,
  bidirectional palette identity maps, and exact full/non-full outputs
- one-shot `PngReadTransformInitialization` classifies palette partial alpha,
  binary transparency, inherent source alpha, and effective tRNS after Strip
  Alpha, snapshots the Expand palette/alpha/color-key payload and quantize
  palette/count plus generated lookup/remap tables and fixed RGB-to-gray
  configuration, and exposes the translated read stages in frozen upstream
  order
- state-driven immutable gamma initialization snapshots configured file/screen
  values plus retained gAMA chunk gamma, resolves frozen precedence/fallback,
  and exposes whether file-to-screen correction is required before table
  generation
- lifecycle-gated fixed gamma configuration translates frozen sRGB/old-Mac
  flags, validates the supported range, and preserves failed-call state
- floating gamma configuration preserves already-fixed/flag-shaped values,
  scales ordinary decimals, and delegates into the fixed setter
- frozen 8-bit scalar gamma correction and immutable 256-entry table generation
  preserve exact endpoints, nearest rounding, identity fast paths, and
  copy-owned table access
- initialized 8-bit gamma snapshots derive exact reciprocal2 correction and
  retain direct plus optional RGB-to-gray to-linear/from-linear tables without
  adding an executable Gamma row stage
- source-shaped `pngDoRgbToGray` converts 8/16-bit RGB/RGBA byte rows into
  Gray/GA with fixed coefficients, PNG network-order preservation, exact row
  information, copy ownership, and aggregate nongray status
- `applyInitializedPngReadStages` composes Expand, Strip Alpha, RGB-to-gray,
  Gray-to-RGB, Scale/Strip16, Quantize, and Expand16 through one initialized
  row entry in frozen order
- `transformPngRowsInitialized` applies that initialized pipeline to a decoded
  non-interlaced image with transformed-byte limiting and copy-owned row access
- `applyInitializedPngQuantizeStage` executes the snapshotted full-color or
  Indexed remap state after Strip16 and before Expand16 while keeping disabled
  and unsupported rows copy-owned no-ops
- direct `pngDoGrayToRgb` row translation preserves the frozen 8/16-bit
  `G -> RGB`, `GA -> RGBA`, `GG -> RRGGBB`, and `GGAA -> RRGGBBAA` byte
  topology with exact row-info updates and copy-owned output; a narrow adapter
  applies it only when initialization contains the `GrayToRgb` stage
- direct `pngDoScale16To8` and `pngDoChop` row translations reduce network-byte
  G/GA/RGB/RGBA components into copy-owned 8-bit rows, update bit depth, pixel
  depth, and row bytes exactly, and retain copy-owned no-op behavior outside
  16-bit input; `applyInitializedPng16To8Stages` preserves Scale-before-Strip
  precedence when both stage bits are present
- direct `pngDoReadInvertAlpha` and `pngDoReadSwapAlpha` translations preserve
  8/16-bit GA/RGBA network-byte topology while producing copy-owned inverted
  or alpha-first rows with unchanged row info; `applySelectedPngAlphaTransforms`
  fixes the upstream relative order as Invert Alpha before Swap Alpha regardless
  of caller selection order
- direct `pngDoReadFiller` translation grows 8/16-bit grayscale or truecolor
  network-byte rows into GX/XG or RGBX/XRGB shapes, uses the low filler byte or
  low 16 filler bits exactly, and updates channels, pixel depth, and row bytes
  while retaining source color type; `PngReadRowInfo` can now represent explicit
  transformed channel counts independently from source color type
- direct `pngDoBgr` translates `pngtrans.c::png_do_bgr` for natural RGB/RGBA
  8-bit and network-order 16-bit rows, exchanges complete red/blue components,
  preserves row information, and returns copy-owned transformed or no-op rows
- direct `pngDoInvertMono` translates `pngtrans.c::png_do_invert` for packed,
  8-bit, and network-order 16-bit grayscale rows plus GA8/GA16 color bytes;
  packed padding bits invert with the complete stored byte and alpha is retained
- the one-shot initialized pipeline now snapshots and executes Invert Mono,
  Invert Alpha, significant-bit Unshift, packed-sample Unpack, invalid
  palette-index diagnosis, BGR, PackSwap, Filler/Add Alpha, Swap Alpha, and
  16-bit Byte Swap plus the native Cangjie read user transform after Expand16
  in frozen upstream-relative order;
  `setPacking()` and `setPackSwap()` only enable for a known sub-byte IHDR while
  `setSwap()` only enables for a known 16-bit IHDR, PackSwap reverses complete
  stored bytes, Byte Swap exchanges every adjacent component byte without
  changing row info, and earlier depth-changing stages produce validated
  copy-owned no-ops when their output no longer matches the selected stage depth
- invalid palette-index checking is enabled by default like frozen libpng and
  can be disabled explicitly; `pngDoCheckPaletteIndexes` scans only logical
  1/2/4/8-bit Indexed samples, excludes final-byte padding, preserves row bytes
  and information, and the initialized row/image results expose the maximum
  observed index plus whether it exceeds the retained PLTE
- `setReadUserTransform` installs a native Cangjie row callback with copy-owned
  input/output, explicit row/pass context, and a final stage after Byte Swap;
  `setUserTransformInfo` snapshots optional output depth/channels, configured
  nonzero values override callback-returned row information, and exact final
  row bytes are validated before the result is accepted
- bounded `projectPngReadTransformInfo` projects the current non-gamma Expand,
  Strip Alpha, RGB/gray, quantize, 16-to-8, Expand16, packing, and configured
  user-transform state into output color type, bit depth, channels, pixel depth,
  row bytes, remaining tRNS state, and a copy-owned synchronized palette using
  the frozen info-function order rather than runtime row-stage order

ICC color application, cHRM-derived RGB-to-gray defaults, gamma-aware
RGB-to-gray and general gamma correction, background composition, remaining
standard metadata, quantize allocation-warning fallback, benign-error callback
delivery for invalid palette indexes, the remaining read-transform dispatch
stages, complete transformed-metadata projection, C ABI callback trampolines,
raw user-transform pointers, Adam7
execution, progressive reading, and all write/C ABI surfaces remain open work.

The translation-first route is tracked in
`doc/PNG_RTRAN_TRANSLATION_LEDGER.md`. Its generated frozen inventory currently
asserts all 45 top-level functions in libpng `1.6.58` `pngrtran.c`; convenience
behavior is marked separately from complete setter/state/metadata translation.
The current ledger is `30 translated / 8 partial / 7 pending`.

## Native Dependency

The current host build links the system zlib library with `-lz`. zlib remains
external by design, matching upstream libpng. The current receipt is for
Cangjie `1.1.0` on macOS arm64; other hosts still require native build and
runtime receipts.

Run `./tools/doctor.sh` before build or test to verify the active Cangjie
toolchain and the host zlib link surface. The platform receipts, the
administrator-reported Cangjie 1.0.5 observation, uncovered large-input and
concurrency cases, and the exact pending capability matrix are recorded in
[Compatibility And Dependency Matrix](doc/COMPATIBILITY_AND_DEPENDENCY_MATRIX.md).

## Port Boundary

zlib remains a dependency, matching upstream libpng. The future compatibility
layer may use a minimal C shim for exported symbols, `setjmp`/`longjmp`, and
callback trampolines; PNG behavior and ownership logic remain Cangjie-owned.

See [README.OpenSource](README.OpenSource), [Feature API](doc/feature_api.md),
[Compatibility And Dependency Matrix](doc/COMPATIBILITY_AND_DEPENDENCY_MATRIX.md),
and [Porting Map](doc/PORTING_MAP.md).
