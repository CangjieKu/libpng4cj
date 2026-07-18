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
- bounded chunk and metadata reading with configurable critical/ancillary CRC
  actions
- whole-image packed-row decoding for non-interlaced and Adam7 input
- bounded chunk-fed progressive lifecycle with native info/row/end callbacks
- bounded non-interlaced and Adam7 packed-row encoding with exact core chunks,
  CRC, zlib compression, fixed filters, and deterministic adaptive filtering
- lifecycle-frozen write transforms for packing, pack swap, filler stripping,
  byte swap, significant-bit shift, alpha order/inversion, BGR, and invert mono
- native custom write sinks with copy-owned signature/framed-chunk delivery,
  exact byte/emission receipts, live callback replacement, and final flush
- copy-owned unknown-chunk write injection with explicit legal regions,
  safe-to-copy/ancillary/all policies, and retained round-trip support
- a copy-owned row-at-a-time writer lifecycle with exact row accounting and
  non-interlaced/Adam7 memory or custom-sink finalization
- genuine non-interlaced incremental deflate with `startTo(sink)`, bounded IDAT
  chunk emission during row intake, and exact-once final IEND/flush
- Adam7 `startTo(sink)` with immediate prefix emission, one-time complete-row
  transforms, bounded seven-pass spooling, and canonical pass-order IDAT output
  during `finishTo()`
- lifecycle-frozen `PngWriteControlState` configuration for filter subsets,
  compression level/memory/window/method/strategy, and deflate output-buffer
  sizing across whole-image, row, sink, and Adam7 write paths
- copy-owned simplified memory images with begin/finish/free lifecycle, the
  common Gray/GA/AG/RGB/BGR/RGBA/ARGB/BGRA/ABGR 8-bit layouts, explicit
  background composition, and non-interlaced or Adam7 memory write-back
- copy-owned host-numeric UInt16 simplified images in the same nine linear
  layouts, with straight/associated alpha, black composition on alpha removal,
  and 16-bit linear or explicitly converted sRGB8 memory write-back
- copy-owned simplified colormap images with one byte per pixel, six common
  entry layouts, direct Indexed palette identity, deterministic generated map
  families, and indexed non-interlaced or Adam7 memory write-back
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
- copy-owned standard ancillary metadata for cICP, cLLI, mDCV, eXIf, hIST,
  oFFs, pCAL, sCAL, and sPLT

The complete translated function inventory and exact status are maintained in
[PNG_RTRAN_TRANSLATION_LEDGER.md](PNG_RTRAN_TRANSLATION_LEDGER.md).

## Simplified Memory Image API

`PngImage` exposes an allocating Cangjie-native memory facade:

```cangjie
let image = beginPngImageReadFromMemory(pngBytes)
let bgra = image.finishRead(ImageBgra8)

let controls = PngWriteControlState()
controls.setCompressionLevel(Int32(3))
let rewritten = writePngImageToMemory(
    bgra, PngWriteMetadata(), controls, Adam7, PngWriteLimits()
)
```

After `beginReadFromMemory`, width, height, source bit depth, source color
type, and an IHDR-derived suggested 8-bit format are available without
transferring input ownership. The suggestion reflects inherent Gray/RGB alpha;
pre-IDAT `tRNS` is applied by `finishRead` but is not folded into that early
suggestion. `finishRead` accepts Gray8, GA8, AG8, RGB8, BGR8, RGBA8, ARGB8,
BGRA8, or ABGR8 and returns a copy-owned `PngImageBuffer` with exact channels,
minimal row stride, byte count, whole-buffer copy, and row copies. Input at
1/2/4/8/16-bit depth, Indexed/tRNS, non-interlaced, or Adam7 is accepted through
the existing decoder.

When the requested format removes alpha, the allocating facade performs bounded
8-bit integer composition in encoded sample space onto the supplied
`PngSrgbColor8`; the no-background overload uses black. This packet does not
claim exact gamma-aware `png_image_finish_read` composition parity.
`writePngImageToMemory` canonicalizes the same nine layouts and reuses the
existing writer, metadata, controls, limits, and `None`/`Adam7` selection.
`free()` releases retained input and is idempotent.

