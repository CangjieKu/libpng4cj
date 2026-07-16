package libpng4cj

import std.math.floor

public enum PngRgbToGrayPolicy <: Equatable<PngRgbToGrayPolicy> & ToString {
    | Convert
    | RequireGray

    public operator func ==(right: PngRgbToGrayPolicy): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngRgbToGrayPolicy): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Convert => 0
            case RequireGray => 1
        }
    }

    public func toString(): String {
        match (this) {
            case Convert => "CONVERT"
            case RequireGray => "REQUIRE_GRAY"
        }
    }
}

private class PngSetRgbToGrayFixedResult {
    let redCoefficient: UInt16
    let greenCoefficient: UInt16
    let blueCoefficient: UInt16
    let accepted: Bool

    init(
        redCoefficient: UInt16,
        greenCoefficient: UInt16,
        blueCoefficient: UInt16,
        accepted: Bool
    ) {
        this.redCoefficient = redCoefficient
        this.greenCoefficient = greenCoefficient
        this.blueCoefficient = blueCoefficient
        this.accepted = accepted
    }
}

// Fixed-coefficient branch of upstream png_set_rgb_to_gray_fixed.
private func pngSetRgbToGrayFixed(
    redWeight: Int64,
    greenWeight: Int64
): PngSetRgbToGrayFixedResult {
    if (redWeight >= 0 && greenWeight >= 0 && redWeight + greenWeight <= 100000) {
        let red = UInt16((UInt64(redWeight) * UInt64(32768)) / UInt64(100000))
        let green = UInt16((UInt64(greenWeight) * UInt64(32768)) / UInt64(100000))
        return PngSetRgbToGrayFixedResult(
            red,
            green,
            UInt16(32768) - red - green,
            true
        )
    }
    PngSetRgbToGrayFixedResult(
        UInt16(6968), UInt16(23434), UInt16(2366), false
    )
}

// Exact floating-point conversion used by upstream png_set_rgb_to_gray.
func pngFixedFromFloat64(value: Float64, label: String): Int64 {
    if (value.isNaN() || value.isInf()) {
        throw PngFormatException(
            InvalidArgument,
            -1,
            "PNG ${label} must be finite"
        )
    }
    let fixed = floor(100000.0 * value + 0.5)
    if (fixed > 2147483647.0 || fixed < -2147483648.0) {
        throw PngFormatException(
            InvalidArgument,
            -1,
            "PNG ${label} exceeds the signed 32-bit fixed-point range"
        )
    }
    Int64(fixed)
}

public class PngRgbToGrayTransform {
    public let policy: PngRgbToGrayPolicy
    public let redCoefficient: UInt16
    public let greenCoefficient: UInt16
    public let blueCoefficient: UInt16
    public let customCoefficientsAccepted: Bool

    public init() {
        policy = Convert
        redCoefficient = UInt16(6968)
        greenCoefficient = UInt16(23434)
        blueCoefficient = UInt16(2366)
        customCoefficientsAccepted = false
    }

    public init(policy: PngRgbToGrayPolicy) {
        this.policy = policy
        redCoefficient = UInt16(6968)
        greenCoefficient = UInt16(23434)
        blueCoefficient = UInt16(2366)
        customCoefficientsAccepted = false
    }

    public init(
        policy: PngRgbToGrayPolicy,
        redWeight: UInt32,
        greenWeight: UInt32
    ) {
        this.policy = policy
        let fixed = pngSetRgbToGrayFixed(Int64(redWeight), Int64(greenWeight))
        redCoefficient = fixed.redCoefficient
        greenCoefficient = fixed.greenCoefficient
        blueCoefficient = fixed.blueCoefficient
        customCoefficientsAccepted = fixed.accepted
    }

    public init(
        policy: PngRgbToGrayPolicy,
        redWeight: Int64,
        greenWeight: Int64
    ) {
        this.policy = policy
        let fixed = pngSetRgbToGrayFixed(redWeight, greenWeight)
        redCoefficient = fixed.redCoefficient
        greenCoefficient = fixed.greenCoefficient
        blueCoefficient = fixed.blueCoefficient
        customCoefficientsAccepted = fixed.accepted
    }

    public init(source: PngRgbToGrayTransform) {
        policy = source.policy
        redCoefficient = source.redCoefficient
        greenCoefficient = source.greenCoefficient
        blueCoefficient = source.blueCoefficient
        customCoefficientsAccepted = source.customCoefficientsAccepted
    }
}

