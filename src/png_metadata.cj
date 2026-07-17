package libpng4cj

class ParsedPngTransparency {
    let present: Bool
    let paletteAlpha: Array<Byte>
    let gray: UInt16
    let red: UInt16
    let green: UInt16
    let blue: UInt16

    init() {
        present = false
        paletteAlpha = Array<Byte>()
        gray = UInt16(0)
        red = UInt16(0)
        green = UInt16(0)
        blue = UInt16(0)
    }

    init(alpha: Array<Byte>) {
        present = true
        paletteAlpha = alpha.clone()
        gray = UInt16(0)
        red = UInt16(0)
        green = UInt16(0)
        blue = UInt16(0)
    }

    init(gray: UInt16) {
        present = true
        paletteAlpha = Array<Byte>()
        this.gray = gray
        red = UInt16(0)
        green = UInt16(0)
        blue = UInt16(0)
    }

    init(red: UInt16, green: UInt16, blue: UInt16) {
        present = true
        paletteAlpha = Array<Byte>()
        gray = UInt16(0)
        this.red = red
        this.green = green
        this.blue = blue
    }
}

public enum PngSrgbIntent <: Equatable<PngSrgbIntent> & ToString {
    | Perceptual
    | RelativeColorimetric
    | Saturation
    | AbsoluteColorimetric

    public operator func ==(right: PngSrgbIntent): Bool {
        encodedValue() == right.encodedValue()
    }

    public operator func !=(right: PngSrgbIntent): Bool {
        !(this == right)
    }

    public func encodedValue(): UInt8 {
        match (this) {
            case Perceptual => UInt8(0)
            case RelativeColorimetric => UInt8(1)
            case Saturation => UInt8(2)
            case AbsoluteColorimetric => UInt8(3)
        }
    }

    public func toString(): String {
        match (this) {
            case Perceptual => "PERCEPTUAL"
            case RelativeColorimetric => "RELATIVE_COLORIMETRIC"
            case Saturation => "SATURATION"
            case AbsoluteColorimetric => "ABSOLUTE_COLORIMETRIC"
        }
    }
}

public class PngChromaticities {
    public let whiteX: Int32
    public let whiteY: Int32
    public let redX: Int32
    public let redY: Int32
    public let greenX: Int32
    public let greenY: Int32
    public let blueX: Int32
    public let blueY: Int32

    init() {
        whiteX = Int32(0)
        whiteY = Int32(0)
        redX = Int32(0)
        redY = Int32(0)
        greenX = Int32(0)
        greenY = Int32(0)
        blueX = Int32(0)
        blueY = Int32(0)
    }

    public init(
        whiteX: Int32,
        whiteY: Int32,
        redX: Int32,
        redY: Int32,
        greenX: Int32,
        greenY: Int32,
        blueX: Int32,
        blueY: Int32
    ) {
        this.whiteX = whiteX
        this.whiteY = whiteY
        this.redX = redX
        this.redY = redY
        this.greenX = greenX
        this.greenY = greenY
        this.blueX = blueX
        this.blueY = blueY
    }
}

public class PngSignificantBits {
    public let gray: UInt8
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let alpha: UInt8

    init() {
        gray = UInt8(0)
        red = UInt8(0)
        green = UInt8(0)
        blue = UInt8(0)
        alpha = UInt8(0)
    }

    public init(gray: UInt8, red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        this.gray = gray
        this.red = red
        this.green = green
        this.blue = blue
        this.alpha = alpha
    }
}

public class PngBackground {
    public let index: UInt8
    public let gray: UInt16
    public let red: UInt16
    public let green: UInt16
    public let blue: UInt16

    public init() {
        index = UInt8(0)
        gray = UInt16(0)
        red = UInt16(0)
        green = UInt16(0)
        blue = UInt16(0)
    }

    public init(
        index: UInt8,
        gray: UInt16,
        red: UInt16,
        green: UInt16,
        blue: UInt16
    ) {
        this.index = index
        this.gray = gray
        this.red = red
        this.green = green
        this.blue = blue
    }

    public init(other: PngBackground) {
        index = other.index
        gray = other.gray
        red = other.red
        green = other.green
        blue = other.blue
    }
}

