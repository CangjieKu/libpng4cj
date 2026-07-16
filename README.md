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
```

## Current Baseline

- upstream version: `1.6.58`
- upstream tag: `v1.6.58`
- upstream commit: `3061454d980de7d53608f594194cfac722721d2a`
- vendored reference: `vendor/libpng-1.6.58/`

The vendored C source is retained as licensed translation reference and as the
oracle-test source. New implementation code belongs under `src/libpng4cj/`.

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
- explicit RGB-to-gray output with the historical libpng fixed coefficients or
  caller-supplied red/green weights on the 100000 scale, `Convert` and
  `RequireGray` policy, a result-level nongray status, and explicit reporting of
  whether custom coefficients were accepted; upstream-style out-of-range
  custom weights retain the historical defaults
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
  palette/count plus generated lookup/remap tables, and exposes the translated
  read stages in frozen upstream order
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
- bounded `projectPngReadTransformInfo` projects the current non-gamma Expand,
  Strip Alpha, RGB/gray, quantize, 16-to-8, and Expand16 state into output color
  type, bit depth, channels, pixel depth, row bytes, remaining tRNS state, and a
  copy-owned synchronized palette using the frozen info-function order rather
  than runtime row-stage order

ICC color application, cHRM-derived RGB-to-gray defaults, gamma-aware
RGB-to-gray and general gamma correction, background composition, remaining
standard metadata, quantize allocation-warning fallback, complete read-transform
dispatch, complete transformed-metadata projection, user callbacks, Adam7
execution, progressive reading, and all write/C ABI surfaces remain open work.

The translation-first route is tracked in
`docs/PNG_RTRAN_TRANSLATION_LEDGER.md`. Its generated frozen inventory currently
asserts all 45 top-level functions in libpng `1.6.58` `pngrtran.c`; convenience
behavior is marked separately from complete setter/state/metadata translation.
The current ledger is `24 translated / 7 partial / 14 pending`.

## Native Dependency

The current host build links the system zlib library with `-lz`. zlib remains
external by design, matching upstream libpng. The current receipt is for
Cangjie `1.1.0` on macOS arm64; other hosts still require native build and
runtime receipts.

## Port Boundary

zlib remains a dependency, matching upstream libpng. The future compatibility
layer may use a minimal C shim for exported symbols, `setjmp`/`longjmp`, and
callback trampolines; PNG behavior and ownership logic remain Cangjie-owned.

See [UPSTREAM.md](UPSTREAM.md) and [Porting Map](docs/PORTING_MAP.md).
