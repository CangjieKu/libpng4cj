package libpng4cj

private func pngComposite8(foreground: UInt8, alpha: UInt8, background: UInt8): UInt8 {
    let temporary = UInt32(foreground) * UInt32(alpha) +
        UInt32(background) * (UInt32(255) - UInt32(alpha)) + UInt32(128)
    UInt8(((temporary + (temporary >> UInt32(8))) >> UInt32(8)) & UInt32(0xff))
}

private func pngComposite16(
    foreground: UInt16,
    alpha: UInt16,
    background: UInt16
): UInt16 {
    let temporary = UInt64(foreground) * UInt64(alpha) +
        UInt64(background) * (UInt64(65535) - UInt64(alpha)) + UInt64(32768)
    UInt16(
        ((temporary + (temporary >> UInt64(16))) >> UInt64(16)) &
        UInt64(0xffff)
    )
}

private func pngReadComposeUInt16(row: Array<Byte>, offset: Int64): UInt16 {
    (UInt16(row[offset]) << UInt16(8)) | UInt16(row[offset + 1])
}

private func pngWriteComposeUInt16(
    output: Array<Byte>,
    offset: Int64,
    value: UInt16
): Unit {
    output[offset] = UInt8(value >> UInt16(8))
    output[offset + 1] = UInt8(value & UInt16(0xff))
}

private func pngComposePackedGray(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    transparency: PngExpandTransparency,
    tables: PngGamma8BitTables,
    gammaEnabled: Bool
): Array<Byte> {
    let output = row.clone()
    let depth = UInt32(rowInfo.bitDepth)
    let sampleMask = (UInt32(1) << depth) - UInt32(1)
    let transparent = UInt32(transparency.gray) & sampleMask
    let replacement = UInt32(background.gray) & sampleMask
    if (!gammaEnabled) {
        var pixel = UInt32(0)
        while (pixel < rowInfo.width) {
            let bitOffset = pixel * depth
            let byteOffset = Int64(bitOffset / UInt32(8))
            let shift = UInt32(8) - depth - (bitOffset % UInt32(8))
            let source = UInt32(output[byteOffset])
            let sample = (source >> shift) & sampleMask
            if (transparency.present && sample == transparent) {
                let cleared = source & !(sampleMask << shift)
                output[byteOffset] = UInt8(
                    cleared | ((replacement & sampleMask) << shift)
                )
            }
            pixel += UInt32(1)
        }
        return output
    }
    let gammaTable = tables.direct()
    var pixel = UInt32(0)
    while (pixel < rowInfo.width) {
        let bitOffset = pixel * depth
        let byteOffset = Int64(bitOffset / UInt32(8))
        let shift = UInt32(8) - depth - (bitOffset % UInt32(8))
        let source = UInt32(output[byteOffset])
        let sample = (source >> shift) & sampleMask
        var value = sample
        if (transparency.present && sample == transparent) {
            value = replacement
        } else if (depth == UInt32(2)) {
            value = UInt32(gammaTable.value(UInt8(sample * UInt32(85)))) >> UInt32(6)
        } else if (depth == UInt32(4)) {
            value = UInt32(gammaTable.value(UInt8(sample * UInt32(17)))) >> UInt32(4)
        }
        let cleared = source & !(sampleMask << shift)
        output[byteOffset] = UInt8(cleared | ((value & sampleMask) << shift))
        pixel += UInt32(1)
    }
    output
}

private func pngComposeGray8(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    transparency: PngExpandTransparency,
    tables: PngGamma8BitTables,
    gammaEnabled: Bool
): Array<Byte> {
    let output = row.clone()
    let key = UInt8(transparency.gray & UInt16(0xff))
    let replacement = UInt8(background.gray & UInt16(0xff))
    if (!gammaEnabled) {
        var pixel: Int64 = 0
        while (pixel < Int64(rowInfo.width)) {
            if (transparency.present && output[pixel] == key) {
                output[pixel] = replacement
            }
            pixel += 1
        }
        return output
    }
    let direct = tables.direct()
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let sample = output[pixel]
        if (transparency.present && sample == key) {
            output[pixel] = replacement
        } else {
            output[pixel] = direct.value(sample)
        }
        pixel += 1
    }
    output
}