public class PngPhysicalDimensions {
    public let pixelsPerUnitX: UInt32
    public let pixelsPerUnitY: UInt32
    public let unit: UInt8

    init() {
        pixelsPerUnitX = UInt32(0)
        pixelsPerUnitY = UInt32(0)
        unit = UInt8(0)
    }

    public init(pixelsPerUnitX: UInt32, pixelsPerUnitY: UInt32, unit: UInt8) {
        this.pixelsPerUnitX = pixelsPerUnitX
        this.pixelsPerUnitY = pixelsPerUnitY
        this.unit = unit
    }
}

class ParsedPngMetadata {
    var hasGamma: Bool = false
    var gamma: UInt32 = UInt32(0)
    var hasChromaticities: Bool = false
    var chromaticities: PngChromaticities = PngChromaticities()
    var hasSrgb: Bool = false
    var srgbIntent: PngSrgbIntent = Perceptual
    var hasSignificantBits: Bool = false
    var significantBits: PngSignificantBits = PngSignificantBits()
    var hasBackground: Bool = false
    var background: PngBackground = PngBackground()
    var hasPhysicalDimensions: Bool = false
    var physicalDimensions: PngPhysicalDimensions = PngPhysicalDimensions()
    let ancillary: ParsedPngAncillaryMetadata = ParsedPngAncillaryMetadata()
    let extended: ParsedExtendedMetadata = ParsedExtendedMetadata()
}

public class PngReadMetadata {
    public let hasPalette: Bool
    public let hasTransparency: Bool
    public let hasGamma: Bool
    public let gamma: UInt32
    public let hasChromaticities: Bool
    public let chromaticities: PngChromaticities
    public let hasSrgb: Bool
    public let srgbIntent: PngSrgbIntent
    public let hasSignificantBits: Bool
    public let significantBits: PngSignificantBits
    public let hasBackground: Bool
    public let background: PngBackground
    public let hasPhysicalDimensions: Bool
    public let physicalDimensions: PngPhysicalDimensions
    public let hasCodingIndependentCodePoints: Bool
    public let codingIndependentCodePoints: PngCodingIndependentCodePoints
    public let hasContentLightLevel: Bool
    public let contentLightLevel: PngContentLightLevel
    public let hasMasteringDisplayColorVolume: Bool
    public let masteringDisplayColorVolume: PngMasteringDisplayColorVolume
    public let hasExif: Bool
    public let hasHistogram: Bool
    public let hasImageOffset: Bool
    public let imageOffset: PngImageOffset
    public let hasPixelCalibration: Bool
    public let pixelCalibration: PngPixelCalibration
    public let hasPhysicalScale: Bool
    public let physicalScale: PngPhysicalScale
    public let hasIccProfile: Bool
    public let iccProfile: PngIccProfile
    public let hasModificationTime: Bool
    public let modificationTime: PngModificationTime
    public let transparentGray: UInt16
    public let transparentRed: UInt16
    public let transparentGreen: UInt16
    public let transparentBlue: UInt16
    private let ownedPalette: Array<Byte>
    private let ownedPaletteAlpha: Array<Byte>
    private let ownedExif: Array<Byte>
    private let ownedHistogram: Array<UInt16>
    private let ownedSuggestedPalettes: Array<PngSuggestedPalette>
    private let ownedTextEntries: Array<PngTextEntry>
    private let ownedUnknownChunks: Array<PngUnknownChunk>

