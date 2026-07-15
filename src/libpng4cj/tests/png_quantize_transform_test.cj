package libpng4cj.tests

import libpng4cj.*

private func quantizePaletteLookup(): Array<Byte> {
    let lookup = Array<Byte>(Int64(32768), repeat: 0)
    lookup[0] = UInt8(7)
    lookup[16644] = UInt8(9)
    lookup[32767] = UInt8(11)
    lookup
}

private func identityQuantizeLookup(): Array<Byte> {
    let lookup = Array<Byte>(Int64(256), repeat: 0)
    var index: Int64 = 0
    while (index < lookup.size) {
        lookup[index] = UInt8(index)
        index += 1
    }
    lookup
}

private func assertQuantizedInfo(
    actual: PngReadRowInfo,
    source: PngReadRowInfo
): Unit {
    @Assert(actual.width, source.width)
    @Assert(actual.bitDepth, UInt8(8))
    @Assert(actual.colorType.toString(), "INDEXED")
    @Assert(actual.channels, UInt8(1))
    @Assert(actual.pixelDepth, UInt16(8))
    @Assert(actual.rowBytes, UInt64(source.width))
}

@Test
public class PngQuantizeTransformTestSuite {
    @TestCase
    public func quantizesRgbThroughFrozenFiveBitCells(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(3), UInt8(8), Truecolor)
        let input: Array<Byte> = [
            0x00, 0x00, 0x00,
            0x80, 0x40, 0x20,
            0xff, 0xff, 0xff
        ]
        let quantized = pngDoQuantize(
            rowInfo,
            input,
            quantizePaletteLookup(),
            []
        )
        let expected: Array<Byte> = [7, 9, 11]
        @Assert(quantized.row(), expected)
        assertQuantizedInfo(quantized.info, rowInfo)

        input[0] = UInt8(0xff)
        @Assert(quantized.row(), expected)
        let mutable = quantized.row()
        mutable[0] = UInt8(0)
        @Assert(quantized.row(), expected)
    }

    @TestCase
    public func quantizesRgbaWhileIgnoringAlpha(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(3), UInt8(8), TruecolorAlpha)
        let quantized = pngDoQuantize(
            rowInfo,
            [
                0x00, 0x00, 0x00, 0xff,
                0x80, 0x40, 0x20, 0x00,
                0xff, 0xff, 0xff, 0x55
            ],
            quantizePaletteLookup(),
            []
        )
        let expected: Array<Byte> = [7, 9, 11]
        @Assert(quantized.row(), expected)
        assertQuantizedInfo(quantized.info, rowInfo)
    }

    @TestCase
    public func remapsCompleteIndexedDomainWithoutChangingInfo(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(4), UInt8(8), Indexed)
        let lookup = identityQuantizeLookup()
        lookup[0] = UInt8(13)
        lookup[1] = UInt8(12)
        lookup[128] = UInt8(4)
        lookup[255] = UInt8(3)
        let remapped = pngDoQuantize(
            rowInfo,
            [0, 1, 128, 255],
            [],
            lookup
        )
        let expected: Array<Byte> = [13, 12, 4, 3]
        @Assert(remapped.row(), expected)
        @Assert(remapped.info.width, rowInfo.width)
        @Assert(remapped.info.bitDepth, rowInfo.bitDepth)
        @Assert(remapped.info.colorType.toString(), "INDEXED")
        @Assert(remapped.info.channels, rowInfo.channels)
        @Assert(remapped.info.pixelDepth, rowInfo.pixelDepth)
        @Assert(remapped.info.rowBytes, rowInfo.rowBytes)
    }

    @TestCase
    public func distinguishesAbsentAndMalformedLookupTables(): Unit {
        let rgbInfo = PngReadRowInfo(UInt32(1), UInt8(8), Truecolor)
        let rgb = pngDoQuantize(rgbInfo, [1, 2, 3], [], [])
        let rgbExpected: Array<Byte> = [1, 2, 3]
        @Assert(rgb.row(), rgbExpected)

        try {
            pngDoQuantize(rgbInfo, [1, 2, 3], [0], [])
            @Fail("quantize should reject a short palette lookup")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }

        let indexedInfo = PngReadRowInfo(UInt32(1), UInt8(8), Indexed)
        try {
            pngDoQuantize(indexedInfo, [255], [], [0])
            @Fail("quantize should reject a short index lookup")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func keepsUnsupportedRowsCopyOwned(): Unit {
        let grayInput: Array<Byte> = [1, 2]
        let grayInfo = PngReadRowInfo(UInt32(2), UInt8(8), Grayscale)
        let gray = pngDoQuantize(
            grayInfo,
            grayInput,
            quantizePaletteLookup(),
            identityQuantizeLookup()
        )
        let grayExpected: Array<Byte> = [1, 2]
        @Assert(gray.row(), grayExpected)

        let rgb16Info = PngReadRowInfo(UInt32(1), UInt8(16), Truecolor)
        let rgb16 = pngDoQuantize(
            rgb16Info,
            [0, 1, 0, 2, 0, 3],
            quantizePaletteLookup(),
            []
        )
        let rgb16Expected: Array<Byte> = [0, 1, 0, 2, 0, 3]
        @Assert(rgb16.row(), rgb16Expected)

        let mismatchInfo = PngReadRowInfo(
            UInt32(1), UInt8(8), Truecolor, UInt8(4)
        )
        let mismatch = pngDoQuantize(
            mismatchInfo,
            [1, 2, 3, 4],
            quantizePaletteLookup(),
            []
        )
        let mismatchExpected: Array<Byte> = [1, 2, 3, 4]
        @Assert(mismatch.row(), mismatchExpected)

        let emptyInfo = PngReadRowInfo(UInt32(0), UInt8(8), Indexed)
        let empty = pngDoQuantize(emptyInfo, [], [], [0])
        let emptyExpected: Array<Byte> = []
        @Assert(empty.row(), emptyExpected)

        grayInput[0] = UInt8(9)
        @Assert(gray.row(), grayExpected)
        let mutable = rgb16.row()
        mutable[0] = UInt8(9)
        @Assert(rgb16.row(), rgb16Expected)
    }

    @TestCase
    public func rejectsMalformedRowsBeforeLookupValidation(): Unit {
        try {
            pngDoQuantize(
                PngReadRowInfo(UInt32(2), UInt8(8), Truecolor),
                [1, 2, 3, 4, 5],
                [0],
                []
            )
            @Fail("quantize should reject a row length mismatch first")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
            @Assert(e.message, "PNG transform row length does not match row info")
        }
    }
}
