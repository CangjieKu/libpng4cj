package libpng4cj

private func pngPackedUnpackSupported(rowInfo: PngReadRowInfo): Bool {
    let sourceShape =
        (rowInfo.colorType == Grayscale || rowInfo.colorType == Indexed) &&
        rowInfo.channels == UInt8(1)
    let packedDepth = rowInfo.bitDepth == UInt8(1) ||
        rowInfo.bitDepth == UInt8(2) || rowInfo.bitDepth == UInt8(4)
    sourceShape && packedDepth && rowInfo.width > UInt32(0)
}

private func pngUnpackedRowInfo(rowInfo: PngReadRowInfo): PngReadRowInfo {
    PngReadRowInfo(
        rowInfo.width,
        UInt8(8),
        rowInfo.colorType,
        rowInfo.channels
    )
}

private func pngDoUnpack1(rowInfo: PngReadRowInfo, row: Array<Byte>): Array<Byte> {
    let rowWidth = UInt64(rowInfo.width)
    let output = Array<Byte>(Int64(rowInfo.width), repeat: 0)
    var sourceOffset = Int64((rowWidth - UInt64(1)) >> 3)
    var destinationOffset = Int64(rowInfo.width) - 1
    var shift = UInt32(UInt64(7) - ((rowWidth + UInt64(7)) & UInt64(0x07)))
    var pixel: UInt64 = UInt64(0)
    while (pixel < rowWidth) {
        output[destinationOffset] = UInt8(
            (UInt32(row[sourceOffset]) >> shift) & UInt32(0x01)
        )
        if (shift == UInt32(7)) {
            shift = UInt32(0)
            sourceOffset -= 1
        } else {
            shift += 1
        }
        destinationOffset -= 1
        pixel += 1
    }
    output
}

private func pngDoUnpack2(rowInfo: PngReadRowInfo, row: Array<Byte>): Array<Byte> {
    let rowWidth = UInt64(rowInfo.width)
    let output = Array<Byte>(Int64(rowInfo.width), repeat: 0)
    var sourceOffset = Int64((rowWidth - UInt64(1)) >> 2)
    var destinationOffset = Int64(rowInfo.width) - 1
    var shift = UInt32(
        (UInt64(3) - ((rowWidth + UInt64(3)) & UInt64(0x03))) << 1
    )
    var pixel: UInt64 = UInt64(0)
    while (pixel < rowWidth) {
        output[destinationOffset] = UInt8(
            (UInt32(row[sourceOffset]) >> shift) & UInt32(0x03)
        )
        if (shift == UInt32(6)) {
            shift = UInt32(0)
            sourceOffset -= 1
        } else {
            shift += 2
        }
        destinationOffset -= 1
        pixel += 1
    }
    output
}

private func pngDoUnpack4(rowInfo: PngReadRowInfo, row: Array<Byte>): Array<Byte> {
    let rowWidth = UInt64(rowInfo.width)
    let output = Array<Byte>(Int64(rowInfo.width), repeat: 0)
    var sourceOffset = Int64((rowWidth - UInt64(1)) >> 1)
    var destinationOffset = Int64(rowInfo.width) - 1
    var shift = UInt32(
        (UInt64(1) - ((rowWidth + UInt64(1)) & UInt64(0x01))) << 2
    )
    var pixel: UInt64 = UInt64(0)
    while (pixel < rowWidth) {
        output[destinationOffset] = UInt8(
            (UInt32(row[sourceOffset]) >> shift) & UInt32(0x0f)
        )
        if (shift == UInt32(4)) {
            shift = UInt32(0)
            sourceOffset -= 1
        } else {
            shift = UInt32(4)
        }
        destinationOffset -= 1
        pixel += 1
    }
    output
}

public func pngDoUnpack(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!pngPackedUnpackSupported(rowInfo)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = match (rowInfo.bitDepth) {
        case 1 => pngDoUnpack1(rowInfo, row)
        case 2 => pngDoUnpack2(rowInfo, row)
        case 4 => pngDoUnpack4(rowInfo, row)
        case _ => row.clone()
    }
    PngReadTransformRow(pngUnpackedRowInfo(rowInfo), output)
}