    init(
        palette: Array<Byte>,
        transparency: ParsedPngTransparency,
        parsed: ParsedPngMetadata
    ) {
        ownedPalette = palette.clone()
        ownedPaletteAlpha = transparency.paletteAlpha.clone()
        hasPalette = ownedPalette.size != 0
        hasTransparency = transparency.present
        hasGamma = parsed.hasGamma
        gamma = parsed.gamma
        hasChromaticities = parsed.hasChromaticities
        chromaticities = parsed.chromaticities
        hasSrgb = parsed.hasSrgb
        srgbIntent = parsed.srgbIntent
        hasSignificantBits = parsed.hasSignificantBits
        significantBits = parsed.significantBits
        hasBackground = parsed.hasBackground
        background = parsed.background
        hasPhysicalDimensions = parsed.hasPhysicalDimensions
        physicalDimensions = parsed.physicalDimensions
        hasCodingIndependentCodePoints = parsed.ancillary.hasCicp
        codingIndependentCodePoints = parsed.ancillary.cicp
        hasContentLightLevel = parsed.ancillary.hasContentLightLevel
        contentLightLevel = parsed.ancillary.contentLightLevel
        hasMasteringDisplayColorVolume = parsed.ancillary.hasMasteringDisplay
        masteringDisplayColorVolume = parsed.ancillary.masteringDisplay
        hasExif = parsed.ancillary.hasExif
        ownedExif = parsed.ancillary.exif.clone()
        hasHistogram = parsed.ancillary.hasHistogram
        ownedHistogram = parsed.ancillary.histogram.clone()
        hasImageOffset = parsed.ancillary.hasOffset
        imageOffset = parsed.ancillary.imageOffset
        hasPixelCalibration = parsed.ancillary.hasCalibration
        pixelCalibration = parsed.ancillary.calibration
        hasPhysicalScale = parsed.ancillary.hasPhysicalScale
        physicalScale = parsed.ancillary.physicalScale
        ownedSuggestedPalettes = parsed.ancillary.suggestedPalettes()
        hasIccProfile = parsed.extended.hasIccProfile
        iccProfile = parsed.extended.iccProfile
        hasModificationTime = parsed.extended.hasModificationTime
        modificationTime = parsed.extended.modificationTime
        ownedTextEntries = parsed.extended.textEntries()
        ownedUnknownChunks = parsed.extended.unknownChunks()
        transparentGray = transparency.gray
        transparentRed = transparency.red
        transparentGreen = transparency.green
        transparentBlue = transparency.blue
    }

    public func palette(): Array<Byte> {
        ownedPalette.clone()
    }

    public func paletteAlpha(): Array<Byte> {
        ownedPaletteAlpha.clone()
    }

    public func exif(): Array<Byte> {
        ownedExif.clone()
    }

    public func histogram(): Array<UInt16> {
        ownedHistogram.clone()
    }

    public func suggestedPaletteCount(): Int64 {
        ownedSuggestedPalettes.size
    }

    public func suggestedPalette(index: Int64): PngSuggestedPalette {
        if (index < 0 || index >= ownedSuggestedPalettes.size) {
            throw PngFormatException(InvalidArgument, index, "PNG suggested palette index is out of bounds")
        }
        ownedSuggestedPalettes[index]
    }

    public func suggestedPalettes(): Array<PngSuggestedPalette> {
        ownedSuggestedPalettes.clone()
    }

    public func textEntryCount(): Int64 {
        ownedTextEntries.size
    }

    public func textEntry(index: Int64): PngTextEntry {
        if (index < 0 || index >= ownedTextEntries.size) {
            throw PngFormatException(InvalidArgument, index, "PNG text entry index is out of bounds")
        }
        ownedTextEntries[index]
    }

    public func textEntries(): Array<PngTextEntry> {
        ownedTextEntries.clone()
    }

    public func unknownChunkCount(): Int64 {
        ownedUnknownChunks.size
    }

    public func unknownChunk(index: Int64): PngUnknownChunk {
        if (index < 0 || index >= ownedUnknownChunks.size) {
            throw PngFormatException(InvalidArgument, index, "PNG unknown chunk index is out of bounds")
        }
        ownedUnknownChunks[index]
    }

    public func unknownChunks(): Array<PngUnknownChunk> {
        ownedUnknownChunks.clone()
    }

    public func paletteEntryCount(): Int64 {
        ownedPalette.size / 3
    }

    private func validatePaletteIndex(index: Int64): Unit {
        if (index < 0 || index >= paletteEntryCount()) {
            throw PngFormatException(
                PaletteIndexOutOfRange,
                index,
                "PNG palette index is outside the declared PLTE"
            )
        }
    }

    public func paletteEntry(index: Int64): Array<Byte> {
        validatePaletteIndex(index)
        copyByteRange(ownedPalette, index * 3, 3)
    }

    func paletteRed(index: Int64): UInt8 {
        validatePaletteIndex(index)
        ownedPalette[index * 3]
    }

