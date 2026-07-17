# pngrtran.c Translation Ledger

Frozen source: `vendor/libpng-1.6.58/pngrtran.c` at upstream commit
`3061454d980de7d53608f594194cfac722721d2a`.

Regenerate the exact top-level function inventory with:

```sh
sh ./tools/update-pngrtran-inventory.sh
```

The generated file is
`doc/upstream/libpng-1.6.58-pngrtran-functions.tsv`. The generator asserts the
frozen count of 45 functions, so upstream/source drift fails visibly.

Status meanings:

- `translated`: the bounded non-gamma behavior is present under a traceable
  Cangjie anchor and covered by tests
- `partial`: useful behavior exists, but upstream state/configuration or one or
  more branches are still missing
- `pending`: no honest translated body exists yet

| Line | Upstream function | Cangjie anchor | Status | Remaining dependency |
| ---: | --- | --- | --- | --- |
| 41 | `png_set_crc_action` | chunk CRC policy | partial | configurable critical/ancillary actions |
| 115 | `png_rtran_ok` | `PngReadTransformState.pngRtranOk` | translated | application error callback emission deferred |
| 142 | `png_set_background_fixed` | `PngReadTransformState.setBackgroundFixed` | translated | warning callback emission and C ABI deferred |
| 172 | `png_set_background` | `PngReadTransformState.setBackground` | translated | C ABI floating setter wrapper deferred |
| 188 | `png_set_scale_16` | `PngReadTransformState.setScale16` | translated | direct C ABI setter deferred |
| 202 | `png_set_strip_16` | `PngReadTransformState.setStrip16` | translated | direct C ABI setter deferred |
| 215 | `png_set_strip_alpha` | `PngReadTransformState.setStripAlpha` | translated | direct C ABI setter deferred |
| 361 | `png_set_alpha_mode_fixed` | `PngReadTransformState.setAlphaModeFixed` | translated | four modes, default/screen Gamma, black Compose background, Encode/Optimize flags, conflict and initialization snapshots translated; C ABI integer mode/error callback deferred |
| 461 | `png_set_alpha_mode` | `PngReadTransformState.setAlphaMode` | translated | floating conversion delegates to fixed state; C ABI wrapper deferred |
| 489 | `png_set_quantize` | `PngReadTransformState.setQuantize` | partial | normal lifecycle, both reduction branches, remap, and full lookup translated; allocation-warning fallback, dispatcher, and C ABI deferred |
| 892 | `png_set_gamma_fixed` | `PngReadTransformState.setGammaFixed` | translated | callback delivery, C ABI, and tables deferred; initialization snapshot connected |
| 934 | `png_set_gamma` | `PngReadTransformState.setGamma` | translated | callback delivery and C ABI wrapper deferred |
| 948 | `png_set_expand` | `PngReadTransformState.setExpand` | translated | transformed IHDR projection deferred |
| 978 | `png_set_palette_to_rgb` | `PngReadTransformState.setPaletteToRgb` | translated | transformed IHDR projection deferred |
| 990 | `png_set_expand_gray_1_2_4_to_8` | `PngReadTransformState.setExpandGrayOneTwoFourToEight` | translated | transformed IHDR projection deferred |
| 1002 | `png_set_tRNS_to_alpha` | `PngReadTransformState.setTransparencyToAlpha` | translated | transformed IHDR projection deferred |
| 1018 | `png_set_expand_16` | `PngReadTransformState.setExpand16` | translated | direct C ABI setter deferred |
| 1031 | `png_set_gray_to_rgb` | `PngReadTransformState.setGrayToRgb` | translated | direct C ABI setter and transformed-info projection deferred |
| 1046 | `png_set_rgb_to_gray_fixed` | `PngReadTransformState.setRgbToGrayFixed` | translated | warning callback emission deferred |
| 1118 | `png_set_rgb_to_gray` | `PngReadTransformState.setRgbToGray` | translated | C ABI floating setter wrapper deferred |
| 1132 | `png_set_read_user_transform_fn` | `PngReadTransformState.setReadUserTransform` | partial | native callback, info projection, and final row hook translated; null/late mutation and C ABI trampoline deferred |
| 1151 | `png_gamma_threshold` | `pngGammaThreshold` | translated | setter/state/initialization connected; table integration deferred |
| 1176 | `png_init_palette_transformations` | `pngInitPaletteTransformations`, `pngInitEffectivePaletteAlpha`, and `pngInitPaletteBackgroundTransformations` | translated | alpha/transparency classification, no-alpha/binary cancellation, palette-index background expansion, copy-owned tRNS inversion, direct/linear Gamma composition, optimized partial-alpha premultiplication, and Compose/Gamma cancellation translated |
| 1265 | `png_init_rgb_transformations` | `pngInitRgbTransformations` | translated | inherent-alpha/tRNS classification, no-alpha Compose/background cancellation, effective Optimize/Encode cancellation, and sub-byte gray background expansion translated |
| 1351 | `png_resolve_file_gamma` | `pngResolveFileGamma` | translated | configured/chunk sources feed initialization; in-place C state and C ABI deferred |
| 1387 | `png_init_gamma_values` | `pngInitGammaValues` | translated | immutable read initialization consumes it; in-place C state and C ABI deferred |
| 1424 | `png_init_read_transformations` | `initializePngReadTransformations` | partial | effective background cancellation/expansion, alpha-mode/default/screen Gamma facts, effective Encode/Optimize cancellation, Expand16/16-to-8 normalization, Screen/File/Unique gamma snapshots, non-palette Compose/Encode stages, Indexed PLTE/tRNS preprocessing, quantize, packing, packswap, and native user-transform are snapshotted; coefficient defaulting and complete dispatcher state remain |
| 2069 | `png_read_transform_info` | `projectPngReadTransformInfo` | partial | non-gamma topology, effective palette/background synchronization, quantize palette sync, packing depth, and configured user-transform depth/channels are projected; filler and full metadata projection remain |
| 2292 | `png_do_unpack` | `pngDoUnpack` | translated | initialized packing dispatch and following palette-index diagnosis are connected; C ABI and complete dispatcher remain partial |
| 2390 | `png_do_unshift` | `pngDoUnshift` | translated | selected adapter is narrow; palette init mutation and complete dispatcher remain partial |
| 2529 | `png_do_scale_16_to_8` | `pngDoScale16To8` | translated | initialized adapter is narrow; complete dispatcher remains partial |
| 2590 | `png_do_chop` | `pngDoChop` | translated | initialized adapter is narrow; complete dispatcher remains partial |
| 2615 | `png_do_read_swap_alpha` | `pngDoReadSwapAlpha` | translated | selected adapter is narrow; setter state and complete dispatcher remain partial |
| 2711 | `png_do_read_invert_alpha` | `pngDoReadInvertAlpha` | translated | selected adapter is narrow; setter state and complete dispatcher remain partial |
| 2813 | `png_do_read_filler` | `pngDoReadFiller` | translated | selected adapter is narrow; setter state and transformed-info color-type projection remain partial |
| 3000 | `png_do_gray_to_rgb` | `pngDoGrayToRgb` | translated | initialized stage adapter is narrow; complete dispatcher remains partial |
| 3139 | `png_do_rgb_to_gray` | `pngDoRgbToGray` plus fixed and initialized gamma-aware 8/16-bit cores | translated | complete frozen row arithmetic covered; warning/error callback delivery remains outside this row helper |
| 3340 | `png_do_compose` | `pngDoCompose` | translated | complete non-palette packed/8/16-bit Gray/GA/RGB/RGBA tRNS, alpha, direct-gamma, and linear-gamma row body plus initialized ordering translated; palette mutation is owned by initializer rows |
| 4084 | `png_do_gamma` | `pngDoGamma` | translated | packed 2/4-bit, 8-bit, and 16-bit Gray/GA/RGB/RGBA branches plus initialized direct/reduction dispatch translated |
| 4285 | `png_do_encode_alpha` | `pngDoEncodeAlpha` | translated | 8/16-bit GA/RGBA alpha-only from-linear encoding, initialized stage, network order, and whole-image execution translated; C ABI dispatcher deferred |
| 4349 | `png_do_expand_palette` | `pngDoExpandPalette` | translated | palette mutation, SIMD, and complete dispatcher remain partial |
| 4523 | `png_do_expand` | `pngDoExpand` | translated | bounded initialized adapter exists; complete dispatcher remains partial |
| 4753 | `png_do_expand_16` | `pngDoExpand16` | translated | bounded initialized adapter exists; complete dispatcher remains partial |
| 4783 | `png_do_quantize` | `pngDoQuantize` | translated | initialized adapter and projected palette synchronization are bounded; complete dispatcher remains partial |
| 4880 | `png_do_read_transformations` | `applyInitializedPngReadStages` | partial | translated expansion, pre/post-Compose Strip Alpha, RGB/gray, non-palette Compose, Gamma, Encode Alpha, reduction, quantize, and late stages through User Transform have bounded composition; Indexed palette Compose/Gamma is consumed during initialization; C ABI callbacks and remaining dispatcher branches remain |

