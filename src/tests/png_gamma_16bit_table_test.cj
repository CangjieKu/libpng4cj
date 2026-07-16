package libpng4cj.tests

import libpng4cj.*
import std.math.floor
import std.math.pow

private func gamma16SegmentOracle(
    segment: Int64,
    high: Int64,
    shift: UInt8,
    gammaValue: Int32
): UInt16 {
    let shift32 = UInt32(shift)
    let compressedMax = (UInt32(1) << (UInt32(16) - shift32)) - UInt32(1)
    let compressedInput =
        (UInt32(high) << (UInt32(8) - shift32)) + UInt32(segment)
    UInt16(floor(
        65535.0 * pow(
            Float64(compressedInput) / Float64(compressedMax),
            Float64(gammaValue) * 0.00001
        ) + 0.5
    ))
}

@Test
public class PngGamma16BitTableTestSuite {
    @TestCase
    public func preservesEndpointsAndRepresentativeScalarOracles(): Unit {
        @Assert(pngGamma16BitCorrect(UInt16(0), Int32(220000)), UInt16(0))
        @Assert(
            pngGamma16BitCorrect(UInt16(65535), Int32(220000)),
            UInt16(65535)
        )
        @Assert(
            pngGamma16BitCorrect(UInt16(16384), Int32(220000)),
            UInt16(3104)
        )
        @Assert(
            pngGamma16BitCorrect(UInt16(32768), Int32(220000)),
            UInt16(14263)
        )
        @Assert(
            pngGamma16BitCorrect(UInt16(49152), Int32(220000)),
            UInt16(34803)
        )
        @Assert(
            pngGamma16BitCorrect(UInt16(32768), Int32(45455)),
            UInt16(47824)
        )
    }

    @TestCase
    public func exhaustivelyMatchesShiftZeroScalarDomain(): Unit {
        let gamma = Int32(220000)
        let table = pngBuildGamma16BitTable(UInt8(0), gamma)
        @Assert(table.segmentCount(), Int64(256))
        @Assert(table.segmentSize(), Int64(256))
        var sample: Int64 = 0
        while (sample < Int64(65536)) {
            @Assert(
                table.value(UInt16(sample)),
                pngGamma16BitCorrect(UInt16(sample), gamma)
            )
            sample += 1
        }
    }

    @TestCase
    public func exhaustivelyMatchesShiftFourSegmentFormula(): Unit {
        let gamma = Int32(45455)
        let shift = UInt8(4)
        let table = pngBuildGamma16BitTable(shift, gamma)
        @Assert(table.segmentCount(), Int64(16))
        var segment: Int64 = 0
        while (segment < table.segmentCount()) {
            let values = table.segment(segment)
            var high: Int64 = 0
            while (high < table.segmentSize()) {
                @Assert(
                    values[high],
                    gamma16SegmentOracle(segment, high, shift, gamma)
                )
                high += 1
            }
            segment += 1
        }
    }

    @TestCase
    public func buildsExactIdentityTablesAcrossShiftDomain(): Unit {
        let shifts: Array<UInt8> = [UInt8(0), UInt8(4), UInt8(8)]
        for (shift in shifts) {
            let table = pngBuildGamma16BitTable(shift, PNG_FP_1)
            var sample: Int64 = 0
            while (sample < Int64(65536)) {
                let compressed = UInt32(sample) >> UInt32(shift)
                let max = (UInt32(1) << (UInt32(16) - UInt32(shift))) -
                    UInt32(1)
                let expected = if (shift == UInt8(0)) {
                    UInt16(sample)
                } else {
                    UInt16(
                        (UInt64(compressed) * UInt64(65535) +
                        UInt64(UInt32(1) <<
                            (UInt32(15) - UInt32(shift)))) / UInt64(max)
                    )
                }
                @Assert(table.value(UInt16(sample)), expected)
                sample += 1
            }
        }
    }

    @TestCase
    public func keepsSegmentedLookupMonotonicCopyOwnedAndBounded(): Unit {
        let table = pngBuildGamma16BitTable(UInt8(8), Int32(220000))
        @Assert(table.segmentCount(), Int64(1))
        var sample: Int64 = 1
        var previous = table.value(UInt16(0))
        while (sample < Int64(65536)) {
            let current = table.value(UInt16(sample))
            @Assert(current >= previous, true)
            previous = current
            sample += 1
        }

        let mutable = table.segment(0)
        mutable[128] = UInt16(0)
        @Assert(table.value(UInt16(0x8080)) == UInt16(0), false)

        var caught = false
        try {
            pngBuildGamma16BitTable(UInt8(9), PNG_FP_1)
        } catch (error: PngFormatException) {
            caught = error.kind == InvalidArgument
        }
        @Assert(caught, true)
    }
}
