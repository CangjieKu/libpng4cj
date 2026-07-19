# libpng4cj

[English](README-EN.md) | 简体中文

libpng4cj 是面向仓颉的 PNG 读写库，也是 libpng `1.6.58` 的全量移植工程。
PNG 解析、过滤、像素转换、元数据、渐进式读取和编码逻辑由仓颉实现；zlib
作为外部压缩依赖保留，这与上游 libpng 的边界一致。

当前版本为 `0.2.0 preview`。仓颉原生 API 已覆盖常用读写流程，macOS arm64
还提供了经过 C11 消费链验证的 libpng16 ABI 子集。它不是完整的 libpng16
替换品，也不是 LTS 或跨平台发行版。

## 当前能力

| 能力 | 0.2.0 preview 状态 |
| --- | --- |
| PNG 解码 | 支持全部 PNG 颜色类型、1/2/4/8/16 位深、五种过滤器和 Adam7 |
| 像素输出 | packed rows、RGBA8、RGBA16、常用 Gray/RGB/BGR/Alpha 布局、线性 UInt16 和索引色 |
| 颜色处理 | Gamma 校正、背景合成、RGB/Gray 转换、Alpha 模式及常用读变换已接入当前管线 |
| 元数据 | 支持 PLTE/tRNS、gAMA/cHRM/sRGB/sBIT/bKGD/pHYs、iCCP、文本、时间及多种标准辅助块 |
| 渐进式读取 | 支持增量输入、早期信息/行回调、Adam7 pass 上下文、暂停与恢复 |
| PNG 编码 | 支持整图、逐行、增量 IDAT、Adam7、过滤/压缩控制、元数据和未知块 |
| 简化 API | 支持内存、文件和调用方管理的流；支持 direct8、linear16、colormap 和正负 stride |
| C ABI | macOS arm64 上提供 preview facade、`png_image` 内存/文件/stdio 子集、经典工具与读取句柄、custom/stdio `png_read_info`、核心 IHDR、固定/浮点标量及扩展元数据 getter、easy-access getter，以及 raw row/image/read-end 子集 |
| ICC | 保留并校验 iCCP profile；不执行 ICC 像素颜色转换 |

更细的边界见 [兼容性与依赖矩阵](doc/COMPATIBILITY_AND_DEPENDENCY_MATRIX.md)。

## 环境要求

- `cjpm` / `cjc`：项目声明最低版本 `1.0.5`
- 当前本机完整回执：Cangjie `1.1.0`，`aarch64-apple-darwin`
- zlib 开发库和运行库
- macOS ABI preview 还需要系统 C 编译器

静态库的链接选项不会自动传递给最终可执行文件，因此消费项目需要显式链接
`-lz`。

先运行环境检查：

```sh
./tools/doctor.sh
```

## 添加依赖

在最终可执行项目的 `cjpm.toml` 中添加：

```toml
[package]
link-option = "-lz"

[dependencies]
libpng4cj = { git = "https://gitcode.com/cinyu/libpng4cj.git" }
```

公开包根就是 `libpng4cj`，不会出现 `libpng4cj.libpng4cj.*` 的重复前缀：

```cangjie
import libpng4cj.*
```

正式项目建议在依赖配置中固定经过验证的 tag 或 commit。

## 快速读取

读取 PNG 并转换为 RGBA8：

```cangjie
import std.fs.*
import libpng4cj.*

main(): Int64 {
    let encoded = File.readFrom("input.png")
    let image = decodePngRgba8(encoded, Scale)

    println("${image.ihdr.width}x${image.ihdr.height}")
    println("rows: ${image.rowCount()}")
    return 0
}
```

`Scale` 使用精确缩放把 16 位输入转换为 8 位。只处理不超过 8 位的输入时，
也可以直接调用 `decodePngRgba8(encoded)`。

## 简化读写

简化 API 适合应用层内存、文件和流操作：

```cangjie
import libpng4cj.*

main(): Int64 {
    let reader = beginPngImageReadFromFile("input.png")
    let image = reader.finishRead(ImageRgba8)

    writePngImageToFile(image, "output.png", Adam7)
    return 0
}
```

还可使用：