## Translation Rule

Future LP-S004 packets should select one bounded `pending` or `partial` cluster,
translate the upstream topology and behavior first, prove it against the frozen
oracle, and only then simplify or optimize the Cangjie implementation. A passing
convenience API is evidence for a row operation, not proof that its upstream
setter, state mutation, metadata projection, warning path, or compile guards are
already translated.

LP-S004J keeps the frozen state aliasing intact: `png_set_expand`,
`png_set_palette_to_rgb`, and `png_set_tRNS_to_alpha` all set the same
`PNG_EXPAND | PNG_EXPAND_tRNS` bits in libpng `1.6.58`; the Cangjie state does
not invent distinct persistent flags merely because the public setter names
differ.

LP-S004K adds the first stateful initialization anchor without hiding the
remaining branches. It distinguishes palette partial alpha from binary
transparency, preserves inherent RGB/gray alpha classification, cancels tRNS
expansion when Strip Alpha precedes composition, and freezes the translated
stage order. The three initializer rows remain `partial` until background row
composition/gamma derivation, encode/optimize-alpha, remaining palette mutation,
and full dispatcher state land.

LP-S004L directly translates `png_do_gray_to_rgb` for 8-bit and 16-bit
grayscale/grayscale-alpha rows. `PngReadRowInfo` carries the source-shaped
width, depth, color type, channels, pixel depth, and row-byte topology;
`pngDoGrayToRgb` preserves every gray/alpha byte while returning a copy-owned
expanded row, and `applyInitializedPngGrayToRgbStage` gates that body on the
frozen initialized stage list. This advances the ledger to
`23 translated / 6 partial / 16 pending`; the complete dispatcher remains
partial because preceding expansion/composition and later transforms are not
executed by this narrow adapter.