private func pngComposeGray16(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    transparency: PngExpandTransparency,
    tables: PngGamma16BitTables,
    gammaEnabled: Bool
): Array<Byte> {
    let output = row.clone()
    if (!gammaEnabled) {
        var pixel: Int64 = 0
        while (pixel < Int64(rowInfo.width)) {
            let offset = pixel * 2
            if (transparency.present &&
                pngReadComposeUInt16(output, offset) == transparency.gray) {
                pngWriteComposeUInt16(output, offset, background.gray)
            }
            pixel += 1
        }
        return output
    }
    let direct = tables.direct()
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let offset = pixel * 2
        let sample = pngReadComposeUInt16(output, offset)
        if (transparency.present && sample == transparency.gray) {
            pngWriteComposeUInt16(output, offset, background.gray)
        } else {
            pngWriteComposeUInt16(output, offset, direct.value(sample))
        }
        pixel += 1
    }
    output
}

private func pngComposeRgb8(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    transparency: PngExpandTransparency,
    tables: PngGamma8BitTables,
    gammaEnabled: Bool
): Array<Byte> {
    let output = row.clone()
    let keyRed = UInt8(transparency.red & UInt16(0xff))
    let keyGreen = UInt8(transparency.green & UInt16(0xff))
    let keyBlue = UInt8(transparency.blue & UInt16(0xff))
    if (!gammaEnabled) {
        var pixel: Int64 = 0
        while (pixel < Int64(rowInfo.width)) {
            let offset = pixel * 3
            if (transparency.present && output[offset] == keyRed &&
                output[offset + 1] == keyGreen && output[offset + 2] == keyBlue) {
                output[offset] = UInt8(background.red & UInt16(0xff))
                output[offset + 1] = UInt8(background.green & UInt16(0xff))
                output[offset + 2] = UInt8(background.blue & UInt16(0xff))
            }
            pixel += 1
        }
        return output
    }
    let direct = tables.direct()
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let offset = pixel * 3
        let transparent = transparency.present && output[offset] == keyRed &&
            output[offset + 1] == keyGreen && output[offset + 2] == keyBlue
        if (transparent) {
            output[offset] = UInt8(background.red & UInt16(0xff))
            output[offset + 1] = UInt8(background.green & UInt16(0xff))
            output[offset + 2] = UInt8(background.blue & UInt16(0xff))
        } else {
            output[offset] = direct.value(output[offset])
            output[offset + 1] = direct.value(output[offset + 1])
            output[offset + 2] = direct.value(output[offset + 2])
        }
        pixel += 1
    }
    output
}

private func pngComposeRgb16(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    transparency: PngExpandTransparency,
    tables: PngGamma16BitTables,
    gammaEnabled: Bool
): Array<Byte> {
    let output = row.clone()
    if (!gammaEnabled) {
        var pixel: Int64 = 0
        while (pixel < Int64(rowInfo.width)) {
            let offset = pixel * 6
            let red = pngReadComposeUInt16(output, offset)
            let green = pngReadComposeUInt16(output, offset + 2)
            let blue = pngReadComposeUInt16(output, offset + 4)
            if (transparency.present && red == transparency.red &&
                green == transparency.green && blue == transparency.blue) {
                pngWriteComposeUInt16(output, offset, background.red)
                pngWriteComposeUInt16(output, offset + 2, background.green)
                pngWriteComposeUInt16(output, offset + 4, background.blue)
            }
            pixel += 1
        }
        return output
    }
    let direct = tables.direct()
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let offset = pixel * 6
        let red = pngReadComposeUInt16(output, offset)
        let green = pngReadComposeUInt16(output, offset + 2)
        let blue = pngReadComposeUInt16(output, offset + 4)
        let transparent = transparency.present && red == transparency.red &&
            green == transparency.green && blue == transparency.blue
        if (transparent) {
            pngWriteComposeUInt16(output, offset, background.red)
            pngWriteComposeUInt16(output, offset + 2, background.green)
            pngWriteComposeUInt16(output, offset + 4, background.blue)
        } else {
            pngWriteComposeUInt16(output, offset, direct.value(red))
            pngWriteComposeUInt16(output, offset + 2, direct.value(green))
            pngWriteComposeUInt16(output, offset + 4, direct.value(blue))
        }
        pixel += 1
    }
    output
}

