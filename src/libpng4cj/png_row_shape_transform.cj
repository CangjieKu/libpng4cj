package libpng4cj

public enum PngFillerMode <: Equatable<PngFillerMode> & ToString {
    | NoFiller
    | FillerBefore
    | FillerAfter
    | AlphaBefore
    | AlphaAfter

    public operator func ==(right: PngFillerMode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngFillerMode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case NoFiller => 0
            case FillerBefore => 1
            case FillerAfter => 2
            case AlphaBefore => 3
            case AlphaAfter => 4
        }
    }

    public func toString(): String {
        match (this) {
            case NoFiller => "NONE"
            case FillerBefore => "FILLER_BEFORE"
            case FillerAfter => "FILLER_AFTER"
            case AlphaBefore => "ALPHA_BEFORE"
            case AlphaAfter => "ALPHA_AFTER"
        }
    }
}

public class PngRowShapeTransform {
    public let stripAlpha: Bool
    public let fillerMode: PngFillerMode
    public let fillerValue: UInt16

    public init(stripAlpha: Bool) {
        this.stripAlpha = stripAlpha
        fillerMode = NoFiller
        fillerValue = UInt16(0)
    }

    public init(stripAlpha: Bool, fillerMode: PngFillerMode, fillerValue: UInt16) {
        this.stripAlpha = stripAlpha
        this.fillerMode = fillerMode
        this.fillerValue = fillerValue
    }
}

public enum PngPixelLayout <: Equatable<PngPixelLayout> & ToString {
    | PixelRgb
    | PixelBgr
    | PixelRgba
    | PixelBgra
    | PixelArgb
    | PixelAbgr
    | PixelRgbx
    | PixelBgrx
    | PixelXrgb
    | PixelXbgr
    | PixelGray
    | PixelGrayAlpha
    | PixelAlphaGray
    | PixelGrayx
    | PixelXgray

    public operator func ==(right: PngPixelLayout): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngPixelLayout): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case PixelRgb => 0
            case PixelBgr => 1
            case PixelRgba => 2
            case PixelBgra => 3
            case PixelArgb => 4
            case PixelAbgr => 5
            case PixelRgbx => 6
            case PixelBgrx => 7
            case PixelXrgb => 8
            case PixelXbgr => 9
            case PixelGray => 10
            case PixelGrayAlpha => 11
            case PixelAlphaGray => 12
            case PixelGrayx => 13
            case PixelXgray => 14
        }
    }

    public func toString(): String {
        match (this) {
            case PixelRgb => "RGB"
            case PixelBgr => "BGR"
            case PixelRgba => "RGBA"
            case PixelBgra => "BGRA"
            case PixelArgb => "ARGB"
            case PixelAbgr => "ABGR"
            case PixelRgbx => "RGBX"
            case PixelBgrx => "BGRX"
            case PixelXrgb => "XRGB"
            case PixelXbgr => "XBGR"
            case PixelGray => "G"
            case PixelGrayAlpha => "GA"
            case PixelAlphaGray => "AG"
            case PixelGrayx => "GX"
            case PixelXgray => "XG"
        }
    }

    public func channelCount(): UInt8 {
        match (this) {
            case PixelGray => UInt8(1)
            case PixelGrayAlpha | PixelAlphaGray | PixelGrayx | PixelXgray => UInt8(2)
            case PixelRgb | PixelBgr => UInt8(3)
            case _ => UInt8(4)
        }
    }
}

public class PngPixelRows8 {
    public let ihdr: PngIhdr
    public let metadata: PngReadMetadata
    public let layout: PngPixelLayout
    public let channelCount: UInt8
    public let hadNonGrayPixels: Bool
    private let ownedRows: Array<Array<Byte>>

    init(
        ihdr: PngIhdr,
        metadata: PngReadMetadata,
        layout: PngPixelLayout,
        rows: Array<Array<Byte>>
    ) {
        this.ihdr = ihdr
        this.metadata = metadata
        this.layout = layout
        channelCount = layout.channelCount()
        hadNonGrayPixels = false
        ownedRows = rows
    }

    init(
        ihdr: PngIhdr,
        metadata: PngReadMetadata,
        layout: PngPixelLayout,
        rows: Array<Array<Byte>>,
        hadNonGrayPixels: Bool
    ) {
        this.ihdr = ihdr
        this.metadata = metadata
        this.layout = layout
        channelCount = layout.channelCount()
        this.hadNonGrayPixels = hadNonGrayPixels
        ownedRows = rows
    }

    public func rowCount(): Int64 {
        ownedRows.size
    }