private class ResolvedPngGrayShape {
    let invertGray: Bool
    let invertExistingAlpha: Bool
    let grayShift: UInt32
    let alphaShift: UInt32
    let existingAlpha: Bool
    let fillerValue: UInt16
    let specialBefore: Bool
    let layout: PngPixelLayout
    let channelCount: Int64

    init(
        invertGray: Bool,
        invertExistingAlpha: Bool,
        grayShift: UInt32,
        alphaShift: UInt32,
        existingAlpha: Bool,
        fillerValue: UInt16,
        specialBefore: Bool,
        layout: PngPixelLayout
    ) {
        this.invertGray = invertGray
        this.invertExistingAlpha = invertExistingAlpha
        this.grayShift = grayShift
        this.alphaShift = alphaShift
        this.existingAlpha = existingAlpha
        this.fillerValue = fillerValue
        this.specialBefore = specialBefore
        this.layout = layout
        channelCount = Int64(layout.channelCount())
    }
}

private class PngDoRgbToGray8Result {
    let canonical: Array<Byte>
    let hadNonGrayPixels: Bool

    init(canonical: Array<Byte>, hadNonGrayPixels: Bool) {
        this.canonical = canonical
        this.hadNonGrayPixels = hadNonGrayPixels
    }
}

private class PngDoRgbToGray16Result {
    let canonical: Array<UInt16>
    let hadNonGrayPixels: Bool

    init(canonical: Array<UInt16>, hadNonGrayPixels: Bool) {
        this.canonical = canonical
        this.hadNonGrayPixels = hadNonGrayPixels
    }
}

private func grayFillerModeIsBefore(mode: PngFillerMode): Bool {
    mode == FillerBefore || mode == AlphaBefore
}

private func grayFillerModeIsAlpha(mode: PngFillerMode): Bool {
    mode == AlphaBefore || mode == AlphaAfter
}

private func resolveGrayLayout(
    channelCount: Int64,
    hasAlpha: Bool,
    specialBefore: Bool
): PngPixelLayout {
    if (channelCount == 1) {
        return PixelGray
    }
    if (hasAlpha) {
        return if (specialBefore) { PixelAlphaGray } else { PixelGrayAlpha }
    }
    if (specialBefore) { PixelXgray } else { PixelGrayx }
}

private func resolveGraySignificantBitShift(
    decoded: PngDecodedRows,
    transforms: Array<PngReadChannelTransform>,
    outputBitDepth: UInt8
): UInt32 {
    if (!decoded.metadata.hasSignificantBits ||
        !hasPngReadChannelTransform(transforms, UnshiftSignificantBits)) {
        return UInt32(0)
    }
    let significantBits = if (decoded.ihdr.colorType == Grayscale ||
        decoded.ihdr.colorType == GrayscaleAlpha) {
        decoded.metadata.significantBits.gray
    } else {
        decoded.metadata.significantBits.green
    }
    if (significantBits == UInt8(0) || significantBits >= outputBitDepth) {
        return UInt32(0)
    }
    UInt32(outputBitDepth - significantBits)
}

private func resolveGrayAlphaShift(
    decoded: PngDecodedRows,
    transforms: Array<PngReadChannelTransform>,
    outputBitDepth: UInt8,
    existingAlpha: Bool
): UInt32 {
    if (!existingAlpha || !decoded.metadata.hasSignificantBits ||
        !hasPngReadChannelTransform(transforms, UnshiftSignificantBits)) {
        return UInt32(0)
    }
    let significantBits = decoded.metadata.significantBits.alpha
    if (significantBits == UInt8(0) || significantBits >= outputBitDepth) {
        return UInt32(0)
    }
    UInt32(outputBitDepth - significantBits)
}

