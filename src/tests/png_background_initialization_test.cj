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

private let BACKGROUND_INIT_RGBA16_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x10, 0x32, 0x51, 0x76, 0x35, 0x09,
    0x73, 0x4d, 0x07, 0x00, 0x06, 0xf3, 0x01, 0xe5
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

private func backgroundInitDiv257(value: UInt16): UInt16 {
    UInt16(
        (UInt32(value) * UInt32(255) + UInt32(32895)) >> UInt32(16)
    )
}

private func backgroundInitTimes257(value: UInt16): UInt16 {
    UInt16((UInt32(value) * UInt32(257)) & UInt32(0xffff))
}

private func backgroundInitCorrect8(
    background: PngBackground,
    gamma: Int32
): PngBackground {
    PngBackground(
        background.index,
        UInt16(pngGamma8BitCorrect(UInt8(background.gray), gamma)),
        UInt16(pngGamma8BitCorrect(UInt8(background.red), gamma)),
        UInt16(pngGamma8BitCorrect(UInt8(background.green), gamma)),
        UInt16(pngGamma8BitCorrect(UInt8(background.blue), gamma))
    )
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
        try {
            initialized.backgroundOriginal()
            @Fail("original background should require configuration")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "UNSUPPORTED_TRANSFORM")
        }
        try {
            initialized.backgroundLinear()
            @Fail("linear background should require configuration")
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

        let alphaState = PngReadTransformState()
        @Assert(
            alphaState.setAlphaModeFixed(AlphaOptimized, Int32(220000)),
            true
        )
        let alphaInitialized = initializePngReadTransformations(
            alphaState,
            decoded
        )
        @Assert(alphaInitialized.inputHasAlpha, false)
        @Assert(alphaInitialized.inputHasTransparency, false)
        @Assert(alphaInitialized.optimizeAlphaEnabled(), false)
        @Assert(alphaInitialized.composeEnabled(), false)
        @Assert(alphaState.optimizeAlphaEnabled(), true)
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
        @Assert(binary.composeEnabled(), false)
        @Assert(binary.paletteComposeApplied(), true)
        @Assert(binary.backgroundExpandEnabled(), true)
        @Assert(binary.inputHasTransparency, true)
        @Assert(binary.inputHasAlpha, false)
        @Assert(binary.hasStage(ReadStageStripAlpha), true)

        let partialState = PngReadTransformState()
        configureBackgroundInit(partialState, PngBackground(), false)
        let partial = initializePngReadTransformations(
            partialState,
            backgroundInitIndexed([0x80])
        )
        @Assert(partial.composeEnabled(), false)
        @Assert(partial.paletteComposeApplied(), true)
        @Assert(partial.inputHasTransparency, true)
        @Assert(partial.inputHasAlpha, true)
        @Assert(partial.hasStage(ReadStageStripAlpha), true)

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
        @Assert(initialized.composeEnabled(), false)
        @Assert(initialized.paletteComposeApplied(), true)
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

    @TestCase
    public func normalizesBackgroundDepthAroundExpand16AndReduction(): Unit {
        let decoded8 = backgroundInitDecoded(
            UInt8(8), UInt8(6), [], BACKGROUND_INIT_RGBA_ZLIB
        )
        let supplied16 = PngBackground(
            UInt8(0), UInt16(0x1234), UInt16(0x4567),
            UInt16(0x89ab), UInt16(0xcdef)
        )
        let expand16State = PngReadTransformState()
        configureBackgroundInit(expand16State, supplied16, false)
        @Assert(expand16State.setExpand16(), true)
        let expand16 = initializePngReadTransformations(
            expand16State, decoded8
        )
        let chopped = PngBackground(
            UInt8(0),
            backgroundInitDiv257(UInt16(0x1234)),
            backgroundInitDiv257(UInt16(0x4567)),
            backgroundInitDiv257(UInt16(0x89ab)),
            backgroundInitDiv257(UInt16(0xcdef))
        )
        @Assert(expand16.backgroundDepthNormalized(), true)
        assertBackgroundInitColor(expand16.backgroundOriginal(), chopped)
        assertBackgroundInitColor(expand16.backgroundLinear(), chopped)
        assertBackgroundInitColor(expand16.background(), chopped)

        let bypassState = PngReadTransformState()
        configureBackgroundInit(bypassState, supplied16, true)
        @Assert(bypassState.setExpand(), true)
        @Assert(bypassState.setExpand16(), true)
        let bypass = initializePngReadTransformations(bypassState, decoded8)
        @Assert(bypass.backgroundDepthNormalized(), false)
        assertBackgroundInitColor(bypass.backgroundOriginal(), supplied16)

        let decoded16 = backgroundInitDecoded(
            UInt8(16), UInt8(6), [], BACKGROUND_INIT_RGBA16_ZLIB
        )
        let supplied8 = PngBackground(
            UInt8(0), UInt16(0x12), UInt16(0x34),
            UInt16(0x56), UInt16(0x78)
        )
        let reductionState = PngReadTransformState()
        configureBackgroundInit(reductionState, supplied8, false)
        @Assert(reductionState.setScale16(), true)
        @Assert(reductionState.setStrip16(), true)
        let reduction = initializePngReadTransformations(
            reductionState, decoded16
        )
        let expanded = PngBackground(
            UInt8(0),
            backgroundInitTimes257(UInt16(0x12)),
            backgroundInitTimes257(UInt16(0x34)),
            backgroundInitTimes257(UInt16(0x56)),
            backgroundInitTimes257(UInt16(0x78))
        )
        @Assert(reduction.backgroundDepthNormalized(), true)
        assertBackgroundInitColor(reduction.backgroundOriginal(), expanded)
        assertBackgroundInitColor(reduction.background(), expanded)
    }

    @TestCase
    public func derivesScreenFileAndUniqueBackgroundGamma(): Unit {
        let decoded = backgroundInitDecoded(
            UInt8(8), UInt8(6), [], BACKGROUND_INIT_RGBA_ZLIB
        )
        let background = PngBackground(
            UInt8(0), UInt16(80), UInt16(64), UInt16(128), UInt16(192)
        )

        let screenState = PngReadTransformState()
        @Assert(
            screenState.setGammaFixed(Int32(220000), Int32(45455)),
            true
        )
        configureBackgroundInit(
            screenState, background, false
        )
        let screen = initializePngReadTransformations(screenState, decoded)
        @Assert(screen.backgroundGammaInitialized(), true)
        @Assert(screen.backgroundGammaCode(), BackgroundGammaFile)
        @Assert(screen.effectiveBackgroundGammaCode(), BackgroundGammaScreen)
        @Assert(
            screen.backgroundToLinearGamma(),
            pngReciprocalFixed(Int32(45455))
        )
        @Assert(
            screen.backgroundToScreenGamma(),
            pngReciprocal2Fixed(Int32(45455), Int32(220000))
        )
        assertBackgroundInitColor(
            screen.backgroundLinear(),
            backgroundInitCorrect8(
                background,
                pngReciprocalFixed(Int32(45455))
            )
        )
        assertBackgroundInitColor(
            screen.background(),
            backgroundInitCorrect8(
                background,
                pngReciprocal2Fixed(Int32(45455), Int32(220000))
            )
        )
        @Assert(screen.gamma8BitLinearTablesBuilt(), true)

        let screenModeState = PngReadTransformState()
        @Assert(
            screenModeState.setGammaFixed(Int32(220000), Int32(45455)),
            true
        )
        @Assert(
            screenModeState.setBackgroundFixed(
                background,
                BackgroundGammaScreen,
                false,
                Int32(100000)
            ),
            true
        )
        let screenMode = initializePngReadTransformations(
            screenModeState, decoded
        )
        @Assert(screenMode.backgroundToLinearGamma(), Int32(220000))
        @Assert(screenMode.backgroundToScreenGamma(), PNG_FP_1)
        assertBackgroundInitColor(screenMode.background(), background)
        assertBackgroundInitColor(
            screenMode.backgroundLinear(),
            backgroundInitCorrect8(background, Int32(220000))
        )

        let uniqueState = PngReadTransformState()
        @Assert(
            uniqueState.setGammaFixed(Int32(220000), Int32(45455)),
            true
        )
        @Assert(
            uniqueState.setBackgroundFixed(
                background,
                BackgroundGammaUnique,
                false,
                Int32(50000)
            ),
            true
        )
        let unique = initializePngReadTransformations(uniqueState, decoded)
        @Assert(
            unique.backgroundToLinearGamma(),
            pngReciprocalFixed(Int32(50000))
        )
        @Assert(
            unique.backgroundToScreenGamma(),
            pngReciprocal2Fixed(Int32(50000), Int32(220000))
        )
        assertBackgroundInitColor(
            unique.backgroundLinear(),
            backgroundInitCorrect8(
                background,
                pngReciprocalFixed(Int32(50000))
            )
        )
    }

    @TestCase
    public func derivesSixteenBitGrayBackgroundGamma(): Unit {
        let decoded = backgroundInitDecoded(
            UInt8(16), UInt8(6), [], BACKGROUND_INIT_RGBA16_ZLIB
        )
        let background = PngBackground(
            UInt8(0), UInt16(0x3456), UInt16(0x3456),
            UInt16(0x3456), UInt16(0x3456)
        )
        let state = PngReadTransformState()
        @Assert(state.setGammaFixed(Int32(220000), Int32(45455)), true)
        configureBackgroundInit(state, background, false)
        let initialized = initializePngReadTransformations(state, decoded)
        let linearValue = pngGamma16BitCorrect(
            UInt16(0x3456),
            pngReciprocalFixed(Int32(45455))
        )
        let screenValue = pngGamma16BitCorrect(
            UInt16(0x3456),
            pngReciprocal2Fixed(Int32(45455), Int32(220000))
        )
        assertBackgroundInitColor(
            initialized.backgroundLinear(),
            PngBackground(
                UInt8(0), linearValue, linearValue, linearValue, linearValue
            )
        )
        assertBackgroundInitColor(
            initialized.background(),
            PngBackground(
                UInt8(0), screenValue, screenValue, screenValue, screenValue
            )
        )
        @Assert(initialized.gamma16BitLinearTablesBuilt(), true)
    }

    @TestCase
    public func preservesIdentityAndCancelledBackgroundGammaPaths(): Unit {
        let alphaDecoded = backgroundInitDecoded(
            UInt8(8), UInt8(6), [], BACKGROUND_INIT_RGBA_ZLIB
        )
        let background = PngBackground(
            UInt8(0), UInt16(50), UInt16(60), UInt16(70), UInt16(80)
        )
        let identityState = PngReadTransformState()
        @Assert(identityState.setGammaFixed(PNG_FP_1, PNG_FP_1), true)
        configureBackgroundInit(identityState, background, false)
        let identity = initializePngReadTransformations(
            identityState, alphaDecoded
        )
        @Assert(identity.backgroundGammaInitialized(), false)
        @Assert(identity.effectiveBackgroundGammaCode(), BackgroundGammaFile)
        assertBackgroundInitColor(identity.backgroundOriginal(), background)
        assertBackgroundInitColor(identity.backgroundLinear(), background)
        assertBackgroundInitColor(identity.background(), background)
        @Assert(identity.gamma8BitTablesBuilt(), false)
        try {
            identity.backgroundToLinearGamma()
            @Fail("identity background path should not claim gamma derivation")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "UNSUPPORTED_TRANSFORM")
        }

        let opaqueDecoded = backgroundInitDecoded(
            UInt8(8), UInt8(2), [], BACKGROUND_INIT_RGB_ZLIB
        )
        let cancelledState = PngReadTransformState()
        @Assert(
            cancelledState.setGammaFixed(Int32(220000), Int32(45455)),
            true
        )
        configureBackgroundInit(cancelledState, background, false)
        @Assert(cancelledState.setExpand16(), true)
        let cancelled = initializePngReadTransformations(
            cancelledState, opaqueDecoded
        )
        @Assert(cancelled.composeEnabled(), false)
        @Assert(cancelled.backgroundDepthNormalized(), false)
        @Assert(cancelled.backgroundGammaInitialized(), false)
        assertBackgroundInitColor(cancelled.background(), background)
    }

    @TestCase
    public func preparesAndConsumesPaletteGammaTablesWithoutMetadataMutation(): Unit {
        let decoded = backgroundInitIndexed([0x00, 0xff])
        let state = PngReadTransformState()
        @Assert(state.setGammaFixed(Int32(220000), Int32(45455)), true)
        configureBackgroundInit(
            state,
            PngBackground(
                UInt8(2), UInt16(0), UInt16(0), UInt16(0), UInt16(0)
            ),
            true
        )
        @Assert(state.setExpand(), true)
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.composeEnabled(), false)
        @Assert(initialized.paletteComposeApplied(), true)
        @Assert(initialized.paletteGammaApplied(), true)
        @Assert(initialized.backgroundGammaInitialized(), true)
        @Assert(
            initialized.effectiveBackgroundGammaCode(),
            BackgroundGammaScreen
        )
        @Assert(initialized.gamma8BitLinearTablesBuilt(), true)
        assertBackgroundInitColor(
            initialized.background(),
            PngBackground(
                UInt8(2), UInt16(0), UInt16(7), UInt16(8), UInt16(9)
            )
        )
        @Assert(initialized.effectivePalette(), initialized.expandPalette())
        @Assert(initialized.effectivePalette() != backgroundInitPalette(), true)
        @Assert(decoded.metadata.palette(), backgroundInitPalette())
    }
}
