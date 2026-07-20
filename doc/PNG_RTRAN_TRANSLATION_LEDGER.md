# pngrtran.c Translation Alignment

[English](PNG_RTRAN_TRANSLATION_LEDGER.md) | [简体中文](zh-CN/READ_TRANSFORMS.md)

Baseline: `libpng 1.6.58`, upstream commit
`3061454d980de7d53608f594194cfac722721d2a`.

The top-level function inventory is generated with:

```sh
./tools/update-pngrtran-inventory.sh
```

The generated source list is
[`upstream/libpng-1.6.58-pngrtran-functions.tsv`](upstream/libpng-1.6.58-pngrtran-functions.tsv).
The generator requires exactly 45 top-level functions and fails if the frozen
source changes unexpectedly.

## Result

| Status | Count |
| --- | ---: |
| Translated | 45 |
| Partial | 0 |
| Pending | 0 |
| Total | 45 |

## Covered Families

- CRC policy and read-transform configuration
- background, alpha mode, gamma, and RGB-to-gray configuration
- expansion, 16-bit reduction, packing, filler, swapping, and channel order
- read user transforms and transform-info projection
- palette and non-palette initialization
- gamma, background composition, alpha encoding, expansion, and quantization
- complete read-transform dispatch ordering

`45/45` means that every top-level function body in the frozen `pngrtran.c`
inventory has a traceable Cangjie implementation and test coverage. It does not
mean that every classic C setter, callback trampoline, compile-time option, or
`libpng16` symbol is already exported.

For ABI availability, use [C ABI Surfaces](ABI_PREVIEW.md) and the symbol
manifests under [`abi/symbols/`](../abi/symbols/).
