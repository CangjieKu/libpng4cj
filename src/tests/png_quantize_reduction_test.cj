package libpng4cj.tests

import libpng4cj.*

private func reductionPalette(): Array<Byte> {
    [
        0, 0, 0,
        0xff, 0, 0,
        0, 0xff, 0,
        0, 0, 0xff
    ]
}

private func reductionHistogram(): Array<UInt16> {
    [10, 20, 100, 90]
}

private func reductionCell(red: Int64, green: Int64, blue: Int64): Int64 {
    (red << 10) | (green << 5) | blue
}

@Test
public class PngQuantizeReductionTestSuite {
    @TestCase
    public func reducesFullPaletteByFrozenHistogramSelection(): Unit {
        let state = PngReadTransformState()
        @Assert(
            state.setQuantize(
                reductionPalette(),
                4,
                2,
                reductionHistogram(),
                true
            ),
            true
        )

        let expected: Array<Byte> = [0, 0, 0xff, 0, 0xff, 0]
        @Assert(state.quantizePalette(), expected)
        @Assert(state.quantizePaletteCount(), Int64(2))
        @Assert(state.quantizeMaximumColors(), Int64(2))
        @Assert(state.quantizePaletteLookup().size, Int64(32768))
        @Assert(
            state.quantizePaletteLookup()[reductionCell(0, 0, 31)],
            UInt8(0)
        )
        @Assert(
            state.quantizePaletteLookup()[reductionCell(0, 31, 0)],
            UInt8(1)
        )
    }

    @TestCase
    public func reducesNonFullPaletteAndBuildsExactRemap(): Unit {
        let state = PngReadTransformState()
        @Assert(
            state.setQuantize(
                reductionPalette(),
                4,
                2,
                reductionHistogram(),
                false
            ),
            true
        )

        let expectedPalette: Array<Byte> = [0, 0, 0xff, 0, 0xff, 0]
        @Assert(state.quantizePalette(), expectedPalette)
        let index = state.quantizeIndex()
        @Assert(index.size, Int64(256))
        @Assert(index[0], UInt8(0))
        @Assert(index[1], UInt8(0))
        @Assert(index[2], UInt8(1))
        @Assert(index[3], UInt8(0))
        @Assert(index[255], UInt8(255))
        @Assert(state.quantizePaletteLookup().size, Int64(0))
    }

    @TestCase
    public func preservesEqualFrequencyOrderAndFirstClosestTie(): Unit {
        let palette: Array<Byte> = [0, 0, 0, 0xff, 0, 0, 0, 0, 0xff]
        let histogram: Array<UInt16> = [5, 5, 5]
        let state = PngReadTransformState()
        @Assert(state.setQuantize(palette, 3, 2, histogram, false), true)

        let retained: Array<Byte> = [0, 0, 0, 0xff, 0, 0]
        @Assert(state.quantizePalette(), retained)
        @Assert(state.quantizeIndex()[0], UInt8(0))
        @Assert(state.quantizeIndex()[1], UInt8(1))
        @Assert(state.quantizeIndex()[2], UInt8(0))
    }

    @TestCase
    public func preservesCallerPaletteAndHistogramOwnership(): Unit {
        let palette = reductionPalette()
        let histogram = reductionHistogram()
        let state = PngReadTransformState()
        @Assert(state.setQuantize(palette, 4, 2, histogram, false), true)

        let expectedPalette = reductionPalette()
        let expectedHistogram = reductionHistogram()
        @Assert(palette, expectedPalette)
        @Assert(histogram, expectedHistogram)

        let retained = state.quantizePalette()
        retained[0] = UInt8(99)
        let expectedRetained: Array<Byte> = [0, 0, 0xff, 0, 0xff, 0]
        @Assert(state.quantizePalette(), expectedRetained)
    }

    @TestCase
    public func acceptsAbsentAndRejectsMalformedReductionHistograms(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setQuantize(reductionPalette(), 4, 2, false), true)
        @Assert(state.quantizeEnabled(), true)

        let malformedState = PngReadTransformState()
        let shortHistogram: Array<UInt16> = [1, 2, 3]
        try {
            malformedState.setQuantize(
                reductionPalette(),
                4,
                2,
                shortHistogram,
                false
            )
            @Fail("quantize should reject a short histogram")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
        }
        @Assert(malformedState.quantizeEnabled(), false)
    }

    @TestCase
    public func failedLifecycleKeepsPreviousReductionState(): Unit {
        let state = PngReadTransformState()
        @Assert(
            state.setQuantize(
                reductionPalette(),
                4,
                2,
                reductionHistogram(),
                false
            ),
            true
        )
        state.markRowInitialized()

        @Assert(
            state.setQuantize(
                reductionPalette(),
                4,
                2,
                reductionHistogram(),
                true
            ),
            false
        )
        @Assert(state.quantizeMode().toString(), "PALETTE_REMAP")
        let expected: Array<Byte> = [0, 0, 0xff, 0, 0xff, 0]
        @Assert(state.quantizePalette(), expected)
        @Assert(state.quantizeIndex()[2], UInt8(1))
    }
}