LP-S004M adds the bounded non-gamma `png_read_transform_info` projection for
the currently translated state. It handles palette/non-palette Expand, tRNS
consumption, Strip Alpha, Scale16/Strip16, Gray-to-RGB, RGB-to-gray, Expand16,
final channels, pixel depth, and row bytes. The projection deliberately follows
the frozen info-function order, where Gray-to-RGB is applied before
RGB-to-gray, instead of iterating runtime row stages. The ledger remains
`23 translated / 6 partial / 16 pending` because palette synchronization,
gamma/background, filler, quantize, pack, user transforms, and complete
metadata projection remain absent.

LP-S004N replaces the convenience-only Scale/Strip anchors with direct
network-byte row bodies. `pngDoScale16To8` applies the exact
`(V * 255 + 32895) >> 16` arithmetic, while `pngDoChop` retains each high byte;
both return copy-owned rows and update bit depth, pixel depth, and row bytes
through `PngReadRowInfo`. `applyInitializedPng16To8Stages` executes Scale before
Strip, so a simultaneous Strip stage becomes a no-op after Scale has already
changed the row to 8-bit depth. The ledger remains
`23 translated / 6 partial / 16 pending`; Expand16 and the complete dispatcher
remain separate work.

LP-S004O replaces the canonical RGBA convenience anchors for alpha inversion
and alpha swapping with direct source-shaped byte-row bodies.
`pngDoReadInvertAlpha` complements only GA/RGBA alpha bytes at 8-bit or 16-bit
network-byte depth. `pngDoReadSwapAlpha` preserves component byte order while
moving GA/RGBA alpha from the last component to the first.
`applySelectedPngAlphaTransforms` reads the existing channel-transform
selection as booleans and always executes Invert Alpha before Swap Alpha,
independent of caller array order or duplicates. The ledger remains
`23 translated / 6 partial / 16 pending`; `pngtrans.c` setter state,
intermediate unshift/BGR/filler stages, and the complete dispatcher remain
separate work.

LP-S004P replaces the generalized row-shape convenience anchor for filler with
the direct source-shaped byte-row body. `PngReadRowInfo` now supports an
explicit transformed channel count, because `png_do_read_filler` increases
channels, pixel depth, and row bytes while retaining the source Gray/RGB color
type. `pngDoReadFiller` preserves 8/16-bit network byte order, uses the low
filler byte or low 16 filler bits, and returns copy-owned GX/XG or RGBX/XRGB
rows. `applyPngReadFillerTransform` maps the existing filler/add-alpha placement
modes onto this row body without claiming preceding Strip Alpha execution or
the separate transformed-info color-type update. The ledger remains
`23 translated / 6 partial / 16 pending`.

