package libpng4cj

public enum PngQuantizeMode <: Equatable<PngQuantizeMode> & ToString {
    | PaletteRemap
    | FullColor

    public operator func ==(right: PngQuantizeMode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngQuantizeMode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case PaletteRemap => 0
            case FullColor => 1
        }
    }

    public func toString(): String {
        match (this) {
            case PaletteRemap => "PALETTE_REMAP"
            case FullColor => "FULL_COLOR"
        }
    }
}

public enum PngBackgroundGammaCode <:
    Equatable<PngBackgroundGammaCode> & ToString {
    | BackgroundGammaUnknown
    | BackgroundGammaScreen
    | BackgroundGammaFile
    | BackgroundGammaUnique

    public operator func ==(right: PngBackgroundGammaCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngBackgroundGammaCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case BackgroundGammaUnknown => 0
            case BackgroundGammaScreen => 1
            case BackgroundGammaFile => 2
            case BackgroundGammaUnique => 3
        }
    }

    public func toString(): String {
        match (this) {
            case BackgroundGammaUnknown => "UNKNOWN"
            case BackgroundGammaScreen => "SCREEN"
            case BackgroundGammaFile => "FILE"
            case BackgroundGammaUnique => "UNIQUE"
        }
    }
}

public enum PngAlphaMode <: Equatable<PngAlphaMode> & ToString {
    | AlphaPng
    | AlphaAssociated
    | AlphaOptimized
    | AlphaBroken

    public operator func ==(right: PngAlphaMode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngAlphaMode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case AlphaPng => 0
            case AlphaAssociated => 1
            case AlphaOptimized => 2
            case AlphaBroken => 3
        }
    }

    public func toString(): String {
        match (this) {
            case AlphaPng => "PNG"
            case AlphaAssociated => "ASSOCIATED"
            case AlphaOptimized => "OPTIMIZED"
            case AlphaBroken => "BROKEN"
        }
    }
}

public enum PngReadTransformApplicationError <:
    Equatable<PngReadTransformApplicationError> & ToString {
    | NoTransformApplicationError
    | InvalidBeforeIhdr
    | InvalidAfterRowInitialization

    public operator func ==(right: PngReadTransformApplicationError): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngReadTransformApplicationError): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case NoTransformApplicationError => 0
            case InvalidBeforeIhdr => 1
            case InvalidAfterRowInitialization => 2
        }
    }

    public func toString(): String {
        match (this) {
            case NoTransformApplicationError => "NONE"
            case InvalidBeforeIhdr => "INVALID_BEFORE_IHDR"
            case InvalidAfterRowInitialization => "INVALID_AFTER_ROW_INITIALIZATION"
        }
    }
}

public class PngReadTransformState {
    private var ihdrReadValue: Bool = false
    private var ihdrColorTypeValue: PngColorType = Grayscale
    private var ihdrBitDepthValue: UInt8 = UInt8(0)
    private var ihdrBitDepthKnownValue: Bool = false
    private var rowInitializedValue: Bool = false
    private var detectUninitializedValue: Bool = false
    private var lastApplicationErrorValue: PngReadTransformApplicationError =
        NoTransformApplicationError

