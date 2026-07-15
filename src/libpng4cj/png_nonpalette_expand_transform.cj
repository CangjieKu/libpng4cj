package libpng4cj

public class PngExpandTransparency {
    public let present: Bool
    public let gray: UInt16
    public let red: UInt16
    public let green: UInt16
    public let blue: UInt16

    public init() {
        present = false
        gray = UInt16(0)
        red = UInt16(0)
        green = UInt16(0)
        blue = UInt16(0)
    }

    public init(gray: UInt16) {
        present = true
        this.gray = gray
        red = UInt16(0)
        green = UInt16(0)
        blue = UInt16(0)
    }

    public init(red: UInt16, green: UInt16, blue: UInt16) {
        present = true
        gray = UInt16(0)
        this.red = red
        this.green = green
        this.blue = blue
    }
}

private func pngPackedGrayExpandSupported(rowInfo: PngReadRowInfo): Bool {
    rowInfo.colorType == Grayscale && rowInfo.channels == UInt8(1) &&
        (rowInfo.bitDepth == UInt8(1) || rowInfo.bitDepth == UInt8(2) ||
        rowInfo.bitDepth == UInt8(4))
}

private func pngGrayExpandFactor(bitDepth: UInt8): UInt16 {
    match (bitDepth) {
        case 1 => UInt16(0xff)
        case 2 => UInt16(0x55)
        case 4 => UInt16(0x11)
        case _ => UInt16(1)
    }
}

private func pngExpandPackedGrayRow(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): Array<Byte> {
    let unpacked = pngDoUnpack(rowInfo, row).row()
    let factor = pngGrayExpandFactor(rowInfo.bitDepth)
    var index: Int64 = 0
    while (index < unpacked.size) {
        unpacked[index] = UInt8(UInt16(unpacked[index]) * factor)
        index += 1
    }
    unpacked
}

private func pngExpandedGrayKey(
    bitDepth: UInt8,
    gray: UInt16
): UInt16 {
    if (bitDepth < UInt8(8)) {
        let mask = (UInt16(1) << UInt16(bitDepth)) - UInt16(1)
        (gray & mask) * pngGrayExpandFactor(bitDepth)
    } else if (bitDepth == UInt8(8)) {
        gray & UInt16(0xff)
    } else {
        gray
    }
}

private func pngExpandedAlphaInfo(
    rowInfo: PngReadRowInfo,
    colorType: PngColorType,
    channels: UInt8
): PngReadRowInfo {
    PngReadRowInfo(
        rowInfo.width,
        rowInfo.bitDepth,
        colorType,
        channels
    )
}

private func pngExpandGrayAlpha8(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    transparentGray: UInt16
): PngReadTransformRow {
    let output = Array<Byte>(Int64(rowInfo.width) * 2, repeat: 0)
    let key = UInt8(transparentGray & UInt16(0xff))
    var sourceOffset = row.size - 1
    var destinationOffset = output.size - 1
    var pixel: UInt64 = UInt64(0)
    while (pixel < UInt64(rowInfo.width)) {
        let gray = row[sourceOffset]
        output[destinationOffset] = if (gray == key) {
            UInt8(0)
        } else {
            UInt8(0xff)
        }
        output[destinationOffset - 1] = gray
        sourceOffset -= 1
        destinationOffset -= 2
        pixel += 1
    }
    PngReadTransformRow(
        pngExpandedAlphaInfo(rowInfo, GrayscaleAlpha, UInt8(2)),
        output
    )
}

private func pngExpandGrayAlpha16(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    transparentGray: UInt16
): PngReadTransformRow {
    let output = Array<Byte>(Int64(rowInfo.width) * 4, repeat: 0)
    let keyHigh = UInt8(transparentGray >> 8)
    let keyLow = UInt8(transparentGray & UInt16(0xff))
    var sourceOffset = row.size - 1
    var destinationOffset = output.size - 1
    var pixel: UInt64 = UInt64(0)
    while (pixel < UInt64(rowInfo.width)) {
        let transparent = row[sourceOffset - 1] == keyHigh &&
            row[sourceOffset] == keyLow
        let alpha = if (transparent) { UInt8(0) } else { UInt8(0xff) }
        output[destinationOffset] = alpha
        output[destinationOffset - 1] = alpha
        output[destinationOffset - 2] = row[sourceOffset]
        output[destinationOffset - 3] = row[sourceOffset - 1]
        sourceOffset -= 2
        destinationOffset -= 4
        pixel += 1
    }
    PngReadTransformRow(
        pngExpandedAlphaInfo(rowInfo, GrayscaleAlpha, UInt8(2)),
        output
    )
}

private func pngExpandGrayAlpha(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    transparentGray: UInt16
): PngReadTransformRow {
    match (rowInfo.bitDepth) {
        case 8 => pngExpandGrayAlpha8(rowInfo, row, transparentGray)
        case 16 => pngExpandGrayAlpha16(rowInfo, row, transparentGray)
        case _ => PngReadTransformRow(rowInfo, row)
    }
}