    func paletteGreen(index: Int64): UInt8 {
        validatePaletteIndex(index)
        ownedPalette[index * 3 + 1]
    }

    func paletteBlue(index: Int64): UInt8 {
        validatePaletteIndex(index)
        ownedPalette[index * 3 + 2]
    }

    public func paletteAlphaAt(index: Int64): UInt8 {
        validatePaletteIndex(index)
        if (index < ownedPaletteAlpha.size) {
            ownedPaletteAlpha[index]
        } else {
            UInt8(0xff)
        }
    }
}

private func parseSrgbIntent(value: UInt8, offset: Int64): PngSrgbIntent {
    match (value) {
        case 0 => Perceptual
        case 1 => RelativeColorimetric
        case 2 => Saturation
        case 3 => AbsoluteColorimetric
        case _ => throw PngFormatException(
            InvalidMetadata,
            offset,
            "sRGB rendering intent must be in 0..3"
        )
    }
}

private func readInt32BeChecked(bytes: Array<Byte>, offset: Int64, sourceOffset: Int64): Int32 {
    let value = readUInt32Be(bytes, offset)
    if (value <= PNG_UINT_31_MAX) {
        return Int32(value)
    }
    if (value == UInt32(0x8000_0000)) {
        throw PngFormatException(
            InvalidMetadata,
            sourceOffset + offset,
            "cHRM fixed-point value cannot encode INT32_MIN"
        )
    }
    let magnitude = (value ^ UInt32(0xffff_ffff)) + UInt32(1)
    -Int32(magnitude)
}

private func parseSignificantBits(data: Array<Byte>, ihdr: PngIhdr, offset: Int64): PngSignificantBits {
    let sampleDepth = if (ihdr.colorType == Indexed) { UInt8(8) } else { ihdr.bitDepth }
    let expectedLength = if (ihdr.colorType == Indexed) { Int64(3) } else { Int64(ihdr.channels) }
    if (data.size != expectedLength) {
        throw PngFormatException(InvalidMetadata, offset, "sBIT length does not match the PNG color type")
    }
    var index: Int64 = 0
    while (index < data.size) {
        if (data[index] == UInt8(0) || data[index] > sampleDepth) {
            throw PngFormatException(
                InvalidMetadata,
                offset + index,
                "sBIT values must be in 1..source sample depth"
            )
        }
        index += 1
    }
    match (ihdr.colorType) {
        case Grayscale => PngSignificantBits(data[0], data[0], data[0], data[0], sampleDepth)
        case Truecolor => PngSignificantBits(UInt8(0), data[0], data[1], data[2], sampleDepth)
        case Indexed => PngSignificantBits(UInt8(0), data[0], data[1], data[2], sampleDepth)
        case GrayscaleAlpha => PngSignificantBits(data[0], data[0], data[0], data[0], data[1])
        case TruecolorAlpha => PngSignificantBits(UInt8(0), data[0], data[1], data[2], data[3])
    }
}

private func parseBackground(
    data: Array<Byte>,
    ihdr: PngIhdr,
    palette: Array<Byte>,
    offset: Int64
): PngBackground {
    match (ihdr.colorType) {
        case Indexed =>
            if (palette.size == 0) {
                throw PngFormatException(MetadataOutOfOrder, offset, "indexed bKGD requires PLTE first")
            }
            if (data.size != 1) {
                throw PngFormatException(InvalidMetadata, offset, "indexed bKGD length must be 1")
            }
            let index = Int64(data[0])
            let paletteEntries = palette.size / 3
            if (index >= paletteEntries) {
                throw PngFormatException(InvalidMetadata, offset, "bKGD palette index is outside PLTE")
            }
            PngBackground(
                data[0],
                UInt16(0),
                UInt16(palette[index * 3]),
                UInt16(palette[index * 3 + 1]),
                UInt16(palette[index * 3 + 2])
            )
        case Grayscale | GrayscaleAlpha =>
            if (data.size != 2) {
                throw PngFormatException(InvalidMetadata, offset, "grayscale bKGD length must be 2")
            }
            let gray = readUInt16Be(data, 0)
            if (ihdr.bitDepth <= UInt8(8)) {
                let maximum = UInt16(1) << UInt16(ihdr.bitDepth)
                if (data[0] != UInt8(0) || gray >= maximum) {
                    throw PngFormatException(InvalidMetadata, offset, "bKGD gray sample exceeds source depth")
                }
            }
            PngBackground(UInt8(0), gray, gray, gray, gray)
        case Truecolor | TruecolorAlpha =>
            if (data.size != 6) {
                throw PngFormatException(InvalidMetadata, offset, "truecolor bKGD length must be 6")
            }
            if (ihdr.bitDepth <= UInt8(8) &&
                (data[0] != UInt8(0) || data[2] != UInt8(0) || data[4] != UInt8(0))) {
                throw PngFormatException(InvalidMetadata, offset, "bKGD color sample exceeds source depth")
            }
            PngBackground(
                UInt8(0),
                UInt16(0),
                readUInt16Be(data, 0),
                readUInt16Be(data, 2),
                readUInt16Be(data, 4)
            )
    }
}

