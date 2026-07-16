package libpng4cj

import std.math.floor

public let PNG_FP_1: Int32 = Int32(100000)
public let PNG_GAMMA_THRESHOLD_FIXED: Int32 = Int32(5000)

public class PngFixedMulDivResult {
    public let success: Bool
    public let value: Int32

    public init(success: Bool, value: Int32) {
        this.success = success
        this.value = value
    }
}

// Frozen default floating-arithmetic branch of upstream png_muldiv.
public func pngMulDivFixed(
    value: Int32,
    multiplier: Int32,
    divisor: Int32
): PngFixedMulDivResult {
    if (divisor == Int32(0)) {
        return PngFixedMulDivResult(false, Int32(0))
    }
    if (value == Int32(0) || multiplier == Int32(0)) {
        return PngFixedMulDivResult(true, Int32(0))
    }

    let rounded = floor(
        Float64(value) * Float64(multiplier) / Float64(divisor) + 0.5
    )
    if (rounded > 2147483647.0 || rounded < -2147483648.0) {
        return PngFixedMulDivResult(false, Int32(0))
    }
    PngFixedMulDivResult(true, Int32(rounded))
}

public func pngGammaSignificant(gammaValue: Int32): Bool {
    gammaValue < PNG_FP_1 - PNG_GAMMA_THRESHOLD_FIXED ||
        gammaValue > PNG_FP_1 + PNG_GAMMA_THRESHOLD_FIXED
}

// Direct translation of upstream png_gamma_threshold.
public func pngGammaThreshold(screenGamma: Int32, fileGamma: Int32): Bool {
    let product = pngMulDivFixed(
        screenGamma,
        fileGamma,
        PNG_FP_1
    )
    !product.success || pngGammaSignificant(product.value)
}
