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
