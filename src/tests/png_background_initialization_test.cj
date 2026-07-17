package libpng4cj.tests

import libpng4cj.*

private let BACKGROUND_INIT_PACKED_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01
]

private let BACKGROUND_INIT_RGB_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0xe0, 0x12, 0x91, 0x03, 0x00, 0x00, 0x68, 0x00, 0x3d
]

private let BACKGROUND_INIT_RGBA_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0xe0, 0x12, 0x91, 0xd3, 0x00,
    0x00, 0x00, 0xcd, 0x00, 0x65
]

private func joinBackgroundInitBytes(
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

private func makeBackgroundInitChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinBackgroundInitBytes(
        joinBackgroundInitBytes(
            joinBackgroundInitBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makeBackgroundInitIhdr(
    bitDepth: UInt8,
    colorType: UInt8
): Array<Byte> {
    let data = Array<Byte>(13, repeat: 0)
    data[3] = UInt8(1)
    data[7] = UInt8(1)
    data[8] = bitDepth
    data[9] = colorType
    makeBackgroundInitChunk(PNG_CHUNK_IHDR, data)
}

private func backgroundInitDecoded(
    bitDepth: UInt8,
    colorType: UInt8,
    beforeIdat: Array<Array<Byte>>,
    compressed: Array<Byte>
): PngDecodedRows {
    var png = joinBackgroundInitBytes(
        PNG_SIGNATURE,
        makeBackgroundInitIhdr(bitDepth, colorType)
    )
    for (chunk in beforeIdat) {
        png = joinBackgroundInitBytes(png, chunk)
    }
    png = joinBackgroundInitBytes(
        png,
        makeBackgroundInitChunk(PNG_CHUNK_IDAT, compressed)
    )
    png = joinBackgroundInitBytes(
        png,
        makeBackgroundInitChunk(PNG_CHUNK_IEND, [])
    )
    decodePngNonInterlaced(png)
}

private func backgroundInitPalette(): Array<Byte> {
    [
        1, 2, 3,
        4, 5, 6,
        7, 8, 9,
        10, 11, 12
    ]
}

private func backgroundInitIndexed(alpha: Array<Byte>): PngDecodedRows {
    let paletteChunk = makeBackgroundInitChunk(
        PNG_CHUNK_PLTE,
        backgroundInitPalette()
    )
    var chunks: Array<Array<Byte>> = [paletteChunk]
    if (alpha.size > 0) {
        chunks = [
            paletteChunk,
            makeBackgroundInitChunk(PNG_CHUNK_tRNS, alpha)
        ]
    }
    backgroundInitDecoded(
        UInt8(2),
        UInt8(3),
        chunks,
        BACKGROUND_INIT_PACKED_ZLIB
    )
}

private func configureBackgroundInit(
    state: PngReadTransformState,
    background: PngBackground,
    needExpand: Bool
): Unit {
    @Assert(
        state.setBackgroundFixed(
            background,
            BackgroundGammaFile,
            needExpand,
            Int32(45455)
        ),
        true
    )
}

private func assertBackgroundInitColor(
    actual: PngBackground,
    expected: PngBackground
): Unit {
    @Assert(actual.index, expected.index)
    @Assert(actual.gray, expected.gray)
    @Assert(actual.red, expected.red)
    @Assert(actual.green, expected.green)
    @Assert(actual.blue, expected.blue)
}

@Test
public class PngBackgroundInitializationTestSuite {
    @TestCase
    public func rejectsUnconfiguredSnapshotReads(): Unit {
        let initialized = initializePngReadTransformations(
            PngReadTransformState(),
            backgroundInitDecoded(
                UInt8(8), UInt8(2), [], BACKGROUND_INIT_RGB_ZLIB
            )
        )
        @Assert(initialized.backgroundConfigured(), false)
        @Assert(initialized.composeEnabled(), false)
        @Assert(initialized.backgroundExpandEnabled(), false)
        try {
            initialized.background()
            @Fail("background snapshot should require configuration")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "UNSUPPORTED_TRANSFORM")
        }
        try {
            initialized.backgroundGammaCode()
            @Fail("background gamma code should require configuration")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "UNSUPPORTED_TRANSFORM")
        }
        try {
            initialized.backgroundGamma()
            @Fail("background gamma should require configuration")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "UNSUPPORTED_TRANSFORM")
        }
    }

    @TestCase
    public func cancelsComposeForOpaqueTruecolorAndPlacesStripEarly(): Unit {
        let decoded = backgroundInitDecoded(
            UInt8(8), UInt8(2), [], BACKGROUND_INIT_RGB_ZLIB
        )
        let background = PngBackground(
            UInt8(0), UInt16(0), UInt16(11), UInt16(22), UInt16(33)
        )
        let state = PngReadTransformState()
        configureBackgroundInit(state, background, true)
        @Assert(state.setExpand(), true)

        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.backgroundConfigured(), true)
        @Assert(initialized.composeEnabled(), false)
        @Assert(initialized.backgroundExpandEnabled(), false)
        assertBackgroundInitColor(initialized.background(), background)
        @Assert(initialized.backgroundGammaCode(), BackgroundGammaFile)
        @Assert(initialized.backgroundGamma(), Int32(45455))
        @Assert(initialized.hasStage(ReadStageExpand), true)
        @Assert(initialized.hasStage(ReadStageStripAlpha), true)
        @Assert(initialized.stage(0), ReadStageExpand)
        @Assert(initialized.stage(1), ReadStageStripAlpha)
    }

    @TestCase
    public func retainsComposeForInherentAlphaAndColorKeyTransparency(): Unit {
        let alphaDecoded = backgroundInitDecoded(
            UInt8(8), UInt8(6), [], BACKGROUND_INIT_RGBA_ZLIB
        )
        let alphaState = PngReadTransformState()
        configureBackgroundInit(alphaState, PngBackground(), true)
        @Assert(alphaState.setExpand(), true)
        let alphaInitialized = initializePngReadTransformations(
            alphaState, alphaDecoded
        )
        @Assert(alphaInitialized.composeEnabled(), true)
        @Assert(alphaInitialized.backgroundExpandEnabled(), true)
        @Assert(alphaInitialized.hasStage(ReadStageStripAlpha), false)
        @Assert(alphaInitialized.inputHasAlpha, true)

        let transparency = makeBackgroundInitChunk(
            PNG_CHUNK_tRNS,
            [0x00, 0x0a, 0x00, 0x14, 0x00, 0x1e]
        )
        let transparentDecoded = backgroundInitDecoded(
            UInt8(8),
            UInt8(2),
            [transparency],
            BACKGROUND_INIT_RGB_ZLIB
        )
        let transparentState = PngReadTransformState()
        configureBackgroundInit(transparentState, PngBackground(), false)
        let transparentInitialized = initializePngReadTransformations(
            transparentState, transparentDecoded
        )
        @Assert(transparentInitialized.composeEnabled(), true)
        @Assert(transparentInitialized.backgroundExpandEnabled(), false)
        @Assert(transparentInitialized.hasStage(ReadStageStripAlpha), false)
        @Assert(transparentInitialized.inputHasTransparency, true)
    }

    @TestCase
    public func classifiesPaletteTransparencyBeforeComposeCancellation(): Unit {
        let binaryState = PngReadTransformState()
        configureBackgroundInit(binaryState, PngBackground(), true)
        let binary = initializePngReadTransformations(
            binaryState,
            backgroundInitIndexed([0x00, 0xff])
        )
        @Assert(binary.composeEnabled(), true)
        @Assert(binary.backgroundExpandEnabled(), true)
        @Assert(binary.inputHasTransparency, true)
        @Assert(binary.inputHasAlpha, false)
        @Assert(binary.hasStage(ReadStageStripAlpha), false)

        let partialState = PngReadTransformState()
        configureBackgroundInit(partialState, PngBackground(), false)
        let partial = initializePngReadTransformations(
            partialState,
            backgroundInitIndexed([0x80])
        )
        @Assert(partial.composeEnabled(), true)
        @Assert(partial.inputHasTransparency, true)
        @Assert(partial.inputHasAlpha, true)

        let opaqueState = PngReadTransformState()
        configureBackgroundInit(opaqueState, PngBackground(), true)
        let opaque = initializePngReadTransformations(
            opaqueState,
            backgroundInitIndexed([0xff, 0xff])
        )
        @Assert(opaque.sourceHasTransparency, true)
        @Assert(opaque.inputHasTransparency, false)
        @Assert(opaque.inputHasAlpha, false)
        @Assert(opaque.composeEnabled(), false)
        @Assert(opaque.backgroundExpandEnabled(), false)
        @Assert(opaque.hasStage(ReadStageStripAlpha), true)

        let plainState = PngReadTransformState()
        configureBackgroundInit(plainState, PngBackground(), true)
        let plain = initializePngReadTransformations(
            plainState,
            backgroundInitIndexed([])
        )
        @Assert(plain.sourceHasTransparency, false)
        @Assert(plain.composeEnabled(), false)
        @Assert(plain.backgroundExpandEnabled(), false)
    }

    @TestCase
    public func expandsPaletteIndexIntoOwnedRgbBackground(): Unit {
        let decoded = backgroundInitIndexed([0x00, 0xff])
        let state = PngReadTransformState()
        configureBackgroundInit(
            state,
            PngBackground(
                UInt8(2), UInt16(99), UInt16(100), UInt16(101), UInt16(102)
            ),
            true
        )
        @Assert(state.setExpand(), true)

        let initialized = initializePngReadTransformations(state, decoded)
        let expected = PngBackground(
            UInt8(2), UInt16(99), UInt16(7), UInt16(8), UInt16(9)
        )
        assertBackgroundInitColor(initialized.background(), expected)
        @Assert(initialized.composeEnabled(), true)
        @Assert(initialized.backgroundExpandEnabled(), true)

        let mutablePalette = decoded.metadata.palette()
        mutablePalette[6] = UInt8(200)
        assertBackgroundInitColor(initialized.background(), expected)
        @Assert(decoded.metadata.palette()[6], UInt8(7))

        @Assert(
            state.setBackgroundFixed(
                PngBackground(),
                BackgroundGammaScreen,
                false,
                Int32(100000)
            ),
            false
        )
        assertBackgroundInitColor(initialized.background(), expected)
    }

    @TestCase
    public func expandsOneTwoAndFourBitGrayBackgrounds(): Unit {
        let bitDepths: Array<UInt8> = [1, 2, 4]
        let inputValues: Array<UInt16> = [1, 2, 10]
        let expectedValues: Array<UInt16> = [255, 170, 170]
        var index: Int64 = 0
        while (index < bitDepths.size) {
            let transparency = makeBackgroundInitChunk(
                PNG_CHUNK_tRNS,
                [0x00, UInt8(inputValues[index])]
            )
            let decoded = backgroundInitDecoded(
                bitDepths[index],
                UInt8(0),
                [transparency],
                BACKGROUND_INIT_PACKED_ZLIB
            )
            let state = PngReadTransformState()
            configureBackgroundInit(
                state,
                PngBackground(
                    UInt8(0), inputValues[index], UInt16(1), UInt16(2), UInt16(3)
                ),
                true
            )
            @Assert(state.setExpand(), true)

            let initialized = initializePngReadTransformations(state, decoded)
            let value = expectedValues[index]
            assertBackgroundInitColor(
                initialized.background(),
                PngBackground(UInt8(0), value, value, value, value)
            )
            @Assert(initialized.composeEnabled(), true)
            @Assert(initialized.backgroundExpandEnabled(), true)
            index += 1
        }
    }

    @TestCase
    public func rejectsInvalidPaletteIndexAndSupportsHonestRetry(): Unit {
        let decoded = backgroundInitIndexed([0x00, 0xff])
        let state = PngReadTransformState()
        configureBackgroundInit(
            state,
            PngBackground(UInt8(4), UInt16(0), UInt16(0), UInt16(0), UInt16(0)),
            true
        )
        @Assert(state.setExpand(), true)
        try {
            initializePngReadTransformations(state, decoded)
            @Fail("background palette index outside PLTE should fail")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
            @Assert(error.offset, Int64(4))
        }
        @Assert(state.rowInitialized(), false)

        configureBackgroundInit(
            state,
            PngBackground(UInt8(1), UInt16(0), UInt16(0), UInt16(0), UInt16(0)),
            true
        )
        let initialized = initializePngReadTransformations(state, decoded)
        assertBackgroundInitColor(
            initialized.background(),
            PngBackground(UInt8(1), UInt16(0), UInt16(4), UInt16(5), UInt16(6))
        )
        @Assert(state.rowInitialized(), true)
        try {
            initializePngReadTransformations(state, decoded)
            @Fail("background initialization should remain one-shot")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
        }
    }
}
