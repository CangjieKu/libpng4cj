package libpng4cj.tests

import libpng4cj.*

private let LATE_GRAY1_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01
]

private let LATE_RGB1_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x06, 0x00, 0x00, 0x0e, 0x00, 0x07
]

private let LATE_GRAY_ALPHA1_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x60, 0x00, 0x00, 0x00, 0x03, 0x00, 0x01
]

private let LATE_RGBA16_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x80, 0x02, 0x00, 0x00, 0x09, 0x00, 0x01
]

private let LATE_RGB16_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x00, 0x03, 0x00, 0x00, 0x07, 0x00, 0x01
]

private let LATE_RGB2X2_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0x60, 0xe7, 0xe0, 0xe4, 0xe2, 0xe6,
    0x01, 0x00, 0x01, 0x8f, 0x00, 0x4f
]

private func joinLateChannelBytes(
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

private func makeLateChannelChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinLateChannelBytes(
        joinLateChannelBytes(
            joinLateChannelBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func lateChannelColorCode(colorType: PngColorType): UInt8 {
    match (colorType) {
        case Grayscale => UInt8(0)
        case Truecolor => UInt8(2)
        case Indexed => UInt8(3)
        case GrayscaleAlpha => UInt8(4)
        case TruecolorAlpha => UInt8(6)
    }
}

private func makeLateChannelIhdr(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8,
    colorType: PngColorType
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
    data[9] = lateChannelColorCode(colorType)
    makeLateChannelChunk(PNG_CHUNK_IHDR, data)
}

private func lateChannelCompressed(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8,
    colorType: PngColorType
): Array<Byte> {
    if (width == UInt32(2) && height == UInt32(2) &&
        colorType == Truecolor) {
        return LATE_RGB2X2_ZLIB.clone()
    }
    if (colorType == GrayscaleAlpha) {
        return LATE_GRAY_ALPHA1_ZLIB.clone()
    }
    if (colorType == TruecolorAlpha && bitDepth == UInt8(16)) {
        return LATE_RGBA16_ZLIB.clone()
    }
    if (colorType == Truecolor && bitDepth == UInt8(16)) {
        return LATE_RGB16_ZLIB.clone()
    }
    if (colorType == Grayscale) {
        return LATE_GRAY1_ZLIB.clone()
    }
    LATE_RGB1_ZLIB.clone()
}

private func lateChannelDecoded(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8,
    colorType: PngColorType
): PngDecodedRows {
    var png = PNG_SIGNATURE.clone()
    png = joinLateChannelBytes(
        png,
        makeLateChannelIhdr(width, height, bitDepth, colorType)
    )
    png = joinLateChannelBytes(
        png,
        makeLateChannelChunk(
            PNG_CHUNK_IDAT,
            lateChannelCompressed(width, height, bitDepth, colorType)
        )
    )
    png = joinLateChannelBytes(png, makeLateChannelChunk(PNG_CHUNK_IEND, []))
    decodePngNonInterlaced(png)
}

private func lateChannelInitialization(
    state: PngReadTransformState,
    bitDepth: UInt8,
    colorType: PngColorType
): PngReadTransformInitialization {
    initializePngReadTransformations(
        state,
        lateChannelDecoded(UInt32(1), UInt32(1), bitDepth, colorType)
    )
}

@Test
public class PngInitializedLateChannelPipelineTestSuite {
    @TestCase
    public func snapshotsLateChannelStateInFrozenOrder(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setInvertAlpha(), true)
        @Assert(
            state.setShift(PngSignificantBits(8, 8, 8, 8, 8)),
            true
        )
        @Assert(
            state.setShift(PngSignificantBits(4, 5, 6, 7, 3)),
            true
        )
        @Assert(state.setAddAlpha(UInt16(0x1234), false), true)
        @Assert(state.setFiller(UInt32(0x00015678), true), true)
        @Assert(state.setSwapAlpha(), true)

        let initialized = lateChannelInitialization(state, UInt8(8), Truecolor)
        @Assert(initialized.stageCount(), Int64(4))
        @Assert(initialized.stage(0).toString(), "INVERT_ALPHA")
        @Assert(initialized.stage(1).toString(), "UNSHIFT")
        @Assert(initialized.stage(2).toString(), "FILLER")
        @Assert(initialized.stage(3).toString(), "SWAP_ALPHA")
        @Assert(initialized.shiftSignificantBits().red, UInt8(5))
        @Assert(initialized.fillerMode().toString(), "ALPHA_AFTER")
        @Assert(initialized.fillerValue(), UInt16(0x5678))
        @Assert(initialized.addAlphaEnabled(), true)
        @Assert(initialized.effectiveOutputHasAlpha, true)

        @Assert(state.setInvertAlpha(), false)
        @Assert(
            state.setShift(PngSignificantBits(1, 1, 1, 1, 1)),
            false
        )
        @Assert(state.setFiller(UInt16(0), false), false)
        @Assert(state.setAddAlpha(UInt16(0), false), false)
        @Assert(state.setSwapAlpha(), false)
        @Assert(
            state.lastApplicationError().toString(),
            "INVALID_AFTER_ROW_INITIALIZATION"
        )
        @Assert(initialized.shiftSignificantBits().red, UInt8(5))
        @Assert(initialized.fillerMode().toString(), "ALPHA_AFTER")
        @Assert(initialized.fillerValue(), UInt16(0x5678))
    }

    @TestCase
    public func invertsAlphaBeforeUnshiftForEightAndSixteenBitRows(): Unit {
        let grayAlphaState = PngReadTransformState()
        @Assert(grayAlphaState.setInvertAlpha(), true)
        @Assert(
            grayAlphaState.setShift(PngSignificantBits(4, 0, 0, 0, 4)),
            true
        )
        let grayAlpha = applyInitializedPngReadStages(
            lateChannelInitialization(grayAlphaState, UInt8(8), GrayscaleAlpha),
            PngReadRowInfo(UInt32(1), UInt8(8), GrayscaleAlpha),
            [0xf0, 0x0f]
        )
        let grayAlphaExpected: Array<Byte> = [0x0f, 0x0f]
        @Assert(grayAlpha.row(), grayAlphaExpected)

        let rgbaState = PngReadTransformState()
        @Assert(rgbaState.setInvertAlpha(), true)
        @Assert(
            rgbaState.setShift(PngSignificantBits(0, 4, 8, 12, 12)),
            true
        )
        let rgba = applyInitializedPngReadStages(
            lateChannelInitialization(rgbaState, UInt8(16), TruecolorAlpha),
            PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha),
            [0xf0, 0x00, 0x0f, 0x00, 0x00, 0xf0, 0x00, 0x0f]
        )
        let rgbaExpected: Array<Byte> = [
            0x00, 0x0f,
            0x00, 0x0f,
            0x00, 0x0f,
            0x0f, 0xff
        ]
        @Assert(rgba.row(), rgbaExpected)
        @Assert(rgba.info.bitDepth, UInt8(16))
        @Assert(rgba.info.colorType.toString(), "TRUECOLOR_ALPHA")
    }

    @TestCase
    public func insertsFillerWithExactEightAndSixteenBitValues(): Unit {
        let grayState = PngReadTransformState()
        @Assert(grayState.setFiller(UInt16(0x01aa), false), true)
        let gray = applyInitializedPngReadStages(
            lateChannelInitialization(grayState, UInt8(8), Grayscale),
            PngReadRowInfo(UInt32(2), UInt8(8), Grayscale),
            [0x11, 0x22]
        )
        let grayExpected: Array<Byte> = [0xaa, 0x11, 0xaa, 0x22]
        @Assert(gray.row(), grayExpected)
        @Assert(gray.info.colorType.toString(), "GRAYSCALE")
        @Assert(gray.info.channels, UInt8(2))
        @Assert(gray.info.rowBytes, UInt64(4))

        let rgbState = PngReadTransformState()
        @Assert(rgbState.setFiller(UInt16(0x1234), true), true)
        let rgb = applyInitializedPngReadStages(
            lateChannelInitialization(rgbState, UInt8(16), Truecolor),
            PngReadRowInfo(UInt32(1), UInt8(16), Truecolor),
            [0x00, 0x01, 0x00, 0x02, 0x00, 0x03]
        )
        let rgbExpected: Array<Byte> = [
            0x00, 0x01,
            0x00, 0x02,
            0x00, 0x03,
            0x12, 0x34
        ]
        @Assert(rgb.row(), rgbExpected)
        @Assert(rgb.info.colorType.toString(), "TRUECOLOR")
        @Assert(rgb.info.channels, UInt8(4))
        @Assert(rgb.info.rowBytes, UInt64(8))
    }

    @TestCase
    public func swapsAddedAlphaWithoutTreatingPlainFillerAsAlpha(): Unit {
        let info = PngReadRowInfo(UInt32(1), UInt8(8), Truecolor)
        let source: Array<Byte> = [1, 2, 3]

        let fillerState = PngReadTransformState()
        @Assert(fillerState.setFiller(UInt16(0x00cc), true), true)
        @Assert(fillerState.setSwapAlpha(), true)
        let filler = applyInitializedPngReadStages(
            lateChannelInitialization(fillerState, UInt8(8), Truecolor),
            info,
            source
        )
        let fillerExpected: Array<Byte> = [1, 2, 3, 0xcc]
        @Assert(filler.row(), fillerExpected)

        let alphaAfterState = PngReadTransformState()
        @Assert(alphaAfterState.setAddAlpha(UInt16(0x00ee), true), true)
        @Assert(alphaAfterState.setSwapAlpha(), true)
        let alphaAfter = applyInitializedPngReadStages(
            lateChannelInitialization(alphaAfterState, UInt8(8), Truecolor),
            info,
            source
        )
        let alphaAfterExpected: Array<Byte> = [0xee, 1, 2, 3]
        @Assert(alphaAfter.row(), alphaAfterExpected)

        let alphaBeforeState = PngReadTransformState()
        @Assert(alphaBeforeState.setAddAlpha(UInt16(0x00dd), false), true)
        @Assert(alphaBeforeState.setSwapAlpha(), true)
        let alphaBefore = applyInitializedPngReadStages(
            lateChannelInitialization(alphaBeforeState, UInt8(8), Truecolor),
            info,
            source
        )
        let alphaBeforeExpected: Array<Byte> = [1, 2, 3, 0xdd]
        @Assert(alphaBefore.row(), alphaBeforeExpected)
        @Assert(alphaBefore.info.colorType.toString(), "TRUECOLOR")
        @Assert(alphaBefore.info.channels, UInt8(4))
    }

    @TestCase
    public func preservesOwnedNoOpsAndMalformedRowPriority(): Unit {
        let disabled = lateChannelInitialization(
            PngReadTransformState(), UInt8(8), Truecolor
        )
        let source: Array<Byte> = [1, 2, 3]
        let unchanged = applyInitializedPngSwapAlphaStage(
            disabled,
            PngReadRowInfo(UInt32(1), UInt8(8), Truecolor),
            source
        )
        source[0] = UInt8(9)
        let unchangedExpected: Array<Byte> = [1, 2, 3]
        @Assert(unchanged.row(), unchangedExpected)

        let unsupportedState = PngReadTransformState()
        @Assert(unsupportedState.setInvertAlpha(), true)
        @Assert(
            unsupportedState.setShift(PngSignificantBits(8, 8, 8, 8, 8)),
            true
        )
        @Assert(unsupportedState.setAddAlpha(UInt16(0xff), true), true)
        @Assert(unsupportedState.setSwapAlpha(), true)
        let unsupportedSource: Array<Byte> = [2, 3]
        let unsupported = applyInitializedPngReadStages(
            lateChannelInitialization(unsupportedState, UInt8(8), Truecolor),
            PngReadRowInfo(UInt32(1), UInt8(8), Truecolor, UInt8(2)),
            unsupportedSource
        )
        unsupportedSource[0] = UInt8(7)
        let unsupportedExpected: Array<Byte> = [2, 3]
        @Assert(unsupported.row(), unsupportedExpected)

        let expandedState = PngReadTransformState()
        @Assert(expandedState.setAddAlpha(UInt16(0xee), true), true)
        @Assert(expandedState.setSwapAlpha(), true)
        let expandedSource: Array<Byte> = [1, 2, 3, 4]
        let unsupportedExpanded = applyInitializedPngReadStages(
            lateChannelInitialization(expandedState, UInt8(8), Truecolor),
            PngReadRowInfo(UInt32(1), UInt8(8), Truecolor, UInt8(4)),
            expandedSource
        )
        expandedSource[0] = UInt8(8)
        let expandedExpected: Array<Byte> = [1, 2, 3, 4]
        @Assert(unsupportedExpanded.row(), expandedExpected)

        try {
            applyInitializedPngFillerStage(
                disabled,
                PngReadRowInfo(UInt32(2), UInt8(8), Truecolor),
                [1, 2, 3]
            )
            @Fail("disabled filler stage should validate malformed rows first")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
            @Assert(
                error.message,
                "PNG transform row length does not match row info"
            )
        }
    }

    @TestCase
    public func appliesWholeImageFillerAndEnforcesOutputLimit(): Unit {
        let decoded = lateChannelDecoded(
            UInt32(2), UInt32(2), UInt8(8), Truecolor
        )
        let state = PngReadTransformState()
        @Assert(state.setFiller(UInt16(0xff), true), true)
        let limits = PngReadLimits(
            UInt32(8_000_000),
            UInt32(100),
            UInt32(100),
            UInt64(1024),
            UInt64(1024),
            UInt64(16)
        )
        let transformed = transformPngRowsInitialized(decoded, state, limits)
        let firstExpected: Array<Byte> = [1, 2, 3, 0xff, 4, 5, 6, 0xff]
        let secondExpected: Array<Byte> = [7, 8, 9, 0xff, 10, 11, 12, 0xff]
        @Assert(transformed.info.channels, UInt8(4))
        @Assert(transformed.info.rowBytes, UInt64(8))
        @Assert(transformed.row(0), firstExpected)
        @Assert(transformed.row(1), secondExpected)

        let limitedState = PngReadTransformState()
        @Assert(limitedState.setFiller(UInt16(0xff), true), true)
        let limited = PngReadLimits(
            UInt32(8_000_000),
            UInt32(100),
            UInt32(100),
            UInt64(1024),
            UInt64(1024),
            UInt64(15)
        )
        try {
            transformPngRowsInitialized(decoded, limitedState, limited)
            @Fail("filler growth should count against transformed-byte limits")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "DECODE_LIMIT_EXCEEDED")
        }
    }
}
