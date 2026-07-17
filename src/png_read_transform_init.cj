package libpng4cj

import std.collection.ArrayList

public enum PngReadTransformStage <: Equatable<PngReadTransformStage> & ToString {
    | ReadStageExpand
    | ReadStageStripAlpha
    | ReadStageRgbToGray
    | ReadStageGrayToRgb
    | ReadStageScale16To8
    | ReadStageStrip16To8
    | ReadStageQuantize
    | ReadStageExpand16
    | ReadStageInvertMono
    | ReadStageInvertAlpha
    | ReadStageUnshift
    | ReadStageBgr
    | ReadStageFiller
    | ReadStageSwapAlpha
    | ReadStageUnpack
    | ReadStagePackSwap
    | ReadStageByteSwap
    | ReadStagePaletteIndexCheck
    | ReadStageUserTransform
    | ReadStageGamma
    | ReadStageCompose
    | ReadStageStripAlphaAfterCompose
    | ReadStageEncodeAlpha

    public operator func ==(right: PngReadTransformStage): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngReadTransformStage): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ReadStageExpand => 0
            case ReadStageStripAlpha => 1
            case ReadStageRgbToGray => 2
            case ReadStageGrayToRgb => 3
            case ReadStageScale16To8 => 4
            case ReadStageStrip16To8 => 5
            case ReadStageQuantize => 6
            case ReadStageExpand16 => 7
            case ReadStageInvertAlpha => 8
            case ReadStageUnshift => 9
            case ReadStageFiller => 10
            case ReadStageSwapAlpha => 11
            case ReadStageBgr => 12
            case ReadStageInvertMono => 13
            case ReadStageUnpack => 14
            case ReadStagePackSwap => 15
            case ReadStageByteSwap => 16
            case ReadStagePaletteIndexCheck => 17
            case ReadStageUserTransform => 18
            case ReadStageGamma => 19
            case ReadStageCompose => 20
            case ReadStageStripAlphaAfterCompose => 21
            case ReadStageEncodeAlpha => 22
        }
    }

    public func toString(): String {
        match (this) {
            case ReadStageExpand => "EXPAND"
            case ReadStageStripAlpha => "STRIP_ALPHA"
            case ReadStageRgbToGray => "RGB_TO_GRAY"
            case ReadStageGrayToRgb => "GRAY_TO_RGB"
            case ReadStageScale16To8 => "SCALE_16_TO_8"
            case ReadStageStrip16To8 => "STRIP_16_TO_8"
            case ReadStageQuantize => "QUANTIZE"
            case ReadStageExpand16 => "EXPAND_16"
            case ReadStageInvertMono => "INVERT_MONO"
            case ReadStageInvertAlpha => "INVERT_ALPHA"
            case ReadStageUnshift => "UNSHIFT"
            case ReadStageUnpack => "UNPACK"
            case ReadStageBgr => "BGR"
            case ReadStagePackSwap => "PACK_SWAP"
            case ReadStageFiller => "FILLER"
            case ReadStageSwapAlpha => "SWAP_ALPHA"
            case ReadStageByteSwap => "BYTE_SWAP"
            case ReadStagePaletteIndexCheck => "PALETTE_INDEX_CHECK"
            case ReadStageUserTransform => "USER_TRANSFORM"
            case ReadStageGamma => "GAMMA"
            case ReadStageCompose => "COMPOSE"
            case ReadStageStripAlphaAfterCompose => "STRIP_ALPHA_AFTER_COMPOSE"
            case ReadStageEncodeAlpha => "ENCODE_ALPHA"
        }
    }
}

public class PngReadTransformInitialization {
    public let usesPaletteInitializer: Bool
    public let sourceHasTransparency: Bool
    public let inputHasAlpha: Bool
    public let inputHasTransparency: Bool
    public let transparencyStripped: Bool
    public let effectiveTransparencyExpansion: Bool
    public let effectiveOutputHasAlpha: Bool
    private let backgroundConfiguredValue: Bool
    private let composeEnabledValue: Bool
    private let backgroundExpandEnabledValue: Bool
    private let backgroundIsGrayValue: Bool
    private let backgroundValue: PngBackground
    private let backgroundOriginalValue: PngBackground
    private let backgroundLinearValue: PngBackground
    private let backgroundGammaCodeValue: PngBackgroundGammaCode
    private let effectiveBackgroundGammaCodeValue: PngBackgroundGammaCode
    private let backgroundGammaValue: Int32
    private let backgroundDepthNormalizedValue: Bool
    private let backgroundGammaInitializedValue: Bool
    private let backgroundToLinearGammaValue: Int32
    private let backgroundToScreenGammaValue: Int32
    private let gammaConfiguredValue: Bool
    private let alphaModeConfiguredValue: Bool
    private let alphaModeValue: PngAlphaMode
    private let encodeAlphaEnabledValue: Bool
    private let optimizeAlphaEnabledValue: Bool
    private let defaultGammaValue: Int32
    private let chunkGammaValue: Int32
    private let initializedGammaValuesValue: PngGammaValues
    private let initializedGamma8BitTablesValue: PngGamma8BitTables
    private let initializedGamma16BitTablesValue: PngGamma16BitTables
    private let ownedEffectivePalette: Array<Byte>
    private let ownedEffectivePaletteAlpha: Array<Byte>
    private let palettePreprocessedValue: Bool
    private let paletteComposeAppliedValue: Bool
    private let paletteGammaAppliedValue: Bool
    private let ownedExpandPalette: Array<Byte>
    private let ownedExpandPaletteAlpha: Array<Byte>
    private let expandTransparencyValue: PngExpandTransparency
    private let composeTransparencyValue: PngExpandTransparency
    private let rgbToGrayEnabledValue: Bool
    private let rgbToGrayTransformValue: PngRgbToGrayTransform
    private let quantizeEnabledValue: Bool
    private let quantizeModeValue: PngQuantizeMode
    private let ownedQuantizePalette: Array<Byte>
    private let quantizePaletteCountValue: Int64
    private let ownedQuantizeIndex: Array<Byte>
    private let ownedQuantizePaletteLookup: Array<Byte>
    private let invertMonoEnabledValue: Bool
    private let invertAlphaEnabledValue: Bool
    private let shiftEnabledValue: Bool
    private let shiftSignificantBitsValue: PngSignificantBits
    private let packingEnabledValue: Bool
    private let bgrEnabledValue: Bool
    private let packSwapEnabledValue: Bool
    private let fillerModeValue: PngFillerMode
    private let fillerValueValue: UInt16
    private let swapAlphaEnabledValue: Bool
    private let byteSwapEnabledValue: Bool
    private let checkForInvalidIndexEnabledValue: Bool
    private let paletteEntryCountValue: Int64
    private let readUserTransformRegistrationValue:
        PngReadUserTransformRegistration
    private let ownedStages: Array<PngReadTransformStage>

