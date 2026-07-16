package libpng4cj

private func pngAlphaRowTransformSupported(rowInfo: PngReadRowInfo): Bool {
    (rowInfo.colorType == GrayscaleAlpha || rowInfo.colorType == TruecolorAlpha) &&
        (rowInfo.bitDepth == UInt8(8) || rowInfo.bitDepth == UInt8(16))
}

private func pngAlphaComponentBytes(rowInfo: PngReadRowInfo): Int64 {
    if (rowInfo.bitDepth == UInt8(8)) { Int64(1) } else { Int64(2) }
}

public func pngDoReadInvertAlpha(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!pngAlphaRowTransformSupported(rowInfo)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = row.clone()
    let componentBytes = pngAlphaComponentBytes(rowInfo)
    let pixelBytes = Int64(rowInfo.channels) * componentBytes
    let alphaOffset = pixelBytes - componentBytes
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let offset = pixel * pixelBytes + alphaOffset
        var byteIndex: Int64 = 0
        while (byteIndex < componentBytes) {
            output[offset + byteIndex] = UInt8(0xff) - output[offset + byteIndex]
            byteIndex += 1
        }
        pixel += 1
    }
    PngReadTransformRow(rowInfo, output)
}

public func pngDoReadSwapAlpha(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!pngAlphaRowTransformSupported(rowInfo)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = Array<Byte>(row.size, repeat: 0)
    let componentBytes = pngAlphaComponentBytes(rowInfo)
    let pixelBytes = Int64(rowInfo.channels) * componentBytes
    let colorBytes = pixelBytes - componentBytes
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let pixelOffset = pixel * pixelBytes
        var byteIndex: Int64 = 0
        while (byteIndex < componentBytes) {
            output[pixelOffset + byteIndex] =
                row[pixelOffset + colorBytes + byteIndex]
            byteIndex += 1
        }
        byteIndex = 0
        while (byteIndex < colorBytes) {
            output[pixelOffset + componentBytes + byteIndex] =
                row[pixelOffset + byteIndex]
            byteIndex += 1
        }
        pixel += 1
    }
    PngReadTransformRow(rowInfo, output)
}

public func applySelectedPngAlphaTransforms(
    transforms: Array<PngReadChannelTransform>,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)

    let inverted = if (hasPngReadChannelTransform(transforms, InvertAlpha)) {
        pngDoReadInvertAlpha(rowInfo, row)
    } else {
        PngReadTransformRow(rowInfo, row)
    }

    if (hasPngReadChannelTransform(transforms, SwapAlpha)) {
        return pngDoReadSwapAlpha(inverted.info, inverted.row())
    }
    inverted
}