private func pngExpandRgbAlpha8(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    transparency: PngExpandTransparency
): PngReadTransformRow {
    let output = Array<Byte>(Int64(rowInfo.width) * 4, repeat: 0)
    let red = UInt8(transparency.red & UInt16(0xff))
    let green = UInt8(transparency.green & UInt16(0xff))
    let blue = UInt8(transparency.blue & UInt16(0xff))
    var sourceOffset = row.size - 1
    var destinationOffset = output.size - 1
    var pixel: UInt64 = UInt64(0)
    while (pixel < UInt64(rowInfo.width)) {
        let transparent = row[sourceOffset - 2] == red &&
            row[sourceOffset - 1] == green && row[sourceOffset] == blue
        output[destinationOffset] = if (transparent) {
            UInt8(0)
        } else {
            UInt8(0xff)
        }
        output[destinationOffset - 1] = row[sourceOffset]
        output[destinationOffset - 2] = row[sourceOffset - 1]
        output[destinationOffset - 3] = row[sourceOffset - 2]
        sourceOffset -= 3
        destinationOffset -= 4
        pixel += 1
    }
    PngReadTransformRow(
        pngExpandedAlphaInfo(rowInfo, TruecolorAlpha, UInt8(4)),
        output
    )
}

private func pngExpandRgbAlpha16(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    transparency: PngExpandTransparency
): PngReadTransformRow {
    let output = Array<Byte>(Int64(rowInfo.width) * 8, repeat: 0)
    let redHigh = UInt8(transparency.red >> 8)
    let redLow = UInt8(transparency.red & UInt16(0xff))
    let greenHigh = UInt8(transparency.green >> 8)
    let greenLow = UInt8(transparency.green & UInt16(0xff))
    let blueHigh = UInt8(transparency.blue >> 8)
    let blueLow = UInt8(transparency.blue & UInt16(0xff))
    var sourceOffset = row.size - 1
    var destinationOffset = output.size - 1
    var pixel: UInt64 = UInt64(0)
    while (pixel < UInt64(rowInfo.width)) {
        let transparent = row[sourceOffset - 5] == redHigh &&
            row[sourceOffset - 4] == redLow &&
            row[sourceOffset - 3] == greenHigh &&
            row[sourceOffset - 2] == greenLow &&
            row[sourceOffset - 1] == blueHigh && row[sourceOffset] == blueLow
        let alpha = if (transparent) { UInt8(0) } else { UInt8(0xff) }
        output[destinationOffset] = alpha
        output[destinationOffset - 1] = alpha
        output[destinationOffset - 2] = row[sourceOffset]
        output[destinationOffset - 3] = row[sourceOffset - 1]
        output[destinationOffset - 4] = row[sourceOffset - 2]
        output[destinationOffset - 5] = row[sourceOffset - 3]
        output[destinationOffset - 6] = row[sourceOffset - 4]
        output[destinationOffset - 7] = row[sourceOffset - 5]
        sourceOffset -= 6
        destinationOffset -= 8
        pixel += 1
    }
    PngReadTransformRow(
        pngExpandedAlphaInfo(rowInfo, TruecolorAlpha, UInt8(4)),
        output
    )
}

private func pngExpandRgbAlpha(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    transparency: PngExpandTransparency
): PngReadTransformRow {
    match (rowInfo.bitDepth) {
        case 8 => pngExpandRgbAlpha8(rowInfo, row, transparency)
        case 16 => pngExpandRgbAlpha16(rowInfo, row, transparency)
        case _ => PngReadTransformRow(rowInfo, row)
    }
}

public func pngDoExpand(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    transparency: PngExpandTransparency
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (rowInfo.width == UInt32(0)) {
        return PngReadTransformRow(rowInfo, row)
    }

    if (pngPackedGrayExpandSupported(rowInfo)) {
        let expandedRow = pngExpandPackedGrayRow(rowInfo, row)
        let expandedInfo = PngReadRowInfo(
            rowInfo.width,
            UInt8(8),
            Grayscale,
            UInt8(1)
        )
        if (transparency.present) {
            return pngExpandGrayAlpha(
                expandedInfo,
                expandedRow,
                pngExpandedGrayKey(rowInfo.bitDepth, transparency.gray)
            )
        }
        return PngReadTransformRow(expandedInfo, expandedRow)
    }

    if (rowInfo.colorType == Grayscale && rowInfo.channels == UInt8(1) &&
        transparency.present && (rowInfo.bitDepth == UInt8(8) ||
        rowInfo.bitDepth == UInt8(16))) {
        return pngExpandGrayAlpha(
            rowInfo,
            row,
            pngExpandedGrayKey(rowInfo.bitDepth, transparency.gray)
        )
    }

    if (rowInfo.colorType == Truecolor && rowInfo.channels == UInt8(3) &&
        transparency.present && (rowInfo.bitDepth == UInt8(8) ||
        rowInfo.bitDepth == UInt8(16))) {
        return pngExpandRgbAlpha(rowInfo, row, transparency)
    }

    PngReadTransformRow(rowInfo, row)
}
