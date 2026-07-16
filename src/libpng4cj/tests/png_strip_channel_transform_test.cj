package libpng4cj.tests

import libpng4cj.*

private func assertStripChannelInfo(
    actual: PngReadRowInfo,
    expectedType: String,
    expectedChannels: UInt8,
    expectedRowBytes: UInt64
): Unit {
    @Assert(actual.colorType.toString(), expectedType)
    @Assert(actual.channels, expectedChannels)
    @Assert(actual.pixelDepth, UInt16(actual.bitDepth) * UInt16(expectedChannels))
    @Assert(actual.rowBytes, expectedRowBytes)
}

@Test
public class PngStripChannelTransformTestSuite {
    @TestCase
    public func stripsEightBitTwoChannelRowsAtEitherEdge(): Unit {
        let gaInfo = PngReadRowInfo(UInt32(2), UInt8(8), GrayscaleAlpha)
        let tail = pngDoStripChannel(gaInfo, [10, 20, 30, 40], false)
        let tailExpected: Array<Byte> = [10, 30]
        @Assert(tail.row(), tailExpected)
        assertStripChannelInfo(tail.info, "GRAYSCALE", UInt8(1), UInt64(2))

        let head = pngDoStripChannel(gaInfo, [10, 20, 30, 40], true)
        let headExpected: Array<Byte> = [20, 40]
        @Assert(head.row(), headExpected)
        assertStripChannelInfo(head.info, "GRAYSCALE", UInt8(1), UInt64(2))
    }

    @TestCase
    public func stripsEightBitFourChannelRowsAtEitherEdge(): Unit {
        let rgbaInfo = PngReadRowInfo(UInt32(2), UInt8(8), TruecolorAlpha)
        let tail = pngDoStripChannel(
            rgbaInfo,
            [1, 2, 3, 4, 5, 6, 7, 8],
            false
        )
        let tailExpected: Array<Byte> = [1, 2, 3, 5, 6, 7]
        @Assert(tail.row(), tailExpected)
        assertStripChannelInfo(tail.info, "TRUECOLOR", UInt8(3), UInt64(6))

        let head = pngDoStripChannel(
            rgbaInfo,
            [1, 2, 3, 4, 5, 6, 7, 8],
            true
        )
        let headExpected: Array<Byte> = [2, 3, 4, 6, 7, 8]
        @Assert(head.row(), headExpected)
        assertStripChannelInfo(head.info, "TRUECOLOR", UInt8(3), UInt64(6))
    }

    @TestCase
    public func stripsSixteenBitChannelsWithoutChangingNetworkOrder(): Unit {
        let gaInfo = PngReadRowInfo(UInt32(2), UInt8(16), GrayscaleAlpha)
        let ga = pngDoStripChannel(
            gaInfo,
            [0x12, 0x34, 0xab, 0xcd, 0x56, 0x78, 0xef, 0x01],
            false
        )
        let gaExpected: Array<Byte> = [0x12, 0x34, 0x56, 0x78]
        @Assert(ga.row(), gaExpected)
        assertStripChannelInfo(ga.info, "GRAYSCALE", UInt8(1), UInt64(4))

        let rgbaInfo = PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha)
        let rgba = pngDoStripChannel(
            rgbaInfo,
            [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08],
            true
        )
        let rgbaExpected: Array<Byte> = [
            0x03, 0x04, 0x05, 0x06, 0x07, 0x08
        ]
        @Assert(rgba.row(), rgbaExpected)
        assertStripChannelInfo(rgba.info, "TRUECOLOR", UInt8(3), UInt64(6))
    }

    @TestCase
    public func preservesFillerShapedColorTypes(): Unit {
        let grayFillerInfo = PngReadRowInfo(
            UInt32(2), UInt8(8), Grayscale, UInt8(2)
        )
        let gray = pngDoStripChannel(grayFillerInfo, [1, 2, 3, 4], false)
        let grayExpected: Array<Byte> = [1, 3]
        @Assert(gray.row(), grayExpected)
        assertStripChannelInfo(gray.info, "GRAYSCALE", UInt8(1), UInt64(2))

        let rgbFillerInfo = PngReadRowInfo(
            UInt32(1), UInt8(8), Truecolor, UInt8(4)
        )
        let rgb = pngDoStripChannel(rgbFillerInfo, [1, 2, 3, 4], true)
        let rgbExpected: Array<Byte> = [2, 3, 4]
        @Assert(rgb.row(), rgbExpected)
        assertStripChannelInfo(rgb.info, "TRUECOLOR", UInt8(3), UInt64(3))
    }

    @TestCase
    public func keepsUnsupportedRowsOwnedAndRejectsMalformedInput(): Unit {
        let input: Array<Byte> = [1, 2, 3]
        let rgbInfo = PngReadRowInfo(UInt32(1), UInt8(8), Truecolor)
        let unchanged = pngDoStripChannel(rgbInfo, input, false)
        let expected: Array<Byte> = [1, 2, 3]
        @Assert(unchanged.row(), expected)
        input[0] = UInt8(9)
        @Assert(unchanged.row(), expected)

        let packedInfo = PngReadRowInfo(
            UInt32(2), UInt8(4), Grayscale, UInt8(2)
        )
        let packed = pngDoStripChannel(packedInfo, [0x12, 0x34], false)
        let packedExpected: Array<Byte> = [0x12, 0x34]
        @Assert(packed.row(), packedExpected)

        try {
            pngDoStripChannel(
                PngReadRowInfo(UInt32(2), UInt8(8), TruecolorAlpha),
                [1, 2, 3, 4, 5, 6, 7],
                false
            )
            @Fail("strip channel should reject a row length mismatch")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }
    }
}