- `beginPngImageReadFromMemory` / `writePngImageToMemory`
- `beginPngImageReadFromStream` / `writePngImageToStream`
- `finishReadLinear` / `writePngLinearImageToMemory`
- `finishReadColormap` / `writePngColormapImageToMemory`
- `PngProgressiveReader`
- `PngWriteSession` / `PngRowWriteSession`

完整 API 索引见 [Feature API](doc/feature_api.md)。

## 构建与测试

```sh
./tools/doctor.sh
cjpm build
cjpm test
```

验证独立仓颉消费项目：

```sh
cd test/consumer
cjpm run
```

刷新并校验冻结的上游基线：

```sh
./tools/update-upstream-baseline.sh
```

当前基线固定为：

- libpng `1.6.58`
- tag `v1.6.58`
- commit `3061454d980de7d53608f594194cfac722721d2a`
- 默认公开符号清单：`258`
- 当前冻结 ABI 清单覆盖：`124/258` 个上游默认符号
- `pngrtran.c` 顶层函数清单：`45`

## C ABI Preview

macOS arm64 可运行完整 ABI preview 验证：

```sh
./tools/test_abi_preview.sh
```

它会：

- 构建直接由仓颉 `@C` 导出的 dylib
- 校验冻结的导出符号清单
- 以 `-Wall -Wextra -Werror` 编译严格 C11 消费者
- 验证 preview facade、`png_image` 内存/文件/stdio 子集、经典无状态工具、
  读取/info 句柄生命周期、warning/error 边界、自定义分配器所有权、
  custom/stdio `png_read_info`、owner 尺寸/单 chunk 限制 setter、核心 IHDR
  getter、固定/浮点 gAMA 与 cHRM、cHRM XYZ、
  sRGB/sBIT/bKGD/pHYs/PLTE/tRNS、oFFs/cICP/cLLI/mDCV、
  pCAL/sCAL/tIME/text/eXIf/iCCP/hIST/sPLT/unknown/rows getter、版本字符串、
  get-valid/签名/物理换算 getter 及 raw row/image/read-end
- 把 dylib 移动后重新运行消费者，验证同机重定位加载

C 进程需要按仓颉工具链要求初始化和结束仓颉 runtime。示例消费者已经展示
`InitCJRuntime`、`LoadCJLibraryWithInit` 和 `FiniCJRuntime` 的完整生命周期。

详见 [C ABI Surfaces](doc/ABI_PREVIEW.md)。

## 兼容性边界

`0.2.0 preview` 暂不声称：

- 完整的 libpng16 默认配置符号与行为兼容
- `png_struct` / `png_info` 的变换后行、Adam7 pass/display 合并、尚未填充的
  rows 高层生命周期、其余 runtime/context setter 与注册、完整 read-end
  元数据、写入和元数据状态 API
- `setjmp` / `longjmp`、chunk/row-status 等其余 C 回调与原始用户指针族
- ICC profile 驱动的像素颜色转换
- Linux、Windows、HarmonyOS/OpenHarmony ABI 制品验证
- 超过 100 MB 图片的吞吐认证或并发压力认证
- LTS、稳定 ABI 或生产发行承诺

这些限制不会影响已验证的仓颉原生主流程，但使用 C ABI 或跨平台发布前应先查看
[兼容性与依赖矩阵](doc/COMPATIBILITY_AND_DEPENDENCY_MATRIX.md)。

## 项目结构

```text
libpng4cj/
├── src/                         # 仓颉实现与 cjpm 单元测试
├── abi/                         # C ABI 头文件和冻结符号清单
├── doc/                         # API、兼容性和上游映射文档
├── test/consumer/               # 独立仓颉消费项目
├── test/abi_consumer/           # 严格 C11 消费者
├── tools/                       # doctor、基线和 ABI 验证脚本
└── vendor/libpng-1.6.58/        # 冻结的上游翻译参考与行为 oracle
```

## 上游与许可证

libpng4cj 以 libpng `1.6.58` 为冻结翻译基线。仓库保留完整上游源码用于许可证、
实现对照和 oracle 测试；产品实现位于 `src/`，PNG 行为不由 vendored C 源码提供。

- 项目许可证：[Libpng-2.0](LICENSE)
- 上游许可证：[vendor/libpng-1.6.58/LICENSE](vendor/libpng-1.6.58/LICENSE)
- 开源依赖清单：[README.OpenSource](README.OpenSource)
- 上游仓库：[pnggroup/libpng](https://github.com/pnggroup/libpng)
