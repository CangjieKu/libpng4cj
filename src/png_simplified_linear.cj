package libpng4cj

public enum PngLinearImageFormat <: Equatable<PngLinearImageFormat> & ToString {
    | LinearGray
    | LinearGrayAlpha
    | LinearAlphaGray
    | LinearRgb
    | LinearBgr
    | LinearRgba
    | LinearArgb
    | LinearBgra
    | LinearAbgr

    public operator func ==(right: PngLinearImageFormat): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngLinearImageFormat): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case LinearGray => Int64(0)
            case LinearGrayAlpha => Int64(1)
            case LinearAlphaGray => Int64(2)
            case LinearRgb => Int64(3)
            case LinearBgr => Int64(4)
            case LinearRgba => Int64(5)
            case LinearArgb => Int64(6)
            case LinearBgra => Int64(7)
            case LinearAbgr => Int64(8)
        }
    }

    public func channelCount(): UInt8 {
        match (this) {
            case LinearGray => UInt8(1)
            case LinearGrayAlpha | LinearAlphaGray => UInt8(2)
            case LinearRgb | LinearBgr => UInt8(3)
            case LinearRgba | LinearArgb | LinearBgra | LinearAbgr => UInt8(4)
        }
    }

    public func hasAlpha(): Bool {
        match (this) {
            case LinearGrayAlpha | LinearAlphaGray | LinearRgba |
                LinearArgb | LinearBgra | LinearAbgr => true
            case _ => false
        }
    }

    public func isColor(): Bool {
        match (this) {
            case LinearRgb | LinearBgr | LinearRgba | LinearArgb |
                LinearBgra | LinearAbgr => true
            case _ => false
        }
    }

    public func toString(): String {
        match (this) {
            case LinearGray => "LINEAR_Y"
            case LinearGrayAlpha => "LINEAR_Y_ALPHA"
            case LinearAlphaGray => "LINEAR_ALPHA_Y"
            case LinearRgb => "LINEAR_RGB"
            case LinearBgr => "LINEAR_BGR"
            case LinearRgba => "LINEAR_RGBA"
            case LinearArgb => "LINEAR_ARGB"
            case LinearBgra => "LINEAR_BGRA"
            case LinearAbgr => "LINEAR_ABGR"
        }
    }
}

private func pngLinearComponentCount(
    width: UInt32,
    height: UInt32,
    format: PngLinearImageFormat
): Int64 {
    let row = UInt64(width) * UInt64(format.channelCount())
    let rows = UInt64(height)
    if (row > UInt64(Int64.Max) || rows > UInt64(Int64.Max) / row) {
        throw PngFormatException(
            DecodeLimitExceeded, -1,
            "simplified linear image component count exceeds Int64"
        )
    }
    Int64(row * rows)
}

public class PngLinearImageBuffer {
    public let width: UInt32
    public let height: UInt32
    public let format: PngLinearImageFormat
    public let channels: UInt8
    public let rowStride: Int64
    public let associatedAlpha: Bool
    private let ownedComponents: Array<UInt16>
    private let strideGeometry: PngStrideGeometry

