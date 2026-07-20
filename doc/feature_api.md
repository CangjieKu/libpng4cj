# API Guide

[English](feature_api.md) | [简体中文](zh-CN/API.md)

libpng4cj exposes a Cangjie-native PNG API. The most convenient entry points
cover memory, file, and stream IO; lower-level types remain available for
packed rows, progressive input, transforms, metadata, and controlled writing.

## Dependency

```toml
[package]
link-option = "-lz"

[dependencies]
libpng4cj = { git = "https://gitcode.com/cinyu/libpng4cj.git" }
```

libpng4cj uses the system zlib implementation, matching upstream libpng's
dependency boundary. The final executable must link `-lz` because cjpm does not
propagate static-library link options to consumers.

```cangjie
import libpng4cj.*
```

## Simplified Read

Read from memory and request an owned 8-bit pixel buffer:

```cangjie
let image = beginPngImageReadFromMemory(pngBytes)
let rgba = image.finishRead(ImageRgba8)

println("${rgba.width()} x ${rgba.height()}")
let pixels = rgba.bytes()
```

Supported direct layouts are Gray, GrayAlpha, AlphaGray, RGB, BGR, RGBA,
ARGB, BGRA, and ABGR. Positive and negative row strides are supported through
the `finishReadStrided` family.

Use the file and stream helpers when the input should not be assembled by the
caller:

```cangjie
let image = beginPngImageReadFromFile("input.png")
let bgra = image.finishRead(ImageBgra8)
```

For host-numeric linear output, use `finishReadLinear`. For indexed output,
use `finishReadColormap`.

## Simplified Write

Write an owned image buffer to memory:

```cangjie
let encoded = writePngImageToMemory(rgba)
```

The same image families can be written to a file or stream:

```cangjie
writePngImageToFile(rgba, "output.png")
```

Advanced writes can supply metadata, compression controls, interlace mode, and
limits:

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

## Packed Row Decode

`decodePng` returns copy-owned packed source rows and retained metadata:

```cangjie
let decoded = decodePng(pngBytes)
let ihdr = decoded.ihdr
let firstRow = decoded.rows[0]
```

Use `decodePngRgba8` or `decodePngRgba16` when a canonical RGBA result is more
useful. The generic decode path accepts both non-interlaced and Adam7 images.
The `*NonInterlaced` variants intentionally reject Adam7 input.

## Packed Row Encode

`encodePngPacked` accepts PNG-shaped rows. All legal PNG color type and bit
depth combinations are supported:

```cangjie
let encoded = encodePngPacked(
    UInt32(2), UInt32(2), UInt8(8), TruecolorAlpha,
    [
        [255, 0, 0, 255, 0, 255, 0, 255],
        [0, 0, 255, 255, 255, 255, 255, 255]
    ]
)
```

Use `encodePngPackedAdam7` for interlaced output and
`encodeIndexedPngPackedAdam7` for indexed interlaced output.

## Progressive Read

The progressive reader accepts fragmented input and delivers owned info, row,
and end callback values. It supports pause, resume, completion, failure, and
explicit close states. Non-interlaced rows can be delivered before IEND;
Adam7 callbacks include pass and image-row context.

Use progressive input when data arrives from a network or another chunked
transport and buffering the complete PNG is undesirable.

## Streaming Write

`PngWriteSink` receives a copy-owned signature or framed PNG chunk and an exact
output context. Its flush callback runs once after IEND:

```cangjie
let sink = PngWriteSink()
sink.setWriteCallback({ context, bytes => output.write(bytes) })
sink.setFlushCallback({ context => output.flush() })

let receipt = session.writeTo(rows, sink)
```

Row-at-a-time sessions support bounded non-interlaced deflate and Adam7 output.
Input rows remain caller-owned.

## Metadata

The native model retains standard PNG metadata including PLTE, tRNS, gAMA,
cHRM, sRGB, sBIT, bKGD, pHYs, iCCP, text chunks, tIME, cICP, cLLI, mDCV, eXIf,
hIST, oFFs, pCAL, sCAL, sPLT, and configured unknown chunks.

Write metadata is supplied through `PngWriteMetadata`. Unknown chunks require
an explicit placement and policy so invalid critical chunks are not emitted by
accident.

## Limits And Errors

`PngReadLimits`, `PngWriteLimits`, and `PngSimplifiedIoLimits` bound dimensions,
chunk allocation, compressed data, inflated rows, transformed output, complete
encoded output, and simplified IO input. Prefer explicit limits for untrusted
input.

Public operations report stable Cangjie errors instead of exposing zlib status
or C pointers as ownership mechanisms.

## Detailed Surfaces

- [Compatibility and dependency matrix](COMPATIBILITY_AND_DEPENDENCY_MATRIX.md)
- [C ABI surfaces](ABI_PREVIEW.md)
- [Porting status](PORTING_MAP.md)
- [Read-transform alignment](PNG_RTRAN_TRANSLATION_LEDGER.md)
- [Write-transform alignment](PNG_WTRAN_TRANSLATION_LEDGER.md)
