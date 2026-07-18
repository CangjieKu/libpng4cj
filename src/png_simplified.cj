package libpng4cj

import std.io.InputStream

public let PNG_IMAGE_VERSION: UInt32 = UInt32(1)
public let PNG_IMAGE_WARNING: UInt32 = UInt32(1)
public let PNG_IMAGE_ERROR: UInt32 = UInt32(2)

public enum PngImageFormat <: Equatable<PngImageFormat> & ToString {
    | ImageGray8
    | ImageGrayAlpha8
    | ImageAlphaGray8
    | ImageRgb8
    | ImageBgr8
    | ImageRgba8
    | ImageArgb8
    | ImageBgra8
    | ImageAbgr8

    public operator func ==(right: PngImageFormat): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngImageFormat): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ImageGray8 => Int64(0)
            case ImageGrayAlpha8 => Int64(1)
            case ImageAlphaGray8 => Int64(2)
            case ImageRgb8 => Int64(3)
            case ImageBgr8 => Int64(4)
            case ImageRgba8 => Int64(5)
            case ImageArgb8 => Int64(6)
            case ImageBgra8 => Int64(7)
            case ImageAbgr8 => Int64(8)
        }
    }

    public func channelCount(): UInt8 {
        match (this) {
            case ImageGray8 => UInt8(1)
            case ImageGrayAlpha8 | ImageAlphaGray8 => UInt8(2)
            case ImageRgb8 | ImageBgr8 => UInt8(3)
            case ImageRgba8 | ImageArgb8 | ImageBgra8 | ImageAbgr8 => UInt8(4)
        }
    }

    public func hasAlpha(): Bool {
        match (this) {
            case ImageGrayAlpha8 | ImageAlphaGray8 | ImageRgba8 |
                ImageArgb8 | ImageBgra8 | ImageAbgr8 => true
            case _ => false
        }
    }

    public func isColor(): Bool {
        match (this) {
            case ImageRgb8 | ImageBgr8 | ImageRgba8 | ImageArgb8 |
                ImageBgra8 | ImageAbgr8 => true
            case _ => false
        }
    }

    public func toString(): String {
        match (this) {
            case ImageGray8 => "GRAY8"
            case ImageGrayAlpha8 => "GA8"
            case ImageAlphaGray8 => "AG8"
            case ImageRgb8 => "RGB8"
            case ImageBgr8 => "BGR8"
            case ImageRgba8 => "RGBA8"
            case ImageArgb8 => "ARGB8"
            case ImageBgra8 => "BGRA8"
            case ImageAbgr8 => "ABGR8"
        }
    }
}

public enum PngImageState <: Equatable<PngImageState> & ToString {
    | PngImageEmpty
    | PngImageReading
    | PngImageFinished
    | PngImageFreed
    | PngImageFailed

    public operator func ==(right: PngImageState): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngImageState): Bool {
        !(this == right)
    }

    private func ordinalValue(): Int64 {
        match (this) {
            case PngImageEmpty => Int64(0)
            case PngImageReading => Int64(1)
            case PngImageFinished => Int64(2)
            case PngImageFreed => Int64(3)
            case PngImageFailed => Int64(4)
        }
    }

    public func toString(): String {
        match (this) {
            case PngImageEmpty => "EMPTY"
            case PngImageReading => "READING"
            case PngImageFinished => "FINISHED"
            case PngImageFreed => "FREED"
            case PngImageFailed => "FAILED"
        }
    }
}

public class PngSrgbColor8 {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        this.red = red
        this.green = green
        this.blue = blue
    }

    public init() {
        red = UInt8(0)
        green = UInt8(0)
        blue = UInt8(0)
    }
}

private func pngImageRowBytes(width: UInt32, format: PngImageFormat): Int64 {
    let size = UInt64(width) * UInt64(format.channelCount())
    if (size > UInt64(Int64.Max)) {
        throw PngFormatException(
            DecodeLimitExceeded, -1, "simplified image row size exceeds Int64"
        )
    }
    Int64(size)
}