LP-S004W adds the bounded `png_set_quantize` state floor after the direct
`png_do_quantize` row body landed in LP-S004V. `PngQuantizeMode` records
palette-remap versus full-color intent, accepted calls retain copy-owned palette
state, and every non-full call rebuilds the complete 256-entry identity remap
required by the frozen safety fix. Palette reduction, histogram/median-cut,
full 32768-entry lookup generation, initialized dispatch, transformed-info
projection, and C ABI remain open. The current ledger is
`24 translated / 7 partial / 14 pending`.

LP-S004X materializes the no-reduction full-color lookup requested by that
state. `pngBuildQuantizePaletteLookup` translates all 32768 5/5/5 cells, the
frozen `dmax + dr + dg + db` distance formula, and strict-smaller updates that
retain the first palette entry on ties. Full lookups are copy-owned, replaceable,
and cleared when a later non-full call installs its 256-entry identity remap.
Palette reduction, histogram/median-cut, initialized dispatch, transformed-info
projection, and C ABI remain open, so the ledger remains
`24 translated / 7 partial / 14 pending`.

LP-S004Y translates the histogram-backed reduction branch for both full and
non-full modes. The implementation preserves descending bubble-sort selection,
equal-frequency order, full palette relocation, non-full swap/remap updates,
and first-closest Manhattan RGB mapping for discarded colors. Palette and
histogram inputs remain caller-owned through an internal palette clone. The
no-histogram closest-pair/median-cut branch, initialized dispatch,
transformed-info projection, and C ABI remain open, so the ledger remains
`24 translated / 7 partial / 14 pending`.

LP-S004Z translates the successful-allocation path of the no-histogram
closest-pair branch. It preserves 96-step distance windows, reverse bucket pair
order, stale-pair rejection, odd/even elimination, last-slot compaction,
bidirectional identity maps, and non-full remap updates before map mutation.
Full mode builds the reduced lookup from the same compacted palette. Native
allocation-warning fallback, initialized dispatch, transformed-info projection,
and C ABI remain open, so the ledger remains
`24 translated / 7 partial / 14 pending`.

LP-S004AA snapshots quantize mode plus lookup/remap tables during one-shot read
initialization and places the direct row body after Strip16 and before Expand16.
The adapter remains bounded and copy-owned; complete dispatch and projected
palette synchronization remain open, so the ledger remains
`24 translated / 7 partial / 14 pending`.

LP-S004AB snapshots the active quantize palette/count and synchronizes a
copy-owned projected PLTE. The transformed-info branch preserves source PLTE
when quantize is disabled and changes only 8-bit RGB/RGBA with a materialized
full lookup to Indexed, after RGB/gray projection and before Expand16. Source
metadata stays immutable, and Indexed output blocks Expand16. Gamma/background,
filler, pack, user-transform, complete metadata projection, complete dispatch,
native allocation-warning fallback, and C ABI remain open, so the ledger stays
`24 translated / 7 partial / 14 pending`.

LP-S004AC adds `applyInitializedPngExpand16Stage` over the direct row body.
Disabled stages remain validated copy-owned no-ops; Scale/Strip output expands
back to network-order 16-bit pairs, while preceding Quantize produces Indexed
rows that correctly block Expand16. The adapter proves the local frozen order
without claiming automatic execution of preceding transforms or the complete
dispatcher, so the ledger remains `24 translated / 7 partial / 14 pending`.

LP-S004AD snapshots the retained payload required by `ReadStageExpand` and
connects both direct expansion bodies through `applyInitializedPngExpandStage`.
Indexed rows receive a copy-owned PLTE plus only the effective palette-alpha
prefix that survives Strip Alpha; non-Indexed rows receive immutable Gray/RGB
color-key state. The adapter preserves the frozen shared transform bits behind
`png_set_palette_to_rgb`, validates disabled no-op rows, and leaves source
metadata isolated. It does not execute adjacent stages or complete the stateful
dispatcher, so the ledger remains `24 translated / 7 partial / 14 pending`.

LP-S004AE translates the `pngtrans.c::png_do_strip_channel` dependency for
8/16-bit two- and four-channel rows, including first/last component removal,
network-byte preservation, alpha color-type updates, row-info shrinkage,
copy-owned no-ops, and malformed-row priority. The initialized Strip Alpha
adapter uses last-channel removal after initialization has already suppressed
effective tRNS expansion. This advances dependency coverage but not the
45-function `pngrtran.c` inventory count, so the ledger remains
`24 translated / 7 partial / 14 pending`.

