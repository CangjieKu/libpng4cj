package libpng4cj

import std.math.floor
import std.math.pow

// Floating-arithmetic branch of upstream png_gamma_8bit_correct.
public func pngGamma8BitCorrect(value: UInt8, gammaValue: Int32): UInt8 {
    if (value == UInt8(0) || value == UInt8(255)) {
        return value
    }
    let normalized = Float64(value) / 255.0
    let exponent = Float64(gammaValue) * 0.00001
    UInt8(floor(255.0 * pow(normalized, exponent) + 0.5))
}

public class PngGamma8BitTable {
    private let ownedValues: Array<Byte>

    init(values: Array<Byte>) {
        if (values.size != 256) {
            throw PngFormatException(
                InvalidArgument,
                values.size,
                "8-bit gamma table must contain 256 entries"
            )
        }
        ownedValues = values.clone()
    }

    public func size(): Int64 {
        ownedValues.size
    }

    public func value(sample: UInt8): UInt8 {
        ownedValues[Int64(sample)]
    }

    public func values(): Array<Byte> {
        ownedValues.clone()
    }
}

// Result-equivalent translation of upstream png_build_8bit_table.
public func pngBuildGamma8BitTable(gammaValue: Int32): PngGamma8BitTable {
    let values = Array<Byte>(256, repeat: 0)
    var index: Int64 = 0
    if (pngGammaSignificant(gammaValue)) {
        while (index < values.size) {
            values[index] = pngGamma8BitCorrect(UInt8(index), gammaValue)
            index += 1
        }
    } else {
        while (index < values.size) {
            values[index] = UInt8(index)
            index += 1
        }
    }
    PngGamma8BitTable(values)
}

public class PngGamma8BitTables {
    private let ownedDirectValues: Array<Byte>
    private let ownedToLinearValues: Array<Byte>
    private let ownedFromLinearValues: Array<Byte>

    init(
        directValues: Array<Byte>,
        toLinearValues: Array<Byte>,
        fromLinearValues: Array<Byte>
    ) {
        if (directValues.size != 0 && directValues.size != 256) {
            throw PngFormatException(
                InvalidArgument,
                directValues.size,
                "direct 8-bit gamma table must be empty or contain 256 entries"
            )
        }
        if ((toLinearValues.size == 0) != (fromLinearValues.size == 0) ||
            (toLinearValues.size != 0 && toLinearValues.size != 256) ||
            (fromLinearValues.size != 0 && fromLinearValues.size != 256)) {
            throw PngFormatException(
                InvalidArgument,
                toLinearValues.size + fromLinearValues.size,
                "linear 8-bit gamma tables must be an empty or complete pair"
            )
        }
        ownedDirectValues = directValues.clone()
        ownedToLinearValues = toLinearValues.clone()
        ownedFromLinearValues = fromLinearValues.clone()
    }

    public init(other: PngGamma8BitTables) {
        ownedDirectValues = other.ownedDirectValues.clone()
        ownedToLinearValues = other.ownedToLinearValues.clone()
        ownedFromLinearValues = other.ownedFromLinearValues.clone()
    }

    public func built(): Bool {
        ownedDirectValues.size == 256
    }

    public func linearTablesBuilt(): Bool {
        ownedToLinearValues.size == 256
    }

    public func direct(): PngGamma8BitTable {
        if (!built()) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "8-bit direct gamma table was not initialized"
            )
        }
        PngGamma8BitTable(ownedDirectValues)
    }

    public func toLinear(): PngGamma8BitTable {
        if (!linearTablesBuilt()) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "8-bit to-linear gamma table was not initialized"
            )
        }
        PngGamma8BitTable(ownedToLinearValues)
    }

    public func fromLinear(): PngGamma8BitTable {
        if (!linearTablesBuilt()) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "8-bit from-linear gamma table was not initialized"
            )
        }
        PngGamma8BitTable(ownedFromLinearValues)
    }
}

private func pngEmptyGamma8BitTables(): PngGamma8BitTables {
    PngGamma8BitTables(Array<Byte>(), Array<Byte>(), Array<Byte>())
}

// 8-bit branch of upstream png_build_gamma_table.
public func pngBuildGamma8BitTables(
    fileGamma: Int32,
    screenGamma: Int32,
    linearTablesRequired: Bool
): PngGamma8BitTables {
    let correction = if (screenGamma > Int32(0)) {
        pngReciprocal2Fixed(screenGamma, fileGamma)
    } else {
        PNG_FP_1
    }
    let directValues = pngBuildGamma8BitTable(correction).values()
    if (!linearTablesRequired) {
        return PngGamma8BitTables(
            directValues,
            Array<Byte>(),
            Array<Byte>()
        )
    }
    let fileToLinear = pngReciprocalFixed(fileGamma)
    let linearToScreen = if (screenGamma > Int32(0)) {
        pngReciprocalFixed(screenGamma)
    } else {
        fileGamma
    }
    PngGamma8BitTables(
        directValues,
        pngBuildGamma8BitTable(fileToLinear).values(),
        pngBuildGamma8BitTable(linearToScreen).values()
    )
}

func pngBuildInitializedGamma8BitTables(
    gammaValues: PngGammaValues,
    rgbToGrayEnabled: Bool,
    composeGammaTablesRequired: Bool,
    bitDepth: UInt8
): PngGamma8BitTables {
    if (bitDepth > UInt8(8)) {
        return pngEmptyGamma8BitTables()
    }
    let linearTablesRequired = composeGammaTablesRequired ||
        (rgbToGrayEnabled &&
        (pngGammaSignificant(gammaValues.fileGamma) ||
        pngGammaSignificant(gammaValues.screenGamma)))
    if (!gammaValues.correctionRequired && !linearTablesRequired) {
        return pngEmptyGamma8BitTables()
    }
    pngBuildGamma8BitTables(
        gammaValues.fileGamma,
        gammaValues.screenGamma,
        linearTablesRequired
    )
}
