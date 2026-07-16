package libpng4cj

import std.math.floor

public let PNG_FP_1: Int32 = Int32(100000)
public let PNG_GAMMA_THRESHOLD_FIXED: Int32 = Int32(5000)
public let PNG_DEFAULT_SRGB: Int32 = Int32(-1)
public let PNG_GAMMA_MAC_18: Int32 = Int32(-2)
public let PNG_DEFAULT_SRGB_RECIPROCAL_FLAG: Int32 = Int32(-100000)
public let PNG_GAMMA_MAC_18_RECIPROCAL_FLAG: Int32 = Int32(-50000)
public let PNG_GAMMA_SRGB: Int32 = Int32(220000)
public let PNG_GAMMA_SRGB_INVERSE: Int32 = Int32(45455)
public let PNG_GAMMA_MAC_OLD: Int32 = Int32(151724)
public let PNG_GAMMA_MAC_INVERSE: Int32 = Int32(65909)
public let PNG_LIB_GAMMA_MIN: Int32 = Int32(1000)
public let PNG_LIB_GAMMA_MAX: Int32 = Int32(10000000)

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

public func pngTranslateGammaFlags(outputGamma: Int32, isScreen: Bool): Int32 {
    if (outputGamma == PNG_DEFAULT_SRGB ||
        outputGamma == PNG_DEFAULT_SRGB_RECIPROCAL_FLAG) {
        return if (isScreen) { PNG_GAMMA_SRGB } else { PNG_GAMMA_SRGB_INVERSE }
    }
    if (outputGamma == PNG_GAMMA_MAC_18 ||
        outputGamma == PNG_GAMMA_MAC_18_RECIPROCAL_FLAG) {
        return if (isScreen) { PNG_GAMMA_MAC_OLD } else { PNG_GAMMA_MAC_INVERSE }
    }
    outputGamma
}

public func pngGammaSupported(gammaValue: Int32): Bool {
    gammaValue >= PNG_LIB_GAMMA_MIN && gammaValue <= PNG_LIB_GAMMA_MAX
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

public func pngReciprocalFixed(value: Int32): Int32 {
    let reciprocal = pngMulDivFixed(PNG_FP_1, PNG_FP_1, value)
    if (reciprocal.success) {
        return reciprocal.value
    }
    Int32(0)
}

public class PngFileGammaSources {
    public let fileGamma: Int32
    public let chunkGamma: Int32
    public let defaultGamma: Int32
    public let screenGamma: Int32

    public init(
        fileGamma: Int32,
        chunkGamma: Int32,
        defaultGamma: Int32,
        screenGamma: Int32
    ) {
        this.fileGamma = fileGamma
        this.chunkGamma = chunkGamma
        this.defaultGamma = defaultGamma
        this.screenGamma = screenGamma
    }
}

// Direct translation of upstream png_resolve_file_gamma.
public func pngResolveFileGamma(sources: PngFileGammaSources): Int32 {
    if (sources.fileGamma != Int32(0)) {
        return sources.fileGamma
    }
    if (sources.chunkGamma != Int32(0)) {
        return sources.chunkGamma
    }
    if (sources.defaultGamma != Int32(0)) {
        return sources.defaultGamma
    }
    if (sources.screenGamma != Int32(0)) {
        return pngReciprocalFixed(sources.screenGamma)
    }
    Int32(0)
}

public class PngGammaValues {
    public let fileGamma: Int32
    public let screenGamma: Int32
    public let correctionRequired: Bool

    public init(
        fileGamma: Int32,
        screenGamma: Int32,
        correctionRequired: Bool
    ) {
        this.fileGamma = fileGamma
        this.screenGamma = screenGamma
        this.correctionRequired = correctionRequired
    }
}

// Immutable translation of upstream png_init_gamma_values.
public func pngInitGammaValues(sources: PngFileGammaSources): PngGammaValues {
    var fileGamma = pngResolveFileGamma(sources)
    var screenGamma = sources.screenGamma
    var correctionRequired = false

    if (fileGamma > Int32(0)) {
        if (screenGamma > Int32(0)) {
            correctionRequired = pngGammaThreshold(fileGamma, screenGamma)
        } else {
            screenGamma = pngReciprocalFixed(fileGamma)
        }
    } else {
        fileGamma = PNG_FP_1
        screenGamma = PNG_FP_1
    }

    PngGammaValues(fileGamma, screenGamma, correctionRequired)
}
