package libpng4cj.tests

import libpng4cj.*

private func indexedPalette(): Array<Byte> {
    let palette = Array<Byte>(Int64(16 * 3), repeat: 0)
    var index: Int64 = 0
    while (index < 16) {
        palette[index * 3] = UInt8(index)
        palette[index * 3 + 1] = UInt8(index + 16)
        palette[index * 3 + 2] = UInt8(index + 32)
        index += 1
    }
    palette
}

private func assertPaletteOutputInfo(
    actual: PngReadRowInfo,
    source: PngReadRowInfo,
    withAlpha: Bool
): Unit {
    let channels = if (withAlpha) { UInt8(4) } else { UInt8(3) }
    @Assert(actual.width, source.width)
    @Assert(actual.bitDepth, UInt8(8))
    @Assert(
        actual.colorType.toString(),
        if (withAlpha) { "TRUECOLOR_ALPHA" } else { "TRUECOLOR" }
    )
    @Assert(actual.channels, channels)
    @Assert(actual.pixelDepth, UInt16(8) * UInt16(channels))
    @Assert(actual.rowBytes, UInt64(source.width) * UInt64(channels))
}

@Test
public class PngPaletteExpandTransformTestSuite {
    @TestCase
    public func expandsOneBitPaletteToRgbAcrossPadding(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(10), UInt8(1), Indexed)
        let input: Array<Byte> = [0xb2, 0xc0]
        let palette: Array<Byte> = [1, 2, 3, 4, 5, 6]
        let expanded = pngDoExpandPalette(rowInfo, input, palette, [])
        let expected: Array<Byte> = [
            4, 5, 6, 1, 2, 3, 4, 5, 6, 4, 5, 6, 1, 2, 3,
            1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6, 4, 5, 6
        ]
        @Assert(expanded.row(), expected)
        assertPaletteOutputInfo(expanded.info, rowInfo, false)

        input[0] = UInt8(0)
        @Assert(expanded.row(), expected)
        let mutable = expanded.row()
        mutable[0] = UInt8(0)
        @Assert(expanded.row(), expected)
    }

    @TestCase
    public func expandsTwoBitPaletteWithPartialTransparency(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(5), UInt8(2), Indexed)
        let expanded = pngDoExpandPalette(
            rowInfo,
            [0x1b, 0x80],
            indexedPalette(),
            [0x00, 0x80]
        )
        let expected: Array<Byte> = [
            0, 16, 32, 0,
            1, 17, 33, 128,
            2, 18, 34, 255,
            3, 19, 35, 255,
            2, 18, 34, 255
        ]
        @Assert(expanded.row(), expected)
        assertPaletteOutputInfo(expanded.info, rowInfo, true)
    }

    @TestCase
    public func expandsFourBitPaletteAcrossPartialFinalByte(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(3), UInt8(4), Indexed)
        let expanded = pngDoExpandPalette(
            rowInfo,
            [0xab, 0xc0],
            indexedPalette(),
            []
        )
        let expected: Array<Byte> = [
            10, 26, 42,
            11, 27, 43,
            12, 28, 44
        ]
        @Assert(expanded.row(), expected)
        assertPaletteOutputInfo(expanded.info, rowInfo, false)
    }

    @TestCase
    public func expandsEightBitPaletteToRgbAndRgba(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(2), UInt8(8), Indexed)
        let rgb = pngDoExpandPalette(
            rowInfo,
            [1, 0],
            indexedPalette(),
            []
        )
        let rgbExpected: Array<Byte> = [1, 17, 33, 0, 16, 32]
        @Assert(rgb.row(), rgbExpected)
        assertPaletteOutputInfo(rgb.info, rowInfo, false)

        let rgba = pngDoExpandPalette(
            rowInfo,
            [1, 0],
            indexedPalette(),
            [0x20, 0x40]
        )
        let rgbaExpected: Array<Byte> = [
            1, 17, 33, 64,
            0, 16, 32, 32
        ]
        @Assert(rgba.row(), rgbaExpected)
        assertPaletteOutputInfo(rgba.info, rowInfo, true)
    }

    @TestCase
    public func rejectsPaletteAndIndexContractViolations(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(1), UInt8(8), Indexed)
        try {
            pngDoExpandPalette(rowInfo, [0], [], [])
            @Fail("palette expansion should require a retained palette")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_PALETTE")
        }

        try {
            pngDoExpandPalette(rowInfo, [0], [1, 2, 3], [0, 1])
            @Fail("palette alpha should not exceed palette entries")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_TRANSPARENCY")
        }

        try {
            pngDoExpandPalette(rowInfo, [2], [1, 2, 3, 4, 5, 6], [])
            @Fail("palette expansion should reject an out-of-range index")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "PALETTE_INDEX_OUT_OF_RANGE")
        }
    }

    @TestCase
    public func keepsUnsupportedRowsOwnedAndRejectsMalformedInput(): Unit {
        let grayInfo = PngReadRowInfo(UInt32(2), UInt8(8), Grayscale)
        let grayInput: Array<Byte> = [1, 2]
        let gray = pngDoExpandPalette(
            grayInfo,
            grayInput,
            [0, 0, 0],
            []
        )
        let grayExpected: Array<Byte> = [1, 2]
        @Assert(gray.row(), grayExpected)

        let invalidDepthInfo = PngReadRowInfo(
            UInt32(2), UInt8(3), Indexed
        )
        let invalidDepth = pngDoExpandPalette(
            invalidDepthInfo,
            [0],
            [0, 0, 0],
            []
        )
        let invalidDepthExpected: Array<Byte> = [0]
        @Assert(invalidDepth.row(), invalidDepthExpected)

        let mismatchInfo = PngReadRowInfo(
            UInt32(2), UInt8(2), Indexed, UInt8(2)
        )
        let mismatch = pngDoExpandPalette(
            mismatchInfo,
            [0],
            [0, 0, 0],
            []
        )
        let mismatchExpected: Array<Byte> = [0]
        @Assert(mismatch.row(), mismatchExpected)

        let emptyInfo = PngReadRowInfo(UInt32(0), UInt8(1), Indexed)
        let empty = pngDoExpandPalette(emptyInfo, [], [], [])
        let emptyExpected: Array<Byte> = []
        @Assert(empty.row(), emptyExpected)

        grayInput[0] = UInt8(9)
        @Assert(gray.row(), grayExpected)
        let mutable = gray.row()
        mutable[0] = UInt8(0)
        @Assert(gray.row(), grayExpected)

        try {
            pngDoExpandPalette(
                PngReadRowInfo(UInt32(5), UInt8(2), Indexed),
                [0x1b],
                indexedPalette(),
                []
            )
            @Fail("palette expansion should reject a row length mismatch")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }
    }
}
