package libpng4cj

public enum Png16To8Mode <: Equatable<Png16To8Mode> & ToString {
    | Strip
    | Scale

    public operator func ==(right: Png16To8Mode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: Png16To8Mode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Strip => 0
            case Scale => 1
        }
    }

    public func toString(): String {
        match (this) {
            case Strip => "STRIP"
            case Scale => "SCALE"
        }
    }
}

public class PngRgba8Rows {
    public let ihdr: PngIhdr
    public let metadata: PngReadMetadata
    private let ownedRows: Array<Array<Byte>>

    init(ihdr: PngIhdr, metadata: PngReadMetadata, rows: Array<Array<Byte>>) {
        this.ihdr = ihdr
        this.metadata = metadata
        ownedRows = rows
    }

    public func rowCount(): Int64 {
        ownedRows.size
    }

    public func row(index: Int64): Array<Byte> {
        if (index < 0 || index >= ownedRows.size) {
            throw PngFormatException(InvalidArgument, index, "RGBA8 row index is out of bounds")
        }
        ownedRows[index].clone()
    }

    public func rows(): Array<Array<Byte>> {
        let out = Array<Array<Byte>>(ownedRows.size, repeat: Array<Byte>())
        var index: Int64 = 0
        while (index < ownedRows.size) {
            out[index] = ownedRows[index].clone()
            index += 1
        }
        out
    }
}

public class PngRgba16Rows {
    public let ihdr: PngIhdr
    public let metadata: PngReadMetadata
    private let ownedRows: Array<Array<UInt16>>

    init(ihdr: PngIhdr, metadata: PngReadMetadata, rows: Array<Array<UInt16>>) {
        this.ihdr = ihdr
        this.metadata = metadata
        ownedRows = rows
    }

    public func rowCount(): Int64 {
        ownedRows.size
    }

    public func row(index: Int64): Array<UInt16> {
        if (index < 0 || index >= ownedRows.size) {
            throw PngFormatException(InvalidArgument, index, "RGBA16 row index is out of bounds")
        }
        ownedRows[index].clone()
    }

    public func rows(): Array<Array<UInt16>> {
        let out = Array<Array<UInt16>>(ownedRows.size, repeat: Array<UInt16>())
        var index: Int64 = 0
        while (index < ownedRows.size) {
            out[index] = ownedRows[index].clone()
            index += 1
        }
        out
    }
}

private func transformedRgbaSize(
    ihdr: PngIhdr,
    limits: PngReadLimits,
    bytesPerPixel: UInt64,
    label: String
): Int64 {
    let rowBytes = UInt64(ihdr.width) * bytesPerPixel
    let height = UInt64(ihdr.height)
    if (height > limits.maxTransformedBytes / rowBytes) {
        throw PngFormatException(
            DecodeLimitExceeded,
            -1,
            "${label} rows exceed configured transformed-byte limit"
        )
    }
    Int64(rowBytes * height)
}

private func transformedRgba8Size(ihdr: PngIhdr, limits: PngReadLimits): Int64 {
    transformedRgbaSize(ihdr, limits, UInt64(4), "RGBA8")
}

private func transformedRgba16Size(ihdr: PngIhdr, limits: PngReadLimits): Int64 {
    transformedRgbaSize(ihdr, limits, UInt64(8), "RGBA16")
}

private func packedSample(row: Array<Byte>, pixelIndex: Int64, bitDepth: UInt8): UInt8 {
    if (bitDepth == UInt8(8)) {
        return row[pixelIndex]
    }
    let bits = Int64(bitDepth)
    let bitOffset = pixelIndex * bits
    let byteIndex = bitOffset / 8
    let withinByte = bitOffset % 8
    let shift = UInt32(8 - bits - withinByte)
    let mask = (UInt32(1) << UInt32(bitDepth)) - UInt32(1)
    UInt8((UInt32(row[byteIndex]) >> shift) & mask)
}

private func expandGraySample(sample: UInt8, bitDepth: UInt8): UInt8 {
    if (bitDepth == UInt8(8)) {
        return sample
    }
    let maximum = (UInt16(1) << UInt16(bitDepth)) - UInt16(1)
    UInt8((UInt16(sample) * UInt16(0xff)) / maximum)
}

private func expand8To16(sample: UInt8): UInt16 {
    UInt16(sample) * UInt16(257)
}

private func strip16To8(sample: UInt16): UInt8 {
    UInt8(sample >> 8)
}

private func scale16To8(sample: UInt16): UInt8 {
    UInt8((UInt32(sample) * UInt32(255) + UInt32(32895)) >> 16)
}

private func reduce16To8(sample: UInt16, mode: Png16To8Mode): UInt8 {
    match (mode) {
        case Strip => strip16To8(sample)
        case Scale => scale16To8(sample)
    }
}

