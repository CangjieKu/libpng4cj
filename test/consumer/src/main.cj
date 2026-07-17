package libpng4cj_consumer

import libpng4cj.*

private let CONSUMER_RGBA_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private let CONSUMER_GRAY16_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x10, 0x32, 0x01, 0x00, 0x00, 0x5b, 0x00, 0x47
]

private let CONSUMER_INDEXED_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x90, 0x06, 0x00, 0x00, 0x1d, 0x00, 0x1c
]

private func joinConsumerBytes(
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

private func makeConsumerChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinConsumerBytes(
        joinConsumerBytes(
            joinConsumerBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func consumerGammaPng(): Array<Byte> {
    let ihdr = Array<Byte>(13, repeat: 0)
    let width = writeUInt32Be(UInt32(2))
    let height = writeUInt32Be(UInt32(1))
    var index: Int64 = 0
    while (index < 4) {
        ihdr[index] = width[index]
        ihdr[index + 4] = height[index]
        index += 1
    }
    ihdr[8] = UInt8(8)
    ihdr[9] = UInt8(6)

    var png = joinConsumerBytes(PNG_SIGNATURE, makeConsumerChunk(PNG_CHUNK_IHDR, ihdr))
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_gAMA, writeUInt32Be(UInt32(45455)))
    )
    png = joinConsumerBytes(png, makeConsumerChunk(PNG_CHUNK_IDAT, CONSUMER_RGBA_ZLIB))
    joinConsumerBytes(png, makeConsumerChunk(PNG_CHUNK_IEND, []))
}

private func consumerGamma16Png(): Array<Byte> {
    let ihdr = Array<Byte>(13, repeat: 0)
    ihdr[3] = UInt8(1)
    ihdr[7] = UInt8(1)
    ihdr[8] = UInt8(16)
    ihdr[9] = UInt8(0)

    var png = joinConsumerBytes(
        PNG_SIGNATURE,
        makeConsumerChunk(PNG_CHUNK_IHDR, ihdr)
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_gAMA, writeUInt32Be(UInt32(45455)))
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_sBIT, [UInt8(12)])
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_IDAT, CONSUMER_GRAY16_ZLIB)
    )
    joinConsumerBytes(png, makeConsumerChunk(PNG_CHUNK_IEND, []))
}

private func consumerIndexedBackgroundPng(): Array<Byte> {
    let ihdr = Array<Byte>(13, repeat: 0)
    ihdr[3] = UInt8(3)
    ihdr[7] = UInt8(1)
    ihdr[8] = UInt8(2)
    ihdr[9] = UInt8(3)
    let palette: Array<Byte> = [
        10, 20, 30,
        100, 110, 120,
        200, 210, 220,
        40, 50, 60
    ]
    var png = joinConsumerBytes(
        PNG_SIGNATURE,
        makeConsumerChunk(PNG_CHUNK_IHDR, ihdr)
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_PLTE, palette)
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_tRNS, [0, 128, 255])
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_IDAT, CONSUMER_INDEXED_ZLIB)
    )
    joinConsumerBytes(png, makeConsumerChunk(PNG_CHUNK_IEND, []))
}