private func pngComposeGrayAlpha8(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    backgroundLinear: PngBackground,
    tables: PngGamma8BitTables,
    gammaEnabled: Bool
): Array<Byte> {
    let output = row.clone()
    if (!gammaEnabled) {
        var pixel: Int64 = 0
        while (pixel < Int64(rowInfo.width)) {
            let offset = pixel * 2
            let alpha = output[offset + 1]
            if (alpha == UInt8(0)) {
                output[offset] = UInt8(background.gray & UInt16(0xff))
            } else if (alpha < UInt8(0xff)) {
                output[offset] = pngComposite8(
                    output[offset],
                    alpha,
                    UInt8(background.gray & UInt16(0xff))
                )
            }
            pixel += 1
        }
        return output
    }
    let direct = tables.direct()
    let toLinear = tables.toLinear()
    let fromLinear = tables.fromLinear()
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let offset = pixel * 2
        let alpha = output[offset + 1]
        if (alpha == UInt8(0xff)) {
            output[offset] = direct.value(output[offset])
        } else if (alpha == UInt8(0)) {
            output[offset] = UInt8(background.gray & UInt16(0xff))
        } else {
            let linear = toLinear.value(output[offset])
            let composed = pngComposite8(
                linear,
                alpha,
                UInt8(backgroundLinear.gray & UInt16(0xff))
            )
            output[offset] = fromLinear.value(composed)
        }
        pixel += 1
    }
    output
}

private func pngComposeRgba8(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    backgroundLinear: PngBackground,
    tables: PngGamma8BitTables,
    gammaEnabled: Bool
): Array<Byte> {
    let output = row.clone()
    if (!gammaEnabled) {
        var pixel: Int64 = 0
        while (pixel < Int64(rowInfo.width)) {
            let offset = pixel * 4
            let alpha = output[offset + 3]
            if (alpha == UInt8(0)) {
                output[offset] = UInt8(background.red & UInt16(0xff))
                output[offset + 1] = UInt8(background.green & UInt16(0xff))
                output[offset + 2] = UInt8(background.blue & UInt16(0xff))
            } else if (alpha < UInt8(0xff)) {
                output[offset] = pngComposite8(
                    output[offset], alpha, UInt8(background.red & UInt16(0xff))
                )
                output[offset + 1] = pngComposite8(
                    output[offset + 1],
                    alpha,
                    UInt8(background.green & UInt16(0xff))
                )
                output[offset + 2] = pngComposite8(
                    output[offset + 2],
                    alpha,
                    UInt8(background.blue & UInt16(0xff))
                )
            }
            pixel += 1
        }
        return output
    }
    let direct = tables.direct()
    let toLinear = tables.toLinear()
    let fromLinear = tables.fromLinear()
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let offset = pixel * 4
        let alpha = output[offset + 3]
        if (alpha == UInt8(0xff)) {
            output[offset] = direct.value(output[offset])
            output[offset + 1] = direct.value(output[offset + 1])
            output[offset + 2] = direct.value(output[offset + 2])
        } else if (alpha == UInt8(0)) {
            output[offset] = UInt8(background.red & UInt16(0xff))
            output[offset + 1] = UInt8(background.green & UInt16(0xff))
            output[offset + 2] = UInt8(background.blue & UInt16(0xff))
        } else {
            var channel: Int64 = 0
            while (channel < 3) {
                let linearBackground = match (channel) {
                    case 0 => backgroundLinear.red
                    case 1 => backgroundLinear.green
                    case _ => backgroundLinear.blue
                }
                let linear = toLinear.value(output[offset + channel])
                let composed = pngComposite8(
                    linear,
                    alpha,
                    UInt8(linearBackground & UInt16(0xff))
                )
                output[offset + channel] = fromLinear.value(composed)
                channel += 1
            }
        }
        pixel += 1
    }
    output
}

