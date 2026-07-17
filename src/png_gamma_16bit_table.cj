package libpng4cj

import std.math.floor
import std.math.pow

// Floating-arithmetic branch of upstream png_gamma_16bit_correct.
public func pngGamma16BitCorrect(value: UInt16, gammaValue: Int32): UInt16 {
    if (value == UInt16(0) || value == UInt16(65535)) {
        return value
    }
    let normalized = Float64(value) / 65535.0
    let exponent = Float64(gammaValue) * 0.00001
    UInt16(floor(65535.0 * pow(normalized, exponent) + 0.5))
}

private func pngCloneGamma16Segments(
    source: Array<Array<UInt16>>
): Array<Array<UInt16>> {
    let output = Array<Array<UInt16>>(source.size, repeat: Array<UInt16>())
    var index: Int64 = 0
    while (index < source.size) {
        output[index] = source[index].clone()
        index += 1
    }
    output
}

private func pngValidateGamma16Segments(
    shift: UInt8,
    segments: Array<Array<UInt16>>
): Unit {
    if (shift > UInt8(8)) {
        throw PngFormatException(
            InvalidArgument,
            Int64(shift),
            "16-bit gamma table shift must be inside 0..8"
        )
    }
    let expectedSegments = Int64(
        UInt32(1) << (UInt32(8) - UInt32(shift))
    )
    if (segments.size != expectedSegments) {
        throw PngFormatException(
            InvalidArgument,
            segments.size,
            "16-bit gamma table segment count does not match shift"
        )
    }
    var index: Int64 = 0
    while (index < segments.size) {
        if (segments[index].size != 256) {
            throw PngFormatException(
                InvalidArgument,
                segments[index].size,
                "16-bit gamma table segments must contain 256 entries"
            )
        }
        index += 1
    }
}

public class PngGamma16BitTable {
    public let shift: UInt8
    private let ownedSegments: Array<Array<UInt16>>

    init(shift: UInt8, segments: Array<Array<UInt16>>) {
        pngValidateGamma16Segments(shift, segments)
        this.shift = shift
        ownedSegments = pngCloneGamma16Segments(segments)
    }

    public init(other: PngGamma16BitTable) {
        shift = other.shift
        ownedSegments = other.segments()
    }

    public func segmentCount(): Int64 {
        ownedSegments.size
    }

    public func segmentSize(): Int64 {
        Int64(256)
    }

    public func segment(index: Int64): Array<UInt16> {
        if (index < 0 || index >= ownedSegments.size) {
            throw PngFormatException(
                InvalidArgument,
                index,
                "16-bit gamma table segment index is out of bounds"
            )
        }
        ownedSegments[index].clone()
    }

    public func value(sample: UInt16): UInt16 {
        let low = UInt32(sample & UInt16(0xff)) >> UInt32(shift)
        let high = UInt32(sample) >> UInt32(8)
        ownedSegments[Int64(low)][Int64(high)]
    }

    public func segments(): Array<Array<UInt16>> {
        pngCloneGamma16Segments(ownedSegments)
    }
}

// Floating-arithmetic branch of upstream png_build_16bit_table.
public func pngBuildGamma16BitTable(
    shift: UInt8,
    gammaValue: Int32
): PngGamma16BitTable {
    if (shift > UInt8(8)) {
        throw PngFormatException(
            InvalidArgument,
            Int64(shift),
            "16-bit gamma table shift must be inside 0..8"
        )
    }
    let shift32 = UInt32(shift)
    let segmentCount = Int64(UInt32(1) << (UInt32(8) - shift32))
    let compressedMax = (UInt32(1) << (UInt32(16) - shift32)) - UInt32(1)
    let maxByTwo = UInt32(1) << (UInt32(15) - shift32)
    let significant = pngGammaSignificant(gammaValue)
    let exponent = Float64(gammaValue) * 0.00001
    let inverseMax = 1.0 / Float64(compressedMax)
    let segments = Array<Array<UInt16>>(
        segmentCount,
        repeat: Array<UInt16>()
    )

    var segmentIndex: Int64 = 0
    while (segmentIndex < segmentCount) {
        let segment = Array<UInt16>(256, repeat: UInt16(0))
        var highIndex: Int64 = 0
        while (highIndex < segment.size) {
            let compressedInput =
                (UInt32(highIndex) << (UInt32(8) - shift32)) +
                UInt32(segmentIndex)
            if (significant) {
                segment[highIndex] = UInt16(floor(
                    65535.0 * pow(
                        Float64(compressedInput) * inverseMax,
                        exponent
                    ) + 0.5
                ))
            } else if (shift != UInt8(0)) {
                segment[highIndex] = UInt16(
                    (UInt64(compressedInput) * UInt64(65535) +
                    UInt64(maxByTwo)) / UInt64(compressedMax)
                )
            } else {
                segment[highIndex] = UInt16(compressedInput)
            }
            highIndex += 1
        }
        segments[segmentIndex] = segment
        segmentIndex += 1
    }
    PngGamma16BitTable(shift, segments)
}

