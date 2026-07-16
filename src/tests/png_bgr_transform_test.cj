package libpng4cj.tests

import libpng4cj.*

@Test
public class PngBgrTransformTestSuite {
    @TestCase
    public func swapsEightBitRgbAndRgbaRows(): Unit {
        let rgbInfo = PngReadRowInfo(UInt32(2), UInt8(8), Truecolor)
        let rgb = pngDoBgr(rgbInfo, [1, 2, 3, 4, 5, 6])
        let rgbExpected: Array<Byte> = [3, 2, 1, 6, 5, 4]
        @Assert(rgb.row(), rgbExpected)
        @Assert(rgb.info.bitDepth, UInt8(8))
        @Assert(rgb.info.colorType.toString(), "TRUECOLOR")
        @Assert(rgb.info.channels, UInt8(3))
        @Assert(rgb.info.rowBytes, UInt64(6))

        let rgbaInfo = PngReadRowInfo(UInt32(2), UInt8(8), TruecolorAlpha)
        let rgba = pngDoBgr(rgbaInfo, [1, 2, 3, 4, 5, 6, 7, 8])
        let rgbaExpected: Array<Byte> = [3, 2, 1, 4, 7, 6, 5, 8]
        @Assert(rgba.row(), rgbaExpected)
        @Assert(rgba.info.colorType.toString(), "TRUECOLOR_ALPHA")
        @Assert(rgba.info.channels, UInt8(4))
        @Assert(rgba.info.rowBytes, UInt64(8))
    }

    @TestCase
    public func swapsSixteenBitNetworkOrderedComponents(): Unit {
        let rgb = pngDoBgr(
            PngReadRowInfo(UInt32(1), UInt8(16), Truecolor),
            [0x01, 0x02, 0x03, 0x04, 0x05, 0x06]
        )
        let rgbExpected: Array<Byte> = [0x05, 0x06, 0x03, 0x04, 0x01, 0x02]
        @Assert(rgb.row(), rgbExpected)

        let rgba = pngDoBgr(
            PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha),
            [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
        )
        let rgbaExpected: Array<Byte> = [
            0x05, 0x06, 0x03, 0x04, 0x01, 0x02, 0x07, 0x08
        ]
        @Assert(rgba.row(), rgbaExpected)
        @Assert(rgba.info.bitDepth, UInt8(16))
        @Assert(rgba.info.rowBytes, UInt64(8))
    }

    @TestCase
    public func preservesOwnedUnsupportedRowsAndMalformedPriority(): Unit {
        let graySource: Array<Byte> = [0x11, 0x22]
        let gray = pngDoBgr(
            PngReadRowInfo(UInt32(2), UInt8(8), Grayscale),
            graySource
        )
        graySource[0] = UInt8(0xff)
        let grayExpected: Array<Byte> = [0x11, 0x22]
        @Assert(gray.row(), grayExpected)

        let fillerSource: Array<Byte> = [1, 2, 3, 4]
        let filler = pngDoBgr(
            PngReadRowInfo(UInt32(1), UInt8(8), Truecolor, UInt8(4)),
            fillerSource
        )
        fillerSource[0] = UInt8(9)
        let fillerExpected: Array<Byte> = [1, 2, 3, 4]
        @Assert(filler.row(), fillerExpected)

        try {
            pngDoBgr(
                PngReadRowInfo(UInt32(2), UInt8(8), Grayscale),
                [1]
            )
            @Fail("unsupported BGR rows should validate malformed length first")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
            @Assert(
                error.message,
                "PNG transform row length does not match row info"
            )
        }
    }
}