private func resolvePngGrayShape(
    decoded: PngDecodedRows,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>,
    outputBitDepth: UInt8
): ResolvedPngGrayShape {
    let sourceAlpha = pngHasSemanticAlpha(decoded.ihdr, decoded.metadata)
    let existingAlpha = sourceAlpha && !shape.stripAlpha
    let fillerApplied = !existingAlpha && shape.fillerMode != NoFiller
    let fillerAlpha = fillerApplied && grayFillerModeIsAlpha(shape.fillerMode)
    let hasAlpha = existingAlpha || fillerAlpha
    let swapAlpha = hasAlpha && hasPngReadChannelTransform(transforms, SwapAlpha)
    var specialBefore = if (existingAlpha) {
        false
    } else {
        fillerApplied && grayFillerModeIsBefore(shape.fillerMode)
    }
    if (swapAlpha) {
        specialBefore = !specialBefore
    }
    let channelCount = if (existingAlpha || fillerApplied) { Int64(2) } else { Int64(1) }
    let layout = resolveGrayLayout(channelCount, hasAlpha, specialBefore)
    ResolvedPngGrayShape(
        hasPngReadChannelTransform(transforms, InvertMonochrome),
        existingAlpha && hasPngReadChannelTransform(transforms, InvertAlpha),
        resolveGraySignificantBitShift(decoded, transforms, outputBitDepth),
        resolveGrayAlphaShift(decoded, transforms, outputBitDepth, existingAlpha),
        existingAlpha,
        shape.fillerValue,
        specialBefore,
        layout
    )
}

private func validateGrayOutputLimit(
    ihdr: PngIhdr,
    limits: PngReadLimits,
    channelCount: Int64,
    bytesPerChannel: UInt64
): Unit {
    let rowBytes = UInt64(ihdr.width) * UInt64(channelCount) * bytesPerChannel
    if (UInt64(ihdr.height) > limits.maxTransformedBytes / rowBytes) {
        throw PngFormatException(
            DecodeLimitExceeded,
            -1,
            "grayscale rows exceed configured transformed-byte limit"
        )
    }
}

// Fast no-gamma 8-bit branch of upstream png_do_rgb_to_gray.
private func pngDoRgbToGray8(
    canonical: Array<Byte>,
    transform: PngRgbToGrayTransform
): PngDoRgbToGray8Result {
    var hadNonGrayPixels = false
    var offset: Int64 = 0
    while (offset < canonical.size) {
        let red = canonical[offset]
        let green = canonical[offset + 1]
        let blue = canonical[offset + 2]
        if (red != green || green != blue) {
            hadNonGrayPixels = true
            if (transform.policy == RequireGray) {
                throw PngFormatException(
                    RgbToGrayMismatch,
                    offset / 4,
                    "RGB-to-gray strict policy encountered a nongray pixel"
                )
            }
            let weighted = UInt32(transform.redCoefficient) * UInt32(red) +
                UInt32(transform.greenCoefficient) * UInt32(green) +
                UInt32(transform.blueCoefficient) * UInt32(blue)
            let gray = UInt8(weighted >> 15)
            canonical[offset] = gray
            canonical[offset + 1] = gray
            canonical[offset + 2] = gray
        }
        offset += 4
    }
    PngDoRgbToGray8Result(canonical, hadNonGrayPixels)
}

// Fast no-gamma 16-bit branch of upstream png_do_rgb_to_gray.
private func pngDoRgbToGray16(
    canonical: Array<UInt16>,
    transform: PngRgbToGrayTransform
): PngDoRgbToGray16Result {
    var hadNonGrayPixels = false
    var offset: Int64 = 0
    while (offset < canonical.size) {
        let red = canonical[offset]
        let green = canonical[offset + 1]
        let blue = canonical[offset + 2]
        if (red != green || green != blue) {
            hadNonGrayPixels = true
            if (transform.policy == RequireGray) {
                throw PngFormatException(
                    RgbToGrayMismatch,
                    offset / 4,
                    "RGB-to-gray strict policy encountered a nongray pixel"
                )
            }
            let weighted = UInt32(transform.redCoefficient) * UInt32(red) +
                UInt32(transform.greenCoefficient) * UInt32(green) +
                UInt32(transform.blueCoefficient) * UInt32(blue) + UInt32(16384)
            let gray = UInt16(weighted >> 15)
            canonical[offset] = gray
            canonical[offset + 1] = gray
            canonical[offset + 2] = gray
        }
        offset += 4
    }
    PngDoRgbToGray16Result(canonical, hadNonGrayPixels)
}