    public func row(index: Int64): Array<Byte> {
        if (index < 0 || index >= ownedRows.size) {
            throw PngFormatException(InvalidArgument, index, "pixel row index is out of bounds")
        }
        ownedRows[index].clone()
    }

    public func rows(): Array<Array<Byte>> {
        let out = Array<Array<Byte>>(ownedRows.size, repeat: Array<Byte>())
        var index: Int64 = 0
        while (index < ownedRows.size) {
            out[index] = ownedRows[index].clone()
            index += 1
        }
        out
    }
}

public class PngPixelRows16 {
    public let ihdr: PngIhdr
    public let metadata: PngReadMetadata
    public let layout: PngPixelLayout
    public let channelCount: UInt8
    public let hadNonGrayPixels: Bool
    private let ownedRows: Array<Array<UInt16>>

    init(
        ihdr: PngIhdr,
        metadata: PngReadMetadata,
        layout: PngPixelLayout,
        rows: Array<Array<UInt16>>
    ) {
        this.ihdr = ihdr
        this.metadata = metadata
        this.layout = layout
        channelCount = layout.channelCount()
        hadNonGrayPixels = false
        ownedRows = rows
    }

    init(
        ihdr: PngIhdr,
        metadata: PngReadMetadata,
        layout: PngPixelLayout,
        rows: Array<Array<UInt16>>,
        hadNonGrayPixels: Bool
    ) {
        this.ihdr = ihdr
        this.metadata = metadata
        this.layout = layout
        channelCount = layout.channelCount()
        this.hadNonGrayPixels = hadNonGrayPixels
        ownedRows = rows
    }

    public func rowCount(): Int64 {
        ownedRows.size
    }

    public func row(index: Int64): Array<UInt16> {
        if (index < 0 || index >= ownedRows.size) {
            throw PngFormatException(InvalidArgument, index, "pixel row index is out of bounds")
        }
        ownedRows[index].clone()
    }

    public func rows(): Array<Array<UInt16>> {
        let out = Array<Array<UInt16>>(ownedRows.size, repeat: Array<UInt16>())
        var index: Int64 = 0
        while (index < ownedRows.size) {
            out[index] = ownedRows[index].clone()
            index += 1
        }
        out
    }
}

class ResolvedPngRowShape {
    let invertMonochrome: Bool
    let invertExistingAlpha: Bool
    let significantBits: ResolvedPngSignificantBitShifts
    let bgr: Bool
    let existingAlpha: Bool
    let fillerValue: UInt16
    let specialBefore: Bool
    let layout: PngPixelLayout
    let channelCount: Int64

    init(
        invertMonochrome: Bool,
        invertExistingAlpha: Bool,
        significantBits: ResolvedPngSignificantBitShifts,
        bgr: Bool,
        existingAlpha: Bool,
        fillerValue: UInt16,
        specialBefore: Bool,
        layout: PngPixelLayout
    ) {
        this.invertMonochrome = invertMonochrome
        this.invertExistingAlpha = invertExistingAlpha
        this.significantBits = significantBits
        this.bgr = bgr
        this.existingAlpha = existingAlpha
        this.fillerValue = fillerValue
        this.specialBefore = specialBefore
        this.layout = layout
        channelCount = Int64(layout.channelCount())
    }
}

private func fillerModeIsBefore(mode: PngFillerMode): Bool {
    mode == FillerBefore || mode == AlphaBefore
}

private func fillerModeIsAlpha(mode: PngFillerMode): Bool {
    mode == AlphaBefore || mode == AlphaAfter
}

private func resolvePixelLayout(
    bgr: Bool,
    channelCount: Int64,
    hasAlpha: Bool,
    specialBefore: Bool
): PngPixelLayout {
    if (channelCount == 3) {
        return if (bgr) { PixelBgr } else { PixelRgb }
    }
    if (hasAlpha) {
        if (specialBefore) {
            return if (bgr) { PixelAbgr } else { PixelArgb }
        }
        return if (bgr) { PixelBgra } else { PixelRgba }
    }
    if (specialBefore) {
        return if (bgr) { PixelXbgr } else { PixelXrgb }
    }
    if (bgr) { PixelBgrx } else { PixelRgbx }
}

