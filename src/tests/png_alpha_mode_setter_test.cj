package libpng4cj.tests

import libpng4cj.*

private let ALPHA_MODE_RGBA_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0xe0, 0x12, 0x91, 0xd3, 0x00,
    0x00, 0x00, 0xcd, 0x00, 0x65
]

private func joinAlphaModeBytes(
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

private func makeAlphaModeChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinAlphaModeBytes(
        joinAlphaModeBytes(
            joinAlphaModeBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func alphaModeDecoded(): PngDecodedRows {
    let ihdr = Array<Byte>(13, repeat: 0)
    ihdr[3] = UInt8(1)
    ihdr[7] = UInt8(1)
    ihdr[8] = UInt8(8)
    ihdr[9] = UInt8(6)
    var png = joinAlphaModeBytes(
        PNG_SIGNATURE,
        makeAlphaModeChunk(PNG_CHUNK_IHDR, ihdr)
    )
    png = joinAlphaModeBytes(
        png,
        makeAlphaModeChunk(PNG_CHUNK_IDAT, ALPHA_MODE_RGBA_ZLIB)
    )
    png = joinAlphaModeBytes(
        png,
        makeAlphaModeChunk(PNG_CHUNK_IEND, [])
    )
    decodePngNonInterlaced(png)
}

private func assertBlackAlphaModeBackground(state: PngReadTransformState): Unit {
    let background = state.background()
    @Assert(background.index, UInt8(0))
    @Assert(background.gray, UInt16(0))
    @Assert(background.red, UInt16(0))
    @Assert(background.green, UInt16(0))
    @Assert(background.blue, UInt16(0))
    @Assert(state.backgroundGammaCode(), BackgroundGammaFile)
    @Assert(state.backgroundExpandEnabled(), false)
}

@Test
public class PngAlphaModeSetterTestSuite {
    @TestCase
    public func preservesFrozenModeIdentities(): Unit {
        @Assert(AlphaPng.ordinalValue(), Int64(0))
        @Assert(AlphaAssociated.ordinalValue(), Int64(1))
        @Assert(AlphaOptimized.ordinalValue(), Int64(2))
        @Assert(AlphaBroken.ordinalValue(), Int64(3))
        @Assert(AlphaPng.toString(), "PNG")
        @Assert(AlphaAssociated.toString(), "ASSOCIATED")
        @Assert(AlphaOptimized.toString(), "OPTIMIZED")
        @Assert(AlphaBroken.toString(), "BROKEN")
    }

    @TestCase
    public func configuresPngModeAndFirstWriteDefaultGamma(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setAlphaModeFixed(AlphaPng, PNG_DEFAULT_SRGB), true)
        @Assert(state.alphaMode(), AlphaPng)
        @Assert(state.screenGamma(), PNG_GAMMA_SRGB)
        @Assert(state.defaultGamma(), PNG_GAMMA_SRGB_INVERSE)
        @Assert(state.composeEnabled(), false)
        @Assert(state.encodeAlphaEnabled(), false)
        @Assert(state.optimizeAlphaEnabled(), false)

        @Assert(state.setAlphaModeFixed(AlphaPng, PNG_FP_1), true)
        @Assert(state.screenGamma(), PNG_FP_1)
        @Assert(state.defaultGamma(), PNG_GAMMA_SRGB_INVERSE)
    }

    @TestCase
    public func configuresAssociatedOptimizedAndBrokenModes(): Unit {
        let associated = PngReadTransformState()
        @Assert(
            associated.setAlphaModeFixed(AlphaAssociated, Int32(220000)),
            true
        )
        @Assert(associated.composeEnabled(), true)
        @Assert(associated.screenGamma(), PNG_FP_1)
        @Assert(associated.encodeAlphaEnabled(), false)
        @Assert(associated.optimizeAlphaEnabled(), false)
        assertBlackAlphaModeBackground(associated)
        @Assert(associated.backgroundGamma(), Int32(45455))

        let optimized = PngReadTransformState()
        @Assert(
            optimized.setAlphaModeFixed(AlphaOptimized, Int32(220000)),
            true
        )
        @Assert(optimized.composeEnabled(), true)
        @Assert(optimized.screenGamma(), Int32(220000))
        @Assert(optimized.encodeAlphaEnabled(), false)
        @Assert(optimized.optimizeAlphaEnabled(), true)
        assertBlackAlphaModeBackground(optimized)

        let broken = PngReadTransformState()
        @Assert(broken.setAlphaModeFixed(AlphaBroken, Int32(220000)), true)
        @Assert(broken.composeEnabled(), true)
        @Assert(broken.screenGamma(), Int32(220000))
        @Assert(broken.encodeAlphaEnabled(), true)
        @Assert(broken.optimizeAlphaEnabled(), false)
        assertBlackAlphaModeBackground(broken)
    }

    @TestCase
    public func preservesExistingBackgroundForPngAndRejectsConflict(): Unit {
        let state = PngReadTransformState()
        let background = PngBackground(
            UInt8(0), UInt16(7), UInt16(8), UInt16(9), UInt16(10)
        )
        @Assert(
            state.setBackgroundFixed(
                background,
                BackgroundGammaScreen,
                false,
                PNG_FP_1
            ),
            true
        )
        @Assert(state.setAlphaModeFixed(AlphaPng, PNG_FP_1), true)
        @Assert(state.composeEnabled(), true)
        @Assert(state.background().red, UInt16(8))

        @Assert(
            state.setAlphaModeFixed(AlphaAssociated, Int32(220000)),
            false
        )
        @Assert(state.alphaMode(), AlphaPng)
        @Assert(state.background().red, UInt16(8))
        @Assert(state.alphaModeBackgroundConflict(), true)
    }

    @TestCase
    public func isolatesUnsupportedFloatingAndLifecycleFailures(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setAlphaMode(AlphaOptimized, 2.2), true)
        @Assert(state.screenGamma(), Int32(220000))
        @Assert(state.defaultGamma(), Int32(45455))

        @Assert(state.setAlphaModeFixed(AlphaBroken, Int32(999)), false)
        @Assert(state.alphaMode(), AlphaOptimized)
        @Assert(state.encodeAlphaEnabled(), false)
        @Assert(state.optimizeAlphaEnabled(), true)
        @Assert(state.alphaModeGammaApplicationError(), true)

        try {
            state.setAlphaMode(AlphaPng, Float64.NaN)
            @Fail("non-finite alpha output gamma should fail")
        } catch (error: PngFormatException) {
            @Assert(error.kind, InvalidArgument)
        }
        @Assert(state.alphaMode(), AlphaOptimized)

        state.markRowInitialized()
        @Assert(state.setAlphaModeFixed(AlphaPng, PNG_FP_1), false)
        @Assert(state.lastApplicationError(), InvalidAfterRowInitialization)
        @Assert(state.alphaMode(), AlphaOptimized)
    }

    @TestCase
    public func feedsDefaultAndScreenGammaIntoInitialization(): Unit {
        let state = PngReadTransformState()
        @Assert(
            state.setAlphaModeFixed(AlphaAssociated, Int32(220000)),
            true
        )
        let initialized = initializePngReadTransformations(
            state,
            alphaModeDecoded()
        )
        @Assert(initialized.alphaModeConfigured(), true)
        @Assert(initialized.alphaMode(), AlphaAssociated)
        @Assert(initialized.defaultGamma(), Int32(45455))
        @Assert(initialized.fileGamma(), Int32(45455))
        @Assert(initialized.screenGamma(), PNG_FP_1)
        @Assert(initialized.composeEnabled(), true)
        @Assert(initialized.encodeAlphaEnabled(), false)
        @Assert(initialized.optimizeAlphaEnabled(), false)
        @Assert(initialized.backgroundGammaCode(), BackgroundGammaFile)
    }

    @TestCase
    public func rejectsAlphaModeReadBeforeConfiguration(): Unit {
        let state = PngReadTransformState()
        try {
            state.alphaMode()
            @Fail("alpha-mode getter should require configuration")
        } catch (error: PngFormatException) {
            @Assert(error.kind, UnsupportedTransform)
        }
    }
}