private func shapeCanonicalGrayRow8(
    canonical: Array<Byte>,
    resolved: ResolvedPngGrayShape
): Array<Byte> {
    let pixels = canonical.size / 4
    let output = Array<Byte>(pixels * resolved.channelCount, repeat: 0)
    var pixel: Int64 = 0
    while (pixel < pixels) {
        let sourceOffset = pixel * 4
        var gray = canonical[sourceOffset]
        var alpha = canonical[sourceOffset + 3]
        if (resolved.invertGray) {
            gray = UInt8(0xff) - gray
        }
        if (resolved.invertExistingAlpha) {
            alpha = UInt8(0xff) - alpha
        }
        gray = UInt8(UInt32(gray) >> resolved.grayShift)
        alpha = UInt8(UInt32(alpha) >> resolved.alphaShift)

        let outputOffset = pixel * resolved.channelCount
        if (resolved.channelCount == 1) {
            output[outputOffset] = gray
        } else {
            let special = if (resolved.existingAlpha) {
                alpha
            } else {
                UInt8(resolved.fillerValue & UInt16(0xff))
            }
            if (resolved.specialBefore) {
                output[outputOffset] = special
                output[outputOffset + 1] = gray
            } else {
                output[outputOffset] = gray
                output[outputOffset + 1] = special
            }
        }
        pixel += 1
    }
    output
}

private func shapeCanonicalGrayRow16(
    canonical: Array<UInt16>,
    resolved: ResolvedPngGrayShape
): Array<UInt16> {
    let pixels = canonical.size / 4
    let output = Array<UInt16>(pixels * resolved.channelCount, repeat: UInt16(0))
    var pixel: Int64 = 0
    while (pixel < pixels) {
        let sourceOffset = pixel * 4
        var gray = canonical[sourceOffset]
        var alpha = canonical[sourceOffset + 3]
        if (resolved.invertGray) {
            gray = UInt16(0xffff) - gray
        }
        if (resolved.invertExistingAlpha) {
            alpha = UInt16(0xffff) - alpha
        }
        gray = UInt16(UInt32(gray) >> resolved.grayShift)
        alpha = UInt16(UInt32(alpha) >> resolved.alphaShift)

        let outputOffset = pixel * resolved.channelCount
        if (resolved.channelCount == 1) {
            output[outputOffset] = gray
        } else {
            let special = if (resolved.existingAlpha) { alpha } else { resolved.fillerValue }
            if (resolved.specialBefore) {
                output[outputOffset] = special
                output[outputOffset + 1] = gray
            } else {
                output[outputOffset] = gray
                output[outputOffset + 1] = special
            }
        }
        pixel += 1
    }
    output
}

