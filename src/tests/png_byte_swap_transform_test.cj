package libpng4cj.tests

import libpng4cj.*

@Test
public class PngByteSwapTransformTestSuite {
    @TestCase
    public func swapsEverySixteenBitComponentAcrossRowShapes(): Unit {
        let gray = pngDoSwap(
            PngReadRowInfo(UInt32(2), UInt8(16), Grayscale),
            [0x12, 0x34, 0xab, 0xcd]
        )
        let grayExpected: Array<Byte> = [0x34, 0x12, 0xcd, 0xab]
        @Assert(gray.row(), grayExpected)

        let grayAlpha = pngDoSwap(
            PngReadRowInfo(UInt32(1), UInt8(16), GrayscaleAlpha),
            [0x01, 0x02, 0x03, 0x04]
        )
        let grayAlphaExpected: Array<Byte> = [0x02, 0x01, 0x04, 0x03]
        @Assert(grayAlpha.row(), grayAlphaExpected)

        let rgb = pngDoSwap(
            PngReadRowInfo(UInt32(1), UInt8(16), Truecolor),
            [0x01, 0x02, 0x03, 0x04, 0x05, 0x06]
        )
        let rgbExpected: Array<Byte> = [0x02, 0x01, 0x04, 0x03, 0x06, 0x05]
        @Assert(rgb.row(), rgbExpected)

        let rgba = pngDoSwap(
            PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha),
            [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
        )
        let rgbaExpected: Array<Byte> = [
            0x02, 0x01, 0x04, 0x03, 0x06, 0x05, 0x08, 0x07
        ]
        @Assert(rgba.row(), rgbaExpected)
        @Assert(rgba.info.bitDepth, UInt8(16))
        @Assert(rgba.info.channels, UInt8(4))
        @Assert(rgba.info.pixelDepth, UInt16(64))
        @Assert(rgba.info.rowBytes, UInt64(8))
    }

    @TestCase
    public func preservesOwnedEightBitAndEmptyNoOps(): Unit {
        let source: Array<Byte> = [1, 2, 3]
        let byteRow = pngDoSwap(
            PngReadRowInfo(UInt32(1), UInt8(8), Truecolor), source
        )
        source[0] = UInt8(9)
        let expected: Array<Byte> = [1, 2, 3]
        @Assert(byteRow.row(), expected)
        let mutable = byteRow.row()
        mutable[1] = UInt8(9)
        @Assert(byteRow.row(), expected)

        let empty = pngDoSwap(
            PngReadRowInfo(UInt32(0), UInt8(16), TruecolorAlpha), []
        )
        let emptyExpected: Array<Byte> = []
        @Assert(empty.row(), emptyExpected)
        @Assert(empty.info.rowBytes, UInt64(0))
    }

    @TestCase
    public func validatesMalformedRowsBeforeDepthChecks(): Unit {
        try {
            pngDoSwap(
                PngReadRowInfo(UInt32(2), UInt8(8), Grayscale),
                [0x7f]
            )
            @Fail("8-bit byte-swap no-op should validate row length first")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
            @Assert(
                error.message,
                "PNG transform row length does not match row info"
            )
        }
    }
}