private func pngImageBufferBytes(
    width: UInt32,
    height: UInt32,
    format: PngImageFormat
): Int64 {
    let rowBytes = UInt64(pngImageRowBytes(width, format))
    let rows = UInt64(height)
    if (rows > UInt64(Int64.Max) / rowBytes) {
        throw PngFormatException(
            DecodeLimitExceeded, -1, "simplified image buffer size exceeds Int64"
        )
    }
    Int64(rowBytes * rows)
}

public class PngImageBuffer {
    public let width: UInt32
    public let height: UInt32
    public let format: PngImageFormat
    public let channels: UInt8
    public let rowStride: Int64
    private let ownedBytes: Array<Byte>
    private let strideGeometry: PngStrideGeometry

    public init(
        width: UInt32,
        height: UInt32,
        format: PngImageFormat,
        bytes: Array<Byte>
    ) {
        if (width == UInt32(0) || height == UInt32(0)) {
            throw PngFormatException(
                InvalidArgument, -1, "simplified image dimensions must be positive"
            )
        }
        let geometry = pngStrideGeometry(
            pngImageRowBytes(width, format), height, Int64(0),
            "simplified image"
        )
        if (bytes.size != geometry.storageCount) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified image buffer length does not match its dimensions and format"
            )
        }
        this.width = width
        this.height = height
        this.format = format
        channels = format.channelCount()
        rowStride = geometry.rowStride
        ownedBytes = bytes.clone()
        strideGeometry = geometry
    }

    public init(
        width: UInt32,
        height: UInt32,
        format: PngImageFormat,
        bytes: Array<Byte>,
        rowStride: Int64
    ) {
        if (width == UInt32(0) || height == UInt32(0)) {
            throw PngFormatException(
                InvalidArgument, -1, "simplified image dimensions must be positive"
            )
        }
        let geometry = pngStrideGeometry(
            pngImageRowBytes(width, format), height, rowStride,
            "simplified image"
        )
        if (bytes.size != geometry.storageCount) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified image buffer length does not match its stride geometry"
            )
        }
        this.width = width
        this.height = height
        this.format = format
        channels = format.channelCount()
        this.rowStride = geometry.rowStride
        ownedBytes = bytes.clone()
        strideGeometry = geometry
    }

    public func byteCount(): Int64 {
        ownedBytes.size
    }

    public func bytes(): Array<Byte> {
        ownedBytes.clone()
    }

    public func minimumRowStride(): Int64 { strideGeometry.minimum }

    public func bottomUp(): Bool { rowStride < Int64(0) }

    public func row(index: Int64): Array<Byte> {
        pngStrideByteRow(
            ownedBytes, strideGeometry, index, false, "simplified image"
        )
    }

    public func storageRow(index: Int64): Array<Byte> {
        pngStrideByteRow(
            ownedBytes, strideGeometry, index, true, "simplified image"
        )
    }

    public func withRowStride(
        rowStride: Int64,
        padding: UInt8
    ): PngImageBuffer {
        let geometry = pngStrideGeometry(
            strideGeometry.minimum, height, rowStride, "simplified image"
        )
        PngImageBuffer(
            width, height, format,
            pngStrideCopyBytePayload(
                ownedBytes,
                strideGeometry,
                geometry,
                padding,
                "simplified image"
            ),
            geometry.rowStride
        )
    }

    public func withRowStride(rowStride: Int64): PngImageBuffer {
        withRowStride(rowStride, UInt8(0))
    }
}

private func pngImageHasInherentAlpha(colorType: PngColorType): Bool {
    colorType == GrayscaleAlpha || colorType == TruecolorAlpha
}

private func pngImageSuggestedFormat(ihdr: PngIhdr): PngImageFormat {
    let alpha = pngImageHasInherentAlpha(ihdr.colorType)
    match (ihdr.colorType) {
        case Grayscale | GrayscaleAlpha =>
            if (alpha) { ImageGrayAlpha8 } else { ImageGray8 }
        case _ =>
            if (alpha) { ImageRgba8 } else { ImageRgb8 }
    }
}