    init(
        usesPaletteInitializer: Bool,
        sourceHasTransparency: Bool,
        inputHasAlpha: Bool,
        inputHasTransparency: Bool,
        transparencyStripped: Bool,
        effectiveTransparencyExpansion: Bool,
        effectiveOutputHasAlpha: Bool,
        backgroundConfigured: Bool,
        composeEnabled: Bool,
        backgroundExpandEnabled: Bool,
        backgroundIsGray: Bool,
        background: PngBackground,
        backgroundOriginal: PngBackground,
        backgroundLinear: PngBackground,
        backgroundGammaCode: PngBackgroundGammaCode,
        effectiveBackgroundGammaCode: PngBackgroundGammaCode,
        backgroundGamma: Int32,
        backgroundDepthNormalized: Bool,
        backgroundGammaInitialized: Bool,
        backgroundToLinearGamma: Int32,
        backgroundToScreenGamma: Int32,
        gammaConfigured: Bool,
        alphaModeConfigured: Bool,
        alphaMode: PngAlphaMode,
        encodeAlphaEnabled: Bool,
        optimizeAlphaEnabled: Bool,
        defaultGamma: Int32,
        chunkGamma: Int32,
        initializedGammaValues: PngGammaValues,
        initializedGamma8BitTables: PngGamma8BitTables,
        initializedGamma16BitTables: PngGamma16BitTables,
        effectivePalette: Array<Byte>,
        effectivePaletteAlpha: Array<Byte>,
        palettePreprocessed: Bool,
        paletteComposeApplied: Bool,
        paletteGammaApplied: Bool,
        expandPalette: Array<Byte>,
        expandPaletteAlpha: Array<Byte>,
        expandTransparency: PngExpandTransparency,
        composeTransparency: PngExpandTransparency,
        rgbToGrayEnabled: Bool,
        rgbToGrayTransform: PngRgbToGrayTransform,
        quantizeEnabled: Bool,
        quantizeMode: PngQuantizeMode,
        quantizePalette: Array<Byte>,
        quantizePaletteCount: Int64,
        quantizeIndex: Array<Byte>,
        quantizePaletteLookup: Array<Byte>,
        invertMonoEnabled: Bool,
        invertAlphaEnabled: Bool,
        shiftEnabled: Bool,
        shiftSignificantBits: PngSignificantBits,
        packingEnabled: Bool,
        bgrEnabled: Bool,
        packSwapEnabled: Bool,
        fillerMode: PngFillerMode,
        fillerValue: UInt16,
        swapAlphaEnabled: Bool,
        byteSwapEnabled: Bool,
        checkForInvalidIndexEnabled: Bool,
        paletteEntryCount: Int64,
        readUserTransformRegistration: PngReadUserTransformRegistration,
        stages: Array<PngReadTransformStage>
    ) {
        this.usesPaletteInitializer = usesPaletteInitializer
        this.sourceHasTransparency = sourceHasTransparency
        this.inputHasAlpha = inputHasAlpha
        this.inputHasTransparency = inputHasTransparency
        this.transparencyStripped = transparencyStripped
        this.effectiveTransparencyExpansion = effectiveTransparencyExpansion
        this.effectiveOutputHasAlpha = effectiveOutputHasAlpha
        backgroundConfiguredValue = backgroundConfigured
        composeEnabledValue = composeEnabled
        backgroundExpandEnabledValue = backgroundExpandEnabled
        backgroundIsGrayValue = backgroundIsGray
        backgroundValue = PngBackground(background)
        backgroundOriginalValue = PngBackground(backgroundOriginal)
        backgroundLinearValue = PngBackground(backgroundLinear)
        backgroundGammaCodeValue = backgroundGammaCode
        effectiveBackgroundGammaCodeValue = effectiveBackgroundGammaCode
        backgroundGammaValue = backgroundGamma
        backgroundDepthNormalizedValue = backgroundDepthNormalized
        backgroundGammaInitializedValue = backgroundGammaInitialized
        backgroundToLinearGammaValue = backgroundToLinearGamma
        backgroundToScreenGammaValue = backgroundToScreenGamma
        gammaConfiguredValue = gammaConfigured
        alphaModeConfiguredValue = alphaModeConfigured
        alphaModeValue = alphaMode
        encodeAlphaEnabledValue = encodeAlphaEnabled
        optimizeAlphaEnabledValue = optimizeAlphaEnabled
        defaultGammaValue = defaultGamma
        chunkGammaValue = chunkGamma
        initializedGammaValuesValue = PngGammaValues(
            initializedGammaValues.fileGamma,
            initializedGammaValues.screenGamma,
            initializedGammaValues.correctionRequired
        )
        initializedGamma8BitTablesValue = PngGamma8BitTables(
            initializedGamma8BitTables
        )
        initializedGamma16BitTablesValue = PngGamma16BitTables(
            initializedGamma16BitTables
        )
        ownedEffectivePalette = effectivePalette.clone()
        ownedEffectivePaletteAlpha = effectivePaletteAlpha.clone()
        palettePreprocessedValue = palettePreprocessed
        paletteComposeAppliedValue = paletteComposeApplied
        paletteGammaAppliedValue = paletteGammaApplied
        ownedExpandPalette = expandPalette.clone()
        ownedExpandPaletteAlpha = expandPaletteAlpha.clone()
        expandTransparencyValue = expandTransparency
        composeTransparencyValue = composeTransparency
        rgbToGrayEnabledValue = rgbToGrayEnabled
        rgbToGrayTransformValue = PngRgbToGrayTransform(rgbToGrayTransform)
        quantizeEnabledValue = quantizeEnabled
        quantizeModeValue = quantizeMode
        ownedQuantizePalette = quantizePalette.clone()
        quantizePaletteCountValue = quantizePaletteCount
        ownedQuantizeIndex = quantizeIndex.clone()
        ownedQuantizePaletteLookup = quantizePaletteLookup.clone()
        invertMonoEnabledValue = invertMonoEnabled
        invertAlphaEnabledValue = invertAlphaEnabled
        shiftEnabledValue = shiftEnabled
        shiftSignificantBitsValue = PngSignificantBits(
            shiftSignificantBits.gray,
            shiftSignificantBits.red,
            shiftSignificantBits.green,
            shiftSignificantBits.blue,
            shiftSignificantBits.alpha
        )
        packingEnabledValue = packingEnabled
        bgrEnabledValue = bgrEnabled
        packSwapEnabledValue = packSwapEnabled
        fillerModeValue = fillerMode
        fillerValueValue = fillerValue
        swapAlphaEnabledValue = swapAlphaEnabled
        byteSwapEnabledValue = byteSwapEnabled
        checkForInvalidIndexEnabledValue = checkForInvalidIndexEnabled
        paletteEntryCountValue = paletteEntryCount
        readUserTransformRegistrationValue = readUserTransformRegistration
        ownedStages = stages.clone()
    }

