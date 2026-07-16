package libpng4cj.tests

import libpng4cj.*

@Test
public class PngGammaSetterTestSuite {
    @TestCase
    public func translatesSrgbAndOldMacFlagsByGammaRole(): Unit {
        @Assert(pngTranslateGammaFlags(PNG_DEFAULT_SRGB, true), PNG_GAMMA_SRGB)
        @Assert(
            pngTranslateGammaFlags(PNG_DEFAULT_SRGB, false),
            PNG_GAMMA_SRGB_INVERSE
        )
        @Assert(
            pngTranslateGammaFlags(PNG_DEFAULT_SRGB_RECIPROCAL_FLAG, true),
            PNG_GAMMA_SRGB
        )
        @Assert(
            pngTranslateGammaFlags(PNG_DEFAULT_SRGB_RECIPROCAL_FLAG, false),
            PNG_GAMMA_SRGB_INVERSE
        )
        @Assert(
            pngTranslateGammaFlags(PNG_GAMMA_MAC_18, true),
            PNG_GAMMA_MAC_OLD
        )
        @Assert(
            pngTranslateGammaFlags(PNG_GAMMA_MAC_18, false),
            PNG_GAMMA_MAC_INVERSE
        )
        @Assert(
            pngTranslateGammaFlags(PNG_GAMMA_MAC_18_RECIPROCAL_FLAG, true),
            PNG_GAMMA_MAC_OLD
        )
        @Assert(
            pngTranslateGammaFlags(PNG_GAMMA_MAC_18_RECIPROCAL_FLAG, false),
            PNG_GAMMA_MAC_INVERSE
        )
        @Assert(pngTranslateGammaFlags(Int32(123456), true), Int32(123456))
    }

    @TestCase
    public func preservesInclusiveSupportedGammaRange(): Unit {
        @Assert(pngGammaSupported(PNG_LIB_GAMMA_MIN), true)
        @Assert(pngGammaSupported(PNG_LIB_GAMMA_MAX), true)
        @Assert(pngGammaSupported(PNG_LIB_GAMMA_MIN - Int32(1)), false)
        @Assert(pngGammaSupported(PNG_LIB_GAMMA_MAX + Int32(1)), false)
    }

    @TestCase
    public func storesTranslatedGammaBeforeIhdrAndReplacesOnSuccess(): Unit {
        let state = PngReadTransformState()
        @Assert(state.gammaConfigured(), false)
        @Assert(state.setGammaFixed(PNG_DEFAULT_SRGB, PNG_DEFAULT_SRGB), true)
        @Assert(state.detectsUninitializedTransforms(), true)
        @Assert(state.screenGamma(), PNG_GAMMA_SRGB)
        @Assert(state.fileGamma(), PNG_GAMMA_SRGB_INVERSE)
        @Assert(state.gammaFileApplicationError(), false)
        @Assert(state.gammaScreenApplicationError(), false)
        @Assert(state.gammaUnsupportedWarning(), false)

        @Assert(state.setGammaFixed(Int32(200000), Int32(50000)), true)
        @Assert(state.screenGamma(), Int32(200000))
        @Assert(state.fileGamma(), Int32(50000))
    }

    @TestCase
    public func reportsInvalidGammaFactsWithoutMutatingState(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setGammaFixed(Int32(200000), Int32(50000)), true)
        @Assert(state.setGammaFixed(Int32(0), Int32(-3)), false)
        @Assert(state.gammaFileApplicationError(), true)
        @Assert(state.gammaScreenApplicationError(), true)
        @Assert(state.gammaUnsupportedWarning(), true)
        @Assert(state.screenGamma(), Int32(200000))
        @Assert(state.fileGamma(), Int32(50000))
    }

    @TestCase
    public func rejectsUnsupportedAndPostInitializationCallsWithoutMutation(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setGammaFixed(Int32(200000), Int32(50000)), true)
        @Assert(
            state.setGammaFixed(PNG_LIB_GAMMA_MAX + Int32(1), Int32(50000)),
            false
        )
        @Assert(state.gammaFileApplicationError(), false)
        @Assert(state.gammaScreenApplicationError(), false)
        @Assert(state.gammaUnsupportedWarning(), true)
        @Assert(state.screenGamma(), Int32(200000))
        @Assert(state.fileGamma(), Int32(50000))

        state.markRowInitialized()
        @Assert(state.setGammaFixed(Int32(250000), Int32(40000)), false)
        @Assert(
            state.lastApplicationError().toString(),
            "INVALID_AFTER_ROW_INITIALIZATION"
        )
        @Assert(state.screenGamma(), Int32(200000))
        @Assert(state.fileGamma(), Int32(50000))
    }
}
