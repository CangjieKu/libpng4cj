package libpng4cj

import std.collection.ArrayList

public enum PngWriteMetadataPlacement <: Equatable<PngWriteMetadataPlacement> & ToString {
    | WriteBeforeIdat
    | WriteAfterIdat

    public operator func ==(right: PngWriteMetadataPlacement): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngWriteMetadataPlacement): Bool {
        !(this == right)
    }

    private func ordinalValue(): Int64 {
        match (this) {
            case WriteBeforeIdat => Int64(0)
            case WriteAfterIdat => Int64(1)
        }
    }

    public func toString(): String {
        match (this) {
            case WriteBeforeIdat => "BEFORE_IDAT"
            case WriteAfterIdat => "AFTER_IDAT"
        }
    }
}

public enum PngWriteTransparencyKind <: Equatable<PngWriteTransparencyKind> & ToString {
    | PaletteTransparency
    | GrayscaleTransparency
    | TruecolorTransparency

    public operator func ==(right: PngWriteTransparencyKind): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngWriteTransparencyKind): Bool {
        !(this == right)
    }

    private func ordinalValue(): Int64 {
        match (this) {
            case PaletteTransparency => Int64(0)
            case GrayscaleTransparency => Int64(1)
            case TruecolorTransparency => Int64(2)
        }
    }

    public func toString(): String {
        match (this) {
            case PaletteTransparency => "PALETTE"
            case GrayscaleTransparency => "GRAYSCALE"
            case TruecolorTransparency => "TRUECOLOR"
        }
    }
}

public class PngWriteTransparency {
    public let kind: PngWriteTransparencyKind
    public let gray: UInt16
    public let red: UInt16
    public let green: UInt16
    public let blue: UInt16
    private let ownedPaletteAlpha: Array<Byte>

    public init(paletteAlpha: Array<Byte>) {
        kind = PaletteTransparency
        ownedPaletteAlpha = paletteAlpha.clone()
        gray = UInt16(0)
        red = UInt16(0)
        green = UInt16(0)
        blue = UInt16(0)
    }

    public init(gray: UInt16) {
        kind = GrayscaleTransparency
        ownedPaletteAlpha = Array<Byte>()
        this.gray = gray
        red = UInt16(0)
        green = UInt16(0)
        blue = UInt16(0)
    }

    public init(red: UInt16, green: UInt16, blue: UInt16) {
        kind = TruecolorTransparency
        ownedPaletteAlpha = Array<Byte>()
        gray = UInt16(0)
        this.red = red
        this.green = green
        this.blue = blue
    }

    public func paletteAlpha(): Array<Byte> {
        ownedPaletteAlpha.clone()
    }
}

class PngPlacedWriteText {
    let entry: PngTextEntry
    let placement: PngWriteMetadataPlacement

    init(entry: PngTextEntry, placement: PngWriteMetadataPlacement) {
        this.entry = pngCloneTextEntry(entry)
        this.placement = placement
    }
}

private func pngCloneChromaticities(value: PngChromaticities): PngChromaticities {
    PngChromaticities(
        value.whiteX, value.whiteY, value.redX, value.redY,
        value.greenX, value.greenY, value.blueX, value.blueY
    )
}

private func pngCloneSignificantBits(value: PngSignificantBits): PngSignificantBits {
    PngSignificantBits(value.gray, value.red, value.green, value.blue, value.alpha)
}

private func pngClonePhysicalDimensions(value: PngPhysicalDimensions): PngPhysicalDimensions {
    PngPhysicalDimensions(value.pixelsPerUnitX, value.pixelsPerUnitY, value.unit)
}

private func pngCloneCicp(value: PngCodingIndependentCodePoints): PngCodingIndependentCodePoints {
    PngCodingIndependentCodePoints(
        value.colorPrimaries, value.transferFunction, value.matrixCoefficients, value.fullRangeFlag
    )
}

private func pngCloneContentLightLevel(value: PngContentLightLevel): PngContentLightLevel {
    PngContentLightLevel(value.maximumContentLightLevel, value.maximumFrameAverageLightLevel)
}

private func pngCloneMasteringDisplay(value: PngMasteringDisplayColorVolume): PngMasteringDisplayColorVolume {
    PngMasteringDisplayColorVolume(
        pngCloneChromaticities(value.chromaticities),
        value.maximumDisplayLuminance,
        value.minimumDisplayLuminance
    )
}

private func pngCloneImageOffset(value: PngImageOffset): PngImageOffset {
    PngImageOffset(value.x, value.y, value.unit)
}

private func pngCloneCalibration(value: PngPixelCalibration): PngPixelCalibration {
    PngPixelCalibration(
        value.purpose(), value.x0, value.x1, value.equationType,
        value.units(), value.parameters()
    )
}

private func pngClonePhysicalScale(value: PngPhysicalScale): PngPhysicalScale {
    PngPhysicalScale(value.unit, value.width(), value.height())
}

private func pngCloneSuggestedPaletteEntry(value: PngSuggestedPaletteEntry): PngSuggestedPaletteEntry {
    PngSuggestedPaletteEntry(value.red, value.green, value.blue, value.alpha, value.frequency)
}

private func pngCloneSuggestedPalette(value: PngSuggestedPalette): PngSuggestedPalette {
    let source = value.entries()
    let entries = Array<PngSuggestedPaletteEntry>(source.size, repeat:
        PngSuggestedPaletteEntry(UInt16(0), UInt16(0), UInt16(0), UInt16(0), UInt16(0)))
    var index: Int64 = Int64(0)
    while (index < source.size) {
        entries[index] = pngCloneSuggestedPaletteEntry(source[index])
        index += Int64(1)
    }
    PngSuggestedPalette(value.name(), value.sampleDepth, entries)
}

private func pngCloneTextEntry(value: PngTextEntry): PngTextEntry {
    PngTextEntry(
        value.kind, value.keyword(), value.text(), value.languageTag(), value.translatedKeyword()
    )
}

private func pngCloneModificationTime(value: PngModificationTime): PngModificationTime {
    PngModificationTime(value.year, value.month, value.day, value.hour, value.minute, value.second)
}

private func pngCloneTransparency(value: PngWriteTransparency): PngWriteTransparency {
    match (value.kind) {
        case PaletteTransparency => PngWriteTransparency(value.paletteAlpha())
        case GrayscaleTransparency => PngWriteTransparency(value.gray)
        case TruecolorTransparency => PngWriteTransparency(value.red, value.green, value.blue)
    }
}

private func pngCloneUnknownChunk(value: PngUnknownChunk): PngUnknownChunk {
    PngUnknownChunk(value.chunkType(), value.payload(), value.location)
}

public enum PngWriteUnknownChunkPolicy <:
    Equatable<PngWriteUnknownChunkPolicy> & ToString {
    | WriteUnknownSafeToCopy
    | WriteUnknownAncillary
    | WriteUnknownAll

    public operator func ==(right: PngWriteUnknownChunkPolicy): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngWriteUnknownChunkPolicy): Bool {
        !(this == right)
    }

    private func ordinalValue(): Int64 {
        match (this) {
            case WriteUnknownSafeToCopy => Int64(0)
            case WriteUnknownAncillary => Int64(1)
            case WriteUnknownAll => Int64(2)
        }
    }

    public func toString(): String {
        match (this) {
            case WriteUnknownSafeToCopy => "SAFE_TO_COPY"
            case WriteUnknownAncillary => "ANCILLARY"
            case WriteUnknownAll => "ALL"
        }
    }
}