private func pngImageComposite8(
    foreground: UInt8,
    alpha: UInt8,
    background: UInt8
): UInt8 {
    let numerator =
        UInt32(foreground) * UInt32(alpha) +
        UInt32(background) * (UInt32(255) - UInt32(alpha)) +
        UInt32(127)
    UInt8(numerator / UInt32(255))
}

private func pngImageGray8(red: UInt8, green: UInt8, blue: UInt8): UInt8 {
    let value =
        UInt32(6968) * UInt32(red) +
        UInt32(23434) * UInt32(green) +
        UInt32(2366) * UInt32(blue) +
        UInt32(16384)
    UInt8(value >> UInt32(15))
}

private func pngImageWritePixel(
    output: Array<Byte>,
    offset: Int64,
    format: PngImageFormat,
    red: UInt8,
    green: UInt8,
    blue: UInt8,
    alpha: UInt8,
    background: PngSrgbColor8
): Unit {
    var r = red
    var g = green
    var b = blue
    if (!format.hasAlpha()) {
        r = pngImageComposite8(r, alpha, background.red)
        g = pngImageComposite8(g, alpha, background.green)
        b = pngImageComposite8(b, alpha, background.blue)
    }
    let gray = pngImageGray8(r, g, b)
    match (format) {
        case ImageGray8 =>
            output[offset] = gray
        case ImageGrayAlpha8 =>
            output[offset] = gray
            output[offset + Int64(1)] = alpha
        case ImageAlphaGray8 =>
            output[offset] = alpha
            output[offset + Int64(1)] = gray
        case ImageRgb8 =>
            output[offset] = r
            output[offset + Int64(1)] = g
            output[offset + Int64(2)] = b
        case ImageBgr8 =>
            output[offset] = b
            output[offset + Int64(1)] = g
            output[offset + Int64(2)] = r
        case ImageRgba8 =>
            output[offset] = r
            output[offset + Int64(1)] = g
            output[offset + Int64(2)] = b
            output[offset + Int64(3)] = alpha
        case ImageArgb8 =>
            output[offset] = alpha
            output[offset + Int64(1)] = r
            output[offset + Int64(2)] = g
            output[offset + Int64(3)] = b
        case ImageBgra8 =>
            output[offset] = b
            output[offset + Int64(1)] = g
            output[offset + Int64(2)] = r
            output[offset + Int64(3)] = alpha
        case ImageAbgr8 =>
            output[offset] = alpha
            output[offset + Int64(1)] = b
            output[offset + Int64(2)] = g
            output[offset + Int64(3)] = r
    }
}

private func pngImageConvertRgba8(
    rgba: PngRgba8Rows,
    format: PngImageFormat,
    background: PngSrgbColor8
): PngImageBuffer {
    let output = Array<Byte>(
        pngImageBufferBytes(rgba.ihdr.width, rgba.ihdr.height, format),
        repeat: UInt8(0)
    )
    let channels = Int64(format.channelCount())
    var outputOffset: Int64 = Int64(0)
    var rowIndex: Int64 = Int64(0)
    while (rowIndex < rgba.rowCount()) {
        let row = rgba.row(rowIndex)
        var inputOffset: Int64 = Int64(0)
        while (inputOffset < row.size) {
            pngImageWritePixel(
                output, outputOffset, format,
                row[inputOffset],
                row[inputOffset + Int64(1)],
                row[inputOffset + Int64(2)],
                row[inputOffset + Int64(3)],
                background
            )
            inputOffset += Int64(4)
            outputOffset += channels
        }
        rowIndex += Int64(1)
    }
    PngImageBuffer(rgba.ihdr.width, rgba.ihdr.height, format, output)
}

public class PngImage {
    public let version: UInt32 = PNG_IMAGE_VERSION
    private var stateValue: PngImageState = PngImageEmpty
    private var inputValue: Array<Byte> = Array<Byte>()
    private var limitsValue: PngReadLimits = PngReadLimits()
    private var widthValue: UInt32 = UInt32(0)
    private var heightValue: UInt32 = UInt32(0)
    private var sourceBitDepthValue: UInt8 = UInt8(0)
    private var sourceColorTypeValue: PngColorType = Grayscale
    private var suggestedFormatValue: PngImageFormat = ImageGray8
    private var warningOrErrorValue: UInt32 = UInt32(0)
    private var errorKindValue: Int64 = Int64(-1)
    private var errorOffsetValue: Int64 = Int64(-1)
    private var messageValue: String = ""

