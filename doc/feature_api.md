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
- fixed/floating background setter state with immutable color, gamma-code,
  expansion, Compose/Strip Alpha, and alpha-encoding override facts

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

## Background Setter State

`PngBackground(index, gray, red, green, blue)` is the immutable
`png_color_16`-shaped value used by retained bKGD metadata and application
background configuration. The default and copy constructors are public.

`PngReadTransformState.setBackgroundFixed(background, gammaCode, needExpand,
backgroundGamma)` translates frozen `png_set_background_fixed`. Screen, File,
and Unique gamma codes are accepted; Unknown returns false, records
`backgroundGammaUnknownWarning()`, and leaves the previous accepted
configuration unchanged. An accepted call selects Compose and Strip Alpha,
clears Encode Alpha and Optimize Alpha, retains the copied color and fixed gamma,
and replaces background expansion from the current argument.

`setBackground(...)` accepts `Float64` gamma and applies
`floor(100000 * value + 0.5)` before delegating to the fixed setter. Nonfinite
and signed-32-bit overflow values fail before mutation. Both Bool and C-style
nonzero `Int64` expansion arguments are available.

## Background Initialization Snapshot

`initializePngReadTransformations` freezes accepted background state into
`PngReadTransformInitialization`. `backgroundConfigured()`, `background()`,
`backgroundGammaCode()`, and `backgroundGamma()` expose the immutable
configuration, while `composeEnabled()` and `backgroundExpandEnabled()` expose
the effective initialized decisions.

Palette and non-palette inputs without effective alpha or transparency cancel
Compose and background expansion. Binary/partial palette transparency,
color-key tRNS, and inherent alpha retain Compose. When both normal Expand and
background expansion are selected, palette indexes are resolved through the
retained PLTE and 1/2/4-bit grayscale background samples are scaled to 8-bit
values. Strip Alpha remains after effective Compose instead of entering the
early initialized stage list.

When Compose remains enabled, `backgroundOriginal()` exposes the background
after frozen depth normalization but before gamma correction,
`backgroundLinear()` exposes the correction-to-linear result, and
`background()` exposes the correction-to-screen result. `backgroundDepthNormalized()`
reports exact Expand16 division by 257 or 16-to-8 multiplication by 257.
`backgroundGammaInitialized()` gates `backgroundToLinearGamma()` and
`backgroundToScreenGamma()`; `effectiveBackgroundGammaCode()` becomes Screen
after non-palette correction while `backgroundGammaCode()` retains the caller's
configured code. Compose also requests linear 8/16-bit gamma tables independently
of RGB-to-gray. Pixel composition and palette mutation remain separate.

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
and whole-table accessors return deep copies.

`pngBuildGamma16To8Table(shift, gammaValue)` translates the frozen boundary-fill
specialization used when 16-bit input will be reduced to 8-bit. Every result is
an 8-bit level expanded by `*257`; boundary inputs are corrected, rescaled to
the compressed domain, and rounded exactly like upstream.

`pngResolveGamma16BitShift(colorType, significantBits, reductionRequired)` uses
the maximum retained RGB significance or grayscale significance, clamps shifts
to `0..8`, and enforces the frozen `PNG_MAX_GAMMA_8=11` floor when Scale16 or
Strip16 will reduce the output.

`pngBuildGamma16BitTables(...)` returns copy-owned direct and optional
to-linear/from-linear segmented tables. `PngGamma16BitTables` reports the
selected shift and whether its direct table is the 16-to-8 specialization.

`PngReadTransformInitialization.gamma16BitTablesBuilt()`,
`gamma16BitLinearTablesBuilt()`, `gamma16BitReductionTableBuilt()`, and
`gamma16BitShift()` expose the immutable 16-bit snapshot. Source depth 16 uses
retained sBIT plus Scale16/Strip16 state to choose the table topology. The
snapshot enables the existing Gamma stage only for direct file-to-screen
correction outside palette and RGB-to-gray ownership.

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
The 16-bit overload corrects network-order Gray/GA/RGB/RGBA color components
through the initialized segmented table and preserves alpha. Reduction-specialized
tables therefore execute before Scale16/Strip16.

When `ReadStageRgbToGray` owns gamma work,
`applyInitializedPngRgbToGrayStage(...)` consumes the initialized 8-bit or
segmented 16-bit to-linear/from-linear pair. Unequal original RGB samples are
linearized, combined with the configured fixed coefficients and frozen rounding,
then mapped back through from-linear; equal RGB uses the direct table. Alpha,
network byte order, strict original-sample mismatch detection, row information,
and copy ownership are preserved.

