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
            case ReadStageBgr => "BGR"
            case ReadStageFiller => "FILLER"
            case ReadStageSwapAlpha => "SWAP_ALPHA"
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
    private let ownedExpandPalette: Array<Byte>
    private let ownedExpandPaletteAlpha: Array<Byte>
    private let expandTransparencyValue: PngExpandTransparency
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
    private let bgrEnabledValue: Bool
    private let fillerModeValue: PngFillerMode
    private let fillerValueValue: UInt16
    private let swapAlphaEnabledValue: Bool
    private let ownedStages: Array<PngReadTransformStage>

    init(
        usesPaletteInitializer: Bool,
        sourceHasTransparency: Bool,
        inputHasAlpha: Bool,
        inputHasTransparency: Bool,
        transparencyStripped: Bool,
        effectiveTransparencyExpansion: Bool,
        effectiveOutputHasAlpha: Bool,
        expandPalette: Array<Byte>,
        expandPaletteAlpha: Array<Byte>,
        expandTransparency: PngExpandTransparency,
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
        bgrEnabled: Bool,
        fillerMode: PngFillerMode,
        fillerValue: UInt16,
        swapAlphaEnabled: Bool,
        stages: Array<PngReadTransformStage>
    ) {
        this.usesPaletteInitializer = usesPaletteInitializer
        this.sourceHasTransparency = sourceHasTransparency
        this.inputHasAlpha = inputHasAlpha
        this.inputHasTransparency = inputHasTransparency
        this.transparencyStripped = transparencyStripped
        this.effectiveTransparencyExpansion = effectiveTransparencyExpansion
        this.effectiveOutputHasAlpha = effectiveOutputHasAlpha
        ownedExpandPalette = expandPalette.clone()
        ownedExpandPaletteAlpha = expandPaletteAlpha.clone()
        expandTransparencyValue = expandTransparency
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
        bgrEnabledValue = bgrEnabled
        fillerModeValue = fillerMode
        fillerValueValue = fillerValue
        swapAlphaEnabledValue = swapAlphaEnabled
        ownedStages = stages.clone()
    }

    public func stageCount(): Int64 {
        ownedStages.size
    }

    public func stage(index: Int64): PngReadTransformStage {
        if (index < 0 || index >= ownedStages.size) {
            throw PngFormatException(
                InvalidArgument,
                index,
                "read transform stage index is out of bounds"
            )
        }
        ownedStages[index]
    }

    public func stages(): Array<PngReadTransformStage> {
        ownedStages.clone()
    }

    public func hasStage(expected: PngReadTransformStage): Bool {
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

    public func expandPalette(): Array<Byte> {
        ownedExpandPalette.clone()
    }

    public func expandPaletteAlpha(): Array<Byte> {
        ownedExpandPaletteAlpha.clone()
    }

    public func expandTransparency(): PngExpandTransparency {
        expandTransparencyValue
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

    public func fillerEnabled(): Bool {
        fillerModeValue != NoFiller
    }

    public func bgrEnabled(): Bool {
        bgrEnabledValue
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
}

private class PngInputAlphaClassification {
    let hasAlpha: Bool
    let hasTransparency: Bool

    init(hasAlpha: Bool, hasTransparency: Bool) {
        this.hasAlpha = hasAlpha
        this.hasTransparency = hasTransparency
    }
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
    state: PngReadTransformState
): Array<PngReadTransformStage> {
    let stages = ArrayList<PngReadTransformStage>()
    if (state.expandEnabled()) {
        stages.add(ReadStageExpand)
    }
    if (state.stripAlphaEnabled()) {
        stages.add(ReadStageStripAlpha)
    }
    if (state.rgbToGrayEnabled()) {
        stages.add(ReadStageRgbToGray)
    }
    if (state.grayToRgbEnabled()) {
        stages.add(ReadStageGrayToRgb)
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
    if (state.invertMonoEnabled()) {
        stages.add(ReadStageInvertMono)
    }
    if (state.invertAlphaEnabled()) {
        stages.add(ReadStageInvertAlpha)
    }
    if (state.shiftEnabled()) {
        stages.add(ReadStageUnshift)
    }
    if (state.bgrEnabled()) {
        stages.add(ReadStageBgr)
    }
    if (state.fillerEnabled()) {
        stages.add(ReadStageFiller)
    }
    if (state.swapAlphaEnabled()) {
        stages.add(ReadStageSwapAlpha)
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
    let sourceHasTransparency = metadata.hasTransparency
    let transparencyStripped = state.stripAlphaEnabled() && sourceHasTransparency
    if (state.stripAlphaEnabled()) {
        state.cancelTransparencyExpansionForInitialization()
    }

    let usesPaletteInitializer = ihdr.colorType == Indexed
    let classification = if (usesPaletteInitializer) {
        pngInitPaletteTransformations(metadata, transparencyStripped)
    } else {
        pngInitRgbTransformations(ihdr, metadata, transparencyStripped)
    }
    let effectiveOutputHasAlpha = if (state.addAlphaEnabled()) {
        true
    } else if (state.stripAlphaEnabled()) {
        false
    } else {
        classification.hasAlpha ||
            (classification.hasTransparency && state.expandTransparencyEnabled())
    }
    let expandEnabled = state.expandEnabled()
    let expandPalette = if (expandEnabled && usesPaletteInitializer) {
        metadata.palette()
    } else {
        Array<Byte>()
    }
    let expandPaletteAlpha = if (expandEnabled && usesPaletteInitializer &&
        state.expandTransparencyEnabled()) {
        metadata.paletteAlpha()
    } else {
        Array<Byte>()
    }
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
    let rgbToGrayEnabled = state.rgbToGrayEnabled()
    let rgbToGrayTransform = if (rgbToGrayEnabled) {
        PngRgbToGrayTransform(state.rgbToGrayTransform())
    } else {
        PngRgbToGrayTransform()
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
    let bgrEnabled = state.bgrEnabled()
    let fillerMode = state.fillerMode()
    let fillerValue = state.fillerValue()
    let swapAlphaEnabled = state.swapAlphaEnabled()
    let stages = pngReadTransformStages(state)
    state.markRowInitialized()

    PngReadTransformInitialization(
        usesPaletteInitializer,
        sourceHasTransparency,
        classification.hasAlpha,
        classification.hasTransparency,
        transparencyStripped,
        state.expandTransparencyEnabled(),
        effectiveOutputHasAlpha,
        expandPalette,
        expandPaletteAlpha,
        expandTransparency,
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
        bgrEnabled,
        fillerMode,
        fillerValue,
        swapAlphaEnabled,
        stages
    )
}
