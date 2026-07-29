<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-libpng4cj-ff6b35?style=for-the-badge&labelColor=1a1a2e" alt="libpng4cj" />
  <img src="https://img.shields.io/badge/version-0.8.1-blue?style=for-the-badge&labelColor=1a1a2e" alt="Version" />
  <img src="https://img.shields.io/badge/license-Libpng--2.0-green?style=for-the-badge&labelColor=1a1a2e" alt="License" />
</p>

<div align="center">
<span style="font-weight:300;font-size:38px">libpng4cj</span><br/>
<span style="font-weight:100;font-size:26px">仓颉原生 PNG 编解码与 libpng 兼容工程</span>
<p align="center">
  <strong>覆盖读取、写入、像素变换、元数据和渐进式处理的仓颉 PNG 库</strong><br>
  <sub>Adam7 · Progressive · Gamma · Metadata · Streaming · C ABI Preview</sub>
</p>
</div>

<p align="center">
  <a href="https://gitcode.com/cinyu/libpng4cj">开源主仓</a> ·
  <a href="doc/README.md">中文文档</a> ·
  <a href="doc/zh-CN/API.md">API 指南</a> ·
  <a href="doc/zh-CN/COMPATIBILITY.md">兼容性矩阵</a> ·
  <a href="README-EN.md">English</a>
</p>

> 当前文档对应版本：`0.8.1`

libpng4cj 是面向仓颉的 PNG 编解码库。项目以 libpng `1.6.58` 为行为参考，
用仓颉实现 PNG 解析、过滤、像素变换、元数据、渐进式读取和编码，并保留 zlib
作为压缩依赖。

`0.8.1` 提供可直接用于仓颉项目的原生读写 API。原生消费链已在 macOS arm64
和 Debian 13 amd64 上验证。仓库同时提供 macOS arm64 上经过严格 C11
消费者验证的 libpng16 C ABI 子集；该 ABI 仍处于 preview 阶段，不是完整的
libpng16 替代品。

## 支持范围

| 能力 | 当前支持 |
| --- | --- |
| 解码 | 全部 PNG 颜色类型，1/2/4/8/16 位深，五种过滤器，非交织和 Adam7 |
| 像素输出 | packed rows、RGBA8、RGBA16、Gray/RGB/BGR/Alpha 常用布局、线性 UInt16、索引色 |
| 颜色处理 | Gamma 校正、背景合成、RGB/Gray 转换、Alpha 模式及常用读变换 |
| 元数据 | PLTE/tRNS、gAMA/cHRM/sRGB/sBIT/bKGD/pHYs、iCCP、文本、时间及多种标准辅助块 |
| 渐进式读取 | 增量输入、info/row/end 回调、Adam7 pass 信息、暂停与恢复 |
| 编码 | 整图、逐行、增量 IDAT、Adam7、过滤和压缩控制、元数据、未知块 |
| 简化 API | 内存、文件、调用方管理的流，支持 direct8、linear16、colormap 和正负 stride |
| C ABI | `136/258` 个默认公开 libpng 符号，另含 5 个 `png4cj_*` 预览扩展符号，当前完整回执限 macOS arm64 |
| ICC | 保留并校验 iCCP profile，不执行 ICC 像素颜色转换 |

详细状态见[兼容性与依赖矩阵](doc/zh-CN/COMPATIBILITY.md)。
API 使用说明见 [API 指南](doc/zh-CN/API.md)。

## 环境要求

- `cjc` 和 `cjpm`，本分支声明 STS `1.1.3` 为最低版本
- zlib 开发库和运行库
- C ABI preview 需要系统 C 编译器

当前本机完整验证使用 Cangjie `1.1.3`、macOS arm64 和 zlib `1.2.12`。
Debian 13 amd64 已有项目所有者提供的原生构建、测试和独立 consumer 实机回执。

先检查环境：

```sh
./tools/doctor.sh
```

由于 cjpm 静态库的链接选项不会自动传递给最终可执行文件，消费项目必须显式
链接 `-lz`。

## 添加依赖

在最终可执行项目的 `cjpm.toml` 中添加：

```toml
[package]
link-option = "-lz"

[dependencies]
libpng4cj = { git = "https://gitcode.com/cinyu/libpng4cj.git" }
```

正式项目应固定经过验证的 tag 或 commit。公开包根为 `libpng4cj`：

```cangjie
import libpng4cj.*
```

## 读取 PNG

读取文件并得到 RGBA8 行：

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

`Scale` 会把 16 位样本精确缩放到 8 位。输入不超过 8 位时，也可以直接调用
`decodePngRgba8(encoded)`。

