package libpng4cj.tests

import libpng4cj.*

private func assertUnshiftInfoUnchanged(
    actual: PngReadRowInfo,
    expected: PngReadRowInfo
): Unit {
    @Assert(actual.width, expected.width)
    @Assert(actual.bitDepth, expected.bitDepth)
    @Assert(actual.colorType.toString(), expected.colorType.toString())
    @Assert(actual.channels, expected.channels)
    @Assert(actual.pixelDepth, expected.pixelDepth)
    @Assert(actual.rowBytes, expected.rowBytes)
}

@Test
public class PngUnshiftTransformTestSuite {
    @TestCase
    public func unshiftsPackedGrayBytesIncludingPadding(): Unit {
        let twoBitInfo = PngReadRowInfo(UInt32(5), UInt8(2), Grayscale)
        let twoBitInput: Array<Byte> = [0xe4, 0xc0]
        let twoBit = pngDoUnshift(
            twoBitInfo,
            twoBitInput,
            PngSignificantBits(UInt8(1), 0, 0, 0, 0)
        )
        let twoBitExpected: Array<Byte> = [0x50, 0x40]
        @Assert(twoBit.row(), twoBitExpected)
        assertUnshiftInfoUnchanged(twoBit.info, twoBitInfo)

        let fourBitInfo = PngReadRowInfo(UInt32(3), UInt8(4), Grayscale)
        let fourBitInput: Array<Byte> = [0xf7, 0xa0]
        let fourBit = pngDoUnshift(
            fourBitInfo,
            fourBitInput,
            PngSignificantBits(UInt8(2), 0, 0, 0, 0)
        )
        let fourBitExpected: Array<Byte> = [0x31, 0x20]
        @Assert(fourBit.row(), fourBitExpected)
        assertUnshiftInfoUnchanged(fourBit.info, fourBitInfo)

        twoBitInput[0] = UInt8(0)
        @Assert(twoBit.row(), twoBitExpected)
        let mutable = fourBit.row()
        mutable[0] = UInt8(0)
        @Assert(fourBit.row(), fourBitExpected)
    }

    @TestCase
    public func cyclesEightBitGrayAndAlphaShifts(): Unit {
        let grayInfo = PngReadRowInfo(UInt32(2), UInt8(8), Grayscale)
        let gray = pngDoUnshift(
            grayInfo,
            [0xf8, 0x80],
            PngSignificantBits(UInt8(5), 0, 0, 0, 0)
        )
        let grayExpected: Array<Byte> = [31, 16]
        @Assert(gray.row(), grayExpected)
        assertUnshiftInfoUnchanged(gray.info, grayInfo)

        let grayAlphaInfo = PngReadRowInfo(
            UInt32(2), UInt8(8), GrayscaleAlpha
        )
        let grayAlpha = pngDoUnshift(
            grayAlphaInfo,
            [0xfc, 0xf0, 0x80, 0x70],
            PngSignificantBits(UInt8(6), 0, 0, 0, UInt8(4))
        )
        let grayAlphaExpected: Array<Byte> = [63, 15, 32, 7]
        @Assert(grayAlpha.row(), grayAlphaExpected)
        assertUnshiftInfoUnchanged(grayAlpha.info, grayAlphaInfo)
    }

    @TestCase
    public func cyclesEightBitRgbAndRgbaShifts(): Unit {
        let rgbInfo = PngReadRowInfo(UInt32(2), UInt8(8), Truecolor)
        let rgb = pngDoUnshift(
            rgbInfo,
            [0xf8, 0xfc, 0xfe, 0x80, 0x40, 0x20],
            PngSignificantBits(0, UInt8(5), UInt8(6), UInt8(7), 0)
        )
        let rgbExpected: Array<Byte> = [31, 63, 127, 16, 16, 16]
        @Assert(rgb.row(), rgbExpected)
        assertUnshiftInfoUnchanged(rgb.info, rgbInfo)

        let rgbaInfo = PngReadRowInfo(UInt32(1), UInt8(8), TruecolorAlpha)
        let rgba = pngDoUnshift(
            rgbaInfo,
            [0xf0, 0xf8, 0xfc, 0xfe],
            PngSignificantBits(
                0, UInt8(4), UInt8(5), UInt8(6), UInt8(7)
            )
        )
        let rgbaExpected: Array<Byte> = [15, 31, 63, 127]
        @Assert(rgba.row(), rgbaExpected)
        assertUnshiftInfoUnchanged(rgba.info, rgbaInfo)
    }