For host-numeric linear UInt16 output, use `finishReadLinear`:

```cangjie
let image = beginPngImageReadFromMemory(pngBytes)
let associated = image.finishReadLinear(LinearRgba, true)

let linearPng = writePngLinearImageToMemory(associated, false, Adam7)
let srgbPng = writePngLinearImageToMemory(associated, true)
```

`PngLinearImageFormat` provides LinearGray, LinearGrayAlpha, LinearAlphaGray,
LinearRgb, LinearBgr, LinearRgba, LinearArgb, LinearBgra, and LinearAbgr.
`PngLinearImageBuffer` owns an exact contiguous `Array<UInt16>` with component
count, byte count, minimal component stride, whole-buffer copies, and row
copies. Read conversion uses retained gAMA/sRGB facts and the initialized gamma,
expand, Gray-to-RGB, 16-bit, and alpha-mode pipeline. Straight output preserves
alpha; associated output premultiplies in linear component space; formats that
remove alpha compose onto linear black.

Linear read uses the frozen upstream exact sRGB-to-linear table for 8-bit sRGB
and default-sRGB sources. Linear write-back unassociates color when required.
The default emits 16-bit PNG with gAMA 1.0; `convertTo8Bit = true` uses the
frozen upstream base/delta transfer tables to emit an 8-bit sRGB PNG. Both
paths reuse caller metadata, `PngWriteControlState`, `PngWriteLimits`, and
non-interlaced or Adam7 output.

For color-mapped output, use `finishReadColormap`:

```cangjie
let image = beginPngImageReadFromMemory(pngBytes)
let mapped = image.finishReadColormap(ColormapBgra8)
let indexedPng = writePngColormapImageToMemory(mapped, Adam7)
```

`PngColormapFormat` provides RGB, BGR, RGBA, ARGB, BGRA, and ABGR 8-bit entry
layouts. `PngColormapImageBuffer` owns one byte per image pixel plus a
copy-owned 1..256-entry table, with exact dimensions, minimal row stride,
entry count/channels, whole-buffer copies, row copies, and entry copies.
Indexed input preserves PLTE/tRNS entry identity and unpacks 1/2/4-bit indices.
Other inputs use the upstream-shaped simplified families: 256-entry
gray/gray-alpha, the 6x6x6 216-color cube, or the 216+1+27 alpha/background
map, with the frozen index thresholds and entry topology. Alpha-removing
formats compose in encoded sample space onto the supplied `PngSrgbColor8`; the
convenience overload uses black.

`writePngColormapImageToMemory` derives PLTE and the minimal tRNS prefix from
the entry table, selects 1/2/4/8-bit indexed depth from entry count, packs the
one-byte application indices, and reuses metadata, controls, limits, and
non-interlaced or Adam7 output. Caller-supplied tRNS is rejected because the
colormap owns transparency.

This native packet is not the exact C `png_image` ABI. Negative or custom row
stride, file/stdio operations, raw pointers, struct layout, and exported
`png_image_*` symbols remain later LP-S007/LP-S008 work.

## Non-Interlaced Packed Write

The first native write surface accepts source-shaped packed rows and emits a
complete PNG with signature, IHDR, optional indexed or truecolor PLTE, one or
more IDAT chunks, and IEND:

```cangjie
let png = encodePngPacked(
    UInt32(2), UInt32(2), UInt8(8), TruecolorAlpha,
    [
        [255, 0, 0, 255, 0, 255, 0, 255],
        [0, 0, 255, 255, 255, 255, 255, 255]
    ]
)
```

