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
  significant-bit unshift, packed-sample unpack, invalid palette-index
  diagnosis, BGR, 1/2/4-bit PackSwap, filler/add alpha placement, alpha
  swapping, and 16-bit byte swapping

The complete translated function inventory and exact status are maintained in
[PNG_RTRAN_TRANSLATION_LEDGER.md](PNG_RTRAN_TRANSLATION_LEDGER.md).

## Invalid Palette Index Diagnosis

`PngReadTransformState` enables invalid palette-index checking by default.
`setCheckForInvalidIndex(Bool)` or the integer overload can explicitly control
that behavior before or after initialization; an existing immutable
initialization snapshot is not changed by later setter calls.

`pngDoCheckPaletteIndexes` accepts a source-shaped Indexed row plus retained
PLTE count and returns a copy-owned `PngPaletteIndexCheckResult`. It scans only
logical 1/2/4/8-bit samples, excludes final-byte padding, preserves row
information, and can accumulate a prior maximum across rows.

Initialized execution places `PALETTE_INDEX_CHECK` after `UNPACK` and before
`BGR`. `PngInitializedReadRowResult` and `PngInitializedReadRowsResult` expose
`maximumPaletteIndex` and `hasInvalidPaletteIndex`. This is a diagnostic fact;
row bytes are not rewritten. Benign-error callback delivery and the separate
palette-expansion zero-fill compatibility path remain open.