private func pngComposeGrayAlpha16(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    backgroundLinear: PngBackground,
    tables: PngGamma16BitTables,
    gammaEnabled: Bool
): Array<Byte> {
    let output = row.clone()
    if (!gammaEnabled) {
        var pixel: Int64 = 0
        while (pixel < Int64(rowInfo.width)) {
            let offset = pixel * 4
            let gray = pngReadComposeUInt16(output, offset)
            let alpha = pngReadComposeUInt16(output, offset + 2)
            if (alpha == UInt16(0)) {
                pngWriteComposeUInt16(output, offset, background.gray)
            } else if (alpha < UInt16(0xffff)) {
                pngWriteComposeUInt16(
                    output, offset, pngComposite16(gray, alpha, background.gray)
                )
            }
            pixel += 1
        }
        return output
    }
    let direct = tables.direct()
    let toLinear = tables.toLinear()
    let fromLinear = tables.fromLinear()
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let offset = pixel * 4
        let gray = pngReadComposeUInt16(output, offset)
        let alpha = pngReadComposeUInt16(output, offset + 2)
        if (alpha == UInt16(0xffff)) {
            pngWriteComposeUInt16(output, offset, direct.value(gray))
        } else if (alpha == UInt16(0)) {
            pngWriteComposeUInt16(output, offset, background.gray)
        } else {
            let linear = toLinear.value(gray)
            let composed = pngComposite16(linear, alpha, backgroundLinear.gray)
            pngWriteComposeUInt16(output, offset, fromLinear.value(composed))
        }
        pixel += 1
    }
    output
}

private func pngComposeRgba16(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    backgroundLinear: PngBackground,
    tables: PngGamma16BitTables,
    gammaEnabled: Bool
): Array<Byte> {
    let output = row.clone()
    if (!gammaEnabled) {
        var pixel: Int64 = 0
        while (pixel < Int64(rowInfo.width)) {
            let offset = pixel * 8
            let alpha = pngReadComposeUInt16(output, offset + 6)
            if (alpha == UInt16(0)) {
                pngWriteComposeUInt16(output, offset, background.red)
                pngWriteComposeUInt16(output, offset + 2, background.green)
                pngWriteComposeUInt16(output, offset + 4, background.blue)
            } else if (alpha < UInt16(0xffff)) {
                pngWriteComposeUInt16(
                    output,
                    offset,
                    pngComposite16(
                        pngReadComposeUInt16(output, offset), alpha, background.red
                    )
                )
                pngWriteComposeUInt16(
                    output,
                    offset + 2,
                    pngComposite16(
                        pngReadComposeUInt16(output, offset + 2),
                        alpha,
                        background.green
                    )
                )
                pngWriteComposeUInt16(
                    output,
                    offset + 4,
                    pngComposite16(
                        pngReadComposeUInt16(output, offset + 4),
                        alpha,
                        background.blue
                    )
                )
            }
            pixel += 1
        }
        return output
    }
    let direct = tables.direct()
    let toLinear = tables.toLinear()
    let fromLinear = tables.fromLinear()
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let offset = pixel * 8
        let alpha = pngReadComposeUInt16(output, offset + 6)
        if (alpha == UInt16(0xffff)) {
            var channel: Int64 = 0
            while (channel < 3) {
                let sampleOffset = offset + channel * 2
                pngWriteComposeUInt16(
                    output,
                    sampleOffset,
                    direct.value(pngReadComposeUInt16(output, sampleOffset))
                )
                channel += 1
            }
        } else if (alpha == UInt16(0)) {
            pngWriteComposeUInt16(output, offset, background.red)
            pngWriteComposeUInt16(output, offset + 2, background.green)
            pngWriteComposeUInt16(output, offset + 4, background.blue)
        } else {
            var channel: Int64 = 0
            while (channel < 3) {
                let sampleOffset = offset + channel * 2
                let linearBackground = match (channel) {
                    case 0 => backgroundLinear.red
                    case 1 => backgroundLinear.green
                    case _ => backgroundLinear.blue
                }
                let sample = pngReadComposeUInt16(output, sampleOffset)
                let linear = toLinear.value(sample)
                let composed = fromLinear.value(
                    pngComposite16(linear, alpha, linearBackground)
                )
                pngWriteComposeUInt16(output, sampleOffset, composed)
                channel += 1
            }
        }
        pixel += 1
    }
    output
}