    public init() {}

    public func state(): PngImageState { stateValue }
    public func width(): UInt32 { widthValue }
    public func height(): UInt32 { heightValue }
    public func sourceBitDepth(): UInt8 { sourceBitDepthValue }
    public func sourceColorType(): PngColorType { sourceColorTypeValue }
    public func suggestedFormat(): PngImageFormat { suggestedFormatValue }
    public func warningOrError(): UInt32 { warningOrErrorValue }
    public func failed(): Bool { (warningOrErrorValue & UInt32(3)) > UInt32(1) }
    public func errorKindOrdinal(): Int64 { errorKindValue }
    public func errorOffset(): Int64 { errorOffsetValue }
    public func message(): String { messageValue }

    private func clearDiagnostic(): Unit {
        warningOrErrorValue = UInt32(0)
        errorKindValue = Int64(-1)
        errorOffsetValue = Int64(-1)
        messageValue = ""
    }

    private func clearImageFacts(): Unit {
        widthValue = UInt32(0)
        heightValue = UInt32(0)
        sourceBitDepthValue = UInt8(0)
        sourceColorTypeValue = Grayscale
        suggestedFormatValue = ImageGray8
    }

    private func recordFailure(error: PngFormatException): Unit {
        warningOrErrorValue |= PNG_IMAGE_ERROR
        errorKindValue = error.kind.ordinalValue()
        errorOffsetValue = error.offset
        messageValue = error.message
        inputValue = Array<Byte>()
        stateValue = PngImageFailed
    }

