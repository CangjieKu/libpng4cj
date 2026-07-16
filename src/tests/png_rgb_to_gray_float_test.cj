package libpng4cj.tests

import libpng4cj.*

private func floatRgbState(
    red: Float64,
    green: Float64,
    colorType!: PngColorType = Truecolor
): PngReadTransformState {
    let state = PngReadTransformState()
    state.markIhdrRead(colorType)
    @Assert(state.setRgbToGray(Convert, red, green), true)
    state
}

@Test
public class PngRgbToGrayFloatTestSuite {
    @TestCase
    public func matchesCommonFixedCoefficientConversion(): Unit {
        let floating = floatRgbState(0.21268, 0.71514).rgbToGrayTransform()
        let fixedState = PngReadTransformState()
        fixedState.markIhdrRead(Truecolor)
        @Assert(
            fixedState.setRgbToGrayFixed(Convert, Int64(21268), Int64(71514)),
            true
        )
        let fixed = fixedState.rgbToGrayTransform()

        @Assert(floating.redCoefficient, fixed.redCoefficient)
        @Assert(floating.greenCoefficient, fixed.greenCoefficient)
        @Assert(floating.blueCoefficient, fixed.blueCoefficient)
        @Assert(floating.customCoefficientsAccepted, true)
    }

    @TestCase
    public func roundsPositiveAndNegativeHalfValuesLikePngFixed(): Unit {
        let belowPositiveHalf = floatRgbState(0.000035, 0.0).rgbToGrayTransform()
        @Assert(belowPositiveHalf.redCoefficient, UInt16(0))
        @Assert(belowPositiveHalf.customCoefficientsAccepted, true)

        let abovePositiveHalf = floatRgbState(
            0.00003500000000001,
            0.0
        ).rgbToGrayTransform()
        @Assert(abovePositiveHalf.redCoefficient, UInt16(1))
        @Assert(abovePositiveHalf.customCoefficientsAccepted, true)

        let negativeHalf = floatRgbState(-0.000005, 0.0).rgbToGrayTransform()
        @Assert(negativeHalf.redCoefficient, UInt16(0))
        @Assert(negativeHalf.customCoefficientsAccepted, true)

        let belowNegativeHalf = floatRgbState(
            -0.00000500000000001,
            0.0
        ).rgbToGrayTransform()
        @Assert(belowNegativeHalf.redCoefficient, UInt16(6968))
        @Assert(belowNegativeHalf.customCoefficientsAccepted, false)
    }

    @TestCase
    public func preservesIgnoredOutOfRangePairBehavior(): Unit {
        let transform = floatRgbState(0.8, 0.3).rgbToGrayTransform()
        @Assert(transform.redCoefficient, UInt16(6968))
        @Assert(transform.greenCoefficient, UInt16(23434))
        @Assert(transform.blueCoefficient, UInt16(2366))
        @Assert(transform.customCoefficientsAccepted, false)
    }

    @TestCase
    public func preservesIndexedExpansionAndLifecycleGates(): Unit {
        let indexed = floatRgbState(0.21268, 0.71514, colorType: Indexed)
        @Assert(indexed.rgbToGrayEnabled(), true)
        @Assert(indexed.expandEnabled(), true)

        let beforeIhdr = PngReadTransformState()
        @Assert(beforeIhdr.setRgbToGray(Convert, 0.21268, 0.71514), false)
        @Assert(beforeIhdr.lastApplicationError().toString(), "INVALID_BEFORE_IHDR")

        let afterInitialization = PngReadTransformState()
        afterInitialization.markIhdrRead(Truecolor)
        afterInitialization.markRowInitialized()
        @Assert(afterInitialization.setRgbToGray(Convert, 0.21268, 0.71514), false)
        @Assert(
            afterInitialization.lastApplicationError().toString(),
            "INVALID_AFTER_ROW_INITIALIZATION"
        )
    }

    @TestCase
    public func rejectsNonFiniteAndFixedPointOverflowBeforeMutation(): Unit {
        let values: Array<Float64> = [Float64.NaN, Float64.Inf, -Float64.Inf, 30000.0]
        for (value in values) {
            let state = PngReadTransformState()
            state.markIhdrRead(Truecolor)
            try {
                state.setRgbToGray(Convert, value, 0.0)
                @Fail("invalid floating RGB-to-gray coefficient should fail")
            } catch (error: PngFormatException) {
                @Assert(error.kind.toString(), "INVALID_ARGUMENT")
                @Assert(state.rgbToGrayEnabled(), false)
            }
        }
    }

    @TestCase
    public func failedSecondCoefficientConversionPreservesPriorState(): Unit {
        let state = PngReadTransformState()
        state.markIhdrRead(Truecolor)
        @Assert(state.setRgbToGrayFixed(RequireGray, Int64(100000), Int64(0)), true)
        let before = state.rgbToGrayTransform()

        try {
            state.setRgbToGray(Convert, 0.21268, Float64.NaN)
            @Fail("invalid green coefficient should fail")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
        }

        let after = state.rgbToGrayTransform()
        @Assert(after.policy.toString(), before.policy.toString())
        @Assert(after.redCoefficient, before.redCoefficient)
        @Assert(after.greenCoefficient, before.greenCoefficient)
        @Assert(after.blueCoefficient, before.blueCoefficient)
    }
}
