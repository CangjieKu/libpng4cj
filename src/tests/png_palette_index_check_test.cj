package libpng4cj.tests

import libpng4cj.*

private let PALETTE_INDEX_ROW2_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x90, 0x06, 0x00, 0x00, 0x1d, 0x00, 0x1c
]

private let PALETTE_INDEX_TWO_ROWS_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x10, 0x60, 0xd0, 0x01, 0x00, 0x00, 0x60, 0x00, 0x3d
]

private func joinPaletteIndexBytes(
    left: Array<Byte>,
    right: Array<Byte>
): Array<Byte> {
    let output = Array<Byte>(left.size + right.size, repeat: 0)
    var index: Int64 = 0
    while (index < left.size) {
        output[index] = left[index]
        index += 1
    }
    var rightIndex: Int64 = 0
    while (rightIndex < right.size) {
        output[left.size + rightIndex] = right[rightIndex]
        rightIndex += 1
    }
    output
}

private func makePaletteIndexChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinPaletteIndexBytes(
        joinPaletteIndexBytes(
            joinPaletteIndexBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makePaletteIndexIhdr(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8
): Array<Byte> {
    let data = Array<Byte>(13, repeat: 0)
    let widthBytes = writeUInt32Be(width)
    let heightBytes = writeUInt32Be(height)
    var index: Int64 = 0
    while (index < 4) {
        data[index] = widthBytes[index]
        data[index + 4] = heightBytes[index]
        index += 1
    }
    data[8] = bitDepth
    data[9] = UInt8(3)
    makePaletteIndexChunk(PNG_CHUNK_IHDR, data)
}

private func makePaletteIndexPalette(entries: Int64): Array<Byte> {
    let palette = Array<Byte>(entries * 3, repeat: 0)
    var index: Int64 = 0
    while (index < entries) {
        palette[index * 3] = UInt8(index)
        palette[index * 3 + 1] = UInt8(index + 1)
        palette[index * 3 + 2] = UInt8(index + 2)
        index += 1
    }
    palette
}

private func makePaletteIndexPng(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8,
    paletteEntries: Int64,
    compressed: Array<Byte>
): Array<Byte> {
    var png = joinPaletteIndexBytes(
        PNG_SIGNATURE,
        makePaletteIndexIhdr(width, height, bitDepth)
    )
    png = joinPaletteIndexBytes(
        png,
        makePaletteIndexChunk(
            PNG_CHUNK_PLTE,
            makePaletteIndexPalette(paletteEntries)
        )
    )
    png = joinPaletteIndexBytes(
        png,
        makePaletteIndexChunk(PNG_CHUNK_IDAT, compressed)
    )
    joinPaletteIndexBytes(
        png,
        makePaletteIndexChunk(PNG_CHUNK_IEND, [])
    )
}

private func paletteIndexDecoded(): PngDecodedRows {
    decodePngNonInterlaced(
        makePaletteIndexPng(
            UInt32(3),
            UInt32(1),
            UInt8(2),
            Int64(2),
            PALETTE_INDEX_ROW2_ZLIB
        )
    )
}

@Test
public class PngPaletteIndexCheckTestSuite {
    @TestCase
    public func scansPackedAndByteIndexesWithoutReadingPadding(): Unit {
        let one = pngDoCheckPaletteIndexes(
            PngReadRowInfo(UInt32(1), UInt8(1), Indexed),
            [0x80],
            Int64(1)
        )
        @Assert(one.maximumPaletteIndex, Int64(1))
        @Assert(one.hasInvalidIndex(Int64(1)), true)

        let two = pngDoCheckPaletteIndexes(
            PngReadRowInfo(UInt32(3), UInt8(2), Indexed),
            [0x1b],
            Int64(2)
        )
        @Assert(two.maximumPaletteIndex, Int64(2))
        @Assert(two.hasInvalidIndex(Int64(2)), true)
        let twoExpected: Array<Byte> = [0x1b]
        @Assert(two.row(), twoExpected)

        let four = pngDoCheckPaletteIndexes(
            PngReadRowInfo(UInt32(1), UInt8(4), Indexed),
            [0x2f],
            Int64(2)
        )
        @Assert(four.maximumPaletteIndex, Int64(2))

        let eight = pngDoCheckPaletteIndexes(
            PngReadRowInfo(UInt32(4), UInt8(8), Indexed),
            [3, 0, 0, 0],
            Int64(2)
        )
        @Assert(eight.maximumPaletteIndex, Int64(3))
        @Assert(eight.info.rowBytes, UInt64(4))
    }

    @TestCase
    public func preservesAccumulationOwnershipAndNoopShapes(): Unit {
        let first = pngDoCheckPaletteIndexes(
            PngReadRowInfo(UInt32(3), UInt8(2), Indexed),
            [0x10],
            Int64(3)
        )
        @Assert(first.maximumPaletteIndex, Int64(1))
        let secondSource: Array<Byte> = [0x2c]
        let second = pngDoCheckPaletteIndexes(
            PngReadRowInfo(UInt32(3), UInt8(2), Indexed),
            secondSource,
            Int64(3),
            first.maximumPaletteIndex
        )
        @Assert(second.maximumPaletteIndex, Int64(3))
        secondSource[0] = UInt8(0)
        let secondExpected: Array<Byte> = [0x2c]
        @Assert(second.row(), secondExpected)

        let complete = pngDoCheckPaletteIndexes(
            PngReadRowInfo(UInt32(3), UInt8(2), Indexed),
            [0xff],
            Int64(4)
        )
        @Assert(complete.checked, false)
        @Assert(complete.maximumPaletteIndex, Int64(0))

        let gray = pngDoCheckPaletteIndexes(
            PngReadRowInfo(UInt32(1), UInt8(8), Grayscale),
            [0xff],
            Int64(1)
        )
        @Assert(gray.checked, false)
        let empty = pngDoCheckPaletteIndexes(
            PngReadRowInfo(UInt32(0), UInt8(2), Indexed),
            [],
            Int64(2)
        )
        @Assert(empty.checked, false)
    }

    @TestCase
    public func validatesMalformedRowsBeforeDiagnosticArguments(): Unit {
        try {
            pngDoCheckPaletteIndexes(
                PngReadRowInfo(UInt32(4), UInt8(8), Indexed),
                [0, 1],
                Int64(2),
                Int64(-1)
            )
            @Fail("palette index check should reject malformed rows first")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
            @Assert(error.offset, Int64(2))
        }
    }

    @TestCase
    public func snapshotsDefaultEnabledStateAndExplicitDisable(): Unit {
        let decoded = paletteIndexDecoded()
        let defaultState = PngReadTransformState()
        @Assert(defaultState.checkForInvalidIndexEnabled(), true)
        let enabled = initializePngReadTransformations(defaultState, decoded)
        @Assert(enabled.checkForInvalidIndexEnabled(), true)
        @Assert(enabled.paletteEntryCount(), Int64(2))
        @Assert(enabled.stageCount(), Int64(1))
        @Assert(enabled.stage(0).toString(), "PALETTE_INDEX_CHECK")

        let disabledState = PngReadTransformState()
        @Assert(disabledState.setCheckForInvalidIndex(Int64(0)), true)
        let disabled = initializePngReadTransformations(disabledState, decoded)
        @Assert(disabled.checkForInvalidIndexEnabled(), false)
        @Assert(disabled.stageCount(), Int64(0))
        @Assert(disabledState.setCheckForInvalidIndex(Int64(1)), true)
        @Assert(disabled.checkForInvalidIndexEnabled(), false)

        let negativeState = PngReadTransformState()
        @Assert(negativeState.setCheckForInvalidIndex(Int64(-1)), true)
        @Assert(negativeState.checkForInvalidIndexEnabled(), false)
        @Assert(negativeState.setCheckForInvalidIndex(true), true)
        @Assert(negativeState.checkForInvalidIndexEnabled(), true)
    }

    @TestCase
    public func placesCheckAfterUnpackBeforeBgrAndReportsRowFact(): Unit {
        let decoded = paletteIndexDecoded()
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(state.setPacking(), true)
        @Assert(state.setBgr(), true)
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.stageCount(), Int64(3))
        @Assert(initialized.stage(0).toString(), "UNPACK")
        @Assert(initialized.stage(1).toString(), "PALETTE_INDEX_CHECK")
        @Assert(initialized.stage(2).toString(), "BGR")
        @Assert(ReadStageByteSwap.ordinalValue(), Int64(16))
        @Assert(ReadStagePaletteIndexCheck.ordinalValue(), Int64(17))

        let transformed = applyInitializedPngReadStages(
            initialized,
            PngReadRowInfo(decoded.ihdr),
            decoded.row(0)
        )
        let expected: Array<Byte> = [0, 1, 2]
        @Assert(transformed.row(), expected)
        @Assert(transformed.info.bitDepth, UInt8(8))
        @Assert(transformed.info.colorType.toString(), "INDEXED")
        @Assert(transformed.maximumPaletteIndex, Int64(2))
        @Assert(transformed.hasInvalidPaletteIndex, true)
    }

    @TestCase
    public func accumulatesWholeImageMaximumAndHonorsDisable(): Unit {
        let decoded = decodePngNonInterlaced(
            makePaletteIndexPng(
                UInt32(3),
                UInt32(2),
                UInt8(2),
                Int64(3),
                PALETTE_INDEX_TWO_ROWS_ZLIB
            )
        )
        let checked = transformPngRowsInitialized(
            decoded,
            PngReadTransformState()
        )
        @Assert(checked.maximumPaletteIndex, Int64(3))
        @Assert(checked.hasInvalidPaletteIndex, true)
        @Assert(checked.rowCount(), Int64(2))
        let row0Expected: Array<Byte> = [0x10]
        let row1Expected: Array<Byte> = [0x2c]
        @Assert(checked.row(0), row0Expected)
        @Assert(checked.row(1), row1Expected)

        let disabledState = PngReadTransformState()
        @Assert(disabledState.setCheckForInvalidIndex(false), true)
        let disabled = transformPngRowsInitialized(decoded, disabledState)
        @Assert(disabled.maximumPaletteIndex, Int64(0))
        @Assert(disabled.hasInvalidPaletteIndex, false)
    }
}
