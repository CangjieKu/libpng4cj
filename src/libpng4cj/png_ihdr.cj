package libpng4cj

public enum PngColorType <: Equatable<PngColorType> & ToString {
    | Grayscale
    | Truecolor
    | Indexed
    | GrayscaleAlpha
    | TruecolorAlpha

    public operator func ==(right: PngColorType): Bool {
        encodedValue() == right.encodedValue()
    }

    public operator func !=(right: PngColorType): Bool {
        !(this == right)
    }

    public func encodedValue(): UInt8 {
        match (this) {
            case Grayscale => UInt8(0)
            case Truecolor => UInt8(2)
            case Indexed => UInt8(3)
            case GrayscaleAlpha => UInt8(4)
            case TruecolorAlpha => UInt8(6)
        }
    }

    public func channels(): UInt8 {
        match (this) {
            case Grayscale => UInt8(1)
            case Truecolor => UInt8(3)
            case Indexed => UInt8(1)
            case GrayscaleAlpha => UInt8(2)
            case TruecolorAlpha => UInt8(4)
        }
    }

    public func toString(): String {
        match (this) {
            case Grayscale => "GRAYSCALE"
            case Truecolor => "TRUECOLOR"
            case Indexed => "INDEXED"
            case GrayscaleAlpha => "GRAYSCALE_ALPHA"
            case TruecolorAlpha => "TRUECOLOR_ALPHA"
        }
    }
}

public enum PngInterlaceMethod <: Equatable<PngInterlaceMethod> & ToString {
    | None
    | Adam7

    public operator func ==(right: PngInterlaceMethod): Bool {
        encodedValue() == right.encodedValue()
    }

    public operator func !=(right: PngInterlaceMethod): Bool {
        !(this == right)
    }

    public func encodedValue(): UInt8 {
        match (this) {
            case None => UInt8(0)
            case Adam7 => UInt8(1)
        }
    }

    public func toString(): String {
        match (this) {
            case None => "NONE"
            case Adam7 => "ADAM7"
        }
    }
}

public class PngIhdr {
    public let width: UInt32
    public let height: UInt32
    public let bitDepth: UInt8
    public let colorType: PngColorType
    public let compressionMethod: UInt8
    public let filterMethod: UInt8
    public let interlaceMethod: PngInterlaceMethod
    public let channels: UInt8
    public let pixelDepth: UInt16
    public let rowBytes: UInt64

    init(
        width: UInt32,
        height: UInt32,
        bitDepth: UInt8,
        colorType: PngColorType,
        compressionMethod: UInt8,
        filterMethod: UInt8,
        interlaceMethod: PngInterlaceMethod
    ) {
        this.width = width
        this.height = height
        this.bitDepth = bitDepth
        this.colorType = colorType
        this.compressionMethod = compressionMethod
        this.filterMethod = filterMethod
        this.interlaceMethod = interlaceMethod
        channels = colorType.channels()
        pixelDepth = UInt16(bitDepth) * UInt16(channels)
        rowBytes = (UInt64(width) * UInt64(pixelDepth) + UInt64(7)) / UInt64(8)
    }
}

private func parseColorType(value: UInt8, offset: Int64): PngColorType {
    match (value) {
        case 0 => Grayscale
        case 2 => Truecolor
        case 3 => Indexed
        case 4 => GrayscaleAlpha
        case 6 => TruecolorAlpha
        case _ => throw PngFormatException(InvalidIhdr, offset, "IHDR color type is invalid")
    }
}

private func parseInterlaceMethod(value: UInt8, offset: Int64): PngInterlaceMethod {
    match (value) {
        case 0 => None
        case 1 => Adam7
        case _ => throw PngFormatException(InvalidIhdr, offset, "IHDR interlace method is invalid")
    }
}

private func validBitDepth(value: UInt8): Bool {
    value == UInt8(1) || value == UInt8(2) || value == UInt8(4) ||
        value == UInt8(8) || value == UInt8(16)
}

private func validColorDepth(colorType: PngColorType, bitDepth: UInt8): Bool {
    match (colorType) {
        case Grayscale => validBitDepth(bitDepth)
        case Indexed => bitDepth == UInt8(1) || bitDepth == UInt8(2) ||
            bitDepth == UInt8(4) || bitDepth == UInt8(8)
        case Truecolor => bitDepth == UInt8(8) || bitDepth == UInt8(16)
        case GrayscaleAlpha => bitDepth == UInt8(8) || bitDepth == UInt8(16)
        case TruecolorAlpha => bitDepth == UInt8(8) || bitDepth == UInt8(16)
    }
}

public func parsePngIhdr(chunk: PngChunk, limits: PngReadLimits): PngIhdr {
    if (!chunk.isType(PNG_CHUNK_IHDR)) {
        throw PngFormatException(InvalidIhdr, chunk.offset + 4, "chunk is not IHDR")
    }
    if (chunk.length != UInt32(13)) {
        throw PngFormatException(InvalidIhdr, chunk.offset, "IHDR chunk length must be 13")
    }

    let data = chunk.payload()
    let dataOffset = chunk.offset + 8
    let width = readUInt32Be(data, 0)
    let height = readUInt32Be(data, 4)
    if (width == UInt32(0) || width > PNG_UINT_31_MAX) {
        throw PngFormatException(InvalidIhdr, dataOffset, "IHDR width is invalid")
    }
    if (height == UInt32(0) || height > PNG_UINT_31_MAX) {
        throw PngFormatException(InvalidIhdr, dataOffset + 4, "IHDR height is invalid")
    }
    if (width > limits.maxWidth || height > limits.maxHeight) {
        throw PngFormatException(InvalidIhdr, dataOffset, "IHDR dimensions exceed configured limits")
    }

    let bitDepth = data[8]
    if (!validBitDepth(bitDepth)) {
        throw PngFormatException(InvalidIhdr, dataOffset + 8, "IHDR bit depth is invalid")
    }
    let colorType = parseColorType(data[9], dataOffset + 9)
    if (!validColorDepth(colorType, bitDepth)) {
        throw PngFormatException(InvalidIhdr, dataOffset + 8, "IHDR color type and bit depth are incompatible")
    }
    if (data[10] != UInt8(0)) {
        throw PngFormatException(InvalidIhdr, dataOffset + 10, "IHDR compression method is invalid")
    }
    if (data[11] != UInt8(0)) {
        throw PngFormatException(InvalidIhdr, dataOffset + 11, "IHDR filter method is invalid")
    }
    let interlaceMethod = parseInterlaceMethod(data[12], dataOffset + 12)

    PngIhdr(width, height, bitDepth, colorType, data[10], data[11], interlaceMethod)
}

public func parsePngIhdr(chunk: PngChunk): PngIhdr {
    parsePngIhdr(chunk, PngReadLimits())
}

public func readPngIhdr(bytes: Array<Byte>, limits: PngReadLimits): PngIhdr {
    PngReadSession(bytes, limits).readIhdr()
}

public func readPngIhdr(bytes: Array<Byte>): PngIhdr {
    PngReadSession(bytes).readIhdr()
}
