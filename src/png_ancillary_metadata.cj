package libpng4cj

import std.collection.ArrayList

public class PngCodingIndependentCodePoints {
    public let colorPrimaries: UInt8
    public let transferFunction: UInt8
    public let matrixCoefficients: UInt8
    public let fullRangeFlag: UInt8

    init() {
        colorPrimaries = UInt8(0)
        transferFunction = UInt8(0)
        matrixCoefficients = UInt8(0)
        fullRangeFlag = UInt8(0)
    }

    public init(colorPrimaries: UInt8, transferFunction: UInt8, matrixCoefficients: UInt8, fullRangeFlag: UInt8) {
        this.colorPrimaries = colorPrimaries
        this.transferFunction = transferFunction
        this.matrixCoefficients = matrixCoefficients
        this.fullRangeFlag = fullRangeFlag
    }
}

public class PngContentLightLevel {
    public let maximumContentLightLevel: UInt32
    public let maximumFrameAverageLightLevel: UInt32

    init() {
        maximumContentLightLevel = UInt32(0)
        maximumFrameAverageLightLevel = UInt32(0)
    }

    public init(maximumContentLightLevel: UInt32, maximumFrameAverageLightLevel: UInt32) {
        this.maximumContentLightLevel = maximumContentLightLevel
        this.maximumFrameAverageLightLevel = maximumFrameAverageLightLevel
    }
}

public class PngMasteringDisplayColorVolume {
    public let chromaticities: PngChromaticities
    public let maximumDisplayLuminance: UInt32
    public let minimumDisplayLuminance: UInt32

    init() {
        chromaticities = PngChromaticities()
        maximumDisplayLuminance = UInt32(0)
        minimumDisplayLuminance = UInt32(0)
    }

    public init(chromaticities: PngChromaticities, maximumDisplayLuminance: UInt32, minimumDisplayLuminance: UInt32) {
        this.chromaticities = chromaticities
        this.maximumDisplayLuminance = maximumDisplayLuminance
        this.minimumDisplayLuminance = minimumDisplayLuminance
    }
}

public class PngImageOffset {
    public let x: Int32
    public let y: Int32
    public let unit: UInt8

    init() {
        x = Int32(0)
        y = Int32(0)
        unit = UInt8(0)
    }

    public init(x: Int32, y: Int32, unit: UInt8) {
        this.x = x
        this.y = y
        this.unit = unit
    }
}

public class PngPixelCalibration {
    public let x0: Int32
    public let x1: Int32
    public let equationType: UInt8
    private let ownedPurpose: Array<Byte>
    private let ownedUnits: Array<Byte>
    private let ownedParameters: Array<Array<Byte>>

    init() {
        x0 = Int32(0)
        x1 = Int32(0)
        equationType = UInt8(0)
        ownedPurpose = Array<Byte>()
        ownedUnits = Array<Byte>()
        ownedParameters = Array<Array<Byte>>()
    }

    public init(
        purpose: Array<Byte>,
        x0: Int32,
        x1: Int32,
        equationType: UInt8,
        units: Array<Byte>,
        parameters: Array<Array<Byte>>
    ) {
        ownedPurpose = purpose.clone()
        this.x0 = x0
        this.x1 = x1
        this.equationType = equationType
        ownedUnits = units.clone()
        ownedParameters = pngCloneByteRows(parameters)
    }

    public func purpose(): Array<Byte> { ownedPurpose.clone() }
    public func units(): Array<Byte> { ownedUnits.clone() }
    public func parameterCount(): Int64 { ownedParameters.size }

    public func parameter(index: Int64): Array<Byte> {
        if (index < 0 || index >= ownedParameters.size) {
            throw PngFormatException(InvalidArgument, index, "PNG pCAL parameter index is out of bounds")
        }
        ownedParameters[index].clone()
    }

    public func parameters(): Array<Array<Byte>> { pngCloneByteRows(ownedParameters) }
}

public class PngPhysicalScale {
    public let unit: UInt8
    private let ownedWidth: Array<Byte>
    private let ownedHeight: Array<Byte>

    init() {
        unit = UInt8(0)
        ownedWidth = Array<Byte>()
        ownedHeight = Array<Byte>()
    }

    public init(unit: UInt8, width: Array<Byte>, height: Array<Byte>) {
        this.unit = unit
        ownedWidth = width.clone()
        ownedHeight = height.clone()
    }

    public func width(): Array<Byte> { ownedWidth.clone() }
    public func height(): Array<Byte> { ownedHeight.clone() }
}

