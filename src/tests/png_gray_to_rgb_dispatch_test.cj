package libpng4cj.tests

import libpng4cj.*

private let GRAY_DISPATCH_ALPHA8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0xe7, 0xe0, 0xe4, 0x02,
    0x00, 0x00, 0x55, 0x00, 0x23
]

private let GRAY_DISPATCH_RGBA8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private func joinGrayDispatchBytes(
    left: Array<Byte>,
    right: Array<Byte>
): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: 0)
    var index: Int64 = 0
    while (index < left.size) {
        out[index] = left[index]
        index += 1
    }
    var rightIndex: Int64 = 0
    while (rightIndex < right.size) {
        out[left.size + rightIndex] = right[rightIndex]
        rightIndex += 1
    }
    out
}

private func makeGrayDispatchChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinGrayDispatchBytes(
        joinGrayDispatchBytes(
            joinGrayDispatchBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makeGrayDispatchPng(): Array<Byte> {
    let ihdr = Array<Byte>(13, repeat: 0)
    ihdr[3] = UInt8(2)
    ihdr[7] = UInt8(1)
    ihdr[8] = UInt8(8)
    ihdr[9] = UInt8(4)
    var png = joinGrayDispatchBytes(
        PNG_SIGNATURE,
        makeGrayDispatchChunk(PNG_CHUNK_IHDR, ihdr)
    )
    png = joinGrayDispatchBytes(
        png,
        makeGrayDispatchChunk(PNG_CHUNK_IDAT, GRAY_DISPATCH_ALPHA8_ZLIB)
    )
    joinGrayDispatchBytes(
        png,
        makeGrayDispatchChunk(PNG_CHUNK_IEND, [])
    )
}

private func makeColorDispatchPng(): Array<Byte> {
    let ihdr = Array<Byte>(13, repeat: 0)
    ihdr[3] = UInt8(2)
    ihdr[7] = UInt8(1)
    ihdr[8] = UInt8(8)
    ihdr[9] = UInt8(6)
    var png = joinGrayDispatchBytes(
        PNG_SIGNATURE,
        makeGrayDispatchChunk(PNG_CHUNK_IHDR, ihdr)
    )
    png = joinGrayDispatchBytes(
        png,
        makeGrayDispatchChunk(PNG_CHUNK_IDAT, GRAY_DISPATCH_RGBA8_ZLIB)
    )
    joinGrayDispatchBytes(
        png,
        makeGrayDispatchChunk(PNG_CHUNK_IEND, [])
    )
}

private func grayDispatchStageIndex(
    initialization: PngReadTransformInitialization,
    expected: PngReadTransformStage
): Int64 {
    var index: Int64 = 0
    while (index < initialization.stageCount()) {
        if (initialization.stage(index) == expected) {
            return index
        }
        index += 1
    }
    Int64(-1)
}

private func grayDispatchState(
    decoded: PngDecodedRows,
    background: PngBackground,
    needExpand: Bool,
    expand16: Bool
): PngReadTransformState {
    let state = PngReadTransformState()
    state.markIhdrRead(decoded.ihdr)
    @Assert(
        state.setBackgroundFixed(
            background,
            BackgroundGammaScreen,
            needExpand,
            PNG_FP_1
        ),
        true
    )
    @Assert(state.setGrayToRgb(), true)
    if (expand16) {
        @Assert(state.setExpand16(), true)
    }
    state
}

@Test
public class PngGrayToRgbDispatchTestSuite {
    @TestCase
    public func placesGrayToRgbBeforeComposeForNonGrayBackground(): Unit {
        let decoded = decodePngNonInterlaced(makeGrayDispatchPng())
        let state = grayDispatchState(
            decoded,
            PngBackground(
                UInt8(0), UInt16(200), UInt16(40), UInt16(50), UInt16(60)
            ),
            false,
            false
        )
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.backgroundIsGray(), false)
        @Assert(initialized.grayToRgbAfterExpand16(), false)
        @Assert(
            grayDispatchStageIndex(initialized, ReadStageGrayToRgb) <
                grayDispatchStageIndex(initialized, ReadStageCompose),
            true
        )

        let transformed = applyInitializedPngReadStages(
            initialized,
            PngReadRowInfo(UInt32(1), UInt8(8), GrayscaleAlpha),
            [UInt8(100), UInt8(0)]
        )
        let expected: Array<Byte> = [40, 50, 60]
        @Assert(transformed.info.colorType, Truecolor)
        @Assert(transformed.row(), expected)
    }

    @TestCase
    public func placesGrayToRgbAfterComposeForEqualRgbBackground(): Unit {
        let decoded = decodePngNonInterlaced(makeGrayDispatchPng())
        let state = grayDispatchState(
            decoded,
            PngBackground(
                UInt8(0), UInt16(200), UInt16(40), UInt16(40), UInt16(40)
            ),
            false,
            false
        )
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.backgroundIsGray(), true)
        @Assert(initialized.grayToRgbAfterExpand16(), true)
        @Assert(initialized.background().gray, UInt16(40))
        @Assert(
            grayDispatchStageIndex(initialized, ReadStageGrayToRgb) >
                grayDispatchStageIndex(initialized, ReadStageCompose),
            true
        )

        let transformed = applyInitializedPngReadStages(
            initialized,
            PngReadRowInfo(UInt32(1), UInt8(8), GrayscaleAlpha),
            [UInt8(100), UInt8(0)]
        )
        let expected: Array<Byte> = [40, 40, 40]
        @Assert(transformed.info.colorType, Truecolor)
        @Assert(transformed.row(), expected)
    }

    @TestCase
    public func classifiesExpandedGrayBackgroundAndRunsAfterExpand16(): Unit {
        let decoded = decodePngNonInterlaced(makeGrayDispatchPng())
        let state = grayDispatchState(
            decoded,
            PngBackground(
                UInt8(0), UInt16(30), UInt16(1), UInt16(2), UInt16(3)
            ),
            true,
            true
        )
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.backgroundIsGray(), true)
        @Assert(initialized.background().gray, UInt16(30))
        @Assert(initialized.background().red, UInt16(30))
        @Assert(
            grayDispatchStageIndex(initialized, ReadStageGrayToRgb) >
                grayDispatchStageIndex(initialized, ReadStageExpand16),
            true
        )

        let transformed = applyInitializedPngReadStages(
            initialized,
            PngReadRowInfo(UInt32(1), UInt8(8), GrayscaleAlpha),
            [UInt8(100), UInt8(0)]
        )
        let expected: Array<Byte> = [30, 30, 30, 30, 30, 30]
        @Assert(transformed.info.bitDepth, UInt8(16))
        @Assert(transformed.info.colorType, Truecolor)
        @Assert(transformed.row(), expected)
    }

    @TestCase
    public func doesNotApplyEqualRgbShortcutDuringColorBackgroundExpand(): Unit {
        let decoded = decodePngNonInterlaced(makeColorDispatchPng())
        let state = grayDispatchState(
            decoded,
            PngBackground(
                UInt8(0), UInt16(20), UInt16(40), UInt16(40), UInt16(40)
            ),
            true,
            false
        )
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.backgroundExpandEnabled(), true)
        @Assert(initialized.backgroundIsGray(), false)
        @Assert(initialized.grayToRgbAfterExpand16(), false)
        @Assert(
            grayDispatchStageIndex(initialized, ReadStageGrayToRgb) <
                grayDispatchStageIndex(initialized, ReadStageCompose),
            true
        )
    }

    @TestCase
    public func transformsWholeImageWithMutuallyExclusivePlacement(): Unit {
        let decoded = decodePngNonInterlaced(makeGrayDispatchPng())
        let state = grayDispatchState(
            decoded,
            PngBackground(
                UInt8(0), UInt16(200), UInt16(40), UInt16(40), UInt16(40)
            ),
            false,
            false
        )
        let transformed = transformPngRowsInitialized(decoded, state)
        @Assert(transformed.info.colorType, Truecolor)
        @Assert(transformed.info.channels, UInt8(3))
        @Assert(transformed.row(0).size, Int64(6))
    }
}