`PngWriteSession` exposes explicit Open, Finalizing, Completed, Failed, and
Closed states. The full constructor accepts `None` or `Adam7`, an optional
indexed palette, copy-owned `PngWriteMetadata`, `PngWriteTransformState`,
`PngWriteControlState`, and `PngWriteLimits`. Legacy overloads accepting
`PngWriteFilterStrategy` plus a zlib level remain available. Filter strategies
include None, Sub, Up, Average, Paeth, and deterministic Adaptive selection.
Adaptive selection minimizes the sum of signed-byte magnitudes and keeps the
first filter on ties. Limits independently bound transformed row bytes,
filtered row bytes, compressed IDAT bytes, raw metadata bytes, compressed
metadata bytes, complete encoded output bytes, and each emitted IDAT payload.

Configure advanced filter and compressor policy before creating a session:

```cangjie
let controls = PngWriteControlState()
controls.setFilters(true, true, true, false, true)
controls.setCompressionLevel(Int32(6))
controls.setCompressionMemoryLevel(Int32(8))
controls.setCompressionWindowBits(Int32(15))
controls.setCompressionMethod(Int32(8))
controls.setCompressionStrategy(WriteCompressionFiltered)
controls.setCompressionBufferBytes(Int64(32768))

let png = encodePngPacked(
    width, height, UInt8(8), TruecolorAlpha, rows,
    Array<Byte>(), PngWriteMetadata(), controls, PngWriteLimits()
)
```

`setFilters` accepts any non-empty subset of the five PNG row filters. An
unset filter policy defaults packed/Indexed output to None and other byte-depth
output to all filters. Width-one images remove Sub/Average/Paeth and height-one
images remove Up/Average/Paeth, with deterministic None fallback when the
requested set becomes empty. Window bits are clamped to PNG's `8..15` range;
level, memory level, method, and buffer size reject invalid values. Explicit
compression strategies are Default, Filtered, Huffman-only, RLE, and Fixed.
Without an explicit strategy, filtered output uses zlib's filtered strategy
and None-only output uses the default strategy, matching the frozen libpng
configuration. `WriteHeuristicDefault` and `WriteHeuristicUnweighted` preserve
the public fixed-heuristic state; libpng 1.6 treats the deprecated weighted
heuristic body as a no-op, so both currently use the same deterministic score.

The control state is frozen when `PngWriteSession` or `PngRowWriteSession` is
created. Later mutations do not change that session. Whole-image memory/sink,
deferred row memory/sink, and early non-interlaced row output share one frozen
control snapshot and produce identical bytes for identical inputs. Adam7 uses
the same compressor controls while retaining pass-local previous-row history.

All legal PNG color-type/bit-depth row shapes are accepted for non-interlaced
or Adam7 output. `encodePngPackedAdam7` and `encodeIndexedPngPackedAdam7`
extract the seven pass streams from canonical full-image rows, including packed
1/2/4-bit samples and 8/16-bit channel groups. Every non-empty pass resets its
previous-row filter state and empty passes emit no bytes. Indexed writes require
RGB palette triples and reject row indexes
outside the declared PLTE. Truecolor and TruecolorAlpha may carry an optional
suggested PLTE, while grayscale-family output rejects PLTE. Input rows remain
caller-owned. The writer checks row count, row bytes, palette shape,
filtered/compressed/output limits, chunk sizing, and zlib status before
reporting Completed.

`PngWriteTransformState` is configured for the target bit depth and color type,
then frozen when a session is created. Its initialized execution order follows
the default `pngwtran.c` pipeline: an optional native user transform, strip
filler, pack swap, pack, 16-bit byte
swap, significant-bit shift, alpha swap, alpha inversion, BGR, then monochrome
inversion. Packing changes the accepted source row from packed 1/2/4-bit samples
to one byte per sample; filler stripping accepts one extra channel before or
after G/RGB. Both non-interlaced and Adam7 writers transform canonical full rows
before filtering, while retaining caller ownership and exact IHDR output shape.

`PngWriteTransformState.setWriteUserTransform(callback)` registers a native
Cangjie callback with this shape:

```cangjie
(
    PngWriteUserTransformContext,
    PngReadRowInfo,
    Array<Byte>
) -> PngWriteUserTransformResult
```