    public init(
        width: UInt32,
        height: UInt32,
        format: PngLinearImageFormat,
        components: Array<UInt16>,
        associatedAlpha: Bool
    ) {
        if (width == UInt32(0) || height == UInt32(0)) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified linear image dimensions must be positive"
            )
        }
        if (associatedAlpha && !format.hasAlpha()) {
            throw PngFormatException(
                InvalidArgument, -1,
                "associated alpha requires a linear format with alpha"
            )
        }
        let geometry = pngStrideGeometry(
            Int64(width) * Int64(format.channelCount()),
            height,
            Int64(0),
            "simplified linear image"
        )
        if (components.size != geometry.storageCount) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified linear image component count does not match shape"
            )
        }
        this.width = width
        this.height = height
        this.format = format
        channels = format.channelCount()
        rowStride = geometry.rowStride
        this.associatedAlpha = associatedAlpha
        ownedComponents = components.clone()
        strideGeometry = geometry
    }

    public init(
        width: UInt32,
        height: UInt32,
        format: PngLinearImageFormat,
        components: Array<UInt16>,
        associatedAlpha: Bool,
        rowStride: Int64
    ) {
        if (width == UInt32(0) || height == UInt32(0)) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified linear image dimensions must be positive"
            )
        }
        if (associatedAlpha && !format.hasAlpha()) {
            throw PngFormatException(
                InvalidArgument, -1,
                "associated alpha requires a linear format with alpha"
            )
        }
        let geometry = pngStrideGeometry(
            Int64(width) * Int64(format.channelCount()),
            height,
            rowStride,
            "simplified linear image"
        )
        if (components.size != geometry.storageCount) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified linear image component count does not match stride geometry"
            )
        }
        this.width = width
        this.height = height
        this.format = format
        channels = format.channelCount()
        this.rowStride = geometry.rowStride
        this.associatedAlpha = associatedAlpha
        ownedComponents = components.clone()
        strideGeometry = geometry
    }

    public func componentCount(): Int64 { ownedComponents.size }

    public func byteCount(): Int64 {
        if (ownedComponents.size > Int64.Max / Int64(2)) {
            throw PngFormatException(
                DecodeLimitExceeded, -1,
                "simplified linear image byte count exceeds Int64"
            )
        }
        ownedComponents.size * Int64(2)
    }

    public func components(): Array<UInt16> { ownedComponents.clone() }

    public func minimumRowStride(): Int64 { strideGeometry.minimum }

    public func bottomUp(): Bool { rowStride < Int64(0) }

    public func row(index: Int64): Array<UInt16> {
        pngStrideUInt16Row(
            ownedComponents,
            strideGeometry,
            index,
            false,
            "simplified linear image"
        )
    }

    public func storageRow(index: Int64): Array<UInt16> {
        pngStrideUInt16Row(
            ownedComponents,
            strideGeometry,
            index,
            true,
            "simplified linear image"
        )
    }

    public func withRowStride(
        rowStride: Int64,
        padding: UInt16
    ): PngLinearImageBuffer {
        let geometry = pngStrideGeometry(
            strideGeometry.minimum,
            height,
            rowStride,
            "simplified linear image"
        )
        PngLinearImageBuffer(
            width,
            height,
            format,
            pngStrideCopyUInt16Payload(
                ownedComponents,
                strideGeometry,
                geometry,
                padding,
                "simplified linear image"
            ),
            associatedAlpha,
            geometry.rowStride
        )
    }

    public func withRowStride(rowStride: Int64): PngLinearImageBuffer {
        withRowStride(rowStride, UInt16(0))
    }
}

private func pngLinearFileGamma(
    decoded: PngDecodedRows,
    assume16BitSrgb: Bool
): Int32 {
    if (decoded.metadata.hasGamma) {
        return Int32(decoded.metadata.gamma)
    }
    if (decoded.metadata.hasSrgb || decoded.ihdr.bitDepth <= UInt8(8) ||
        assume16BitSrgb) {
        return Int32(45455)
    }
    PNG_FP_1
}

private func pngLinearUsesExactSrgb8(decoded: PngDecodedRows): Bool {
    if (decoded.ihdr.bitDepth > UInt8(8)) { return false }
    if (decoded.metadata.hasSrgb) { return true }
    let normalized = Int32(
        (Int64(pngLinearFileGamma(decoded, false)) * Int64(11) + Int64(2)) /
        Int64(5)
    )
    !pngGammaSignificant(normalized)
}

private func pngLinearAssociate(component: UInt16, alpha: UInt16): UInt16 {
    if (alpha == UInt16(0)) { return UInt16(0) }
    if (alpha == UInt16(0xffff)) { return component }
    UInt16(
        (UInt64(component) * UInt64(alpha) + UInt64(32767)) /
        UInt64(65535)
    )
}

private func pngLinearWriteUInt16(
    row: Array<Byte>,
    offset: Int64,
    value: UInt16
): Unit {
    row[offset] = UInt8(value >> UInt16(8))
    row[offset + Int64(1)] = UInt8(value & UInt16(0xff))
}

