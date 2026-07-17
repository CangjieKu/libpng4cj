package libpng4cj_consumer

import std.fs.*
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

private let CONSUMER_GRAY_ALPHA_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0xe7, 0xe0, 0xe4, 0x02,
    0x00, 0x00, 0x55, 0x00, 0x23
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

private func consumerAncillaryMetadataPng(): Array<Byte> {
    let ihdr = Array<Byte>(13, repeat: UInt8(0))
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

    var png = joinConsumerBytes(
        PNG_SIGNATURE,
        makeConsumerChunk(PNG_CHUNK_IHDR, ihdr)
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_cICP, [UInt8(1), UInt8(13), UInt8(0), UInt8(1)])
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_sCAL, [UInt8(1), UInt8(0x31), UInt8(0), UInt8(0x32)])
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_IDAT, CONSUMER_RGBA_ZLIB)
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_eXIf, [UInt8(0x49), UInt8(0x49), UInt8(0x2a), UInt8(0)])
    )
    joinConsumerBytes(png, makeConsumerChunk(PNG_CHUNK_IEND, []))
}

private func consumerChromaticityPng(): Array<Byte> {
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

    let chromaticityValues: Array<UInt32> = [
        UInt32(34570), UInt32(35850),
        UInt32(73470), UInt32(26530),
        UInt32(15960), UInt32(84040),
        UInt32(3660), UInt32(10)
    ]
    let chromaticities = Array<Byte>(32, repeat: 0)
    var valueIndex: Int64 = 0
    while (valueIndex < chromaticityValues.size) {
        let encoded = writeUInt32Be(chromaticityValues[valueIndex])
        var byteIndex: Int64 = 0
        while (byteIndex < encoded.size) {
            chromaticities[valueIndex * 4 + byteIndex] = encoded[byteIndex]
            byteIndex += 1
        }
        valueIndex += 1
    }

    var png = joinConsumerBytes(
        PNG_SIGNATURE,
        makeConsumerChunk(PNG_CHUNK_IHDR, ihdr)
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_cHRM, chromaticities)
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_IDAT, CONSUMER_RGBA_ZLIB)
    )
    joinConsumerBytes(png, makeConsumerChunk(PNG_CHUNK_IEND, []))
}

