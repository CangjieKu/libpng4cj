package libpng4cj

public let PNG_FILTER_NONE: UInt8 = UInt8(0)
public let PNG_FILTER_SUB: UInt8 = UInt8(1)
public let PNG_FILTER_UP: UInt8 = UInt8(2)
public let PNG_FILTER_AVERAGE: UInt8 = UInt8(3)
public let PNG_FILTER_PAETH: UInt8 = UInt8(4)

private func addByteModulo(left: UInt8, right: UInt8): UInt8 {
    UInt8((UInt16(left) + UInt16(right)) & UInt16(0xff))
}

private func absoluteInt64(value: Int64): Int64 {
    if (value < 0) { -value } else { value }
}

private func paethPredictor(left: UInt8, up: UInt8, upperLeft: UInt8): UInt8 {
    let a = Int64(left)
    let b = Int64(up)
    let c = Int64(upperLeft)
    let estimate = a + b - c
    let distanceA = absoluteInt64(estimate - a)
    let distanceB = absoluteInt64(estimate - b)
    let distanceC = absoluteInt64(estimate - c)
    if (distanceA <= distanceB && distanceA <= distanceC) {
        left
    } else if (distanceB <= distanceC) {
        up
    } else {
        upperLeft
    }
}

public func pngFilterBytesPerPixel(ihdr: PngIhdr): Int64 {
    let bytes = (Int64(ihdr.pixelDepth) + 7) / 8
    if (bytes > 0) { bytes } else { 1 }
}

public func unfilterPngRow(
    filterType: UInt8,
    filtered: Array<Byte>,
    previous: Array<Byte>,
    bytesPerPixel: Int64
): Array<Byte> {
    if (filtered.size != previous.size) {
        throw PngFormatException(InvalidArgument, -1, "current and previous PNG rows differ in size")
    }
    if (bytesPerPixel <= 0) {
        throw PngFormatException(InvalidArgument, -1, "PNG filter bytes-per-pixel must be positive")
    }
    if (filterType > PNG_FILTER_PAETH) {
        throw PngFormatException(InvalidFilter, -1, "PNG row has an invalid adaptive filter value")
    }

    let row = filtered.clone()
    if (filterType == PNG_FILTER_NONE) {
        return row
    }

    var index: Int64 = 0
    while (index < row.size) {
        let left = if (index >= bytesPerPixel) { row[index - bytesPerPixel] } else { UInt8(0) }
        let up = previous[index]
        let upperLeft = if (index >= bytesPerPixel) { previous[index - bytesPerPixel] } else { UInt8(0) }
        let predictor = if (filterType == PNG_FILTER_SUB) {
            left
        } else if (filterType == PNG_FILTER_UP) {
            up
        } else if (filterType == PNG_FILTER_AVERAGE) {
            UInt8((UInt16(left) + UInt16(up)) / UInt16(2))
        } else {
            paethPredictor(left, up, upperLeft)
        }
        row[index] = addByteModulo(row[index], predictor)
        index += 1
    }
    row
}
