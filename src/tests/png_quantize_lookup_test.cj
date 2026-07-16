package libpng4cj.tests

import libpng4cj.*

private func quantizeCell(red: Int64, green: Int64, blue: Int64): Int64 {
    (red << 10) | (green << 5) | blue
}

private func blackWhiteQuantizePalette(): Array<Byte> {
    [0, 0, 0, 0xff, 0xff, 0xff]
}

@Test
public class PngQuantizeLookupTestSuite {
    @TestCase
    public func generatesFrozenBlackWhiteThresholdCells(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setQuantize(blackWhiteQuantizePalette(), 2, 2, true), true)

        let lookup = state.quantizePaletteLookup()
        @Assert(lookup.size, Int64(32768))
        @Assert(lookup[quantizeCell(0, 0, 0)], UInt8(0))
        @Assert(lookup[quantizeCell(15, 15, 15)], UInt8(0))
        @Assert(lookup[quantizeCell(16, 16, 16)], UInt8(1))
        @Assert(lookup[quantizeCell(31, 31, 31)], UInt8(1))
    }

    @TestCase
    public func preservesFrozenFiveBitRgbCellIndexing(): Unit {
        let palette: Array<Byte> = [0xf8, 0, 0, 0, 0xf8, 0, 0, 0, 0xf8]
        let state = PngReadTransformState()
        @Assert(state.setQuantize(palette, 3, 3, true), true)

        let lookup = state.quantizePaletteLookup()
        @Assert(lookup[quantizeCell(31, 0, 0)], UInt8(0))
        @Assert(lookup[quantizeCell(0, 31, 0)], UInt8(1))
        @Assert(lookup[quantizeCell(0, 0, 31)], UInt8(2))
        @Assert(lookup[quantizeCell(20, 5, 5)], UInt8(0))
    }

    @TestCase
    public func keepsFirstPaletteEntryOnEqualDistanceTies(): Unit {
        let duplicate: Array<Byte> = [0x80, 0x80, 0x80, 0x80, 0x80, 0x80]
        let state = PngReadTransformState()
        @Assert(state.setQuantize(duplicate, 2, 2, true), true)

        let lookup = state.quantizePaletteLookup()
        var index: Int64 = 0
        while (index < lookup.size) {
            @Assert(lookup[index], UInt8(0))
            index += 1
        }
    }

    @TestCase
    public func supportsTheFinalPaletteIndexAcrossTheFullCount(): Unit {
        let palette = Array<Byte>(Int64(256 * 3), repeat: 0)
        let finalOffset = Int64(255 * 3)
        palette[finalOffset] = UInt8(0xff)
        palette[finalOffset + 1] = UInt8(0xff)
        palette[finalOffset + 2] = UInt8(0xff)

        let state = PngReadTransformState()
        @Assert(state.setQuantize(palette, 256, 256, true), true)
        let lookup = state.quantizePaletteLookup()
        @Assert(lookup[quantizeCell(0, 0, 0)], UInt8(0))
        @Assert(lookup[quantizeCell(31, 31, 31)], UInt8(255))
    }

    @TestCase
    public func ownsAndReplacesFullLookupState(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setQuantize(blackWhiteQuantizePalette(), 2, 2, true), true)

        let first = state.quantizePaletteLookup()
        first[0] = UInt8(1)
        @Assert(state.quantizePaletteLookup()[0], UInt8(0))

        let reversed: Array<Byte> = [0xff, 0xff, 0xff, 0, 0, 0]
        @Assert(state.setQuantize(reversed, 2, 2, true), true)
        let replacement = state.quantizePaletteLookup()
        @Assert(replacement[quantizeCell(0, 0, 0)], UInt8(1))
        @Assert(replacement[quantizeCell(31, 31, 31)], UInt8(0))
    }

    @TestCase
    public func clearsFullLookupWhenSwitchingToNonFullMode(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setQuantize(blackWhiteQuantizePalette(), 2, 2, true), true)
        @Assert(state.quantizePaletteLookup().size, Int64(32768))

        @Assert(state.setQuantize(blackWhiteQuantizePalette(), 2, 2, false), true)
        @Assert(state.quantizeMode().toString(), "PALETTE_REMAP")
        @Assert(state.quantizePaletteLookup().size, Int64(0))
        @Assert(state.quantizeIndex().size, Int64(256))
    }

    @TestCase
    public func failedCallsKeepThePreviousFullLookup(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setQuantize(blackWhiteQuantizePalette(), 2, 2, true), true)
        state.markRowInitialized()

        let replacement: Array<Byte> = [0, 0, 0]
        @Assert(state.setQuantize(replacement, 1, 1, false), false)
        @Assert(state.quantizeMode().toString(), "FULL_COLOR")
        @Assert(state.quantizePaletteLookup().size, Int64(32768))
        @Assert(
            state.quantizePaletteLookup()[quantizeCell(31, 31, 31)],
            UInt8(1)
        )
    }
}
