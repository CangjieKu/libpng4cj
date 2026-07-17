package libpng4cj

public class PngPaletteTransformInitialization {
    private let ownedPalette: Array<Byte>
    private let ownedPaletteAlpha: Array<Byte>
    public let preprocessed: Bool
    public let composeApplied: Bool
    public let gammaApplied: Bool

    init(
        palette: Array<Byte>,
        paletteAlpha: Array<Byte>,
        preprocessed: Bool,
        composeApplied: Bool,
        gammaApplied: Bool
    ) {
        ownedPalette = palette.clone()
        ownedPaletteAlpha = paletteAlpha.clone()
        this.preprocessed = preprocessed
        this.composeApplied = composeApplied
        this.gammaApplied = gammaApplied
    }

    public func palette(): Array<Byte> {
        ownedPalette.clone()
    }

    public func paletteAlpha(): Array<Byte> {
        ownedPaletteAlpha.clone()
    }
}

private func pngValidatePaletteTransformInputs(
    palette: Array<Byte>,
    paletteAlpha: Array<Byte>
): Int64 {
    if (palette.size == 0 || palette.size % 3 != 0) {
        throw PngFormatException(
            InvalidPalette,
            palette.size,
            "palette background transform requires complete RGB entries"
        )
    }
    let entryCount = palette.size / 3
    if (paletteAlpha.size > entryCount) {
        throw PngFormatException(
            InvalidTransparency,
            paletteAlpha.size,
            "palette alpha prefix exceeds the retained palette"
        )
    }
    entryCount
}

private func pngPaletteComposite8(
    foreground: UInt8,
    alpha: UInt8,
    background: UInt8
): UInt8 {
    let temporary = UInt32(foreground) * UInt32(alpha) +
        UInt32(background) * (UInt32(255) - UInt32(alpha)) + UInt32(128)
    UInt8(((temporary + (temporary >> UInt32(8))) >> UInt32(8)) & UInt32(0xff))
}

private func pngPaletteBackgroundChannel(
    background: PngBackground,
    channel: Int64
): UInt8 {
    UInt8(match (channel) {
        case 0 => background.red
        case 1 => background.green
        case _ => background.blue
    } & UInt16(0xff))
}

private func pngComposePaletteWithoutGamma(
    palette: Array<Byte>,
    paletteAlpha: Array<Byte>,
    background: PngBackground
): Array<Byte> {
    let output = palette.clone()
    let entryCount = pngValidatePaletteTransformInputs(palette, paletteAlpha)
    var entry: Int64 = 0
    while (entry < entryCount) {
        let alpha = if (entry < paletteAlpha.size) {
            paletteAlpha[entry]
        } else {
            UInt8(0xff)
        }
        if (alpha != UInt8(0xff)) {
            var channel: Int64 = 0
            while (channel < 3) {
                let offset = entry * 3 + channel
                let back = pngPaletteBackgroundChannel(background, channel)
                output[offset] = if (alpha == UInt8(0)) {
                    back
                } else {
                    pngPaletteComposite8(output[offset], alpha, back)
                }
                channel += 1
            }
        }
        entry += 1
    }
    output
}

private func pngComposePaletteWithGamma(
    palette: Array<Byte>,
    paletteAlpha: Array<Byte>,
    background: PngBackground,
    backgroundLinear: PngBackground,
    tables: PngGamma8BitTables
): Array<Byte> {
    let output = palette.clone()
    let entryCount = pngValidatePaletteTransformInputs(palette, paletteAlpha)
    let direct = tables.direct()
    let toLinear = tables.toLinear()
    let fromLinear = tables.fromLinear()
    var entry: Int64 = 0
    while (entry < entryCount) {
        let alpha = if (entry < paletteAlpha.size) {
            paletteAlpha[entry]
        } else {
            UInt8(0xff)
        }
        var channel: Int64 = 0
        while (channel < 3) {
            let offset = entry * 3 + channel
            if (alpha == UInt8(0)) {
                output[offset] = pngPaletteBackgroundChannel(
                    background,
                    channel
                )
            } else if (alpha == UInt8(0xff)) {
                output[offset] = direct.value(output[offset])
            } else {
                let linear = toLinear.value(output[offset])
                let back = pngPaletteBackgroundChannel(
                    backgroundLinear,
                    channel
                )
                output[offset] = fromLinear.value(
                    pngPaletteComposite8(linear, alpha, back)
                )
            }
            channel += 1
        }
        entry += 1
    }
    output
}

private func pngCorrectPaletteGamma(
    palette: Array<Byte>,
    paletteAlpha: Array<Byte>,
    tables: PngGamma8BitTables
): Array<Byte> {
    pngValidatePaletteTransformInputs(palette, paletteAlpha)
    let output = palette.clone()
    let direct = tables.direct()
    var index: Int64 = 0
    while (index < output.size) {
        output[index] = direct.value(output[index])
        index += 1
    }
    output
}

public func pngInitPaletteBackgroundTransformations(
    palette: Array<Byte>,
    paletteAlpha: Array<Byte>,
    composeEnabled: Bool,
    background: PngBackground,
    backgroundLinear: PngBackground,
    gammaCorrectionRequired: Bool,
    tables: PngGamma8BitTables
): PngPaletteTransformInitialization {
    pngValidatePaletteTransformInputs(palette, paletteAlpha)
    if (composeEnabled) {
        let transformed = if (tables.linearTablesBuilt()) {
            pngComposePaletteWithGamma(
                palette,
                paletteAlpha,
                background,
                backgroundLinear,
                tables
            )
        } else {
            pngComposePaletteWithoutGamma(
                palette,
                paletteAlpha,
                background
            )
        }
        return PngPaletteTransformInitialization(
            transformed,
            paletteAlpha,
            true,
            true,
            tables.linearTablesBuilt()
        )
    }
    if (gammaCorrectionRequired && tables.built()) {
        return PngPaletteTransformInitialization(
            pngCorrectPaletteGamma(palette, paletteAlpha, tables),
            paletteAlpha,
            true,
            false,
            true
        )
    }
    PngPaletteTransformInitialization(
        palette,
        paletteAlpha,
        false,
        false,
        false
    )
}