The callback receives an owned complete source row plus its full-image row
number and interlace method. It runs before the default write transforms and
must return the configured source row shape. Registration without a callback
enables an identity stage. The callback may be enabled or replaced after session
initialization; replacement is observed by the next complete row. Adam7 invokes
the callback exactly once per full-image row before seven-pass gathering.

`PngWriteSession.writeTo(rows, sink)` routes the same prepared PNG used by
`write(rows)` through a native `PngWriteSink`. The write callback receives one
copy-owned emission for the signature or one complete framed chunk, plus
`PngWriteOutputContext` containing its sequence number, output kind, chunk
type, byte offsets, and final-IEND flag. The flush callback receives final byte
and emission counts exactly once after IEND and output-size validation.

```cangjie
let sink = PngWriteSink()
sink.setWriteCallback({ context, bytes => output.write(bytes) })
sink.setFlushCallback({ context => output.flush() })
let receipt = session.writeTo(rows, sink)
```

Write and flush callbacks may be replaced while emission is active; the next
callback observes the replacement. Callback input is copy-owned. Sink or flush
exceptions, including reentrant write/close attempts, move the session to
`WriteFailed`. Whole-image output limits are checked before the first sink
callback; incremental row output enforces the same limit before every emitted
signature/chunk callback because the final compressed size is not known yet.

`PngRowWriteSession` accepts one complete source row at a time through
`writeRow`. The constructor freezes the same metadata, palette, transform,
filter, compression, interlace, and limit configuration as `PngWriteSession`.
Each row is validated against `expectedRowBytes()` and copied immediately.
`expectedRowCount()`, `acceptedRowCount()`, and `remainingRowCount()` expose
the intake state.

```cangjie
let writer = PngRowWriteSession(
    width, height, UInt8(8), TruecolorAlpha, Adam7,
    Array<Byte>(), PngWriteMetadata(), WriteFilterAdaptive, Int32(6),
    PngWriteLimits()
)
for (row in rows) {
    writer.writeRow(row)
}
let png = writer.finish()
```

`finish()` returns memory output and `finishTo(sink)` uses the same custom-sink
contract as the whole-image writer. For non-interlaced output both paths now
feed rows through the same incremental deflate and IDAT framing core.

To receive output during row intake, attach the sink before the first row:

```cangjie
writer.startTo(sink)
for (row in rows) {
    writer.writeRow(row)
}
let receipt = writer.finishTo()
```

`startTo` emits the signature, IHDR, palette, and legal pre-IDAT metadata at
startup. Each subsequent non-interlaced `writeRow` applies the frozen user and
default transforms, selects the configured filter, feeds one framed row into a
bounded `z_stream`, and emits every complete configured IDAT chunk immediately.
Trailing metadata, IEND, and the exact-once flush are emitted by the no-argument
`finishTo()`. Callback replacement, copy ownership, output/compressed limits,
and failed-state rules match the existing sink contract.

For Adam7, `startTo` emits the same prefix immediately. Each accepted complete
image row is transformed once and gathered into only the pass rows to which it
contributes. `finishTo()` then resets filter history per non-empty pass and
feeds those bounded pass-local rows through the same configured deflater and
IDAT framing core. Because PNG requires pass order while callers provide image
row order, Adam7 IDAT starts during `finishTo()`, not during `writeRow`; the
session does not retain both the original and transformed complete image.

`PngWriteMetadata.addUnknownChunk` accepts a public copy-owned
`PngUnknownChunk`. Locations map to the frozen upstream write regions:

- `AfterIhdr`: immediately after IHDR and before known pre-PLTE metadata
- `AfterPlte`: after known pre-IDAT metadata and PLTE when present
- `AfterIdat`: after known trailing metadata and before IEND

