package libpng4cj.tests

import libpng4cj.*

private func smallQuantizePalette(): Array<Byte> {
    [0, 0, 0, 0xff, 0x80, 0x40]
}

@Test
public class PngQuantizeStateTestSuite {
    @TestCase
    public func initializesCompleteNonFullIdentityRemap(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setQuantize(smallQuantizePalette(), 2, 2, false), true)
        @Assert(state.quantizeEnabled(), true)
        @Assert(state.quantizeMode().toString(), "PALETTE_REMAP")
        @Assert(state.quantizePaletteCount(), Int64(2))
        @Assert(state.quantizeMaximumColors(), Int64(2))

        let index = state.quantizeIndex()
        @Assert(index.size, Int64(256))
        @Assert(index[0], UInt8(0))
        @Assert(index[127], UInt8(127))
        @Assert(index[255], UInt8(255))
    }

    @TestCase
    public func ownsPaletteAndRemapResults(): Unit {
        let palette = smallQuantizePalette()
        let state = PngReadTransformState()
        @Assert(state.setQuantize(palette, 2, 2, false), true)

        palette[0] = UInt8(99)
        let expectedPalette: Array<Byte> = [0, 0, 0, 0xff, 0x80, 0x40]
        @Assert(state.quantizePalette(), expectedPalette)

        let index = state.quantizeIndex()
        index[255] = UInt8(0)
        @Assert(state.quantizeIndex()[255], UInt8(255))
    }

    @TestCase
    public func repeatedNonFullSetterRebuildsIdentityState(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setQuantize(smallQuantizePalette(), 2, 2, false), true)
        let first = state.quantizeIndex()
        first[1] = UInt8(0)

        let replacement: Array<Byte> = [1, 2, 3]
        @Assert(state.setQuantize(replacement, 1, 1, false), true)
        @Assert(state.quantizePalette(), replacement)
        @Assert(state.quantizePaletteCount(), Int64(1))
        @Assert(state.quantizeIndex()[1], UInt8(1))
    }

    @TestCase
    public func recordsFullModeWithoutFabricatingLookupState(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setQuantize(smallQuantizePalette(), 2, 2, false), true)
        @Assert(state.quantizeIndex().size, Int64(256))
        @Assert(state.setQuantize(smallQuantizePalette(), 2, 2, true), true)
        @Assert(state.quantizeMode().toString(), "FULL_COLOR")
        @Assert(state.quantizeIndex().size, Int64(0))
        @Assert(state.quantizePalette(), smallQuantizePalette())
    }

    @TestCase
    public func rejectsAfterRowInitializationWithoutMutation(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setQuantize(smallQuantizePalette(), 2, 2, false), true)
        state.markRowInitialized()

        let replacement: Array<Byte> = [1, 2, 3]
        @Assert(state.setQuantize(replacement, 1, 1, true), false)
        @Assert(
            state.lastApplicationError().toString(),
            "INVALID_AFTER_ROW_INITIALIZATION"
        )
        @Assert(state.quantizeMode().toString(), "PALETTE_REMAP")
        @Assert(state.quantizePalette(), smallQuantizePalette())
        @Assert(state.quantizeIndex()[255], UInt8(255))
    }

    @TestCase
    public func rejectsInvalidInputsAndAcceptsClosestPairReduction(): Unit {
        let state = PngReadTransformState()

        try {
            state.setQuantize([0, 0], 1, 1, false)
            @Fail("quantize should reject incomplete RGB entries")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
        }
        @Assert(state.quantizeEnabled(), false)

        @Assert(state.setQuantize(smallQuantizePalette(), 2, 1, false), true)
        @Assert(state.quantizeEnabled(), true)
        @Assert(state.quantizePaletteCount(), Int64(1))
        @Assert(state.quantizeIndex()[0], UInt8(0))
        @Assert(state.quantizeIndex()[1], UInt8(0))
    }
}
