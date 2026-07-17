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

private func gammaAwareGray8Oracle(
    red: UInt8,
    green: UInt8,
    blue: UInt8,
    transform: PngRgbToGrayTransform,
    tables: PngGamma8BitTables
): UInt8 {
    if (red == green && red == blue) {
        return tables.direct().value(red)
    }
    let toLinear = tables.toLinear()
    let linearRed = toLinear.value(red)
    let linearGreen = toLinear.value(green)
    let linearBlue = toLinear.value(blue)
    let weighted = UInt32(transform.redCoefficient) * UInt32(linearRed) +
        UInt32(transform.greenCoefficient) * UInt32(linearGreen) +
        UInt32(transform.blueCoefficient) * UInt32(linearBlue) + UInt32(16384)
    tables.fromLinear().value(UInt8(weighted >> 15))
}

@Test
public class PngGammaInitializationSnapshotTestSuite {
    @TestCase
    public func usesChunkGammaWhenSetterStateIsAbsent(): Unit {
        let decoded = gammaInitDecoded(UInt32(45455))
        let initialized = initializePngReadTransformations(
            PngReadTransformState(),
            decoded
        )
        @Assert(initialized.gammaConfigured(), false)
        @Assert(initialized.chunkGamma(), Int32(45455))
        @Assert(initialized.fileGamma(), Int32(45455))
        @Assert(initialized.screenGamma(), Int32(219998))
        @Assert(initialized.gammaCorrectionRequired(), false)
        @Assert(initialized.stageCount(), Int64(0))
        let projected = projectPngReadTransformInfo(initialized, decoded)
        @Assert(projected.hasGamma, true)
        @Assert(projected.gamma, Int32(45455))
    }

    @TestCase
    public func prefersConfiguredGammaAndExposesCorrectionDecision(): Unit {
        let decoded = gammaInitDecoded(UInt32(45455))
        let state = PngReadTransformState()
        @Assert(state.setGammaFixed(Int32(106000), Int32(100000)), true)
        let initialized = initializePngReadTransformations(
            state,
            decoded
        )
        @Assert(initialized.gammaConfigured(), true)
        @Assert(initialized.chunkGamma(), Int32(45455))
        @Assert(initialized.fileGamma(), Int32(100000))
        @Assert(initialized.screenGamma(), Int32(106000))
        @Assert(initialized.gammaCorrectionRequired(), true)
        let projected = projectPngReadTransformInfo(initialized, decoded)
        @Assert(projected.hasGamma, true)
        @Assert(projected.gamma, Int32(100000))
    }