private func consumerGrayDispatchPng(): Array<Byte> {
    let ihdr = Array<Byte>(13, repeat: 0)
    ihdr[3] = UInt8(2)
    ihdr[7] = UInt8(1)
    ihdr[8] = UInt8(8)
    ihdr[9] = UInt8(4)
    var png = joinConsumerBytes(
        PNG_SIGNATURE,
        makeConsumerChunk(PNG_CHUNK_IHDR, ihdr)
    )
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_IDAT, CONSUMER_GRAY_ALPHA_ZLIB)
    )
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
    let corruptGammaPng = consumerGammaPng()
    corruptGammaPng[48] = corruptGammaPng[48] ^ UInt8(1)
    let crcSession = PngReadSession(corruptGammaPng)
    crcSession.setCrcAction(CrcNoChange, CrcWarnUse)
    crcSession.readIhdr()
    let corruptGammaChunk = crcSession.readNextChunk()
    if (corruptGammaChunk.crcValid ||
        crcSession.ancillaryCrcAction() != CrcWarnUse ||
        crcSession.crcWarningCount() != Int64(1)) {
        println("libpng4cj CRC action session check failed")
        return 1
    }
    let crcDecoded = decodePngNonInterlaced(
        corruptGammaPng,
        CrcNoChange,
        CrcWarnUse
    )
    if (!crcDecoded.metadata.hasGamma ||
        crcDecoded.metadata.gamma != UInt32(45455)) {
        println("libpng4cj CRC action decode check failed")
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
    let chromaticityDecoded = decodePngNonInterlaced(
        consumerChromaticityPng()
    )
    let chromaticityState = PngReadTransformState()
    chromaticityState.markIhdrRead(chromaticityDecoded.ihdr)
    if (!chromaticityState.setRgbToGrayFixed(
        Convert,
        Int64(-1),
        Int64(-1)
    )) {
        println("libpng4cj cHRM RGB-to-gray setup failed")
        return 1
    }
    let chromaticityInit = initializePngReadTransformations(
        chromaticityState,
        chromaticityDecoded
    )
    let chromaticityTransform = chromaticityInit.rgbToGrayTransform()
    if (chromaticityTransform.redCoefficient != UInt16(9440) ||
        chromaticityTransform.greenCoefficient != UInt16(23325) ||
        chromaticityTransform.blueCoefficient != UInt16(3)) {
        println("libpng4cj cHRM RGB-to-gray coefficient check failed")
        return 1
    }
    let chromaticityWholeState = PngReadTransformState()
    chromaticityWholeState.markIhdrRead(chromaticityDecoded.ihdr)
    if (!chromaticityWholeState.setRgbToGrayFixed(
        Convert,
        Int64(-1),
        Int64(-1)
    )) {
        println("libpng4cj cHRM RGB-to-gray whole-image setup failed")
        return 1
    }
    let chromaticityRows = transformPngRowsInitialized(
        chromaticityDecoded,
        chromaticityWholeState
    )
    if (chromaticityRows.info.colorType != GrayscaleAlpha ||
        chromaticityRows.info.channels != UInt8(2)) {
        println("libpng4cj cHRM RGB-to-gray whole-image check failed")
        return 1
    }
    let grayDispatchDecoded = decodePngNonInterlaced(
        consumerGrayDispatchPng()
    )
    let grayDispatchState = PngReadTransformState()
    grayDispatchState.markIhdrRead(grayDispatchDecoded.ihdr)
    if (!grayDispatchState.setBackgroundFixed(
        PngBackground(
            UInt8(0), UInt16(200), UInt16(40), UInt16(40), UInt16(40)
        ),
        BackgroundGammaScreen,
        false,
        PNG_FP_1
    ) || !grayDispatchState.setGrayToRgb()) {
        println("libpng4cj background-aware Gray-to-RGB setup failed")
        return 1
    }
    let grayDispatchInit = initializePngReadTransformations(
        grayDispatchState,
        grayDispatchDecoded
    )
    let grayDispatchRow = applyInitializedPngReadStages(
        grayDispatchInit,
        PngReadRowInfo(UInt32(1), UInt8(8), GrayscaleAlpha),
        [UInt8(100), UInt8(0)]
    )
    let grayDispatchInfo = projectPngReadTransformInfo(
        grayDispatchInit,
        grayDispatchDecoded
    )
    if (!grayDispatchInit.backgroundIsGray() ||
        !grayDispatchInit.grayToRgbAfterExpand16() ||
        grayDispatchInit.background().gray != UInt16(40) ||
        grayDispatchRow.info.colorType != Truecolor ||
        grayDispatchRow.row() != [UInt8(40), UInt8(40), UInt8(40)] ||
        !grayDispatchInfo.hasBackground ||
        grayDispatchInfo.background().gray != UInt16(40) ||
        grayDispatchInfo.colorType != Truecolor ||
        grayDispatchInfo.channels != UInt8(3) ||
        grayDispatchInfo.transparencyCount != Int64(0)) {
        println("libpng4cj background-aware Gray-to-RGB check failed")
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
    let optimizedPaletteState = PngReadTransformState()
    if (!optimizedPaletteState.setAlphaModeFixed(
        AlphaOptimized,
        Int32(220000)
    ) || !optimizedPaletteState.setExpand()) {
        println("libpng4cj optimized palette setup failed")
        return 1
    }
    let optimizedPaletteInit = initializePngReadTransformations(
        optimizedPaletteState,
        indexedBackgroundDecoded
    )
    let optimizedPaletteRow = applyInitializedPngReadStages(
        optimizedPaletteInit,
        PngReadRowInfo(indexedBackgroundDecoded.ihdr),
        indexedBackgroundDecoded.row(0)
    )
    let optimizedPalette = optimizedPaletteInit.effectivePalette()
    let optimizedAlpha = optimizedPaletteInit.effectivePaletteAlpha()
    let optimizedExpected: Array<Byte> = [
        optimizedPalette[0], optimizedPalette[1], optimizedPalette[2],
        optimizedAlpha[0],
        optimizedPalette[3], optimizedPalette[4], optimizedPalette[5],
        optimizedAlpha[1],
        optimizedPalette[6], optimizedPalette[7], optimizedPalette[8],
        optimizedAlpha[2]
    ]
    if (!optimizedPaletteInit.optimizeAlphaEnabled() ||
        !optimizedPaletteInit.paletteComposeApplied() ||
        optimizedPaletteRow.info.colorType != TruecolorAlpha ||
        optimizedPaletteRow.row() != optimizedExpected) {
        println("libpng4cj optimized palette alpha check failed")
        return 1
    }
    let invertedPaletteState = PngReadTransformState()
    if (!invertedPaletteState.setBackgroundFixed(
        PngBackground(UInt8(3), UInt16(0), UInt16(0), UInt16(0), UInt16(0)),
        BackgroundGammaScreen,
        true,
        PNG_FP_1
    ) || !invertedPaletteState.setExpandGrayOneTwoFourToEight() ||
        !invertedPaletteState.setInvertAlpha()) {
        println("libpng4cj palette tRNS invert setup failed")
        return 1
    }
    let invertedPalette = initializePngReadTransformations(
        invertedPaletteState,
        indexedBackgroundDecoded
    )
    let invertedExpectedAlpha: Array<Byte> = [255, 127, 0]
    if (invertedPalette.effectiveTransparencyExpansion ||
        invertedPalette.effectivePaletteAlpha() != invertedExpectedAlpha ||
        indexedBackgroundDecoded.metadata.paletteAlpha() != [0, 128, 255]) {
        println("libpng4cj palette tRNS invert initialization check failed")
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
    let alphaModeInfo = projectPngReadTransformInfo(
        alphaModeInitialized,
        gammaRgbDecoded
    )
    if (!alphaModeInfo.hasGamma || alphaModeInfo.gamma != Int32(45455) ||
        !alphaModeInfo.hasBackground) {
        println("libpng4cj transformed info metadata check failed")
        return 1
    }
    let encodeAlphaState = PngReadTransformState()
    if (!encodeAlphaState.setAlphaModeFixed(AlphaBroken, Int32(220000))) {
        println("libpng4cj encode-alpha setup failed")
        return 1
    }
    let encodeAlphaInitialized = initializePngReadTransformations(
        encodeAlphaState,
        gammaRgbDecoded
    )
    let encodeAlphaRow = applyInitializedPngReadStages(
        encodeAlphaInitialized,
        PngReadRowInfo(UInt32(1), UInt8(8), TruecolorAlpha),
        [64, 128, 192, 77]
    )
    let encodedAlpha = encodeAlphaInitialized.gamma8BitTables().fromLinear().value(
        UInt8(77)
    )
    if (!encodeAlphaInitialized.hasStage(ReadStageEncodeAlpha) ||
        encodeAlphaRow.row()[3] != encodedAlpha) {
        println("libpng4cj encode-alpha row check failed")
        return 1
    }
    let quantizePalette: Array<Byte> = [
        0, 0, 0,
        0xff, 0, 0,
        0, 0xff, 0,
        0, 0, 0xff
    ]
    let quantizeDecoded = decodePngNonInterlaced(consumerGammaPng())
    let baselineQuantizeState = PngReadTransformState()
    if (!baselineQuantizeState.setQuantize(
        quantizePalette, 4, 2, true
    )) {
        println("libpng4cj baseline quantize setup failed")
        return 1
    }
    let recoveredQuantizeState = PngReadTransformState()
    if (!recoveredQuantizeState.setQuantize(
        quantizePalette,
        4,
        2,
        true,
        PngQuantizeAllocationFaultPlan(1, 1, 2)
    )) {
        println("libpng4cj recovered quantize setup failed")
        return 1
    }
    let baselineQuantized = transformPngRowsInitialized(
        quantizeDecoded,
        baselineQuantizeState
    )
    let recoveredQuantized = transformPngRowsInitialized(
        quantizeDecoded,
        recoveredQuantizeState
    )
    if (recoveredQuantizeState.quantizeAllocationWarningCount() != Int64(1) ||
        recoveredQuantizeState.quantizeAllocationRetryCount() != Int64(1) ||
        recoveredQuantizeState.quantizePalette() !=
            baselineQuantizeState.quantizePalette() ||
        recoveredQuantized.row(0) != baselineQuantized.row(0) ||
        recoveredQuantized.info.colorType != Indexed ||
        recoveredQuantized.info.channels != UInt8(1) ||
        recoveredQuantized.info.rowBytes != UInt64(2)) {
        println("libpng4cj quantize allocation retry check failed")
        return 1
    }
    let userTransformDecoded = decodePngNonInterlaced(consumerGammaPng())
    let userTransformState = PngReadTransformState()
    if (!userTransformState.setUserTransformInfo(UInt8(8), UInt8(4)) ||
        !userTransformState.setReadUserTransform()) {
        println("libpng4cj identity user-transform setup failed")
        return 1
    }
    let userTransformInitialized = initializePngReadTransformations(
        userTransformState,
        userTransformDecoded
    )
    let userTransformSource = userTransformDecoded.row(0)
    let identityUserTransform = applyInitializedPngReadStages(
        userTransformInitialized,
        PngReadRowInfo(userTransformDecoded.ihdr),
        userTransformSource
    )
    let projectedUserTransform = projectPngReadTransformInfo(
        userTransformInitialized,
        userTransformDecoded
    )
    if (!userTransformInitialized.hasStage(ReadStageUserTransform) ||
        identityUserTransform.row() != userTransformSource ||
        projectedUserTransform.bitDepth != UInt8(8) ||
        projectedUserTransform.channels != UInt8(4)) {
        println("libpng4cj identity user-transform check failed")
        return 1
    }
    let lateUserTransform: (
        PngReadUserTransformContext,
        PngReadRowInfo,
        Array<Byte>
    ) -> PngReadUserTransformResult = {
        _, info, row =>
            row[0] = UInt8(99)
            PngReadUserTransformResult(info, row)
    }
    if (!userTransformState.setReadUserTransform(lateUserTransform)) {
        println("libpng4cj late user-transform replacement failed")
        return 1
    }
    let lateUserTransformRow = applyInitializedPngReadStages(
        userTransformInitialized,
        PngReadRowInfo(userTransformDecoded.ihdr),
        userTransformSource
    )
    if (lateUserTransformRow.row()[0] != UInt8(99) ||
        userTransformSource[0] == UInt8(99)) {
        println("libpng4cj late user-transform execution failed")
        return 1
    }
    let ancillaryMetadata = decodePngNonInterlaced(
        consumerAncillaryMetadataPng(),
        RetainAncillary
    ).metadata
    if (!ancillaryMetadata.hasCodingIndependentCodePoints ||
        ancillaryMetadata.codingIndependentCodePoints.transferFunction != UInt8(13) ||
        !ancillaryMetadata.hasPhysicalScale ||
        ancillaryMetadata.physicalScale.width() != [UInt8(0x31)] ||
        !ancillaryMetadata.hasExif ||
        ancillaryMetadata.exif() != [UInt8(0x49), UInt8(0x49), UInt8(0x2a), UInt8(0)] ||
        ancillaryMetadata.unknownChunkCount() != Int64(0)) {
        println("libpng4cj ancillary metadata consumer check failed")
        return 1
    }
    let adam7 = decodePngRgba8(File.readFrom("testdata/ibasn0g01.png"))
    let adam7FirstRow = adam7.row(0)
    if (adam7.ihdr.interlaceMethod != Adam7 || adam7.rowCount() != Int64(32) ||
        adam7FirstRow.size != Int64(128) || adam7FirstRow[0] != UInt8(255) ||
        adam7FirstRow[3] != UInt8(255) || adam7FirstRow[124] != UInt8(0) ||
        adam7FirstRow[127] != UInt8(255)) {
        println("libpng4cj Adam7 consumer check failed")
        return 1
    }
    println("libpng4cj ${LIBPNG4CJ_VERSION} / libpng ${LIBPNG_UPSTREAM_VERSION}")
    0
}