The default `WriteUnknownSafeToCopy` policy emits chunks whose fourth type byte
has the PNG safe-to-copy bit. `WriteUnknownAncillary` emits all ancillary
unknown chunks, and `WriteUnknownAll` also permits critical unknown chunks.
Configured chunks are validated before output for four ASCII letters, an
uppercase reserved bit, non-collision with every recognized core/standard
metadata type, and 31-bit payload size. Policy-filtered chunks still receive
those structural checks but are not emitted; emitted chunks also consume the
metadata and final-output budgets.

```cangjie
let metadata = PngWriteMetadata()
metadata.setUnknownChunkPolicy(WriteUnknownAncillary)
metadata.addUnknownChunk(PngUnknownChunk(
    [UInt8(0x76), UInt8(0x70), UInt8(0x41), UInt8(0x67)],
    [UInt8(1), UInt8(2), UInt8(3)], AfterIhdr
))
```

`PngWriteMetadata(readMetadata, colorType)` copies retained unknown chunks and
selects `WriteUnknownAll` so an explicitly retained decode-write-decode flow
does not silently discard them. Memory output and custom sinks use the same
framed chunk plan.

`PngWriteMetadata` emits typed tRNS, gAMA, cHRM, sRGB, sBIT, bKGD, pHYs,
iCCP, tEXt/zTXt/iTXt, tIME, cICP, cLLI, mDCV, eXIf, hIST, oFFs, pCAL,
sCAL, and ordered sPLT chunks. The writer freezes the upstream pre-PLTE,
post-PLTE/pre-IDAT, and post-IDAT ordering. Text, tIME, and eXIf support legal
before/after-IDAT placement. `PngWriteMetadata(readMetadata, colorType)` copies
the standard read model into canonical pre-IDAT write placement for
decode-write-decode workflows.

Raw C callback trampolines, simplified `png_image_write_*`, and full C ABI
write parity remain later work.
ICC support retains and emits profile bytes; it does not perform ICC pixel
conversion.

## Adam7 Whole-Image Decode

Use the generic entry points when input may be either non-interlaced or Adam7:

```cangjie
let packed = decodePng(bytes)
let rgba8 = decodePngRgba8(bytes)
let rgba16 = decodePngRgba16(bytes)
```

Their limits and unknown-chunk overloads mirror the existing whole-image read
surface. `decodePngRgba8` also keeps the explicit `Png16To8Mode` overloads for
16-bit source reduction.

Adam7 input is reconstructed from the frozen seven-pass start/step geometry.
Each non-empty pass has independent PNG filter history; packed 1/2/4-bit
samples and 8/16-bit channel bytes are scattered into canonical full-width
rows before the existing metadata and transform pipeline runs. Returned rows
and metadata retain the same copy-ownership contract as non-interlaced input.

The explicit `decodePngNonInterlaced`, `decodePngRgba8NonInterlaced`, and
`decodePngRgba16NonInterlaced` families remain available and still reject
Adam7 input with `UnsupportedInterlace`. Progressive pass delivery is described
below; pass-aware user-transform execution remains separate.

## Incremental Progressive Feed

`PngProgressiveReader` accepts arbitrary input splits, parses chunks and CRCs
incrementally, and streams IDAT data through a bounded zlib state:

```cangjie
let reader = PngProgressiveReader()
reader.setInfoCallback({ ihdr, metadata => /* inspect header and metadata */ })
reader.setRowCallback({ context, row => /* consume an owned packed row */ })
reader.setEndCallback({ ihdr, metadata => /* completed */ })

reader.feed(firstChunk)
reader.feed(secondChunk)
let decoded = reader.finish()
```

Info is delivered when the first IDAT header makes the pre-IDAT contract
complete. Non-interlaced rows are delivered as soon as each filter byte and
row payload is inflated. Adam7 callbacks expose `passNumber`,
`passRowNumber`, and `imageRowNumber`; callback rows are owned canonical rows
after applying the current pass through `pngProgressiveCombineRow`.

The reader exposes `state()`, `receivedBytes()`, `processedBytes()`, and
`lastUnconsumedBytes()`.
Constructors accept `PngReadLimits` and an optional total progressive-input
limit; the default is `PNG_DEFAULT_MAX_PROGRESSIVE_INPUT_BYTES`. Unknown-chunk
and CRC actions are configured before the first feed. Callback registration is
replaceable while state is Open or Paused and no callback is active.