    public func stageCount(): Int64 {
        ownedStages.size + if (readUserTransformEnabled()) { Int64(1) } else { Int64(0) }
    }

    public func stage(index: Int64): PngReadTransformStage {
        if (index < 0) {
            throw PngFormatException(
                InvalidArgument,
                index,
                "read transform stage index is out of bounds"
            )
        }
        if (index >= 0 && index < ownedStages.size) {
            return ownedStages[index]
        }
        if (index == ownedStages.size && readUserTransformEnabled()) {
            return ReadStageUserTransform
        }
        throw PngFormatException(
            InvalidArgument,
            index,
            "read transform stage index is out of bounds"
        )
    }

    public func stages(): Array<PngReadTransformStage> {
        let output = ArrayList<PngReadTransformStage>()
        for (stage in ownedStages) {
            output.add(stage)
        }
        if (readUserTransformEnabled()) {
            output.add(ReadStageUserTransform)
        }
        output.toArray()
    }

    public func hasStage(expected: PngReadTransformStage): Bool {
        if (expected == ReadStageUserTransform) {
            return readUserTransformEnabled()
        }
        var index: Int64 = 0
        while (index < ownedStages.size) {
            if (ownedStages[index] == expected) {
                return true
            }
            index += 1
        }
        false
    }

    public func quantizeEnabled(): Bool {
        quantizeEnabledValue
    }

    public func backgroundConfigured(): Bool {
        backgroundConfiguredValue
    }

    public func composeEnabled(): Bool {
        composeEnabledValue
    }

    public func backgroundExpandEnabled(): Bool {
        backgroundExpandEnabledValue
    }

    public func backgroundIsGray(): Bool {
        backgroundIsGrayValue
    }

    public func grayToRgbAfterExpand16(): Bool {
        backgroundIsGrayValue && hasStage(ReadStageGrayToRgb)
    }

