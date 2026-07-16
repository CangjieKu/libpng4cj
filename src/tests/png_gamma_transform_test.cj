package libpng4cj.tests

import libpng4cj.*

private func gammaPacked2Oracle(value: UInt8, table: PngGamma8BitTable): UInt8 {
    var output = UInt32(0)
    var position = UInt32(0)
    while (position < UInt32(4)) {
        let shift = UInt32(6) - position * UInt32(2)
        let sample = (UInt32(value) >> shift) & UInt32(0x03)
        let expanded = UInt8(sample * UInt32(85))
        let corrected = UInt32(table.value(expanded)) >> UInt32(6)
        output = output | (corrected << shift)
        position += 1
    }
    UInt8(output)
}

private func gammaPacked4Oracle(value: UInt8, table: PngGamma8BitTable): UInt8 {
    let high = UInt8((UInt32(value) >> UInt32(4)) * UInt32(17))
    let low = UInt8((UInt32(value) & UInt32(0x0f)) * UInt32(17))
    UInt8(
        (UInt32(table.value(high)) & UInt32(0xf0)) |
        (UInt32(table.value(low)) >> UInt32(4))
    )
}

@Test
public class PngGammaTransformTestSuite {
    @TestCase
    public func correctsEightBitColorChannelsAndPreservesAlpha(): Unit {
        let table = pngBuildGamma8BitTable(Int32(220000))
        let gray = pngDoGamma(
            PngReadRowInfo(UInt32(4), UInt8(8), Grayscale),
            [0, 64, 128, 255],
            table
        )
        let grayExpected: Array<Byte> = [0, 12, 56, 255]
        @Assert(gray.row(), grayExpected)

        let ga = pngDoGamma(
            PngReadRowInfo(UInt32(2), UInt8(8), GrayscaleAlpha),
            [64, 201, 128, 17],
            table
        )
        let gaExpected: Array<Byte> = [12, 201, 56, 17]
        @Assert(ga.row(), gaExpected)

        let rgb = pngDoGamma(
            PngReadRowInfo(UInt32(1), UInt8(8), Truecolor),
            [64, 128, 192],
            table
        )
        let rgbExpected: Array<Byte> = [12, 56, 137]
        @Assert(rgb.row(), rgbExpected)

        let rgba = pngDoGamma(
            PngReadRowInfo(UInt32(1), UInt8(8), TruecolorAlpha),
            [64, 128, 192, 77],
            table
        )
        let rgbaExpected: Array<Byte> = [12, 56, 137, 77]
        @Assert(rgba.row(), rgbaExpected)
    }

    @TestCase
    public func exhaustivelyMatchesPackedTwoAndFourBitOracles(): Unit {
        let table = pngBuildGamma8BitTable(Int32(220000))
        var value: Int64 = 0
        while (value < Int64(256)) {
            let byte = UInt8(value)
            @Assert(
                pngDoGamma(
                    PngReadRowInfo(UInt32(4), UInt8(2), Grayscale),
                    [byte],
                    table
                ).row()[0],
                gammaPacked2Oracle(byte, table)
            )
            @Assert(
                pngDoGamma(
                    PngReadRowInfo(UInt32(2), UInt8(4), Grayscale),
                    [byte],
                    table
                ).row()[0],
                gammaPacked4Oracle(byte, table)
            )
            value += 1
        }
    }

    @TestCase
    public func preservesFrozenNoOpsOwnershipAndMalformedPriority(): Unit {
        let table = pngBuildGamma8BitTable(Int32(220000))
        let gray1: Array<Byte> = [0xaa]
        let gray1Result = pngDoGamma(
            PngReadRowInfo(UInt32(8), UInt8(1), Grayscale),
            gray1,
            table
        )
        gray1[0] = UInt8(0)
        let gray1Expected: Array<Byte> = [0xaa]
        @Assert(gray1Result.row(), gray1Expected)

        let indexedExpected: Array<Byte> = [7]
        @Assert(
            pngDoGamma(
                PngReadRowInfo(UInt32(1), UInt8(8), Indexed),
                [7],
                table
            ).row(),
            indexedExpected
        )
        let sixteenExpected: Array<Byte> = [0, 1, 0, 2, 0, 3]
        @Assert(
            pngDoGamma(
                PngReadRowInfo(UInt32(1), UInt8(16), Truecolor),
                [0, 1, 0, 2, 0, 3],
                table
            ).row(),
            sixteenExpected
        )

        var caught = false
        try {
            pngDoGamma(
                PngReadRowInfo(UInt32(1), UInt8(8), Truecolor),
                [1, 2],
                table
            )
        } catch (error: PngFormatException) {
            caught = error.kind == InvalidArgument
        }
        @Assert(caught, true)
    }
}
