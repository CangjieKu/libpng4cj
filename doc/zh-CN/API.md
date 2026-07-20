# API 使用指南

[简体中文](API.md) | [English](../feature_api.md)

libpng4cj 提供仓颉原生 PNG API。推荐优先使用内存、文件和流式 IO 的简化
接口；需要精确控制时，可以继续使用打包行、渐进式读取、转换、元数据和
受控写入接口。

## 添加依赖

```toml
[package]
link-option = "-lz"

[dependencies]
libpng4cj = { git = "https://gitcode.com/cinyu/libpng4cj.git" }
```

libpng4cj 与上游 libpng 一样依赖系统 zlib。由于 cjpm 不会把静态库的链接
参数自动传递给最终消费者，可执行程序需要显式链接 `-lz`。

```cangjie
import libpng4cj.*
```

## 简化读取

从内存读取 PNG，并取得自有的 RGBA8 像素缓冲区：

```cangjie
let image = beginPngImageReadFromMemory(pngBytes)
let rgba = image.finishRead(ImageRgba8)

println("${rgba.width()} x ${rgba.height()}")
let pixels = rgba.bytes()
```

直接像素格式支持 Gray、GrayAlpha、AlphaGray、RGB、BGR、RGBA、ARGB、
BGRA 和 ABGR。`finishReadStrided` 系列支持正向和负向行跨度。

文件读取示例：

```cangjie
let image = beginPngImageReadFromFile("input.png")
let bgra = image.finishRead(ImageBgra8)
```

需要宿主数值形式的线性 UInt16 输出时，使用 `finishReadLinear`；需要索引
图像时，使用 `finishReadColormap`。

## 简化写入

把图像缓冲区写入内存：

```cangjie
let encoded = writePngImageToMemory(rgba)
```

写入文件：

```cangjie
writePngImageToFile(rgba, "output.png")
```

需要控制元数据、压缩参数、隔行方式和资源限制时：

```cangjie
let controls = PngWriteControlState()
controls.setCompressionLevel(Int32(6))

let encoded = writePngImageToMemory(
    rgba,
    PngWriteMetadata(),
    controls,
    Adam7,
    PngWriteLimits()
)
```

## 打包行解码

`decodePng` 返回源格式的自有打包行及保留的 PNG 元数据：

```cangjie
let decoded = decodePng(pngBytes)
let ihdr = decoded.ihdr
let firstRow = decoded.rows[0]
```

需要统一像素格式时，使用 `decodePngRgba8` 或 `decodePngRgba16`。通用接口
同时接受非隔行和 Adam7 图片；名称带 `NonInterlaced` 的接口会明确拒绝
Adam7 输入。

## 打包行编码

`encodePngPacked` 接受符合 PNG 色彩类型和位深布局的行数据：

```cangjie
let encoded = encodePngPacked(
    UInt32(2), UInt32(2), UInt8(8), TruecolorAlpha,
    [
        [255, 0, 0, 255, 0, 255, 0, 255],
        [0, 0, 255, 255, 255, 255, 255, 255]
    ]
)
```

Adam7 输出使用 `encodePngPackedAdam7`；索引色 Adam7 输出使用
`encodeIndexedPngPackedAdam7`。

## 渐进式读取

渐进式读取器支持分片输入、暂停、恢复、完成、失败和显式关闭，并通过
info、row、end 回调交付自有数据。非隔行图片可以在 IEND 前交付完整行；
Adam7 回调会携带 pass 和图像行上下文。

当 PNG 数据来自网络或其他分片传输，并且不希望先缓存完整文件时，优先
使用渐进式接口。

## 流式写入

`PngWriteSink` 接收自有的 PNG 签名或完整分帧 chunk，以及精确的输出上下文：

```cangjie
let sink = PngWriteSink()
sink.setWriteCallback({ context, bytes => output.write(bytes) })
sink.setFlushCallback({ context => output.flush() })

let receipt = session.writeTo(rows, sink)
```

逐行写入会执行有界的非隔行 deflate 或 Adam7 输出，输入行始终归调用方所有。

## 元数据

原生模型支持 PLTE、tRNS、gAMA、cHRM、sRGB、sBIT、bKGD、pHYs、iCCP、
文本块、tIME、cICP、cLLI、mDCV、eXIf、hIST、oFFs、pCAL、sCAL、sPLT，
以及按策略保留的未知 chunk。

写入元数据通过 `PngWriteMetadata` 提供。未知 chunk 必须显式指定位置和策略，
避免意外写出非法关键 chunk。

## 资源限制与错误

`PngReadLimits`、`PngWriteLimits` 和 `PngSimplifiedIoLimits` 可限制尺寸、
chunk 分配、压缩数据、解压行、转换输出、完整编码输出和简化 IO 输入。
处理不可信输入时应显式配置限制。

公开 API 使用稳定的仓颉错误，不把 zlib 状态码或 C 指针当作所有权接口。

## 延伸阅读

- [兼容性与依赖矩阵](COMPATIBILITY.md)
- [C ABI 说明](C_ABI.md)
- [移植状态](PORTING_STATUS.md)
- [读取转换对齐](READ_TRANSFORMS.md)
- [写入转换对齐](WRITE_TRANSFORMS.md)
