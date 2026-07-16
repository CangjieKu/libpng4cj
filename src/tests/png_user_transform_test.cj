package libpng4cj.tests

import libpng4cj.*

private let USER_RGB2X2_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0x60, 0xe7, 0xe0, 0xe4, 0xe2, 0xe6,
    0x01, 0x00, 0x01, 0x8f, 0x00, 0x4f
]

private let USER_GRAY16_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x10, 0x32, 0x01, 0x00, 0x00, 0x5b, 0x00, 0x47
]

private class UserTransformRecorder {
    var calls: Int64 = 0
    var firstRowNumber: UInt32 = UInt32(99)
    var secondRowNumber: UInt32 = UInt32(99)
    var lastPassNumber: UInt8 = UInt8(99)
    private var ownedLastRow: Array<Byte> = Array<Byte>()

    func record(context: PngReadUserTransformContext, row: Array<Byte>): Unit {
        if (calls == 0) {
            firstRowNumber = context.rowNumber
        } else if (calls == 1) {
            secondRowNumber = context.rowNumber
        }
        lastPassNumber = context.passNumber
        ownedLastRow = row.clone()
        calls += 1
    }

    func lastRow(): Array<Byte> {
        ownedLastRow.clone()
    }
}

private func joinUserTransformBytes(
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

private func makeUserTransformChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinUserTransformBytes(
        joinUserTransformBytes(
            joinUserTransformBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func userTransformColorCode(colorType: PngColorType): UInt8 {
    match (colorType) {
        case Grayscale => UInt8(0)
        case Truecolor => UInt8(2)
        case Indexed => UInt8(3)
        case GrayscaleAlpha => UInt8(4)
        case TruecolorAlpha => UInt8(6)
    }
}

private func makeUserTransformIhdr(
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
    data[9] = userTransformColorCode(colorType)
    makeUserTransformChunk(PNG_CHUNK_IHDR, data)
}

private func userTransformDecoded(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8,
    colorType: PngColorType,
    compressed: Array<Byte>
): PngDecodedRows {
    var png = PNG_SIGNATURE.clone()
    png = joinUserTransformBytes(
        png,
        makeUserTransformIhdr(width, height, bitDepth, colorType)
    )
    png = joinUserTransformBytes(
        png,
        makeUserTransformChunk(PNG_CHUNK_IDAT, compressed)
    )
    png = joinUserTransformBytes(
        png,
        makeUserTransformChunk(PNG_CHUNK_IEND, [])
    )
    decodePngNonInterlaced(png)
}

private func userRgbDecoded(): PngDecodedRows {
    userTransformDecoded(
        UInt32(2),
        UInt32(2),
        UInt8(8),
        Truecolor,
        USER_RGB2X2_ZLIB
    )
}

private func userGray16Decoded(): PngDecodedRows {
    userTransformDecoded(
        UInt32(1),
        UInt32(1),
        UInt8(16),
        Grayscale,
        USER_GRAY16_ZLIB
    )
}

@Test
public class PngUserTransformTestSuite {
    @TestCase
    public func snapshotsCallbackAndProjectsConfiguredInfo(): Unit {
        let decoded = userRgbDecoded()
        let callback: (
            PngReadUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngReadUserTransformResult = {
            _, info, row => PngReadUserTransformResult(info, row)
        }
        let state = PngReadTransformState()
        @Assert(state.setUserTransformInfo(Int64(16), Int64(2)), true)
        @Assert(state.setReadUserTransform(callback), true)
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.stageCount(), Int64(1))
        @Assert(initialized.stage(0).toString(), "USER_TRANSFORM")
        @Assert(ReadStagePaletteIndexCheck.ordinalValue(), Int64(17))
        @Assert(ReadStageUserTransform.ordinalValue(), Int64(18))
        @Assert(initialized.userTransformDepth(), UInt8(16))
        @Assert(initialized.userTransformChannels(), UInt8(2))

        let projected = projectPngReadTransformInfo(initialized, decoded)
        @Assert(projected.bitDepth, UInt8(16))
        @Assert(projected.channels, UInt8(2))
        @Assert(projected.pixelDepth, UInt16(32))
        @Assert(projected.rowBytes, UInt64(8))

        @Assert(state.setUserTransformInfo(UInt8(8), UInt8(1)), false)
        @Assert(state.setReadUserTransform(callback), false)
        @Assert(
            state.lastApplicationError().toString(),
            "INVALID_AFTER_ROW_INITIALIZATION"
        )
    }

    @TestCase
    public func infoWithoutCallbackDoesNotChangeProjectedShape(): Unit {
        let decoded = userRgbDecoded()
        let state = PngReadTransformState()
        @Assert(state.setUserTransformInfo(UInt8(16), UInt8(1)), true)
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.stageCount(), Int64(0))
        let projected = projectPngReadTransformInfo(initialized, decoded)
        @Assert(projected.bitDepth, UInt8(8))
        @Assert(projected.channels, UInt8(3))
        @Assert(projected.rowBytes, UInt64(6))
    }

    @TestCase
    public func callbackInputAndResultAreCopyOwned(): Unit {
        let decoded = userRgbDecoded()
        let callback: (
            PngReadUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngReadUserTransformResult = {
            _, info, row =>
                row[0] = UInt8(99)
                PngReadUserTransformResult(info, row)
        }
        let state = PngReadTransformState()
        @Assert(state.setReadUserTransform(callback), true)
        let initialized = initializePngReadTransformations(state, decoded)
        let source: Array<Byte> = [1, 2, 3, 4, 5, 6]
        let transformed = applyInitializedPngReadStages(
            initialized,
            PngReadRowInfo(UInt32(2), UInt8(8), Truecolor),
            source
        )
        let sourceExpected: Array<Byte> = [1, 2, 3, 4, 5, 6]
        let transformedExpected: Array<Byte> = [99, 2, 3, 4, 5, 6]
        @Assert(source, sourceExpected)
        @Assert(transformed.row(), transformedExpected)
        let leaked = transformed.row()
        leaked[0] = UInt8(0)
        @Assert(transformed.row(), transformedExpected)
    }

    @TestCase
    public func configuredShapeOverridesCallbackInfoAndValidatesRowBytes(): Unit {
        let decoded = userRgbDecoded()
        let validCallback: (
            PngReadUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngReadUserTransformResult = {
            _, info, _ =>
                PngReadUserTransformResult(
                    PngReadRowInfo(info.width, UInt8(8), info.colorType, UInt8(1)),
                    [0x12, 0x34, 0x56, 0x78]
                )
        }
        let validState = PngReadTransformState()
        @Assert(validState.setUserTransformInfo(UInt8(16), UInt8(1)), true)
        @Assert(validState.setReadUserTransform(validCallback), true)
        let valid = applyInitializedPngReadStages(
            initializePngReadTransformations(validState, decoded),
            PngReadRowInfo(UInt32(2), UInt8(8), Truecolor),
            [1, 2, 3, 4, 5, 6]
        )
        @Assert(valid.info.bitDepth, UInt8(16))
        @Assert(valid.info.channels, UInt8(1))
        @Assert(valid.info.rowBytes, UInt64(4))

        let invalidCallback: (
            PngReadUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngReadUserTransformResult = {
            _, info, _ => PngReadUserTransformResult(info, [1])
        }
        let invalidState = PngReadTransformState()
        @Assert(invalidState.setReadUserTransform(invalidCallback), true)
        let invalid = initializePngReadTransformations(invalidState, decoded)
        try {
            applyInitializedPngReadStages(
                invalid,
                PngReadRowInfo(UInt32(2), UInt8(8), Truecolor),
                [1, 2, 3, 4, 5, 6]
            )
            @Fail("user transform should reject a mismatched returned row")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
            @Assert(error.offset, Int64(1))
        }
    }

    @TestCase
    public func executesAfterByteSwapAndReceivesExplicitContext(): Unit {
        let decoded = userGray16Decoded()
        let recorder = UserTransformRecorder()
        let callback: (
            PngReadUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngReadUserTransformResult = {
            context, info, row =>
                recorder.record(context, row)
                PngReadUserTransformResult(info, row)
        }
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(state.setSwap(), true)
        @Assert(state.setReadUserTransform(callback), true)
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.stageCount(), Int64(2))
        @Assert(initialized.stage(0).toString(), "BYTE_SWAP")
        @Assert(initialized.stage(1).toString(), "USER_TRANSFORM")

        let transformed = applyInitializedPngReadStages(
            initialized,
            PngReadRowInfo(decoded.ihdr),
            decoded.row(0),
            PngReadUserTransformContext(UInt32(7), UInt8(3))
        )
        let expected: Array<Byte> = [0x34, 0x12]
        @Assert(recorder.lastRow(), expected)
        @Assert(transformed.row(), expected)
        @Assert(recorder.firstRowNumber, UInt32(7))
        @Assert(recorder.lastPassNumber, UInt8(3))
    }

    @TestCase
    public func transformsWholeImageWithRowContextAndLimits(): Unit {
        let decoded = userRgbDecoded()
        let recorder = UserTransformRecorder()
        let callback: (
            PngReadUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngReadUserTransformResult = {
            context, info, row =>
                recorder.record(context, row)
                let output = Array<Byte>(Int64(info.width), repeat: 0)
                var pixel: Int64 = 0
                while (pixel < Int64(info.width)) {
                    output[pixel] = row[pixel * Int64(info.channels)]
                    pixel += 1
                }
                PngReadUserTransformResult(
                    PngReadRowInfo(info.width, info.bitDepth, info.colorType, UInt8(1)),
                    output
                )
        }
        let state = PngReadTransformState()
        @Assert(state.setUserTransformInfo(UInt8(8), UInt8(1)), true)
        @Assert(state.setReadUserTransform(callback), true)
        let transformed = transformPngRowsInitialized(decoded, state)
        @Assert(transformed.rowCount(), Int64(2))
        let row0: Array<Byte> = [1, 4]
        let row1: Array<Byte> = [7, 10]
        @Assert(transformed.row(0), row0)
        @Assert(transformed.row(1), row1)
        @Assert(transformed.info.channels, UInt8(1))
        @Assert(transformed.info.rowBytes, UInt64(2))
        @Assert(recorder.calls, Int64(2))
        @Assert(recorder.firstRowNumber, UInt32(0))
        @Assert(recorder.secondRowNumber, UInt32(1))
        @Assert(recorder.lastPassNumber, UInt8(0))

        let limitedState = PngReadTransformState()
        @Assert(limitedState.setUserTransformInfo(UInt8(8), UInt8(1)), true)
        @Assert(limitedState.setReadUserTransform(callback), true)
        try {
            transformPngRowsInitialized(
                decoded,
                limitedState,
                PngReadLimits(
                    PNG_UINT_31_MAX,
                    PNG_UINT_31_MAX,
                    PNG_UINT_31_MAX,
                    PNG_DEFAULT_MAX_COMPRESSED_BYTES,
                    PNG_DEFAULT_MAX_INFLATED_BYTES,
                    UInt64(3)
                )
            )
            @Fail("user transformed rows should honor the transformed limit")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "DECODE_LIMIT_EXCEEDED")
        }
    }

    @TestCase
    public func rejectsOutOfRangeUserInfoArguments(): Unit {
        let state = PngReadTransformState()
        try {
            state.setUserTransformInfo(Int64(256), Int64(1))
            @Fail("user transform depth should reject values above UInt8")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
            @Assert(error.offset, Int64(256))
        }
    }
}