public class PngWriteMetadata {
    var hasTransparencyValue: Bool = false
    var transparencyValue: PngWriteTransparency = PngWriteTransparency(Array<Byte>())
    var hasGammaValue: Bool = false
    var gammaValue: UInt32 = UInt32(0)
    var hasChromaticitiesValue: Bool = false
    var chromaticitiesValue: PngChromaticities = PngChromaticities()
    var hasSrgbValue: Bool = false
    var srgbValue: PngSrgbIntent = Perceptual
    var hasSignificantBitsValue: Bool = false
    var significantBitsValue: PngSignificantBits = PngSignificantBits()
    var hasBackgroundValue: Bool = false
    var backgroundValue: PngBackground = PngBackground()
    var hasPhysicalDimensionsValue: Bool = false
    var physicalDimensionsValue: PngPhysicalDimensions = PngPhysicalDimensions()
    var hasCicpValue: Bool = false
    var cicpValue: PngCodingIndependentCodePoints = PngCodingIndependentCodePoints()
    var hasContentLightLevelValue: Bool = false
    var contentLightLevelValue: PngContentLightLevel = PngContentLightLevel()
    var hasMasteringDisplayValue: Bool = false
    var masteringDisplayValue: PngMasteringDisplayColorVolume = PngMasteringDisplayColorVolume()
    var hasIccProfileValue: Bool = false
    var iccProfileValue: PngIccProfile = PngIccProfile()
    var hasExifValue: Bool = false
    var exifValue: Array<Byte> = Array<Byte>()
    var exifPlacementValue: PngWriteMetadataPlacement = WriteBeforeIdat
    var hasHistogramValue: Bool = false
    var histogramValue: Array<UInt16> = Array<UInt16>()
    var hasImageOffsetValue: Bool = false
    var imageOffsetValue: PngImageOffset = PngImageOffset()
    var hasCalibrationValue: Bool = false
    var calibrationValue: PngPixelCalibration = PngPixelCalibration()
    var hasPhysicalScaleValue: Bool = false
    var physicalScaleValue: PngPhysicalScale = PngPhysicalScale()
    var hasModificationTimeValue: Bool = false
    var modificationTimeValue: PngModificationTime = PngModificationTime()
    var modificationTimePlacementValue: PngWriteMetadataPlacement = WriteBeforeIdat
    var unknownChunkPolicyValue: PngWriteUnknownChunkPolicy = WriteUnknownSafeToCopy
    private let suggestedPalettesValue = ArrayList<PngSuggestedPalette>()
    private let textEntriesValue = ArrayList<PngPlacedWriteText>()
    private let unknownChunksValue = ArrayList<PngUnknownChunk>()

    public init() {}

    public init(read: PngReadMetadata, colorType: PngColorType) {
        this()
        if (read.hasTransparency) {
            match (colorType) {
                case Indexed => setTransparency(PngWriteTransparency(read.paletteAlpha()))
                case Grayscale => setTransparency(PngWriteTransparency(read.transparentGray))
                case Truecolor => setTransparency(PngWriteTransparency(
                    read.transparentRed, read.transparentGreen, read.transparentBlue
                ))
                case GrayscaleAlpha | TruecolorAlpha =>
                    throw PngFormatException(
                        InvalidTransparency, -1,
                        "read metadata cannot contain tRNS for an alpha color type"
                    )
            }
        }
        if (read.hasGamma) { setGamma(read.gamma) }
        if (read.hasChromaticities) { setChromaticities(read.chromaticities) }
        if (read.hasSrgb) { setSrgb(read.srgbIntent) }
        if (read.hasSignificantBits) { setSignificantBits(read.significantBits) }
        if (read.hasBackground) { setBackground(read.background) }
        if (read.hasPhysicalDimensions) { setPhysicalDimensions(read.physicalDimensions) }
        if (read.hasCodingIndependentCodePoints) {
            setCodingIndependentCodePoints(read.codingIndependentCodePoints)
        }
        if (read.hasContentLightLevel) { setContentLightLevel(read.contentLightLevel) }
        if (read.hasMasteringDisplayColorVolume) {
            setMasteringDisplayColorVolume(read.masteringDisplayColorVolume)
        }
        if (read.hasIccProfile) { setIccProfile(read.iccProfile) }
        if (read.hasExif) { setExif(read.exif(), WriteBeforeIdat) }
        if (read.hasHistogram) { setHistogram(read.histogram()) }
        if (read.hasImageOffset) { setImageOffset(read.imageOffset) }
        if (read.hasPixelCalibration) { setPixelCalibration(read.pixelCalibration) }
        if (read.hasPhysicalScale) { setPhysicalScale(read.physicalScale) }
        if (read.hasModificationTime) {
            setModificationTime(read.modificationTime, WriteBeforeIdat)
        }
        var paletteIndex: Int64 = Int64(0)
        while (paletteIndex < read.suggestedPaletteCount()) {
            addSuggestedPalette(read.suggestedPalette(paletteIndex))
            paletteIndex += Int64(1)
        }
        var textIndex: Int64 = Int64(0)
        while (textIndex < read.textEntryCount()) {
            addText(read.textEntry(textIndex), WriteBeforeIdat)
            textIndex += Int64(1)
        }
        if (read.unknownChunkCount() > Int64(0)) {
            setUnknownChunkPolicy(WriteUnknownAll)
            var unknownIndex: Int64 = Int64(0)
            while (unknownIndex < read.unknownChunkCount()) {
                addUnknownChunk(read.unknownChunk(unknownIndex))
                unknownIndex += Int64(1)
            }
        }
    }

