package libpng4cj.tests

import libpng4cj.*

private func assertExpandedAlphaInfo(
    actual: PngReadRowInfo,
    source: PngReadRowInfo,
    colorType: String,
    channels: UInt8
): Unit {
    @Assert(actual.width, source.width)
    @Assert(actual.bitDepth, if (source.bitDepth < UInt8(8)) {
        UInt8(8)
    } else {
        source.bitDepth
    })
    @Assert(actual.colorType.toString(), colorType)
    @Assert(actual.channels, channels)
    @Assert(actual.pixelDepth, UInt16(actual.bitDepth) * UInt16(channels))
    @Assert(
        actual.rowBytes,
        (UInt64(source.width) * UInt64(actual.pixelDepth) + UInt64(7)) /
            UInt64(8)
    )
}

@Test
public class PngNonPaletteExpandTransformTestSuite {
    @TestCase
    public func expandsPackedGrayValuesWithoutTransparency(): Unit {
        let oneInfo = PngReadRowInfo(UInt32(10), UInt8(1), Grayscale)
        let one = pngDoExpand(
            oneInfo,
            [0xb2, 0xc0],
            PngExpandTransparency()
        )
        let oneExpected: Array<Byte> = [
            255, 0, 255, 255, 0, 0, 255, 0, 255, 255
        ]
        @Assert(one.row(), oneExpected)
        @Assert(one.info.bitDepth, UInt8(8))
        @Assert(one.info.rowBytes, UInt64(10))

        let two = pngDoExpand(
            PngReadRowInfo(UInt32(5), UInt8(2), Grayscale),
            [0x1b, 0x80],
            PngExpandTransparency()
        )
        let twoExpected: Array<Byte> = [0, 85, 170, 255, 170]
        @Assert(two.row(), twoExpected)

        let four = pngDoExpand(
            PngReadRowInfo(UInt32(3), UInt8(4), Grayscale),
            [0xab, 0xc0],
            PngExpandTransparency()
        )
        let fourExpected: Array<Byte> = [170, 187, 204]
        @Assert(four.row(), fourExpected)
    }