LP-S004AF snapshots fixed RGB-to-gray configuration and adds the source-shaped
`pngDoRgbToGray` adapter for 8/16-bit RGB/RGBA rows. The combined
`applyInitializedPngReadStages` entry executes Expand, Strip Alpha,
RGB-to-gray, Gray-to-RGB, Scale/Strip16, Quantize, and Expand16 in frozen order;
`transformPngRowsInitialized` applies the same initialization to a decoded
non-interlaced image with transformed-byte limiting and aggregate nongray
status. This widens the bounded `png_do_read_transformations` anchor without
changing the inventory totals, which remain
`24 translated / 7 partial / 14 pending`.

LP-S004AG snapshots the existing Invert Alpha, significant-bit Unshift,
Filler/Add Alpha, and Swap Alpha state and connects those translated row bodies
after Expand16 in the combined initialized pipeline. The adapter preserves
8/16-bit network-byte rows, exact filler growth, semantic added-alpha versus
plain-filler behavior, disabled/unsupported copy ownership, malformed-row
priority, and whole-image transformed-byte limits. This advances the bounded
`png_do_read_transformations` dispatcher anchor without adding new top-level
`pngrtran.c` functions, so the ledger remains
`24 translated / 7 partial / 14 pending`.

LP-S004AH translates the shared `pngtrans.c::png_do_bgr` row body for natural
RGB/RGBA 8-bit and network-order 16-bit rows, preserving row information,
copy ownership, unsupported no-op behavior, and malformed-row priority. It adds
lifecycle-gated `setBgr()` state, snapshots that state during one-shot read
initialization, and places BGR after Unshift and before Filler in both row and
whole-image initialized execution. This advances the bounded
`png_do_read_transformations` dispatcher anchor without adding a top-level
`pngrtran.c` inventory function, so the ledger remains
`24 translated / 7 partial / 14 pending`.

LP-S004AI translates the shared `pngtrans.c::png_do_invert` body for packed,
8-bit, and network-order 16-bit Grayscale rows plus GA8/GA16 gray components.
It preserves packed padding inversion, alpha bytes, row information, copy-owned
no-op behavior, and malformed-row priority. Lifecycle-gated `setInvertMono()`
state is snapshotted and placed before Invert Alpha and Unshift in row and
whole-image initialized execution. This advances the bounded dispatcher anchor
without adding a top-level `pngrtran.c` inventory function, so the ledger
remains `24 translated / 7 partial / 14 pending`.

LP-S004AJ translates read-side `pngtrans.c::png_set_packing` state and connects
the existing direct `pngDoUnpack` body after Unshift and before BGR. The setter
requires a known IHDR, enables only for source bit depths below 8, and is copied
into the immutable one-shot initialization snapshot. Initialized Gray and
Indexed 1/2/4-bit rows grow to one byte per stored sample with exact row-info
projection, copy-owned disabled/unsupported behavior, malformed-row priority,
and whole-image transformed-byte limiting. This widens the bounded dispatcher
and transformed-info anchors without adding a top-level `pngrtran.c` function,
so the ledger remains `24 translated / 7 partial / 14 pending`.

LP-S004AK translates read-side `pngtrans.c::png_set_packswap` state plus the
shared `png_do_packswap` body. The direct row transform reverses 1-bit values,
2-bit groups, or 4-bit nibbles in every stored byte, including final padding
bits, without changing row information. The immutable initialized stage is
placed after BGR and before Filler. When Packing runs first, Unpack raises the
row depth to 8 and PackSwap becomes a validated copy-owned no-op, matching the
frozen dispatcher order. These anchors live in `pngtrans.c`, not the generated
45-function `pngrtran.c` inventory, so the ledger remains
`24 translated / 7 partial / 14 pending`.

LP-S004AL translates read-side `pngtrans.c::png_set_swap` state plus the shared
`png_do_swap` body. The direct transform exchanges every adjacent byte pair in
16-bit rows without changing row information. Immutable initialized execution
places Byte Swap after Filler and Swap Alpha and before the eventual user
transform. Earlier Scale16/Strip16 output is 8-bit, so Byte Swap becomes a
validated copy-owned no-op in those combinations. These anchors live in
`pngtrans.c`, not the generated 45-function `pngrtran.c` inventory, so the
ledger remains `24 translated / 7 partial / 14 pending`.

LP-S004AM translates `pngset.c::png_set_check_for_invalid_index` state plus the
shared `pngtrans.c::png_do_check_palette_indexes` body. Default-enabled state is
snapshotted with retained PLTE count, and direct 1/2/4/8-bit Indexed scanning
updates only an accumulated maximum while excluding final-byte padding. The
bounded dispatcher places the diagnostic after Unpack and before BGR, and row
plus whole-image results expose whether the maximum exceeds the retained PLTE.
The setter/body live outside the generated 45-function `pngrtran.c` inventory,
so the ledger remains `24 translated / 7 partial / 14 pending`.

