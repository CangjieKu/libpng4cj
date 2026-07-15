package libpng4cj

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

private func transformedRgba8Size(ihdr: PngIhdr, limits: PngReadLimits): Int64 {
    let rowBytes = UInt64(ihdr.width) * UInt64(4)
    let height = UInt64(ihdr.height)
    if (height > limits.maxTransformedBytes / rowBytes) {
        throw PngFormatException(
            DecodeLimitExceeded,
            -1,
            "RGBA8 rows exceed configured transformed-byte limit"
        )
    }
    Int64(rowBytes * height)
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

public func transformPngRowsToRgba8(
    decoded: PngDecodedRows,
    limits: PngReadLimits
): PngRgba8Rows {
    if (decoded.ihdr.bitDepth > UInt8(8)) {
        throw PngFormatException(
            UnsupportedTransform,
            -1,
            "LP-S004A RGBA8 expansion does not yet define 16-bit reduction"
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

public func decodePngRgba8NonInterlaced(
    bytes: Array<Byte>,
    limits: PngReadLimits
): PngRgba8Rows {
    transformPngRowsToRgba8(decodePngNonInterlaced(bytes, limits), limits)
}

public func decodePngRgba8NonInterlaced(bytes: Array<Byte>): PngRgba8Rows {
    decodePngRgba8NonInterlaced(bytes, PngReadLimits())
}