For explicit pause accounting, use `feedAvailable`. A callback may call
`pause()`, after which the returned count identifies the consumed input prefix:

```cangjie
let consumed = reader.feedAvailable(bytes)
if (reader.state() == ProgressivePaused) {
    reader.resume()
    reader.feed(copyByteRange(bytes, consumed, bytes.size - consumed))
}
```

The compatibility `feed` entry retains any unprocessed suffix internally when
a callback pauses; `resume()` continues that suffix without duplicate parsing,
CRC mutation, inflate, or callback delivery.

Info executes before rows, End executes after the final row, and any decode or
callback exception moves the reader to Failed. Feed after completion, repeated
finish, and callback/configuration changes outside Open are rejected; Close
releases buffered input and permanently selects Closed.

For non-interlaced input, row context reports pass `0` and the image row.
Adam7 reports exact passes `0..6`, pass-local and image row numbers,
`passRowPresent = true`, and `canonicalCombined = true`. An empty pass row is a
copy-owned no-op for `pngProgressiveCombineRow`, matching the nullable-row role
of upstream progressive combination without exposing borrowed native memory.
Custom IO and C ABI callback trampolines remain outside this surface.

## Standard Ancillary Metadata

`PngReadMetadata` exposes immutable presence/value pairs for coding-independent
code points, content light level, mastering-display color volume, image offset,
pixel calibration, and physical scale. `exif()` and `histogram()` return owned
copies. Suggested palettes are available through `suggestedPaletteCount()`,
`suggestedPalette(index)`, and `suggestedPalettes()`; palette names and pCAL or
sCAL byte strings are copy-owned at their accessors.

The native decoder recognizes cICP, cLLI, and mDCV before PLTE/IDAT; hIST after
PLTE and before IDAT; oFFs, pCAL, sCAL, and sPLT before IDAT; and eXIf on either
side of IDAT. Single-instance chunks reject duplicates, while multiple sPLT
chunks are retained in file order. These values do not alter pixel data.

iCCP profile retention remains separate. libpng validates and stores ICC
profiles but does not perform ICC pixel color conversion, and libpng4cj makes
the same boundary explicit.

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

## cHRM RGB To Gray Initialization

When RGB-to-gray is enabled with default or rejected coefficients,
`initializePngReadTransformations` resolves retained cHRM chromaticities into
red, green, and blue Y coefficients on libpng's `32768` scale. Accepted
explicit setter coefficients always win. An sRGB chunk, absent cHRM data, or
unusable chromaticities keep the historical `6968`, `23434`, and `2366`
coefficients.

The resolved `PngRgbToGrayTransform` is copy-frozen in
`PngReadTransformInitialization` and is used by direct initialized row and
whole-image execution. The source metadata remains unchanged.

## Background-Aware Gray To RGB Dispatch

`PngReadTransformInitialization.backgroundIsGray()` exposes the frozen
background classification used by Gray-to-RGB dispatch.
`grayToRgbAfterExpand16()` is true when Gray-to-RGB runs after Compose and
Expand16; otherwise the selected stage runs before Compose.

Background Expand on grayscale-family input is gray by definition. For normal
Compose, equal red/green/blue values are treated as gray and the effective
background gray component is synchronized from red. The initialized pipeline
therefore applies exactly one Gray-to-RGB stage and preserves the upstream
composition order for gray and non-gray backgrounds.

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

When Background Expand and Expand are selected without tRNS-to-alpha expansion,
`InvertAlpha` is consumed against a copy-owned effective palette-alpha prefix
before palette composition. The source tRNS metadata is unchanged. Ordinary
Expand-tRNS keeps the original prefix in the initialization snapshot so alpha
inversion remains a row-stage concern.

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

## Quantize Allocation Retry Diagnostic