    init(other: PngWriteMetadata) {
        if (other.hasTransparencyValue) { setTransparency(other.transparencyValue) }
        if (other.hasGammaValue) { setGamma(other.gammaValue) }
        if (other.hasChromaticitiesValue) { setChromaticities(other.chromaticitiesValue) }
        if (other.hasSrgbValue) { setSrgb(other.srgbValue) }
        if (other.hasSignificantBitsValue) { setSignificantBits(other.significantBitsValue) }
        if (other.hasBackgroundValue) { setBackground(other.backgroundValue) }
        if (other.hasPhysicalDimensionsValue) { setPhysicalDimensions(other.physicalDimensionsValue) }
        if (other.hasCicpValue) { setCodingIndependentCodePoints(other.cicpValue) }
        if (other.hasContentLightLevelValue) { setContentLightLevel(other.contentLightLevelValue) }
        if (other.hasMasteringDisplayValue) {
            setMasteringDisplayColorVolume(other.masteringDisplayValue)
        }
        if (other.hasIccProfileValue) { setIccProfile(other.iccProfileValue) }
        if (other.hasExifValue) { setExif(other.exifValue, other.exifPlacementValue) }
        if (other.hasHistogramValue) { setHistogram(other.histogramValue) }
        if (other.hasImageOffsetValue) { setImageOffset(other.imageOffsetValue) }
        if (other.hasCalibrationValue) { setPixelCalibration(other.calibrationValue) }
        if (other.hasPhysicalScaleValue) { setPhysicalScale(other.physicalScaleValue) }
        if (other.hasModificationTimeValue) {
            setModificationTime(other.modificationTimeValue, other.modificationTimePlacementValue)
        }
        var paletteIndex: Int64 = Int64(0)
        while (paletteIndex < other.suggestedPalettesValue.size) {
            addSuggestedPalette(other.suggestedPalettesValue[paletteIndex])
            paletteIndex += Int64(1)
        }
        var textIndex: Int64 = Int64(0)
        while (textIndex < other.textEntriesValue.size) {
            let placed = other.textEntriesValue[textIndex]
            addText(placed.entry, placed.placement)
            textIndex += Int64(1)
        }
        setUnknownChunkPolicy(other.unknownChunkPolicyValue)
        var unknownIndex: Int64 = Int64(0)
        while (unknownIndex < other.unknownChunksValue.size) {
            addUnknownChunk(other.unknownChunksValue[unknownIndex])
            unknownIndex += Int64(1)
        }
    }

    private func requireUnset(present: Bool, name: String): Unit {
        if (present) {
            throw PngFormatException(DuplicateMetadata, -1, "PNG write metadata already contains ${name}")
        }
    }

    public func setTransparency(value: PngWriteTransparency): Unit {
        requireUnset(hasTransparencyValue, "tRNS")
        transparencyValue = pngCloneTransparency(value)
        hasTransparencyValue = true
    }

    public func setGamma(value: UInt32): Unit {
        requireUnset(hasGammaValue, "gAMA")
        gammaValue = value
        hasGammaValue = true
    }

    public func setChromaticities(value: PngChromaticities): Unit {
        requireUnset(hasChromaticitiesValue, "cHRM")
        chromaticitiesValue = pngCloneChromaticities(value)
        hasChromaticitiesValue = true
    }

    public func setSrgb(value: PngSrgbIntent): Unit {
        requireUnset(hasSrgbValue, "sRGB")
        srgbValue = value
        hasSrgbValue = true
    }

    public func setSignificantBits(value: PngSignificantBits): Unit {
        requireUnset(hasSignificantBitsValue, "sBIT")
        significantBitsValue = pngCloneSignificantBits(value)
        hasSignificantBitsValue = true
    }

    public func setBackground(value: PngBackground): Unit {
        requireUnset(hasBackgroundValue, "bKGD")
        backgroundValue = PngBackground(value)
        hasBackgroundValue = true
    }

    public func setPhysicalDimensions(value: PngPhysicalDimensions): Unit {
        requireUnset(hasPhysicalDimensionsValue, "pHYs")
        physicalDimensionsValue = pngClonePhysicalDimensions(value)
        hasPhysicalDimensionsValue = true
    }

    public func setCodingIndependentCodePoints(value: PngCodingIndependentCodePoints): Unit {
        requireUnset(hasCicpValue, "cICP")
        cicpValue = pngCloneCicp(value)
        hasCicpValue = true
    }

    public func setContentLightLevel(value: PngContentLightLevel): Unit {
        requireUnset(hasContentLightLevelValue, "cLLI")
        contentLightLevelValue = pngCloneContentLightLevel(value)
        hasContentLightLevelValue = true
    }

    public func setMasteringDisplayColorVolume(value: PngMasteringDisplayColorVolume): Unit {
        requireUnset(hasMasteringDisplayValue, "mDCV")
        masteringDisplayValue = pngCloneMasteringDisplay(value)
        hasMasteringDisplayValue = true
    }

    public func setIccProfile(value: PngIccProfile): Unit {
        requireUnset(hasIccProfileValue, "iCCP")
        iccProfileValue = PngIccProfile(value.name(), value.profile())
        hasIccProfileValue = true
    }

    public func setExif(value: Array<Byte>, placement: PngWriteMetadataPlacement): Unit {
        requireUnset(hasExifValue, "eXIf")
        exifValue = value.clone()
        exifPlacementValue = placement
        hasExifValue = true
    }

    public func setHistogram(value: Array<UInt16>): Unit {
        requireUnset(hasHistogramValue, "hIST")
        histogramValue = value.clone()
        hasHistogramValue = true
    }

    public func setImageOffset(value: PngImageOffset): Unit {
        requireUnset(hasImageOffsetValue, "oFFs")
        imageOffsetValue = pngCloneImageOffset(value)
        hasImageOffsetValue = true
    }

    public func setPixelCalibration(value: PngPixelCalibration): Unit {
        requireUnset(hasCalibrationValue, "pCAL")
        calibrationValue = pngCloneCalibration(value)
        hasCalibrationValue = true
    }

    public func setPhysicalScale(value: PngPhysicalScale): Unit {
        requireUnset(hasPhysicalScaleValue, "sCAL")
        physicalScaleValue = pngClonePhysicalScale(value)
        hasPhysicalScaleValue = true
    }

    public func setModificationTime(
        value: PngModificationTime,
        placement: PngWriteMetadataPlacement
    ): Unit {
        requireUnset(hasModificationTimeValue, "tIME")
        modificationTimeValue = pngCloneModificationTime(value)
        modificationTimePlacementValue = placement
        hasModificationTimeValue = true
    }

    public func addSuggestedPalette(value: PngSuggestedPalette): Unit {
        suggestedPalettesValue.add(pngCloneSuggestedPalette(value))
    }

    public func addText(value: PngTextEntry, placement: PngWriteMetadataPlacement): Unit {
        textEntriesValue.add(PngPlacedWriteText(value, placement))
    }

    public func setUnknownChunkPolicy(policy: PngWriteUnknownChunkPolicy): Unit {
        unknownChunkPolicyValue = policy
    }

    public func addUnknownChunk(value: PngUnknownChunk): Unit {
        unknownChunksValue.add(pngCloneUnknownChunk(value))
    }

    public func unknownChunkCount(): Int64 {
        unknownChunksValue.size
    }

    public func unknownChunk(index: Int64): PngUnknownChunk {
        if (index < Int64(0) || index >= unknownChunksValue.size) {
            throw PngFormatException(
                InvalidArgument, index,
                "PNG write unknown chunk index is out of bounds"
            )
        }
        pngCloneUnknownChunk(unknownChunksValue[index])
    }

    func suggestedPalettes(): Array<PngSuggestedPalette> {
        let source = suggestedPalettesValue.toArray()
        if (source.size == Int64(0)) { return Array<PngSuggestedPalette>() }
        let out = Array<PngSuggestedPalette>(
            source.size,
            repeat: pngCloneSuggestedPalette(source[0])
        )
        var index: Int64 = Int64(0)
        while (index < source.size) {
            out[index] = pngCloneSuggestedPalette(source[index])
            index += Int64(1)
        }
        out
    }

