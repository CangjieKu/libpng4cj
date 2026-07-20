# libpng4cj 文档

[简体中文](README.md) | [English](README-EN.md)

这里收录面向使用者、贡献者和兼容性审计的公开文档。中文文档位于
[`zh-CN/`](zh-CN/)，英文文档保留原有路径，便于已有链接继续工作。

## 使用者文档

- [API 使用指南](zh-CN/API.md)
- [兼容性与依赖矩阵](zh-CN/COMPATIBILITY.md)
- [C ABI 说明](zh-CN/C_ABI.md)
- [持续集成](zh-CN/CI.md)

## 移植与上游对齐

- [移植状态](zh-CN/PORTING_STATUS.md)
- [读取转换对齐](zh-CN/READ_TRANSFORMS.md)
- [写入转换对齐](zh-CN/WRITE_TRANSFORMS.md)
- [`libpng 1.6.58` 上游清单](upstream/)

逐函数清单描述源函数翻译状态，不代表完整 `libpng16` C ABI 覆盖率。
C ABI 的实际边界以 [C ABI 说明](zh-CN/C_ABI.md)和
[`abi/symbols/`](../abi/symbols/) 下的符号清单为准。
