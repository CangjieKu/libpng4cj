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
    private var rowInitializedValue: Bool = false
    private var detectUninitializedValue: Bool = false
    private var lastApplicationErrorValue: PngReadTransformApplicationError =
        NoTransformApplicationError

    private var scale16Value: Bool = false
    private var strip16Value: Bool = false
    private var stripAlphaValue: Bool = false
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

    public init() {}

    public func markIhdrRead(ihdr: PngIhdr): Unit {
        markIhdrRead(ihdr.colorType)
    }

    public func markIhdrRead(colorType: PngColorType): Unit {
        ihdrReadValue = true
        ihdrColorTypeValue = colorType
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

    public func setQuantize(
        palette: Array<Byte>,
        numPalette: Int64,
        maximumColors: Int64,
        fullQuantize: Bool
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
        if (numPalette > maximumColors) {
            throw PngFormatException(
                UnsupportedTransform,
                numPalette,
                "PNG quantize palette reduction is not translated yet"
            )
        }

        let index = if (fullQuantize) {
            Array<Byte>()
        } else {
            let identity = Array<Byte>(Int64(256), repeat: 0)
            var indexValue: Int64 = 0
            while (indexValue < identity.size) {
                identity[indexValue] = UInt8(indexValue)
                indexValue += 1
            }
            identity
        }
        let paletteLookup = if (fullQuantize) {
            pngBuildQuantizePaletteLookup(palette, numPalette)
        } else {
            Array<Byte>()
        }

        quantizeValue = true
        quantizeModeValue = if (fullQuantize) { FullColor } else { PaletteRemap }
        quantizePaletteValue = palette.clone()
        quantizePaletteCountValue = numPalette
        quantizeMaximumColorsValue = maximumColors
        quantizeIndexValue = index
        quantizePaletteLookupValue = paletteLookup
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
        PngRowShapeTransform(stripAlphaValue)
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