    @TestCase
    public func initializesMissingSourcesToIdentityGamma(): Unit {
        let decoded = gammaInitDecoded(UInt32(0))
        let initialized = initializePngReadTransformations(
            PngReadTransformState(),
            decoded
        )
        @Assert(initialized.chunkGamma(), Int32(0))
        @Assert(initialized.fileGamma(), PNG_FP_1)
        @Assert(initialized.screenGamma(), PNG_FP_1)
        @Assert(initialized.gammaCorrectionRequired(), false)
        let projected = projectPngReadTransformInfo(initialized, decoded)
        @Assert(projected.hasGamma, false)
        @Assert(projected.gamma, PNG_FP_1)
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

    @TestCase
    public func snapshotsConfiguredDirectGammaTableAndGammaStage(): Unit {
        let state = PngReadTransformState()
        @Assert(state.setGammaFixed(Int32(106000), Int32(100000)), true)
        let initialized = initializePngReadTransformations(
            state,
            gammaInitDecoded(UInt32(45455))
        )
        @Assert(initialized.gamma8BitTablesBuilt(), true)
        @Assert(initialized.gamma8BitLinearTablesBuilt(), false)
        @Assert(initialized.stageCount(), Int64(1))
        @Assert(initialized.stage(0), ReadStageGamma)
        let correction = pngReciprocal2Fixed(Int32(106000), Int32(100000))
        @Assert(correction, Int32(94340))
        @Assert(
            initialized.gamma8BitTables().direct().value(UInt8(128)),
            pngGamma8BitCorrect(UInt8(128), correction)
        )
    }

    @TestCase
    public func skipsTablesForInsignificantChunkFallback(): Unit {
        let initialized = initializePngReadTransformations(
            PngReadTransformState(),
            gammaInitDecoded(UInt32(45455))
        )
        @Assert(initialized.gamma8BitTablesBuilt(), false)
        @Assert(initialized.gamma8BitLinearTablesBuilt(), false)
        @Assert(initialized.stageCount(), Int64(0))
    }

    @TestCase
    public func snapshotsRgbToGrayLinearTablesForChunkGamma(): Unit {
        let decoded = gammaInitDecoded(UInt32(45455))
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(
            state.setRgbToGrayFixed(Convert, UInt32(21268), UInt32(71514)),
            true
        )
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.gammaCorrectionRequired(), false)
        @Assert(initialized.gamma8BitTablesBuilt(), true)
        @Assert(initialized.gamma8BitLinearTablesBuilt(), true)
        @Assert(initialized.stageCount(), Int64(1))
        @Assert(initialized.stage(0), ReadStageRgbToGray)

        let tables = initialized.gamma8BitTables()
        @Assert(tables.direct().value(UInt8(128)), UInt8(128))
        @Assert(
            tables.toLinear().value(UInt8(128)),
            pngBuildGamma8BitTable(
                pngReciprocalFixed(initialized.fileGamma())
            ).value(UInt8(128))
        )
        @Assert(
            tables.fromLinear().value(UInt8(128)),
            pngBuildGamma8BitTable(
                pngReciprocalFixed(initialized.screenGamma())
            ).value(UInt8(128))
        )

        let mutable = tables.toLinear().values()
        mutable[128] = UInt8(0)
        @Assert(
            initialized.gamma8BitTables().toLinear().value(UInt8(128)) ==
                UInt8(0),
            false
        )
    }

    @TestCase
    public func executesGammaAwareEightBitRgbToGrayRows(): Unit {
        let decoded = gammaInitDecoded(UInt32(45455))
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(
            state.setRgbToGrayFixed(Convert, UInt32(21268), UInt32(71514)),
            true
        )
        @Assert(state.setGammaFixed(Int32(106000), Int32(100000)), true)
        let initialized = initializePngReadTransformations(state, decoded)
        let transform = initialized.rgbToGrayTransform()
        let tables = initialized.gamma8BitTables()
        let source: Array<Byte> = [64, 128, 192, 77, 80, 80, 80, 99]
        let transformed = applyInitializedPngRgbToGrayStage(
            initialized,
            PngReadRowInfo(UInt32(2), UInt8(8), TruecolorAlpha),
            source
        )
        let expected: Array<Byte> = [
            gammaAwareGray8Oracle(
                UInt8(64), UInt8(128), UInt8(192), transform, tables
            ),
            UInt8(77),
            tables.direct().value(UInt8(80)),
            UInt8(99)
        ]
        @Assert(transformed.row(), expected)
        @Assert(transformed.info.colorType.toString(), "GRAYSCALE_ALPHA")
        @Assert(transformed.hadNonGrayPixels, true)

        source[0] = UInt8(0)
        @Assert(transformed.row(), expected)
        let mutable = transformed.row()
        mutable[0] = UInt8(0)
        @Assert(transformed.row(), expected)
    }