    @TestCase
    public func scalesPackedGrayTransparencyBeforeAlphaGrowth(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(5), UInt8(2), Grayscale)
        let expanded = pngDoExpand(
            rowInfo,
            [0x1b, 0x80],
            PngExpandTransparency(UInt16(2))
        )
        let expected: Array<Byte> = [
            0, 255,
            85, 255,
            170, 0,
            255, 255,
            170, 0
        ]
        @Assert(expanded.row(), expected)
        assertExpandedAlphaInfo(
            expanded.info,
            rowInfo,
            "GRAYSCALE_ALPHA",
            UInt8(2)
        )
    }

    @TestCase
    public func expandsEightAndSixteenBitGrayColorKeys(): Unit {
        let gray8Info = PngReadRowInfo(UInt32(3), UInt8(8), Grayscale)
        let gray8 = pngDoExpand(
            gray8Info,
            [0, 7, 0],
            PngExpandTransparency(UInt16(0))
        )
        let gray8Expected: Array<Byte> = [0, 0, 7, 255, 0, 0]
        @Assert(gray8.row(), gray8Expected)
        assertExpandedAlphaInfo(
            gray8.info,
            gray8Info,
            "GRAYSCALE_ALPHA",
            UInt8(2)
        )

        let gray16Info = PngReadRowInfo(UInt32(2), UInt8(16), Grayscale)
        let gray16 = pngDoExpand(
            gray16Info,
            [0x12, 0x34, 0xab, 0xcd],
            PngExpandTransparency(UInt16(0x1234))
        )
        let gray16Expected: Array<Byte> = [
            0x12, 0x34, 0x00, 0x00,
            0xab, 0xcd, 0xff, 0xff
        ]
        @Assert(gray16.row(), gray16Expected)
        assertExpandedAlphaInfo(
            gray16.info,
            gray16Info,
            "GRAYSCALE_ALPHA",
            UInt8(2)
        )
    }

    @TestCase
    public func expandsEightAndSixteenBitRgbColorKeys(): Unit {
        let rgb8Info = PngReadRowInfo(UInt32(2), UInt8(8), Truecolor)
        let rgb8 = pngDoExpand(
            rgb8Info,
            [1, 2, 3, 4, 5, 6],
            PngExpandTransparency(UInt16(1), UInt16(2), UInt16(3))
        )
        let rgb8Expected: Array<Byte> = [
            1, 2, 3, 0,
            4, 5, 6, 255
        ]
        @Assert(rgb8.row(), rgb8Expected)
        assertExpandedAlphaInfo(
            rgb8.info,
            rgb8Info,
            "TRUECOLOR_ALPHA",
            UInt8(4)
        )

        let rgb16Info = PngReadRowInfo(UInt32(2), UInt8(16), Truecolor)
        let rgb16 = pngDoExpand(
            rgb16Info,
            [
                0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
                0x10, 0x20, 0x30, 0x40, 0x50, 0x60
            ],
            PngExpandTransparency(
                UInt16(0x0102),
                UInt16(0x0304),
                UInt16(0x0506)
            )
        )
        let rgb16Expected: Array<Byte> = [
            0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x00, 0x00,
            0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0xff, 0xff
        ]
        @Assert(rgb16.row(), rgb16Expected)
        assertExpandedAlphaInfo(
            rgb16.info,
            rgb16Info,
            "TRUECOLOR_ALPHA",
            UInt8(4)
        )
    }

    @TestCase
    public func keepsAbsentAndUnsupportedTransformsCopyOwned(): Unit {
        let grayInput: Array<Byte> = [0, 7]
        let grayInfo = PngReadRowInfo(UInt32(2), UInt8(8), Grayscale)
        let gray = pngDoExpand(
            grayInfo,
            grayInput,
            PngExpandTransparency()
        )
        let grayExpected: Array<Byte> = [0, 7]
        @Assert(gray.row(), grayExpected)

        let rgbaInfo = PngReadRowInfo(UInt32(1), UInt8(8), TruecolorAlpha)
        let rgba = pngDoExpand(
            rgbaInfo,
            [1, 2, 3, 4],
            PngExpandTransparency(UInt16(1), UInt16(2), UInt16(3))
        )
        let rgbaExpected: Array<Byte> = [1, 2, 3, 4]
        @Assert(rgba.row(), rgbaExpected)

        let invalidDepthInfo = PngReadRowInfo(
            UInt32(1), UInt8(4), Truecolor
        )
        let invalidDepth = pngDoExpand(
            invalidDepthInfo,
            [0x12, 0x30],
            PngExpandTransparency(UInt16(1), UInt16(2), UInt16(3))
        )
        let invalidDepthExpected: Array<Byte> = [0x12, 0x30]
        @Assert(invalidDepth.row(), invalidDepthExpected)

        let emptyInfo = PngReadRowInfo(UInt32(0), UInt8(1), Grayscale)
        let empty = pngDoExpand(
            emptyInfo,
            [],
            PngExpandTransparency(UInt16(0))
        )
        let emptyExpected: Array<Byte> = []
        @Assert(empty.row(), emptyExpected)

        grayInput[0] = UInt8(9)
        @Assert(gray.row(), grayExpected)
        let mutable = rgba.row()
        mutable[0] = UInt8(0)
        @Assert(rgba.row(), rgbaExpected)
    }

    @TestCase
    public func rejectsMalformedRowsBeforeExpansion(): Unit {
        try {
            pngDoExpand(
                PngReadRowInfo(UInt32(2), UInt8(16), Truecolor),
                [0, 1, 2],
                PngExpandTransparency(
                    UInt16(0),
                    UInt16(0),
                    UInt16(0)
                )
            )
            @Fail("non-palette expansion should reject a row length mismatch")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }
    }
}