// Floating-arithmetic branch of upstream png_build_16to8_table.
public func pngBuildGamma16To8Table(
    shift: UInt8,
    gammaValue: Int32
): PngGamma16BitTable {
    if (shift > UInt8(8)) {
        throw PngFormatException(
            InvalidArgument,
            Int64(shift),
            "16-to-8 gamma table shift must be inside 0..8"
        )
    }
    let shift32 = UInt32(shift)
    let segmentCount = Int64(UInt32(1) << (UInt32(8) - shift32))
    let compressedMax = (UInt32(1) << (UInt32(16) - shift32)) - UInt32(1)
    let segmentMask = UInt32(0xff) >> shift32
    let segments = Array<Array<UInt16>>(
        segmentCount,
        repeat: Array<UInt16>()
    )
    var segmentIndex: Int64 = 0
    while (segmentIndex < segmentCount) {
        segments[segmentIndex] = Array<UInt16>(256, repeat: UInt16(0))
        segmentIndex += 1
    }

    var last = UInt32(0)
    var outputIndex = UInt32(0)
    while (outputIndex < UInt32(255)) {
        let output = UInt16(outputIndex * UInt32(257))
        let corrected = pngGamma16BitCorrect(
            UInt16(UInt32(output) + UInt32(128)),
            gammaValue
        )
        let bound = UInt32(
            (UInt64(corrected) * UInt64(compressedMax) + UInt64(32768)) /
            UInt64(65535) + UInt64(1)
        )
        while (last < bound) {
            segments[Int64(last & segmentMask)][
                Int64(last >> (UInt32(8) - shift32))
            ] = output
            last += UInt32(1)
        }
        outputIndex += UInt32(1)
    }

    let entryCount = UInt32(segmentCount) << UInt32(8)
    while (last < entryCount) {
        segments[Int64(last & segmentMask)][
            Int64(last >> (UInt32(8) - shift32))
        ] = UInt16(65535)
        last += UInt32(1)
    }
    PngGamma16BitTable(shift, segments)
}

public func pngResolveGamma16BitShift(
    colorType: PngColorType,
    significantBits: PngSignificantBits,
    reductionRequired: Bool
): UInt8 {
    var significant = significantBits.gray
    if (colorType == Truecolor || colorType == TruecolorAlpha ||
        colorType == Indexed) {
        significant = significantBits.red
        if (significantBits.green > significant) {
            significant = significantBits.green
        }
        if (significantBits.blue > significant) {
            significant = significantBits.blue
        }
    }
    var shift = if (significant > UInt8(0) && significant < UInt8(16)) {
        UInt8(16) - significant
    } else {
        UInt8(0)
    }
    if (reductionRequired && shift < UInt8(5)) {
        shift = UInt8(5)
    }
    if (shift > UInt8(8)) {
        shift = UInt8(8)
    }
    shift
}

public class PngGamma16BitTables {
    private let shiftValue: UInt8
    private let reductionTableValue: Bool
    private let ownedDirectSegments: Array<Array<UInt16>>
    private let ownedToLinearSegments: Array<Array<UInt16>>
    private let ownedFromLinearSegments: Array<Array<UInt16>>

    init(
        shift: UInt8,
        reductionTable: Bool,
        directSegments: Array<Array<UInt16>>,
        toLinearSegments: Array<Array<UInt16>>,
        fromLinearSegments: Array<Array<UInt16>>
    ) {
        if (shift > UInt8(8)) {
            throw PngFormatException(
                InvalidArgument,
                Int64(shift),
                "16-bit gamma table group shift must be inside 0..8"
            )
        }
        if (directSegments.size != 0) {
            pngValidateGamma16Segments(shift, directSegments)
        }
        if ((toLinearSegments.size == 0) != (fromLinearSegments.size == 0)) {
            throw PngFormatException(
                InvalidArgument,
                toLinearSegments.size + fromLinearSegments.size,
                "linear 16-bit gamma tables must be an empty or complete pair"
            )
        }
        if (toLinearSegments.size != 0) {
            pngValidateGamma16Segments(shift, toLinearSegments)
            pngValidateGamma16Segments(shift, fromLinearSegments)
        }
        shiftValue = shift
        reductionTableValue = reductionTable && directSegments.size != 0
        ownedDirectSegments = pngCloneGamma16Segments(directSegments)
        ownedToLinearSegments = pngCloneGamma16Segments(toLinearSegments)
        ownedFromLinearSegments = pngCloneGamma16Segments(fromLinearSegments)
    }

