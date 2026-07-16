package libpng4cj.tests

import libpng4cj.*

private let GAMMA_INIT_RGBA_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private func joinGammaInitBytes(
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

private func makeGammaInitChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinGammaInitBytes(
        joinGammaInitBytes(
            joinGammaInitBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makeGammaInitIhdr(): Array<Byte> {
    let data = Array<Byte>(13, repeat: 0)
    let width = writeUInt32Be(UInt32(2))
    let height = writeUInt32Be(UInt32(1))
    var index: Int64 = 0
    while (index < 4) {
        data[index] = width[index]
        data[index + 4] = height[index]
        index += 1
    }
    data[8] = UInt8(8)
    data[9] = UInt8(6)
    makeGammaInitChunk(PNG_CHUNK_IHDR, data)
}

private func gammaInitDecoded(gamma: UInt32): PngDecodedRows {
    var png = joinGammaInitBytes(PNG_SIGNATURE, makeGammaInitIhdr())
    if (gamma != UInt32(0)) {
        png = joinGammaInitBytes(
            png,
            makeGammaInitChunk(PNG_CHUNK_gAMA, writeUInt32Be(gamma))
        )
    }
    png = joinGammaInitBytes(
        png,
        makeGammaInitChunk(PNG_CHUNK_IDAT, GAMMA_INIT_RGBA_ZLIB)
    )
    png = joinGammaInitBytes(png, makeGammaInitChunk(PNG_CHUNK_IEND, []))
    decodePngNonInterlaced(png)
}

@Test
public class PngGammaInitializationSnapshotTestSuite {
    @TestCase
    public func usesChunkGammaWhenSetterStateIsAbsent(): Unit {
        let initialized = initializePngReadTransformations(
            PngReadTransformState(),
            gammaInitDecoded(UInt32(45455))
        )
        @Assert(initialized.gammaConfigured(), false)
        @Assert(initialized.chunkGamma(), Int32(45455))
        @Assert(initialized.fileGamma(), Int32(45455))
        @Assert(initialized.screenGamma(), Int32(219998))
        @Assert(initialized.gammaCorrectionRequired(), false)
        @Assert(initialized.stageCount(), Int64(0))
    }

    @TestCase
    public func prefersConfiguredGammaAndExposesCorrectionDecision(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setGammaFixed(Int32(106000), Int32(100000)), true)
        let initialized = initializePngReadTransformations(
            state,
            gammaInitDecoded(UInt32(45455))
        )
        @Assert(initialized.gammaConfigured(), true)
        @Assert(initialized.chunkGamma(), Int32(45455))
        @Assert(initialized.fileGamma(), Int32(100000))
        @Assert(initialized.screenGamma(), Int32(106000))
        @Assert(initialized.gammaCorrectionRequired(), true)
    }

    @TestCase
    public func initializesMissingSourcesToIdentityGamma(): Unit {
        let initialized = initializePngReadTransformations(
            PngReadTransformState(),
            gammaInitDecoded(UInt32(0))
        )
        @Assert(initialized.chunkGamma(), Int32(0))
        @Assert(initialized.fileGamma(), PNG_FP_1)
        @Assert(initialized.screenGamma(), PNG_FP_1)
        @Assert(initialized.gammaCorrectionRequired(), false)
    }

    @TestCase
    public func ignoresRejectedSetterStateAndFallsBackToChunkGamma(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setGammaFixed(Int32(0), Int32(-3)), false)
        let initialized = initializePngReadTransformations(
            state,
            gammaInitDecoded(UInt32(50000))
        )
        @Assert(initialized.gammaConfigured(), false)
        @Assert(initialized.fileGamma(), Int32(50000))
        @Assert(initialized.screenGamma(), Int32(200000))
        @Assert(initialized.gammaCorrectionRequired(), false)
    }

    @TestCase
    public func freezesValuesAndRejectsPostInitializationMutation(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setGammaFixed(Int32(200000), Int32(50000)), true)
        let initialized = initializePngReadTransformations(
            state,
            gammaInitDecoded(UInt32(45455))
        )
        let values = initialized.gammaValues()
        @Assert(state.setGammaFixed(Int32(106000), Int32(100000)), false)
        @Assert(values.fileGamma, Int32(50000))
        @Assert(values.screenGamma, Int32(200000))
        @Assert(values.correctionRequired, false)
        @Assert(initialized.fileGamma(), Int32(50000))
        @Assert(initialized.screenGamma(), Int32(200000))
    }
}