main(): Int64 {
    if (!isPngSignature(PNG_SIGNATURE)) {
        println("libpng4cj signature check failed")
        return 1
    }
    let backgroundState = PngReadTransformState()
    let background = PngBackground(
        UInt8(0),
        UInt16(0x1111),
        UInt16(0x2222),
        UInt16(0x3333),
        UInt16(0x4444)
    )
    if (!backgroundState.setBackgroundFixed(
        background,
        BackgroundGammaFile,
        true,
        Int32(45455)
    ) || !backgroundState.backgroundConfigured() ||
        !backgroundState.composeEnabled() ||
        !backgroundState.stripAlphaEnabled() ||
        !backgroundState.backgroundExpandEnabled() ||
        backgroundState.encodeAlphaEnabled() ||
        backgroundState.optimizeAlphaEnabled() ||
        backgroundState.backgroundGammaCode() != BackgroundGammaFile ||
        backgroundState.backgroundGamma() != Int32(45455) ||
        backgroundState.background().blue != UInt16(0x4444)) {
        println("libpng4cj fixed background setter check failed")
        return 1
    }
    if (backgroundState.setBackgroundFixed(
        PngBackground(),
        BackgroundGammaUnknown,
        false,
        Int32(100000)
    ) || !backgroundState.backgroundGammaUnknownWarning() ||
        backgroundState.backgroundGammaCode() != BackgroundGammaFile ||
        backgroundState.background().blue != UInt16(0x4444)) {
        println("libpng4cj background rejection stability check failed")
        return 1
    }
    if (!backgroundState.setBackground(
        background,
        BackgroundGammaUnique,
        false,
        1.0
    ) || backgroundState.backgroundGamma() != Int32(100000) ||
        backgroundState.backgroundExpandEnabled() ||
        backgroundState.backgroundGammaUnknownWarning()) {
        println("libpng4cj floating background setter check failed")
        return 1
    }
    let initializedBackgroundState = PngReadTransformState()
    let initializedBackgroundColor = PngBackground(
        UInt8(0), UInt16(80), UInt16(64), UInt16(128), UInt16(192)
    )
    if (!initializedBackgroundState.setGammaFixed(
        Int32(220000), Int32(45455)
    ) || !initializedBackgroundState.setBackgroundFixed(
        initializedBackgroundColor,
        BackgroundGammaFile,
        false,
        Int32(45455)
    )) {
        println("libpng4cj background initialization setup failed")
        return 1
    }
    let initializedBackground = initializePngReadTransformations(
        initializedBackgroundState,
        decodePngNonInterlaced(consumerGammaPng())
    )
    let backgroundToLinear = pngReciprocalFixed(Int32(45455))
    let backgroundToScreen = pngReciprocal2Fixed(
        Int32(45455), Int32(220000)
    )
    if (!initializedBackground.backgroundConfigured() ||
        !initializedBackground.composeEnabled() ||
        initializedBackground.backgroundExpandEnabled() ||
        initializedBackground.hasStage(ReadStageStripAlpha) ||
        !initializedBackground.hasStage(ReadStageCompose) ||
        !initializedBackground.hasStage(ReadStageStripAlphaAfterCompose) ||
        initializedBackground.hasStage(ReadStageGamma) ||
        !initializedBackground.backgroundGammaInitialized() ||
        initializedBackground.backgroundGammaCode() != BackgroundGammaFile ||
        initializedBackground.effectiveBackgroundGammaCode() !=
            BackgroundGammaScreen ||
        initializedBackground.backgroundToLinearGamma() != backgroundToLinear ||
        initializedBackground.backgroundToScreenGamma() != backgroundToScreen ||
        initializedBackground.backgroundOriginal().blue != UInt16(192) ||
        initializedBackground.backgroundLinear().blue != UInt16(
            pngGamma8BitCorrect(UInt8(192), backgroundToLinear)
        ) || initializedBackground.background().blue != UInt16(
            pngGamma8BitCorrect(UInt8(192), backgroundToScreen)
        ) || !initializedBackground.gamma8BitLinearTablesBuilt()) {
        println("libpng4cj background initialization snapshot check failed")
        return 1
    }
    let composedBackground = PngBackground(
        UInt8(0), UInt16(30), UInt16(20), UInt16(40), UInt16(60)
    )
    let composed = pngDoCompose(
        PngReadRowInfo(UInt32(1), UInt8(8), TruecolorAlpha),
        [100, 110, 120, 128],
        composedBackground,
        PngExpandTransparency()
    )
    if (composed.row() != [
        UInt8(60), UInt8(75), UInt8(90), UInt8(128)
    ] || ReadStageCompose.ordinalValue() != Int64(20) ||
        ReadStageStripAlphaAfterCompose.ordinalValue() != Int64(21)) {
        println("libpng4cj background compose row check failed")
        return 1
    }
    let gamma = pngInitGammaValues(PngFileGammaSources(
        Int32(45455),
        Int32(0),
        Int32(0),
        Int32(0)
    ))
    if (gamma.fileGamma != Int32(45455) ||
        gamma.screenGamma != Int32(219998) ||
        gamma.correctionRequired) {
        println("libpng4cj gamma initialization check failed")
        return 1
    }
    let gammaState = PngReadTransformState()
    if (!gammaState.setGammaFixed(PNG_DEFAULT_SRGB, PNG_DEFAULT_SRGB) ||
        gammaState.screenGamma() != PNG_GAMMA_SRGB ||
        gammaState.fileGamma() != PNG_GAMMA_SRGB_INVERSE) {
        println("libpng4cj fixed gamma setter check failed")
        return 1
    }
    let floatingGammaState = PngReadTransformState()
    if (!floatingGammaState.setGamma(2.2, 0.45455) ||
        floatingGammaState.screenGamma() != PNG_GAMMA_SRGB ||
        floatingGammaState.fileGamma() != PNG_GAMMA_SRGB_INVERSE) {
        println("libpng4cj floating gamma setter check failed")
        return 1
    }
    let initializedGammaState = PngReadTransformState()
    if (!initializedGammaState.setGammaFixed(Int32(106000), Int32(100000))) {
        println("libpng4cj initialized gamma state setup failed")
        return 1
    }
    let initializedGamma = initializePngReadTransformations(
        initializedGammaState,
        decodePngNonInterlaced(consumerGammaPng())
    )
    if (!initializedGamma.gammaConfigured() ||
        initializedGamma.chunkGamma() != Int32(45455) ||
        initializedGamma.fileGamma() != Int32(100000) ||
        initializedGamma.screenGamma() != Int32(106000) ||
        !initializedGamma.gammaCorrectionRequired()) {
        println("libpng4cj state-driven gamma initialization check failed")
        return 1
    }
    let gammaTable = pngBuildGamma8BitTable(Int32(220000))
    if (gammaTable.size() != Int64(256) ||
        gammaTable.value(UInt8(128)) != UInt8(56)) {
        println("libpng4cj 8-bit gamma table check failed")
        return 1
    }
    let gammaTables = initializedGamma.gamma8BitTables()
    let gammaCorrection = pngReciprocal2Fixed(Int32(106000), Int32(100000))
    if (!initializedGamma.gamma8BitTablesBuilt() ||
        initializedGamma.gamma8BitLinearTablesBuilt() ||
        !gammaTables.built() || gammaTables.linearTablesBuilt() ||
        gammaTables.direct().value(UInt8(128)) !=
            pngGamma8BitCorrect(UInt8(128), gammaCorrection)) {
        println("libpng4cj initialized 8-bit gamma table check failed")
        return 1
    }
    let gammaRow = applyInitializedPngGammaStage(
        initializedGamma,
        PngReadRowInfo(UInt32(1), UInt8(8), TruecolorAlpha),
        [64, 128, 192, 77]
    )
    if (!initializedGamma.hasStage(ReadStageGamma) ||
        gammaRow.row() != [
            gammaTables.direct().value(UInt8(64)),
            gammaTables.direct().value(UInt8(128)),
            gammaTables.direct().value(UInt8(192)),
            UInt8(77)
        ]) {
        println("libpng4cj initialized gamma row check failed")
        return 1
    }
    let gammaRgbDecoded = decodePngNonInterlaced(consumerGammaPng())
    let gammaRgbState = PngReadTransformState()
    gammaRgbState.markIhdrRead(gammaRgbDecoded.ihdr)
    if (!gammaRgbState.setRgbToGrayFixed(
        Convert, UInt32(21268), UInt32(71514)
    ) || !gammaRgbState.setGammaFixed(Int32(106000), Int32(100000))) {
        println("libpng4cj gamma-aware RGB-to-gray setup failed")
        return 1
    }
    let initializedGammaRgb = initializePngReadTransformations(
        gammaRgbState,
        gammaRgbDecoded
    )
    let gammaRgbTables = initializedGammaRgb.gamma8BitTables()
    let gammaRgbTransform = initializedGammaRgb.rgbToGrayTransform()
    let gammaRgbToLinear = gammaRgbTables.toLinear()
    let gammaRgbWeighted =
        UInt32(gammaRgbTransform.redCoefficient) *
            UInt32(gammaRgbToLinear.value(UInt8(64))) +
        UInt32(gammaRgbTransform.greenCoefficient) *
            UInt32(gammaRgbToLinear.value(UInt8(128))) +
        UInt32(gammaRgbTransform.blueCoefficient) *
            UInt32(gammaRgbToLinear.value(UInt8(192))) + UInt32(16384)
    let gammaRgbExpected = gammaRgbTables.fromLinear().value(
        UInt8(gammaRgbWeighted >> 15)
    )
    let gammaRgbRow = applyInitializedPngRgbToGrayStage(
        initializedGammaRgb,
        PngReadRowInfo(UInt32(1), UInt8(8), TruecolorAlpha),
        [64, 128, 192, 77]
    )
    if (gammaRgbRow.row() != [gammaRgbExpected, UInt8(77)] ||
        !gammaRgbRow.hadNonGrayPixels ||
        gammaRgbRow.info.colorType != GrayscaleAlpha) {
        println("libpng4cj gamma-aware 8-bit RGB-to-gray check failed")
        return 1
    }
    let gamma16Table = pngBuildGamma16BitTable(UInt8(8), Int32(220000))
    if (gamma16Table.segmentCount() != Int64(1) ||
        gamma16Table.value(UInt16(0x8080)) !=
            pngGamma16BitCorrect(UInt16(0x8080), Int32(220000))) {
        println("libpng4cj 16-bit gamma table check failed")
        return 1
    }
    let gamma16State = PngReadTransformState()
    if (!gamma16State.setScale16() ||
        !gamma16State.setGammaFixed(Int32(106000), Int32(100000))) {
        println("libpng4cj initialized 16-bit gamma setup failed")
        return 1
    }
    let initializedGamma16 = initializePngReadTransformations(
        gamma16State,
        decodePngNonInterlaced(consumerGamma16Png())
    )
    if (!initializedGamma16.gamma16BitTablesBuilt() ||
        !initializedGamma16.gamma16BitReductionTableBuilt() ||
        initializedGamma16.gamma16BitLinearTablesBuilt() ||
        initializedGamma16.gamma16BitShift() != UInt8(5) ||
        !initializedGamma16.hasStage(ReadStageGamma)) {
        println("libpng4cj initialized 16-bit gamma table check failed")
        return 1
    }
    let gamma16Row = applyInitializedPngReadStages(
        initializedGamma16,
        PngReadRowInfo(UInt32(1), UInt8(16), Grayscale),
        [0x12, 0x34]
    )
    let gamma16Expected = initializedGamma16.gamma16BitTables().direct().value(
        UInt16(0x1234)
    )
    let gamma16RowExpected: Array<Byte> = [
        UInt8(gamma16Expected >> UInt16(8))
    ]
    if (gamma16Row.row() != gamma16RowExpected) {
        println("libpng4cj initialized 16-bit gamma row check failed")
        return 1
    }
    let gamma16RgbDecoded = decodePngNonInterlaced(consumerGamma16Png())
    let gamma16RgbState = PngReadTransformState()
    gamma16RgbState.markIhdrRead(gamma16RgbDecoded.ihdr)
    if (!gamma16RgbState.setRgbToGrayFixed(
        Convert, UInt32(21268), UInt32(71514)
    ) || !gamma16RgbState.setGammaFixed(Int32(106000), Int32(100000))) {
        println("libpng4cj gamma-aware 16-bit RGB-to-gray setup failed")
        return 1
    }
    let initializedGamma16Rgb = initializePngReadTransformations(
        gamma16RgbState,
        gamma16RgbDecoded
    )
    let gamma16RgbTables = initializedGamma16Rgb.gamma16BitTables()
    let gamma16RgbTransform = initializedGamma16Rgb.rgbToGrayTransform()
    let gamma16ToLinear = gamma16RgbTables.toLinear()
    let gamma16Weighted =
        UInt64(gamma16RgbTransform.redCoefficient) *
            UInt64(gamma16ToLinear.value(UInt16(0x1234))) +
        UInt64(gamma16RgbTransform.greenCoefficient) *
            UInt64(gamma16ToLinear.value(UInt16(0x5678))) +
        UInt64(gamma16RgbTransform.blueCoefficient) *
            UInt64(gamma16ToLinear.value(UInt16(0x9abc))) + UInt64(16384)
    let gamma16RgbExpected = gamma16RgbTables.fromLinear().value(
        UInt16(gamma16Weighted >> 15)
    )
    let gamma16RgbRow = applyInitializedPngRgbToGrayStage(
        initializedGamma16Rgb,
        PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha),
        [0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0]
    )
    let gamma16RgbRowExpected: Array<Byte> = [
        UInt8(gamma16RgbExpected >> UInt16(8)),
        UInt8(gamma16RgbExpected & UInt16(0xff)),
        0xde,
        0xf0
    ]
    if (gamma16RgbRow.row() != gamma16RgbRowExpected ||
        !gamma16RgbRow.hadNonGrayPixels ||
        gamma16RgbRow.info.colorType != GrayscaleAlpha) {
        println("libpng4cj gamma-aware 16-bit RGB-to-gray check failed")
        return 1
    }
    let indexedBackgroundDecoded = decodePngNonInterlaced(
        consumerIndexedBackgroundPng()
    )
    let indexedBackgroundState = PngReadTransformState()
    if (!indexedBackgroundState.setBackgroundFixed(
        PngBackground(UInt8(3), UInt16(0), UInt16(0), UInt16(0), UInt16(0)),
        BackgroundGammaScreen,
        true,
        PNG_FP_1
    ) || !indexedBackgroundState.setExpand()) {
        println("libpng4cj indexed background setup failed")
        return 1
    }
    let indexedBackground = transformPngRowsInitialized(
        indexedBackgroundDecoded,
        indexedBackgroundState
    )
    let indexedExpected: Array<Byte> = [
        40, 50, 60,
        70, 80, 90,
        200, 210, 220
    ]
    if (indexedBackground.info.colorType != Truecolor ||
        indexedBackground.info.channels != UInt8(3) ||
        indexedBackground.row(0) != indexedExpected) {
        println("libpng4cj indexed palette background check failed")
        return 1
    }
    let alphaModeState = PngReadTransformState()
    if (!alphaModeState.setAlphaMode(AlphaAssociated, 2.2)) {
        println("libpng4cj alpha-mode setup failed")
        return 1
    }
    let alphaModeInitialized = initializePngReadTransformations(
        alphaModeState,
        gammaRgbDecoded
    )
    if (alphaModeInitialized.alphaMode() != AlphaAssociated ||
        alphaModeInitialized.defaultGamma() != Int32(45455) ||
        alphaModeInitialized.fileGamma() != Int32(45455) ||
        alphaModeInitialized.screenGamma() != PNG_FP_1 ||
        !alphaModeInitialized.composeEnabled() ||
        alphaModeInitialized.encodeAlphaEnabled() ||
        alphaModeInitialized.optimizeAlphaEnabled() ||
        alphaModeInitialized.backgroundGammaCode() != BackgroundGammaFile) {
        println("libpng4cj alpha-mode initialization check failed")
        return 1
    }
    println("libpng4cj ${LIBPNG4CJ_VERSION} / libpng ${LIBPNG_UPSTREAM_VERSION}")
    0
}