    private func beginReadWith(
        source: () -> Array<Byte>,
        limits: PngReadLimits
    ): Unit {
        if (stateValue != PngImageEmpty && stateValue != PngImageFreed) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified image begin requires an empty or freed image"
            )
        }
        clearDiagnostic()
        clearImageFacts()
        try {
            let bytes = source()
            let ihdr = readPngIhdr(bytes, limits)
            inputValue = bytes.clone()
            limitsValue = limits
            widthValue = ihdr.width
            heightValue = ihdr.height
            sourceBitDepthValue = ihdr.bitDepth
            sourceColorTypeValue = ihdr.colorType
            suggestedFormatValue = pngImageSuggestedFormat(ihdr)
            stateValue = PngImageReading
        } catch (error: PngFormatException) {
            recordFailure(error)
            throw error
        }
    }

    public func beginReadFromMemory(bytes: Array<Byte>, limits: PngReadLimits): Unit {
        beginReadWith({ => bytes }, limits)
    }

    public func beginReadFromMemory(bytes: Array<Byte>): Unit {
        beginReadFromMemory(bytes, PngReadLimits())
    }

    public func beginReadFromStream(
        input: InputStream,
        limits: PngReadLimits,
        ioLimits: PngSimplifiedIoLimits
    ): Unit {
        beginReadWith(
            { => pngReadSimplifiedStreamBytes(input, ioLimits) },
            limits
        )
    }

    public func beginReadFromStream(
        input: InputStream,
        limits: PngReadLimits
    ): Unit {
        beginReadFromStream(input, limits, PngSimplifiedIoLimits())
    }

    public func beginReadFromStream(input: InputStream): Unit {
        beginReadFromStream(input, PngReadLimits())
    }

    public func beginReadFromFile(
        path: String,
        limits: PngReadLimits,
        ioLimits: PngSimplifiedIoLimits
    ): Unit {
        beginReadWith(
            { => pngReadSimplifiedFileBytes(path, ioLimits) },
            limits
        )
    }

    public func beginReadFromFile(path: String, limits: PngReadLimits): Unit {
        beginReadFromFile(path, limits, PngSimplifiedIoLimits())
    }

    public func beginReadFromFile(path: String): Unit {
        beginReadFromFile(path, PngReadLimits())
    }

    public func finishRead(
        format: PngImageFormat,
        background: PngSrgbColor8
    ): PngImageBuffer {
        if (stateValue != PngImageReading) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified image finish requires a successful begin"
            )
        }
        try {
            let output = pngImageConvertRgba8(
                decodePngRgba8(inputValue, limitsValue, Scale),
                format,
                background
            )
            inputValue = Array<Byte>()
            stateValue = PngImageFinished
            output
        } catch (error: PngFormatException) {
            recordFailure(error)
            throw error
        }
    }

    public func finishRead(format: PngImageFormat): PngImageBuffer {
        finishRead(format, PngSrgbColor8())
    }

    public func finishReadStrided(
        format: PngImageFormat,
        background: PngSrgbColor8,
        rowStride: Int64,
        padding: UInt8
    ): PngImageBuffer {
        if (stateValue != PngImageReading) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified image finish requires a successful begin"
            )
        }
        try {
            let geometry = pngStrideGeometry(
                pngImageRowBytes(widthValue, format), heightValue, rowStride,
                "simplified image"
            )
            pngStrideChargeRead(
                geometry.storageCount, Int64(1), Int64(0), limitsValue,
                "simplified image"
            )
            let output = pngImageConvertRgba8(
                decodePngRgba8(inputValue, limitsValue, Scale),
                format,
                background
            ).withRowStride(geometry.rowStride, padding)
            inputValue = Array<Byte>()
            stateValue = PngImageFinished
            output
        } catch (error: PngFormatException) {
            recordFailure(error)
            throw error
        }
    }

    public func finishReadStrided(
        format: PngImageFormat,
        rowStride: Int64,
        padding: UInt8
    ): PngImageBuffer {
        finishReadStrided(format, PngSrgbColor8(), rowStride, padding)
    }

    public func finishReadStrided(
        format: PngImageFormat,
        background: PngSrgbColor8,
        rowStride: Int64
    ): PngImageBuffer {
        finishReadStrided(format, background, rowStride, UInt8(0))
    }

    public func finishReadStrided(
        format: PngImageFormat,
        rowStride: Int64
    ): PngImageBuffer {
        finishReadStrided(format, rowStride, UInt8(0))
    }

    public func finishReadLinear(
        format: PngLinearImageFormat,
        associatedAlpha: Bool
    ): PngLinearImageBuffer {
        if (stateValue != PngImageReading) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified linear image finish requires a successful begin"
            )
        }
        try {
            let output = pngImageConvertLinear16(
                inputValue,
                limitsValue,
                format,
                associatedAlpha
            )
            inputValue = Array<Byte>()
            stateValue = PngImageFinished
            output
        } catch (error: PngFormatException) {
            recordFailure(error)
            throw error
        }
    }

    public func finishReadLinear(
        format: PngLinearImageFormat
    ): PngLinearImageBuffer {
        finishReadLinear(format, false)
    }

    public func finishReadLinearStrided(
        format: PngLinearImageFormat,
        associatedAlpha: Bool,
        rowStride: Int64,
        padding: UInt16
    ): PngLinearImageBuffer {
        if (stateValue != PngImageReading) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified linear image finish requires a successful begin"
            )
        }
        try {
            let geometry = pngStrideGeometry(
                Int64(widthValue) * Int64(format.channelCount()),
                heightValue,
                rowStride,
                "simplified linear image"
            )
            pngStrideChargeRead(
                geometry.storageCount,
                Int64(2),
                Int64(0),
                limitsValue,
                "simplified linear image"
            )
            let output = pngImageConvertLinear16(
                inputValue,
                limitsValue,
                format,
                associatedAlpha
            ).withRowStride(geometry.rowStride, padding)
            inputValue = Array<Byte>()
            stateValue = PngImageFinished
            output
        } catch (error: PngFormatException) {
            recordFailure(error)
            throw error
        }
    }

    public func finishReadLinearStrided(
        format: PngLinearImageFormat,
        rowStride: Int64,
        padding: UInt16
    ): PngLinearImageBuffer {
        finishReadLinearStrided(format, false, rowStride, padding)
    }

    public func finishReadLinearStrided(
        format: PngLinearImageFormat,
        associatedAlpha: Bool,
        rowStride: Int64
    ): PngLinearImageBuffer {
        finishReadLinearStrided(
            format, associatedAlpha, rowStride, UInt16(0)
        )
    }

    public func finishReadLinearStrided(
        format: PngLinearImageFormat,
        rowStride: Int64
    ): PngLinearImageBuffer {
        finishReadLinearStrided(format, rowStride, UInt16(0))
    }

    public func finishReadColormap(
        format: PngColormapFormat,
        background: PngSrgbColor8
    ): PngColormapImageBuffer {
        if (stateValue != PngImageReading) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified colormap finish requires a successful begin"
            )
        }
        try {
            let output = pngImageConvertColormap(
                inputValue, limitsValue, format, background
            )
            inputValue = Array<Byte>()
            stateValue = PngImageFinished
            output
        } catch (error: PngFormatException) {
            recordFailure(error)
            throw error
        }
    }

    public func finishReadColormap(
        format: PngColormapFormat
    ): PngColormapImageBuffer {
        finishReadColormap(format, PngSrgbColor8())
    }

    public func finishReadColormapStrided(
        format: PngColormapFormat,
        background: PngSrgbColor8,
        rowStride: Int64,
        padding: UInt8
    ): PngColormapImageBuffer {
        if (stateValue != PngImageReading) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified colormap finish requires a successful begin"
            )
        }
        try {
            let geometry = pngStrideGeometry(
                Int64(widthValue),
                heightValue,
                rowStride,
                "simplified colormap image"
            )
            let output = pngImageConvertColormap(
                inputValue, limitsValue, format, background
            )
            pngStrideChargeRead(
                geometry.storageCount,
                Int64(1),
                output.colormapByteCount(),
                limitsValue,
                "simplified colormap image"
            )
            let strided = output.withRowStride(geometry.rowStride, padding)
            inputValue = Array<Byte>()
            stateValue = PngImageFinished
            strided
        } catch (error: PngFormatException) {
            recordFailure(error)
            throw error
        }
    }

    public func finishReadColormapStrided(
        format: PngColormapFormat,
        rowStride: Int64,
        padding: UInt8
    ): PngColormapImageBuffer {
        finishReadColormapStrided(
            format, PngSrgbColor8(), rowStride, padding
        )
    }

    public func finishReadColormapStrided(
        format: PngColormapFormat,
        background: PngSrgbColor8,
        rowStride: Int64
    ): PngColormapImageBuffer {
        finishReadColormapStrided(
            format, background, rowStride, UInt8(0)
        )
    }

    public func finishReadColormapStrided(
        format: PngColormapFormat,
        rowStride: Int64
    ): PngColormapImageBuffer {
        finishReadColormapStrided(format, rowStride, UInt8(0))
    }

    public func free(): Unit {
        inputValue = Array<Byte>()
        stateValue = PngImageFreed
    }
}

