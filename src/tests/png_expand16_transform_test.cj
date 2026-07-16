package libpng4cj.tests

import libpng4cj.*

private func assertExpand16Info(
    actual: PngReadRowInfo,
    source: PngReadRowInfo
): Unit {
    @Assert(actual.width, source.width)
    @Assert(actual.bitDepth, UInt8(16))
    @Assert(actual.colorType.toString(), source.colorType.toString())
    @Assert(actual.channels, source.channels)
    @Assert(actual.pixelDepth, UInt16(16) * UInt16(source.channels))
    @Assert(actual.rowBytes, source.rowBytes * UInt64(2))
}

@Test
public class PngExpand16TransformTestSuite {
    @TestCase
    public func replicatesGrayBytesInReverseGrowthOrder(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(4), UInt8(8), Grayscale)
        let input: Array<Byte> = [0x00, 0x01, 0x7f, 0xff]
        let expanded = pngDoExpand16(rowInfo, input)
        let expected: Array<Byte> = [
            0x00, 0x00,
            0x01, 0x01,
            0x7f, 0x7f,
            0xff, 0xff
        ]
        @Assert(expanded.row(), expected)
        assertExpand16Info(expanded.info, rowInfo)

        input[0] = UInt8(9)
        @Assert(expanded.row(), expected)
        let mutable = expanded.row()
        mutable[0] = UInt8(9)
        @Assert(expanded.row(), expected)
    }

    @TestCase
    public func expandsStandardRuntimeChannelTopologies(): Unit {
        let gaInfo = PngReadRowInfo(UInt32(1), UInt8(8), GrayscaleAlpha)
        let ga = pngDoExpand16(gaInfo, [0x12, 0x34])
        let gaExpected: Array<Byte> = [0x12, 0x12, 0x34, 0x34]
        @Assert(ga.row(), gaExpected)
        assertExpand16Info(ga.info, gaInfo)

        let rgbInfo = PngReadRowInfo(UInt32(1), UInt8(8), Truecolor)
        let rgb = pngDoExpand16(rgbInfo, [1, 2, 3])
        let rgbExpected: Array<Byte> = [1, 1, 2, 2, 3, 3]
        @Assert(rgb.row(), rgbExpected)
        assertExpand16Info(rgb.info, rgbInfo)

        let rgbaInfo = PngReadRowInfo(UInt32(1), UInt8(8), TruecolorAlpha)
        let rgba = pngDoExpand16(rgbaInfo, [1, 2, 3, 4])
        let rgbaExpected: Array<Byte> = [1, 1, 2, 2, 3, 3, 4, 4]
        @Assert(rgba.row(), rgbaExpected)
        assertExpand16Info(rgba.info, rgbaInfo)
    }

    @TestCase
    public func preservesExplicitRuntimeChannelsIndependentOfColorType(): Unit {
        let rowInfo = PngReadRowInfo(
            UInt32(1), UInt8(8), Truecolor, UInt8(4)
        )
        let expanded = pngDoExpand16(rowInfo, [5, 6, 7, 8])
        let expected: Array<Byte> = [5, 5, 6, 6, 7, 7, 8, 8]
        @Assert(expanded.row(), expected)
        @Assert(expanded.info.colorType.toString(), "TRUECOLOR")
        @Assert(expanded.info.channels, UInt8(4))
        assertExpand16Info(expanded.info, rowInfo)
    }

    @TestCase
    public func keepsUnsupportedRowsOwnedAndRejectsMalformedInput(): Unit {
        let indexedInput: Array<Byte> = [1, 2]
        let indexedInfo = PngReadRowInfo(UInt32(2), UInt8(8), Indexed)
        let indexed = pngDoExpand16(indexedInfo, indexedInput)
        let indexedExpected: Array<Byte> = [1, 2]
        @Assert(indexed.row(), indexedExpected)

        let sixteenInfo = PngReadRowInfo(UInt32(1), UInt8(16), Grayscale)
        let sixteen = pngDoExpand16(sixteenInfo, [0x12, 0x34])
        let sixteenExpected: Array<Byte> = [0x12, 0x34]
        @Assert(sixteen.row(), sixteenExpected)

        let zeroChannelsInfo = PngReadRowInfo(
            UInt32(2), UInt8(8), Grayscale, UInt8(0)
        )
        let zeroChannels = pngDoExpand16(zeroChannelsInfo, [])
        let zeroChannelsExpected: Array<Byte> = []
        @Assert(zeroChannels.row(), zeroChannelsExpected)

        let emptyInfo = PngReadRowInfo(UInt32(0), UInt8(8), Grayscale)
        let empty = pngDoExpand16(emptyInfo, [])
        let emptyExpected: Array<Byte> = []
        @Assert(empty.row(), emptyExpected)

        indexedInput[0] = UInt8(9)
        @Assert(indexed.row(), indexedExpected)
        let mutable = sixteen.row()
        mutable[0] = UInt8(0)
        @Assert(sixteen.row(), sixteenExpected)

        try {
            pngDoExpand16(
                PngReadRowInfo(UInt32(2), UInt8(8), Truecolor),
                [1, 2, 3, 4, 5]
            )
            @Fail("Expand16 should reject a row length mismatch")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }
    }
}