    @TestCase
    public func unshiftsSixteenBitNetworkOrderChannels(): Unit {
        let grayInfo = PngReadRowInfo(UInt32(2), UInt8(16), Grayscale)
        let gray = pngDoUnshift(
            grayInfo,
            [0xf1, 0x23, 0x80, 0x00],
            PngSignificantBits(UInt8(12), 0, 0, 0, 0)
        )
        let grayExpected: Array<Byte> = [0x0f, 0x12, 0x08, 0x00]
        @Assert(gray.row(), grayExpected)
        assertUnshiftInfoUnchanged(gray.info, grayInfo)

        let grayAlphaInfo = PngReadRowInfo(
            UInt32(1), UInt8(16), GrayscaleAlpha
        )
        let grayAlpha = pngDoUnshift(
            grayAlphaInfo,
            [0xf1, 0x23, 0xab, 0xcd],
            PngSignificantBits(UInt8(12), 0, 0, 0, UInt8(8))
        )
        let grayAlphaExpected: Array<Byte> = [0x0f, 0x12, 0x00, 0xab]
        @Assert(grayAlpha.row(), grayAlphaExpected)
        assertUnshiftInfoUnchanged(grayAlpha.info, grayAlphaInfo)

        let rgbInfo = PngReadRowInfo(UInt32(1), UInt8(16), Truecolor)
        let rgb = pngDoUnshift(
            rgbInfo,
            [0xf1, 0x23, 0xab, 0xcd, 0x98, 0x76],
            PngSignificantBits(0, UInt8(12), UInt8(8), UInt8(4), 0)
        )
        let rgbExpected: Array<Byte> = [0x0f, 0x12, 0x00, 0xab, 0x00, 0x09]
        @Assert(rgb.row(), rgbExpected)
        assertUnshiftInfoUnchanged(rgb.info, rgbInfo)

        let rgbaInfo = PngReadRowInfo(
            UInt32(1), UInt8(16), TruecolorAlpha
        )
        let rgba = pngDoUnshift(
            rgbaInfo,
            [0xf1, 0x23, 0xab, 0xcd, 0x98, 0x76, 0xfe, 0xdc],
            PngSignificantBits(
                0, UInt8(12), UInt8(8), UInt8(4), UInt8(15)
            )
        )
        let rgbaExpected: Array<Byte> = [
            0x0f, 0x12, 0x00, 0xab, 0x00, 0x09, 0x7f, 0x6e
        ]
        @Assert(rgba.row(), rgbaExpected)
        assertUnshiftInfoUnchanged(rgba.info, rgbaInfo)
    }

    @TestCase
    public func keepsUnsupportedAndIneffectiveRowsUnchanged(): Unit {
        let bits = PngSignificantBits(
            UInt8(1), UInt8(5), UInt8(6), UInt8(7), UInt8(4)
        )
        let paletteInput: Array<Byte> = [1, 2]
        let palette = pngDoUnshift(
            PngReadRowInfo(UInt32(2), UInt8(8), Indexed),
            paletteInput,
            bits
        )
        let paletteExpected: Array<Byte> = [1, 2]
        @Assert(palette.row(), paletteExpected)

        let oneBitInput: Array<Byte> = [0xaa]
        let oneBit = pngDoUnshift(
            PngReadRowInfo(UInt32(8), UInt8(1), Grayscale),
            oneBitInput,
            bits
        )
        @Assert(oneBit.row(), oneBitInput)

        let unsupportedInput: Array<Byte> = [0xe0]
        let unsupported = pngDoUnshift(
            PngReadRowInfo(UInt32(2), UInt8(3), Grayscale),
            unsupportedInput,
            bits
        )
        @Assert(unsupported.row(), unsupportedInput)

        let expandedInfo = PngReadRowInfo(
            UInt32(1), UInt8(8), Truecolor, UInt8(4)
        )
        let expandedInput: Array<Byte> = [1, 2, 3, 4]
        let expanded = pngDoUnshift(expandedInfo, expandedInput, bits)
        let expandedExpected: Array<Byte> = [1, 2, 3, 4]
        @Assert(expanded.row(), expandedExpected)

        let zero = pngDoUnshift(
            PngReadRowInfo(UInt32(1), UInt8(8), Grayscale),
            [0xf0],
            PngSignificantBits(UInt8(0), 0, 0, 0, 0)
        )
        let zeroExpected: Array<Byte> = [0xf0]
        @Assert(zero.row(), zeroExpected)

        let equal = pngDoUnshift(
            PngReadRowInfo(UInt32(1), UInt8(8), Grayscale),
            [0xf0],
            PngSignificantBits(UInt8(8), 0, 0, 0, 0)
        )
        @Assert(equal.row(), zeroExpected)

        let wider = pngDoUnshift(
            PngReadRowInfo(UInt32(1), UInt8(8), Grayscale),
            [0xf0],
            PngSignificantBits(UInt8(9), 0, 0, 0, 0)
        )
        @Assert(wider.row(), zeroExpected)

        paletteInput[0] = UInt8(9)
        @Assert(palette.row(), paletteExpected)
        expandedInput[0] = UInt8(9)
        @Assert(expanded.row(), expandedExpected)
        let mutable = expanded.row()
        mutable[0] = UInt8(9)
        @Assert(expanded.row(), expandedExpected)
    }

    @TestCase
    public func rejectsMalformedRowsAndAdaptsExistingSelection(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(1), UInt8(8), Truecolor)
        let bits = PngSignificantBits(
            0, UInt8(5), UInt8(6), UInt8(7), 0
        )
        try {
            pngDoUnshift(rowInfo, [1, 2], bits)
            @Fail("unshift should reject a row length mismatch")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }

        let input: Array<Byte> = [0xf8, 0xfc, 0xfe]
        let disabledTransforms: Array<PngReadChannelTransform> = []
        let disabled = applySelectedPngUnshiftTransform(
            disabledTransforms, rowInfo, input, bits
        )
        @Assert(disabled.row(), input)

        let selectedTransforms: Array<PngReadChannelTransform> = [
            UnshiftSignificantBits, UnshiftSignificantBits
        ]
        let selected = applySelectedPngUnshiftTransform(
            selectedTransforms, rowInfo, input, bits
        )
        let selectedExpected: Array<Byte> = [31, 63, 127]
        @Assert(selected.row(), selectedExpected)
        assertUnshiftInfoUnchanged(selected.info, rowInfo)
    }
}