    private var scale16Value: Bool = false
    private var strip16Value: Bool = false
    private var stripAlphaValue: Bool = false
    private var composeValue: Bool = false
    private var backgroundExpandValue: Bool = false
    private var encodeAlphaValue: Bool = false
    private var optimizeAlphaValue: Bool = false
    private var alphaModeConfiguredValue: Bool = false
    private var alphaModeValue: PngAlphaMode = AlphaPng
    private var alphaModeGammaApplicationErrorValue: Bool = false
    private var alphaModeBackgroundConflictValue: Bool = false
    private var backgroundConfiguredValue: Bool = false
    private var backgroundValue: PngBackground = PngBackground()
    private var backgroundGammaCodeValue: PngBackgroundGammaCode =
        BackgroundGammaUnknown
    private var backgroundGammaValue: Int32 = Int32(0)
    private var backgroundGammaUnknownWarningValue: Bool = false
    private var expandValue: Bool = false
    private var expandTransparencyValue: Bool = false
    private var expand16Value: Bool = false
    private var grayToRgbValue: Bool = false
    private var rgbToGrayValue: Bool = false
    private var rgbToGrayTransformValue: PngRgbToGrayTransform = PngRgbToGrayTransform()
    private var quantizeValue: Bool = false
    private var quantizeModeValue: PngQuantizeMode = PaletteRemap
    private var quantizePaletteValue: Array<Byte> = Array<Byte>()
    private var quantizePaletteCountValue: Int64 = 0
    private var quantizeMaximumColorsValue: Int64 = 0
    private var quantizeIndexValue: Array<Byte> = Array<Byte>()
    private var quantizePaletteLookupValue: Array<Byte> = Array<Byte>()
    private var quantizeAllocationWarningCountValue: Int64 = 0
    private var quantizeAllocationRetryCountValue: Int64 = 0
    private var invertMonoValue: Bool = false
    private var invertAlphaValue: Bool = false
    private var shiftValue: Bool = false
    private var shiftSignificantBitsValue: PngSignificantBits = PngSignificantBits()
    private var packingValue: Bool = false
    private var bgrValue: Bool = false
    private var packSwapValue: Bool = false
    private var fillerModeValue: PngFillerMode = NoFiller
    private var fillerValueValue: UInt16 = UInt16(0)
    private var swapAlphaValue: Bool = false
    private var byteSwapValue: Bool = false
    private var checkForInvalidIndexValue: Bool = true
    private let readUserTransformRegistrationValue =
        PngReadUserTransformRegistration()
    private var gammaConfiguredValue: Bool = false
    private var fileGammaValue: Int32 = Int32(0)
    private var screenGammaValue: Int32 = Int32(0)
    private var defaultGammaValue: Int32 = Int32(0)
    private var gammaFileApplicationErrorValue: Bool = false
    private var gammaScreenApplicationErrorValue: Bool = false
    private var gammaUnsupportedWarningValue: Bool = false

    public init() {}

    public func markIhdrRead(ihdr: PngIhdr): Unit {
        ihdrReadValue = true
        ihdrColorTypeValue = ihdr.colorType
        ihdrBitDepthValue = ihdr.bitDepth
        ihdrBitDepthKnownValue = true
    }

    public func markIhdrRead(colorType: PngColorType): Unit {
        ihdrReadValue = true
        ihdrColorTypeValue = colorType
        ihdrBitDepthValue = UInt8(0)
        ihdrBitDepthKnownValue = false
    }

    public func markRowInitialized(): Unit {
        rowInitializedValue = true
    }

    public func ihdrRead(): Bool {
        ihdrReadValue
    }

    public func rowInitialized(): Bool {
        rowInitializedValue
    }

    public func detectsUninitializedTransforms(): Bool {
        detectUninitializedValue
    }

    public func lastApplicationError(): PngReadTransformApplicationError {
        lastApplicationErrorValue
    }

    private func pngRtranOk(needIhdr: Bool): Bool {
        if (rowInitializedValue) {
            lastApplicationErrorValue = InvalidAfterRowInitialization
            return false
        }
        if (needIhdr && !ihdrReadValue) {
            lastApplicationErrorValue = InvalidBeforeIhdr
            return false
        }
        detectUninitializedValue = true
        lastApplicationErrorValue = NoTransformApplicationError
        true
    }

    public func setScale16(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        scale16Value = true
        true
    }

    public func setStrip16(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        strip16Value = true
        true
    }

    public func setStripAlpha(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        stripAlphaValue = true
        true
    }

    public func setBackgroundFixed(
        background: PngBackground,
        gammaCode: PngBackgroundGammaCode,
        needExpand: Bool,
        backgroundGamma: Int32
    ): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        if (gammaCode == BackgroundGammaUnknown) {
            backgroundGammaUnknownWarningValue = true
            return false
        }