public class PngSuggestedPaletteEntry {
    public let red: UInt16
    public let green: UInt16
    public let blue: UInt16
    public let alpha: UInt16
    public let frequency: UInt16

    public init(red: UInt16, green: UInt16, blue: UInt16, alpha: UInt16, frequency: UInt16) {
        this.red = red
        this.green = green
        this.blue = blue
        this.alpha = alpha
        this.frequency = frequency
    }
}

public class PngSuggestedPalette {
    public let sampleDepth: UInt8
    private let ownedName: Array<Byte>
    private let ownedEntries: Array<PngSuggestedPaletteEntry>

    public init(name: Array<Byte>, sampleDepth: UInt8, entries: Array<PngSuggestedPaletteEntry>) {
        ownedName = name.clone()
        this.sampleDepth = sampleDepth
        ownedEntries = entries.clone()
    }

    public func name(): Array<Byte> { ownedName.clone() }
    public func entryCount(): Int64 { ownedEntries.size }

    public func entry(index: Int64): PngSuggestedPaletteEntry {
        if (index < 0 || index >= ownedEntries.size) {
            throw PngFormatException(InvalidArgument, index, "PNG sPLT entry index is out of bounds")
        }
        ownedEntries[index]
    }

    public func entries(): Array<PngSuggestedPaletteEntry> { ownedEntries.clone() }
}

private func pngCloneByteRows(rows: Array<Array<Byte>>): Array<Array<Byte>> {
    let out = Array<Array<Byte>>(rows.size, repeat: Array<Byte>())
    var index: Int64 = 0
    while (index < rows.size) {
        out[index] = rows[index].clone()
        index += 1
    }
    out
}

private func pngFindZero(bytes: Array<Byte>, start: Int64): Int64 {
    var index = start
    while (index < bytes.size && bytes[index] != UInt8(0)) { index += 1 }
    index
}

func pngValidKeyword(bytes: Array<Byte>): Bool {
    if (bytes.size < 1 || bytes.size > 79 || bytes[0] == UInt8(0x20) ||
        bytes[bytes.size - 1] == UInt8(0x20)) {
        return false
    }
    var previousSpace = false
    var index: Int64 = 0
    while (index < bytes.size) {
        let value = bytes[index]
        let valid = (value >= UInt8(0x20) && value <= UInt8(0x7e)) || value >= UInt8(0xa1)
        if (!valid || (value == UInt8(0x20) && previousSpace)) {
            return false
        }
        previousSpace = value == UInt8(0x20)
        index += 1
    }
    true
}

private func pngReadSignedInt32(bytes: Array<Byte>, offset: Int64): Int32 {
    let value = readUInt32Be(bytes, offset)
    if (value <= PNG_UINT_31_MAX) { return Int32(value) }
    if (value == UInt32(0x8000_0000)) { return Int32(-2147483647) - Int32(1) }
    -Int32((value ^ UInt32(0xffff_ffff)) + UInt32(1))
}

private func pngAsciiDigit(value: UInt8): Bool {
    value >= UInt8(0x30) && value <= UInt8(0x39)
}

func pngValidAsciiNumber(bytes: Array<Byte>): Bool {
    if (bytes.size == 0) { return false }
    var index: Int64 = 0
    if (bytes[index] == UInt8(0x2b) || bytes[index] == UInt8(0x2d)) {
        index += 1
    }
    var digits: Int64 = 0
    while (index < bytes.size && pngAsciiDigit(bytes[index])) {
        digits += 1
        index += 1
    }
    if (index < bytes.size && bytes[index] == UInt8(0x2e)) {
        index += 1
        while (index < bytes.size && pngAsciiDigit(bytes[index])) {
            digits += 1
            index += 1
        }
    }
    if (digits == 0) { return false }
    if (index < bytes.size && (bytes[index] == UInt8(0x45) || bytes[index] == UInt8(0x65))) {
        index += 1
        if (index < bytes.size && (bytes[index] == UInt8(0x2b) || bytes[index] == UInt8(0x2d))) {
            index += 1
        }
        var exponentDigits: Int64 = 0
        while (index < bytes.size && pngAsciiDigit(bytes[index])) {
            exponentDigits += 1
            index += 1
        }
        if (exponentDigits == 0) { return false }
    }
    index == bytes.size
}

func pngPositiveAsciiNumber(bytes: Array<Byte>): Bool {
    if (!pngValidAsciiNumber(bytes) || bytes[0] == UInt8(0x2d)) { return false }
    var index: Int64 = 0
    while (index < bytes.size && bytes[index] != UInt8(0x45) && bytes[index] != UInt8(0x65)) {
        if (bytes[index] >= UInt8(0x31) && bytes[index] <= UInt8(0x39)) { return true }
        index += 1
    }
    false
}

