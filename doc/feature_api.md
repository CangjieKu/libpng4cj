# Feature API

## Dependency

```toml
[package]
link-option = "-lz"

[dependencies]
libpng4cj = { git = "https://gitcode.com/cinyu/libpng4cj.git" }
```

The final executable links the system zlib because libpng4cj is currently
published as a static Cangjie library. Run `./tools/doctor.sh` from the member
root to verify the local Cangjie and zlib surfaces before consuming the package.

## Import

```cangjie
import libpng4cj.*
```

## Current Entry Points

- PNG signature, endian, chunk-type, and CRC primitives
- bounded chunk and metadata reading
- non-interlaced packed-row decoding
- RGBA8, RGBA16, generalized row-shape, and initialized row transformations
- fixed RGB-to-gray, expansion, alpha, invert-mono, BGR, 16-bit reduction,
  quantize, filler, and significant-bit row operations
- initialized late-channel setters and stages for invert mono, invert alpha,
  significant-bit unshift, packed-sample unpack, BGR, 1/2/4-bit PackSwap,
  filler/add alpha placement, and alpha swapping

The complete translated function inventory and exact status are maintained in
[PNG_RTRAN_TRANSLATION_LEDGER.md](PNG_RTRAN_TRANSLATION_LEDGER.md).
