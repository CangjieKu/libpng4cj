package libpng4cj

private func pngPaletteExpandSupported(rowInfo: PngReadRowInfo): Bool {
    let sourceShape = rowInfo.colorType == Indexed &&
        rowInfo.channels == UInt8(1)
    let sourceDepth = rowInfo.bitDepth == UInt8(1) ||
        rowInfo.bitDepth == UInt8(2) || rowInfo.bitDepth == UInt8(4) ||
        rowInfo.bitDepth == UInt8(8)
    sourceShape && sourceDepth && rowInfo.width > UInt32(0)
}

private func validatePngPaletteExpandInputs(
    palette: Array<Byte>,
    paletteAlpha: Array<Byte>
): Int64 {
    if (palette.size == 0 || palette.size % 3 != 0 || palette.size / 3 > 256) {
        throw PngFormatException(
            InvalidPalette,
            palette.size,
            "PNG palette expansion requires 1..256 complete RGB entries"
        )
    }
    let entryCount = palette.size / 3
    if (paletteAlpha.size > entryCount) {
        throw PngFormatException(
            InvalidTransparency,
            paletteAlpha.size,
            "PNG palette alpha count exceeds the retained palette"
        )
    }
    entryCount
}

private func pngPaletteOutputInfo(
    rowInfo: PngReadRowInfo,
    withAlpha: Bool
): PngReadRowInfo {
    if (withAlpha) {
        PngReadRowInfo(
            rowInfo.width,
            UInt8(8),
            TruecolorAlpha,
            UInt8(4)
        )
    } else {
        PngReadRowInfo(
            rowInfo.width,
            UInt8(8),
            Truecolor,
            UInt8(3)
        )
    }
}

private func pngPaletteIndexes(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): Array<Byte> {
    if (rowInfo.bitDepth < UInt8(8)) {
        pngDoUnpack(rowInfo, row).row()
    } else {
        row.clone()
    }
}

public func pngDoExpandPalette(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    palette: Array<Byte>,
    paletteAlpha: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!pngPaletteExpandSupported(rowInfo)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let paletteEntryCount = validatePngPaletteExpandInputs(
        palette,
        paletteAlpha
    )
    let indexes = pngPaletteIndexes(rowInfo, row)
    let withAlpha = paletteAlpha.size > 0
    let channels = if (withAlpha) { Int64(4) } else { Int64(3) }
    let output = Array<Byte>(Int64(rowInfo.width) * channels, repeat: 0)
    var sourceOffset = Int64(rowInfo.width) - 1
    var destinationOffset = output.size - 1
    var pixel: UInt64 = UInt64(0)
    while (pixel < UInt64(rowInfo.width)) {
        let paletteIndex = Int64(indexes[sourceOffset])
        if (paletteIndex >= paletteEntryCount) {
            throw PngFormatException(
                PaletteIndexOutOfRange,
                paletteIndex,
                "PNG palette index is outside the retained PLTE"
            )
        }

        if (withAlpha) {
            output[destinationOffset] = if (paletteIndex < paletteAlpha.size) {
                paletteAlpha[paletteIndex]
            } else {
                UInt8(0xff)
            }
            destinationOffset -= 1
        }
        let paletteOffset = paletteIndex * 3
        output[destinationOffset] = palette[paletteOffset + 2]
        output[destinationOffset - 1] = palette[paletteOffset + 1]
        output[destinationOffset - 2] = palette[paletteOffset]
        destinationOffset -= 3
        sourceOffset -= 1
        pixel += 1
    }

    PngReadTransformRow(
        pngPaletteOutputInfo(rowInfo, withAlpha),
        output
    )
}
