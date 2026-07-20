# pngrtran.c 读取转换对齐

[简体中文](READ_TRANSFORMS.md) | [English](../PNG_RTRAN_TRANSLATION_LEDGER.md)

基线：`libpng 1.6.58`，上游提交
`3061454d980de7d53608f594194cfac722721d2a`。

使用以下命令重新生成顶层函数清单：

```sh
./tools/update-pngrtran-inventory.sh
```

生成文件为
[`upstream/libpng-1.6.58-pngrtran-functions.tsv`](../upstream/libpng-1.6.58-pngrtran-functions.tsv)。
脚本固定要求 45 个顶层函数；上游源码发生意外变化时会直接失败。

## 结果

| 状态 | 数量 |
| --- | ---: |
| 已翻译 | 45 |
| 部分翻译 | 0 |
| 待翻译 | 0 |
| 合计 | 45 |

## 覆盖范围

- CRC 策略和读取转换配置
- 背景、Alpha mode、伽马和 RGB 转灰配置
- 展开、16 位缩减、打包、filler、交换和通道顺序
- 读取用户转换和转换后信息投影
- 调色板与非调色板初始化
- 伽马、背景合成、Alpha 编码、展开和量化
- 完整读取转换调度顺序

`45/45` 表示固定 `pngrtran.c` 清单中的每个顶层函数都有可追踪的仓颉实现
和测试覆盖，不表示所有 classic C setter、回调 trampoline、编译选项或
`libpng16` 符号均已导出。

C ABI 可用范围见 [C ABI 说明](C_ABI.md)和
[`abi/symbols/`](../../abi/symbols/) 下的符号清单。