private func putRgba(
    output: Array<Byte>,
    pixelIndex: Int64,
    red: UInt8,
    green: UInt8,
    blue: UInt8,
    alpha: UInt8
): Unit {
    let offset = pixelIndex * 4
    output[offset] = red
    output[offset + 1] = green
    output[offset + 2] = blue
    output[offset + 3] = alpha
}

private func putRgba16(
    output: Array<UInt16>,
    pixelIndex: Int64,
    red: UInt16,
    green: UInt16,
    blue: UInt16,
    alpha: UInt16
): Unit {
    let offset = pixelIndex * 4
    output[offset] = red
    output[offset + 1] = green
    output[offset + 2] = blue
    output[offset + 3] = alpha
}

private func expandRowToRgba8(
    row: Array<Byte>,
    ihdr: PngIhdr,
    metadata: PngReadMetadata
): Array<Byte> {
    let width = Int64(ihdr.width)
    let output = Array<Byte>(width * 4, repeat: 0)
    var pixel: Int64 = 0
    match (ihdr.colorType) {
        case Grayscale =>
            while (pixel < width) {
                let sample = packedSample(row, pixel, ihdr.bitDepth)
                let gray = expandGraySample(sample, ihdr.bitDepth)
                let transparencyMask = (UInt16(1) << UInt16(ihdr.bitDepth)) - UInt16(1)
                let transparentSample = metadata.transparentGray & transparencyMask
                let alpha = if (metadata.hasTransparency && UInt16(sample) == transparentSample) {
                    UInt8(0)
                } else {
                    UInt8(0xff)
                }
                putRgba(output, pixel, gray, gray, gray, alpha)
                pixel += 1
            }
        case Truecolor =>
            while (pixel < width) {
                let offset = pixel * 3
                let red = row[offset]
                let green = row[offset + 1]
                let blue = row[offset + 2]
                let transparent = metadata.hasTransparency &&
                    red == UInt8(metadata.transparentRed & UInt16(0xff)) &&
                    green == UInt8(metadata.transparentGreen & UInt16(0xff)) &&
                    blue == UInt8(metadata.transparentBlue & UInt16(0xff))
                let alpha = if (transparent) { UInt8(0) } else { UInt8(0xff) }
                putRgba(output, pixel, red, green, blue, alpha)
                pixel += 1
            }
        case Indexed =>
            while (pixel < width) {
                let paletteIndex = Int64(packedSample(row, pixel, ihdr.bitDepth))
                putRgba(
                    output,
                    pixel,
                    metadata.paletteRed(paletteIndex),
                    metadata.paletteGreen(paletteIndex),
                    metadata.paletteBlue(paletteIndex),
                    metadata.paletteAlphaAt(paletteIndex)
                )
                pixel += 1
            }
        case GrayscaleAlpha =>
            while (pixel < width) {
                let offset = pixel * 2
                let gray = row[offset]
                putRgba(output, pixel, gray, gray, gray, row[offset + 1])
                pixel += 1
            }
        case TruecolorAlpha =>
            while (pixel < width) {
                let offset = pixel * 4
                putRgba(
                    output,
                    pixel,
                    row[offset],
                    row[offset + 1],
                    row[offset + 2],
                    row[offset + 3]
                )
                pixel += 1
            }
    }
    output
}

