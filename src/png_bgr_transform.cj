package libpng4cj

private func pngBgrSupported(rowInfo: PngReadRowInfo): Bool {
    (rowInfo.colorType == Truecolor || rowInfo.colorType == TruecolorAlpha) &&
        (rowInfo.bitDepth == UInt8(8) || rowInfo.bitDepth == UInt8(16)) &&
        rowInfo.channels == rowInfo.colorType.channels()
}

private func pngSwapBgrComponent(
    row: Array<Byte>,
    left: Int64,
    right: Int64,
    componentBytes: Int64
): Unit {
    var index: Int64 = 0
    while (index < componentBytes) {
        let saved = row[left + index]
        row[left + index] = row[right + index]
        row[right + index] = saved
        index += 1
    }
}

public func pngDoBgr(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!pngBgrSupported(rowInfo)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = row.clone()
    let componentBytes = if (rowInfo.bitDepth == UInt8(16)) {
        Int64(2)
    } else {
        Int64(1)
    }
    let pixelBytes = Int64(rowInfo.channels) * componentBytes
    let blueOffset = componentBytes * 2
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let offset = pixel * pixelBytes
        pngSwapBgrComponent(
            output,
            offset,
            offset + blueOffset,
            componentBytes
        )
        pixel += 1
    }
    PngReadTransformRow(rowInfo, output)
}

public func applyInitializedPngBgrStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageBgr)) {
        return PngReadTransformRow(rowInfo, row)
    }
    pngDoBgr(rowInfo, row)
}