    public func background(): PngBackground {
        if (!backgroundConfiguredValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no background configuration"
            )
        }
        PngBackground(backgroundValue)
    }

    public func backgroundOriginal(): PngBackground {
        if (!backgroundConfiguredValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no original background"
            )
        }
        PngBackground(backgroundOriginalValue)
    }

    public func backgroundLinear(): PngBackground {
        if (!backgroundConfiguredValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no linear background"
            )
        }
        PngBackground(backgroundLinearValue)
    }

    public func backgroundGammaCode(): PngBackgroundGammaCode {
        if (!backgroundConfiguredValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no background gamma code"
            )
        }
        backgroundGammaCodeValue
    }

    public func effectiveBackgroundGammaCode(): PngBackgroundGammaCode {
        if (!backgroundConfiguredValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no effective background gamma code"
            )
        }
        effectiveBackgroundGammaCodeValue
    }

    public func backgroundGamma(): Int32 {
        if (!backgroundConfiguredValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no background gamma"
            )
        }
        backgroundGammaValue
    }

    public func backgroundDepthNormalized(): Bool {
        backgroundDepthNormalizedValue
    }

    public func backgroundGammaInitialized(): Bool {
        backgroundGammaInitializedValue
    }

    public func backgroundToLinearGamma(): Int32 {
        if (!backgroundGammaInitializedValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no background-to-linear gamma"
            )
        }
        backgroundToLinearGammaValue
    }

    public func backgroundToScreenGamma(): Int32 {
        if (!backgroundGammaInitializedValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no background-to-screen gamma"
            )
        }
        backgroundToScreenGammaValue
    }

    public func gammaConfigured(): Bool {
        gammaConfiguredValue
    }

    public func alphaModeConfigured(): Bool {
        alphaModeConfiguredValue
    }

    public func alphaMode(): PngAlphaMode {
        if (!alphaModeConfiguredValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no alpha-mode configuration"
            )
        }
        alphaModeValue
    }

    public func encodeAlphaEnabled(): Bool {
        encodeAlphaEnabledValue
    }

    public func optimizeAlphaEnabled(): Bool {
        optimizeAlphaEnabledValue
    }

    public func defaultGamma(): Int32 {
        defaultGammaValue
    }

    public func chunkGamma(): Int32 {
        chunkGammaValue
    }

    public func fileGamma(): Int32 {
        initializedGammaValuesValue.fileGamma
    }

    public func screenGamma(): Int32 {
        initializedGammaValuesValue.screenGamma
    }

    public func gammaCorrectionRequired(): Bool {
        initializedGammaValuesValue.correctionRequired
    }

    public func gammaValues(): PngGammaValues {
        PngGammaValues(
            initializedGammaValuesValue.fileGamma,
            initializedGammaValuesValue.screenGamma,
            initializedGammaValuesValue.correctionRequired
        )
    }

    public func gamma8BitTablesBuilt(): Bool {
        initializedGamma8BitTablesValue.built()
    }

    public func gamma8BitLinearTablesBuilt(): Bool {
        initializedGamma8BitTablesValue.linearTablesBuilt()
    }

    public func gamma8BitTables(): PngGamma8BitTables {
        PngGamma8BitTables(initializedGamma8BitTablesValue)
    }

    public func gamma16BitTablesBuilt(): Bool {
        initializedGamma16BitTablesValue.built()
    }

    public func gamma16BitLinearTablesBuilt(): Bool {
        initializedGamma16BitTablesValue.linearTablesBuilt()
    }

    public func gamma16BitReductionTableBuilt(): Bool {
        initializedGamma16BitTablesValue.reductionTableBuilt()
    }

    public func gamma16BitShift(): UInt8 {
        initializedGamma16BitTablesValue.shift()
    }

    public func gamma16BitTables(): PngGamma16BitTables {
        PngGamma16BitTables(initializedGamma16BitTablesValue)
    }

    public func effectivePalette(): Array<Byte> {
        ownedEffectivePalette.clone()
    }

    public func effectivePaletteAlpha(): Array<Byte> {
        ownedEffectivePaletteAlpha.clone()
    }

    public func palettePreprocessed(): Bool {
        palettePreprocessedValue
    }

    public func paletteComposeApplied(): Bool {
        paletteComposeAppliedValue
    }

    public func paletteGammaApplied(): Bool {
        paletteGammaAppliedValue
    }

    public func expandPalette(): Array<Byte> {
        ownedExpandPalette.clone()
    }

    public func expandPaletteAlpha(): Array<Byte> {
        ownedExpandPaletteAlpha.clone()
    }

    public func expandTransparency(): PngExpandTransparency {
        expandTransparencyValue
    }

    public func composeTransparency(): PngExpandTransparency {
        composeTransparencyValue
    }

    public func rgbToGrayEnabled(): Bool {
        rgbToGrayEnabledValue
    }

    public func rgbToGrayTransform(): PngRgbToGrayTransform {
        if (!rgbToGrayEnabledValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no RGB-to-gray transform"
            )
        }
        PngRgbToGrayTransform(rgbToGrayTransformValue)
    }

    public func quantizeMode(): PngQuantizeMode {
        if (!quantizeEnabledValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no quantize mode"
            )
        }
        quantizeModeValue
    }

    public func quantizeIndex(): Array<Byte> {
        ownedQuantizeIndex.clone()
    }

    public func quantizePalette(): Array<Byte> {
        ownedQuantizePalette.clone()
    }

    public func quantizePaletteCount(): Int64 {
        quantizePaletteCountValue
    }

    public func quantizePaletteLookup(): Array<Byte> {
        ownedQuantizePaletteLookup.clone()
    }

    public func quantizePaletteLookupAvailable(): Bool {
        ownedQuantizePaletteLookup.size != 0
    }

    public func invertAlphaEnabled(): Bool {
        invertAlphaEnabledValue
    }

    public func invertMonoEnabled(): Bool {
        invertMonoEnabledValue
    }

    public func shiftEnabled(): Bool {
        shiftEnabledValue
    }

    public func shiftSignificantBits(): PngSignificantBits {
        if (!shiftEnabledValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no significant-bit shift"
            )
        }
        PngSignificantBits(
            shiftSignificantBitsValue.gray,
            shiftSignificantBitsValue.red,
            shiftSignificantBitsValue.green,
            shiftSignificantBitsValue.blue,
            shiftSignificantBitsValue.alpha
        )
    }

    public func packingEnabled(): Bool {
        packingEnabledValue
    }

    public func fillerEnabled(): Bool {
        fillerModeValue != NoFiller
    }

    public func bgrEnabled(): Bool {
        bgrEnabledValue
    }

    public func packSwapEnabled(): Bool {
        packSwapEnabledValue
    }

    public func fillerMode(): PngFillerMode {
        fillerModeValue
    }

    public func fillerValue(): UInt16 {
        fillerValueValue
    }

    public func addAlphaEnabled(): Bool {
        fillerModeValue == AlphaBefore || fillerModeValue == AlphaAfter
    }

    public func swapAlphaEnabled(): Bool {
        swapAlphaEnabledValue
    }

    public func byteSwapEnabled(): Bool {
        byteSwapEnabledValue
    }

    public func checkForInvalidIndexEnabled(): Bool {
        checkForInvalidIndexEnabledValue
    }

    public func paletteEntryCount(): Int64 {
        paletteEntryCountValue
    }

    public func readUserTransformEnabled(): Bool {
        readUserTransformRegistrationValue.enabled()
    }

    public func userTransformDepth(): UInt8 {
        readUserTransformRegistrationValue.depth()
    }

    public func userTransformChannels(): UInt8 {
        readUserTransformRegistrationValue.channels()
    }

    public func readUserTransform(): (
        PngReadUserTransformContext,
        PngReadRowInfo,
        Array<Byte>
    ) -> PngReadUserTransformResult {
        if (!readUserTransformRegistrationValue.enabled()) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform initialization has no user transform callback"
            )
        }
        readUserTransformRegistrationValue.callback()
    }
}

private class PngInputAlphaClassification {
    let hasAlpha: Bool
    let hasTransparency: Bool

    init(hasAlpha: Bool, hasTransparency: Bool) {
        this.hasAlpha = hasAlpha
        this.hasTransparency = hasTransparency
    }
}

private class PngGrayToRgbBackgroundInitialization {
    let background: PngEffectiveBackgroundInitialization
    let backgroundIsGray: Bool

    init(
        background: PngEffectiveBackgroundInitialization,
        backgroundIsGray: Bool
    ) {
        this.background = background
        this.backgroundIsGray = backgroundIsGray
    }
}

private class PngEffectiveBackgroundInitialization {
    let configured: Bool
    let composeEnabled: Bool
    let expandEnabled: Bool
    let background: PngBackground
    let original: PngBackground
    let linear: PngBackground
    let gammaCode: PngBackgroundGammaCode
    let effectiveGammaCode: PngBackgroundGammaCode
    let gamma: Int32
    let depthNormalized: Bool
    let gammaInitialized: Bool
    let toLinearGamma: Int32
    let toScreenGamma: Int32

    init(
        configured: Bool,
        composeEnabled: Bool,
        expandEnabled: Bool,
        background: PngBackground,
        original: PngBackground,
        linear: PngBackground,
        gammaCode: PngBackgroundGammaCode,
        effectiveGammaCode: PngBackgroundGammaCode,
        gamma: Int32,
        depthNormalized: Bool,
        gammaInitialized: Bool,
        toLinearGamma: Int32,
        toScreenGamma: Int32
    ) {
        this.configured = configured
        this.composeEnabled = composeEnabled
        this.expandEnabled = expandEnabled
        this.background = PngBackground(background)
        this.original = PngBackground(original)
        this.linear = PngBackground(linear)
        this.gammaCode = gammaCode
        this.effectiveGammaCode = effectiveGammaCode
        this.gamma = gamma
        this.depthNormalized = depthNormalized
        this.gammaInitialized = gammaInitialized
        this.toLinearGamma = toLinearGamma
        this.toScreenGamma = toScreenGamma
    }
}

