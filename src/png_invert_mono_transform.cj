package libpng4cj

private func pngInvertMonoSupported(rowInfo: PngReadRowInfo): Bool {
    if (rowInfo.channels != rowInfo.colorType.channels()) {
        return false
    }
    if (rowInfo.colorType == Grayscale) {
        return rowInfo.bitDepth == UInt8(1) ||
            rowInfo.bitDepth == UInt8(2) ||
            rowInfo.bitDepth == UInt8(4) ||
            rowInfo.bitDepth == UInt8(8) ||
            rowInfo.bitDepth == UInt8(16)
    }
    rowInfo.colorType == GrayscaleAlpha &&
        (rowInfo.bitDepth == UInt8(8) || rowInfo.bitDepth == UInt8(16))
}

private func pngInvertAllBytes(row: Array<Byte>): Array<Byte> {
    let output = row.clone()
    var index: Int64 = 0
    while (index < output.size) {
        output[index] = UInt8(0xff) - output[index]
        index += 1
    }
    output
}

private func pngInvertGrayAlpha(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): Array<Byte> {
    let output = row.clone()
    let componentBytes = if (rowInfo.bitDepth == UInt8(16)) {
        Int64(2)
    } else {
        Int64(1)
    }
    let pixelBytes = componentBytes * 2
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let offset = pixel * pixelBytes
        var byteIndex: Int64 = 0
        while (byteIndex < componentBytes) {
            output[offset + byteIndex] = UInt8(0xff) -
                output[offset + byteIndex]
            byteIndex += 1
        }
        pixel += 1
    }
    output
}

public func pngDoInvertMono(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!pngInvertMonoSupported(rowInfo)) {
        return PngReadTransformRow(rowInfo, row)
    }
    let output = if (rowInfo.colorType == Grayscale) {
        pngInvertAllBytes(row)
    } else {
        pngInvertGrayAlpha(rowInfo, row)
    }
    PngReadTransformRow(rowInfo, output)
}

public func applyInitializedPngInvertMonoStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageInvertMono)) {
        return PngReadTransformRow(rowInfo, row)
    }
    pngDoInvertMono(rowInfo, row)
}
