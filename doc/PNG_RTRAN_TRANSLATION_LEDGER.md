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
| 142 | `png_set_background_fixed` | retained bKGD only | pending | background transform state |
| 172 | `png_set_background` | none | pending | floating-point facade |
| 188 | `png_set_scale_16` | `PngReadTransformState.setScale16` | translated | direct C ABI setter deferred |
| 202 | `png_set_strip_16` | `PngReadTransformState.setStrip16` | translated | direct C ABI setter deferred |
| 215 | `png_set_strip_alpha` | `PngReadTransformState.setStripAlpha` | translated | direct C ABI setter deferred |
| 361 | `png_set_alpha_mode_fixed` | none | pending | alpha/background/gamma state |
| 461 | `png_set_alpha_mode` | none | pending | floating-point facade |
| 489 | `png_set_quantize` | `PngReadTransformState.setQuantize` | partial | normal lifecycle, both reduction branches, remap, and full lookup translated; allocation-warning fallback, dispatcher, and C ABI deferred |
| 892 | `png_set_gamma_fixed` | retained gAMA only | pending | gamma transform state and tables |
| 934 | `png_set_gamma` | none | pending | floating-point facade |
| 948 | `png_set_expand` | `PngReadTransformState.setExpand` | translated | transformed IHDR projection deferred |
| 978 | `png_set_palette_to_rgb` | `PngReadTransformState.setPaletteToRgb` | translated | transformed IHDR projection deferred |
| 990 | `png_set_expand_gray_1_2_4_to_8` | `PngReadTransformState.setExpandGrayOneTwoFourToEight` | translated | transformed IHDR projection deferred |
| 1002 | `png_set_tRNS_to_alpha` | `PngReadTransformState.setTransparencyToAlpha` | translated | transformed IHDR projection deferred |
| 1018 | `png_set_expand_16` | `PngReadTransformState.setExpand16` | translated | direct C ABI setter deferred |
| 1031 | `png_set_gray_to_rgb` | `PngReadTransformState.setGrayToRgb` | translated | direct C ABI setter and transformed-info projection deferred |
| 1046 | `png_set_rgb_to_gray_fixed` | `PngReadTransformState.setRgbToGrayFixed` | translated | warning callback emission deferred |
| 1118 | `png_set_rgb_to_gray` | none | pending | floating-point fixed conversion facade |
| 1132 | `png_set_read_user_transform_fn` | none | pending | callback ABI and row hook |
| 1151 | `png_gamma_threshold` | none | pending | gamma fixed-point substrate |
| 1176 | `png_init_palette_transformations` | `pngInitPaletteTransformations` | partial | background/encode-alpha optimization and palette mutation branches |
| 1265 | `png_init_rgb_transformations` | `pngInitRgbTransformations` | partial | background/encode-alpha optimization branches |
| 1351 | `png_resolve_file_gamma` | retained gAMA/sRGB/cHRM | pending | precedence and fixed-point resolution |
| 1387 | `png_init_gamma_values` | none | pending | gamma values and table requirements |
| 1424 | `png_init_read_transformations` | `initializePngReadTransformations` | partial | quantize palette/count/mode/tables are snapshotted; gamma/background, coefficient defaulting, remaining palette mutation, and complete dispatcher state remain |
| 2069 | `png_read_transform_info` | `projectPngReadTransformInfo` | partial | non-gamma topology plus quantize palette sync are projected; gamma/background, filler, pack, user-transform, and full metadata projection remain |
| 2292 | `png_do_unpack` | `pngDoUnpack` | translated | packing setter state and complete dispatcher remain partial |
| 2390 | `png_do_unshift` | `pngDoUnshift` | translated | selected adapter is narrow; palette init mutation and complete dispatcher remain partial |
| 2529 | `png_do_scale_16_to_8` | `pngDoScale16To8` | translated | initialized adapter is narrow; complete dispatcher remains partial |
| 2590 | `png_do_chop` | `pngDoChop` | translated | initialized adapter is narrow; complete dispatcher remains partial |
| 2615 | `png_do_read_swap_alpha` | `pngDoReadSwapAlpha` | translated | selected adapter is narrow; setter state and complete dispatcher remain partial |
| 2711 | `png_do_read_invert_alpha` | `pngDoReadInvertAlpha` | translated | selected adapter is narrow; setter state and complete dispatcher remain partial |
| 2813 | `png_do_read_filler` | `pngDoReadFiller` | translated | selected adapter is narrow; setter state and transformed-info color-type projection remain partial |
| 3000 | `png_do_gray_to_rgb` | `pngDoGrayToRgb` | translated | initialized stage adapter is narrow; complete dispatcher remains partial |
| 3139 | `png_do_rgb_to_gray` | `pngDoRgbToGray` plus fixed 8/16-bit cores | translated | gamma-table branches deferred |
| 3340 | `png_do_compose` | none | pending | background/alpha/gamma composition |
| 4084 | `png_do_gamma` | none | pending | gamma tables |
| 4285 | `png_do_encode_alpha` | none | pending | alpha-mode gamma encoding |
| 4349 | `png_do_expand_palette` | `pngDoExpandPalette` | translated | palette mutation, SIMD, and complete dispatcher remain partial |
| 4523 | `png_do_expand` | `pngDoExpand` | translated | bounded initialized adapter exists; complete dispatcher remains partial |
| 4753 | `png_do_expand_16` | `pngDoExpand16` | translated | bounded initialized adapter exists; complete dispatcher remains partial |
| 4783 | `png_do_quantize` | `pngDoQuantize` | translated | initialized adapter and projected palette synchronization are bounded; complete dispatcher remains partial |
| 4880 | `png_do_read_transformations` | `applyInitializedPngReadStages` | partial | Expand, Strip Alpha, RGB-to-gray, Gray-to-RGB, Scale/Strip16, Quantize, and Expand16 have bounded initialized composition; remaining stateful stages and pending bodies remain |

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
stage order. The three initializer rows remain `partial` until background,
encode/optimize-alpha, palette mutation, gamma, and full dispatcher state land.

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