private func expandRowToRgba16(
    row: Array<Byte>,
    ihdr: PngIhdr,
    metadata: PngReadMetadata
): Array<UInt16> {
    let width = Int64(ihdr.width)
    let output = Array<UInt16>(width * 4, repeat: UInt16(0))
    var pixel: Int64 = 0
    match (ihdr.colorType) {
        case Grayscale =>
            while (pixel < width) {
                var gray: UInt16 = UInt16(0)
                var transparent = false
                if (ihdr.bitDepth == UInt8(16)) {
                    gray = readUInt16Be(row, pixel * 2)
                    transparent = metadata.hasTransparency && gray == metadata.transparentGray
                } else {
                    let sample = packedSample(row, pixel, ihdr.bitDepth)
                    gray = expand8To16(expandGraySample(sample, ihdr.bitDepth))
                    let mask = (UInt16(1) << UInt16(ihdr.bitDepth)) - UInt16(1)
                    transparent = metadata.hasTransparency &&
                        UInt16(sample) == (metadata.transparentGray & mask)
                }
                let alpha = if (transparent) { UInt16(0) } else { UInt16(0xffff) }
                putRgba16(output, pixel, gray, gray, gray, alpha)
                pixel += 1
            }
        case Truecolor =>
            while (pixel < width) {
                var red: UInt16 = UInt16(0)
                var green: UInt16 = UInt16(0)
                var blue: UInt16 = UInt16(0)
                var transparent = false
                if (ihdr.bitDepth == UInt8(16)) {
                    let offset = pixel * 6
                    red = readUInt16Be(row, offset)
                    green = readUInt16Be(row, offset + 2)
                    blue = readUInt16Be(row, offset + 4)
                    transparent = metadata.hasTransparency &&
                        red == metadata.transparentRed &&
                        green == metadata.transparentGreen &&
                        blue == metadata.transparentBlue
                } else {
                    let offset = pixel * 3
                    let red8 = row[offset]
                    let green8 = row[offset + 1]
                    let blue8 = row[offset + 2]
                    red = expand8To16(red8)
                    green = expand8To16(green8)
                    blue = expand8To16(blue8)
                    transparent = metadata.hasTransparency &&
                        red8 == UInt8(metadata.transparentRed & UInt16(0xff)) &&
                        green8 == UInt8(metadata.transparentGreen & UInt16(0xff)) &&
                        blue8 == UInt8(metadata.transparentBlue & UInt16(0xff))
                }
                let alpha = if (transparent) { UInt16(0) } else { UInt16(0xffff) }
                putRgba16(output, pixel, red, green, blue, alpha)
                pixel += 1
            }
        case Indexed =>
            while (pixel < width) {
                let paletteIndex = Int64(packedSample(row, pixel, ihdr.bitDepth))
                putRgba16(
                    output,
                    pixel,
                    expand8To16(metadata.paletteRed(paletteIndex)),
                    expand8To16(metadata.paletteGreen(paletteIndex)),
                    expand8To16(metadata.paletteBlue(paletteIndex)),
                    expand8To16(metadata.paletteAlphaAt(paletteIndex))
                )
                pixel += 1
            }
        case GrayscaleAlpha =>
            while (pixel < width) {
                if (ihdr.bitDepth == UInt8(16)) {
                    let offset = pixel * 4
                    let gray = readUInt16Be(row, offset)
                    putRgba16(output, pixel, gray, gray, gray, readUInt16Be(row, offset + 2))
                } else {
                    let offset = pixel * 2
                    let gray = expand8To16(row[offset])
                    putRgba16(output, pixel, gray, gray, gray, expand8To16(row[offset + 1]))
                }
                pixel += 1
            }
        case TruecolorAlpha =>
            while (pixel < width) {
                if (ihdr.bitDepth == UInt8(16)) {
                    let offset = pixel * 8
                    putRgba16(
                        output,
                        pixel,
                        readUInt16Be(row, offset),
                        readUInt16Be(row, offset + 2),
                        readUInt16Be(row, offset + 4),
                        readUInt16Be(row, offset + 6)
                    )
                } else {
                    let offset = pixel * 4
                    putRgba16(
                        output,
                        pixel,
                        expand8To16(row[offset]),
                        expand8To16(row[offset + 1]),
                        expand8To16(row[offset + 2]),
                        expand8To16(row[offset + 3])
                    )
                }
                pixel += 1
            }
    }
    output
}

private func reduceRgba16Row(row: Array<UInt16>, mode: Png16To8Mode): Array<Byte> {
    let output = Array<Byte>(row.size, repeat: 0)
    var index: Int64 = 0
    while (index < row.size) {
        output[index] = reduce16To8(row[index], mode)
        index += 1
    }
    output
}

public func transformPngRowsToRgba8(
    decoded: PngDecodedRows,
    limits: PngReadLimits
): PngRgba8Rows {
    if (decoded.ihdr.bitDepth > UInt8(8)) {
        throw PngFormatException(
            UnsupportedTransform,
            -1,
            "16-bit PNG input requires an explicit Png16To8Mode"
        )
    }
    transformedRgba8Size(decoded.ihdr, limits)
    let outputRows = Array<Array<Byte>>(decoded.rowCount(), repeat: Array<Byte>())
    var index: Int64 = 0
    while (index < outputRows.size) {
        outputRows[index] = expandRowToRgba8(decoded.row(index), decoded.ihdr, decoded.metadata)
        index += 1
    }
    PngRgba8Rows(decoded.ihdr, decoded.metadata, outputRows)
}

public func transformPngRowsToRgba8(decoded: PngDecodedRows): PngRgba8Rows {
    transformPngRowsToRgba8(decoded, PngReadLimits())
}

