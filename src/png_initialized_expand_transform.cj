package libpng4cj

public func applyInitializedPngExpandStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageExpand)) {
        return PngReadTransformRow(rowInfo, row)
    }

    if (rowInfo.colorType == Indexed) {
        return pngDoExpandPalette(
            rowInfo,
            row,
            initialization.expandPalette(),
            initialization.expandPaletteAlpha()
        )
    }

    pngDoExpand(
        rowInfo,
        row,
        initialization.expandTransparency()
    )
}
