# C ABI 说明

[简体中文](C_ABI.md) | [English](../ABI_PREVIEW.md)

libpng4cj 提供由仓颉 `@C` 直接导出的 Preview C ABI，用于早期业务接入和
兼容性建设。它目前还不是完整 `libpng16` 的替代品。

## 构建与测试

在 macOS arm64 上执行：

```sh
./tools/test_abi_preview.sh
```

输出目录包含动态库、公开头文件、符号记录和严格 C11 consumer。测试会同时
验证原始输出位置和复制目录下的重定位加载。

## 导出范围

当前符号清单覆盖默认公开 libpng 符号中的 `139/258`。

主要包括：

- 5 个 `png4cj_*` 能力发现和 RGBA8 解码函数
- 8 个简化 `png_image` 内存、文件和 stdio 函数
- classic 版本、签名、大小端和灰度调色板工具函数
- read/write owner 创建与销毁
- 错误、警告、分配器和 IO 回调上下文
- 用户尺寸和单 chunk 分配限制
- `png_read_info`、源格式打包行读取和 `png_read_end`
- IHDR、标量、定点、浮点、物理尺寸、色彩、文本、ICC 和扩展元数据 getter
- 写回调、签名、单次及分段 raw chunk、CRC、flush 和 stdio 输出

准确符号范围以 [`abi/symbols/`](../../abi/symbols/) 中的清单为准。

## 头文件

[`abi/include/png.h`](../../abi/include/png.h) 提供已支持的 libpng 风格类型、
宏、结构体和函数声明，但不会伪装成完整上游头文件。

[`abi/include/libpng4cj_preview.h`](../../abi/include/libpng4cj_preview.h)
提供较小的 `png4cj_*` Preview API。

消费者应使用与动态库同一版本发布的头文件。

## 运行时生命周期

C 程序调用动态库前必须初始化仓颉运行时。已验证顺序为：

1. `InitCJRuntime`
2. `LoadCJLibraryWithInit`
3. 调用 libpng4cj 导出函数
4. 释放全部 libpng4cj owner 和缓冲区
5. `FiniCJRuntime`

[`test/abi_consumer/`](../../test/abi_consumer/) 中的示例展示了完整流程。

## 所有权规则

- `png_struct` 和 `png_info` 是由仓颉持有的不透明句柄。
- 销毁函数会使句柄失效，并在兼容接口要求时通过传入指针写回 NULL。
- 调用方提供的 read、write、error、memory 和 stdio 上下文仍归调用方所有。
- classic 分配接口返回的内存必须通过匹配的 libpng4cj free 路径释放。
- 借用的元数据指针仅在其 info owner 存活且未发生对应变更时有效。
- 回调在内部注册表锁之外执行。

## 错误边界

仓颉异常不会越过 C ABI。可恢复操作通过约定返回值或 image 错误状态报告。
classic `png_error` 在没有兼容非局部跳转边界时会进入终止路径。

当前 Preview 不声明完整 `setjmp`/`longjmp` 兼容。

## 平台状态

动态库、符号、consumer 和重定位的完整验证目前限于 macOS arm64。其他平台
可以使用仓颉原生 API；在加入对应构建和 consumer 记录前，不声明可移植的
C ABI 产物。

## 待补兼容范围

- 剩余 `124` 个默认公开符号
- 完整 classic transform setter 和转换后行时序
- 完整 progressive 及用户回调 C trampoline
- 上游一致的 `setjmp`/`longjmp` 行为
- 标准 `libpng16` 命名、安装和包元数据
- 非 macOS C ABI 产物与验证记录