private func resolvePngRowShape(
    decoded: PngDecodedRows,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>,
    outputBitDepth: UInt8
): ResolvedPngRowShape {
    let sourceAlpha = pngHasSemanticAlpha(decoded.ihdr, decoded.metadata)
    let existingAlpha = sourceAlpha && !shape.stripAlpha
    let fillerApplied = !existingAlpha && shape.fillerMode != NoFiller
    let fillerAlpha = fillerApplied && fillerModeIsAlpha(shape.fillerMode)
    let hasAlpha = existingAlpha || fillerAlpha
    let swapAlpha = hasAlpha && hasPngReadChannelTransform(transforms, SwapAlpha)
    var specialBefore = if (existingAlpha) {
        false
    } else {
        fillerApplied && fillerModeIsBefore(shape.fillerMode)
    }
    if (swapAlpha) {
        specialBefore = !specialBefore
    }
    let channelCount = if (existingAlpha || fillerApplied) { Int64(4) } else { Int64(3) }
    let bgr = hasPngReadChannelTransform(transforms, Bgr)
    let significantBits = resolvePngSignificantBitShifts(
        decoded.metadata,
        transforms,
        outputBitDepth,
        existingAlpha
    )
    let layout = resolvePixelLayout(bgr, channelCount, hasAlpha, specialBefore)
    ResolvedPngRowShape(
        hasPngReadChannelTransform(transforms, InvertMonochrome) &&
            (decoded.ihdr.colorType == Grayscale || decoded.ihdr.colorType == GrayscaleAlpha),
        existingAlpha && hasPngReadChannelTransform(transforms, InvertAlpha),
        significantBits,
        bgr,
        existingAlpha,
        shape.fillerValue,
        specialBefore,
        layout
    )
}

private func validatePixelOutputLimit(
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
            "pixel rows exceed configured transformed-byte limit"
        )
    }
}

private func transformCanonicalRow8(
    canonical: Array<Byte>,
    resolved: ResolvedPngRowShape
): Array<Byte> {
    let pixels = canonical.size / 4
    let output = Array<Byte>(pixels * resolved.channelCount, repeat: 0)
    var pixel: Int64 = 0
    while (pixel < pixels) {
        let sourceOffset = pixel * 4
        var red = canonical[sourceOffset]
        var green = canonical[sourceOffset + 1]
        var blue = canonical[sourceOffset + 2]
        var alpha = canonical[sourceOffset + 3]
        if (resolved.invertMonochrome) {
            red = UInt8(0xff) - red
            green = UInt8(0xff) - green
            blue = UInt8(0xff) - blue
        }
        if (resolved.invertExistingAlpha) {
            alpha = UInt8(0xff) - alpha
        }
        red = UInt8(UInt32(red) >> resolved.significantBits.red)
        green = UInt8(UInt32(green) >> resolved.significantBits.green)
        blue = UInt8(UInt32(blue) >> resolved.significantBits.blue)
        alpha = UInt8(UInt32(alpha) >> resolved.significantBits.alpha)
        if (resolved.bgr) {
            let value = red
            red = blue
            blue = value
        }

        let outputOffset = pixel * resolved.channelCount
        if (resolved.channelCount == 3) {
            output[outputOffset] = red
            output[outputOffset + 1] = green
            output[outputOffset + 2] = blue
        } else {
            let special = if (resolved.existingAlpha) {
                alpha
            } else {
                UInt8(resolved.fillerValue & UInt16(0xff))
            }
            if (resolved.specialBefore) {
                output[outputOffset] = special
                output[outputOffset + 1] = red
                output[outputOffset + 2] = green
                output[outputOffset + 3] = blue
            } else {
                output[outputOffset] = red
                output[outputOffset + 1] = green
                output[outputOffset + 2] = blue
                output[outputOffset + 3] = special
            }
        }
        pixel += 1
    }
    output
}

private func transformCanonicalRow16(
    canonical: Array<UInt16>,
    resolved: ResolvedPngRowShape
): Array<UInt16> {
    let pixels = canonical.size / 4
    let output = Array<UInt16>(pixels * resolved.channelCount, repeat: UInt16(0))
    var pixel: Int64 = 0
    while (pixel < pixels) {
        let sourceOffset = pixel * 4
        var red = canonical[sourceOffset]
        var green = canonical[sourceOffset + 1]
        var blue = canonical[sourceOffset + 2]
        var alpha = canonical[sourceOffset + 3]
        if (resolved.invertMonochrome) {
            red = UInt16(0xffff) - red
            green = UInt16(0xffff) - green
            blue = UInt16(0xffff) - blue
        }
        if (resolved.invertExistingAlpha) {
            alpha = UInt16(0xffff) - alpha
        }
        red = UInt16(UInt32(red) >> resolved.significantBits.red)
        green = UInt16(UInt32(green) >> resolved.significantBits.green)
        blue = UInt16(UInt32(blue) >> resolved.significantBits.blue)
        alpha = UInt16(UInt32(alpha) >> resolved.significantBits.alpha)
        if (resolved.bgr) {
            let value = red
            red = blue
            blue = value
        }

        let outputOffset = pixel * resolved.channelCount
        if (resolved.channelCount == 3) {
            output[outputOffset] = red
            output[outputOffset + 1] = green
            output[outputOffset + 2] = blue
        } else {
            let special = if (resolved.existingAlpha) { alpha } else { resolved.fillerValue }
            if (resolved.specialBefore) {
                output[outputOffset] = special
                output[outputOffset + 1] = red
                output[outputOffset + 2] = green
                output[outputOffset + 3] = blue
            } else {
                output[outputOffset] = red
                output[outputOffset + 1] = green
                output[outputOffset + 2] = blue
                output[outputOffset + 3] = special
            }
        }
        pixel += 1
    }
    output
}

