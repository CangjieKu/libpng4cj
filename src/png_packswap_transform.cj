package libpng4cj

private func pngPackSwapByte(value: Byte, bitDepth: UInt8): Byte {
    let source = UInt32(value)
    if (bitDepth == UInt8(1)) {
        var swapped = ((source & UInt32(0x55)) << 1) |
            ((source >> 1) & UInt32(0x55))
        swapped = ((swapped & UInt32(0x33)) << 2) |
            ((swapped >> 2) & UInt32(0x33))
        swapped = ((swapped & UInt32(0x0f)) << 4) |
            ((swapped >> 4) & UInt32(0x0f))
        return UInt8(swapped)
    }
    if (bitDepth == UInt8(2)) {
        return UInt8(
            ((source & UInt32(0x03)) << 6) |
            ((source & UInt32(0x0c)) << 2) |
            ((source & UInt32(0x30)) >> 2) |
            ((source & UInt32(0xc0)) >> 6)
        )
    }
    if (bitDepth == UInt8(4)) {
        return UInt8(
            ((source & UInt32(0x0f)) << 4) |
            ((source & UInt32(0xf0)) >> 4)
        )
    }
    value
}

public func pngDoPackSwap(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (rowInfo.bitDepth != UInt8(1) && rowInfo.bitDepth != UInt8(2) &&
        rowInfo.bitDepth != UInt8(4)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = Array<Byte>(row.size, repeat: 0)
    var index: Int64 = 0
    while (index < row.size) {
        output[index] = pngPackSwapByte(row[index], rowInfo.bitDepth)
        index += 1
    }
    PngReadTransformRow(rowInfo, output)
}

public func applyInitializedPngPackSwapStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStagePackSwap)) {
        return PngReadTransformRow(rowInfo, row)
    }
    pngDoPackSwap(rowInfo, row)
}
