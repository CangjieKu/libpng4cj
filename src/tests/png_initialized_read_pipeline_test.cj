package libpng4cj.tests

import libpng4cj.*

@Test
public class PngInitializedReadPipelineTestSuite {
    @TestCase
    public func convertsSourceShapedEightBitRgbAndRgba(): Unit {
        let defaults = pngDoRgbToGray(
            PngReadRowInfo(UInt32(2), UInt8(8), Truecolor),
            [10, 20, 30, 40, 50, 60],
            PngRgbToGrayTransform()
        )
        let defaultsExpected: Array<Byte> = [18, 48]
        @Assert(defaults.row(), defaultsExpected)
        @Assert(defaults.info.colorType.toString(), "GRAYSCALE")
        @Assert(defaults.info.channels, UInt8(1))
        @Assert(defaults.hadNonGrayPixels, true)

        let redOnly = pngDoRgbToGray(
            PngReadRowInfo(UInt32(2), UInt8(8), TruecolorAlpha),
            [10, 20, 30, 0xaa, 40, 50, 60, 0xbb],
            PngRgbToGrayTransform(Convert, UInt32(100000), UInt32(0))
        )
        let redExpected: Array<Byte> = [10, 0xaa, 40, 0xbb]
        @Assert(redOnly.row(), redExpected)
        @Assert(redOnly.info.colorType.toString(), "GRAYSCALE_ALPHA")
        @Assert(redOnly.info.channels, UInt8(2))
        @Assert(redOnly.hadNonGrayPixels, true)
    }

    @TestCase
    public func preservesSixteenBitNetworkOrderAndAlpha(): Unit {
        let converted = pngDoRgbToGray(
            PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha),
            [
                0x12, 0x34,
                0x56, 0x78,
                0x9a, 0xbc,
                0xde, 0xf0
            ],
            PngRgbToGrayTransform(Convert, UInt32(100000), UInt32(0))
        )
        let expected: Array<Byte> = [0x12, 0x34, 0xde, 0xf0]
        @Assert(converted.row(), expected)
        @Assert(converted.info.colorType.toString(), "GRAYSCALE_ALPHA")
        @Assert(converted.info.bitDepth, UInt8(16))
        @Assert(converted.info.rowBytes, UInt64(4))
        @Assert(converted.hadNonGrayPixels, true)
    }

    @TestCase
    public func preservesEqualRgbAndEnforcesStrictPolicy(): Unit {
        let equal = pngDoRgbToGray(
            PngReadRowInfo(UInt32(1), UInt8(8), Truecolor),
            [7, 7, 7],
            PngRgbToGrayTransform(RequireGray)
        )
        let expected: Array<Byte> = [7]
        @Assert(equal.row(), expected)
        @Assert(equal.hadNonGrayPixels, false)

        try {
            pngDoRgbToGray(
                PngReadRowInfo(UInt32(1), UInt8(8), Truecolor),
                [7, 8, 9],
                PngRgbToGrayTransform(RequireGray)
            )
            @Fail("strict source-shaped RGB-to-gray should reject nongray data")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "RGB_TO_GRAY_MISMATCH")
        }
    }

    @TestCase
    public func keepsUnsupportedRowsOwnedAndRejectsMalformedInput(): Unit {
        let input: Array<Byte> = [1, 2]
        let gray = pngDoRgbToGray(
            PngReadRowInfo(UInt32(2), UInt8(8), Grayscale),
            input,
            PngRgbToGrayTransform()
        )
        let expected: Array<Byte> = [1, 2]
        @Assert(gray.row(), expected)
        input[0] = UInt8(9)
        @Assert(gray.row(), expected)

        try {
            pngDoRgbToGray(
                PngReadRowInfo(UInt32(2), UInt8(8), Truecolor),
                [1, 2, 3, 4, 5],
                PngRgbToGrayTransform()
            )
            @Fail("source-shaped RGB-to-gray should reject malformed rows")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }
    }
}
