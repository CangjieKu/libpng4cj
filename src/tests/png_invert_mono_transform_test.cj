package libpng4cj.tests

import libpng4cj.*

@Test
public class PngInvertMonoTransformTestSuite {
    @TestCase
    public func invertsPackedGrayBytesIncludingPadding(): Unit {
        let one = pngDoInvertMono(
            PngReadRowInfo(UInt32(9), UInt8(1), Grayscale),
            [0x80, 0x40]
        )
        let oneExpected: Array<Byte> = [0x7f, 0xbf]
        @Assert(one.row(), oneExpected)

        let two = pngDoInvertMono(
            PngReadRowInfo(UInt32(5), UInt8(2), Grayscale),
            [0x1b, 0xc0]
        )
        let twoExpected: Array<Byte> = [0xe4, 0x3f]
        @Assert(two.row(), twoExpected)

        let four = pngDoInvertMono(
            PngReadRowInfo(UInt32(3), UInt8(4), Grayscale),
            [0x12, 0x30]
        )
        let fourExpected: Array<Byte> = [0xed, 0xcf]
        @Assert(four.row(), fourExpected)
        @Assert(four.info.rowBytes, UInt64(2))
    }

    @TestCase
    public func invertsEightAndSixteenBitGrayRows(): Unit {
        let gray8 = pngDoInvertMono(
            PngReadRowInfo(UInt32(3), UInt8(8), Grayscale),
            [0x00, 0x7f, 0xff]
        )
        let gray8Expected: Array<Byte> = [0xff, 0x80, 0x00]
        @Assert(gray8.row(), gray8Expected)

        let gray16 = pngDoInvertMono(
            PngReadRowInfo(UInt32(2), UInt8(16), Grayscale),
            [0x01, 0x02, 0xab, 0xcd]
        )
        let gray16Expected: Array<Byte> = [0xfe, 0xfd, 0x54, 0x32]
        @Assert(gray16.row(), gray16Expected)
        @Assert(gray16.info.bitDepth, UInt8(16))
        @Assert(gray16.info.rowBytes, UInt64(4))
    }

    @TestCase
    public func preservesGrayAlphaBytesAcrossEightAndSixteenBitRows(): Unit {
        let grayAlpha8 = pngDoInvertMono(
            PngReadRowInfo(UInt32(2), UInt8(8), GrayscaleAlpha),
            [0x10, 0x20, 0x30, 0x40]
        )
        let grayAlpha8Expected: Array<Byte> = [0xef, 0x20, 0xcf, 0x40]
        @Assert(grayAlpha8.row(), grayAlpha8Expected)

        let grayAlpha16 = pngDoInvertMono(
            PngReadRowInfo(UInt32(1), UInt8(16), GrayscaleAlpha),
            [0x12, 0x34, 0x56, 0x78]
        )
        let grayAlpha16Expected: Array<Byte> = [0xed, 0xcb, 0x56, 0x78]
        @Assert(grayAlpha16.row(), grayAlpha16Expected)
        @Assert(grayAlpha16.info.colorType.toString(), "GRAYSCALE_ALPHA")
    }

    @TestCase
    public func preservesOwnedUnsupportedRowsAndMalformedPriority(): Unit {
        let source: Array<Byte> = [1, 2, 3]
        let rgb = pngDoInvertMono(
            PngReadRowInfo(UInt32(1), UInt8(8), Truecolor),
            source
        )
        source[0] = UInt8(9)
        let expected: Array<Byte> = [1, 2, 3]
        @Assert(rgb.row(), expected)

        try {
            pngDoInvertMono(
                PngReadRowInfo(UInt32(2), UInt8(8), Truecolor),
                [1, 2, 3]
            )
            @Fail("unsupported invert-mono rows should validate length first")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
        }
    }
}