private func pngBackgroundInitialization(
    configured: Bool,
    composeEnabled: Bool,
    expandEnabled: Bool,
    background: PngBackground,
    gammaCode: PngBackgroundGammaCode,
    gamma: Int32
): PngEffectiveBackgroundInitialization {
    PngEffectiveBackgroundInitialization(
        configured,
        composeEnabled,
        expandEnabled,
        background,
        background,
        background,
        gammaCode,
        gammaCode,
        gamma,
        false,
        false,
        PNG_FP_1,
        PNG_FP_1
    )
}

private func pngScaleInitializedBackgroundGray(
    value: UInt16,
    bitDepth: UInt8
): UInt16 {
    let factor = match (bitDepth) {
        case 1 => UInt32(0xff)
        case 2 => UInt32(0x55)
        case 4 => UInt32(0x11)
        case _ => UInt32(1)
    }
    UInt16((UInt32(value) * factor) & UInt32(0xffff))
}

private func pngInitializeEffectiveBackground(
    state: PngReadTransformState,
    ihdr: PngIhdr,
    metadata: PngReadMetadata,
    classification: PngInputAlphaClassification
): PngEffectiveBackgroundInitialization {
    if (!state.backgroundConfigured()) {
        return pngBackgroundInitialization(
            false,
            false,
            false,
            PngBackground(),
            BackgroundGammaUnknown,
            Int32(0)
        )
    }

    var composeEnabled = state.composeEnabled()
    var expandEnabled = state.backgroundExpandEnabled()
    var background = state.background()
    if (!classification.hasAlpha && !classification.hasTransparency) {
        composeEnabled = false
        expandEnabled = false
    } else if (expandEnabled && state.expandEnabled()) {
        if (ihdr.colorType == Indexed) {
            let palette = metadata.palette()
            let index = Int64(background.index)
            let entryCount = palette.size / 3
            if (index >= entryCount) {
                throw PngFormatException(
                    InvalidArgument,
                    index,
                    "PNG background palette index exceeds retained PLTE"
                )
            }
            let offset = index * 3
            background = PngBackground(
                background.index,
                background.gray,
                UInt16(palette[offset]),
                UInt16(palette[offset + 1]),
                UInt16(palette[offset + 2])
            )
        } else if (ihdr.colorType == Grayscale ||
            ihdr.colorType == GrayscaleAlpha) {
            let gray = pngScaleInitializedBackgroundGray(
                background.gray,
                ihdr.bitDepth
            )
            background = PngBackground(
                background.index,
                gray,
                gray,
                gray,
                gray
            )
        }
    }
    pngBackgroundInitialization(
        true,
        composeEnabled,
        expandEnabled,
        background,
        state.backgroundGammaCode(),
        state.backgroundGamma()
    )
}

private func pngInitializeGrayToRgbBackground(
    state: PngReadTransformState,
    ihdr: PngIhdr,
    initialized: PngEffectiveBackgroundInitialization
): PngGrayToRgbBackgroundInitialization {
    if (!state.grayToRgbEnabled()) {
        return PngGrayToRgbBackgroundInitialization(initialized, false)
    }
    if (initialized.expandEnabled) {
        return PngGrayToRgbBackgroundInitialization(
            initialized,
            ihdr.colorType == Grayscale || ihdr.colorType == GrayscaleAlpha
        )
    }
    if (!initialized.composeEnabled ||
        initialized.background.red != initialized.background.green ||
        initialized.background.red != initialized.background.blue) {
        return PngGrayToRgbBackgroundInitialization(initialized, false)
    }

    let grayBackground = PngBackground(
        initialized.background.index,
        initialized.background.red,
        initialized.background.red,
        initialized.background.green,
        initialized.background.blue
    )
    PngGrayToRgbBackgroundInitialization(
        PngEffectiveBackgroundInitialization(
            initialized.configured,
            initialized.composeEnabled,
            initialized.expandEnabled,
            grayBackground,
            grayBackground,
            grayBackground,
            initialized.gammaCode,
            initialized.effectiveGammaCode,
            initialized.gamma,
            initialized.depthNormalized,
            initialized.gammaInitialized,
            initialized.toLinearGamma,
            initialized.toScreenGamma
        ),
        true
    )
}

private func pngDivideInitializedBackgroundBy257(value: UInt16): UInt16 {
    UInt16(
        (UInt32(value) * UInt32(255) + UInt32(32895)) >> UInt32(16)
    )
}

private func pngMultiplyInitializedBackgroundBy257(value: UInt16): UInt16 {
    UInt16((UInt32(value) * UInt32(257)) & UInt32(0xffff))
}

private func pngNormalizeInitializedBackgroundDepth(
    initialized: PngEffectiveBackgroundInitialization,
    state: PngReadTransformState,
    ihdr: PngIhdr
): PngEffectiveBackgroundInitialization {
    if (!initialized.configured || !initialized.composeEnabled ||
        initialized.expandEnabled) {
        return initialized
    }

    var normalized = initialized.background
    var changed = false
    if (state.expand16Enabled() && ihdr.bitDepth != UInt8(16)) {
        normalized = PngBackground(
            normalized.index,
            pngDivideInitializedBackgroundBy257(normalized.gray),
            pngDivideInitializedBackgroundBy257(normalized.red),
            pngDivideInitializedBackgroundBy257(normalized.green),
            pngDivideInitializedBackgroundBy257(normalized.blue)
        )
        changed = true
    } else if ((state.scale16Enabled() || state.strip16Enabled()) &&
        ihdr.bitDepth == UInt8(16)) {
        normalized = PngBackground(
            normalized.index,
            pngMultiplyInitializedBackgroundBy257(normalized.gray),
            pngMultiplyInitializedBackgroundBy257(normalized.red),
            pngMultiplyInitializedBackgroundBy257(normalized.green),
            pngMultiplyInitializedBackgroundBy257(normalized.blue)
        )
        changed = true
    }

    PngEffectiveBackgroundInitialization(
        initialized.configured,
        initialized.composeEnabled,
        initialized.expandEnabled,
        normalized,
        normalized,
        normalized,
        initialized.gammaCode,
        initialized.effectiveGammaCode,
        initialized.gamma,
        changed,
        false,
        PNG_FP_1,
        PNG_FP_1
    )
}