`pngDoCompose(...)` exposes the translated non-palette background row body.
The no-table overload performs exact tRNS replacement or alpha composition in
the supplied screen background. The 8-bit and 16-bit table overloads also take
the linear background and apply direct correction to opaque/color-key samples
or to-linear/composite/from-linear correction to partial alpha. Packed
grayscale padding, alpha bytes, row information, and 16-bit network order are
preserved.

Initialized background execution uses `ReadStageCompose` identity `20` and
`ReadStageStripAlphaAfterCompose` identity `21`. Compose executes after the
current gray/RGB stages, suppresses the separate Gamma stage when it owns
alpha/tRNS correction, and strips alpha only after composition.

For Indexed input, `pngInitPaletteBackgroundTransformations(...)` consumes
background composition and palette Gamma during one-shot initialization.
`PngPaletteTransformInitialization` exposes copy-owned effective PLTE/tRNS
snapshots plus `preprocessed`, `composeApplied`, and `gammaApplied` facts.

`PngReadTransformInitialization.effectivePalette()` and
`effectivePaletteAlpha()` expose the frozen payload used by both Expand and
transform-info projection. `palettePreprocessed()`, `paletteComposeApplied()`,
and `paletteGammaApplied()` distinguish configuration intent from work already
consumed before row execution. Source `PngReadMetadata` remains unchanged.

Transparent entries receive the effective screen background. Partial entries
use exact encoded-byte composition when no linear tables exist, or
to-linear/composite/from-linear correction when Gamma is required. Opaque and
implicit-tail entries use direct correction only when required. Screen, File,
and Unique background modes are resolved at 8-bit palette depth regardless of
the Indexed sample bit depth.

When effective `AlphaOptimized` survives initialization, partial palette
entries use the frozen optimized branch instead: convert to linear, compute
`round(component * alpha / 255)`, and convert back to the requested output
Gamma without adding a background contribution. Transparent entries become
black, opaque entries receive direct correction, and the retained alpha prefix
continues into Expanded associated-alpha output. Source PLTE/tRNS ownership is
unchanged.

The Gamma-only optimization is suppressed when Indexed input will Expand into
gamma-aware RGB-to-gray. In that topology the original PLTE reaches the
RGB-to-gray stage so color samples are linearized exactly once.

After palette preprocessing, row Compose and row Gamma are absent. Expand uses
the effective palette and retained alpha prefix, then the background setter's
Strip Alpha removes the temporary alpha channel. Non-Expand info projection
retains Indexed rows while exposing the effective palette and no remaining
transparency.

## Alpha Mode State

`PngReadTransformState.setAlphaModeFixed(mode, outputGamma)` translates the
fixed read alpha-mode setter. `setAlphaMode(mode, outputGamma)` converts a
floating Gamma value through the same fixed-point rules before delegating.

`PngAlphaMode` provides `AlphaPng`, `AlphaAssociated`, `AlphaOptimized`, and
`AlphaBroken`. The state exposes `alphaModeConfigured()`, `alphaMode()`,
`defaultGamma()`, `screenGamma()`, `composeEnabled()`,
`encodeAlphaEnabled()`, and `optimizeAlphaEnabled()`.

The first successful alpha-mode call stores reciprocal default file Gamma.
Associated mode forces screen Gamma to `PNG_FP_1`; premultiplying modes use a
black `BackgroundGammaFile` background and Compose. PNG mode preserves an
existing background while clearing Encode/Optimize. Conflicts and invalid or
late calls leave prior state intact and expose diagnostic facts.

`PngReadTransformInitialization` freezes the same alpha-mode/default-Gamma
facts and resolves them into `fileGamma()` and `screenGamma()`. This surface is
configuration and initialization state; row execution is provided by the
separate helpers below.

Input classification follows the frozen initializer: palette input counts only
partial tRNS values as alpha, while inherent GA/RGBA counts as alpha by color
type. Opaque input and binary-only palette transparency cancel effective Encode
and Optimize, as does insignificant screen Gamma. These cancellations affect
the immutable initialization snapshot only; the caller's configured setter
intent remains readable from `PngReadTransformState`.

`pngDoEncodeAlpha(rowInfo, row, table)` provides 8-bit and 16-bit overloads for
GA/RGBA rows. It applies only the supplied from-linear Gamma table to the final
alpha component and returns a copy-owned `PngReadTransformRow`.

When Broken alpha mode remains effective after initialization,
`ReadStageEncodeAlpha` is placed after Compose, Gamma, and post-Compose Strip
Alpha, then before Scale/Strip 16-to-8. `encodeAlphaEnabled()` and
`optimizeAlphaEnabled()` on the initialization expose effective state after
near-linear screen-Gamma and surviving-alpha cancellation.
For partial Indexed alpha, effective Optimize is consumed by initialization-time
palette premultiplication and is shared by Expand and non-Expand consumers.

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
