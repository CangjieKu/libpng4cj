# libpng 1.6.58 移植状态

[简体中文](PORTING_STATUS.md) | [English](../PORTING_MAP.md)

libpng4cj 在保持 libpng `1.6.58` 主要职责边界可追踪的同时，提供仓颉原生
API。仓库中的上游源码是固定的实现参考，不会被链接进仓颉实现。

## 源文件对应关系

| 上游源码 | 仓颉侧职责 |
| --- | --- |
| `png.c`、`pngerror.c`、`pngmem.c` | 运行时、错误、签名、校验和、内存契约 |
| `pngread.c`、`pngrio.c`、`pngrutil.c` | 读取生命周期、IO、chunk、解压和元数据 |
| `pngrtran.c`、`pngtrans.c` | 读取转换和共享转换状态 |
| `pngpread.c` | 渐进式读取生命周期 |
| `pngwrite.c`、`pngwio.c`、`pngwutil.c` | 写入生命周期、IO、过滤、压缩和 chunk 输出 |
| `pngwtran.c` | 写入转换 |
| `pngget.c`、`pngset.c` | 元数据 getter、setter 和校验 |
| `png.h`、`pngconf.h`、`pnglibconf.h` | 公开 C ABI 声明与配置边界 |
| `scripts/symbols.def` | 导出符号对比基线 |

## 已实现的仓颉原生能力

- PNG 签名、大小端、CRC、chunk 分帧、校验和可配置限制
- 非隔行和 Adam7 解码
- 增量渐进式读取
- 读取过滤器以及完整 `pngrtran.c` 函数清单
- 伽马、背景合成、Alpha、调色板、打包、量化和通道转换
- 标准及扩展 PNG 元数据
- 非隔行和 Adam7 编码
- 逐行及回调驱动的流式输出
- 完整 `pngwtran.c` 函数清单
- 直接、线性和色表三类简化图像 API

## ABI 范围

C ABI 由仓颉 `@C` 直接导出。目前清单覆盖默认公开 libpng 符号中的
`134/258`，包含简化图像操作、classic read owner、IO、行读取、元数据
getter、内存和错误回调、限制，以及 raw write chunk 输出。另有 5 个
`png4cj_*` 预览扩展符号用于能力发现和 RGBA8 解码，不计入上游总数。

受支持契约和明确边界见 [C ABI 说明](C_ABI.md)。

## 对齐证据

- [读取转换对齐](READ_TRANSFORMS.md)
- [写入转换对齐](WRITE_TRANSFORMS.md)
- [固定上游清单](../upstream/)
- [兼容性与依赖矩阵](COMPATIBILITY.md)
