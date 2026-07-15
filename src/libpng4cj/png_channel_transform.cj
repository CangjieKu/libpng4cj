package libpng4cj

public enum PngReadChannelTransform <: Equatable<PngReadChannelTransform> & ToString {
    | InvertMonochrome
    | InvertAlpha
    | Bgr
    | SwapAlpha

    public operator func ==(right: PngReadChannelTransform): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngReadChannelTransform): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case InvertMonochrome => 0
            case InvertAlpha => 1
            case Bgr => 2
            case SwapAlpha => 3
        }
    }

    public func toString(): String {
        match (this) {
            case InvertMonochrome => "INVERT_MONOCHROME"
            case InvertAlpha => "INVERT_ALPHA"
            case Bgr => "BGR"
            case SwapAlpha => "SWAP_ALPHA"
        }
    }
}

public enum PngRgbaLayout <: Equatable<PngRgbaLayout> & ToString {
    | Rgba
    | Bgra
    | Argb
    | Abgr

    public operator func ==(right: PngRgbaLayout): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngRgbaLayout): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Rgba => 0
            case Bgra => 1
            case Argb => 2
            case Abgr => 3
        }
    }

    public func toString(): String {
        match (this) {
            case Rgba => "RGBA"
            case Bgra => "BGRA"
            case Argb => "ARGB"
            case Abgr => "ABGR"
        }
    }
}

let PNG_NO_READ_CHANNEL_TRANSFORMS: Array<PngReadChannelTransform> = []

class ResolvedPngChannelTransforms {
    let invertMonochrome: Bool
    let invertAlpha: Bool
    let bgr: Bool
    let swapAlpha: Bool
    let layout: PngRgbaLayout

    init(
        invertMonochrome: Bool,
        invertAlpha: Bool,
        bgr: Bool,
        swapAlpha: Bool,
        layout: PngRgbaLayout
    ) {
        this.invertMonochrome = invertMonochrome
        this.invertAlpha = invertAlpha
        this.bgr = bgr
        this.swapAlpha = swapAlpha
        this.layout = layout
    }
}

func hasPngReadChannelTransform(
    transforms: Array<PngReadChannelTransform>,
    expected: PngReadChannelTransform
): Bool {
    var index: Int64 = 0
    while (index < transforms.size) {
        if (transforms[index] == expected) {
            return true
        }
        index += 1
    }
    false
}

func pngHasSemanticAlpha(ihdr: PngIhdr, metadata: PngReadMetadata): Bool {
    ihdr.colorType == GrayscaleAlpha || ihdr.colorType == TruecolorAlpha ||
        metadata.hasTransparency
}

func resolvePngChannelTransforms(
    ihdr: PngIhdr,
    metadata: PngReadMetadata,
    transforms: Array<PngReadChannelTransform>
): ResolvedPngChannelTransforms {
    let semanticAlpha = pngHasSemanticAlpha(ihdr, metadata)
    let invertMonochrome = hasPngReadChannelTransform(transforms, InvertMonochrome) &&
        (ihdr.colorType == Grayscale || ihdr.colorType == GrayscaleAlpha)
    let invertAlpha = semanticAlpha && hasPngReadChannelTransform(transforms, InvertAlpha)
    let bgr = hasPngReadChannelTransform(transforms, Bgr)
    let swapAlpha = semanticAlpha && hasPngReadChannelTransform(transforms, SwapAlpha)
    let layout = if (swapAlpha) {
        if (bgr) { Abgr } else { Argb }
    } else {
        if (bgr) { Bgra } else { Rgba }
    }
    ResolvedPngChannelTransforms(
        invertMonochrome,
        invertAlpha,
        bgr,
        swapAlpha,
        layout
    )
}

private func swapByte(row: Array<Byte>, left: Int64, right: Int64): Unit {
    let value = row[left]
    row[left] = row[right]
    row[right] = value
}

private func swapUInt16(row: Array<UInt16>, left: Int64, right: Int64): Unit {
    let value = row[left]
    row[left] = row[right]
    row[right] = value
}

func applyPngChannelTransforms8(
    row: Array<Byte>,
    resolved: ResolvedPngChannelTransforms
): Unit {
    var offset: Int64 = 0
    while (offset < row.size) {
        if (resolved.invertMonochrome) {
            row[offset] = UInt8(0xff) - row[offset]
            row[offset + 1] = UInt8(0xff) - row[offset + 1]
            row[offset + 2] = UInt8(0xff) - row[offset + 2]
        }
        if (resolved.invertAlpha) {
            row[offset + 3] = UInt8(0xff) - row[offset + 3]
        }
        if (resolved.bgr) {
            swapByte(row, offset, offset + 2)
        }
        if (resolved.swapAlpha) {
            let alpha = row[offset + 3]
            row[offset + 3] = row[offset + 2]
            row[offset + 2] = row[offset + 1]
            row[offset + 1] = row[offset]
            row[offset] = alpha
        }
        offset += 4
    }
}

func applyPngChannelTransforms16(
    row: Array<UInt16>,
    resolved: ResolvedPngChannelTransforms
): Unit {
    var offset: Int64 = 0
    while (offset < row.size) {
        if (resolved.invertMonochrome) {
            row[offset] = UInt16(0xffff) - row[offset]
            row[offset + 1] = UInt16(0xffff) - row[offset + 1]
            row[offset + 2] = UInt16(0xffff) - row[offset + 2]
        }
        if (resolved.invertAlpha) {
            row[offset + 3] = UInt16(0xffff) - row[offset + 3]
        }
        if (resolved.bgr) {
            swapUInt16(row, offset, offset + 2)
        }
        if (resolved.swapAlpha) {
            let alpha = row[offset + 3]
            row[offset + 3] = row[offset + 2]
            row[offset + 2] = row[offset + 1]
            row[offset + 1] = row[offset]
            row[offset] = alpha
        }
        offset += 4
    }
}
