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
    public let transparencyCount: Int64
    public let hasBackground: Bool
    public let hasGamma: Bool
    public let gamma: Int32
    public let hasPalette: Bool
    private let ownedPalette: Array<Byte>
    private let ownedBackground: PngBackground

    init(
        ihdr: PngIhdr,
        bitDepth: UInt8,
        colorType: PngColorType,
        channels: UInt8,
        transparencyCount: Int64,
        hasBackground: Bool,
        background: PngBackground,
        hasGamma: Bool,
        gamma: Int32,
        palette: Array<Byte>
    ) {
        width = ihdr.width
        height = ihdr.height
        this.bitDepth = bitDepth
        this.colorType = colorType
        this.channels = channels
        pixelDepth = UInt16(bitDepth) * UInt16(channels)
        rowBytes = (UInt64(width) * UInt64(pixelDepth) + UInt64(7)) / UInt64(8)
        this.transparencyCount = transparencyCount
        hasTransparency = transparencyCount != 0
        this.hasBackground = hasBackground
        ownedBackground = PngBackground(background)
        this.hasGamma = hasGamma
        this.gamma = gamma
        ownedPalette = palette.clone()
        hasPalette = ownedPalette.size != 0
    }

    public func background(): PngBackground {
        if (!hasBackground) {
            throw PngFormatException(
                InvalidMetadata,
                -1,
                "projected PNG info has no background metadata"
            )
        }
        PngBackground(ownedBackground)
    }

    public func palette(): Array<Byte> {
        ownedPalette.clone()
    }

    public func paletteEntryCount(): Int64 {
        ownedPalette.size / 3
    }

    public func paletteEntry(index: Int64): Array<Byte> {
        if (index < 0 || index >= paletteEntryCount()) {
            throw PngFormatException(
                PaletteIndexOutOfRange,
                index,
                "projected PNG palette index is out of bounds"
            )
        }
        copyByteRange(ownedPalette, index * 3, 3)
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

private func pngProjectedTransparencyCount(
    initialization: PngReadTransformInitialization,
    ihdr: PngIhdr,
    metadata: PngReadMetadata
): Int64 {
    if (!metadata.hasTransparency || initialization.transparencyStripped) {
        return Int64(0)
    }
    if (ihdr.colorType == Indexed) {
        return if (initialization.usesPaletteInitializer) {
            initialization.effectivePaletteAlpha().size
        } else {
            metadata.paletteAlpha().size
        }
    }
    Int64(1)
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
    var transparencyCount = pngProjectedTransparencyCount(
        initialization,
        ihdr,
        metadata
    )
    var palette = if (initialization.usesPaletteInitializer) {
        initialization.effectivePalette()
    } else {
        metadata.palette()
    }
    var hasBackground = metadata.hasBackground
    var background = PngBackground(metadata.background)
    if (initialization.composeEnabled()) {
        hasBackground = true
        background = initialization.background()
    }
    let hasGamma = metadata.hasGamma || initialization.gammaConfigured() ||
        initialization.alphaModeConfigured()
    let gamma = initialization.fileGamma()

    if (initialization.quantizeEnabled()) {
        palette = initialization.quantizePalette()
        let paletteCount = initialization.quantizePaletteCount()
        if (paletteCount <= 0 || paletteCount > 256 ||
            palette.size != paletteCount * 3) {
            throw PngFormatException(
                InvalidPalette,
                paletteCount,
                "initialized quantize palette is inconsistent"
            )
        }
    }

    if (initialization.hasStage(ReadStageExpand)) {
        if (colorType == Indexed) {
            if (!metadata.hasPalette) {
                throw PngFormatException(
                    InvalidPalette,
                    -1,
                    "indexed transform info projection requires a retained palette"
                )
            }
            colorType = if (transparencyCount != 0) {
                TruecolorAlpha
            } else {
                Truecolor
            }
            bitDepth = UInt8(8)
        } else {
            if (transparencyCount != 0 &&
                initialization.effectiveTransparencyExpansion) {
                colorType = pngColorTypeWithAlpha(colorType)
            }
            if (bitDepth < UInt8(8)) {
                bitDepth = UInt8(8)
            }
        }
        transparencyCount = Int64(0)
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

    if (initialization.hasStage(ReadStageQuantize) &&
        (colorType == Truecolor || colorType == TruecolorAlpha) &&
        initialization.quantizePaletteLookupAvailable() &&
        bitDepth == UInt8(8)) {
        colorType = Indexed
    }

    if (initialization.hasStage(ReadStageExpand16) &&
        bitDepth == UInt8(8) && colorType != Indexed) {
        bitDepth = UInt8(16)
    }

    if (initialization.hasStage(ReadStageUnpack) && bitDepth < UInt8(8)) {
        bitDepth = UInt8(8)
    }

    if (initialization.hasStage(ReadStageStripAlpha) ||
        initialization.hasStage(ReadStageStripAlphaAfterCompose)) {
        colorType = pngColorTypeWithoutAlpha(colorType)
        transparencyCount = Int64(0)
    }

    var channels = colorType.channels()
    if (initialization.hasStage(ReadStageFiller) &&
        (colorType == Grayscale || colorType == Truecolor)) {
        channels += UInt8(1)
        if (initialization.addAlphaEnabled()) {
            colorType = pngColorTypeWithAlpha(colorType)
        }
    }
    if (initialization.hasStage(ReadStageUserTransform)) {
        if (initialization.userTransformDepth() != UInt8(0)) {
            bitDepth = initialization.userTransformDepth()
        }
        if (initialization.userTransformChannels() != UInt8(0)) {
            channels = initialization.userTransformChannels()
        }
    }

    PngReadTransformInfo(
        ihdr,
        bitDepth,
        colorType,
        channels,
        transparencyCount,
        hasBackground,
        background,
        hasGamma,
        gamma,
        palette
    )
}
