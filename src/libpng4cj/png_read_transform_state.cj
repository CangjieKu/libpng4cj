package libpng4cj

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
