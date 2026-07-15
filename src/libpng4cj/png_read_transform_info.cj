package libpng4cj

public class PngReadTransformInfo {
    public let width: UInt32
    public let height: UInt32
    public let bitDepth: UInt8
    public let colorType: PngColorType
    public let channels: UInt8
    public let pixelDepth: UInt16
    public let rowBytes: UInt64
    public let hasTransparency: Bool

    init(
        ihdr: PngIhdr,
        bitDepth: UInt8,
        colorType: PngColorType,
        hasTransparency: Bool
    ) {
        width = ihdr.width
        height = ihdr.height
        this.bitDepth = bitDepth
        this.colorType = colorType
        channels = colorType.channels()
        pixelDepth = UInt16(bitDepth) * UInt16(channels)
        rowBytes = (UInt64(width) * UInt64(pixelDepth) + UInt64(7)) / UInt64(8)
        this.hasTransparency = hasTransparency
    }
}

private func pngColorTypeWithAlpha(colorType: PngColorType): PngColorType {
    match (colorType) {
        case Grayscale => GrayscaleAlpha
        case Truecolor => TruecolorAlpha
        case _ => colorType
    }
}

private func pngColorTypeWithoutAlpha(colorType: PngColorType): PngColorType {
    match (colorType) {
        case GrayscaleAlpha => Grayscale
        case TruecolorAlpha => Truecolor
        case _ => colorType
    }
}

private func pngColorTypeWithColor(colorType: PngColorType): PngColorType {
    match (colorType) {
        case Grayscale => Truecolor
        case GrayscaleAlpha => TruecolorAlpha
        case _ => colorType
    }
}

private func pngColorTypeWithoutColor(colorType: PngColorType): PngColorType {
    match (colorType) {
        case Truecolor => Grayscale
        case TruecolorAlpha => GrayscaleAlpha
        case _ => colorType
    }
}

public func projectPngReadTransformInfo(
    initialization: PngReadTransformInitialization,
    decoded: PngDecodedRows
): PngReadTransformInfo {
    projectPngReadTransformInfo(initialization, decoded.ihdr, decoded.metadata)
}

public func projectPngReadTransformInfo(
    initialization: PngReadTransformInitialization,
    ihdr: PngIhdr,
    metadata: PngReadMetadata
): PngReadTransformInfo {
    var bitDepth = ihdr.bitDepth
    var colorType = ihdr.colorType
    var hasTransparency = metadata.hasTransparency && !initialization.transparencyStripped

    if (initialization.hasStage(ReadStageExpand)) {
        if (colorType == Indexed) {
            if (!metadata.hasPalette) {
                throw PngFormatException(
                    InvalidPalette,
                    -1,
                    "indexed transform info projection requires a retained palette"
                )
            }
            colorType = if (hasTransparency) { TruecolorAlpha } else { Truecolor }
            bitDepth = UInt8(8)
        } else {
            if (hasTransparency && initialization.effectiveTransparencyExpansion) {
                colorType = pngColorTypeWithAlpha(colorType)
            }
            if (bitDepth < UInt8(8)) {
                bitDepth = UInt8(8)
            }
        }
        hasTransparency = false
    }

    if (bitDepth == UInt8(16) &&
        (initialization.hasStage(ReadStageScale16To8) ||
        initialization.hasStage(ReadStageStrip16To8))) {
        bitDepth = UInt8(8)
    }

    if (initialization.hasStage(ReadStageGrayToRgb)) {
        colorType = pngColorTypeWithColor(colorType)
    }
    if (initialization.hasStage(ReadStageRgbToGray)) {
        colorType = pngColorTypeWithoutColor(colorType)
    }

    if (initialization.hasStage(ReadStageExpand16) &&
        bitDepth == UInt8(8) && colorType != Indexed) {
        bitDepth = UInt8(16)
    }

    if (initialization.hasStage(ReadStageStripAlpha)) {
        colorType = pngColorTypeWithoutAlpha(colorType)
        hasTransparency = false
    }

    PngReadTransformInfo(ihdr, bitDepth, colorType, hasTransparency)
}
