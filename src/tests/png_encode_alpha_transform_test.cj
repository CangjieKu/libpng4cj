package libpng4cj.tests

import libpng4cj.*

private let ENCODE_ALPHA_RGBA_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0xe0, 0x12, 0x91, 0xd3, 0x00,
    0x00, 0x00, 0xcd, 0x00, 0x65
]

private func joinEncodeAlphaBytes(
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

private func makeEncodeAlphaChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinEncodeAlphaBytes(
        joinEncodeAlphaBytes(
            joinEncodeAlphaBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func encodeAlphaDecoded(): PngDecodedRows {
    let ihdr = Array<Byte>(13, repeat: 0)
    ihdr[3] = UInt8(1)
    ihdr[7] = UInt8(1)
    ihdr[8] = UInt8(8)
    ihdr[9] = UInt8(6)
    var png = joinEncodeAlphaBytes(
        PNG_SIGNATURE,
        makeEncodeAlphaChunk(PNG_CHUNK_IHDR, ihdr)
    )
    png = joinEncodeAlphaBytes(
        png,
        makeEncodeAlphaChunk(PNG_CHUNK_IDAT, ENCODE_ALPHA_RGBA_ZLIB)
    )
    png = joinEncodeAlphaBytes(
        png,
        makeEncodeAlphaChunk(PNG_CHUNK_IEND, [])
    )
    decodePngNonInterlaced(png)
}

@Test
public class PngEncodeAlphaTransformTestSuite {
    @TestCase
    public func encodesOnlyEightBitGaAndRgbaAlpha(): Unit {
        let table = pngBuildGamma8BitTables(
            Int32(45455), Int32(220000), true
        ).fromLinear()
        let ga = pngDoEncodeAlpha(
            PngReadRowInfo(UInt32(2), UInt8(8), GrayscaleAlpha),
            [10, 64, 20, 192],
            table
        )
        @Assert(ga.row(), [10, table.value(UInt8(64)), 20, table.value(UInt8(192))])

        let rgba = pngDoEncodeAlpha(
            PngReadRowInfo(UInt32(1), UInt8(8), TruecolorAlpha),
            [10, 20, 30, 128],
            table
        )
        @Assert(rgba.row(), [10, 20, 30, table.value(UInt8(128))])
    }

    @TestCase
    public func encodesSixteenBitAlphaInNetworkOrder(): Unit {
        let table = pngBuildGamma16BitTables(
            UInt8(0), Int32(45455), Int32(220000), true, false
        ).fromLinear()
        let result = pngDoEncodeAlpha(
            PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha),
            [0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0x40, 0x00],
            table
        )
        let expected = table.value(UInt16(0x4000))
        @Assert(result.row(), [
            0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc,
            UInt8(expected >> UInt16(8)), UInt8(expected & UInt16(0xff))
        ])
    }

    @TestCase
    public func preservesOwnedUnsupportedRowsAndMalformedPriority(): Unit {
        let table = pngBuildGamma8BitTable(Int32(220000))
        let source: Array<Byte> = [10, 20, 30]
        let result = pngDoEncodeAlpha(
            PngReadRowInfo(UInt32(1), UInt8(8), Truecolor),
            source,
            table
        )
        source[0] = UInt8(99)
        let expectedOwned: Array<Byte> = [10, 20, 30]
        @Assert(result.row(), expectedOwned)
        try {
            pngDoEncodeAlpha(
                PngReadRowInfo(UInt32(1), UInt8(8), TruecolorAlpha),
                [1, 2, 3],
                table
            )
            @Fail("malformed encode-alpha row should fail")
        } catch (error: PngFormatException) {
            @Assert(error.kind, InvalidArgument)
        }
    }

    @TestCase
    public func initializesEncodeAfterComposeBeforeReduction(): Unit {
        let decoded = encodeAlphaDecoded()
        let state = PngReadTransformState()
        @Assert(state.setAlphaModeFixed(AlphaBroken, Int32(220000)), true)
        @Assert(state.setScale16(), true)
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.hasStage(ReadStageCompose), true)
        @Assert(initialized.hasStage(ReadStageEncodeAlpha), true)
        @Assert(initialized.encodeAlphaEnabled(), true)
        @Assert(ReadStageEncodeAlpha.ordinalValue(), Int64(22))
        var composeIndex: Int64 = -1
        var encodeIndex: Int64 = -1
        var reduceIndex: Int64 = -1
        var index: Int64 = 0
        while (index < initialized.stageCount()) {
            let stage = initialized.stage(index)
            if (stage == ReadStageCompose) { composeIndex = index }
            if (stage == ReadStageEncodeAlpha) { encodeIndex = index }
            if (stage == ReadStageScale16To8) { reduceIndex = index }
            index += 1
        }
        @Assert(composeIndex < encodeIndex, true)
        @Assert(encodeIndex < reduceIndex, true)
    }

    @TestCase
    public func cancelsIneffectiveEncodeAndOptimizeState(): Unit {
        let decoded = encodeAlphaDecoded()
        let linearState = PngReadTransformState()
        @Assert(linearState.setAlphaModeFixed(AlphaBroken, PNG_FP_1), true)
        let linear = initializePngReadTransformations(linearState, decoded)
        @Assert(linear.encodeAlphaEnabled(), false)
        @Assert(linear.hasStage(ReadStageEncodeAlpha), false)

        let optimizedState = PngReadTransformState()
        @Assert(
            optimizedState.setAlphaModeFixed(AlphaOptimized, PNG_FP_1),
            true
        )
        let optimized = initializePngReadTransformations(
            optimizedState,
            encodeAlphaDecoded()
        )
        @Assert(optimized.optimizeAlphaEnabled(), false)

        let strippedState = PngReadTransformState()
        @Assert(
            strippedState.setAlphaModeFixed(AlphaBroken, Int32(220000)),
            true
        )
        @Assert(strippedState.setStripAlpha(), true)
        let stripped = initializePngReadTransformations(strippedState, decoded)
        @Assert(stripped.encodeAlphaEnabled(), false)
        @Assert(stripped.hasStage(ReadStageEncodeAlpha), false)
    }

    @TestCase
    public func executesWholeImageAndRetainsOutputLimit(): Unit {
        let decoded = encodeAlphaDecoded()
        let state = PngReadTransformState()
        @Assert(state.setAlphaModeFixed(AlphaBroken, Int32(220000)), true)
        let transformed = transformPngRowsInitialized(decoded, state)
        let initializedState = PngReadTransformState()
        @Assert(
            initializedState.setAlphaModeFixed(AlphaBroken, Int32(220000)),
            true
        )
        let initialized = initializePngReadTransformations(
            initializedState,
            decoded
        )
        let expectedAlpha = initialized.gamma8BitTables().fromLinear().value(
            decoded.row(0)[3]
        )
        @Assert(transformed.row(0)[3], expectedAlpha)
        @Assert(transformed.info.rowBytes, UInt64(4))

        let limited = PngReadTransformState()
        @Assert(limited.setAlphaModeFixed(AlphaBroken, Int32(220000)), true)
        try {
            transformPngRowsInitialized(
                decoded,
                limited,
                PngReadLimits(
                    PNG_UINT_31_MAX,
                    PNG_UINT_31_MAX,
                    PNG_UINT_31_MAX,
                    UInt64(1024),
                    UInt64(1024),
                    UInt64(3)
                )
            )
            @Fail("encode-alpha output limit should fail")
        } catch (error: PngFormatException) {
            @Assert(error.kind, DecodeLimitExceeded)
        }
    }
}