        composeValue = true
        stripAlphaValue = true
        encodeAlphaValue = false
        optimizeAlphaValue = false
        backgroundValue = PngBackground(background)
        backgroundGammaValue = backgroundGamma
        backgroundGammaCodeValue = gammaCode
        backgroundExpandValue = needExpand
        backgroundConfiguredValue = true
        backgroundGammaUnknownWarningValue = false
        true
    }

    public func setBackgroundFixed(
        background: PngBackground,
        gammaCode: PngBackgroundGammaCode,
        needExpand: Int64,
        backgroundGamma: Int32
    ): Bool {
        setBackgroundFixed(
            background,
            gammaCode,
            needExpand != Int64(0),
            backgroundGamma
        )
    }

    public func setBackground(
        background: PngBackground,
        gammaCode: PngBackgroundGammaCode,
        needExpand: Bool,
        backgroundGamma: Float64
    ): Bool {
        let fixed = pngFixedFromFloat64(backgroundGamma, "background gamma")
        setBackgroundFixed(
            background,
            gammaCode,
            needExpand,
            Int32(fixed)
        )
    }

    public func setAlphaModeFixed(
        mode: PngAlphaMode,
        outputGamma: Int32
    ): Bool {
        if (!pngRtranOk(false)) {
            return false
        }

        let translatedOutput = pngTranslateGammaFlags(outputGamma, true)
        if (!pngGammaSupported(translatedOutput)) {
            alphaModeGammaApplicationErrorValue = true
            return false
        }

        let premultiply = mode != AlphaPng
        if (premultiply && composeValue) {
            alphaModeBackgroundConflictValue = true
            return false
        }

        let fileGamma = if (defaultGammaValue == Int32(0)) {
            pngReciprocalFixed(translatedOutput)
        } else {
            defaultGammaValue
        }
        var effectiveOutput = translatedOutput
        var encodeAlpha = false
        var optimizeAlpha = false
        if (mode == AlphaAssociated) {
            effectiveOutput = PNG_FP_1
        } else if (mode == AlphaOptimized) {
            optimizeAlpha = true
        } else if (mode == AlphaBroken) {
            encodeAlpha = true
        }

        if (defaultGammaValue == Int32(0)) {
            defaultGammaValue = fileGamma
        }
        screenGammaValue = effectiveOutput
        encodeAlphaValue = encodeAlpha
        optimizeAlphaValue = optimizeAlpha
        if (premultiply) {
            backgroundValue = PngBackground()
            backgroundGammaValue = fileGamma
            backgroundGammaCodeValue = BackgroundGammaFile
            backgroundExpandValue = false
            backgroundConfiguredValue = true
            composeValue = true
        }
        alphaModeValue = mode
        alphaModeConfiguredValue = true
        alphaModeGammaApplicationErrorValue = false
        alphaModeBackgroundConflictValue = false
        true
    }

    public func setAlphaMode(
        mode: PngAlphaMode,
        outputGamma: Float64
    ): Bool {
        let fixed = pngConvertGammaValue(outputGamma, "alpha output gamma")
        setAlphaModeFixed(mode, fixed)
    }

    public func setBackground(
        background: PngBackground,
        gammaCode: PngBackgroundGammaCode,
        needExpand: Int64,
        backgroundGamma: Float64
    ): Bool {
        setBackground(
            background,
            gammaCode,
            needExpand != Int64(0),
            backgroundGamma
        )
    }

    public func setExpand(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        expandValue = true
        expandTransparencyValue = true
        true
    }

    public func setPaletteToRgb(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        expandValue = true
        expandTransparencyValue = true
        true
    }

    public func setExpandGrayOneTwoFourToEight(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        expandValue = true
        true
    }

    public func setTransparencyToAlpha(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        expandValue = true
        expandTransparencyValue = true
        true
    }

    public func setExpand16(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        expand16Value = true
        expandValue = true
        expandTransparencyValue = true
        true
    }

    public func setGrayToRgb(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        expandValue = true
        grayToRgbValue = true
        true
    }

    public func setRgbToGrayFixed(
        policy: PngRgbToGrayPolicy,
        redWeight: Int64,
        greenWeight: Int64
    ): Bool {
        if (!pngRtranOk(true)) {
            return false
        }
        if (ihdrColorTypeValue == Indexed) {
            expandValue = true
        }
        rgbToGrayTransformValue = PngRgbToGrayTransform(policy, redWeight, greenWeight)
        rgbToGrayValue = true
        true
    }

    public func setRgbToGrayFixed(
        policy: PngRgbToGrayPolicy,
        redWeight: UInt32,
        greenWeight: UInt32
    ): Bool {
        setRgbToGrayFixed(policy, Int64(redWeight), Int64(greenWeight))
    }

    public func setRgbToGray(
        policy: PngRgbToGrayPolicy,
        redWeight: Float64,
        greenWeight: Float64
    ): Bool {
        let redFixed = pngFixedFromFloat64(redWeight, "RGB-to-gray red coefficient")
        let greenFixed = pngFixedFromFloat64(greenWeight, "RGB-to-gray green coefficient")
        setRgbToGrayFixed(policy, redFixed, greenFixed)
    }

    public func setGammaFixed(screenGamma: Int32, fileGamma: Int32): Bool {
        if (!pngRtranOk(false)) {
            return false
        }

        let translatedScreen = pngTranslateGammaFlags(screenGamma, true)
        let translatedFile = pngTranslateGammaFlags(fileGamma, false)
        gammaFileApplicationErrorValue = translatedFile <= Int32(0)
        gammaScreenApplicationErrorValue = translatedScreen <= Int32(0)
        gammaUnsupportedWarningValue = !pngGammaSupported(translatedFile) ||
            !pngGammaSupported(translatedScreen)

        if (gammaUnsupportedWarningValue) {
            return false
        }

        fileGammaValue = translatedFile
        screenGammaValue = translatedScreen
        gammaConfiguredValue = true
        true
    }

    public func setGamma(screenGamma: Float64, fileGamma: Float64): Bool {
        let screenFixed = pngConvertGammaValue(screenGamma, "screen gamma")
        let fileFixed = pngConvertGammaValue(fileGamma, "file gamma")
        setGammaFixed(screenFixed, fileFixed)
    }

    public func setQuantize(
        palette: Array<Byte>,
        numPalette: Int64,
        maximumColors: Int64,
        fullQuantize: Bool
    ): Bool {
        setQuantizeWithAllocationPlan(
            palette,
            numPalette,
            maximumColors,
            Array<UInt16>(),
            fullQuantize,
            pngNoQuantizeAllocationFaultPlan()
        )
    }

    public func setQuantize(
        palette: Array<Byte>,
        numPalette: Int64,
        maximumColors: Int64,
        fullQuantize: Bool,
        allocationFaultPlan: PngQuantizeAllocationFaultPlan
    ): Bool {
        setQuantizeWithAllocationPlan(
            palette,
            numPalette,
            maximumColors,
            Array<UInt16>(),
            fullQuantize,
            allocationFaultPlan
        )
    }

    public func setQuantize(
        palette: Array<Byte>,
        numPalette: Int64,
        maximumColors: Int64,
        histogram: Array<UInt16>,
        fullQuantize: Bool
    ): Bool {
        setQuantizeWithAllocationPlan(
            palette,
            numPalette,
            maximumColors,
            histogram,
            fullQuantize,
            pngNoQuantizeAllocationFaultPlan()
        )
    }

    private func setQuantizeWithAllocationPlan(
        palette: Array<Byte>,
        numPalette: Int64,
        maximumColors: Int64,
        histogram: Array<UInt16>,
        fullQuantize: Bool,
        allocationFaultPlan: PngQuantizeAllocationFaultPlan
    ): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        if (numPalette <= 0 || numPalette > 256) {
            throw PngFormatException(
                InvalidArgument,
                numPalette,
                "PNG quantize palette count must be in 1..256"
            )
        }
        if (palette.size != numPalette * 3) {
            throw PngFormatException(
                InvalidArgument,
                palette.size,
                "PNG quantize palette must contain exactly numPalette RGB entries"
            )
        }
        if (maximumColors <= 0 || maximumColors > 256) {
            throw PngFormatException(
                InvalidArgument,
                maximumColors,
                "PNG quantize maximum colors must be in 1..256"
            )
        }
        if (histogram.size != 0 && histogram.size != numPalette) {
            throw PngFormatException(
                InvalidArgument,
                histogram.size,
                "PNG quantize histogram must match the palette count"
            )
        }
        let prepared = pngPrepareQuantizeState(
            palette,
            numPalette,
            maximumColors,
            histogram,
            fullQuantize,
            allocationFaultPlan
        )

        quantizeValue = true
        quantizeModeValue = if (fullQuantize) { FullColor } else { PaletteRemap }
        quantizePaletteValue = prepared.palette
        quantizePaletteCountValue = prepared.paletteCount
        quantizeMaximumColorsValue = maximumColors
        quantizeIndexValue = prepared.index
        quantizePaletteLookupValue = prepared.paletteLookup
        quantizeAllocationWarningCountValue = prepared.allocationWarningCount
        quantizeAllocationRetryCountValue = prepared.allocationRetryCount
        true
    }

    public func setInvertAlpha(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        invertAlphaValue = true
        true
    }

    public func setInvertMono(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        invertMonoValue = true
        true
    }

    public func setShift(significantBits: PngSignificantBits): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        shiftSignificantBitsValue = PngSignificantBits(
            significantBits.gray,
            significantBits.red,
            significantBits.green,
            significantBits.blue,
            significantBits.alpha
        )
        shiftValue = true
        true
    }

    public func setPacking(): Bool {
        if (!pngRtranOk(true)) {
            return false
        }
        packingValue = ihdrBitDepthKnownValue && ihdrBitDepthValue < UInt8(8)
        true
    }

    public func setBgr(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        bgrValue = true
        true
    }

    public func setPackSwap(): Bool {
        if (!pngRtranOk(true)) {
            return false
        }
        packSwapValue = ihdrBitDepthKnownValue && ihdrBitDepthValue < UInt8(8)
        true
    }

    private func pngFillerMode(after: Bool, addAlpha: Bool): PngFillerMode {
        if (addAlpha) {
            return if (after) { AlphaAfter } else { AlphaBefore }
        }
        if (after) { FillerAfter } else { FillerBefore }
    }

    public func setFiller(value: UInt16, after: Bool): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        let addAlpha = fillerModeValue == AlphaBefore ||
            fillerModeValue == AlphaAfter
        fillerModeValue = pngFillerMode(after, addAlpha)
        fillerValueValue = value
        true
    }

    public func setFiller(value: UInt32, after: Bool): Bool {
        setFiller(UInt16(value & UInt32(0xffff)), after)
    }

    public func setAddAlpha(value: UInt16, after: Bool): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        fillerModeValue = pngFillerMode(after, true)
        fillerValueValue = value
        true
    }

    public func setAddAlpha(value: UInt32, after: Bool): Bool {
        setAddAlpha(UInt16(value & UInt32(0xffff)), after)
    }

    public func setSwapAlpha(): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        swapAlphaValue = true
        true
    }

    public func setSwap(): Bool {
        if (!pngRtranOk(true)) {
            return false
        }
        byteSwapValue = ihdrBitDepthKnownValue && ihdrBitDepthValue == UInt8(16)
        true
    }

    public func setCheckForInvalidIndex(allowed: Bool): Bool {
        checkForInvalidIndexValue = allowed
        true
    }

    public func setCheckForInvalidIndex(allowed: Int64): Bool {
        setCheckForInvalidIndex(allowed > 0)
    }

    public func setUserTransformInfo(depth: UInt8, channels: UInt8): Bool {
        if (!pngRtranOk(false)) {
            return false
        }
        readUserTransformRegistrationValue.setInfo(depth, channels)
        true
    }

    public func setUserTransformInfo(depth: Int64, channels: Int64): Bool {
        if (depth < 0 || depth > 255 || channels < 0 || channels > 255) {
            throw PngFormatException(
                InvalidArgument,
                if (depth < 0 || depth > 255) { depth } else { channels },
                "PNG user transform depth and channels must be in 0..255"
            )
        }
        setUserTransformInfo(UInt8(depth), UInt8(channels))
    }

    public func setReadUserTransform(): Bool {
        readUserTransformRegistrationValue.enableIdentity()
        true
    }

    public func setReadUserTransform(
        callback: (
            PngReadUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngReadUserTransformResult
    ): Bool {
        readUserTransformRegistrationValue.setCallback(callback)
        true
    }

    public func scale16Enabled(): Bool {
        scale16Value
    }

    public func strip16Enabled(): Bool {
        strip16Value
    }

    public func stripAlphaEnabled(): Bool {
        stripAlphaValue
    }

    public func composeEnabled(): Bool {
        composeValue
    }

    public func backgroundExpandEnabled(): Bool {
        backgroundExpandValue
    }

    public func encodeAlphaEnabled(): Bool {
        encodeAlphaValue
    }

    public func optimizeAlphaEnabled(): Bool {
        optimizeAlphaValue
    }

    public func alphaModeConfigured(): Bool {
        alphaModeConfiguredValue
    }

    public func alphaMode(): PngAlphaMode {
        if (!alphaModeConfiguredValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform state has no alpha-mode configuration"
            )
        }
        alphaModeValue
    }

    public func alphaModeGammaApplicationError(): Bool {
        alphaModeGammaApplicationErrorValue
    }

    public func alphaModeBackgroundConflict(): Bool {
        alphaModeBackgroundConflictValue
    }

    public func backgroundConfigured(): Bool {
        backgroundConfiguredValue
    }

    public func background(): PngBackground {
        if (!backgroundConfiguredValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform state has no background configuration"
            )
        }
        PngBackground(backgroundValue)
    }

    public func backgroundGammaCode(): PngBackgroundGammaCode {
        if (!backgroundConfiguredValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform state has no background gamma code"
            )
        }
        backgroundGammaCodeValue
    }

    public func backgroundGamma(): Int32 {
        if (!backgroundConfiguredValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform state has no background gamma"
            )
        }
        backgroundGammaValue
    }

    public func backgroundGammaUnknownWarning(): Bool {
        backgroundGammaUnknownWarningValue
    }

    public func expandEnabled(): Bool {
        expandValue
    }

    public func expandTransparencyEnabled(): Bool {
        expandTransparencyValue
    }

    public func expand16Enabled(): Bool {
        expand16Value
    }

    public func grayToRgbEnabled(): Bool {
        grayToRgbValue
    }

    public func rgbToGrayEnabled(): Bool {
        rgbToGrayValue
    }

    public func quantizeEnabled(): Bool {
        quantizeValue
    }

    public func quantizeMode(): PngQuantizeMode {
        if (!quantizeValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform state has no quantize mode"
            )
        }
        quantizeModeValue
    }

    public func quantizePalette(): Array<Byte> {
        quantizePaletteValue.clone()
    }

    public func quantizePaletteCount(): Int64 {
        quantizePaletteCountValue
    }

    public func quantizeMaximumColors(): Int64 {
        quantizeMaximumColorsValue
    }

    public func quantizeIndex(): Array<Byte> {
        quantizeIndexValue.clone()
    }

    public func quantizePaletteLookup(): Array<Byte> {
        quantizePaletteLookupValue.clone()
    }

    public func quantizeAllocationWarningCount(): Int64 {
        quantizeAllocationWarningCountValue
    }

    public func quantizeAllocationRetryCount(): Int64 {
        quantizeAllocationRetryCountValue
    }

    public func invertAlphaEnabled(): Bool {
        invertAlphaValue
    }

    public func invertMonoEnabled(): Bool {
        invertMonoValue
    }

    public func shiftEnabled(): Bool {
        shiftValue
    }

    public func shiftSignificantBits(): PngSignificantBits {
        if (!shiftValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform state has no significant-bit shift"
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
        packingValue
    }

    public func bgrEnabled(): Bool {
        bgrValue
    }

    public func packSwapEnabled(): Bool {
        packSwapValue
    }

    public func fillerEnabled(): Bool {
        fillerModeValue != NoFiller
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
        swapAlphaValue
    }

    public func byteSwapEnabled(): Bool {
        byteSwapValue
    }

    public func checkForInvalidIndexEnabled(): Bool {
        checkForInvalidIndexValue
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
                "read transform state has no user transform callback"
            )
        }
        readUserTransformRegistrationValue.callback()
    }

    func readUserTransformRegistration(): PngReadUserTransformRegistration {
        readUserTransformRegistrationValue
    }

    public func gammaConfigured(): Bool {
        gammaConfiguredValue
    }

    public func fileGamma(): Int32 {
        fileGammaValue
    }

    public func screenGamma(): Int32 {
        screenGammaValue
    }

    public func defaultGamma(): Int32 {
        defaultGammaValue
    }

    public func gammaFileApplicationError(): Bool {
        gammaFileApplicationErrorValue
    }

    public func gammaScreenApplicationError(): Bool {
        gammaScreenApplicationErrorValue
    }

    public func gammaUnsupportedWarning(): Bool {
        gammaUnsupportedWarningValue
    }

    func cancelTransparencyExpansionForInitialization(): Unit {
        expandTransparencyValue = false
    }

    public func has16To8Mode(): Bool {
        scale16Value || strip16Value
    }

    public func sixteenToEightMode(): Png16To8Mode {
        if (scale16Value) {
            return Scale
        }
        if (strip16Value) {
            return Strip
        }
        throw PngFormatException(
            UnsupportedTransform,
            -1,
            "read transform state has no 16-to-8 mode"
        )
    }

    public func rowShapeTransform(): PngRowShapeTransform {
        PngRowShapeTransform(stripAlphaValue, fillerModeValue, fillerValueValue)
    }

    public func rgbToGrayTransform(): PngRgbToGrayTransform {
        if (!rgbToGrayValue) {
            throw PngFormatException(
                UnsupportedTransform,
                -1,
                "read transform state has no RGB-to-gray transform"
            )
        }
        rgbToGrayTransformValue
    }
}
