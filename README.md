# libpng4cj

libpng4cj is a full-port program for libpng `1.6.58`, implemented primarily in
Cangjie. It targets two eventual surfaces:

- a native Cangjie package named `libpng4cj`
- a compatible `libpng16` artifact for existing C and C++ consumers

The current `0.1.0` foundation contains PNG signature, chunk, endian, and CRC32
primitives. It is not yet a PNG decoder or a replacement for libpng.

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

## Port Boundary

zlib remains a dependency, matching upstream libpng. The future compatibility
layer may use a minimal C shim for exported symbols, `setjmp`/`longjmp`, and
callback trampolines; PNG behavior and ownership logic remain Cangjie-owned.

See [UPSTREAM.md](UPSTREAM.md) and [Porting Map](docs/PORTING_MAP.md).