LP-S004AN adds native Cangjie read user-transform registration, byte-sized
depth/channel info, transformed-info projection, row/pass context, and the
final initialized stage after Byte Swap. Callback input/output is copy-owned,
configured nonzero depth/channels override callback-returned row information,
and exact final row bytes are validated before acceptance. The frozen top-level
setter moves from pending to partial because null callback semantics, late
mutation, raw user pointers, and the C ABI trampoline remain open. The current
ledger is `24 translated / 8 partial / 13 pending`.

LP-S004AO translates the floating-point `png_set_rgb_to_gray` facade and its
`png_fixed` dependency. `pngFixedFromFloat64` applies exact
`floor(100000 * value + 0.5)` conversion, rejects non-finite and signed-32-bit
overflow values before mutation, and delegates accepted fixed values into the
existing lifecycle-gated `setRgbToGrayFixed` path. The direct C ABI wrapper and
warning callback delivery remain separate, while the ledger advances to
`25 translated / 8 partial / 12 pending`.

LP-S004AP translates the frozen-default floating-arithmetic branch of
`png_muldiv`, the shared `png_gamma_significant` predicate, and direct
`png_gamma_threshold`. The fixed substrate preserves nearest rounding,
divide-by-zero and signed-32-bit overflow failure, strict
`100000 +/- 5000` significance boundaries, and the upstream rule that failed
multiplication forces gamma correction. Gamma setters, file-gamma resolution,
tables, and row correction remain separate, while the ledger advances to
`26 translated / 8 partial / 11 pending`.

LP-S004AQ translates `png_reciprocal` through the accepted fixed
multiply/divide substrate and adds immutable `pngResolveFileGamma` precedence.
The first nonzero explicit file, chunk, or default gamma wins; otherwise a
nonzero screen gamma is reciprocated, with zero or reciprocal failure returning
zero. Mutable read-state integration, gamma initialization, tables, and row
correction remain separate, while the ledger advances to
`27 translated / 8 partial / 10 pending`.

LP-S004AR translates `png_init_gamma_values` as immutable
`pngInitGammaValues`. Positive resolved file and screen gamma values use the
accepted threshold helper; a positive file with absent/nonpositive screen gamma
uses the exact reciprocal; a nonpositive resolved file resets both values to
`PNG_FP_1`. Mutable read-state integration, tables, and row correction remain
separate, while the ledger advances to
`28 translated / 8 partial / 9 pending`.

LP-S004AS translates gamma flag aliases, the inclusive supported range, and
`png_set_gamma_fixed` as lifecycle-gated `PngReadTransformState.setGammaFixed`.
Accepted calls store translated file/screen values; invalid nonpositive inputs
record application-error facts, unsupported values record a warning fact, and
failed calls preserve prior state. Floating conversion, callback delivery,
initialization snapshot, tables, and row correction remain separate, while the
ledger advances to `29 translated / 8 partial / 8 pending`.

LP-S004AT translates `convert_gamma_value` and floating `png_set_gamma` as
`pngConvertGammaValue` plus `PngReadTransformState.setGamma`. Positive values
below 128 are scaled by `PNG_FP_1`; other finite values remain fixed/flag-shaped
before nearest rounding. Nonfinite and signed-32-bit overflow fail before state
mutation, and accepted values delegate into the AS fixed setter. Initialization
snapshot, tables, row correction, callbacks, and C ABI remain separate, while
the ledger advances to `30 translated / 8 partial / 7 pending`.

LP-S004AU connects configured file/screen gamma state and retained gAMA chunk
gamma to `initializePngReadTransformations`. The initializer constructs one
immutable `PngFileGammaSources`, applies the translated precedence and fallback
through `pngInitGammaValues`, and exposes resolved values plus correction status
without adding an executable Gamma row stage. Rejected setter state falls back
to chunk/default behavior, explicit file gamma wins over gAMA, and the snapshot
is isolated from post-initialization mutation. Gamma tables, row correction,
background/alpha mode, palette mutation, callbacks, and C ABI remain separate,
so the ledger remains `30 translated / 8 partial / 7 pending`.

LP-S004AV translates the frozen floating-arithmetic
`png_gamma_8bit_correct` helper and result-equivalent `png_build_8bit_table`
substrate from `png.c`. Exact endpoints, nearest `pow` rounding, identity
filling, significant table generation, exhaustive table/scalar equivalence,
monotonicity, and copy ownership are covered. These helpers are outside the
generated 45-function `pngrtran.c` inventory; initialization attachment,
16-bit tables, and `png_do_gamma` remain separate, so the ledger remains
`30 translated / 8 partial / 7 pending`.