private func pngLinearApplyExactSrgb8(
    input: PngInitializedReadRowsResult,
    associatedAlpha: Bool
): PngInitializedReadRowsResult {
    let rows = Array<Array<Byte>>(input.rowCount(), repeat: Array<Byte>())
    var rowIndex: Int64 = Int64(0)
    while (rowIndex < rows.size) {
        let row = input.row(rowIndex)
        var offset: Int64 = Int64(0)
        while (offset < row.size) {
            let alpha = pngLinearReadUInt16(row, offset + Int64(6))
            var red = pngSrgb8ToLinear16(row[offset])
            var green = pngSrgb8ToLinear16(row[offset + Int64(2)])
            var blue = pngSrgb8ToLinear16(row[offset + Int64(4)])
            if (associatedAlpha) {
                red = pngLinearAssociate(red, alpha)
                green = pngLinearAssociate(green, alpha)
                blue = pngLinearAssociate(blue, alpha)
            }
            pngLinearWriteUInt16(row, offset, red)
            pngLinearWriteUInt16(row, offset + Int64(2), green)
            pngLinearWriteUInt16(row, offset + Int64(4), blue)
            offset += Int64(8)
        }
        rows[rowIndex] = row
        rowIndex += Int64(1)
    }
    PngInitializedReadRowsResult(
        input.info,
        rows,
        input.hadNonGrayPixels,
        input.maximumPaletteIndex,
        input.hasInvalidPaletteIndex
    )
}

private func pngLinearReadRgba16(
    bytes: Array<Byte>,
    limits: PngReadLimits,
    associatedAlpha: Bool,
    assume16BitSrgb: Bool
): PngInitializedReadRowsResult {
    let decoded = decodePng(bytes, limits)
    let exactSrgb8 = pngLinearUsesExactSrgb8(decoded)
    let state = PngReadTransformState()
    if (!exactSrgb8 &&
        !state.setGammaFixed(
            PNG_FP_1, pngLinearFileGamma(decoded, assume16BitSrgb)
        )) {
        throw PngFormatException(
            InvalidArgument, -1,
            "simplified linear image gamma setup failed"
        )
    }
    if (!state.setExpand() ||
        !state.setGrayToRgb() ||
        !state.setExpand16() ||
        !state.setAddAlpha(UInt16(0xffff), true)) {
        throw PngFormatException(
            InvalidArgument, -1,
            "simplified linear image transform setup failed"
        )
    }
    if (associatedAlpha && !exactSrgb8 &&
        !state.setAlphaModeFixed(AlphaAssociated, PNG_FP_1)) {
        throw PngFormatException(
            InvalidArgument, -1,
            "simplified associated-alpha transform setup failed"
        )
    }
    let output = transformPngRowsInitialized(decoded, state, limits)
    let rgbaColorType = output.info.colorType == TruecolorAlpha ||
        output.info.colorType == Truecolor
    if (output.info.bitDepth != UInt8(16) ||
        !rgbaColorType || output.info.channels != UInt8(4)) {
        throw PngFormatException(
            UnsupportedTransform, -1,
            "simplified linear image pipeline did not produce RGBA16"
        )
    }
    let normalized = if (output.info.colorType == TruecolorAlpha) {
        output
    } else {
        PngInitializedReadRowsResult(
            PngReadRowInfo(output.info.width, UInt8(16), TruecolorAlpha),
            output.rows(),
            output.hadNonGrayPixels,
            output.maximumPaletteIndex,
            output.hasInvalidPaletteIndex
        )
    }
    if (exactSrgb8) {
        pngLinearApplyExactSrgb8(normalized, associatedAlpha)
    } else {
        normalized
    }
}

private func pngLinearReadUInt16(row: Array<Byte>, offset: Int64): UInt16 {
    UInt16(
        (UInt16(row[offset]) << UInt16(8)) |
        UInt16(row[offset + Int64(1)])
    )
}

private func pngLinearGray(red: UInt16, green: UInt16, blue: UInt16): UInt16 {
    let value =
        UInt64(6968) * UInt64(red) +
        UInt64(23434) * UInt64(green) +
        UInt64(2366) * UInt64(blue) +
        UInt64(16384)
    UInt16(value >> UInt64(15))
}