public func transformPngRowsToPixels8(
    decoded: PngDecodedRows,
    limits: PngReadLimits,
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
    let resolved = resolvePngRowShape(decoded, shape, transforms, UInt8(8))
    validatePixelOutputLimit(decoded.ihdr, limits, resolved.channelCount, UInt64(1))
    let rows = Array<Array<Byte>>(decoded.rowCount(), repeat: Array<Byte>())
    var index: Int64 = 0
    while (index < rows.size) {
        let canonical = expandRowToRgba8(decoded.row(index), decoded.ihdr, decoded.metadata)
        rows[index] = transformCanonicalRow8(canonical, resolved)
        index += 1
    }
    PngPixelRows8(decoded.ihdr, decoded.metadata, resolved.layout, rows)
}

public func transformPngRowsToPixels8(
    decoded: PngDecodedRows,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows8 {
    transformPngRowsToPixels8(decoded, PngReadLimits(), shape, transforms)
}

public func transformPngRowsToPixels8(
    decoded: PngDecodedRows,
    shape: PngRowShapeTransform
): PngPixelRows8 {
    transformPngRowsToPixels8(decoded, PngReadLimits(), shape, PNG_NO_READ_CHANNEL_TRANSFORMS)
}

public func transformPngRowsToPixels8(
    decoded: PngDecodedRows,
    limits: PngReadLimits,
    mode: Png16To8Mode,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows8 {
    let resolved = resolvePngRowShape(decoded, shape, transforms, UInt8(8))
    validatePixelOutputLimit(decoded.ihdr, limits, resolved.channelCount, UInt64(1))
    let rows = Array<Array<Byte>>(decoded.rowCount(), repeat: Array<Byte>())
    var index: Int64 = 0
    while (index < rows.size) {
        let rgba16 = expandRowToRgba16(decoded.row(index), decoded.ihdr, decoded.metadata)
        let canonical = reduceRgba16Row(rgba16, mode)
        rows[index] = transformCanonicalRow8(canonical, resolved)
        index += 1
    }
    PngPixelRows8(decoded.ihdr, decoded.metadata, resolved.layout, rows)
}

public func transformPngRowsToPixels8(
    decoded: PngDecodedRows,
    mode: Png16To8Mode,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows8 {
    transformPngRowsToPixels8(decoded, PngReadLimits(), mode, shape, transforms)
}

public func transformPngRowsToPixels8(
    decoded: PngDecodedRows,
    mode: Png16To8Mode,
    shape: PngRowShapeTransform
): PngPixelRows8 {
    transformPngRowsToPixels8(
        decoded,
        PngReadLimits(),
        mode,
        shape,
        PNG_NO_READ_CHANNEL_TRANSFORMS
    )
}

public func transformPngRowsToPixels16(
    decoded: PngDecodedRows,
    limits: PngReadLimits,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows16 {
    let resolved = resolvePngRowShape(decoded, shape, transforms, UInt8(16))
    validatePixelOutputLimit(decoded.ihdr, limits, resolved.channelCount, UInt64(2))
    let rows = Array<Array<UInt16>>(decoded.rowCount(), repeat: Array<UInt16>())
    var index: Int64 = 0
    while (index < rows.size) {
        let canonical = expandRowToRgba16(decoded.row(index), decoded.ihdr, decoded.metadata)
        rows[index] = transformCanonicalRow16(canonical, resolved)
        index += 1
    }
    PngPixelRows16(decoded.ihdr, decoded.metadata, resolved.layout, rows)
}

public func transformPngRowsToPixels16(
    decoded: PngDecodedRows,
    shape: PngRowShapeTransform,
    transforms: Array<PngReadChannelTransform>
): PngPixelRows16 {
    transformPngRowsToPixels16(decoded, PngReadLimits(), shape, transforms)
}

public func transformPngRowsToPixels16(
    decoded: PngDecodedRows,
    shape: PngRowShapeTransform
): PngPixelRows16 {
    transformPngRowsToPixels16(decoded, PngReadLimits(), shape, PNG_NO_READ_CHANNEL_TRANSFORMS)
}
