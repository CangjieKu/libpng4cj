# pngrtran.c Translation Ledger

Frozen source: `vendor/libpng-1.6.58/pngrtran.c` at upstream commit
`3061454d980de7d53608f594194cfac722721d2a`.

Regenerate the exact top-level function inventory with:

```sh
sh ./tools/update-pngrtran-inventory.sh
```

The generated file is
`docs/upstream/libpng-1.6.58-pngrtran-functions.tsv`. The generator asserts the
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
| 489 | `png_set_quantize` | none | pending | palette quantization state |
| 892 | `png_set_gamma_fixed` | retained gAMA only | pending | gamma transform state and tables |
| 934 | `png_set_gamma` | none | pending | floating-point facade |
| 948 | `png_set_expand` | `PngReadTransformState.setExpand` | translated | transformed IHDR projection deferred |
| 978 | `png_set_palette_to_rgb` | `PngReadTransformState.setPaletteToRgb` | translated | transformed IHDR projection deferred |
| 990 | `png_set_expand_gray_1_2_4_to_8` | `PngReadTransformState.setExpandGrayOneTwoFourToEight` | translated | transformed IHDR projection deferred |
| 1002 | `png_set_tRNS_to_alpha` | `PngReadTransformState.setTransparencyToAlpha` | translated | transformed IHDR projection deferred |
| 1018 | `png_set_expand_16` | `PngReadTransformState.setExpand16` | translated | transformed IHDR projection deferred |
| 1031 | `png_set_gray_to_rgb` | `PngReadTransformState.setGrayToRgb` | translated | direct `png_do_gray_to_rgb` row topology remains partial |
| 1046 | `png_set_rgb_to_gray_fixed` | `PngReadTransformState.setRgbToGrayFixed` | translated | warning callback emission deferred |
| 1118 | `png_set_rgb_to_gray` | none | pending | floating-point fixed conversion facade |
| 1132 | `png_set_read_user_transform_fn` | none | pending | callback ABI and row hook |
| 1151 | `png_gamma_threshold` | none | pending | gamma fixed-point substrate |
| 1176 | `png_init_palette_transformations` | `pngInitPaletteTransformations` | partial | background/encode-alpha optimization and palette mutation branches |
| 1265 | `png_init_rgb_transformations` | `pngInitRgbTransformations` | partial | background/encode-alpha optimization branches |
| 1351 | `png_resolve_file_gamma` | retained gAMA/sRGB/cHRM | pending | precedence and fixed-point resolution |
| 1387 | `png_init_gamma_values` | none | pending | gamma values and table requirements |
| 1424 | `png_init_read_transformations` | `initializePngReadTransformations` | partial | gamma/background, coefficient defaulting, palette mutation, and complete dispatcher state |
| 2069 | `png_read_transform_info` | explicit result layouts | partial | transformed IHDR/metadata projection |
| 2292 | `png_do_unpack` | `packedSample`, gray/index expansion | translated | direct packed-row public surface unchanged |
| 2390 | `png_do_unshift` | significant-bit shift resolver | translated | row-info topology alignment |
| 2529 | `png_do_scale_16_to_8` | `Png16To8Mode.Scale` | translated | row-info topology alignment |
| 2590 | `png_do_chop` | `Png16To8Mode.Strip` | translated | row-info topology alignment |
| 2615 | `png_do_read_swap_alpha` | `SwapAlpha` | translated | row-info topology alignment |
| 2711 | `png_do_read_invert_alpha` | `InvertAlpha` | translated | row-info topology alignment |
| 2813 | `png_do_read_filler` | `PngRowShapeTransform` filler modes | translated | row-info topology alignment |
| 3000 | `png_do_gray_to_rgb` | canonical grayscale expansion | partial | direct translated row body |
| 3139 | `png_do_rgb_to_gray` | `pngDoRgbToGray8/16` | translated | gamma-table branches deferred |
| 3340 | `png_do_compose` | none | pending | background/alpha/gamma composition |
| 4084 | `png_do_gamma` | none | pending | gamma tables |
| 4285 | `png_do_encode_alpha` | none | pending | alpha-mode gamma encoding |
| 4349 | `png_do_expand_palette` | indexed palette/tRNS expansion | translated | row-info topology alignment |
| 4523 | `png_do_expand` | gray/RGB/tRNS expansion | translated | row-info topology alignment |
| 4753 | `png_do_expand_16` | 8-to-16 channel replication | translated | row-info topology alignment |
| 4783 | `png_do_quantize` | none | pending | palette lookup and dither state |
| 4880 | `png_do_read_transformations` | current ordered transform calls | partial | complete stateful dispatcher and pending bodies |

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
