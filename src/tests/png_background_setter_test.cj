package libpng4cj.tests

import libpng4cj.*

private func assertBackground(
    actual: PngBackground,
    expected: PngBackground
): Unit {
    @Assert(actual.index, expected.index)
    @Assert(actual.gray, expected.gray)
    @Assert(actual.red, expected.red)
    @Assert(actual.green, expected.green)
    @Assert(actual.blue, expected.blue)
}

@Test
public class PngBackgroundSetterTestSuite {
    @TestCase
    public func preservesFrozenGammaCodeIdentities(): Unit {
        @Assert(BackgroundGammaUnknown.ordinalValue(), Int64(0))
        @Assert(BackgroundGammaScreen.ordinalValue(), Int64(1))
        @Assert(BackgroundGammaFile.ordinalValue(), Int64(2))
        @Assert(BackgroundGammaUnique.ordinalValue(), Int64(3))
        @Assert(BackgroundGammaUnknown.toString(), "UNKNOWN")
        @Assert(BackgroundGammaScreen.toString(), "SCREEN")
        @Assert(BackgroundGammaFile.toString(), "FILE")
        @Assert(BackgroundGammaUnique.toString(), "UNIQUE")
    }

    @TestCase
    public func storesFixedBackgroundAndSelectsFrozenFlags(): Unit {
        let state = PngReadTransformState()
        let background = PngBackground(
            UInt8(7),
            UInt16(0x1111),
            UInt16(0x2222),
            UInt16(0x3333),
            UInt16(0x4444)
        )
        @Assert(
            state.setBackgroundFixed(
                background,
                BackgroundGammaFile,
                true,
                Int32(45455)
            ),
            true
        )
        @Assert(state.backgroundConfigured(), true)
        assertBackground(state.background(), background)
        @Assert(state.backgroundGammaCode(), BackgroundGammaFile)
        @Assert(state.backgroundGamma(), Int32(45455))
        @Assert(state.composeEnabled(), true)
        @Assert(state.stripAlphaEnabled(), true)
        @Assert(state.backgroundExpandEnabled(), true)
        @Assert(state.encodeAlphaEnabled(), false)
        @Assert(state.optimizeAlphaEnabled(), false)
        @Assert(state.backgroundGammaUnknownWarning(), false)
        @Assert(state.detectsUninitializedTransforms(), true)
    }

    @TestCase
    public func rejectsUnknownGammaWithoutReplacingPriorState(): Unit {
        let state = PngReadTransformState()
        let original = PngBackground(
            UInt8(1), UInt16(2), UInt16(3), UInt16(4), UInt16(5)
        )
        @Assert(
            state.setBackgroundFixed(
                original,
                BackgroundGammaScreen,
                false,
                Int32(100000)
            ),
            true
        )
        let replacement = PngBackground(
            UInt8(9), UInt16(8), UInt16(7), UInt16(6), UInt16(5)
        )
        @Assert(
            state.setBackgroundFixed(
                replacement,
                BackgroundGammaUnknown,
                true,
                Int32(220000)
            ),
            false
        )
        assertBackground(state.background(), original)
        @Assert(state.backgroundGammaCode(), BackgroundGammaScreen)
        @Assert(state.backgroundGamma(), Int32(100000))
        @Assert(state.backgroundExpandEnabled(), false)
        @Assert(state.backgroundGammaUnknownWarning(), true)

        @Assert(
            state.setBackgroundFixed(
                replacement,
                BackgroundGammaUnique,
                Int64(-1),
                Int32(-3)
            ),
            true
        )
        assertBackground(state.background(), replacement)
        @Assert(state.backgroundGammaCode(), BackgroundGammaUnique)
        @Assert(state.backgroundGamma(), Int32(-3))
        @Assert(state.backgroundExpandEnabled(), true)
        @Assert(state.backgroundGammaUnknownWarning(), false)
    }

    @TestCase
    public func convertsFloatingGammaBeforeFixedSetter(): Unit {
        let state = PngReadTransformState()
        let background = PngBackground(
            UInt8(0), UInt16(1), UInt16(2), UInt16(3), UInt16(4)
        )
        @Assert(
            state.setBackground(
                background,
                BackgroundGammaUnique,
                Int64(0),
                0.45455
            ),
            true
        )
        @Assert(state.backgroundGamma(), Int32(45455))
        @Assert(state.backgroundExpandEnabled(), false)

        @Assert(
            state.setBackground(
                background,
                BackgroundGammaScreen,
                true,
                -0.000005
            ),
            true
        )
        @Assert(state.backgroundGamma(), Int32(0))
    }

    @TestCase
    public func preservesStateAcrossFloatingAndLifecycleFailures(): Unit {
        let state = PngReadTransformState()
        let original = PngBackground(
            UInt8(1), UInt16(2), UInt16(3), UInt16(4), UInt16(5)
        )
        @Assert(
            state.setBackgroundFixed(
                original,
                BackgroundGammaFile,
                false,
                Int32(45455)
            ),
            true
        )
        let invalidValues: Array<Float64> = [
            Float64.NaN,
            Float64.Inf,
            -Float64.Inf,
            30000.0
        ]
        for (value in invalidValues) {
            try {
                state.setBackground(
                    PngBackground(),
                    BackgroundGammaUnique,
                    true,
                    value
                )
                @Fail("invalid floating background gamma should fail")
            } catch (error: PngFormatException) {
                @Assert(error.kind.toString(), "INVALID_ARGUMENT")
            }
            assertBackground(state.background(), original)
            @Assert(state.backgroundGammaCode(), BackgroundGammaFile)
            @Assert(state.backgroundGamma(), Int32(45455))
        }

        state.markRowInitialized()
        @Assert(
            state.setBackgroundFixed(
                PngBackground(),
                BackgroundGammaScreen,
                true,
                Int32(100000)
            ),
            false
        )
        @Assert(
            state.lastApplicationError(),
            InvalidAfterRowInitialization
        )
        assertBackground(state.background(), original)
        @Assert(state.backgroundGammaUnknownWarning(), false)
    }

    @TestCase
    public func rejectsReadsBeforeBackgroundConfiguration(): Unit {
        let state = PngReadTransformState()
        try {
            state.background()
            @Fail("background getter should require configuration")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "UNSUPPORTED_TRANSFORM")
        }
        try {
            state.backgroundGammaCode()
            @Fail("background gamma code should require configuration")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "UNSUPPORTED_TRANSFORM")
        }
        try {
            state.backgroundGamma()
            @Fail("background gamma should require configuration")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "UNSUPPORTED_TRANSFORM")
        }
    }
}
