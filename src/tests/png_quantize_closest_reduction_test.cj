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

    @TestCase
    public func retriesAfterDiscardingPartiallyBuiltDistanceBuckets(): Unit {
        let baseline = PngReadTransformState()
        @Assert(
            baseline.setQuantize(closestReductionPalette(), 4, 2, false),
            true
        )

        let recovered = PngReadTransformState()
        let fault = PngQuantizeAllocationFaultPlan(2, 1, 1)
        @Assert(
            recovered.setQuantize(
                closestReductionPalette(), 4, 2, false, fault
            ),
            true
        )
        @Assert(recovered.quantizePalette(), baseline.quantizePalette())
        @Assert(recovered.quantizeIndex(), baseline.quantizeIndex())
        @Assert(recovered.quantizeAllocationWarningCount(), Int64(1))
        @Assert(recovered.quantizeAllocationRetryCount(), Int64(1))
    }

    @TestCase
    public func rebuildsFullLookupAfterRecoverableAllocationWarning(): Unit {
        let baseline = PngReadTransformState()
        @Assert(
            baseline.setQuantize(closestReductionPalette(), 4, 2, true),
            true
        )

        let recovered = PngReadTransformState()
        @Assert(
            recovered.setQuantize(
                closestReductionPalette(),
                4,
                2,
                true,
                PngQuantizeAllocationFaultPlan(1, 1, 2)
            ),
            true
        )
        @Assert(recovered.quantizePalette(), baseline.quantizePalette())
        @Assert(
            recovered.quantizePaletteLookup(),
            baseline.quantizePaletteLookup()
        )
        @Assert(recovered.quantizeAllocationWarningCount(), Int64(1))
        @Assert(recovered.quantizeAllocationRetryCount(), Int64(1))
    }

    @TestCase
    public func saturatesDistanceBucketScanAfterRepeatedWarnings(): Unit {
        let baseline = PngReadTransformState()
        @Assert(
            baseline.setQuantize(closestReductionPalette(), 4, 2, false),
            true
        )

        let recovered = PngReadTransformState()
        @Assert(
            recovered.setQuantize(
                closestReductionPalette(),
                4,
                2,
                false,
                PngQuantizeAllocationFaultPlan(0, 8, 8)
            ),
            true
        )
        @Assert(recovered.quantizePalette(), baseline.quantizePalette())
        @Assert(recovered.quantizeIndex(), baseline.quantizeIndex())
        @Assert(recovered.quantizeAllocationWarningCount(), Int64(8))
        @Assert(recovered.quantizeAllocationRetryCount(), Int64(8))
    }

    @TestCase
    public func exhaustedRetriesKeepThePreviousQuantizeSnapshot(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setQuantize(closestReductionPalette(), 4, 2, false), true)
        let previousPalette = state.quantizePalette()
        let previousIndex = state.quantizeIndex()

        try {
            state.setQuantize(
                closestReductionPalette(),
                4,
                1,
                false,
                PngQuantizeAllocationFaultPlan(0, 2, 1)
            )
            @Fail("quantize should reject an exhausted allocation retry plan")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "ALLOCATION_FAILURE")
            @Assert(error.offset, Int64(2))
        }
        @Assert(state.quantizePalette(), previousPalette)
        @Assert(state.quantizeIndex(), previousIndex)
        @Assert(state.quantizeAllocationWarningCount(), Int64(0))
        @Assert(state.quantizeAllocationRetryCount(), Int64(0))
    }

    @TestCase
    public func successfulReplacementResetsAllocationWarningFacts(): Unit {
        let state = PngReadTransformState()
        @Assert(
            state.setQuantize(
                closestReductionPalette(),
                4,
                2,
                false,
                PngQuantizeAllocationFaultPlan(0, 1, 1)
            ),
            true
        )
        @Assert(state.quantizeAllocationWarningCount(), Int64(1))
        @Assert(state.quantizeAllocationRetryCount(), Int64(1))

        @Assert(state.setQuantize(closestReductionPalette(), 4, 2, false), true)
        @Assert(state.quantizeAllocationWarningCount(), Int64(0))
        @Assert(state.quantizeAllocationRetryCount(), Int64(0))
    }

    @TestCase
    public func rejectsInvalidAllocationFaultPlanArguments(): Unit {
        try {
            PngQuantizeAllocationFaultPlan(-1, 1, 1)
            @Fail("quantize allocation fault offset should be nonnegative")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
            @Assert(error.offset, Int64(-1))
        }
    }
}
