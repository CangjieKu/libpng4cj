package libpng4cj

private func pngReadFillerSupported(rowInfo: PngReadRowInfo): Bool {
    let sourceChannelsMatch =
        (rowInfo.colorType == Grayscale && rowInfo.channels == UInt8(1)) ||
        (rowInfo.colorType == Truecolor && rowInfo.channels == UInt8(3))
    sourceChannelsMatch &&
        (rowInfo.bitDepth == UInt8(8) || rowInfo.bitDepth == UInt8(16))
}

private func pngWriteFillerComponent(
    output: Array<Byte>,
    offset: Int64,
    filler: UInt32,
    componentBytes: Int64
): Unit {
    if (componentBytes == Int64(2)) {
        output[offset] = UInt8((filler >> 8) & UInt32(0xff))
        output[offset + 1] = UInt8(filler & UInt32(0xff))
    } else {
        output[offset] = UInt8(filler & UInt32(0xff))
    }
}

private func pngCopyRowBytes(
    source: Array<Byte>,
    sourceOffset: Int64,
    output: Array<Byte>,
    outputOffset: Int64,
    count: Int64
): Unit {
    var index: Int64 = 0
    while (index < count) {
        output[outputOffset + index] = source[sourceOffset + index]
        index += 1
    }
}

public func pngDoReadFiller(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    filler: UInt32,
    fillerAfter: Bool
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!pngReadFillerSupported(rowInfo)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let componentBytes = if (rowInfo.bitDepth == UInt8(16)) {
        Int64(2)
    } else {
        Int64(1)
    }
    let sourcePixelBytes = Int64(rowInfo.channels) * componentBytes
    let outputChannels = rowInfo.channels + UInt8(1)
    let outputPixelBytes = Int64(outputChannels) * componentBytes
    let output = Array<Byte>(
        Int64(rowInfo.width) * outputPixelBytes,
        repeat: 0
    )

    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let sourceOffset = pixel * sourcePixelBytes
        let outputOffset = pixel * outputPixelBytes
        if (fillerAfter) {
            pngCopyRowBytes(
                row, sourceOffset, output, outputOffset, sourcePixelBytes
            )
            pngWriteFillerComponent(
                output,
                outputOffset + sourcePixelBytes,
                filler,
                componentBytes
            )
        } else {
            pngWriteFillerComponent(output, outputOffset, filler, componentBytes)
            pngCopyRowBytes(
                row,
                sourceOffset,
                output,
                outputOffset + componentBytes,
                sourcePixelBytes
            )
        }
        pixel += 1
    }

    PngReadTransformRow(
        PngReadRowInfo(
            rowInfo.width,
            rowInfo.bitDepth,
            rowInfo.colorType,
            outputChannels
        ),
        output
    )
}

public func applyPngReadFillerTransform(
    transform: PngRowShapeTransform,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (transform.fillerMode == NoFiller) {
        return PngReadTransformRow(rowInfo, row)
    }

    let fillerAfter = transform.fillerMode == FillerAfter ||
        transform.fillerMode == AlphaAfter
    pngDoReadFiller(
        rowInfo,
        row,
        UInt32(transform.fillerValue),
        fillerAfter
    )
}