private func pngLinearWritePixel(
    output: Array<UInt16>,
    offset: Int64,
    format: PngLinearImageFormat,
    red: UInt16,
    green: UInt16,
    blue: UInt16,
    alpha: UInt16
): Unit {
    let gray = pngLinearGray(red, green, blue)
    match (format) {
        case LinearGray => output[offset] = gray
        case LinearGrayAlpha =>
            output[offset] = gray
            output[offset + Int64(1)] = alpha
        case LinearAlphaGray =>
            output[offset] = alpha
            output[offset + Int64(1)] = gray
        case LinearRgb =>
            output[offset] = red
            output[offset + Int64(1)] = green
            output[offset + Int64(2)] = blue
        case LinearBgr =>
            output[offset] = blue
            output[offset + Int64(1)] = green
            output[offset + Int64(2)] = red
        case LinearRgba =>
            output[offset] = red
            output[offset + Int64(1)] = green
            output[offset + Int64(2)] = blue
            output[offset + Int64(3)] = alpha
        case LinearArgb =>
            output[offset] = alpha
            output[offset + Int64(1)] = red
            output[offset + Int64(2)] = green
            output[offset + Int64(3)] = blue
        case LinearBgra =>
            output[offset] = blue
            output[offset + Int64(1)] = green
            output[offset + Int64(2)] = red
            output[offset + Int64(3)] = alpha
        case LinearAbgr =>
            output[offset] = alpha
            output[offset + Int64(1)] = blue
            output[offset + Int64(2)] = green
            output[offset + Int64(3)] = red
    }
}

func pngImageConvertLinear16(
    bytes: Array<Byte>,
    limits: PngReadLimits,
    format: PngLinearImageFormat,
    associatedAlpha: Bool,
    assume16BitSrgb: Bool
): PngLinearImageBuffer {
    if (associatedAlpha && !format.hasAlpha()) {
        throw PngFormatException(
            InvalidArgument, -1,
            "associated alpha requires a linear output format with alpha"
        )
    }
    let useAssociated = associatedAlpha || !format.hasAlpha()
    let rgba = pngLinearReadRgba16(
        bytes, limits, useAssociated, assume16BitSrgb
    )
    let output = Array<UInt16>(
        pngLinearComponentCount(
            rgba.info.width,
            UInt32(rgba.rowCount()),
            format
        ),
        repeat: UInt16(0)
    )
    let channels = Int64(format.channelCount())
    var outputOffset: Int64 = Int64(0)
    var rowIndex: Int64 = Int64(0)
    while (rowIndex < rgba.rowCount()) {
        let row = rgba.row(rowIndex)
        var inputOffset: Int64 = Int64(0)
        while (inputOffset < row.size) {
            pngLinearWritePixel(
                output,
                outputOffset,
                format,
                pngLinearReadUInt16(row, inputOffset),
                pngLinearReadUInt16(row, inputOffset + Int64(2)),
                pngLinearReadUInt16(row, inputOffset + Int64(4)),
                pngLinearReadUInt16(row, inputOffset + Int64(6))
            )
            inputOffset += Int64(8)
            outputOffset += channels
        }
        rowIndex += Int64(1)
    }
    PngLinearImageBuffer(
        rgba.info.width,
        UInt32(rgba.rowCount()),
        format,
        output,
        associatedAlpha
    )
}

func pngImageConvertLinear16(
    bytes: Array<Byte>,
    limits: PngReadLimits,
    format: PngLinearImageFormat,
    associatedAlpha: Bool
): PngLinearImageBuffer {
    pngImageConvertLinear16(bytes, limits, format, associatedAlpha, false)
}

