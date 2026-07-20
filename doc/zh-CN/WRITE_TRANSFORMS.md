# pngwtran.c 写入转换对齐

[简体中文](WRITE_TRANSFORMS.md) | [English](../PNG_WTRAN_TRANSLATION_LEDGER.md)

基线：`libpng 1.6.58`，上游提交
`3061454d980de7d53608f594194cfac722721d2a`。

使用以下命令重新生成函数清单：

```sh
./tools/update-pngwtran-inventory.sh
```

生成文件为
[`upstream/libpng-1.6.58-pngwtran-functions.tsv`](../upstream/libpng-1.6.58-pngwtran-functions.tsv)。

## 结果

| 上游函数 | 仓颉实现锚点 | 状态 |
| --- | --- | --- |
| `png_do_pack` | `pngDoWritePack` | 已翻译 |
| `png_do_pack_swap` | `pngDoWritePackSwap` | 已翻译 |
| `png_do_write_swap_alpha` | `pngDoWriteSwapAlpha` | 已翻译 |
| `png_do_write_invert_alpha` | `pngDoWriteInvertAlpha` | 已翻译 |
| `png_do_write_transformations` | `applyInitializedPngWriteStages` | 已翻译 |

| 状态 | 数量 |
| --- | ---: |
| 已翻译 | 5 |
| 部分翻译 | 0 |
| 待翻译 | 0 |
| 合计 | 5 |

写入管线还会组合共享的 filler 移除、16 位字节交换、有效位移位、BGR 和
单色反转操作。源函数翻译完成度与完整写入侧 C ABI 覆盖率是两个独立指标。
