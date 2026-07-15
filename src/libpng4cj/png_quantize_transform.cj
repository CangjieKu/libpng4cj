package libpng4cj

private let PNG_QUANTIZE_LOOKUP_SIZE: Int64 = Int64(1) << 15
private let PNG_QUANTIZE_INDEX_SIZE: Int64 = Int64(256)

private func pngQuantizeLookupIndex(
    red: UInt8,
    green: UInt8,
    blue: UInt8
): Int64 {
    let redIndex = UInt32(red) >> 3
    let greenIndex = UInt32(green) >> 3
    let blueIndex = UInt32(blue) >> 3
    Int64((redIndex << 10) | (greenIndex << 5) | blueIndex)
}

private func validatePngQuantizeLookup(
    lookup: Array<Byte>,
    expectedSize: Int64,
    name: String
): Unit {
    if (lookup.size != expectedSize) {
        throw PngFormatException(
            InvalidArgument,
            lookup.size,
            "PNG quantize " + name + " lookup has an invalid size"
        )
    }
}

private func pngQuantizedRowInfo(rowInfo: PngReadRowInfo): PngReadRowInfo {
    PngReadRowInfo(
        rowInfo.width,
        UInt8(8),
        Indexed,
        UInt8(1)
    )
}

private func pngQuantizeRgbRow(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    paletteLookup: Array<Byte>,
    sourceChannels: Int64
): PngReadTransformRow {
    let output = Array<Byte>(Int64(rowInfo.width), repeat: 0)
    var sourceOffset: Int64 = 0
    var destinationOffset: Int64 = 0
    while (destinationOffset < output.size) {
        let lookupIndex = pngQuantizeLookupIndex(
            row[sourceOffset],
            row[sourceOffset + 1],
            row[sourceOffset + 2]
        )
        output[destinationOffset] = paletteLookup[lookupIndex]
        sourceOffset += sourceChannels
        destinationOffset += 1
    }
    PngReadTransformRow(pngQuantizedRowInfo(rowInfo), output)
}

private func pngRemapIndexedRow(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    quantizeLookup: Array<Byte>
): PngReadTransformRow {
    let output = row.clone()
    var index: Int64 = 0
    while (index < output.size) {
        output[index] = quantizeLookup[Int64(output[index])]
        index += 1
    }
    PngReadTransformRow(rowInfo, output)
}

public func pngDoQuantize(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    paletteLookup: Array<Byte>,
    quantizeLookup: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (rowInfo.width == UInt32(0) || rowInfo.bitDepth != UInt8(8)) {
        return PngReadTransformRow(rowInfo, row)
    }

    if (rowInfo.colorType == Truecolor && rowInfo.channels == UInt8(3)) {
        if (paletteLookup.size == 0) {
            return PngReadTransformRow(rowInfo, row)
        }
        validatePngQuantizeLookup(
            paletteLookup,
            PNG_QUANTIZE_LOOKUP_SIZE,
            "palette"
        )
        return pngQuantizeRgbRow(
            rowInfo,
            row,
            paletteLookup,
            Int64(3)
        )
    }

    if (rowInfo.colorType == TruecolorAlpha && rowInfo.channels == UInt8(4)) {
        if (paletteLookup.size == 0) {
            return PngReadTransformRow(rowInfo, row)
        }
        validatePngQuantizeLookup(
            paletteLookup,
            PNG_QUANTIZE_LOOKUP_SIZE,
            "palette"
        )
        return pngQuantizeRgbRow(
            rowInfo,
            row,
            paletteLookup,
            Int64(4)
        )
    }

    if (rowInfo.colorType == Indexed && rowInfo.channels == UInt8(1)) {
        if (quantizeLookup.size == 0) {
            return PngReadTransformRow(rowInfo, row)
        }
        validatePngQuantizeLookup(
            quantizeLookup,
            PNG_QUANTIZE_INDEX_SIZE,
            "index"
        )
        return pngRemapIndexedRow(rowInfo, row, quantizeLookup)
    }

    PngReadTransformRow(rowInfo, row)
}

public func applyInitializedPngQuantizeStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    if (!initialization.hasStage(ReadStageQuantize)) {
        validatePngTransformRowLength(rowInfo, row)
        return PngReadTransformRow(rowInfo, row)
    }
    pngDoQuantize(
        rowInfo,
        row,
        initialization.quantizePaletteLookup(),
        initialization.quantizeIndex()
    )
}