private func pngLinearReadPixel(
    row: Array<UInt16>,
    offset: Int64,
    format: PngLinearImageFormat
): (UInt16, UInt16, UInt16, UInt16) {
    match (format) {
        case LinearGray =>
            (row[offset], row[offset], row[offset], UInt16(0xffff))
        case LinearGrayAlpha =>
            (row[offset], row[offset], row[offset], row[offset + Int64(1)])
        case LinearAlphaGray =>
            (row[offset + Int64(1)], row[offset + Int64(1)],
                row[offset + Int64(1)], row[offset])
        case LinearRgb =>
            (row[offset], row[offset + Int64(1)], row[offset + Int64(2)],
                UInt16(0xffff))
        case LinearBgr =>
            (row[offset + Int64(2)], row[offset + Int64(1)], row[offset],
                UInt16(0xffff))
        case LinearRgba =>
            (row[offset], row[offset + Int64(1)], row[offset + Int64(2)],
                row[offset + Int64(3)])
        case LinearArgb =>
            (row[offset + Int64(1)], row[offset + Int64(2)],
                row[offset + Int64(3)], row[offset])
        case LinearBgra =>
            (row[offset + Int64(2)], row[offset + Int64(1)], row[offset],
                row[offset + Int64(3)])
        case LinearAbgr =>
            (row[offset + Int64(3)], row[offset + Int64(2)],
                row[offset + Int64(1)], row[offset])
    }
}

private func pngLinearUnassociate(component: UInt16, alpha: UInt16): UInt16 {
    if (alpha == UInt16(0)) { return UInt16(0) }
    if (alpha == UInt16(0xffff)) { return component }
    let value = (
        UInt64(component) * UInt64(65535) + UInt64(alpha) / UInt64(2)
    ) / UInt64(alpha)
    if (value > UInt64(65535)) { UInt16(65535) } else { UInt16(value) }
}

private func pngLinearWriteShape(
    format: PngLinearImageFormat
): (PngColorType, Int64) {
    if (format.isColor()) {
        if (format.hasAlpha()) { (TruecolorAlpha, Int64(4)) }
        else { (Truecolor, Int64(3)) }
    } else if (format.hasAlpha()) {
        (GrayscaleAlpha, Int64(2))
    } else {
        (Grayscale, Int64(1))
    }
}

private func pngLinearToSrgb8(value: UInt16): UInt8 {
    pngLinear16ToSrgb8(value)
}

private func pngLinearAlpha8(value: UInt16): UInt8 {
    UInt8((UInt32(value) * UInt32(255) + UInt32(32895)) >> UInt32(16))
}

private func pngLinearCanonicalWriteRows(
    image: PngLinearImageBuffer,
    convertTo8Bit: Bool
): Array<Array<Byte>> {
    let (colorType, targetChannels) = pngLinearWriteShape(image.format)
    let bytesPerComponent = if (convertTo8Bit) { Int64(1) } else { Int64(2) }
    let rows = Array<Array<Byte>>(Int64(image.height), repeat: Array<Byte>())
    let sourceChannels = Int64(image.channels)
    var rowIndex: Int64 = Int64(0)
    while (rowIndex < rows.size) {
        let source = image.row(rowIndex)
        let target = Array<Byte>(
            Int64(image.width) * targetChannels * bytesPerComponent,
            repeat: UInt8(0)
        )
        var sourceOffset: Int64 = Int64(0)
        var targetOffset: Int64 = Int64(0)
        while (sourceOffset < source.size) {
            let (inputRed, inputGreen, inputBlue, alpha) =
                pngLinearReadPixel(source, sourceOffset, image.format)
            let red = if (image.associatedAlpha) {
                pngLinearUnassociate(inputRed, alpha)
            } else { inputRed }
            let green = if (image.associatedAlpha) {
                pngLinearUnassociate(inputGreen, alpha)
            } else { inputGreen }
            let blue = if (image.associatedAlpha) {
                pngLinearUnassociate(inputBlue, alpha)
            } else { inputBlue }
            let components: Array<UInt16> = match (colorType) {
                case Grayscale => [red]
                case GrayscaleAlpha => [red, alpha]
                case Truecolor => [red, green, blue]
                case TruecolorAlpha => [red, green, blue, alpha]
                case Indexed => throw PngFormatException(
                    InvalidArgument, -1,
                    "simplified linear image writing does not use indexed rows"
                )
            }
            let colorHasAlpha =
                colorType == GrayscaleAlpha || colorType == TruecolorAlpha
            var componentIndex: Int64 = Int64(0)
            while (componentIndex < components.size) {
                let component = components[componentIndex]
                let isAlpha = colorHasAlpha &&
                    componentIndex == components.size - Int64(1)
                if (convertTo8Bit) {
                    target[targetOffset] = if (isAlpha) {
                        pngLinearAlpha8(component)
                    } else {
                        pngLinearToSrgb8(component)
                    }
                    targetOffset += Int64(1)
                } else {
                    target[targetOffset] = UInt8(component >> UInt16(8))
                    target[targetOffset + Int64(1)] =
                        UInt8(component & UInt16(0xff))
                    targetOffset += Int64(2)
                }
                componentIndex += Int64(1)
            }
            sourceOffset += sourceChannels
        }
        rows[rowIndex] = target
        rowIndex += Int64(1)
    }
    rows
}

