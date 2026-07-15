# libpng4cj

libpng4cj is a full-port program for libpng `1.6.58`, implemented primarily in
Cangjie. It targets two eventual surfaces:

- a native Cangjie package named `libpng4cj`
- a compatible `libpng16` artifact for existing C and C++ consumers

The current `0.1.0` development line contains PNG signature/endian/CRC32
primitives, a bounded in-memory chunk reader, strictly validated IHDR and PLTE
handling, and the first non-interlaced raw-row decoder. It is not yet a complete
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

Adam7 execution, palette/sample expansion, the complete transform matrix,
metadata materialization, progressive reading, and all write/C ABI surfaces
remain open work.

## Native Dependency

The current host build links the system zlib library with `-lz`. zlib remains
external by design, matching upstream libpng. The verified LP-S003 receipt is
for Cangjie `1.1.0` on macOS arm64; other hosts still require native build and
runtime receipts.

## Port Boundary

zlib remains a dependency, matching upstream libpng. The future compatibility
layer may use a minimal C shim for exported symbols, `setjmp`/`longjmp`, and
callback trampolines; PNG behavior and ownership logic remain Cangjie-owned.

See [UPSTREAM.md](UPSTREAM.md) and [Porting Map](docs/PORTING_MAP.md).