private func pngBackgroundGammaTablesRequired(
    initialized: PngEffectiveBackgroundInitialization,
    gammaValues: PngGammaValues
): Bool {
    initialized.configured && initialized.composeEnabled &&
        (gammaValues.correctionRequired ||
        pngGammaSignificant(gammaValues.fileGamma) ||
        pngGammaSignificant(gammaValues.screenGamma) ||
        (initialized.gammaCode == BackgroundGammaUnique &&
        pngGammaSignificant(initialized.gamma)))
}

private func pngCorrectInitializedBackgroundSample(
    value: UInt16,
    bitDepth: UInt8,
    gamma: Int32
): UInt16 {
    if (!pngGammaSignificant(gamma)) {
        return value
    }
    if (bitDepth == UInt8(8)) {
        return UInt16(pngGamma8BitCorrect(UInt8(value), gamma))
    }
    pngGamma16BitCorrect(value, gamma)
}

private func pngCorrectInitializedBackground(
    background: PngBackground,
    bitDepth: UInt8,
    gamma: Int32
): PngBackground {
    let gray = pngCorrectInitializedBackgroundSample(
        background.gray,
        bitDepth,
        gamma
    )
    if (background.red == background.green &&
        background.red == background.blue &&
        background.red == background.gray) {
        return PngBackground(background.index, gray, gray, gray, gray)
    }
    PngBackground(
        background.index,
        gray,
        pngCorrectInitializedBackgroundSample(background.red, bitDepth, gamma),
        pngCorrectInitializedBackgroundSample(background.green, bitDepth, gamma),
        pngCorrectInitializedBackgroundSample(background.blue, bitDepth, gamma)
    )
}

private func pngInitializeBackgroundGamma(
    initialized: PngEffectiveBackgroundInitialization,
    ihdr: PngIhdr,
    gammaValues: PngGammaValues,
    gammaTablesRequired: Bool
): PngEffectiveBackgroundInitialization {
    if (!gammaTablesRequired) {
        return initialized
    }

    var toLinearGamma = PNG_FP_1
    var toScreenGamma = PNG_FP_1
    if (initialized.gammaCode == BackgroundGammaScreen) {
        toLinearGamma = gammaValues.screenGamma
    } else if (initialized.gammaCode == BackgroundGammaFile) {
        toLinearGamma = pngReciprocalFixed(gammaValues.fileGamma)
        toScreenGamma = pngReciprocal2Fixed(
            gammaValues.fileGamma,
            gammaValues.screenGamma
        )
    } else if (initialized.gammaCode == BackgroundGammaUnique) {
        toLinearGamma = pngReciprocalFixed(initialized.gamma)
        toScreenGamma = pngReciprocal2Fixed(
            initialized.gamma,
            gammaValues.screenGamma
        )
    } else {
        throw PngFormatException(
            InvalidArgument,
            initialized.gammaCode.ordinalValue(),
            "invalid initialized background gamma code"
        )
    }

    let backgroundBitDepth = if (ihdr.colorType == Indexed) {
        UInt8(8)
    } else {
        ihdr.bitDepth
    }
    let linear = pngCorrectInitializedBackground(
        initialized.original,
        backgroundBitDepth,
        toLinearGamma
    )
    let screen = pngCorrectInitializedBackground(
        initialized.original,
        backgroundBitDepth,
        toScreenGamma
    )
    PngEffectiveBackgroundInitialization(
        initialized.configured,
        initialized.composeEnabled,
        initialized.expandEnabled,
        screen,
        initialized.original,
        linear,
        initialized.gammaCode,
        BackgroundGammaScreen,
        initialized.gamma,
        initialized.depthNormalized,
        true,
        toLinearGamma,
        toScreenGamma
    )
}

private func pngInitPaletteTransformations(
    metadata: PngReadMetadata,
    transparencyStripped: Bool
): PngInputAlphaClassification {
    if (transparencyStripped) {
        return PngInputAlphaClassification(false, false)
    }
    let alpha = metadata.paletteAlpha()
    var hasAlpha = false
    var hasTransparency = false
    var index: Int64 = 0
    while (index < alpha.size) {
        if (alpha[index] == UInt8(0xff)) {
            index += 1
            continue
        }
        hasTransparency = true
        if (alpha[index] != UInt8(0)) {
            hasAlpha = true
            break
        }
        index += 1
    }
    PngInputAlphaClassification(hasAlpha, hasTransparency)
}

private func pngInitEffectivePaletteAlpha(
    state: PngReadTransformState,
    metadata: PngReadMetadata,
    background: PngEffectiveBackgroundInitialization
): Array<Byte> {
    let alpha = metadata.paletteAlpha()
    if (!background.expandEnabled || !state.expandEnabled() ||
        !state.invertAlphaEnabled() || state.expandTransparencyEnabled()) {
        return alpha
    }

    let inverted = alpha.clone()
    var index: Int64 = 0
    while (index < inverted.size) {
        inverted[index] = UInt8(0xff) - inverted[index]
        index += 1
    }
    inverted
}

private func pngInitRgbTransformations(
    ihdr: PngIhdr,
    metadata: PngReadMetadata,
    transparencyStripped: Bool
): PngInputAlphaClassification {
    let hasAlpha = ihdr.colorType == GrayscaleAlpha || ihdr.colorType == TruecolorAlpha
    let hasTransparency = metadata.hasTransparency && !transparencyStripped
    PngInputAlphaClassification(hasAlpha, hasTransparency)
}