    func textEntries(): Array<PngPlacedWriteText> {
        let source = textEntriesValue.toArray()
        if (source.size == Int64(0)) { return Array<PngPlacedWriteText>() }
        let out = Array<PngPlacedWriteText>(
            source.size,
            repeat: PngPlacedWriteText(source[0].entry, source[0].placement)
        )
        var index: Int64 = Int64(0)
        while (index < source.size) {
            out[index] = PngPlacedWriteText(source[index].entry, source[index].placement)
            index += Int64(1)
        }
        out
    }

    func unknownChunks(): Array<PngUnknownChunk> {
        let source = unknownChunksValue.toArray()
        if (source.size == Int64(0)) { return Array<PngUnknownChunk>() }
        let out = Array<PngUnknownChunk>(
            source.size,
            repeat: pngCloneUnknownChunk(source[0])
        )
        var index: Int64 = Int64(0)
        while (index < source.size) {
            out[index] = pngCloneUnknownChunk(source[index])
            index += Int64(1)
        }
        out
    }
}

func pngSnapshotWriteMetadata(metadata: PngWriteMetadata): PngWriteMetadata {
    PngWriteMetadata(metadata)
}

class PngWriteMetadataPlan {
    private let beforePaletteValue = ArrayList<Array<Byte>>()
    private let afterPaletteValue = ArrayList<Array<Byte>>()
    private let afterIdatValue = ArrayList<Array<Byte>>()
    var framedBytes: UInt64 = UInt64(0)

    func addBeforePalette(chunk: Array<Byte>): Unit {
        beforePaletteValue.add(chunk)
        framedBytes += UInt64(chunk.size)
    }

    func addAfterPalette(chunk: Array<Byte>): Unit {
        afterPaletteValue.add(chunk)
        framedBytes += UInt64(chunk.size)
    }

    func addAfterIdat(chunk: Array<Byte>): Unit {
        afterIdatValue.add(chunk)
        framedBytes += UInt64(chunk.size)
    }

    func beforePalette(): Array<Array<Byte>> { beforePaletteValue.toArray() }
    func afterPalette(): Array<Array<Byte>> { afterPaletteValue.toArray() }
    func afterIdat(): Array<Array<Byte>> { afterIdatValue.toArray() }
}

private class PngWriteMetadataBudget {
    let maxRawBytes: UInt64
    let maxCompressedBytes: UInt64
    var rawBytes: UInt64 = UInt64(0)
    var compressedBytes: UInt64 = UInt64(0)

    init(maxRawBytes: UInt64, maxCompressedBytes: UInt64) {
        this.maxRawBytes = maxRawBytes
        this.maxCompressedBytes = maxCompressedBytes
    }

    func chargeRaw(amount: UInt64): Unit {
        if (amount > maxRawBytes || rawBytes > maxRawBytes - amount) {
            throw PngFormatException(
                DecodeLimitExceeded, -1,
                "PNG write metadata exceeds configured raw metadata limit"
            )
        }
        rawBytes += amount
    }

    func compress(bytes: Array<Byte>, level: Int32): Array<Byte> {
        if (compressedBytes >= maxCompressedBytes) {
            throw PngFormatException(
                DecodeLimitExceeded, -1,
                "PNG write metadata exceeds configured compressed metadata limit"
            )
        }
        let compressed = compressPngZlib(bytes, level, maxCompressedBytes - compressedBytes)
        compressedBytes += UInt64(compressed.size)
        compressed
    }
}

private func appendMetadataBytes(target: ArrayList<Byte>, bytes: Array<Byte>): Unit {
    var index: Int64 = Int64(0)
    while (index < bytes.size) {
        target.add(bytes[index])
        index += Int64(1)
    }
}

private func appendMetadataUInt16(target: ArrayList<Byte>, value: UInt16): Unit {
    target.add(UInt8(value >> UInt16(8)))
    target.add(UInt8(value & UInt16(0xff)))
}

private func metadataUInt16Bytes(value: UInt16): Array<Byte> {
    [UInt8(value >> UInt16(8)), UInt8(value & UInt16(0xff))]
}

private func writeMetadataInt32(value: Int32): Array<Byte> {
    if (value >= Int32(0)) {
        return writeUInt32Be(UInt32(value))
    }
    if (value == Int32(-2147483647) - Int32(1)) {
        return writeUInt32Be(UInt32(0x8000_0000))
    }
    let magnitude = UInt32(-value)
    writeUInt32Be((magnitude ^ UInt32(0xffff_ffff)) + UInt32(1))
}

private func metadataContainsZero(bytes: Array<Byte>): Bool {
    var index: Int64 = Int64(0)
    while (index < bytes.size) {
        if (bytes[index] == UInt8(0)) { return true }
        index += Int64(1)
    }
    false
}

private func requireMetadataNoZero(bytes: Array<Byte>, label: String, kind: PngErrorKind): Unit {
    if (metadataContainsZero(bytes)) {
        throw PngFormatException(kind, -1, "${label} cannot contain a zero byte")
    }
}

private func requireWriteKeyword(bytes: Array<Byte>, label: String, kind: PngErrorKind): Unit {
    if (!pngValidKeyword(bytes)) {
        throw PngFormatException(kind, -1, "${label} is not a valid PNG keyword")
    }
}

private func makeGammaWriteChunk(value: UInt32): Array<Byte> {
    if (value > PNG_UINT_31_MAX) {
        throw PngFormatException(InvalidMetadata, -1, "gAMA value exceeds PNG_UINT_31_MAX")
    }
    makeWriteChunk(PNG_CHUNK_gAMA, writeUInt32Be(value))
}

private func makeChromaticitiesWriteChunk(value: PngChromaticities): Array<Byte> {
    let minimum = Int32(-2147483647) - Int32(1)
    if (value.whiteX == minimum || value.whiteY == minimum ||
        value.redX == minimum || value.redY == minimum ||
        value.greenX == minimum || value.greenY == minimum ||
        value.blueX == minimum || value.blueY == minimum) {
        throw PngFormatException(InvalidMetadata, -1, "cHRM cannot encode INT32_MIN")
    }
    let data = ArrayList<Byte>()
    appendMetadataBytes(data, writeMetadataInt32(value.whiteX))
    appendMetadataBytes(data, writeMetadataInt32(value.whiteY))
    appendMetadataBytes(data, writeMetadataInt32(value.redX))
    appendMetadataBytes(data, writeMetadataInt32(value.redY))
    appendMetadataBytes(data, writeMetadataInt32(value.greenX))
    appendMetadataBytes(data, writeMetadataInt32(value.greenY))
    appendMetadataBytes(data, writeMetadataInt32(value.blueX))
    appendMetadataBytes(data, writeMetadataInt32(value.blueY))
    makeWriteChunk(PNG_CHUNK_cHRM, data.toArray())
}

