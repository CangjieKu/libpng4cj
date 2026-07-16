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

public class PngGamma16BitTable {
    public let shift: UInt8
    private let ownedSegments: Array<Array<UInt16>>

    init(shift: UInt8, segments: Array<Array<UInt16>>) {
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
        this.shift = shift
        ownedSegments = pngCloneGamma16Segments(segments)
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
