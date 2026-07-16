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
- immutable 8-bit and segmented 16-bit gamma table substrates
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

`PngReadTransformState.setGammaFixed(screenGamma, fileGamma)` translates the
reserved sRGB/old-Mac flag aliases by screen/file role, accepts only the frozen
inclusive range `1000..10000000`, and stores values only after the existing
read-transform lifecycle gate succeeds. Invalid nonpositive inputs expose
application-error facts; unsupported values expose a warning fact. Failed calls
do not replace the last accepted gamma state.

`PngReadTransformState.setGamma(screenGamma, fileGamma)` accepts `Float64`.
Positive values below `128` are multiplied by `PNG_FP_1`; other finite values
are treated as already-fixed or flag-shaped inputs. The conversion then applies
`floor(value + 0.5)`, rejects nonfinite/signed-32-bit overflow before mutation,
and delegates both converted values into `setGammaFixed`.

`initializePngReadTransformations` snapshots the accepted explicit file/screen
gamma state together with retained gAMA chunk gamma, then calls
`pngInitGammaValues`. `PngReadTransformInitialization` exposes
`gammaConfigured`, `chunkGamma`, resolved `fileGamma`/`screenGamma`,
`gammaCorrectionRequired`, and a copy of the immutable `PngGammaValues` result.
Explicit file gamma wins over gAMA; absent sources resolve to identity gamma.
This initialization fact does not itself add a Gamma row stage or alter
existing stage ordinals. Later packets attach the 8-bit table snapshot and
bounded packed/8-bit row correction; 16-bit attachment remains separate work.

`pngGamma8BitCorrect(value, gammaValue)` translates the frozen floating
arithmetic branch for byte samples. Zero and 255 remain exact; interior values
use `floor(255 * pow(value / 255, gammaValue * 0.00001) + 0.5)`.

`pngBuildGamma8BitTable(gammaValue)` returns a copy-owned immutable
`PngGamma8BitTable`. Gamma values inside the significance threshold generate
the exact identity table; significant values apply scalar correction to all
256 entries. The table builder is intended for positive gamma values already
resolved from validated setter/metadata state.

`pngGamma16BitCorrect(value, gammaValue)` preserves exact zero/65535 endpoints
and applies the frozen floating correction
`floor(65535 * pow(value / 65535, gammaValue * 0.00001) + 0.5)` to interior
samples.

`pngBuildGamma16BitTable(shift, gammaValue)` returns an immutable
`PngGamma16BitTable` for shifts `0..8`. It retains the frozen segmented layout:
`1 << (8 - shift)` segments of 256 entries, selected by the retained low bits
and indexed by the input high byte. Significant gamma uses direct full-range
`pow` scaling; insignificant gamma uses exact identity-range scaling. Segment
and whole-table accessors return deep copies. The table is not yet attached to
read initialization or 16-bit `pngDoGamma` execution.

`pngReciprocal2Fixed(a, b)` preserves the frozen floating arithmetic used for
file-to-screen correction: nonzero inputs calculate `floor(1E15/a/b + 0.5)`,
signed-32-bit overflow returns zero, and either zero input returns zero.

`pngBuildGamma8BitTables(fileGamma, screenGamma, linearTablesRequired)` builds
the direct correction table from reciprocal2. When linear tables are requested,
it also builds file-to-linear and linear-to-screen tables, including the frozen
unknown-screen fallback. `PngGamma8BitTables` owns every table copy.

`PngReadTransformInitialization.gamma8BitTablesBuilt()` and
`gamma8BitLinearTablesBuilt()` report the initialized snapshot. Direct tables
are retained only for required correction or linear RGB-to-gray work at source
depths up to 8. LP-S004AW retained these snapshots without row execution;
LP-S004AX below consumes the direct table for bounded packed/8-bit rows.

`pngDoGamma(rowInfo, row, table)` translates the frozen packed and 8-bit
branches of `png_do_gamma`. It corrects 2/4-bit packed grayscale and 8-bit
Gray/GA/RGB/RGBA color samples, preserves alpha, leaves 1-bit grayscale,
palette, and 16-bit rows copy-owned and unchanged, and validates row length
before transform selection.

`applyInitializedPngGammaStage(...)` executes only when direct correction is
required and neither palette initialization nor RGB-to-gray owns gamma work.
`ReadStageGamma` has stable identity `19`, leaving all prior stage identities
unchanged while executing after Gray-to-RGB and before 16-to-8 reduction.
Sixteen-bit Gamma rows and gamma-aware RGB-to-gray remain separate work.

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