private func pngRequireBeforeIdat(seenIdat: Bool, chunk: PngChunk, name: String): Unit {
    if (seenIdat) {
        throw PngFormatException(MetadataOutOfOrder, chunk.offset, "${name} must precede IDAT")
    }
}

private func pngRequireBeforePalette(
    seenPalette: Bool,
    seenIdat: Bool,
    chunk: PngChunk,
    name: String
): Unit {
    if (seenPalette || seenIdat) {
        throw PngFormatException(MetadataOutOfOrder, chunk.offset, "${name} must precede PLTE and IDAT")
    }
}

private func pngRequireSingle(present: Bool, chunk: PngChunk, name: String): Unit {
    if (present) {
        throw PngFormatException(DuplicateMetadata, chunk.offset, "PNG contains more than one ${name} chunk")
    }
}

private func pngParseCalibration(chunk: PngChunk): PngPixelCalibration {
    let data = chunk.payload()
    let purposeEnd = pngFindZero(data, 0)
    if (purposeEnd < 1 || purposeEnd > 79 || data.size - purposeEnd <= 12) {
        throw PngFormatException(InvalidMetadata, chunk.offset, "pCAL purpose or fixed fields are invalid")
    }
    let x0 = pngReadSignedInt32(data, purposeEnd + 1)
    let x1 = pngReadSignedInt32(data, purposeEnd + 5)
    let equationType = data[purposeEnd + 9]
    let parameterCount = Int64(data[purposeEnd + 10])
    let expected = match (equationType) {
        case 0 => Int64(2)
        case 1 | 2 => Int64(3)
        case 3 => Int64(4)
        case _ => throw PngFormatException(InvalidMetadata, chunk.offset, "pCAL equation type must be in 0..3")
    }
    if (parameterCount != expected) {
        throw PngFormatException(InvalidMetadata, chunk.offset, "pCAL parameter count does not match equation type")
    }
    let unitsStart = purposeEnd + 11
    let unitsEnd = pngFindZero(data, unitsStart)
    if (unitsEnd >= data.size) {
        throw PngFormatException(InvalidMetadata, chunk.offset, "pCAL units are not terminated")
    }
    let parameters = Array<Array<Byte>>(parameterCount, repeat: Array<Byte>())
    var cursor = unitsEnd + 1
    var parameterIndex: Int64 = 0
    while (parameterIndex < parameterCount) {
        let end = pngFindZero(data, cursor)
        if (end > data.size || (end == data.size && parameterIndex + 1 < parameterCount)) {
            throw PngFormatException(InvalidMetadata, chunk.offset, "pCAL parameter data is truncated")
        }
        if (parameterIndex + 1 == parameterCount && end < data.size - 1) {
            throw PngFormatException(InvalidMetadata, chunk.offset, "pCAL contains trailing parameter data")
        }
        let value = copyByteRange(data, cursor, end - cursor)
        if (!pngValidAsciiNumber(value)) {
            throw PngFormatException(InvalidMetadata, chunk.offset, "pCAL parameter is not a valid ASCII number")
        }
        parameters[parameterIndex] = value
        cursor = end + 1
        parameterIndex += 1
    }
    PngPixelCalibration(
        copyByteRange(data, 0, purposeEnd),
        x0,
        x1,
        equationType,
        copyByteRange(data, unitsStart, unitsEnd - unitsStart),
        parameters
    )
}

private func pngParsePhysicalScale(chunk: PngChunk): PngPhysicalScale {
    let data = chunk.payload()
    if (data.size < 4 || (data[0] != UInt8(1) && data[0] != UInt8(2))) {
        throw PngFormatException(InvalidMetadata, chunk.offset, "sCAL unit or length is invalid")
    }
    let widthEnd = pngFindZero(data, 1)
    if (widthEnd >= data.size - 1) {
        throw PngFormatException(InvalidMetadata, chunk.offset, "sCAL width or height is missing")
    }
    let width = copyByteRange(data, 1, widthEnd - 1)
    let height = copyByteRange(data, widthEnd + 1, data.size - widthEnd - 1)
    if (!pngPositiveAsciiNumber(width) || !pngPositiveAsciiNumber(height)) {
        throw PngFormatException(InvalidMetadata, chunk.offset, "sCAL dimensions must be positive ASCII numbers")
    }
    PngPhysicalScale(data[0], width, height)
}

