# pngwtran.c Translation Alignment

[English](PNG_WTRAN_TRANSLATION_LEDGER.md) | [简体中文](zh-CN/WRITE_TRANSFORMS.md)

Baseline: `libpng 1.6.58`, upstream commit
`3061454d980de7d53608f594194cfac722721d2a`.

Regenerate the inventory with:

```sh
./tools/update-pngwtran-inventory.sh
```

The generated source list is
[`upstream/libpng-1.6.58-pngwtran-functions.tsv`](upstream/libpng-1.6.58-pngwtran-functions.tsv).

## Result

| Upstream function | Cangjie anchor | Status |
| --- | --- | --- |
| `png_do_pack` | `pngDoWritePack` | Translated |
| `png_do_pack_swap` | `pngDoWritePackSwap` | Translated |
| `png_do_write_swap_alpha` | `pngDoWriteSwapAlpha` | Translated |
| `png_do_write_invert_alpha` | `pngDoWriteInvertAlpha` | Translated |
| `png_do_write_transformations` | `applyInitializedPngWriteStages` | Translated |

| Status | Count |
| --- | ---: |
| Translated | 5 |
| Partial | 0 |
| Pending | 0 |
| Total | 5 |

The write pipeline also composes shared write-transform operations for filler
stripping, 16-bit byte swapping, significant-bit shifting, BGR, and monochrome
inversion. Source-function alignment is separate from complete write-side C ABI
coverage.
