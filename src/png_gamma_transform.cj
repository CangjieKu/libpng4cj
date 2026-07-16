package libpng4cj

private func pngDoGammaPacked2(
    row: Array<Byte>,
    table: PngGamma8BitTable
): Array<Byte> {
    let output = row.clone()
    var offset: Int64 = 0
    while (offset < output.size) {
        let source = UInt32(output[offset])
        var packed = UInt32(0)
        var position = UInt32(0)
        while (position < UInt32(4)) {
            let shift = UInt32(6) - position * UInt32(2)
            let sample = (source >> shift) & UInt32(0x03)
            let expanded = UInt8(sample * UInt32(85))
            let corrected = UInt32(table.value(expanded)) >> UInt32(6)
            packed = packed | (corrected << shift)
            position += 1
        }
        output[offset] = UInt8(packed)
        offset += 1
    }
    output
}

private func pngDoGammaPacked4(
    row: Array<Byte>,
    table: PngGamma8BitTable
): Array<Byte> {
    let output = row.clone()
    var offset: Int64 = 0
    while (offset < output.size) {
        let source = UInt32(output[offset])
        let high = UInt8(((source >> UInt32(4)) & UInt32(0x0f)) * UInt32(17))
        let low = UInt8((source & UInt32(0x0f)) * UInt32(17))
        output[offset] = UInt8(
            (UInt32(table.value(high)) & UInt32(0xf0)) |
            (UInt32(table.value(low)) >> UInt32(4))
        )
        offset += 1
    }
    output
}

private func pngDoGamma8(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    table: PngGamma8BitTable
): Array<Byte> {
    var colorChannels: Int64 = 0
    var pixelChannels: Int64 = 0
    if (rowInfo.colorType == Grayscale) {
        colorChannels = 1
        pixelChannels = 1
    } else if (rowInfo.colorType == GrayscaleAlpha) {
        colorChannels = 1
        pixelChannels = 2
    } else if (rowInfo.colorType == Truecolor) {
        colorChannels = 3
        pixelChannels = 3
    } else if (rowInfo.colorType == TruecolorAlpha) {
        colorChannels = 3
        pixelChannels = 4
    } else {
        return row.clone()
    }

    if (Int64(rowInfo.channels) != pixelChannels) {
        return row.clone()
    }
    let output = row.clone()
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let base = pixel * pixelChannels
        var channel: Int64 = 0
        while (channel < colorChannels) {
            output[base + channel] = table.value(output[base + channel])
            channel += 1
        }
        pixel += 1
    }
    output
}

private func pngDoGamma16(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    table: PngGamma16BitTable
): Array<Byte> {
    var colorChannels: Int64 = 0
    var pixelChannels: Int64 = 0
    if (rowInfo.colorType == Grayscale) {
        colorChannels = 1
        pixelChannels = 1
    } else if (rowInfo.colorType == GrayscaleAlpha) {
        colorChannels = 1
        pixelChannels = 2
    } else if (rowInfo.colorType == Truecolor) {
        colorChannels = 3
        pixelChannels = 3
    } else if (rowInfo.colorType == TruecolorAlpha) {
        colorChannels = 3
        pixelChannels = 4
    } else {
        return row.clone()
    }
    if (Int64(rowInfo.channels) != pixelChannels) {
        return row.clone()
    }

    let output = row.clone()
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let base = pixel * pixelChannels * 2
        var channel: Int64 = 0
        while (channel < colorChannels) {
            let offset = base + channel * 2
            let sample = UInt16(
                (UInt16(output[offset]) << UInt16(8)) |
                UInt16(output[offset + 1])
            )
            let corrected = table.value(sample)
            output[offset] = UInt8((corrected >> UInt16(8)) & UInt16(0xff))
            output[offset + 1] = UInt8(corrected & UInt16(0xff))
            channel += 1
        }
        pixel += 1
    }
    output
}

// Packed and 8-bit branches of upstream png_do_gamma.
public func pngDoGamma(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    table: PngGamma8BitTable
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (rowInfo.colorType == Grayscale && rowInfo.channels == UInt8(1)) {
        let output = match (rowInfo.bitDepth) {
            case 2 => pngDoGammaPacked2(row, table)
            case 4 => pngDoGammaPacked4(row, table)
            case 8 => pngDoGamma8(rowInfo, row, table)
            case _ => row.clone()
        }
        return PngReadTransformRow(rowInfo, output)
    }
    if (rowInfo.bitDepth == UInt8(8)) {
        return PngReadTransformRow(rowInfo, pngDoGamma8(rowInfo, row, table))
    }
    PngReadTransformRow(rowInfo, row)
}

// 16-bit branches of upstream png_do_gamma.
public func pngDoGamma(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    table: PngGamma16BitTable
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (rowInfo.bitDepth != UInt8(16)) {
        return PngReadTransformRow(rowInfo, row)
    }
    PngReadTransformRow(rowInfo, pngDoGamma16(rowInfo, row, table))
}

public func applyInitializedPngGammaStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageGamma)) {
        return PngReadTransformRow(rowInfo, row)
    }
    if (rowInfo.bitDepth == UInt8(16)) {
        return pngDoGamma(
            rowInfo,
            row,
            initialization.gamma16BitTables().direct()
        )
    }
    pngDoGamma(rowInfo, row, initialization.gamma8BitTables().direct())
}