private func makeSignificantBitsWriteChunk(value: PngSignificantBits, ihdr: PngIhdr): Array<Byte> {
    let maximum = if (ihdr.colorType == Indexed) { UInt8(8) } else { ihdr.bitDepth }
    let data: Array<Byte> = match (ihdr.colorType) {
        case Grayscale => [value.gray]
        case Truecolor | Indexed => [value.red, value.green, value.blue]
        case GrayscaleAlpha => [value.gray, value.alpha]
        case TruecolorAlpha => [value.red, value.green, value.blue, value.alpha]
    }
    var index: Int64 = Int64(0)
    while (index < data.size) {
        if (data[index] == UInt8(0) || data[index] > maximum) {
            throw PngFormatException(
                InvalidMetadata, -1,
                "sBIT values must be in 1..source sample depth"
            )
        }
        index += Int64(1)
    }
    makeWriteChunk(PNG_CHUNK_sBIT, data)
}

private func makeTransparencyWriteChunk(
    value: PngWriteTransparency,
    ihdr: PngIhdr,
    palette: Array<Byte>
): Array<Byte> {
    match (ihdr.colorType) {
        case Indexed =>
            if (value.kind != PaletteTransparency) {
                throw PngFormatException(InvalidTransparency, -1, "indexed PNG requires palette tRNS")
            }
            let alpha = value.paletteAlpha()
            let paletteCount = palette.size / Int64(3)
            if (alpha.size < Int64(1) || alpha.size > paletteCount) {
                throw PngFormatException(
                    InvalidTransparency, -1,
                    "indexed tRNS must contain 1..PLTE-entry-count alpha values"
                )
            }
            makeWriteChunk(PNG_CHUNK_tRNS, alpha)
        case Grayscale =>
            if (value.kind != GrayscaleTransparency) {
                throw PngFormatException(InvalidTransparency, -1, "grayscale PNG requires gray tRNS")
            }
            if (ihdr.bitDepth < UInt8(16) && value.gray >= (UInt16(1) << UInt16(ihdr.bitDepth))) {
                throw PngFormatException(
                    InvalidTransparency, -1,
                    "grayscale tRNS sample exceeds source bit depth"
                )
            }
            makeWriteChunk(PNG_CHUNK_tRNS, metadataUInt16Bytes(value.gray))
        case Truecolor =>
            if (value.kind != TruecolorTransparency) {
                throw PngFormatException(InvalidTransparency, -1, "truecolor PNG requires RGB tRNS")
            }
            if (ihdr.bitDepth == UInt8(8) &&
                (value.red > UInt16(255) || value.green > UInt16(255) || value.blue > UInt16(255))) {
                throw PngFormatException(
                    InvalidTransparency, -1,
                    "8-bit truecolor tRNS samples must fit in one byte"
                )
            }
            let data = ArrayList<Byte>()
            appendMetadataUInt16(data, value.red)
            appendMetadataUInt16(data, value.green)
            appendMetadataUInt16(data, value.blue)
            makeWriteChunk(PNG_CHUNK_tRNS, data.toArray())
        case GrayscaleAlpha | TruecolorAlpha =>
            throw PngFormatException(InvalidTransparency, -1, "tRNS is not allowed with an alpha channel")
    }
}

private func makeBackgroundWriteChunk(
    value: PngBackground,
    ihdr: PngIhdr,
    palette: Array<Byte>
): Array<Byte> {
    match (ihdr.colorType) {
        case Indexed =>
            if (Int64(value.index) >= palette.size / Int64(3)) {
                throw PngFormatException(InvalidMetadata, -1, "bKGD palette index is outside PLTE")
            }
            makeWriteChunk(PNG_CHUNK_bKGD, [value.index])
        case Grayscale | GrayscaleAlpha =>
            if (ihdr.bitDepth < UInt8(16) && value.gray >= (UInt16(1) << UInt16(ihdr.bitDepth))) {
                throw PngFormatException(InvalidMetadata, -1, "bKGD gray sample exceeds source depth")
            }
            makeWriteChunk(PNG_CHUNK_bKGD, metadataUInt16Bytes(value.gray))
        case Truecolor | TruecolorAlpha =>
            if (ihdr.bitDepth == UInt8(8) &&
                (value.red > UInt16(255) || value.green > UInt16(255) || value.blue > UInt16(255))) {
                throw PngFormatException(InvalidMetadata, -1, "8-bit bKGD samples must fit in one byte")
            }
            let data = ArrayList<Byte>()
            appendMetadataUInt16(data, value.red)
            appendMetadataUInt16(data, value.green)
            appendMetadataUInt16(data, value.blue)
            makeWriteChunk(PNG_CHUNK_bKGD, data.toArray())
    }
}

private func makeCicpWriteChunk(value: PngCodingIndependentCodePoints): Array<Byte> {
    if (value.matrixCoefficients != UInt8(0)) {
        throw PngFormatException(InvalidMetadata, -1, "cICP matrix coefficients must be zero for PNG")
    }
    makeWriteChunk(PNG_CHUNK_cICP, [
        value.colorPrimaries, value.transferFunction, value.matrixCoefficients, value.fullRangeFlag
    ])
}

private func makeContentLightWriteChunk(value: PngContentLightLevel): Array<Byte> {
    if (value.maximumContentLightLevel > PNG_UINT_31_MAX ||
        value.maximumFrameAverageLightLevel > PNG_UINT_31_MAX) {
        throw PngFormatException(InvalidMetadata, -1, "cLLI values exceed the PNG limit")
    }
    let data = ArrayList<Byte>()
    appendMetadataBytes(data, writeUInt32Be(value.maximumContentLightLevel))
    appendMetadataBytes(data, writeUInt32Be(value.maximumFrameAverageLightLevel))
    makeWriteChunk(PNG_CHUNK_cLLI, data.toArray())
}

private func masteringCoordinate(value: Int32): UInt16 {
    if (value < Int32(0) || value > Int32(131071)) {
        throw PngFormatException(
            InvalidMetadata, -1,
            "mDCV chromaticity is outside the representable PNG range"
        )
    }
    UInt16(value / Int32(2))
}

private func makeMasteringDisplayWriteChunk(value: PngMasteringDisplayColorVolume): Array<Byte> {
    if (value.maximumDisplayLuminance > PNG_UINT_31_MAX ||
        value.minimumDisplayLuminance > PNG_UINT_31_MAX) {
        throw PngFormatException(InvalidMetadata, -1, "mDCV luminance exceeds the PNG limit")
    }
    let xy = value.chromaticities
    let data = ArrayList<Byte>()
    appendMetadataUInt16(data, masteringCoordinate(xy.redX))
    appendMetadataUInt16(data, masteringCoordinate(xy.redY))
    appendMetadataUInt16(data, masteringCoordinate(xy.greenX))
    appendMetadataUInt16(data, masteringCoordinate(xy.greenY))
    appendMetadataUInt16(data, masteringCoordinate(xy.blueX))
    appendMetadataUInt16(data, masteringCoordinate(xy.blueY))
    appendMetadataUInt16(data, masteringCoordinate(xy.whiteX))
    appendMetadataUInt16(data, masteringCoordinate(xy.whiteY))
    appendMetadataBytes(data, writeUInt32Be(value.maximumDisplayLuminance))
    appendMetadataBytes(data, writeUInt32Be(value.minimumDisplayLuminance))
    makeWriteChunk(PNG_CHUNK_mDCV, data.toArray())
}

