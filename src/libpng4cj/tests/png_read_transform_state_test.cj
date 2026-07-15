package libpng4cj.tests

import libpng4cj.*

@Test
public class PngReadTransformStateTestSuite {
    @TestCase
    public func preservesRtranLifecycleAndDetectFlag(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setStripAlpha(), true)
        @Assert(state.detectsUninitializedTransforms(), true)
        @Assert(state.lastApplicationError().toString(), "NONE")

        let rgbState = PngReadTransformState()
        @Assert(
            rgbState.setRgbToGrayFixed(Convert, UInt32(21268), UInt32(71514)),
            false
        )
        @Assert(rgbState.lastApplicationError().toString(), "INVALID_BEFORE_IHDR")
        @Assert(rgbState.detectsUninitializedTransforms(), false)

        rgbState.markIhdrRead(Truecolor)
        @Assert(
            rgbState.setRgbToGrayFixed(Convert, UInt32(21268), UInt32(71514)),
            true
        )
        @Assert(rgbState.detectsUninitializedTransforms(), true)
        @Assert(rgbState.lastApplicationError().toString(), "NONE")

        rgbState.markRowInitialized()
        @Assert(rgbState.setExpand(), false)
        @Assert(
            rgbState.lastApplicationError().toString(),
            "INVALID_AFTER_ROW_INITIALIZATION"
        )

        let rowFirstState = PngReadTransformState()
        rowFirstState.markRowInitialized()
        @Assert(
            rowFirstState.setRgbToGrayFixed(Convert, UInt32(21268), UInt32(71514)),
            false
        )
        @Assert(
            rowFirstState.lastApplicationError().toString(),
            "INVALID_AFTER_ROW_INITIALIZATION"
        )
    }

    @TestCase
    public func preservesSimpleSetterBitsAndAliasCollapse(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setExpandGrayOneTwoFourToEight(), true)
        @Assert(state.expandEnabled(), true)
        @Assert(state.expandTransparencyEnabled(), false)

        @Assert(state.setExpand(), true)
        @Assert(state.expandEnabled(), true)
        @Assert(state.expandTransparencyEnabled(), true)

        let paletteState = PngReadTransformState()
        @Assert(paletteState.setPaletteToRgb(), true)
        @Assert(paletteState.expandEnabled(), true)
        @Assert(paletteState.expandTransparencyEnabled(), true)

        let transparencyState = PngReadTransformState()
        @Assert(transparencyState.setTransparencyToAlpha(), true)
        @Assert(transparencyState.expandEnabled(), true)
        @Assert(transparencyState.expandTransparencyEnabled(), true)

        @Assert(state.setExpand16(), true)
        @Assert(state.expand16Enabled(), true)
        @Assert(state.expandEnabled(), true)
        @Assert(state.expandTransparencyEnabled(), true)

        @Assert(state.setGrayToRgb(), true)
        @Assert(state.grayToRgbEnabled(), true)
        @Assert(state.expandEnabled(), true)
    }

    @TestCase
    public func keepsScalePrecedenceAndDuplicateSettersIdempotent(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setStrip16(), true)
        @Assert(state.setStrip16(), true)
        @Assert(state.sixteenToEightMode().toString(), "STRIP")

        @Assert(state.setScale16(), true)
        @Assert(state.setScale16(), true)
        @Assert(state.scale16Enabled(), true)
        @Assert(state.strip16Enabled(), true)
        @Assert(state.sixteenToEightMode().toString(), "SCALE")
    }

    @TestCase
    public func indexedRgbToGrayAlsoRequestsExpand(): Unit {
        let state = PngReadTransformState()
        state.markIhdrRead(Indexed)
        @Assert(
            state.setRgbToGrayFixed(Convert, UInt32(21268), UInt32(71514)),
            true
        )
        @Assert(state.rgbToGrayEnabled(), true)
        @Assert(state.expandEnabled(), true)
        @Assert(state.rgbToGrayTransform().customCoefficientsAccepted, true)
    }
}