    @TestCase
    public func detectsOriginalEightBitRgbBeforeLinearization(): Unit {
        let decoded = gammaInitDecoded(UInt32(45455))
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(
            state.setRgbToGrayFixed(RequireGray, UInt32(21268), UInt32(71514)),
            true
        )
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(
            initialized.gamma8BitTables().toLinear().value(UInt8(1)),
            initialized.gamma8BitTables().toLinear().value(UInt8(2))
        )
        try {
            applyInitializedPngRgbToGrayStage(
                initialized,
                PngReadRowInfo(UInt32(1), UInt8(8), Truecolor),
                [1, 2, 1]
            )
            @Fail("gamma-aware RGB-to-gray must compare original samples")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "RGB_TO_GRAY_MISMATCH")
            @Assert(error.offset, Int64(0))
        }
        try {
            applyInitializedPngRgbToGrayStage(
                initialized,
                PngReadRowInfo(UInt32(2), UInt8(8), Truecolor),
                [1, 2, 3, 4, 5]
            )
            @Fail("gamma-aware RGB-to-gray should reject malformed rows")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func transformsWholeImageWithGammaAwareRgbToGray(): Unit {
        let decoded = gammaInitDecoded(UInt32(45455))
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(
            state.setRgbToGrayFixed(Convert, UInt32(21268), UInt32(71514)),
            true
        )
        @Assert(state.setGammaFixed(Int32(106000), Int32(100000)), true)
        let initialized = initializePngReadTransformations(state, decoded)
        let source = decoded.row(0)
        let transform = initialized.rgbToGrayTransform()
        let tables = initialized.gamma8BitTables()
        let expected: Array<Byte> = [
            gammaAwareGray8Oracle(
                source[0], source[1], source[2], transform, tables
            ),
            source[3],
            gammaAwareGray8Oracle(
                source[4], source[5], source[6], transform, tables
            ),
            source[7]
        ]
        let wholeState = PngReadTransformState()
        wholeState.markIhdrRead(decoded.ihdr)
        @Assert(
            wholeState.setRgbToGrayFixed(
                Convert, UInt32(21268), UInt32(71514)
            ),
            true
        )
        @Assert(
            wholeState.setGammaFixed(Int32(106000), Int32(100000)),
            true
        )
        let transformed = transformPngRowsInitialized(decoded, wholeState)
        @Assert(transformed.rowCount(), Int64(1))
        @Assert(transformed.row(0), expected)
        @Assert(transformed.info.colorType.toString(), "GRAYSCALE_ALPHA")
        @Assert(transformed.hadNonGrayPixels, true)
    }

    @TestCase
    public func preservesReciprocal2FailureAndSignedRangeBehavior(): Unit {
        @Assert(pngReciprocal2Fixed(Int32(0), PNG_FP_1), Int32(0))
        @Assert(pngReciprocal2Fixed(PNG_FP_1, Int32(0)), Int32(0))
        @Assert(pngReciprocal2Fixed(Int32(1), Int32(1)), Int32(0))
        @Assert(
            pngReciprocal2Fixed(Int32(-100000), Int32(100000)),
            Int32(-100000)
        )
    }

    @TestCase
    public func gatesAndExecutesInitializedGammaBeforeReduction(): Unit {
        let decoded = gammaInitDecoded(UInt32(45455))
        let state = PngReadTransformState()
        @Assert(state.setGammaFixed(Int32(106000), Int32(100000)), true)
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.stageCount(), Int64(1))
        @Assert(initialized.stage(0), ReadStageGamma)
        @Assert(ReadStageGamma.ordinalValue(), Int64(19))
        @Assert(ReadStageScale16To8.ordinalValue(), Int64(4))

        let source = decoded.row(0)
        let transformed = applyInitializedPngGammaStage(
            initialized,
            PngReadRowInfo(decoded.ihdr),
            source
        )
        let table = initialized.gamma8BitTables().direct()
        var offset: Int64 = 0
        while (offset < source.size) {
            @Assert(transformed.row()[offset], table.value(source[offset]))
            @Assert(transformed.row()[offset + 1], table.value(source[offset + 1]))
            @Assert(transformed.row()[offset + 2], table.value(source[offset + 2]))
            @Assert(transformed.row()[offset + 3], source[offset + 3])
            offset += 4
        }

        let wholeState = PngReadTransformState()
        @Assert(wholeState.setGammaFixed(Int32(106000), Int32(100000)), true)
        let whole = transformPngRowsInitialized(decoded, wholeState)
        @Assert(whole.row(0), transformed.row())

        let orderedState = PngReadTransformState()
        @Assert(orderedState.setGrayToRgb(), true)
        @Assert(
            orderedState.setGammaFixed(Int32(106000), Int32(100000)),
            true
        )
        let ordered = initializePngReadTransformations(orderedState, decoded)
        @Assert(ordered.stageCount(), Int64(3))
        @Assert(ordered.stage(0), ReadStageExpand)
        @Assert(ordered.stage(1), ReadStageGrayToRgb)
        @Assert(ordered.stage(2), ReadStageGamma)
    }
}