private func makeIccWriteChunk(
    value: PngIccProfile,
    ihdr: PngIhdr,
    compressionLevel: Int32,
    budget: PngWriteMetadataBudget
): Array<Byte> {
    let name = value.name()
    let profile = value.profile()
    requireWriteKeyword(name, "iCCP name", InvalidIccProfile)
    budget.chargeRaw(UInt64(name.size) + UInt64(2) + UInt64(profile.size))
    validateIccProfile(profile, ihdr, budget.maxRawBytes)
    let compressed = budget.compress(profile, compressionLevel)
    let data = ArrayList<Byte>()
    appendMetadataBytes(data, name)
    data.add(UInt8(0))
    data.add(UInt8(0))
    appendMetadataBytes(data, compressed)
    makeWriteChunk(PNG_CHUNK_iCCP, data.toArray())
}

private func makeExifWriteChunk(value: Array<Byte>): Array<Byte> {
    if (value.size < Int64(4)) {
        throw PngFormatException(InvalidMetadata, -1, "eXIf length must be at least 4")
    }
    let header = readUInt32Be(value, Int64(0))
    if (header != UInt32(0x4949_2a00) && header != UInt32(0x4d4d_002a)) {
        throw PngFormatException(InvalidMetadata, -1, "eXIf TIFF header is invalid")
    }
    makeWriteChunk(PNG_CHUNK_eXIf, value)
}

private func makeHistogramWriteChunk(value: Array<UInt16>, palette: Array<Byte>): Array<Byte> {
    let paletteCount = palette.size / Int64(3)
    if (paletteCount == Int64(0) || value.size != paletteCount) {
        throw PngFormatException(InvalidMetadata, -1, "hIST length must match PLTE entries")
    }
    let data = ArrayList<Byte>()
    var index: Int64 = Int64(0)
    while (index < value.size) {
        appendMetadataUInt16(data, value[index])
        index += Int64(1)
    }
    makeWriteChunk(PNG_CHUNK_hIST, data.toArray())
}

private func makeOffsetWriteChunk(value: PngImageOffset): Array<Byte> {
    let data = ArrayList<Byte>()
    appendMetadataBytes(data, writeMetadataInt32(value.x))
    appendMetadataBytes(data, writeMetadataInt32(value.y))
    data.add(value.unit)
    makeWriteChunk(PNG_CHUNK_oFFs, data.toArray())
}

private func makeCalibrationWriteChunk(value: PngPixelCalibration): Array<Byte> {
    let purpose = value.purpose()
    let units = value.units()
    let parameters = value.parameters()
    requireWriteKeyword(purpose, "pCAL purpose", InvalidMetadata)
    requireMetadataNoZero(units, "pCAL units", InvalidMetadata)
    let expected = match (value.equationType) {
        case 0 => Int64(2)
        case 1 | 2 => Int64(3)
        case 3 => Int64(4)
        case _ => throw PngFormatException(InvalidMetadata, -1, "pCAL equation type must be in 0..3")
    }
    if (parameters.size != expected) {
        throw PngFormatException(InvalidMetadata, -1, "pCAL parameter count does not match equation type")
    }
    let data = ArrayList<Byte>()
    appendMetadataBytes(data, purpose)
    data.add(UInt8(0))
    appendMetadataBytes(data, writeMetadataInt32(value.x0))
    appendMetadataBytes(data, writeMetadataInt32(value.x1))
    data.add(value.equationType)
    data.add(UInt8(parameters.size))
    appendMetadataBytes(data, units)
    data.add(UInt8(0))
    var index: Int64 = Int64(0)
    while (index < parameters.size) {
        if (!pngValidAsciiNumber(parameters[index])) {
            throw PngFormatException(InvalidMetadata, -1, "pCAL parameter is not a valid ASCII number")
        }
        appendMetadataBytes(data, parameters[index])
        if (index + Int64(1) < parameters.size) { data.add(UInt8(0)) }
        index += Int64(1)
    }
    makeWriteChunk(PNG_CHUNK_pCAL, data.toArray())
}

private func makePhysicalScaleWriteChunk(value: PngPhysicalScale): Array<Byte> {
    let width = value.width()
    let height = value.height()
    if ((value.unit != UInt8(1) && value.unit != UInt8(2)) ||
        !pngPositiveAsciiNumber(width) || !pngPositiveAsciiNumber(height)) {
        throw PngFormatException(InvalidMetadata, -1, "sCAL requires unit 1/2 and positive ASCII dimensions")
    }
    let data = ArrayList<Byte>()
    data.add(value.unit)
    appendMetadataBytes(data, width)
    data.add(UInt8(0))
    appendMetadataBytes(data, height)
    makeWriteChunk(PNG_CHUNK_sCAL, data.toArray())
}

private func makePhysicalDimensionsWriteChunk(value: PngPhysicalDimensions): Array<Byte> {
    let data = ArrayList<Byte>()
    appendMetadataBytes(data, writeUInt32Be(value.pixelsPerUnitX))
    appendMetadataBytes(data, writeUInt32Be(value.pixelsPerUnitY))
    data.add(value.unit)
    makeWriteChunk(PNG_CHUNK_pHYs, data.toArray())
}

private func validWriteTime(value: PngModificationTime): Bool {
    value.month >= UInt8(1) && value.month <= UInt8(12) &&
        value.day >= UInt8(1) && value.day <= UInt8(31) &&
        value.hour <= UInt8(23) && value.minute <= UInt8(59) && value.second <= UInt8(60)
}

private func makeTimeWriteChunk(value: PngModificationTime): Array<Byte> {
    if (!validWriteTime(value)) {
        throw PngFormatException(InvalidTimeMetadata, -1, "tIME contains an invalid calendar value")
    }
    let data = ArrayList<Byte>()
    appendMetadataUInt16(data, value.year)
    data.add(value.month)
    data.add(value.day)
    data.add(value.hour)
    data.add(value.minute)
    data.add(value.second)
    makeWriteChunk(PNG_CHUNK_tIME, data.toArray())
}

private func makeSuggestedPaletteWriteChunk(value: PngSuggestedPalette): Array<Byte> {
    let name = value.name()
    let entries = value.entries()
    requireWriteKeyword(name, "sPLT name", InvalidMetadata)
    if (value.sampleDepth != UInt8(8) && value.sampleDepth != UInt8(16)) {
        throw PngFormatException(InvalidMetadata, -1, "sPLT sample depth must be 8 or 16")
    }
    if (entries.size == Int64(0)) {
        throw PngFormatException(InvalidMetadata, -1, "sPLT requires at least one entry")
    }
    let data = ArrayList<Byte>()
    appendMetadataBytes(data, name)
    data.add(UInt8(0))
    data.add(value.sampleDepth)
    var index: Int64 = Int64(0)
    while (index < entries.size) {
        let entry = entries[index]
        if (value.sampleDepth == UInt8(8)) {
            if (entry.red > UInt16(255) || entry.green > UInt16(255) ||
                entry.blue > UInt16(255) || entry.alpha > UInt16(255)) {
                throw PngFormatException(InvalidMetadata, -1, "8-bit sPLT entries must fit in one byte")
            }
            data.add(UInt8(entry.red))
            data.add(UInt8(entry.green))
            data.add(UInt8(entry.blue))
            data.add(UInt8(entry.alpha))
        } else {
            appendMetadataUInt16(data, entry.red)
            appendMetadataUInt16(data, entry.green)
            appendMetadataUInt16(data, entry.blue)
            appendMetadataUInt16(data, entry.alpha)
        }
        appendMetadataUInt16(data, entry.frequency)
        index += Int64(1)
    }
    makeWriteChunk(PNG_CHUNK_sPLT, data.toArray())
}