private func pngParseSuggestedPalette(chunk: PngChunk): PngSuggestedPalette {
    let data = chunk.payload()
    let nameEnd = pngFindZero(data, 0)
    if (nameEnd < 1 || nameEnd > 79 || nameEnd + 2 > data.size) {
        throw PngFormatException(InvalidMetadata, chunk.offset, "sPLT name or depth is invalid")
    }
    let name = copyByteRange(data, 0, nameEnd)
    if (!pngValidKeyword(name)) {
        throw PngFormatException(InvalidMetadata, chunk.offset, "sPLT name is not a valid PNG keyword")
    }
    let depth = data[nameEnd + 1]
    let entrySize = if (depth == UInt8(8)) {
        Int64(6)
    } else if (depth == UInt8(16)) {
        Int64(10)
    } else {
        throw PngFormatException(InvalidMetadata, chunk.offset, "sPLT depth must be 8 or 16")
    }
    let entryStart = nameEnd + 2
    let entryBytes = data.size - entryStart
    if (entryBytes == 0 || entryBytes % entrySize != 0) {
        throw PngFormatException(InvalidMetadata, chunk.offset, "sPLT entry data has an invalid length")
    }
    let entries = Array<PngSuggestedPaletteEntry>(entryBytes / entrySize, repeat:
        PngSuggestedPaletteEntry(UInt16(0), UInt16(0), UInt16(0), UInt16(0), UInt16(0)))
    var index: Int64 = 0
    while (index < entries.size) {
        let offset = entryStart + index * entrySize
        entries[index] = if (depth == UInt8(8)) {
            PngSuggestedPaletteEntry(
                UInt16(data[offset]),
                UInt16(data[offset + 1]),
                UInt16(data[offset + 2]),
                UInt16(data[offset + 3]),
                readUInt16Be(data, offset + 4)
            )
        } else {
            PngSuggestedPaletteEntry(
                readUInt16Be(data, offset),
                readUInt16Be(data, offset + 2),
                readUInt16Be(data, offset + 4),
                readUInt16Be(data, offset + 6),
                readUInt16Be(data, offset + 8)
            )
        }
        index += 1
    }
    PngSuggestedPalette(name, depth, entries)
}

class ParsedPngAncillaryMetadata {
    var hasCicp: Bool = false
    var cicp: PngCodingIndependentCodePoints = PngCodingIndependentCodePoints()
    var hasContentLightLevel: Bool = false
    var contentLightLevel: PngContentLightLevel = PngContentLightLevel()
    var hasMasteringDisplay: Bool = false
    var masteringDisplay: PngMasteringDisplayColorVolume = PngMasteringDisplayColorVolume()
    var hasExif: Bool = false
    var exifBeforeIdat: Bool = false
    var exif: Array<Byte> = Array<Byte>()
    var hasHistogram: Bool = false
    var histogram: Array<UInt16> = Array<UInt16>()
    var hasOffset: Bool = false
    var imageOffset: PngImageOffset = PngImageOffset()
    var hasCalibration: Bool = false
    var calibration: PngPixelCalibration = PngPixelCalibration()
    var hasPhysicalScale: Bool = false
    var physicalScale: PngPhysicalScale = PngPhysicalScale()
    private let suggestedPalettesValue = ArrayList<PngSuggestedPalette>()

    func suggestedPalettes(): Array<PngSuggestedPalette> { suggestedPalettesValue.toArray() }