class PngMetadataBuilder {
    private let parsed = ParsedPngMetadata()

    func hasBackground(): Bool {
        parsed.hasBackground
    }

    func handleChunk(
        chunk: PngChunk,
        ihdr: PngIhdr,
        seenPalette: Bool,
        seenIdat: Bool,
        palette: Array<Byte>,
        limits: PngReadLimits
    ): Bool {
        if (chunk.isType(PNG_CHUNK_gAMA)) {
            if (seenPalette || seenIdat) {
                throw PngFormatException(MetadataOutOfOrder, chunk.offset, "gAMA must precede PLTE and IDAT")
            }
            if (parsed.hasGamma) {
                throw PngFormatException(DuplicateMetadata, chunk.offset, "PNG contains more than one gAMA chunk")
            }
            if (chunk.length != UInt32(4)) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "gAMA length must be 4")
            }
            let gamma = readUInt32Be(chunk.payload(), 0)
            if (gamma > PNG_UINT_31_MAX) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "gAMA value exceeds PNG_UINT_31_MAX")
            }
            parsed.gamma = gamma
            parsed.hasGamma = true
            return true
        }
        if (chunk.isType(PNG_CHUNK_cHRM)) {
            if (seenPalette || seenIdat) {
                throw PngFormatException(MetadataOutOfOrder, chunk.offset, "cHRM must precede PLTE and IDAT")
            }
            if (parsed.hasChromaticities) {
                throw PngFormatException(DuplicateMetadata, chunk.offset, "PNG contains more than one cHRM chunk")
            }
            if (chunk.length != UInt32(32)) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "cHRM length must be 32")
            }
            let data = chunk.payload()
            let dataOffset = chunk.offset + 8
            parsed.chromaticities = PngChromaticities(
                readInt32BeChecked(data, 0, dataOffset),
                readInt32BeChecked(data, 4, dataOffset),
                readInt32BeChecked(data, 8, dataOffset),
                readInt32BeChecked(data, 12, dataOffset),
                readInt32BeChecked(data, 16, dataOffset),
                readInt32BeChecked(data, 20, dataOffset),
                readInt32BeChecked(data, 24, dataOffset),
                readInt32BeChecked(data, 28, dataOffset)
            )
            parsed.hasChromaticities = true
            return true
        }
        if (chunk.isType(PNG_CHUNK_sRGB)) {
            if (seenPalette || seenIdat) {
                throw PngFormatException(MetadataOutOfOrder, chunk.offset, "sRGB must precede PLTE and IDAT")
            }
            if (parsed.hasSrgb) {
                throw PngFormatException(DuplicateMetadata, chunk.offset, "PNG contains more than one sRGB chunk")
            }
            if (chunk.length != UInt32(1)) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "sRGB length must be 1")
            }
            parsed.srgbIntent = parseSrgbIntent(chunk.payload()[0], chunk.offset)
            parsed.hasSrgb = true
            return true
        }
        if (chunk.isType(PNG_CHUNK_sBIT)) {
            if (seenPalette || seenIdat) {
                throw PngFormatException(MetadataOutOfOrder, chunk.offset, "sBIT must precede PLTE and IDAT")
            }
            if (parsed.hasSignificantBits) {
                throw PngFormatException(DuplicateMetadata, chunk.offset, "PNG contains more than one sBIT chunk")
            }
            parsed.significantBits = parseSignificantBits(chunk.payload(), ihdr, chunk.offset)
            parsed.hasSignificantBits = true
            return true
        }
        if (chunk.isType(PNG_CHUNK_bKGD)) {
            if (seenIdat) {
                throw PngFormatException(MetadataOutOfOrder, chunk.offset, "bKGD must precede IDAT")
            }
            if (parsed.hasBackground) {
                throw PngFormatException(DuplicateMetadata, chunk.offset, "PNG contains more than one bKGD chunk")
            }
            parsed.background = parseBackground(chunk.payload(), ihdr, palette, chunk.offset)
            parsed.hasBackground = true
            return true
        }
        if (chunk.isType(PNG_CHUNK_pHYs)) {
            if (seenIdat) {
                throw PngFormatException(MetadataOutOfOrder, chunk.offset, "pHYs must precede IDAT")
            }
            if (parsed.hasPhysicalDimensions) {
                throw PngFormatException(DuplicateMetadata, chunk.offset, "PNG contains more than one pHYs chunk")
            }
            if (chunk.length != UInt32(9)) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "pHYs length must be 9")
            }
            let data = chunk.payload()
            parsed.physicalDimensions = PngPhysicalDimensions(
                readUInt32Be(data, 0),
                readUInt32Be(data, 4),
                data[8]
            )
            parsed.hasPhysicalDimensions = true
            return true
        }
        if (parsed.ancillary.handleChunk(chunk, seenPalette, seenIdat, palette)) {
            return true
        }
        handleExtendedMetadataChunk(parsed.extended, chunk, ihdr, seenPalette, seenIdat, limits)
    }

    func retainUnknown(
        chunk: PngChunk,
        seenPalette: Bool,
        seenIdat: Bool,
        policy: PngUnknownChunkPolicy
    ): Bool {
        if (!shouldRetainUnknown(chunk, policy)) {
            return false
        }
        parsed.extended.addUnknown(
            PngUnknownChunk(chunk.chunkType(), chunk.payload(), unknownChunkLocation(seenPalette, seenIdat))
        )
        true
    }

    func build(palette: Array<Byte>, transparency: ParsedPngTransparency): PngReadMetadata {
        PngReadMetadata(palette, transparency, parsed)
    }
}