public func transformPngRowsToGray8(
    decoded: PngDecodedRows,
    limits: PngReadLimits,
    rgbToGray: PngRgbToGrayTransform,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows8 {
    if (decoded.ihdr.bitDepth > UInt8(8)) {
        throw PngFormatException(
            UnsupportedTransform,
            -1,
            "16-bit PNG input requires an explicit Png16To8Mode"
        )
    }
    let resolved = resolvePngGrayShape(decoded, shape, transforms, UInt8(8))
    validateGrayOutputLimit(decoded.ihdr, limits, resolved.channelCount, UInt64(1))
    let rows = Array<Array<Byte>>(decoded.rowCount(), repeat: Array<Byte>())
    var hadNonGrayPixels = false
    var index: Int64 = 0
    while (index < rows.size) {
        let canonical = expandRowToRgba8(decoded.row(index), decoded.ihdr, decoded.metadata)
        let converted = pngDoRgbToGray8(canonical, rgbToGray)
        hadNonGrayPixels = hadNonGrayPixels || converted.hadNonGrayPixels
        rows[index] = shapeCanonicalGrayRow8(converted.canonical, resolved)
        index += 1
    }
    PngPixelRows8(decoded.ihdr, decoded.metadata, resolved.layout, rows, hadNonGrayPixels)
}

public func transformPngRowsToGray8(
    decoded: PngDecodedRows,
    rgbToGray: PngRgbToGrayTransform
): PngPixelRows8 {
    transformPngRowsToGray8(
        decoded,
        PngReadLimits(),
        rgbToGray,
        PngRowShapeTransform(false),
        PNG_NO_READ_CHANNEL_TRANSFORMS
    )
}

public func transformPngRowsToGray8(
    decoded: PngDecodedRows,
    rgbToGray: PngRgbToGrayTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows8 {
    transformPngRowsToGray8(
        decoded,
        PngReadLimits(),
        rgbToGray,
        PngRowShapeTransform(false),
        transforms
    )
}

public func transformPngRowsToGray8(
    decoded: PngDecodedRows,
    rgbToGray: PngRgbToGrayTransform,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows8 {
    transformPngRowsToGray8(decoded, PngReadLimits(), rgbToGray, shape, transforms)
}

public func transformPngRowsToGray8(
    decoded: PngDecodedRows,
    limits: PngReadLimits,
    mode: Png16To8Mode,
    rgbToGray: PngRgbToGrayTransform,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows8 {
    let resolved = resolvePngGrayShape(decoded, shape, transforms, UInt8(8))
    validateGrayOutputLimit(decoded.ihdr, limits, resolved.channelCount, UInt64(1))
    let rows = Array<Array<Byte>>(decoded.rowCount(), repeat: Array<Byte>())
    var hadNonGrayPixels = false
    var index: Int64 = 0
    while (index < rows.size) {
        let canonical16 = expandRowToRgba16(decoded.row(index), decoded.ihdr, decoded.metadata)
        let converted = pngDoRgbToGray16(canonical16, rgbToGray)
        hadNonGrayPixels = hadNonGrayPixels || converted.hadNonGrayPixels
        let canonical8 = reduceRgba16Row(converted.canonical, mode)
        rows[index] = shapeCanonicalGrayRow8(canonical8, resolved)
        index += 1
    }
    PngPixelRows8(decoded.ihdr, decoded.metadata, resolved.layout, rows, hadNonGrayPixels)
}

public func transformPngRowsToGray8(
    decoded: PngDecodedRows,
    mode: Png16To8Mode,
    rgbToGray: PngRgbToGrayTransform
): PngPixelRows8 {
    transformPngRowsToGray8(
        decoded,
        PngReadLimits(),
        mode,
        rgbToGray,
        PngRowShapeTransform(false),
        PNG_NO_READ_CHANNEL_TRANSFORMS
    )
}

public func transformPngRowsToGray8(
    decoded: PngDecodedRows,
    mode: Png16To8Mode,
    rgbToGray: PngRgbToGrayTransform,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows8 {
    transformPngRowsToGray8(
        decoded, PngReadLimits(), mode, rgbToGray, shape, transforms
    )
}

public func transformPngRowsToGray16(
    decoded: PngDecodedRows,
    limits: PngReadLimits,
    rgbToGray: PngRgbToGrayTransform,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows16 {
    let resolved = resolvePngGrayShape(decoded, shape, transforms, UInt8(16))
    validateGrayOutputLimit(decoded.ihdr, limits, resolved.channelCount, UInt64(2))
    let rows = Array<Array<UInt16>>(decoded.rowCount(), repeat: Array<UInt16>())
    var hadNonGrayPixels = false
    var index: Int64 = 0
    while (index < rows.size) {
        let canonical = expandRowToRgba16(decoded.row(index), decoded.ihdr, decoded.metadata)
        let converted = pngDoRgbToGray16(canonical, rgbToGray)
        hadNonGrayPixels = hadNonGrayPixels || converted.hadNonGrayPixels
        rows[index] = shapeCanonicalGrayRow16(converted.canonical, resolved)
        index += 1
    }
    PngPixelRows16(decoded.ihdr, decoded.metadata, resolved.layout, rows, hadNonGrayPixels)
}

public func transformPngRowsToGray16(
    decoded: PngDecodedRows,
    rgbToGray: PngRgbToGrayTransform
): PngPixelRows16 {
    transformPngRowsToGray16(
        decoded,
        PngReadLimits(),
        rgbToGray,
        PngRowShapeTransform(false),
        PNG_NO_READ_CHANNEL_TRANSFORMS
    )
}

public func transformPngRowsToGray16(
    decoded: PngDecodedRows,
    rgbToGray: PngRgbToGrayTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows16 {
    transformPngRowsToGray16(
        decoded,
        PngReadLimits(),
        rgbToGray,
        PngRowShapeTransform(false),
        transforms
    )
}

public func transformPngRowsToGray16(
    decoded: PngDecodedRows,
    rgbToGray: PngRgbToGrayTransform,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows16 {
    transformPngRowsToGray16(decoded, PngReadLimits(), rgbToGray, shape, transforms)
}
