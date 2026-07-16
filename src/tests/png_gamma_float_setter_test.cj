package libpng4cj.tests

import libpng4cj.*

@Test
public class PngGammaFloatSetterTestSuite {
    @TestCase
    public func convertsOrdinaryAlreadyFixedAndFlagValues(): Unit {
        @Assert(pngConvertGammaValue(2.2, "screen"), Int32(220000))
        @Assert(pngConvertGammaValue(0.45455, "file"), Int32(45455))
        @Assert(pngConvertGammaValue(220000.0, "fixed"), Int32(220000))
        @Assert(pngConvertGammaValue(-1.0, "flag"), PNG_DEFAULT_SRGB)
        @Assert(pngConvertGammaValue(-2.0, "flag"), PNG_GAMMA_MAC_18)
    }

    @TestCase
    public func bracketsFloatingGammaHalfThresholds(): Unit {
        @Assert(
            pngConvertGammaValue(0.00003499999999999, "below"),
            Int32(3)
        )
        @Assert(
            pngConvertGammaValue(0.00003500000000001, "above"),
            Int32(4)
        )
    }

    @TestCase
    public func delegatesConvertedValuesIntoFixedSetterState(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setGamma(2.2, 0.45455), true)
        @Assert(state.screenGamma(), PNG_GAMMA_SRGB)
        @Assert(state.fileGamma(), PNG_GAMMA_SRGB_INVERSE)

        let flags = PngReadTransformState()
        @Assert(flags.setGamma(-1.0, -1.0), true)
        @Assert(flags.screenGamma(), PNG_GAMMA_SRGB)
        @Assert(flags.fileGamma(), PNG_GAMMA_SRGB_INVERSE)
    }

    @TestCase
    public func treatsOneHundredTwentyEightAsAlreadyFixed(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setGamma(128.0, 50000.0), false)
        @Assert(state.gammaUnsupportedWarning(), true)
        @Assert(state.gammaConfigured(), false)
    }

    @TestCase
    public func rejectsNonfiniteAndOverflowBeforeStateMutation(): Unit {
        let values: Array<Float64> = [Float64.NaN, Float64.Inf, -Float64.Inf]
        for (value in values) {
            let state = PngReadTransformState()
            try {
                state.setGamma(value, 0.45455)
                @Fail("nonfinite gamma should fail")
            } catch (error: PngFormatException) {
                @Assert(error.kind.toString(), "INVALID_ARGUMENT")
                @Assert(state.gammaConfigured(), false)
            }
        }

        let overflow = PngReadTransformState()
        try {
            overflow.setGamma(2147483648.0, 0.45455)
            @Fail("overflow gamma should fail")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
            @Assert(overflow.gammaConfigured(), false)
        }
    }

    @TestCase
    public func preservesPriorStateWhenSecondConversionOrLifecycleFails(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setGamma(2.0, 0.5), true)

        try {
            state.setGamma(2.2, Float64.NaN)
            @Fail("invalid file gamma should fail")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
        }
        @Assert(state.screenGamma(), Int32(200000))
        @Assert(state.fileGamma(), Int32(50000))

        state.markRowInitialized()
        @Assert(state.setGamma(2.5, 0.4), false)
        @Assert(state.screenGamma(), Int32(200000))
        @Assert(state.fileGamma(), Int32(50000))
        @Assert(
            state.lastApplicationError().toString(),
            "INVALID_AFTER_ROW_INITIALIZATION"
        )
    }
}
