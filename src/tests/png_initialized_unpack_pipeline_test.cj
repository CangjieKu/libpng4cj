package libpng4cj.tests

import libpng4cj.*

private let PACKING_GRAY1_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01
]

private let PACKSWAP_GRAY1_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0xd8, 0x04, 0x00, 0x00, 0xb4, 0x00, 0xb3
]

private func joinPackingBytes(
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

private func makePackingChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinPackingBytes(
        joinPackingBytes(
            joinPackingBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func packingColorCode(colorType: PngColorType): UInt8 {
    match (colorType) {
        case Grayscale => UInt8(0)
        case Truecolor => UInt8(2)
        case Indexed => UInt8(3)
        case GrayscaleAlpha => UInt8(4)
        case TruecolorAlpha => UInt8(6)
    }
}

private func makePackingIhdrChunk(
    width: UInt32,
    bitDepth: UInt8,
    colorType: PngColorType
): Array<Byte> {
    let data = Array<Byte>(13, repeat: 0)
    let widthBytes = writeUInt32Be(width)
    let heightBytes = writeUInt32Be(UInt32(1))
    var index: Int64 = 0
    while (index < 4) {
        data[index] = widthBytes[index]
        data[index + 4] = heightBytes[index]
        index += 1
    }
    data[8] = bitDepth
    data[9] = packingColorCode(colorType)
    makePackingChunk(PNG_CHUNK_IHDR, data)
}

private func packingIhdr(
    bitDepth: UInt8,
    colorType: PngColorType
): PngIhdr {
    readPngIhdr(
        joinPackingBytes(
            PNG_SIGNATURE,
            makePackingIhdrChunk(UInt32(8), bitDepth, colorType)
        )
    )
}

private func packingDecoded(): PngDecodedRows {
    var png = joinPackingBytes(
        PNG_SIGNATURE,
        makePackingIhdrChunk(UInt32(8), UInt8(1), Grayscale)
    )
    png = joinPackingBytes(
        png,
        makePackingChunk(PNG_CHUNK_IDAT, PACKING_GRAY1_ZLIB)
    )
    png = joinPackingBytes(png, makePackingChunk(PNG_CHUNK_IEND, []))
    decodePngNonInterlaced(png)
}

private func packSwapDecoded(): PngDecodedRows {
    var png = joinPackingBytes(
        PNG_SIGNATURE,
        makePackingIhdrChunk(UInt32(8), UInt8(1), Grayscale)
    )
    png = joinPackingBytes(
        png,
        makePackingChunk(PNG_CHUNK_IDAT, PACKSWAP_GRAY1_ZLIB)
    )
    png = joinPackingBytes(png, makePackingChunk(PNG_CHUNK_IEND, []))
    decodePngNonInterlaced(png)
}

private func packingInitializationForSourceDepth(
    bitDepth: UInt8
): PngReadTransformInitialization {
    let state = PngReadTransformState()
    state.markIhdrRead(packingIhdr(bitDepth, Grayscale))
    @Assert(state.setPacking(), true)
    initializePngReadTransformations(state, packingDecoded())
}

@Test
public class PngInitializedUnpackPipelineTestSuite {
    @TestCase
    public func gatesPackingOnKnownSubByteIhdrDepth(): Unit {
        let beforeIhdr = PngReadTransformState()
        @Assert(beforeIhdr.setPacking(), false)
        @Assert(
            beforeIhdr.lastApplicationError().toString(),
            "INVALID_BEFORE_IHDR"
        )

        let depths: Array<UInt8> = [1, 2, 4]
        var index: Int64 = 0
        while (index < depths.size) {
            let state = PngReadTransformState()
            state.markIhdrRead(packingIhdr(depths[index], Grayscale))
            @Assert(state.setPacking(), true)
            @Assert(state.packingEnabled(), true)
            index += 1
        }

        let byteDepth = PngReadTransformState()
        byteDepth.markIhdrRead(packingIhdr(UInt8(8), Grayscale))
        @Assert(byteDepth.setPacking(), true)
        @Assert(byteDepth.packingEnabled(), false)

        let wordDepth = PngReadTransformState()
        wordDepth.markIhdrRead(packingIhdr(UInt8(16), Grayscale))
        @Assert(wordDepth.setPacking(), true)
        @Assert(wordDepth.packingEnabled(), false)

        let colorOnly = PngReadTransformState()
        colorOnly.markIhdrRead(Grayscale)
        @Assert(colorOnly.setPacking(), true)
        @Assert(colorOnly.packingEnabled(), false)
    }

    @TestCase
    public func snapshotsPackingAfterUnshiftBeforeBgr(): Unit {
        let decoded = packingDecoded()
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(state.setInvertMono(), true)
        @Assert(
            state.setShift(PngSignificantBits(1, 0, 0, 0, 0)),
            true
        )
        @Assert(state.setPacking(), true)
        @Assert(state.setBgr(), true)

        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.stageCount(), Int64(4))
        @Assert(initialized.stage(0).toString(), "INVERT_MONO")
        @Assert(initialized.stage(1).toString(), "UNSHIFT")
        @Assert(initialized.stage(2).toString(), "UNPACK")
        @Assert(initialized.stage(3).toString(), "BGR")
        @Assert(initialized.packingEnabled(), true)

        @Assert(state.setPacking(), false)
        @Assert(
            state.lastApplicationError().toString(),
            "INVALID_AFTER_ROW_INITIALIZATION"
        )
        @Assert(initialized.packingEnabled(), true)
    }

    @TestCase
    public func unpacksGrayAndIndexedRowsWithExactInfo(): Unit {
        let initialized = packingInitializationForSourceDepth(UInt8(1))

        let gray1 = applyInitializedPngUnpackStage(
            initialized,
            PngReadRowInfo(UInt32(8), UInt8(1), Grayscale),
            [0xb2]
        )
        let gray1Expected: Array<Byte> = [1, 0, 1, 1, 0, 0, 1, 0]
        @Assert(gray1.row(), gray1Expected)
        @Assert(gray1.info.bitDepth, UInt8(8))
        @Assert(gray1.info.pixelDepth, UInt16(8))
        @Assert(gray1.info.rowBytes, UInt64(8))

        let indexed2 = applyInitializedPngUnpackStage(
            initialized,
            PngReadRowInfo(UInt32(4), UInt8(2), Indexed),
            [0x1b]
        )
        let indexed2Expected: Array<Byte> = [0, 1, 2, 3]
        @Assert(indexed2.row(), indexed2Expected)
        @Assert(indexed2.info.bitDepth, UInt8(8))
        @Assert(indexed2.info.colorType.toString(), "INDEXED")
        @Assert(indexed2.info.rowBytes, UInt64(4))

        let gray4 = applyInitializedPngUnpackStage(
            initialized,
            PngReadRowInfo(UInt32(3), UInt8(4), Grayscale),
            [0xa5, 0xf0]
        )
        let gray4Expected: Array<Byte> = [10, 5, 15]
        @Assert(gray4.row(), gray4Expected)
        @Assert(gray4.info.bitDepth, UInt8(8))
        @Assert(gray4.info.rowBytes, UInt64(3))

        let projected = projectPngReadTransformInfo(initialized, packingDecoded())
        @Assert(projected.bitDepth, UInt8(8))
        @Assert(projected.pixelDepth, UInt16(8))
        @Assert(projected.rowBytes, UInt64(8))
    }

    @TestCase
    public func preservesOwnedNoOpsForDisabledAndUnsupportedRows(): Unit {
        let disabled8 = packingInitializationForSourceDepth(UInt8(8))
        let byteSource: Array<Byte> = [0x7f]
        let byteRow = applyInitializedPngUnpackStage(
            disabled8,
            PngReadRowInfo(UInt32(1), UInt8(8), Grayscale),
            byteSource
        )
        byteSource[0] = UInt8(0)
        let byteExpected: Array<Byte> = [0x7f]
        @Assert(byteRow.row(), byteExpected)
        @Assert(byteRow.info.bitDepth, UInt8(8))

        let disabled16 = packingInitializationForSourceDepth(UInt8(16))
        let wordSource: Array<Byte> = [0x12, 0x34]
        let wordRow = applyInitializedPngUnpackStage(
            disabled16,
            PngReadRowInfo(UInt32(1), UInt8(16), Grayscale),
            wordSource
        )
        wordSource[0] = UInt8(0)
        let wordExpected: Array<Byte> = [0x12, 0x34]
        @Assert(wordRow.row(), wordExpected)
        @Assert(wordRow.info.bitDepth, UInt8(16))

        let enabled = packingInitializationForSourceDepth(UInt8(1))
        let unsupportedSource: Array<Byte> = [1, 2, 3]
        let unsupported = applyInitializedPngUnpackStage(
            enabled,
            PngReadRowInfo(UInt32(1), UInt8(8), Truecolor),
            unsupportedSource
        )
        unsupportedSource[0] = UInt8(9)
        let unsupportedExpected: Array<Byte> = [1, 2, 3]
        @Assert(unsupported.row(), unsupportedExpected)
    }

    @TestCase
    public func validatesMalformedRowsBeforeStageSelection(): Unit {
        let enabled = packingInitializationForSourceDepth(UInt8(1))
        try {
            applyInitializedPngUnpackStage(
                enabled,
                PngReadRowInfo(UInt32(9), UInt8(1), Grayscale),
                [0xff]
            )
            @Fail("enabled unpack should reject malformed packed rows")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
        }

        let disabled = packingInitializationForSourceDepth(UInt8(8))
        try {
            applyInitializedPngUnpackStage(
                disabled,
                PngReadRowInfo(UInt32(2), UInt8(8), Grayscale),
                [0xff]
            )
            @Fail("disabled unpack should validate malformed rows first")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func appliesWholeImagePackingAndLimitsGrowth(): Unit {
        let decoded = packingDecoded()
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(state.setPacking(), true)
        let transformed = transformPngRowsInitialized(
            decoded,
            state,
            PngReadLimits(
                UInt32(8_000_000),
                UInt32(100),
                UInt32(100),
                UInt64(1024),
                UInt64(1024),
                UInt64(8)
            )
        )
        let expected: Array<Byte> = [0, 0, 0, 0, 0, 0, 0, 0]
        @Assert(transformed.row(0), expected)
        @Assert(transformed.info.bitDepth, UInt8(8))
        @Assert(transformed.info.rowBytes, UInt64(8))

        let limitedState = PngReadTransformState()
        limitedState.markIhdrRead(decoded.ihdr)
        @Assert(limitedState.setPacking(), true)
        try {
            transformPngRowsInitialized(
                decoded,
                limitedState,
                PngReadLimits(
                    UInt32(8_000_000),
                    UInt32(100),
                    UInt32(100),
                    UInt64(1024),
                    UInt64(1024),
                    UInt64(7)
                )
            )
            @Fail("unpack growth should count against transformed-byte limits")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "DECODE_LIMIT_EXCEEDED")
        }
    }

    @TestCase
    public func gatesAndSnapshotsPackSwapAfterBgrBeforeFiller(): Unit {
        let beforeIhdr = PngReadTransformState()
        @Assert(beforeIhdr.setPackSwap(), false)
        @Assert(
            beforeIhdr.lastApplicationError().toString(),
            "INVALID_BEFORE_IHDR"
        )

        let depths: Array<UInt8> = [1, 2, 4]
        var index: Int64 = 0
        while (index < depths.size) {
            let state = PngReadTransformState()
            state.markIhdrRead(packingIhdr(depths[index], Grayscale))
            @Assert(state.setPackSwap(), true)
            @Assert(state.packSwapEnabled(), true)
            index += 1
        }

        let byteDepth = PngReadTransformState()
        byteDepth.markIhdrRead(packingIhdr(UInt8(8), Grayscale))
        @Assert(byteDepth.setPackSwap(), true)
        @Assert(byteDepth.packSwapEnabled(), false)

        let colorOnly = PngReadTransformState()
        colorOnly.markIhdrRead(Grayscale)
        @Assert(colorOnly.setPackSwap(), true)
        @Assert(colorOnly.packSwapEnabled(), false)

        let decoded = packSwapDecoded()
        let ordered = PngReadTransformState()
        ordered.markIhdrRead(decoded.ihdr)
        @Assert(ordered.setBgr(), true)
        @Assert(ordered.setPackSwap(), true)
        @Assert(ordered.setFiller(UInt16(0xff), true), true)
        let initialized = initializePngReadTransformations(ordered, decoded)
        @Assert(initialized.stageCount(), Int64(3))
        @Assert(initialized.stage(0).toString(), "BGR")
        @Assert(initialized.stage(1).toString(), "PACK_SWAP")
        @Assert(initialized.stage(2).toString(), "FILLER")
        @Assert(initialized.packSwapEnabled(), true)

        @Assert(ordered.setPackSwap(), false)
        @Assert(
            ordered.lastApplicationError().toString(),
            "INVALID_AFTER_ROW_INITIALIZATION"
        )
        @Assert(initialized.packSwapEnabled(), true)
    }

    @TestCase
    public func appliesPackSwapAndPackingInteractionInInitializedOrder(): Unit {
        let decoded = packSwapDecoded()
        let packSwapOnly = PngReadTransformState()
        packSwapOnly.markIhdrRead(decoded.ihdr)
        @Assert(packSwapOnly.setPackSwap(), true)
        let transformed = transformPngRowsInitialized(decoded, packSwapOnly)
        let swappedExpected: Array<Byte> = [0x4d]
        @Assert(transformed.row(0), swappedExpected)
        @Assert(transformed.info.bitDepth, UInt8(1))
        @Assert(transformed.info.rowBytes, UInt64(1))

        let combinedState = PngReadTransformState()
        combinedState.markIhdrRead(decoded.ihdr)
        @Assert(combinedState.setPacking(), true)
        @Assert(combinedState.setPackSwap(), true)
        let combinedInitialization = initializePngReadTransformations(
            combinedState,
            decoded
        )
        @Assert(combinedInitialization.stageCount(), Int64(2))
        @Assert(combinedInitialization.stage(0).toString(), "UNPACK")
        @Assert(combinedInitialization.stage(1).toString(), "PACK_SWAP")

        let combined = applyInitializedPngReadStages(
            combinedInitialization,
            PngReadRowInfo(UInt32(8), UInt8(1), Grayscale),
            [0xb2]
        )
        let unpackedExpected: Array<Byte> = [1, 0, 1, 1, 0, 0, 1, 0]
        @Assert(combined.row(), unpackedExpected)
        @Assert(combined.info.bitDepth, UInt8(8))
        @Assert(combined.info.rowBytes, UInt64(8))
    }

    @TestCase
    public func validatesPackSwapRowsBeforeStageSelection(): Unit {
        let state = PngReadTransformState()
        state.markIhdrRead(packingIhdr(UInt8(8), Grayscale))
        @Assert(state.setPackSwap(), true)
        let disabled = initializePngReadTransformations(state, packingDecoded())
        try {
            applyInitializedPngPackSwapStage(
                disabled,
                PngReadRowInfo(UInt32(2), UInt8(8), Grayscale),
                [0xff]
            )
            @Fail("disabled PackSwap should validate malformed rows first")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
        }
    }
}