private func makeTextWriteChunk(
    value: PngTextEntry,
    compressionLevel: Int32,
    budget: PngWriteMetadataBudget
): Array<Byte> {
    let keyword = value.keyword()
    let text = value.text()
    let language = value.languageTag()
    let translated = value.translatedKeyword()
    requireWriteKeyword(keyword, "text keyword", InvalidTextMetadata)
    requireMetadataNoZero(text, "text value", InvalidTextMetadata)
    requireMetadataNoZero(language, "iTXt language tag", InvalidTextMetadata)
    requireMetadataNoZero(translated, "iTXt translated keyword", InvalidTextMetadata)
    match (value.kind) {
        case Latin1Uncompressed =>
            if (language.size != Int64(0) || translated.size != Int64(0)) {
                throw PngFormatException(
                    InvalidTextMetadata, -1,
                    "Latin-1 text cannot carry iTXt language fields"
                )
            }
            budget.chargeRaw(UInt64(keyword.size) + UInt64(text.size) + UInt64(1))
            let data = ArrayList<Byte>()
            appendMetadataBytes(data, keyword)
            data.add(UInt8(0))
            appendMetadataBytes(data, text)
            makeWriteChunk(PNG_CHUNK_tEXt, data.toArray())
        case Latin1Compressed =>
            if (language.size != Int64(0) || translated.size != Int64(0)) {
                throw PngFormatException(
                    InvalidTextMetadata, -1,
                    "Latin-1 text cannot carry iTXt language fields"
                )
            }
            budget.chargeRaw(UInt64(keyword.size) + UInt64(text.size) + UInt64(2))
            let compressed = budget.compress(text, compressionLevel)
            let data = ArrayList<Byte>()
            appendMetadataBytes(data, keyword)
            data.add(UInt8(0))
            data.add(UInt8(0))
            appendMetadataBytes(data, compressed)
            makeWriteChunk(PNG_CHUNK_zTXt, data.toArray())
        case Utf8Uncompressed | Utf8Compressed =>
            budget.chargeRaw(
                UInt64(keyword.size) + UInt64(text.size) + UInt64(language.size) +
                    UInt64(translated.size) + UInt64(5)
            )
            let compressed = value.kind == Utf8Compressed
            let encodedText = if (compressed) { budget.compress(text, compressionLevel) } else { text }
            let data = ArrayList<Byte>()
            appendMetadataBytes(data, keyword)
            data.add(UInt8(0))
            data.add(if (compressed) { UInt8(1) } else { UInt8(0) })
            data.add(UInt8(0))
            appendMetadataBytes(data, language)
            data.add(UInt8(0))
            appendMetadataBytes(data, translated)
            data.add(UInt8(0))
            appendMetadataBytes(data, encodedText)
            makeWriteChunk(PNG_CHUNK_iTXt, data.toArray())
    }
}

private func chargeFixedMetadataChunk(budget: PngWriteMetadataBudget, chunk: Array<Byte>): Array<Byte> {
    budget.chargeRaw(UInt64(chunk.size - Int64(12)))
    chunk
}

private func isRecognizedWriteChunkType(chunkType: Array<Byte>): Bool {
    sameBytes(chunkType, PNG_CHUNK_IHDR) ||
        sameBytes(chunkType, PNG_CHUNK_PLTE) ||
        sameBytes(chunkType, PNG_CHUNK_IDAT) ||
        sameBytes(chunkType, PNG_CHUNK_IEND) ||
        sameBytes(chunkType, PNG_CHUNK_tRNS) ||
        sameBytes(chunkType, PNG_CHUNK_gAMA) ||
        sameBytes(chunkType, PNG_CHUNK_cHRM) ||
        sameBytes(chunkType, PNG_CHUNK_sRGB) ||
        sameBytes(chunkType, PNG_CHUNK_sBIT) ||
        sameBytes(chunkType, PNG_CHUNK_bKGD) ||
        sameBytes(chunkType, PNG_CHUNK_pHYs) ||
        sameBytes(chunkType, PNG_CHUNK_iCCP) ||
        sameBytes(chunkType, PNG_CHUNK_tEXt) ||
        sameBytes(chunkType, PNG_CHUNK_zTXt) ||
        sameBytes(chunkType, PNG_CHUNK_iTXt) ||
        sameBytes(chunkType, PNG_CHUNK_tIME) ||
        sameBytes(chunkType, PNG_CHUNK_cICP) ||
        sameBytes(chunkType, PNG_CHUNK_cLLI) ||
        sameBytes(chunkType, PNG_CHUNK_mDCV) ||
        sameBytes(chunkType, PNG_CHUNK_eXIf) ||
        sameBytes(chunkType, PNG_CHUNK_hIST) ||
        sameBytes(chunkType, PNG_CHUNK_oFFs) ||
        sameBytes(chunkType, PNG_CHUNK_pCAL) ||
        sameBytes(chunkType, PNG_CHUNK_sCAL) ||
        sameBytes(chunkType, PNG_CHUNK_sPLT)
}

private func shouldWriteUnknownChunk(
    chunk: PngUnknownChunk,
    policy: PngWriteUnknownChunkPolicy
): Bool {
    match (policy) {
        case WriteUnknownSafeToCopy => chunk.isSafeToCopy()
        case WriteUnknownAncillary => !isCriticalChunk(chunk.chunkType())
        case WriteUnknownAll => true
    }
}

private func addUnknownWriteChunks(
    plan: PngWriteMetadataPlan,
    budget: PngWriteMetadataBudget,
    chunks: Array<PngUnknownChunk>,
    policy: PngWriteUnknownChunkPolicy,
    location: PngUnknownChunkLocation
): Unit {
    var index: Int64 = Int64(0)
    while (index < chunks.size) {
        let chunk = chunks[index]
        if (chunk.location == location) {
            let chunkType = chunk.chunkType()
            let payload = chunk.payload()
            if (!isValidChunkType(chunkType)) {
                throw PngFormatException(
                    InvalidChunkType, -1,
                    "PNG write unknown chunk type must contain four ASCII letters"
                )
            }
            if ((chunkType[2] & UInt8(0x20)) != UInt8(0)) {
                throw PngFormatException(
                    InvalidChunkType, -1,
                    "PNG write unknown chunk type has a lowercase reserved bit"
                )
            }
            if (isRecognizedWriteChunkType(chunkType)) {
                throw PngFormatException(
                    DuplicateMetadata, -1,
                    "PNG write unknown chunk duplicates a recognized chunk type"
                )
            }
            if (payload.size > Int64(PNG_UINT_31_MAX)) {
                throw PngFormatException(
                    ChunkTooLarge, -1,
                    "PNG write unknown chunk payload exceeds 31 bits"
                )
            }
            if (shouldWriteUnknownChunk(chunk, policy)) {
                budget.chargeRaw(UInt64(payload.size))
                let framed = makeWriteChunk(chunkType, payload)
                match (location) {
                    case AfterIhdr => plan.addBeforePalette(framed)
                    case AfterPlte => plan.addAfterPalette(framed)
                    case AfterIdat => plan.addAfterIdat(framed)
                }
            }
        }
        index += Int64(1)
    }
}

