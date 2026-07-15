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
- explicit `UnshiftSignificantBits` applies retained sBIT precision per color
  and surviving semantic-alpha channel after inversion and before BGR,
  filler/add-alpha, and alpha swap; palette, UInt16, and reduced output use the
  component depth present at that stage
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
- one-shot `PngReadTransformInitialization` classifies palette partial alpha,
  binary transparency, inherent source alpha, and effective tRNS after Strip
  Alpha, then exposes the translated read stages in frozen upstream order
- direct `pngDoGrayToRgb` row translation preserves the frozen 8/16-bit
  `G -> RGB`, `GA -> RGBA`, `GG -> RRGGBB`, and `GGAA -> RRGGBBAA` byte
  topology with exact row-info updates and copy-owned output; a narrow adapter
  applies it only when initialization contains the `GrayToRgb` stage
- bounded `projectPngReadTransformInfo` projects the current non-gamma Expand,
  Strip Alpha, RGB/gray, 16-to-8, and Expand16 state into output color type,
  bit depth, channels, pixel depth, row bytes, and remaining tRNS state using
  the frozen info-function order rather than runtime row-stage order

ICC color application, cHRM-derived RGB-to-gray defaults, gamma-aware
RGB-to-gray and general gamma correction, background composition, remaining
standard metadata, quantization, user callbacks, Adam7 execution, progressive
reading, and all write/C ABI surfaces remain open work.

The translation-first route is tracked in
`docs/PNG_RTRAN_TRANSLATION_LEDGER.md`. Its generated frozen inventory currently
asserts all 45 top-level functions in libpng `1.6.58` `pngrtran.c`; convenience
behavior is marked separately from complete setter/state/metadata translation.
The current ledger is `23 translated / 6 partial / 16 pending`.

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