public func transformPngRowsToRgba8(
    decoded: PngDecodedRows,
    limits: PngReadLimits,
    mode: Png16To8Mode
): PngRgba8Rows {
    transformedRgba8Size(decoded.ihdr, limits)
    let outputRows = Array<Array<Byte>>(decoded.rowCount(), repeat: Array<Byte>())
    var index: Int64 = 0
    while (index < outputRows.size) {
        let rgba16 = expandRowToRgba16(decoded.row(index), decoded.ihdr, decoded.metadata)
        outputRows[index] = reduceRgba16Row(rgba16, mode)
        index += 1
    }
    PngRgba8Rows(decoded.ihdr, decoded.metadata, outputRows)
}

public func transformPngRowsToRgba8(
    decoded: PngDecodedRows,
    mode: Png16To8Mode
): PngRgba8Rows {
    transformPngRowsToRgba8(decoded, PngReadLimits(), mode)
}

public func transformPngRowsToRgba16(
    decoded: PngDecodedRows,
    limits: PngReadLimits
): PngRgba16Rows {
    transformedRgba16Size(decoded.ihdr, limits)
    let outputRows = Array<Array<UInt16>>(decoded.rowCount(), repeat: Array<UInt16>())
    var index: Int64 = 0
    while (index < outputRows.size) {
        outputRows[index] = expandRowToRgba16(decoded.row(index), decoded.ihdr, decoded.metadata)
        index += 1
    }
    PngRgba16Rows(decoded.ihdr, decoded.metadata, outputRows)
}

public func transformPngRowsToRgba16(decoded: PngDecodedRows): PngRgba16Rows {
    transformPngRowsToRgba16(decoded, PngReadLimits())
}

public func decodePngRgba8NonInterlaced(
    bytes: Array<Byte>,
    limits: PngReadLimits
): PngRgba8Rows {
    transformPngRowsToRgba8(decodePngNonInterlaced(bytes, limits), limits)
}

public func decodePngRgba8NonInterlaced(
    bytes: Array<Byte>,
    limits: PngReadLimits,
    unknownPolicy: PngUnknownChunkPolicy
): PngRgba8Rows {
    transformPngRowsToRgba8(
        decodePngNonInterlaced(bytes, limits, unknownPolicy),
        limits
    )
}

public func decodePngRgba8NonInterlaced(
    bytes: Array<Byte>,
    unknownPolicy: PngUnknownChunkPolicy
): PngRgba8Rows {
    decodePngRgba8NonInterlaced(bytes, PngReadLimits(), unknownPolicy)
}

public func decodePngRgba8NonInterlaced(bytes: Array<Byte>): PngRgba8Rows {
    decodePngRgba8NonInterlaced(bytes, PngReadLimits())
}

public func decodePngRgba8NonInterlaced(
    bytes: Array<Byte>,
    limits: PngReadLimits,
    mode: Png16To8Mode
): PngRgba8Rows {
    transformPngRowsToRgba8(decodePngNonInterlaced(bytes, limits), limits, mode)
}

public func decodePngRgba8NonInterlaced(
    bytes: Array<Byte>,
    limits: PngReadLimits,
    unknownPolicy: PngUnknownChunkPolicy,
    mode: Png16To8Mode
): PngRgba8Rows {
    transformPngRowsToRgba8(
        decodePngNonInterlaced(bytes, limits, unknownPolicy),
        limits,
        mode
    )
}

public func decodePngRgba8NonInterlaced(
    bytes: Array<Byte>,
    unknownPolicy: PngUnknownChunkPolicy,
    mode: Png16To8Mode
): PngRgba8Rows {
    decodePngRgba8NonInterlaced(bytes, PngReadLimits(), unknownPolicy, mode)
}

public func decodePngRgba8NonInterlaced(
    bytes: Array<Byte>,
    mode: Png16To8Mode
): PngRgba8Rows {
    decodePngRgba8NonInterlaced(bytes, PngReadLimits(), mode)
}

public func decodePngRgba16NonInterlaced(
    bytes: Array<Byte>,
    limits: PngReadLimits
): PngRgba16Rows {
    transformPngRowsToRgba16(decodePngNonInterlaced(bytes, limits), limits)
}

public func decodePngRgba16NonInterlaced(
    bytes: Array<Byte>,
    limits: PngReadLimits,
    unknownPolicy: PngUnknownChunkPolicy
): PngRgba16Rows {
    transformPngRowsToRgba16(
        decodePngNonInterlaced(bytes, limits, unknownPolicy),
        limits
    )
}

public func decodePngRgba16NonInterlaced(
    bytes: Array<Byte>,
    unknownPolicy: PngUnknownChunkPolicy
): PngRgba16Rows {
    decodePngRgba16NonInterlaced(bytes, PngReadLimits(), unknownPolicy)
}

public func decodePngRgba16NonInterlaced(bytes: Array<Byte>): PngRgba16Rows {
    decodePngRgba16NonInterlaced(bytes, PngReadLimits())
}