public func beginPngImageReadFromMemory(
    bytes: Array<Byte>,
    limits: PngReadLimits
): PngImage {
    let image = PngImage()
    image.beginReadFromMemory(bytes, limits)
    image
}

public func beginPngImageReadFromMemory(bytes: Array<Byte>): PngImage {
    beginPngImageReadFromMemory(bytes, PngReadLimits())
}

private func pngImageReadPixel(
    row: Array<Byte>,
    offset: Int64,
    format: PngImageFormat
): (UInt8, UInt8, UInt8, UInt8) {
    match (format) {
        case ImageGray8 =>
            (row[offset], row[offset], row[offset], UInt8(255))
        case ImageGrayAlpha8 =>
            (row[offset], row[offset], row[offset], row[offset + Int64(1)])
        case ImageAlphaGray8 =>
            (row[offset + Int64(1)], row[offset + Int64(1)],
                row[offset + Int64(1)], row[offset])
        case ImageRgb8 =>
            (row[offset], row[offset + Int64(1)], row[offset + Int64(2)], UInt8(255))
        case ImageBgr8 =>
            (row[offset + Int64(2)], row[offset + Int64(1)], row[offset], UInt8(255))
        case ImageRgba8 =>
            (row[offset], row[offset + Int64(1)], row[offset + Int64(2)],
                row[offset + Int64(3)])
        case ImageArgb8 =>
            (row[offset + Int64(1)], row[offset + Int64(2)],
                row[offset + Int64(3)], row[offset])
        case ImageBgra8 =>
            (row[offset + Int64(2)], row[offset + Int64(1)], row[offset],
                row[offset + Int64(3)])
        case ImageAbgr8 =>
            (row[offset + Int64(3)], row[offset + Int64(2)],
                row[offset + Int64(1)], row[offset])
    }
}