private func pngReadTransformStages(
    state: PngReadTransformState,
    checkForInvalidIndexEnabled: Bool,
    gammaStageEnabled: Bool,
    grayToRgbAfterExpand16: Bool,
    stripAlphaBeforeCompose: Bool,
    composeEnabled: Bool,
    stripAlphaAfterCompose: Bool,
    encodeAlphaEnabled: Bool
): Array<PngReadTransformStage> {
    let stages = ArrayList<PngReadTransformStage>()
    if (state.expandEnabled()) {
        stages.add(ReadStageExpand)
    }
    if (stripAlphaBeforeCompose) {
        stages.add(ReadStageStripAlpha)
    }
    if (state.rgbToGrayEnabled()) {
        stages.add(ReadStageRgbToGray)
    }
    if (state.grayToRgbEnabled() && !grayToRgbAfterExpand16) {
        stages.add(ReadStageGrayToRgb)
    }
    if (composeEnabled) {
        stages.add(ReadStageCompose)
    }
    if (gammaStageEnabled) {
        stages.add(ReadStageGamma)
    }
    if (stripAlphaAfterCompose) {
        stages.add(ReadStageStripAlphaAfterCompose)
    }
    if (encodeAlphaEnabled) {
        stages.add(ReadStageEncodeAlpha)
    }
    if (state.scale16Enabled()) {
        stages.add(ReadStageScale16To8)
    }
    if (state.strip16Enabled()) {
        stages.add(ReadStageStrip16To8)
    }
    if (state.quantizeEnabled()) {
        stages.add(ReadStageQuantize)
    }
    if (state.expand16Enabled()) {
        stages.add(ReadStageExpand16)
    }
    if (state.grayToRgbEnabled() && grayToRgbAfterExpand16) {
        stages.add(ReadStageGrayToRgb)
    }
    if (state.invertMonoEnabled()) {
        stages.add(ReadStageInvertMono)
    }
    if (state.invertAlphaEnabled()) {
        stages.add(ReadStageInvertAlpha)
    }
    if (state.shiftEnabled()) {
        stages.add(ReadStageUnshift)
    }
    if (state.packingEnabled()) {
        stages.add(ReadStageUnpack)
    }
    if (checkForInvalidIndexEnabled) {
        stages.add(ReadStagePaletteIndexCheck)
    }
    if (state.bgrEnabled()) {
        stages.add(ReadStageBgr)
    }
    if (state.packSwapEnabled()) {
        stages.add(ReadStagePackSwap)
    }
    if (state.fillerEnabled()) {
        stages.add(ReadStageFiller)
    }
    if (state.swapAlphaEnabled()) {
        stages.add(ReadStageSwapAlpha)
    }
    if (state.byteSwapEnabled()) {
        stages.add(ReadStageByteSwap)
    }
    stages.toArray()
}

public func initializePngReadTransformations(
    state: PngReadTransformState,
    decoded: PngDecodedRows
): PngReadTransformInitialization {
    initializePngReadTransformations(state, decoded.ihdr, decoded.metadata)
}