LP-S004AW translates frozen `png_reciprocal2` plus the 8-bit branch of
`png_build_gamma_table` and attaches direct/to-linear/from-linear table
snapshots to immutable read initialization. Tables are built only for required
file-to-screen correction or linear RGB-to-gray work, and all row-stage
ordinals remain unchanged. These helpers remain outside the generated
45-function `pngrtran.c` inventory; executable `png_do_gamma`, gamma-aware
RGB-to-gray row arithmetic, and 16-bit tables remain separate, so the ledger
remains `30 translated / 8 partial / 7 pending`.

LP-S004AX translates packed 2/4-bit and 8-bit `png_do_gamma` row execution,
including alpha preservation, 1-bit/palette/16-bit bounded no-ops, initialized
direct-table gating, whole-image execution, and stable prior stage identities.
The inventoried `png_do_gamma` row advances from pending to partial; 16-bit
segmented-table branches and gamma-aware RGB-to-gray remain separate. The
ledger advances to `30 translated / 9 partial / 6 pending`.

LP-S004AY translates frozen `png_gamma_16bit_correct` and
`png_build_16bit_table` helpers from `png.c`. The immutable Cangjie table keeps
the exact shift `0..8` segmented topology, significant direct scaling,
insignificant identity scaling, deep-copy ownership, and selected exhaustive
equivalence proofs. These helpers are outside the generated 45-function
`pngrtran.c` inventory; 16-to-8 specialization, initialized attachment,
16-bit `png_do_gamma`, and gamma-aware RGB-to-gray remain separate, so the
ledger remains `30 translated / 9 partial / 6 pending`.

LP-S004AZ translates frozen `png_build_16to8_table`, gamma-shift selection,
and the 16-bit branch of `png_build_gamma_table` from `png.c`. Immutable read
initialization now retains sBIT/reduction-aware direct or 16-to-8 tables plus
optional to-linear/from-linear tables without enabling 16-bit row execution.
These helpers remain outside the generated inventory; `png_do_gamma` stays
partial until its 16-bit branches land, so the ledger remains
`30 translated / 9 partial / 6 pending`.

LP-S004BA completes 16-bit Gray/GA/RGB/RGBA `png_do_gamma` execution through
the initialized segmented direct or 16-to-8-specialized table. Network order,
alpha preservation, Gamma-before-reduction order, whole-image behavior, and
consumer use are covered. The inventoried row advances from partial to
translated, so the ledger advances to
`31 translated / 8 partial / 6 pending`.

LP-S004BB completes the frozen gamma-table branches of `png_do_rgb_to_gray` for
8/16-bit RGB and RGBA rows. Initialized execution compares original samples,
uses to-linear tables for unequal RGB, applies the rounded fixed coefficients,
maps through from-linear tables, uses direct correction for equal RGB, and
preserves alpha plus PNG network order. Direct-row, strict-policy, whole-image,
ownership, malformed-row, and consumer proof are covered. The inventoried row
was already translated, so the ledger remains
`31 translated / 8 partial / 6 pending`.

LP-S004BC translates `png_set_background_fixed` and its floating facade into
`PngReadTransformState`. The state retains a copy-owned `PngBackground`, frozen
gamma code/value, background expansion, Compose plus Strip Alpha selection,
Encode Alpha/Optimize Alpha cancellation, unknown-gamma diagnosis, lifecycle
gating, repeated replacement, and prior-state stability. Initialization and
`png_do_compose` remain separate. Two inventoried setters advance from pending
to translated, so the ledger advances to
`33 translated / 8 partial / 4 pending`.

LP-S004BD snapshots that accepted state through the still-partial palette, RGB,
and read initializers. Opaque/no-transparency inputs cancel effective Compose
and Background Expand; palette binary/partial transparency, color-key tRNS, and
inherent alpha retain Compose. Requested palette-index and 1/2/4-bit grayscale
background expansion is frozen into copy-owned initialization state, and Strip
Alpha remains after effective Compose. `png_do_compose`, background gamma-table
derivation, alpha-mode setters, and remaining initializer branches stay open,
so the ledger remains `33 translated / 8 partial / 4 pending`.

LP-S004BE continues those initializer rows through non-palette Compose
preparation. It snapshots exact Expand16/16-to-8 background normalization,
original/linear/screen colors, Screen/File/Unique `g` and `gs`, effective Screen
gamma identity, and Compose-driven 8/16-bit linear tables. Palette inputs build
the required tables but intentionally retain PLTE unchanged. `png_do_compose`,
palette composition/mutation, alpha-mode setters, and remaining initializer
branches stay open, so the ledger remains
`33 translated / 8 partial / 4 pending`.

