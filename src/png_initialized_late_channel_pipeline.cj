package libpng4cj

public func applyInitializedPngInvertAlphaStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageInvertAlpha)) {
        return PngReadTransformRow(rowInfo, row)
    }
    pngDoReadInvertAlpha(rowInfo, row)
}

public func applyInitializedPngUnshiftStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageUnshift)) {
        return PngReadTransformRow(rowInfo, row)
    }
    pngDoUnshift(rowInfo, row, initialization.shiftSignificantBits())
}

public func applyInitializedPngFillerStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageFiller)) {
        return PngReadTransformRow(rowInfo, row)
    }
    applyPngReadFillerTransform(
        PngRowShapeTransform(
            false,
            initialization.fillerMode(),
            initialization.fillerValue()
        ),
        rowInfo,
        row
    )
}

private func pngAddedAlphaColorType(rowInfo: PngReadRowInfo): PngColorType {
    match (rowInfo.colorType) {
        case Grayscale => GrayscaleAlpha
        case Truecolor => TruecolorAlpha
        case _ => rowInfo.colorType
    }
}

private func pngMoveLeadingAddedAlphaToEnd(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    let componentBytes = if (rowInfo.bitDepth == UInt8(16)) {
        Int64(2)
    } else {
        Int64(1)
    }
    let pixelBytes = Int64(rowInfo.channels) * componentBytes
    let colorBytes = pixelBytes - componentBytes
    let output = Array<Byte>(row.size, repeat: 0)
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let offset = pixel * pixelBytes
        var index: Int64 = 0
        while (index < colorBytes) {
            output[offset + index] = row[offset + componentBytes + index]
            index += 1
        }
        index = 0
        while (index < componentBytes) {
            output[offset + colorBytes + index] = row[offset + index]
            index += 1
        }
        pixel += 1
    }
    PngReadTransformRow(rowInfo, output)
}

private func pngSwapAddedAlpha(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    let naturalChannels = rowInfo.colorType.channels()
    if (rowInfo.channels != naturalChannels + UInt8(1) ||
        (rowInfo.bitDepth != UInt8(8) && rowInfo.bitDepth != UInt8(16))) {
        return PngReadTransformRow(rowInfo, row)
    }
    if (initialization.fillerMode() == AlphaBefore) {
        return pngMoveLeadingAddedAlphaToEnd(rowInfo, row)
    }
    let alphaInfo = PngReadRowInfo(
        rowInfo.width,
        rowInfo.bitDepth,
        pngAddedAlphaColorType(rowInfo)
    )
    let swapped = pngDoReadSwapAlpha(alphaInfo, row)
    PngReadTransformRow(rowInfo, swapped.row())
}

func applyInitializedPngSwapAlphaAfterFillerStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    fillerApplied: Bool
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageSwapAlpha)) {
        return PngReadTransformRow(rowInfo, row)
    }
    if (rowInfo.colorType == GrayscaleAlpha ||
        rowInfo.colorType == TruecolorAlpha) {
        return pngDoReadSwapAlpha(rowInfo, row)
    }
    if (initialization.addAlphaEnabled() && fillerApplied) {
        return pngSwapAddedAlpha(initialization, rowInfo, row)
    }
    PngReadTransformRow(rowInfo, row)
}

public func applyInitializedPngSwapAlphaStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    applyInitializedPngSwapAlphaAfterFillerStage(
        initialization,
        rowInfo,
        row,
        false
    )
}