public func initializePngReadTransformations(
    state: PngReadTransformState,
    ihdr: PngIhdr,
    metadata: PngReadMetadata
): PngReadTransformInitialization {
    if (state.rowInitialized()) {
        throw PngFormatException(
            InvalidArgument,
            -1,
            "read transformations have already been initialized"
        )
    }

    state.markIhdrRead(ihdr)
    let gammaConfigured = state.gammaConfigured()
    let chunkGamma = if (metadata.hasGamma) {
        Int32(metadata.gamma)
    } else {
        Int32(0)
    }
    let initializedGammaValues = pngInitGammaValues(PngFileGammaSources(
        if (gammaConfigured) { state.fileGamma() } else { Int32(0) },
        chunkGamma,
        state.defaultGamma(),
        state.screenGamma()
    ))
    let sourceHasTransparency = metadata.hasTransparency
    let stripAlphaBeforeCompose = state.stripAlphaEnabled() &&
        !state.composeEnabled()
    let transparencyStripped = stripAlphaBeforeCompose && sourceHasTransparency
    if (stripAlphaBeforeCompose) {
        state.cancelTransparencyExpansionForInitialization()
    }

    let usesPaletteInitializer = ihdr.colorType == Indexed
    let classification = if (usesPaletteInitializer) {
        pngInitPaletteTransformations(metadata, transparencyStripped)
    } else {
        pngInitRgbTransformations(ihdr, metadata, transparencyStripped)
    }
    let effectiveBackground = pngInitializeEffectiveBackground(
        state,
        ihdr,
        metadata,
        classification
    )
    let grayToRgbBackground = pngInitializeGrayToRgbBackground(
        state,
        ihdr,
        effectiveBackground
    )
    let normalizedBackground = pngNormalizeInitializedBackgroundDepth(
        grayToRgbBackground.background,
        state,
        ihdr
    )
    let composeGammaTablesRequired = pngBackgroundGammaTablesRequired(
        normalizedBackground,
        initializedGammaValues
    )
    let initializedBackground = pngInitializeBackgroundGamma(
        normalizedBackground,
        ihdr,
        initializedGammaValues,
        composeGammaTablesRequired
    )
    let effectivePaletteAlpha = if (usesPaletteInitializer) {
        pngInitEffectivePaletteAlpha(state, metadata, initializedBackground)
    } else {
        Array<Byte>()
    }
    let effectiveOutputHasAlpha = if (state.addAlphaEnabled()) {
        true
    } else if (state.stripAlphaEnabled()) {
        false
    } else {
        classification.hasAlpha ||
            (classification.hasTransparency && state.expandTransparencyEnabled())
    }
    let alphaGammaEffective = pngGammaSignificant(
        initializedGammaValues.screenGamma
    )
    let encodeAlphaEnabled = state.encodeAlphaEnabled() &&
        classification.hasAlpha && effectiveOutputHasAlpha && alphaGammaEffective
    let optimizeAlphaEnabled = state.optimizeAlphaEnabled() &&
        classification.hasAlpha && alphaGammaEffective
    let expandEnabled = state.expandEnabled()
    let expandTransparency = if (expandEnabled && !usesPaletteInitializer &&
        state.expandTransparencyEnabled() && metadata.hasTransparency) {
        match (ihdr.colorType) {
            case Grayscale => PngExpandTransparency(metadata.transparentGray)
            case Truecolor => PngExpandTransparency(
                metadata.transparentRed,
                metadata.transparentGreen,
                metadata.transparentBlue
            )
            case _ => PngExpandTransparency()
        }
    } else {
        PngExpandTransparency()
    }
    let composeTransparency = if (!usesPaletteInitializer &&
        metadata.hasTransparency) {
        match (ihdr.colorType) {
            case Grayscale => PngExpandTransparency(metadata.transparentGray)
            case Truecolor => PngExpandTransparency(
                metadata.transparentRed,
                metadata.transparentGreen,
                metadata.transparentBlue
            )
            case _ => PngExpandTransparency()
        }
    } else {
        PngExpandTransparency()
    }
    let rgbToGrayEnabled = state.rgbToGrayEnabled()
    let rgbToGrayTransform = if (rgbToGrayEnabled) {
        pngResolveRgbToGrayTransform(state.rgbToGrayTransform(), metadata)
    } else {
        PngRgbToGrayTransform()
    }
    let initializedGamma8BitTables = pngBuildInitializedGamma8BitTables(
        initializedGammaValues,
        rgbToGrayEnabled,
        composeGammaTablesRequired,
        ihdr.bitDepth
    )
    let initializedGamma16BitTables = pngBuildInitializedGamma16BitTables(
        initializedGammaValues,
        rgbToGrayEnabled,
        composeGammaTablesRequired,
        ihdr.bitDepth,
        ihdr.colorType,
        metadata.significantBits,
        state.scale16Enabled() || state.strip16Enabled()
    )
    let paletteInitialization = if (usesPaletteInitializer) {
        pngInitPaletteBackgroundTransformations(
            metadata.palette(),
            effectivePaletteAlpha,
            initializedBackground.composeEnabled,
            if (initializedBackground.configured) {
                initializedBackground.background
            } else {
                PngBackground()
            },
            if (initializedBackground.configured) {
                initializedBackground.linear
            } else {
                PngBackground()
            },
            initializedGammaValues.correctionRequired &&
                (!expandEnabled || !rgbToGrayEnabled),
            initializedGamma8BitTables,
            optimizeAlphaEnabled
        )
    } else {
        PngPaletteTransformInitialization(
            Array<Byte>(),
            Array<Byte>(),
            false,
            false,
            false
        )
    }
    let rowComposeEnabled = initializedBackground.composeEnabled &&
        !paletteInitialization.composeApplied
    let effectiveStripAlphaBeforeCompose = state.stripAlphaEnabled() &&
        !rowComposeEnabled
    let expandPalette = if (expandEnabled && usesPaletteInitializer) {
        paletteInitialization.palette()
    } else {
        Array<Byte>()
    }
    let expandPaletteAlpha = if (expandEnabled && usesPaletteInitializer &&
        state.expandTransparencyEnabled()) {
        paletteInitialization.paletteAlpha()
    } else {
        Array<Byte>()
    }
    let quantizeEnabled = state.quantizeEnabled()
    let quantizeMode = if (quantizeEnabled) {
        state.quantizeMode()
    } else {
        PaletteRemap
    }
    let quantizeIndex = if (quantizeEnabled) {
        state.quantizeIndex()
    } else {
        Array<Byte>()
    }
    let quantizePaletteLookup = if (quantizeEnabled) {
        state.quantizePaletteLookup()
    } else {
        Array<Byte>()
    }
    let quantizePalette = if (quantizeEnabled) {
        state.quantizePalette()
    } else {
        Array<Byte>()
    }
    let quantizePaletteCount = if (quantizeEnabled) {
        state.quantizePaletteCount()
    } else {
        Int64(0)
    }
    let invertMonoEnabled = state.invertMonoEnabled()
    let invertAlphaEnabled = state.invertAlphaEnabled()
    let shiftEnabled = state.shiftEnabled()
    let shiftSignificantBits = if (shiftEnabled) {
        state.shiftSignificantBits()
    } else {
        PngSignificantBits()
    }
    let packingEnabled = state.packingEnabled()
    let bgrEnabled = state.bgrEnabled()
    let packSwapEnabled = state.packSwapEnabled()
    let fillerMode = state.fillerMode()
    let fillerValue = state.fillerValue()
    let swapAlphaEnabled = state.swapAlphaEnabled()
    let byteSwapEnabled = state.byteSwapEnabled()
    let checkForInvalidIndexEnabled = ihdr.colorType == Indexed &&
        state.checkForInvalidIndexEnabled()
    let paletteEntryCount = if (checkForInvalidIndexEnabled) {
        metadata.paletteEntryCount()
    } else {
        Int64(0)
    }
    let gammaStageEnabled = (initializedGamma8BitTables.built() ||
        initializedGamma16BitTables.built()) &&
        initializedGammaValues.correctionRequired && !rgbToGrayEnabled &&
        ihdr.colorType != Indexed && !rowComposeEnabled
    let stripAlphaAfterCompose = state.stripAlphaEnabled() &&
        rowComposeEnabled
    let stages = pngReadTransformStages(
        state,
        checkForInvalidIndexEnabled,
        gammaStageEnabled,
        grayToRgbBackground.backgroundIsGray,
        effectiveStripAlphaBeforeCompose,
        rowComposeEnabled,
        stripAlphaAfterCompose,
        encodeAlphaEnabled
    )
    state.markRowInitialized()

    PngReadTransformInitialization(
        usesPaletteInitializer,
        sourceHasTransparency,
        classification.hasAlpha,
        classification.hasTransparency,
        transparencyStripped,
        state.expandTransparencyEnabled(),
        effectiveOutputHasAlpha,
        initializedBackground.configured,
        rowComposeEnabled,
        initializedBackground.expandEnabled,
        grayToRgbBackground.backgroundIsGray,
        initializedBackground.background,
        initializedBackground.original,
        initializedBackground.linear,
        initializedBackground.gammaCode,
        initializedBackground.effectiveGammaCode,
        initializedBackground.gamma,
        initializedBackground.depthNormalized,
        initializedBackground.gammaInitialized,
        initializedBackground.toLinearGamma,
        initializedBackground.toScreenGamma,
        gammaConfigured,
        state.alphaModeConfigured(),
        if (state.alphaModeConfigured()) { state.alphaMode() } else { AlphaPng },
        encodeAlphaEnabled,
        optimizeAlphaEnabled,
        state.defaultGamma(),
        chunkGamma,
        initializedGammaValues,
        initializedGamma8BitTables,
        initializedGamma16BitTables,
        paletteInitialization.palette(),
        paletteInitialization.paletteAlpha(),
        paletteInitialization.preprocessed,
        paletteInitialization.composeApplied,
        paletteInitialization.gammaApplied,
        expandPalette,
        expandPaletteAlpha,
        expandTransparency,
        composeTransparency,
        rgbToGrayEnabled,
        rgbToGrayTransform,
        quantizeEnabled,
        quantizeMode,
        quantizePalette,
        quantizePaletteCount,
        quantizeIndex,
        quantizePaletteLookup,
        invertMonoEnabled,
        invertAlphaEnabled,
        shiftEnabled,
        shiftSignificantBits,
        packingEnabled,
        bgrEnabled,
        packSwapEnabled,
        fillerMode,
        fillerValue,
        swapAlphaEnabled,
        byteSwapEnabled,
        checkForInvalidIndexEnabled,
        paletteEntryCount,
        state.readUserTransformRegistration(),
        stages
    )
}
