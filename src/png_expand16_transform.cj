package libpng4cj

private func pngExpand16Supported(rowInfo: PngReadRowInfo): Bool {
    rowInfo.bitDepth == UInt8(8) && rowInfo.colorType != Indexed &&
        rowInfo.channels > UInt8(0) && rowInfo.width > UInt32(0)
}

public func pngDoExpand16(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!pngExpand16Supported(rowInfo)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = Array<Byte>(row.size * 2, repeat: 0)
    var sourceOffset = row.size - 1
    var destinationOffset = output.size - 1
    while (sourceOffset >= 0) {
        let value = row[sourceOffset]
        output[destinationOffset] = value
        output[destinationOffset - 1] = value
        sourceOffset -= 1
        destinationOffset -= 2
    }

    PngReadTransformRow(
        PngReadRowInfo(
            rowInfo.width,
            UInt8(16),
            rowInfo.colorType,
            rowInfo.channels
        ),
        output
    )
}

public func applyInitializedPngExpand16Stage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageExpand16)) {
        return PngReadTransformRow(rowInfo, row)
    }
    pngDoExpand16(rowInfo, row)
}
