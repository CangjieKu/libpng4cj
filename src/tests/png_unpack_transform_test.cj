package libpng4cj.tests

import libpng4cj.*

private func assertUnpackedRowInfo(
    actual: PngReadRowInfo,
    source: PngReadRowInfo
): Unit {
    @Assert(actual.width, source.width)
    @Assert(actual.bitDepth, UInt8(8))
    @Assert(actual.colorType.toString(), source.colorType.toString())
    @Assert(actual.channels, source.channels)
    @Assert(actual.pixelDepth, UInt16(8) * UInt16(source.channels))
    @Assert(
        actual.rowBytes,
        UInt64(source.width) * UInt64(source.channels)
    )
}

@Test
public class PngUnpackTransformTestSuite {
    @TestCase
    public func unpacksOneBitRowsAcrossBytePadding(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(10), UInt8(1), Grayscale)
        let input: Array<Byte> = [0xb2, 0xc0]
        let unpacked = pngDoUnpack(rowInfo, input)
        let expected: Array<Byte> = [1, 0, 1, 1, 0, 0, 1, 0, 1, 1]
        @Assert(unpacked.row(), expected)
        assertUnpackedRowInfo(unpacked.info, rowInfo)

        input[0] = UInt8(0)
        @Assert(unpacked.row(), expected)
        let mutable = unpacked.row()
        mutable[0] = UInt8(0)
        @Assert(unpacked.row(), expected)
    }

    @TestCase
    public func unpacksTwoBitRowsAcrossPartialFinalByte(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(5), UInt8(2), Grayscale)
        let unpacked = pngDoUnpack(rowInfo, [0x1b, 0x80])
        let expected: Array<Byte> = [0, 1, 2, 3, 2]
        @Assert(unpacked.row(), expected)
        assertUnpackedRowInfo(unpacked.info, rowInfo)
    }

    @TestCase
    public func unpacksFourBitRowsAcrossPartialFinalByte(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(3), UInt8(4), Grayscale)
        let unpacked = pngDoUnpack(rowInfo, [0xab, 0xc0])
        let expected: Array<Byte> = [10, 11, 12]
        @Assert(unpacked.row(), expected)
        assertUnpackedRowInfo(unpacked.info, rowInfo)
    }

    @TestCase
    public func retainsPaletteTypeAndUnpackedIndexValues(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(3), UInt8(2), Indexed)
        let unpacked = pngDoUnpack(rowInfo, [0x6c])
        let expected: Array<Byte> = [1, 2, 3]
        @Assert(unpacked.row(), expected)
        @Assert(unpacked.info.colorType.toString(), "INDEXED")
        assertUnpackedRowInfo(unpacked.info, rowInfo)
    }

    @TestCase
    public func handlesWidthOneInitialShiftEdges(): Unit {
        let one = pngDoUnpack(
            PngReadRowInfo(UInt32(1), UInt8(1), Grayscale),
            [0x80]
        )
        let oneExpected: Array<Byte> = [1]
        @Assert(one.row(), oneExpected)

        let two = pngDoUnpack(
            PngReadRowInfo(UInt32(1), UInt8(2), Grayscale),
            [0xc0]
        )
        let twoExpected: Array<Byte> = [3]
        @Assert(two.row(), twoExpected)

        let four = pngDoUnpack(
            PngReadRowInfo(UInt32(1), UInt8(4), Grayscale),
            [0xf0]
        )
        let fourExpected: Array<Byte> = [15]
        @Assert(four.row(), fourExpected)
    }

    @TestCase
    public func keepsUnsupportedRowsCopyOwnedAndRejectsMalformedInput(): Unit {
        let eightInput: Array<Byte> = [1, 2]
        let eightInfo = PngReadRowInfo(UInt32(2), UInt8(8), Grayscale)
        let eight = pngDoUnpack(eightInfo, eightInput)
        let eightExpected: Array<Byte> = [1, 2]
        @Assert(eight.row(), eightExpected)
        @Assert(eight.info.bitDepth, UInt8(8))

        let truecolorInfo = PngReadRowInfo(
            UInt32(1), UInt8(4), Truecolor
        )
        let truecolorInput: Array<Byte> = [0xab, 0xc0]
        let truecolor = pngDoUnpack(truecolorInfo, truecolorInput)
        let truecolorExpected: Array<Byte> = [0xab, 0xc0]
        @Assert(truecolor.row(), truecolorExpected)

        let unsupportedInfo = PngReadRowInfo(
            UInt32(2), UInt8(3), Grayscale
        )
        let unsupportedInput: Array<Byte> = [0xe0]
        let unsupported = pngDoUnpack(unsupportedInfo, unsupportedInput)
        let unsupportedExpected: Array<Byte> = [0xe0]
        @Assert(unsupported.row(), unsupportedExpected)

        let mismatchInfo = PngReadRowInfo(
            UInt32(2), UInt8(2), Grayscale, UInt8(2)
        )
        let mismatchInput: Array<Byte> = [0x10]
        let mismatch = pngDoUnpack(mismatchInfo, mismatchInput)
        let mismatchExpected: Array<Byte> = [0x10]
        @Assert(mismatch.row(), mismatchExpected)

        let emptyInfo = PngReadRowInfo(UInt32(0), UInt8(1), Grayscale)
        let empty = pngDoUnpack(emptyInfo, [])
        let emptyExpected: Array<Byte> = []
        @Assert(empty.row(), emptyExpected)

        eightInput[0] = UInt8(9)
        @Assert(eight.row(), eightExpected)
        let mutable = truecolor.row()
        mutable[0] = UInt8(0)
        @Assert(truecolor.row(), truecolorExpected)

        try {
            pngDoUnpack(
                PngReadRowInfo(UInt32(5), UInt8(2), Grayscale),
                [0x1b]
            )
            @Fail("packed-row unpack should reject a row length mismatch")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }
    }
}
