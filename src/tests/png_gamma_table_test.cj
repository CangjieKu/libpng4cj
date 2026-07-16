package libpng4cj.tests

import libpng4cj.*

@Test
public class PngGammaTableTestSuite {
    @TestCase
    public func preservesEndpointsAndFrozenRepresentativeValues(): Unit {
        @Assert(pngGamma8BitCorrect(UInt8(0), Int32(220000)), UInt8(0))
        @Assert(pngGamma8BitCorrect(UInt8(255), Int32(220000)), UInt8(255))
        @Assert(pngGamma8BitCorrect(UInt8(16), Int32(220000)), UInt8(1))
        @Assert(pngGamma8BitCorrect(UInt8(64), Int32(220000)), UInt8(12))
        @Assert(pngGamma8BitCorrect(UInt8(128), Int32(220000)), UInt8(56))
        @Assert(pngGamma8BitCorrect(UInt8(192), Int32(220000)), UInt8(137))
        @Assert(pngGamma8BitCorrect(UInt8(254), Int32(220000)), UInt8(253))

        @Assert(pngGamma8BitCorrect(UInt8(1), Int32(45455)), UInt8(21))
        @Assert(pngGamma8BitCorrect(UInt8(64), Int32(45455)), UInt8(136))
        @Assert(pngGamma8BitCorrect(UInt8(128), Int32(45455)), UInt8(186))
        @Assert(pngGamma8BitCorrect(UInt8(192), Int32(45455)), UInt8(224))
    }

    @TestCase
    public func buildsExactIdentityTableInsideThreshold(): Unit {
        let gammaValues: Array<Int32> = [Int32(95000), PNG_FP_1, Int32(105000)]
        for (gamma in gammaValues) {
            let table = pngBuildGamma8BitTable(gamma)
            @Assert(table.size(), Int64(256))
            var index: Int64 = 0
            while (index < table.size()) {
                @Assert(table.value(UInt8(index)), UInt8(index))
                index += 1
            }
        }
    }

    @TestCase
    public func matchesScalarCorrectionForEverySignificantEntry(): Unit {
        let gamma = Int32(220000)
        let table = pngBuildGamma8BitTable(gamma)
        var index: Int64 = 0
        while (index < table.size()) {
            @Assert(
                table.value(UInt8(index)),
                pngGamma8BitCorrect(UInt8(index), gamma)
            )
            index += 1
        }
    }

    @TestCase
    public func keepsSignificantTableMonotonicAndCopyOwned(): Unit {
        let table = pngBuildGamma8BitTable(Int32(45455))
        var index: Int64 = 1
        var previous = table.value(UInt8(0))
        while (index < table.size()) {
            let current = table.value(UInt8(index))
            @Assert(current >= previous, true)
            previous = current
            index += 1
        }

        let mutable = table.values()
        mutable[128] = UInt8(0)
        @Assert(table.value(UInt8(128)), UInt8(186))
    }
}
