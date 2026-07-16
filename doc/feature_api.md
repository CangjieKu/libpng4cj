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
- fixed/floating RGB-to-gray, expansion, alpha, invert-mono, BGR, 16-bit
  reduction, quantize, filler, and significant-bit row operations
- fixed-point multiply/divide and gamma significance/threshold helpers
- fixed reciprocal and immutable file-gamma precedence resolution
- initialized late-channel setters and stages for invert mono, invert alpha,
  significant-bit unshift, packed-sample unpack, invalid palette-index
  diagnosis, BGR, 1/2/4-bit PackSwap, filler/add alpha placement, alpha
  swapping, 16-bit byte swapping, and native Cangjie read user transforms

The complete translated function inventory and exact status are maintained in
[PNG_RTRAN_TRANSLATION_LEDGER.md](PNG_RTRAN_TRANSLATION_LEDGER.md).

## Floating RGB To Gray Setter

`PngReadTransformState.setRgbToGray(policy, redWeight, greenWeight)` accepts
`Float64` coefficients. Each value is converted with the frozen
`png_fixed` rule:

```text
floor(100000 * value + 0.5)
```

The converted signed fixed-point weights delegate into
`setRgbToGrayFixed`. Non-finite values and converted values outside signed
32-bit range fail before transform state changes. Negative converted values
retain historical defaults; nonnegative red/green pairs whose sum exceeds
`100000` are ignored by the fixed setter while RGB-to-gray remains selected,
matching the upstream setter behavior.

## Gamma Threshold Helpers

`pngMulDivFixed(value, multiplier, divisor)` mirrors frozen libpng's default
floating-arithmetic `png_muldiv` branch for signed 32-bit values. It returns an
explicit success flag plus value, preserving divide-by-zero and signed-32-bit
overflow failure.

`pngGammaSignificant(gammaValue)` uses the strict frozen range from `95000`
through `105000`, inclusive, as not significant. `pngGammaThreshold` evaluates
the screen/file product on the `100000` scale and returns `true` when that
product is significant or cannot be represented, matching upstream's
correction-enabling failure behavior.

`pngReciprocalFixed(value)` returns the frozen 100000-scale reciprocal or zero
when division or signed-32-bit representation fails.

`PngFileGammaSources` holds explicit file, chunk, default, and screen values.
`pngResolveFileGamma` returns the first nonzero value in that order, except that
screen gamma is reciprocated before return. An all-zero source set or failed
screen reciprocal resolves to zero. The input object remains immutable.

`pngInitGammaValues` returns immutable `PngGammaValues`. Positive file and
screen gamma values retain both inputs and evaluate correction significance. A
positive file with absent or nonpositive screen gamma derives the screen value
from the file reciprocal. A nonpositive resolved file resets both values to
`PNG_FP_1` and disables correction.

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

## Native Read User Transform

`PngReadTransformState.setReadUserTransform` accepts a native Cangjie function
with this shape:

```cangjie
(
    PngReadUserTransformContext,
    PngReadRowInfo,
    Array<Byte>
) -> PngReadUserTransformResult
```

The callback receives a copy-owned row and immutable row/pass context. It
returns copy-owned row information and bytes. Initialized execution runs the
callback after `BYTE_SWAP`; configured nonzero values from
`setUserTransformInfo(depth, channels)` then override the callback-returned
depth/channels, and the final row length must match the recomputed row bytes.

`projectPngReadTransformInfo` applies the same configured nonzero
depth/channels only when a user-transform callback is active. The current
whole-image non-interlaced path reports zero-based row numbers and pass `0`.

The current surface is Cangjie-native. C ABI callback trampolines, raw
`user_transform_ptr` storage, null callback semantics, late callback mutation,
write user transforms, and progressive/Adam7 pass execution remain open.