func planPngWriteMetadata(
    metadata: PngWriteMetadata,
    ihdr: PngIhdr,
    palette: Array<Byte>,
    compressionLevel: Int32,
    maxRawBytes: UInt64,
    maxCompressedBytes: UInt64
): PngWriteMetadataPlan {
    let plan = PngWriteMetadataPlan()
    let budget = PngWriteMetadataBudget(maxRawBytes, maxCompressedBytes)
    let unknownChunks = metadata.unknownChunks()

    addUnknownWriteChunks(
        plan, budget, unknownChunks, metadata.unknownChunkPolicyValue, AfterIhdr
    )

    if (metadata.hasSignificantBitsValue) {
        plan.addBeforePalette(chargeFixedMetadataChunk(
            budget, makeSignificantBitsWriteChunk(metadata.significantBitsValue, ihdr)
        ))
    }
    if (metadata.hasContentLightLevelValue) {
        plan.addBeforePalette(chargeFixedMetadataChunk(
            budget, makeContentLightWriteChunk(metadata.contentLightLevelValue)
        ))
    }
    if (metadata.hasMasteringDisplayValue) {
        plan.addBeforePalette(chargeFixedMetadataChunk(
            budget, makeMasteringDisplayWriteChunk(metadata.masteringDisplayValue)
        ))
    }
    if (metadata.hasCicpValue) {
        plan.addBeforePalette(chargeFixedMetadataChunk(
            budget, makeCicpWriteChunk(metadata.cicpValue)
        ))
    }
    if (metadata.hasIccProfileValue) {
        plan.addBeforePalette(makeIccWriteChunk(
            metadata.iccProfileValue, ihdr, compressionLevel, budget
        ))
    }
    if (metadata.hasSrgbValue) {
        plan.addBeforePalette(chargeFixedMetadataChunk(
            budget, makeWriteChunk(PNG_CHUNK_sRGB, [metadata.srgbValue.encodedValue()])
        ))
    }
    if (metadata.hasGammaValue) {
        plan.addBeforePalette(chargeFixedMetadataChunk(
            budget, makeGammaWriteChunk(metadata.gammaValue)
        ))
    }
    if (metadata.hasChromaticitiesValue) {
        plan.addBeforePalette(chargeFixedMetadataChunk(
            budget, makeChromaticitiesWriteChunk(metadata.chromaticitiesValue)
        ))
    }

    if (metadata.hasTransparencyValue) {
        plan.addAfterPalette(chargeFixedMetadataChunk(
            budget, makeTransparencyWriteChunk(metadata.transparencyValue, ihdr, palette)
        ))
    }
    if (metadata.hasBackgroundValue) {
        plan.addAfterPalette(chargeFixedMetadataChunk(
            budget, makeBackgroundWriteChunk(metadata.backgroundValue, ihdr, palette)
        ))
    }
    if (metadata.hasExifValue && metadata.exifPlacementValue == WriteBeforeIdat) {
        plan.addAfterPalette(chargeFixedMetadataChunk(
            budget, makeExifWriteChunk(metadata.exifValue)
        ))
    }
    if (metadata.hasHistogramValue) {
        plan.addAfterPalette(chargeFixedMetadataChunk(
            budget, makeHistogramWriteChunk(metadata.histogramValue, palette)
        ))
    }
    if (metadata.hasImageOffsetValue) {
        plan.addAfterPalette(chargeFixedMetadataChunk(
            budget, makeOffsetWriteChunk(metadata.imageOffsetValue)
        ))
    }
    if (metadata.hasCalibrationValue) {
        plan.addAfterPalette(chargeFixedMetadataChunk(
            budget, makeCalibrationWriteChunk(metadata.calibrationValue)
        ))
    }
    if (metadata.hasPhysicalScaleValue) {
        plan.addAfterPalette(chargeFixedMetadataChunk(
            budget, makePhysicalScaleWriteChunk(metadata.physicalScaleValue)
        ))
    }
    if (metadata.hasPhysicalDimensionsValue) {
        plan.addAfterPalette(chargeFixedMetadataChunk(
            budget, makePhysicalDimensionsWriteChunk(metadata.physicalDimensionsValue)
        ))
    }
    if (metadata.hasModificationTimeValue && metadata.modificationTimePlacementValue == WriteBeforeIdat) {
        plan.addAfterPalette(chargeFixedMetadataChunk(
            budget, makeTimeWriteChunk(metadata.modificationTimeValue)
        ))
    }
    let suggestedPalettes = metadata.suggestedPalettes()
    var paletteIndex: Int64 = Int64(0)
    while (paletteIndex < suggestedPalettes.size) {
        plan.addAfterPalette(chargeFixedMetadataChunk(
            budget, makeSuggestedPaletteWriteChunk(suggestedPalettes[paletteIndex])
        ))
        paletteIndex += Int64(1)
    }
    let textEntries = metadata.textEntries()
    var textIndex: Int64 = Int64(0)
    while (textIndex < textEntries.size) {
        let placed = textEntries[textIndex]
        if (placed.placement == WriteBeforeIdat) {
            plan.addAfterPalette(makeTextWriteChunk(placed.entry, compressionLevel, budget))
        }
        textIndex += Int64(1)
    }

    addUnknownWriteChunks(
        plan, budget, unknownChunks, metadata.unknownChunkPolicyValue, AfterPlte
    )

    if (metadata.hasModificationTimeValue && metadata.modificationTimePlacementValue == WriteAfterIdat) {
        plan.addAfterIdat(chargeFixedMetadataChunk(
            budget, makeTimeWriteChunk(metadata.modificationTimeValue)
        ))
    }
    textIndex = Int64(0)
    while (textIndex < textEntries.size) {
        let placed = textEntries[textIndex]
        if (placed.placement == WriteAfterIdat) {
            plan.addAfterIdat(makeTextWriteChunk(placed.entry, compressionLevel, budget))
        }
        textIndex += Int64(1)
    }
    if (metadata.hasExifValue && metadata.exifPlacementValue == WriteAfterIdat) {
        plan.addAfterIdat(chargeFixedMetadataChunk(
            budget, makeExifWriteChunk(metadata.exifValue)
        ))
    }
    addUnknownWriteChunks(
        plan, budget, unknownChunks, metadata.unknownChunkPolicyValue, AfterIdat
    )
    plan
}