LP-S004BF translates the complete row-local `png_do_compose` body into
`pngDoCompose`. It covers packed 1/2/4-bit grayscale color-key replacement,
2/4-bit direct Gamma for surviving samples, 8/16-bit Gray/RGB tRNS replacement,
8/16-bit GA/RGBA alpha composition with frozen no-division rounding, direct
correction for opaque samples, to-linear/composite/from-linear correction for
partial alpha, transparent screen backgrounds, preserved alpha bytes, and
network-order UInt16 rows. Initialized execution now places Compose before the
separate Gamma decision and post-Compose Strip Alpha, suppressing duplicate
Gamma when Compose owns alpha/tRNS work. Palette mutation remains in the
still-partial initializer rows, so `png_do_compose` advances from pending to
translated and the ledger becomes
`34 translated / 8 partial / 3 pending`.

LP-S004BG translates the frozen Indexed PLTE/tRNS preprocessing branches across
`png_init_palette_transformations` and `png_init_read_transformations`.
Initialization snapshots a copy-owned effective palette and alpha prefix,
composes transparent and partial-alpha entries in encoded or linear space,
directly corrects opaque and Gamma-only entries, derives 8-bit
Screen/File/Unique backgrounds, and cancels row Compose/Gamma after palette
work is consumed. Gamma-only preprocessing is withheld for expanded
RGB-to-gray so that stage owns linearization once. Expand uses the effective
palette before Strip Alpha, while
non-Expand transform-info projection exposes the same synchronized PLTE without
mutating source metadata. The palette/read/info/dispatcher rows remain partial
until alpha-mode Encode/Optimize behavior and the remaining projection/dispatch
branches land, so the ledger remains
`34 translated / 8 partial / 3 pending`.

LP-S004BH translates both alpha-mode setter rows. The fixed setter preserves
the four frozen modes, screen-role Gamma sentinel translation and range gate,
first-write reciprocal default file Gamma, Associated linear output,
Optimized and Broken flags, black File-Gamma Compose background, PNG-mode
interaction with existing background state, and conflict/lifecycle failure
isolation. The floating facade uses the existing frozen Gamma conversion before
delegating to fixed state. Read initialization now resolves default/screen
Gamma and freezes alpha-mode, Encode, Optimize, and background facts without
claiming the pending `png_do_encode_alpha` row stage. The two setter rows become
translated and the ledger advances to
`36 translated / 8 partial / 1 pending`.

LP-S004BI translates the final pending `png_do_encode_alpha` body. Direct 8-bit
and 16-bit GA/RGBA helpers transform only the final alpha component through the
from-linear Gamma table, preserve color bytes and network order, validate rows
before topology selection, and keep unsupported results copy-owned. Read
initialization cancels Encode/Optimize when screen Gamma is insignificant or
semantic alpha does not survive, then places effective Encode Alpha after
Compose/Gamma/post-Compose Strip and before 16-to-8 reduction. Whole-image and
consumer paths execute the same stage. The row body becomes translated and the
ledger reaches
`37 translated / 8 partial / 0 pending`.

LP-S004BJ closes Alpha Optimize/Encode initializer parity. Palette input now
distinguishes opaque, binary-only, and partial tRNS; opaque and binary-only
inputs cancel effective Encode/Optimize without mutating configured setter
intent, and insignificant screen Gamma performs the same cancellation. Partial
Indexed alpha keeps Optimize and preprocesses PLTE through the frozen
to-linear, `round(component * alpha / 255)`, and from-linear arithmetic while
retaining tRNS for associated-alpha Expand output. Non-Expand snapshots,
source-metadata ownership, whole-image execution, and standalone consumer use
are covered. `png_init_rgb_transformations` advances from partial to translated;
the palette and complete read initializer rows retain other deferred branches,
so the ledger becomes `38 translated / 7 partial / 0 pending`.

LP-S004BK closes the final palette initializer branch. Background Expand plus
Expand without tRNS-to-alpha expansion now inverts the copy-owned effective
palette alpha prefix byte-for-byte before the existing palette composition
path. Source metadata and the implicit opaque tail remain unchanged, while the
ordinary Expand-tRNS path retains the original prefix for row-stage alpha
handling. Transparent/partial/opaque values, Expand/non-Expand snapshots,
whole-image execution, malformed-prefix behavior, and consumer use are covered.
`png_init_palette_transformations` advances from partial to translated, so the
ledger becomes `39 translated / 6 partial / 0 pending`.
