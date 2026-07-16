package libpng4cj.tests

import libpng4cj.*

private func closestReductionPalette(): Array<Byte> {
    [
        0, 0, 0,
        0xff, 0, 0,
        0, 0xff, 0,
        0, 0, 0xff
    ]
}

private func closestReductionCell(
    red: Int64,
    green: Int64,
    blue: Int64
): Int64 {
    (red << 10) | (green << 5) | blue
}

@Test
public class PngQuantizeClosestReductionTestSuite {
    @TestCase
    public func preservesReverseBucketOrderAndOddEvenElimination(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setQuantize(closestReductionPalette(), 4, 2, false), true)

        let expectedPalette: Array<Byte> = [0, 0xff, 0, 0xff, 0, 0]
        @Assert(state.quantizePalette(), expectedPalette)
        let index = state.quantizeIndex()
        @Assert(index[0], UInt8(0))
        @Assert(index[1], UInt8(1))
        @Assert(index[2], UInt8(0))
        @Assert(index[3], UInt8(0))
    }

    @TestCase
    public func buildsFullLookupFromClosestReducedPalette(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setQuantize(closestReductionPalette(), 4, 2, true), true)

        let expectedPalette: Array<Byte> = [0, 0xff, 0, 0xff, 0, 0]
        @Assert(state.quantizePalette(), expectedPalette)
        let lookup = state.quantizePaletteLookup()
        @Assert(
            lookup[closestReductionCell(0, 31, 0)],
            UInt8(0)
        )
        @Assert(
            lookup[closestReductionCell(31, 0, 0)],
            UInt8(1)
        )
    }

    @TestCase
    public func expandsDistanceWindowUntilAValidPairExists(): Unit {
        let palette: Array<Byte> = [0, 0, 0, 0xff, 0xff, 0xff]
        let state = PngReadTransformState()
        @Assert(state.setQuantize(palette, 2, 1, false), true)

        let expected: Array<Byte> = [0, 0, 0]
        @Assert(state.quantizePalette(), expected)
        @Assert(state.quantizeIndex()[0], UInt8(0))
        @Assert(state.quantizeIndex()[1], UInt8(0))
    }

    @TestCase
    public func skipsStalePairsAfterEarlierBucketEliminations(): Unit {
        let identical: Array<Byte> = [
            0x80, 0x80, 0x80,
            0x80, 0x80, 0x80,
            0x80, 0x80, 0x80,
            0x80, 0x80, 0x80
        ]
        let state = PngReadTransformState()
        @Assert(state.setQuantize(identical, 4, 2, false), true)

        let index = state.quantizeIndex()
        @Assert(index[0], UInt8(0))
        @Assert(index[1], UInt8(1))
        @Assert(index[2], UInt8(1))
        @Assert(index[3], UInt8(1))
    }

    @TestCase
    public func preservesCallerOwnershipAndFailedLifecycleState(): Unit {
        let palette = closestReductionPalette()
        let state = PngReadTransformState()
        @Assert(state.setQuantize(palette, 4, 2, false), true)
        @Assert(palette, closestReductionPalette())

        state.markRowInitialized()
        @Assert(state.setQuantize(palette, 4, 1, true), false)
        let expected: Array<Byte> = [0, 0xff, 0, 0xff, 0, 0]
        @Assert(state.quantizePalette(), expected)
        @Assert(state.quantizeMode().toString(), "PALETTE_REMAP")
    }
}