应用层文件读写可以使用简化 API：

```cangjie
import libpng4cj.*

main(): Int64 {
    let reader = beginPngImageReadFromFile("input.png")
    let image = reader.finishRead(ImageRgba8)

    writePngImageToFile(image, "output.png", Adam7)
    return 0
}
```

同一组 API 还支持：

- `beginPngImageReadFromMemory` / `writePngImageToMemory`
- `beginPngImageReadFromStream` / `writePngImageToStream`
- `finishReadLinear` / `writePngLinearImageToMemory`
- `finishReadColormap` / `writePngColormapImageToMemory`
- `PngProgressiveReader`
- `PngWriteSession` / `PngRowWriteSession`

## 构建与验证

常规开发命令：

```sh
cjpm build
cjpm test

cd test/consumer
cjpm run
```

完整自动化入口会依次执行环境检查、冻结清单校验、构建、单元测试和独立
consumer：

```sh
./tools/ci.sh
```

仓库已包含 `.github/workflows/cangjie-ci.yml`。当前公共托管 runner 不提供所需
仓颉 SDK，因此 workflow 使用带 `cangjie` 和 `posix` 标签的自托管 runner。
配置说明见[持续集成](doc/zh-CN/CI.md)。

当前测试集为 `504/504`。独立 consumer 包含真实 Adam7 fixture 的
decode -> encode -> decode 完整像素 roundtrip。

## 上游对应关系

项目冻结以下上游参考：

- libpng `1.6.58`
- tag `v1.6.58`
- commit `3061454d980de7d53608f594194cfac722721d2a`
- 默认公开符号清单：`258`
- `pngrtran.c`：`45/45` 顶层函数已映射到仓颉实现
- `pngwtran.c`：`5/5` 顶层函数已映射到仓颉实现

逐函数状态见[读取转换对齐](doc/zh-CN/READ_TRANSFORMS.md)
和[写入转换对齐](doc/zh-CN/WRITE_TRANSFORMS.md)。这些数字描述
源文件函数体覆盖，不等于完整 C ABI 覆盖。

## C ABI Preview
> 注意！ 该能力为额外维护项，本项目主要方向是维护*仓颉原生API*的实现

macOS arm64 上可以运行完整 C ABI 验证：

```sh
./tools/test_abi_preview.sh
```

该脚本会构建仓颉 `@C` 导出的 dylib，校验符号清单，以 warnings-as-errors
编译严格 C11 消费者，并在原位置和同机重定位后重复运行。当前覆盖
`png_image` 内存/文件/stdio 子集、经典读取和元数据 getter、allocator/error/
IO 生命周期，以及 write owner、raw chunk、CRC 和 flush。

C 进程需要按照仓颉工具链要求调用 `InitCJRuntime`、
`LoadCJLibraryWithInit` 和 `FiniCJRuntime`。完整说明见
[C ABI 说明](doc/zh-CN/C_ABI.md)。

## 当前限制

- C ABI 尚未覆盖全部 libpng16 默认符号和行为 | **该能力为额外维护项**
- `setjmp` / `longjmp`、部分回调和原始用户指针族仍未完成 | **Cangjie 用 Exception**
- 经典 write-info/row/image 与剩余 setter/state API 仍需补齐
- 不执行 ICC profile 驱动的像素颜色转换 | **原版 libpng 也不默认做 ICC 转换(需要 lcms2)**
- Linux、Windows、HarmonyOS/OpenHarmony 的 C ABI 制品尚未验证 | **主要负责方向是仓颉原生接口**
- 尚无超过 100 MB 图片的吞吐认证、并发压力证明或稳定 ABI 承诺
- `0.8.1` 不是 LTS 版本

## 项目结构

```text
libpng4cj/
├── src/                         # 仓颉实现与 cjpm 单元测试
├── abi/                         # C ABI 头文件和冻结符号清单
├── doc/                         # 中英文 API、兼容性、CI 和上游映射
├── test/consumer/               # 独立仓颉消费项目
├── test/abi_consumer/           # 严格 C11 消费者
├── tools/                       # doctor、CI、清单和 ABI 验证脚本
└── vendor/libpng-1.6.58/        # 冻结的上游参考与行为 oracle
```

## 许可证

libpng4cj 使用 [Libpng-2.0](LICENSE)。仓库保留完整上游源码用于许可证、
实现对照和 oracle 测试；运行时 PNG 行为由 `src/` 下的仓颉实现提供。

- [README.OpenSource](README.OpenSource)
- [上游 libpng 许可证](vendor/libpng-1.6.58/LICENSE)
- [pnggroup/libpng](https://github.com/pnggroup/libpng)