private func pngImageWriteShape(format: PngImageFormat): (PngColorType, Int64) {
    if (format.isColor()) {
        if (format.hasAlpha()) {
            (TruecolorAlpha, Int64(4))
        } else {
            (Truecolor, Int64(3))
        }
    } else if (format.hasAlpha()) {
        (GrayscaleAlpha, Int64(2))
    } else {
        (Grayscale, Int64(1))
    }
}

private func pngImageCanonicalWriteRows(image: PngImageBuffer): Array<Array<Byte>> {
    let (colorType, targetChannels) = pngImageWriteShape(image.format)
    let rows = Array<Array<Byte>>(Int64(image.height), repeat: Array<Byte>())
    let sourceChannels = Int64(image.channels)
    var rowIndex: Int64 = Int64(0)
    while (rowIndex < rows.size) {
        let source = image.row(rowIndex)
        let target = Array<Byte>(
            Int64(image.width) * targetChannels, repeat: UInt8(0)
        )
        var sourceOffset: Int64 = Int64(0)
        var targetOffset: Int64 = Int64(0)
        while (sourceOffset < source.size) {
            let (red, green, blue, alpha) =
                pngImageReadPixel(source, sourceOffset, image.format)
            match (colorType) {
                case Grayscale =>
                    target[targetOffset] = red
                case GrayscaleAlpha =>
                    target[targetOffset] = red
                    target[targetOffset + Int64(1)] = alpha
                case Truecolor =>
                    target[targetOffset] = red
                    target[targetOffset + Int64(1)] = green
                    target[targetOffset + Int64(2)] = blue
                case TruecolorAlpha =>
                    target[targetOffset] = red
                    target[targetOffset + Int64(1)] = green
                    target[targetOffset + Int64(2)] = blue
                    target[targetOffset + Int64(3)] = alpha
                case Indexed =>
                    throw PngFormatException(
                        InvalidArgument, -1,
                        "simplified direct image writing does not use indexed rows"
                    )
            }
            sourceOffset += sourceChannels
            targetOffset += targetChannels
        }
        rows[rowIndex] = target
        rowIndex += Int64(1)
    }
    rows
}

public func writePngImageToMemory(
    image: PngImageBuffer,
    metadata: PngWriteMetadata,
    controls: PngWriteControlState,
    interlaceMethod: PngInterlaceMethod,
    limits: PngWriteLimits
): Array<Byte> {
    let (colorType, _) = pngImageWriteShape(image.format)
    PngWriteSession(
        image.width,
        image.height,
        UInt8(8),
        colorType,
        interlaceMethod,
        Array<Byte>(),
        metadata,
        controls,
        limits
    ).write(pngImageCanonicalWriteRows(image))
}

public func writePngImageToMemory(
    image: PngImageBuffer,
    interlaceMethod: PngInterlaceMethod
): Array<Byte> {
    writePngImageToMemory(
        image,
        PngWriteMetadata(),
        PngWriteControlState(),
        interlaceMethod,
        PngWriteLimits()
    )
}

public func writePngImageToMemory(image: PngImageBuffer): Array<Byte> {
    writePngImageToMemory(image, None)
}