private func pngLinearWriteMetadata(
    metadata: PngWriteMetadata,
    colorType: PngColorType,
    convertTo8Bit: Bool,
    colorspaceNotSrgb: Bool
): PngWriteMetadata {
    let output = PngWriteMetadata(metadata)
    output.hasGammaValue = true
    output.gammaValue = if (convertTo8Bit) { UInt32(45455) } else { UInt32(100000) }
    if (convertTo8Bit && !colorspaceNotSrgb) {
        output.hasSrgbValue = true
        output.srgbValue = Perceptual
    } else {
        output.hasSrgbValue = false
        if (!convertTo8Bit && !colorspaceNotSrgb &&
            (colorType == Truecolor || colorType == TruecolorAlpha)) {
            output.hasChromaticitiesValue = true
            output.chromaticitiesValue = PngChromaticities(
                Int32(31270), Int32(32900),
                Int32(64000), Int32(33000),
                Int32(30000), Int32(60000),
                Int32(15000), Int32(6000)
            )
        }
    }
    output
}

func writePngLinearImageToMemoryWithColorspace(
    image: PngLinearImageBuffer,
    convertTo8Bit: Bool,
    colorspaceNotSrgb: Bool,
    metadata: PngWriteMetadata,
    controls: PngWriteControlState,
    interlaceMethod: PngInterlaceMethod,
    limits: PngWriteLimits
): Array<Byte> {
    let (colorType, _) = pngLinearWriteShape(image.format)
    PngWriteSession(
        image.width,
        image.height,
        if (convertTo8Bit) { UInt8(8) } else { UInt8(16) },
        colorType,
        interlaceMethod,
        Array<Byte>(),
        pngLinearWriteMetadata(
            metadata, colorType, convertTo8Bit, colorspaceNotSrgb
        ),
        controls,
        limits
    ).write(pngLinearCanonicalWriteRows(image, convertTo8Bit))
}

public func writePngLinearImageToMemory(
    image: PngLinearImageBuffer,
    convertTo8Bit: Bool,
    metadata: PngWriteMetadata,
    controls: PngWriteControlState,
    interlaceMethod: PngInterlaceMethod,
    limits: PngWriteLimits
): Array<Byte> {
    writePngLinearImageToMemoryWithColorspace(
        image, convertTo8Bit, false, metadata, controls, interlaceMethod, limits
    )
}

public func writePngLinearImageToMemory(
    image: PngLinearImageBuffer,
    convertTo8Bit: Bool,
    interlaceMethod: PngInterlaceMethod
): Array<Byte> {
    writePngLinearImageToMemory(
        image,
        convertTo8Bit,
        PngWriteMetadata(),
        PngWriteControlState(),
        interlaceMethod,
        PngWriteLimits()
    )
}

public func writePngLinearImageToMemory(
    image: PngLinearImageBuffer,
    convertTo8Bit: Bool
): Array<Byte> {
    writePngLinearImageToMemory(image, convertTo8Bit, None)
}

public func writePngLinearImageToMemory(
    image: PngLinearImageBuffer
): Array<Byte> {
    writePngLinearImageToMemory(image, false)
}