    func handleChunk(
        chunk: PngChunk,
        seenPalette: Bool,
        seenIdat: Bool,
        palette: Array<Byte>
    ): Bool {
        if (chunk.isType(PNG_CHUNK_cICP)) {
            pngRequireBeforePalette(seenPalette, seenIdat, chunk, "cICP")
            pngRequireSingle(hasCicp, chunk, "cICP")
            if (chunk.length != UInt32(4)) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "cICP length must be 4")
            }
            let data = chunk.payload()
            if (data[2] != UInt8(0)) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "cICP matrix coefficients must be zero for PNG")
            }
            cicp = PngCodingIndependentCodePoints(data[0], data[1], data[2], data[3])
            hasCicp = true
            return true
        }
        if (chunk.isType(PNG_CHUNK_cLLI)) {
            pngRequireBeforePalette(seenPalette, seenIdat, chunk, "cLLI")
            pngRequireSingle(hasContentLightLevel, chunk, "cLLI")
            if (chunk.length != UInt32(8)) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "cLLI length must be 8")
            }
            let data = chunk.payload()
            let maximum = readUInt32Be(data, 0)
            let average = readUInt32Be(data, 4)
            if (maximum > PNG_UINT_31_MAX || average > PNG_UINT_31_MAX) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "cLLI values exceed the PNG limit")
            }
            contentLightLevel = PngContentLightLevel(maximum, average)
            hasContentLightLevel = true
            return true
        }
        if (chunk.isType(PNG_CHUNK_mDCV)) {
            pngRequireBeforePalette(seenPalette, seenIdat, chunk, "mDCV")
            pngRequireSingle(hasMasteringDisplay, chunk, "mDCV")
            if (chunk.length != UInt32(24)) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "mDCV length must be 24")
            }
            let data = chunk.payload()
            let maximum = readUInt32Be(data, 16)
            let minimum = readUInt32Be(data, 20)
            if (maximum > PNG_UINT_31_MAX || minimum > PNG_UINT_31_MAX) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "mDCV luminance exceeds the PNG limit")
            }
            masteringDisplay = PngMasteringDisplayColorVolume(
                PngChromaticities(
                    Int32(readUInt16Be(data, 12)) * Int32(2),
                    Int32(readUInt16Be(data, 14)) * Int32(2),
                    Int32(readUInt16Be(data, 0)) * Int32(2),
                    Int32(readUInt16Be(data, 2)) * Int32(2),
                    Int32(readUInt16Be(data, 4)) * Int32(2),
                    Int32(readUInt16Be(data, 6)) * Int32(2),
                    Int32(readUInt16Be(data, 8)) * Int32(2),
                    Int32(readUInt16Be(data, 10)) * Int32(2)
                ),
                maximum,
                minimum
            )
            hasMasteringDisplay = true
            return true
        }
        if (chunk.isType(PNG_CHUNK_eXIf)) {
            pngRequireSingle(hasExif, chunk, "eXIf")
            let data = chunk.payload()
            if (data.size < 4) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "eXIf length must be at least 4")
            }
            let header = readUInt32Be(data, 0)
            if (header != UInt32(0x4949_2a00) && header != UInt32(0x4d4d_002a)) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "eXIf TIFF header is invalid")
            }
            exif = data.clone()
            hasExif = true
            exifBeforeIdat = !seenIdat
            return true
        }
        if (chunk.isType(PNG_CHUNK_hIST)) {
            pngRequireBeforeIdat(seenIdat, chunk, "hIST")
            pngRequireSingle(hasHistogram, chunk, "hIST")
            if (!seenPalette || palette.size == 0) {
                throw PngFormatException(MetadataOutOfOrder, chunk.offset, "hIST requires PLTE first")
            }
            let paletteCount = palette.size / 3
            if (chunk.length != UInt32(paletteCount * 2)) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "hIST length must match PLTE entries")
            }
            let data = chunk.payload()
            histogram = Array<UInt16>(paletteCount, repeat: UInt16(0))
            var index: Int64 = 0
            while (index < paletteCount) {
                histogram[index] = readUInt16Be(data, index * 2)
                index += 1
            }
            hasHistogram = true
            return true
        }
        if (chunk.isType(PNG_CHUNK_oFFs)) {
            pngRequireBeforeIdat(seenIdat, chunk, "oFFs")
            pngRequireSingle(hasOffset, chunk, "oFFs")
            if (chunk.length != UInt32(9)) {
                throw PngFormatException(InvalidMetadata, chunk.offset, "oFFs length must be 9")
            }
            let data = chunk.payload()
            imageOffset = PngImageOffset(pngReadSignedInt32(data, 0), pngReadSignedInt32(data, 4), data[8])
            hasOffset = true
            return true
        }
        if (chunk.isType(PNG_CHUNK_pCAL)) {
            pngRequireBeforeIdat(seenIdat, chunk, "pCAL")
            pngRequireSingle(hasCalibration, chunk, "pCAL")
            calibration = pngParseCalibration(chunk)
            hasCalibration = true
            return true
        }
        if (chunk.isType(PNG_CHUNK_sCAL)) {
            pngRequireBeforeIdat(seenIdat, chunk, "sCAL")
            pngRequireSingle(hasPhysicalScale, chunk, "sCAL")
            physicalScale = pngParsePhysicalScale(chunk)
            hasPhysicalScale = true
            return true
        }
        if (chunk.isType(PNG_CHUNK_sPLT)) {
            pngRequireBeforeIdat(seenIdat, chunk, "sPLT")
            suggestedPalettesValue.add(pngParseSuggestedPalette(chunk))
            return true
        }
        false
    }
}
