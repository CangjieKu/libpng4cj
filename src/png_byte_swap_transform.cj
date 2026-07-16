package libpng4cj

public func pngDoSwap(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (rowInfo.bitDepth != UInt8(16)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = row.clone()
    var offset: Int64 = 0
    while (offset < output.size) {
        let saved = output[offset]
        output[offset] = output[offset + 1]
        output[offset + 1] = saved
        offset += 2
    }
    PngReadTransformRow(rowInfo, output)
}

public func applyInitializedPngByteSwapStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageByteSwap)) {
        return PngReadTransformRow(rowInfo, row)
    }
    pngDoSwap(rowInfo, row)
}
