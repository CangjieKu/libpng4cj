package libpng4cj.tests

import libpng4cj.*

private func expectedPackSwapByte(value: UInt8, bitDepth: UInt8): UInt8 {
    let depth = UInt32(bitDepth)
    let groupCount = UInt32(8) / depth
    let mask = (UInt32(1) << depth) - UInt32(1)
    let source = UInt32(value)
    var output: UInt32 = UInt32(0)
    var group: UInt32 = UInt32(0)
    while (group < groupCount) {
        let sample = (source >> (group * depth)) & mask
        output |= sample << ((groupCount - UInt32(1) - group) * depth)
        group += 1
    }
    UInt8(output)
}

@Test
public class PngPackSwapTransformTestSuite {
    @TestCase
    public func exhaustivelyMatchesAllFrozenLookupTableEntries(): Unit {
        let depths: Array<UInt8> = [1, 2, 4]
        var depthIndex: Int64 = 0
        while (depthIndex < depths.size) {
            let depth = depths[depthIndex]
            let width = UInt32(UInt8(8) / depth)
            var value: UInt32 = UInt32(0)
            while (value < UInt32(256)) {
                let actual = pngDoPackSwap(
                    PngReadRowInfo(width, depth, Grayscale),
                    [UInt8(value)]
                )
                @Assert(
                    actual.row()[0],
                    expectedPackSwapByte(UInt8(value), depth)
                )
                value += 1
            }
            depthIndex += 1
        }
    }

    @TestCase
    public func reversesOneTwoAndFourBitGroupsPerStoredByte(): Unit {
        let one = pngDoPackSwap(
            PngReadRowInfo(UInt32(16), UInt8(1), Grayscale),
            [0xb2, 0x41]
        )
        let oneExpected: Array<Byte> = [0x4d, 0x82]
        @Assert(one.row(), oneExpected)
        @Assert(one.info.bitDepth, UInt8(1))
        @Assert(one.info.rowBytes, UInt64(2))

        let two = pngDoPackSwap(
            PngReadRowInfo(UInt32(8), UInt8(2), Indexed),
            [0x1b, 0x6c]
        )
        let twoExpected: Array<Byte> = [0xe4, 0x39]
        @Assert(two.row(), twoExpected)
        @Assert(two.info.colorType.toString(), "INDEXED")
        @Assert(two.info.rowBytes, UInt64(2))

        let four = pngDoPackSwap(
            PngReadRowInfo(UInt32(4), UInt8(4), Grayscale),
            [0xa5, 0xf0]
        )
        let fourExpected: Array<Byte> = [0x5a, 0x0f]
        @Assert(four.row(), fourExpected)
        @Assert(four.info.pixelDepth, UInt16(4))
        @Assert(four.info.rowBytes, UInt64(2))
    }

    @TestCase
    public func transformsCompleteFinalBytesIncludingPaddingBits(): Unit {
        let partialTwo = pngDoPackSwap(
            PngReadRowInfo(UInt32(3), UInt8(2), Grayscale),
            [0x1b]
        )
        let partialTwoExpected: Array<Byte> = [0xe4]
        @Assert(partialTwo.row(), partialTwoExpected)

        let partialFour = pngDoPackSwap(
            PngReadRowInfo(UInt32(1), UInt8(4), Indexed),
            [0xa5]
        )
        let partialFourExpected: Array<Byte> = [0x5a]
        @Assert(partialFour.row(), partialFourExpected)
    }

    @TestCase
    public func preservesOwnedNoOpsAndMalformedPriority(): Unit {
        let byteSource: Array<Byte> = [0x12, 0x34]
        let byteRow = pngDoPackSwap(
            PngReadRowInfo(UInt32(2), UInt8(8), Grayscale),
            byteSource
        )
        byteSource[0] = UInt8(0xff)
        let byteExpected: Array<Byte> = [0x12, 0x34]
        @Assert(byteRow.row(), byteExpected)

        let unsupportedSource: Array<Byte> = [0x5a]
        let unsupported = pngDoPackSwap(
            PngReadRowInfo(UInt32(2), UInt8(3), Grayscale),
            unsupportedSource
        )
        unsupportedSource[0] = UInt8(0)
        let unsupportedExpected: Array<Byte> = [0x5a]
        @Assert(unsupported.row(), unsupportedExpected)

        try {
            pngDoPackSwap(
                PngReadRowInfo(UInt32(2), UInt8(8), Grayscale),
                [0x7f]
            )
            @Fail("unsupported PackSwap rows should validate length first")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
            @Assert(
                error.message,
                "PNG transform row length does not match row info"
            )
        }
    }
}