    public init(other: PngGamma16BitTables) {
        shiftValue = other.shiftValue
        reductionTableValue = other.reductionTableValue
        ownedDirectSegments = pngCloneGamma16Segments(
            other.ownedDirectSegments
        )
        ownedToLinearSegments = pngCloneGamma16Segments(
            other.ownedToLinearSegments
        )
        ownedFromLinearSegments = pngCloneGamma16Segments(
            other.ownedFromLinearSegments
        )
    }

    public func built(): Bool {
        ownedDirectSegments.size != 0
    }

    public func linearTablesBuilt(): Bool {
        ownedToLinearSegments.size != 0
    }

    public func reductionTableBuilt(): Bool {
        reductionTableValue
    }

    public func shift(): UInt8 {
        shiftValue
    }

    public func direct(): PngGamma16BitTable {
        if (!built()) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "16-bit direct gamma table was not initialized"
            )
        }
        PngGamma16BitTable(shiftValue, ownedDirectSegments)
    }

    public func toLinear(): PngGamma16BitTable {
        if (!linearTablesBuilt()) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "16-bit to-linear gamma table was not initialized"
            )
        }
        PngGamma16BitTable(shiftValue, ownedToLinearSegments)
    }

    public func fromLinear(): PngGamma16BitTable {
        if (!linearTablesBuilt()) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "16-bit from-linear gamma table was not initialized"
            )
        }
        PngGamma16BitTable(shiftValue, ownedFromLinearSegments)
    }
}

private func pngEmptyGamma16BitTables(): PngGamma16BitTables {
    PngGamma16BitTables(
        UInt8(0),
        false,
        Array<Array<UInt16>>(),
        Array<Array<UInt16>>(),
        Array<Array<UInt16>>()
    )
}

// 16-bit branch of upstream png_build_gamma_table.
public func pngBuildGamma16BitTables(
    shift: UInt8,
    fileGamma: Int32,
    screenGamma: Int32,
    linearTablesRequired: Bool,
    reductionRequired: Bool
): PngGamma16BitTables {
    let correction = if (screenGamma > Int32(0)) {
        pngReciprocal2Fixed(screenGamma, fileGamma)
    } else {
        PNG_FP_1
    }
    let direct = if (reductionRequired) {
        pngBuildGamma16To8Table(shift, pngReciprocalFixed(correction))
    } else {
        pngBuildGamma16BitTable(shift, correction)
    }
    if (!linearTablesRequired) {
        return PngGamma16BitTables(
            shift,
            reductionRequired,
            direct.segments(),
            Array<Array<UInt16>>(),
            Array<Array<UInt16>>()
        )
    }
    let fileToLinear = pngReciprocalFixed(fileGamma)
    let linearToScreen = if (screenGamma > Int32(0)) {
        pngReciprocalFixed(screenGamma)
    } else {
        fileGamma
    }
    PngGamma16BitTables(
        shift,
        reductionRequired,
        direct.segments(),
        pngBuildGamma16BitTable(shift, fileToLinear).segments(),
        pngBuildGamma16BitTable(shift, linearToScreen).segments()
    )
}

func pngBuildInitializedGamma16BitTables(
    gammaValues: PngGammaValues,
    rgbToGrayEnabled: Bool,
    composeGammaTablesRequired: Bool,
    bitDepth: UInt8,
    colorType: PngColorType,
    significantBits: PngSignificantBits,
    reductionRequired: Bool
): PngGamma16BitTables {
    if (bitDepth != UInt8(16)) {
        return pngEmptyGamma16BitTables()
    }
    let linearTablesRequired = composeGammaTablesRequired ||
        (rgbToGrayEnabled &&
        (pngGammaSignificant(gammaValues.fileGamma) ||
        pngGammaSignificant(gammaValues.screenGamma)))
    if (!gammaValues.correctionRequired && !linearTablesRequired) {
        return pngEmptyGamma16BitTables()
    }
    let shift = pngResolveGamma16BitShift(
        colorType,
        significantBits,
        reductionRequired
    )
    pngBuildGamma16BitTables(
        shift,
        gammaValues.fileGamma,
        gammaValues.screenGamma,
        linearTablesRequired,
        reductionRequired
    )
}
