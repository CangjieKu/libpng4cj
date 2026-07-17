package libpng4cj

private func pngStripChannelSupported(rowInfo: PngReadRowInfo): Bool {
    let channelShape = rowInfo.channels == UInt8(2) ||
        rowInfo.channels == UInt8(4)
    let sampleDepth = rowInfo.bitDepth == UInt8(8) ||
        rowInfo.bitDepth == UInt8(16)
    channelShape && sampleDepth && rowInfo.width > UInt32(0)
}

private func pngStripChannelOutputType(rowInfo: PngReadRowInfo): PngColorType {
    match (rowInfo.colorType) {
        case GrayscaleAlpha => Grayscale
        case TruecolorAlpha => Truecolor
        case _ => rowInfo.colorType
    }
}

public func pngDoStripChannel(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    atStart: Bool
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!pngStripChannelSupported(rowInfo)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let componentBytes = Int64(rowInfo.bitDepth / UInt8(8))
    let sourcePixelBytes = Int64(rowInfo.channels) * componentBytes
    let outputChannels = rowInfo.channels - UInt8(1)
    let outputPixelBytes = Int64(outputChannels) * componentBytes
    let output = Array<Byte>(
        Int64(rowInfo.width) * outputPixelBytes,
        repeat: 0
    )
    let sourceComponentOffset = if (atStart) { componentBytes } else { Int64(0) }
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let sourceOffset = pixel * sourcePixelBytes + sourceComponentOffset
        let outputOffset = pixel * outputPixelBytes
        var byteIndex: Int64 = 0
        while (byteIndex < outputPixelBytes) {
            output[outputOffset + byteIndex] = row[sourceOffset + byteIndex]
            byteIndex += 1
        }
        pixel += 1
    }

    PngReadTransformRow(
        PngReadRowInfo(
            rowInfo.width,
            rowInfo.bitDepth,
            pngStripChannelOutputType(rowInfo),
            outputChannels
        ),
        output
    )
}

public func applyInitializedPngStripAlphaStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageStripAlpha)) {
        return PngReadTransformRow(rowInfo, row)
    }
    pngDoStripChannel(rowInfo, row, false)
}

public func applyInitializedPngStripAlphaAfterComposeStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageStripAlphaAfterCompose)) {
        return PngReadTransformRow(rowInfo, row)
    }
    pngDoStripChannel(rowInfo, row, false)
}
