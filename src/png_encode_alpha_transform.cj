package libpng4cj

private func pngEncodeAlphaChannels(rowInfo: PngReadRowInfo): Int64 {
    if (rowInfo.colorType == GrayscaleAlpha && rowInfo.channels == UInt8(2)) {
        return Int64(2)
    }
    if (rowInfo.colorType == TruecolorAlpha && rowInfo.channels == UInt8(4)) {
        return Int64(4)
    }
    Int64(0)
}

public func pngDoEncodeAlpha(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    table: PngGamma8BitTable
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    let channels = pngEncodeAlphaChannels(rowInfo)
    if (rowInfo.bitDepth != UInt8(8) || channels == Int64(0)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = row.clone()
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let alphaOffset = pixel * channels + channels - 1
        output[alphaOffset] = table.value(output[alphaOffset])
        pixel += 1
    }
    PngReadTransformRow(rowInfo, output)
}

public func pngDoEncodeAlpha(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    table: PngGamma16BitTable
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    let channels = pngEncodeAlphaChannels(rowInfo)
    if (rowInfo.bitDepth != UInt8(16) || channels == Int64(0)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = row.clone()
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let alphaOffset = (pixel * channels + channels - 1) * 2
        let alpha = UInt16(
            (UInt16(output[alphaOffset]) << UInt16(8)) |
            UInt16(output[alphaOffset + 1])
        )
        let encoded = table.value(alpha)
        output[alphaOffset] = UInt8(encoded >> UInt16(8))
        output[alphaOffset + 1] = UInt8(encoded & UInt16(0xff))
        pixel += 1
    }
    PngReadTransformRow(rowInfo, output)
}

public func applyInitializedPngEncodeAlphaStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageEncodeAlpha)) {
        return PngReadTransformRow(rowInfo, row)
    }
    if (rowInfo.bitDepth == UInt8(16)) {
        return pngDoEncodeAlpha(
            rowInfo,
            row,
            initialization.gamma16BitTables().fromLinear()
        )
    }
    pngDoEncodeAlpha(
        rowInfo,
        row,
        initialization.gamma8BitTables().fromLinear()
    )
}