The ordinary `PngReadTransformState.setQuantize` overloads retain histogram
reduction, no-histogram closest-pair reduction, 256-entry Indexed remapping,
and full-color 5-bit RGB lookup generation.

The quantize-specific diagnostic overload accepts a final
`PngQuantizeAllocationFaultPlan`:

```cangjie
state.setQuantize(
    palette,
    numPalette,
    maximumColors,
    fullQuantize,
    PngQuantizeAllocationFaultPlan(
        successfulPairAllocationsBeforeFailure,
        failureCount,
        maximumRetries
    )
)
```

When a planned pair-node admission fails, the partially built distance buckets
are discarded before palette or remap mutation. The closest-pair pass expands
its distance window and retries from unchanged working state. A recovered
setter exposes `quantizeAllocationWarningCount()` and
`quantizeAllocationRetryCount()`; a later ordinary successful setter resets
both values.

If the bounded retry limit is exhausted, `PngFormatException` reports
`ALLOCATION_FAILURE` and the previous accepted quantize state remains intact.
This is deterministic translation and fault-injection evidence for the
upstream `png_malloc_warn` branch. It is not a generic allocator surface or a
claim that the managed runtime can recover from actual process OOM.

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

The no-argument `setReadUserTransform()` form explicitly enables the same
stage with identity execution. This mirrors a registered null read callback:
the stage remains active and configured depth/channel overrides still apply.

The callback receives a copy-owned row and immutable row/pass context. It
returns copy-owned row information and bytes. Initialized execution runs the
callback after `BYTE_SWAP`; configured nonzero values from
`setUserTransformInfo(depth, channels)` then override the callback-returned
depth/channels, and the final row length must match the recomputed row bytes.

`projectPngReadTransformInfo` applies the same configured nonzero
depth/channels only when user-transform registration is active. Callback
enablement and replacement remain live after initialization, including
replacement with identity execution; unrelated initialized transform state is
not rebuilt. The current whole-image non-interlaced path reports zero-based row
numbers and pass `0`.

The completed read-info projection also exposes `transparencyCount`,
`hasBackground`, `background()`, `hasGamma`, and `gamma`. The transparency
count preserves palette tRNS prefix length or the single Gray/RGB color key
until Expand or Strip Alpha consumes it. Effective Compose background replaces
retained bKGD only while Compose remains active; otherwise source bKGD is
preserved. `gamma` is the initialized fixed-point file Gamma, including the
identity fallback, while `hasGamma` records retained or explicitly configured
Gamma provenance. Plain filler changes only projected channels; Add Alpha also
changes the projected color type.

The current surface is Cangjie-native. C ABI callback trampolines, raw
`user_transform_ptr` storage, write user transforms, and progressive/Adam7 pass
execution remain open.

## Read CRC Actions

`PngCrcAction` preserves the six upstream values as `CrcDefault`,
`CrcErrorQuit`, `CrcWarnDiscard`, `CrcWarnUse`, `CrcQuietUse`, and
`CrcNoChange`. Their `ordinalValue()` results are the frozen `0..5` values.

`PngReadSession.setCrcAction(criticalAction, ancillaryAction)` replaces the two
policies independently. New sessions default to critical error/quit and
ancillary warn/discard. `CrcNoChange` keeps the current value; critical
`CrcWarnDiscard` is invalid and records a warning fact before selecting
error/quit.

When corrupt data is accepted, `PngChunk.crcValid` is `false`. The session
exposes `crcWarningCount()`, `crcQuietUseCount()`, `crcDiscardCount()`, and
`invalidCriticalDiscardWarning()`. These are native diagnostic facts, not a
warning/error callback contract.

The high-level overload is:

```cangjie
decodePngNonInterlaced(
    bytes,
    criticalCrcAction,
    ancillaryCrcAction
)
```

The full limits/unknown-chunk overload accepts both actions after
`unknownPolicy`. Existing overloads preserve the default policy. Frame length,
chunk type, configured size, and IHDR ordering remain mandatory even when a CRC
mismatch would otherwise be used or discarded.