func parsePngTransparencyChunk(
    chunk: PngChunk,
    ihdr: PngIhdr,
    palette: Array<Byte>
): ParsedPngTransparency {
    let data = chunk.payload()
    match (ihdr.colorType) {
        case Grayscale =>
            if (chunk.length != UInt32(2)) {
                throw PngFormatException(
                    InvalidTransparency,
                    chunk.offset,
                    "grayscale tRNS length must be 2"
                )
            }
            ParsedPngTransparency(readUInt16Be(data, 0))
        case Truecolor =>
            if (chunk.length != UInt32(6)) {
                throw PngFormatException(
                    InvalidTransparency,
                    chunk.offset,
                    "truecolor tRNS length must be 6"
                )
            }
            ParsedPngTransparency(
                readUInt16Be(data, 0),
                readUInt16Be(data, 2),
                readUInt16Be(data, 4)
            )
        case Indexed =>
            let paletteEntries = palette.size / 3
            if (paletteEntries == 0) {
                throw PngFormatException(
                    InvalidTransparency,
                    chunk.offset,
                    "indexed tRNS requires PLTE first"
                )
            }
            if (data.size == 0 || data.size > paletteEntries) {
                throw PngFormatException(
                    InvalidTransparency,
                    chunk.offset,
                    "indexed tRNS must contain 1..PLTE-entry-count alpha values"
                )
            }
            ParsedPngTransparency(data)
        case GrayscaleAlpha =>
            throw PngFormatException(
                InvalidTransparency,
                chunk.offset,
                "tRNS is not allowed for grayscale-alpha PNG images"
            )
        case TruecolorAlpha =>
            throw PngFormatException(
                InvalidTransparency,
                chunk.offset,
                "tRNS is not allowed for truecolor-alpha PNG images"
            )
    }
}