private func pngDoCompose8(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    backgroundLinear: PngBackground,
    transparency: PngExpandTransparency,
    tables: PngGamma8BitTables,
    gammaEnabled: Bool
): Array<Byte> {
    if (rowInfo.colorType == Grayscale && rowInfo.channels == UInt8(1)) {
        if (rowInfo.bitDepth == UInt8(1) || rowInfo.bitDepth == UInt8(2) ||
            rowInfo.bitDepth == UInt8(4)) {
            return pngComposePackedGray(
                rowInfo, row, background, transparency, tables, gammaEnabled
            )
        }
        if (rowInfo.bitDepth == UInt8(8)) {
            return pngComposeGray8(
                rowInfo, row, background, transparency, tables, gammaEnabled
            )
        }
    }
    if (rowInfo.bitDepth != UInt8(8)) {
        return row.clone()
    }
    match (rowInfo.colorType) {
        case Truecolor =>
            pngComposeRgb8(
                rowInfo, row, background, transparency, tables, gammaEnabled
            )
        case GrayscaleAlpha => pngComposeGrayAlpha8(
            rowInfo, row, background, backgroundLinear, tables, gammaEnabled
        )
        case TruecolorAlpha => pngComposeRgba8(
            rowInfo, row, background, backgroundLinear, tables, gammaEnabled
        )
        case _ => row.clone()
    }
}

private func pngDoCompose16(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    backgroundLinear: PngBackground,
    transparency: PngExpandTransparency,
    tables: PngGamma16BitTables,
    gammaEnabled: Bool
): Array<Byte> {
    if (rowInfo.bitDepth != UInt8(16)) {
        return row.clone()
    }
    match (rowInfo.colorType) {
        case Grayscale =>
            pngComposeGray16(
                rowInfo, row, background, transparency, tables, gammaEnabled
            )
        case Truecolor =>
            pngComposeRgb16(
                rowInfo, row, background, transparency, tables, gammaEnabled
            )
        case GrayscaleAlpha => pngComposeGrayAlpha16(
            rowInfo, row, background, backgroundLinear, tables, gammaEnabled
        )
        case TruecolorAlpha => pngComposeRgba16(
            rowInfo, row, background, backgroundLinear, tables, gammaEnabled
        )
        case _ => row.clone()
    }
}

public func pngDoCompose(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    transparency: PngExpandTransparency
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    let output = if (rowInfo.bitDepth == UInt8(16)) {
        pngDoCompose16(
            rowInfo,
            row,
            background,
            background,
            transparency,
            PngGamma16BitTables(
                UInt8(0),
                false,
                Array<Array<UInt16>>(),
                Array<Array<UInt16>>(),
                Array<Array<UInt16>>()
            ),
            false
        )
    } else {
        pngDoCompose8(
            rowInfo,
            row,
            background,
            background,
            transparency,
            PngGamma8BitTables(Array<Byte>(), Array<Byte>(), Array<Byte>()),
            false
        )
    }
    PngReadTransformRow(rowInfo, output)
}

public func pngDoCompose(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    backgroundLinear: PngBackground,
    transparency: PngExpandTransparency,
    tables: PngGamma8BitTables
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    PngReadTransformRow(
        rowInfo,
        pngDoCompose8(
            rowInfo,
            row,
            background,
            backgroundLinear,
            transparency,
            tables,
            true
        )
    )
}

public func pngDoCompose(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    background: PngBackground,
    backgroundLinear: PngBackground,
    transparency: PngExpandTransparency,
    tables: PngGamma16BitTables
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    PngReadTransformRow(
        rowInfo,
        pngDoCompose16(
            rowInfo,
            row,
            background,
            backgroundLinear,
            transparency,
            tables,
            true
        )
    )
}

public func applyInitializedPngComposeStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageCompose)) {
        return PngReadTransformRow(rowInfo, row)
    }
    if (rowInfo.bitDepth == UInt8(16) &&
        initialization.gamma16BitTablesBuilt()) {
        return pngDoCompose(
            rowInfo,
            row,
            initialization.background(),
            initialization.backgroundLinear(),
            initialization.composeTransparency(),
            initialization.gamma16BitTables()
        )
    }
    if (rowInfo.bitDepth <= UInt8(8) &&
        initialization.gamma8BitTablesBuilt()) {
        return pngDoCompose(
            rowInfo,
            row,
            initialization.background(),
            initialization.backgroundLinear(),
            initialization.composeTransparency(),
            initialization.gamma8BitTables()
        )
    }
    pngDoCompose(
        rowInfo,
        row,
        initialization.background(),
        initialization.composeTransparency()
    )
}
