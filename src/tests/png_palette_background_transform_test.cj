package libpng4cj.tests

import libpng4cj.*

private let PALETTE_BACKGROUND_ROW_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x90, 0x06, 0x00, 0x00, 0x1d, 0x00, 0x1c
]

private func joinPaletteBackgroundBytes(
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

private func makePaletteBackgroundChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinPaletteBackgroundBytes(
        joinPaletteBackgroundBytes(
            joinPaletteBackgroundBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makePaletteBackgroundIhdr(): Array<Byte> {
    let data = Array<Byte>(13, repeat: 0)
    data[3] = UInt8(3)
    data[7] = UInt8(1)
    data[8] = UInt8(2)
    data[9] = UInt8(3)
    makePaletteBackgroundChunk(PNG_CHUNK_IHDR, data)
}

private func paletteBackgroundPalette(): Array<Byte> {
    [
        10, 20, 30,
        100, 110, 120,
        200, 210, 220,
        1, 2, 3
    ]
}

private func paletteBackgroundDecoded(
    alpha: Array<Byte>
): PngDecodedRows {
    var png = joinPaletteBackgroundBytes(
        PNG_SIGNATURE,
        makePaletteBackgroundIhdr()
    )
    png = joinPaletteBackgroundBytes(
        png,
        makePaletteBackgroundChunk(
            PNG_CHUNK_PLTE,
            paletteBackgroundPalette()
        )
    )
    if (alpha.size > 0) {
        png = joinPaletteBackgroundBytes(
            png,
            makePaletteBackgroundChunk(PNG_CHUNK_tRNS, alpha)
        )
    }
    png = joinPaletteBackgroundBytes(
        png,
        makePaletteBackgroundChunk(
            PNG_CHUNK_IDAT,
            PALETTE_BACKGROUND_ROW_ZLIB
        )
    )
    png = joinPaletteBackgroundBytes(
        png,
        makePaletteBackgroundChunk(PNG_CHUNK_IEND, [])
    )
    decodePngNonInterlaced(png)
}

private func paletteBackgroundComposite(
    foreground: UInt8,
    alpha: UInt8,
    background: UInt8
): UInt8 {
    let temporary = UInt32(foreground) * UInt32(alpha) +
        UInt32(background) * (UInt32(255) - UInt32(alpha)) + UInt32(128)
    UInt8(((temporary + (temporary >> UInt32(8))) >> UInt32(8)) & UInt32(0xff))
}

private func paletteBackgroundColor(
    red: UInt16,
    green: UInt16,
    blue: UInt16
): PngBackground {
    PngBackground(UInt8(0), UInt16(0), red, green, blue)
}

private func configurePaletteBackground(
    state: PngReadTransformState,
    background: PngBackground,
    code: PngBackgroundGammaCode,
    gamma: Int32,
    expand: Bool
): Unit {
    @Assert(
        state.setBackgroundFixed(background, code, expand, gamma),
        true
    )
}

private func expectedNoGammaPalette(
    background: PngBackground
): Array<Byte> {
    [
        UInt8(background.red),
        UInt8(background.green),
        UInt8(background.blue),
        paletteBackgroundComposite(UInt8(100), UInt8(128), UInt8(background.red)),
        paletteBackgroundComposite(UInt8(110), UInt8(128), UInt8(background.green)),
        paletteBackgroundComposite(UInt8(120), UInt8(128), UInt8(background.blue)),
        200, 210, 220,
        1, 2, 3
    ]
}

private func expectedGammaComposePalette(
    background: PngBackground,
    backgroundLinear: PngBackground,
    tables: PngGamma8BitTables
): Array<Byte> {
    let direct = tables.direct()
    let toLinear = tables.toLinear()
    let fromLinear = tables.fromLinear()
    let source = paletteBackgroundPalette()
    let output = source.clone()
    output[0] = UInt8(background.red)
    output[1] = UInt8(background.green)
    output[2] = UInt8(background.blue)
    output[3] = fromLinear.value(paletteBackgroundComposite(
        toLinear.value(source[3]), UInt8(128), UInt8(backgroundLinear.red)
    ))
    output[4] = fromLinear.value(paletteBackgroundComposite(
        toLinear.value(source[4]), UInt8(128), UInt8(backgroundLinear.green)
    ))
    output[5] = fromLinear.value(paletteBackgroundComposite(
        toLinear.value(source[5]), UInt8(128), UInt8(backgroundLinear.blue)
    ))
    var index: Int64 = 6
    while (index < output.size) {
        output[index] = direct.value(output[index])
        index += 1
    }
    output
}

private func assertPaletteBackgroundEntry(
    palette: Array<Byte>,
    entry: Int64,
    expected: PngBackground
): Unit {
    let offset = entry * 3
    @Assert(palette[offset], UInt8(expected.red))
    @Assert(palette[offset + 1], UInt8(expected.green))
    @Assert(palette[offset + 2], UInt8(expected.blue))
}

@Test
public class PngPaletteBackgroundTransformTestSuite {
    @TestCase
    public func preprocessesNoGammaPaletteAndCancelsRowCompose(): Unit {
        let decoded = paletteBackgroundDecoded([0, 128, 255])
        let background = paletteBackgroundColor(40, 50, 60)
        let state = PngReadTransformState()
        configurePaletteBackground(
            state,
            background,
            BackgroundGammaScreen,
            PNG_FP_1,
            false
        )

        let initialized = initializePngReadTransformations(state, decoded)
        let expected: Array<Byte> = expectedNoGammaPalette(background)
        @Assert(initialized.palettePreprocessed(), true)
        @Assert(initialized.paletteComposeApplied(), true)
        @Assert(initialized.paletteGammaApplied(), false)
        @Assert(initialized.composeEnabled(), false)
        @Assert(initialized.hasStage(ReadStageCompose), false)
        @Assert(initialized.hasStage(ReadStageGamma), false)
        @Assert(initialized.hasStage(ReadStageStripAlpha), true)
        @Assert(initialized.effectivePalette(), expected)
        let expectedAlpha: Array<Byte> = [0, 128, 255]
        @Assert(initialized.effectivePaletteAlpha(), expectedAlpha)
        @Assert(decoded.metadata.palette(), paletteBackgroundPalette())

        let mutable = initialized.effectivePalette()
        mutable[0] = UInt8(0xff)
        @Assert(initialized.effectivePalette(), expected)

        let projected = projectPngReadTransformInfo(
            initialized,
            decoded
        )
        @Assert(projected.colorType, Indexed)
        @Assert(projected.hasTransparency, false)
        @Assert(projected.palette(), expected)
    }

    @TestCase
    public func expandsPrecomposedPaletteToRgbWithoutLeakingAlpha(): Unit {
        let decoded = paletteBackgroundDecoded([0, 128, 255])
        let background = paletteBackgroundColor(40, 50, 60)
        let state = PngReadTransformState()
        configurePaletteBackground(
            state,
            background,
            BackgroundGammaScreen,
            PNG_FP_1,
            true
        )
        @Assert(state.setExpand(), true)

        let initialized = initializePngReadTransformations(state, decoded)
        let palette = expectedNoGammaPalette(initialized.background())
        let sourceInfo = PngReadRowInfo(decoded.ihdr)
        let transformed = applyInitializedPngReadStages(
            initialized,
            sourceInfo,
            decoded.row(0)
        )
        let expected: Array<Byte> = [
            palette[0], palette[1], palette[2],
            palette[3], palette[4], palette[5],
            palette[6], palette[7], palette[8]
        ]
        @Assert(transformed.info.colorType, Truecolor)
        @Assert(transformed.info.channels, UInt8(3))
        @Assert(transformed.info.rowBytes, UInt64(9))
        @Assert(transformed.row(), expected)
    }

    @TestCase
    public func usesLinearGammaForFileBackgroundComposition(): Unit {
        let decoded = paletteBackgroundDecoded([0, 128, 255])
        let background = paletteBackgroundColor(40, 50, 60)
        let state = PngReadTransformState()
        @Assert(state.setGammaFixed(Int32(220000), PNG_FP_1), true)
        configurePaletteBackground(
            state,
            background,
            BackgroundGammaFile,
            PNG_FP_1,
            false
        )

        let initialized = initializePngReadTransformations(state, decoded)
        let tables = pngBuildGamma8BitTables(
            PNG_FP_1,
            Int32(220000),
            true
        )
        let expected = expectedGammaComposePalette(
            initialized.background(),
            initialized.backgroundLinear(),
            tables
        )
        @Assert(initialized.backgroundGammaInitialized(), true)
        @Assert(initialized.paletteComposeApplied(), true)
        @Assert(initialized.paletteGammaApplied(), true)
        @Assert(initialized.gamma8BitLinearTablesBuilt(), true)
        @Assert(initialized.hasStage(ReadStageCompose), false)
        @Assert(initialized.hasStage(ReadStageGamma), false)
        @Assert(initialized.effectivePalette(), expected)
    }

    @TestCase
    public func derivesPaletteBackgroundForScreenFileAndUniqueModes(): Unit {
        let decoded = paletteBackgroundDecoded([0])
        let original = paletteBackgroundColor(40, 50, 60)

        let screenState = PngReadTransformState()
        @Assert(screenState.setGammaFixed(Int32(220000), PNG_FP_1), true)
        configurePaletteBackground(
            screenState,
            original,
            BackgroundGammaScreen,
            PNG_FP_1,
            false
        )
        let screen = initializePngReadTransformations(screenState, decoded)
        assertPaletteBackgroundEntry(screen.effectivePalette(), 0, original)
        assertPaletteBackgroundEntry(
            [
                UInt8(screen.backgroundLinear().red),
                UInt8(screen.backgroundLinear().green),
                UInt8(screen.backgroundLinear().blue)
            ],
            0,
            paletteBackgroundColor(
                UInt16(pngGamma8BitCorrect(UInt8(40), Int32(220000))),
                UInt16(pngGamma8BitCorrect(UInt8(50), Int32(220000))),
                UInt16(pngGamma8BitCorrect(UInt8(60), Int32(220000)))
            )
        )

        let fileState = PngReadTransformState()
        @Assert(fileState.setGammaFixed(Int32(220000), PNG_FP_1), true)
        configurePaletteBackground(
            fileState,
            original,
            BackgroundGammaFile,
            PNG_FP_1,
            false
        )
        let file = initializePngReadTransformations(fileState, decoded)
        let fileScreenGamma = pngReciprocal2Fixed(PNG_FP_1, Int32(220000))
        assertPaletteBackgroundEntry(
            file.effectivePalette(),
            0,
            paletteBackgroundColor(
                UInt16(pngGamma8BitCorrect(UInt8(40), fileScreenGamma)),
                UInt16(pngGamma8BitCorrect(UInt8(50), fileScreenGamma)),
                UInt16(pngGamma8BitCorrect(UInt8(60), fileScreenGamma))
            )
        )

        let uniqueState = PngReadTransformState()
        @Assert(uniqueState.setGammaFixed(Int32(220000), PNG_FP_1), true)
        configurePaletteBackground(
            uniqueState,
            original,
            BackgroundGammaUnique,
            Int32(180000),
            false
        )
        let unique = initializePngReadTransformations(uniqueState, decoded)
        let uniqueScreenGamma = pngReciprocal2Fixed(
            Int32(180000),
            Int32(220000)
        )
        assertPaletteBackgroundEntry(
            unique.effectivePalette(),
            0,
            paletteBackgroundColor(
                UInt16(pngGamma8BitCorrect(UInt8(40), uniqueScreenGamma)),
                UInt16(pngGamma8BitCorrect(UInt8(50), uniqueScreenGamma)),
                UInt16(pngGamma8BitCorrect(UInt8(60), uniqueScreenGamma))
            )
        )
    }

    @TestCase
    public func appliesPaletteGammaWithoutBackgroundOrRowGamma(): Unit {
        let decoded = paletteBackgroundDecoded([])
        let state = PngReadTransformState()
        @Assert(state.setGammaFixed(Int32(220000), PNG_FP_1), true)
        @Assert(state.setExpand(), true)

        let initialized = initializePngReadTransformations(state, decoded)
        let direct = pngBuildGamma8BitTables(
            PNG_FP_1,
            Int32(220000),
            false
        ).direct()
        let expected = paletteBackgroundPalette()
        var index: Int64 = 0
        while (index < expected.size) {
            expected[index] = direct.value(expected[index])
            index += 1
        }
        @Assert(initialized.palettePreprocessed(), true)
        @Assert(initialized.paletteComposeApplied(), false)
        @Assert(initialized.paletteGammaApplied(), true)
        @Assert(initialized.hasStage(ReadStageGamma), false)
        @Assert(initialized.expandPalette(), expected)

        let row = applyInitializedPngExpandStage(
            initialized,
            PngReadRowInfo(decoded.ihdr),
            decoded.row(0)
        )
        let expectedRow: Array<Byte> = [
            expected[0], expected[1], expected[2],
            expected[3], expected[4], expected[5],
            expected[6], expected[7], expected[8]
        ]
        @Assert(row.info.colorType, Truecolor)
        @Assert(row.row(), expectedRow)
    }

    @TestCase
    public func leavesPaletteUngammaCorrectedForExpandedRgbToGray(): Unit {
        let decoded = paletteBackgroundDecoded([])
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(
            state.setRgbToGrayFixed(
                Convert,
                UInt32(21268),
                UInt32(71514)
            ),
            true
        )
        @Assert(state.setGammaFixed(Int32(220000), PNG_FP_1), true)

        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.palettePreprocessed(), false)
        @Assert(initialized.paletteGammaApplied(), false)
        @Assert(initialized.effectivePalette(), paletteBackgroundPalette())
        @Assert(initialized.hasStage(ReadStageExpand), true)
        @Assert(initialized.hasStage(ReadStageRgbToGray), true)
        @Assert(initialized.gamma8BitLinearTablesBuilt(), true)

        let result = applyInitializedPngReadStages(
            initialized,
            PngReadRowInfo(decoded.ihdr),
            decoded.row(0)
        )
        @Assert(result.info.colorType, Grayscale)
        @Assert(result.info.channels, UInt8(1))
        @Assert(result.row().size, Int64(3))
    }

    @TestCase
    public func rejectsMalformedPaletteSnapshots(): Unit {
        let tables = pngBuildGamma8BitTables(
            PNG_FP_1,
            PNG_FP_1,
            false
        )
        try {
            pngInitPaletteBackgroundTransformations(
                [1, 2, 3, 4],
                [],
                false,
                PngBackground(),
                PngBackground(),
                false,
                tables
            )
            @Fail("incomplete RGB palette should fail")
        } catch (error: PngFormatException) {
            @Assert(error.kind, InvalidPalette)
        }
        try {
            pngInitPaletteBackgroundTransformations(
                [1, 2, 3],
                [0, 1],
                false,
                PngBackground(),
                PngBackground(),
                false,
                tables
            )
            @Fail("palette alpha prefix beyond PLTE should fail")
        } catch (error: PngFormatException) {
            @Assert(error.kind, InvalidTransparency)
        }
    }
}
