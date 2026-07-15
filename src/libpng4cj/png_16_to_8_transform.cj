package libpng4cj

private func png16To8OutputInfo(rowInfo: PngReadRowInfo): PngReadRowInfo {
    PngReadRowInfo(rowInfo.width, UInt8(8), rowInfo.colorType)
}

private func pngScale16Component(high: Byte, low: Byte): Byte {
    let value = (UInt32(high) << 8) | UInt32(low)
    UInt8((value * UInt32(255) + UInt32(32895)) >> 16)
}

public func pngDoScale16To8(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (rowInfo.bitDepth != UInt8(16)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = Array<Byte>(row.size / 2, repeat: 0)
    var sourceOffset: Int64 = 0
    var outputOffset: Int64 = 0
    while (sourceOffset < row.size) {
        output[outputOffset] = pngScale16Component(
            row[sourceOffset], row[sourceOffset + 1]
        )
        sourceOffset += 2
        outputOffset += 1
    }
    PngReadTransformRow(png16To8OutputInfo(rowInfo), output)
}

public func pngDoChop(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (rowInfo.bitDepth != UInt8(16)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = Array<Byte>(row.size / 2, repeat: 0)
    var sourceOffset: Int64 = 0
    var outputOffset: Int64 = 0
    while (sourceOffset < row.size) {
        output[outputOffset] = row[sourceOffset]
        sourceOffset += 2
        outputOffset += 1
    }
    PngReadTransformRow(png16To8OutputInfo(rowInfo), output)
}

public func applyInitializedPng16To8Stages(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)

    let scaled = if (initialization.hasStage(ReadStageScale16To8)) {
        pngDoScale16To8(rowInfo, row)
    } else {
        PngReadTransformRow(rowInfo, row)
    }

    if (initialization.hasStage(ReadStageStrip16To8)) {
        return pngDoChop(scaled.info, scaled.row())
    }
    scaled
}
