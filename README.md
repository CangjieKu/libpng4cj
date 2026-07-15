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
  and swap-alpha in frozen upstream order across RGBA8 and RGBA16 rows, with
  final `RGBA`, `BGRA`, `ARGB`, or `ABGR` layout reported on the result

ICC color application, gamma correction, background composition, remaining
standard metadata, sBIT shift, strip/filler and RGB-to-gray transforms,
quantization, user callbacks, Adam7 execution, progressive reading, and all
write/C ABI surfaces remain open work.

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
