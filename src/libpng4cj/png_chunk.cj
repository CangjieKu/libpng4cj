package libpng4cj

public let PNG_CHUNK_IHDR: Array<Byte> = [0x49, 0x48, 0x44, 0x52]

public class PngReadLimits {
    public let maxChunkBytes: UInt32
    public let maxWidth: UInt32
    public let maxHeight: UInt32

    public init(maxChunkBytes: UInt32, maxWidth: UInt32, maxHeight: UInt32) {
        if (maxChunkBytes == UInt32(0) || maxChunkBytes > PNG_UINT_31_MAX) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "maximum chunk size must be in 1..PNG_UINT_31_MAX"
            )
        }
        if (maxWidth == UInt32(0) || maxWidth > PNG_UINT_31_MAX ||
            maxHeight == UInt32(0) || maxHeight > PNG_UINT_31_MAX) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "maximum image dimensions must be in 1..PNG_UINT_31_MAX"
            )
        }
        this.maxChunkBytes = maxChunkBytes
        this.maxWidth = maxWidth
        this.maxHeight = maxHeight
    }

    public init() {
        maxChunkBytes = UInt32(8_000_000)
        maxWidth = UInt32(1_000_000)
        maxHeight = UInt32(1_000_000)
    }
}

public class PngChunk {
    public let length: UInt32
    public let crc: UInt32
    public let offset: Int64
    private let ownedType: Array<Byte>
    private let ownedData: Array<Byte>

    init(
        length: UInt32,
        chunkType: Array<Byte>,
        data: Array<Byte>,
        crc: UInt32,
        offset: Int64
    ) {
        this.length = length
        this.ownedType = chunkType
        this.ownedData = data
        this.crc = crc
        this.offset = offset
    }

    public func chunkType(): Array<Byte> {
        ownedType.clone()
    }

    public func payload(): Array<Byte> {
        ownedData.clone()
    }

    public func isType(expected: Array<Byte>): Bool {
        sameBytes(ownedType, expected)
    }
}

public class PngReadSession {
    private let source: Array<Byte>
    private let limits: PngReadLimits
    private var cursor: Int64 = 0
    private var signatureRead: Bool = false
    private var ihdrRead: Bool = false
    private var chunkCount: Int64 = 0
    private var closed: Bool = false

    public init(bytes: Array<Byte>, limits: PngReadLimits) {
        source = bytes.clone()
        this.limits = limits
    }

    public init(bytes: Array<Byte>) {
        source = bytes.clone()
        limits = PngReadLimits()
    }

    public func position(): Int64 {
        cursor
    }

    public func remaining(): Int64 {
        source.size - cursor
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        closed = true
    }

    private func ensureOpen(): Unit {
        if (closed) {
            throw PngFormatException(SessionClosed, cursor, "PNG read session is closed")
        }
    }

    public func readSignature(): Unit {
        ensureOpen()
        if (signatureRead) {
            return
        }
        if (source.size < PNG_SIGNATURE.size) {
            throw PngFormatException(TruncatedInput, 0, "PNG signature is truncated")
        }
        let signature = copyByteRange(source, 0, PNG_SIGNATURE.size)
        if (!isPngSignature(signature)) {
            throw PngFormatException(InvalidSignature, 0, "input does not start with a PNG signature")
        }
        cursor = PNG_SIGNATURE.size
        signatureRead = true
    }

    public func readNextChunk(): PngChunk {
        ensureOpen()
        readSignature()
        let chunkOffset = cursor
        if (remaining() < 12) {
            throw PngFormatException(TruncatedInput, chunkOffset, "PNG chunk header or CRC is truncated")
        }

        let length = readUInt32Be(source, chunkOffset)
        if (length > PNG_UINT_31_MAX) {
            throw PngFormatException(InvalidChunkLength, chunkOffset, "PNG chunk length exceeds 31 bits")
        }
        if (length > limits.maxChunkBytes) {
            throw PngFormatException(ChunkTooLarge, chunkOffset, "PNG chunk exceeds configured memory limit")
        }

        let chunkType = copyByteRange(source, chunkOffset + 4, 4)
        if (!isValidChunkType(chunkType)) {
            throw PngFormatException(InvalidChunkType, chunkOffset + 4, "PNG chunk type is invalid")
        }

        let frameLength = Int64(length) + 12
        if (frameLength > remaining()) {
            throw PngFormatException(TruncatedInput, chunkOffset, "PNG chunk payload or CRC is truncated")
        }

        if (chunkCount == 0 && !sameBytes(chunkType, PNG_CHUNK_IHDR)) {
            throw PngFormatException(IhdrOutOfOrder, chunkOffset + 4, "IHDR must be the first PNG chunk")
        }
        if (sameBytes(chunkType, PNG_CHUNK_IHDR)) {
            if (ihdrRead) {
                throw PngFormatException(DuplicateIhdr, chunkOffset + 4, "PNG contains more than one IHDR chunk")
            }
            if (chunkCount != 0) {
                throw PngFormatException(IhdrOutOfOrder, chunkOffset + 4, "IHDR is not the first PNG chunk")
            }
        }

        let data = copyByteRange(source, chunkOffset + 8, Int64(length))
        let expectedCrc = readUInt32Be(source, chunkOffset + 8 + Int64(length))
        let actualCrc = pngChunkCrc32(chunkType, data)
        if (expectedCrc != actualCrc) {
            throw PngFormatException(CrcMismatch, chunkOffset + 8 + Int64(length), "PNG chunk CRC does not match")
        }

        cursor = chunkOffset + frameLength
        chunkCount += 1
        if (sameBytes(chunkType, PNG_CHUNK_IHDR)) {
            ihdrRead = true
        }
        PngChunk(length, chunkType, data, expectedCrc, chunkOffset)
    }

    public func readIhdr(): PngIhdr {
        ensureOpen()
        readSignature()
        if (remaining() == 0) {
            throw PngFormatException(MissingIhdr, cursor, "PNG does not contain an IHDR chunk")
        }
        let chunk = readNextChunk()
        parsePngIhdr(chunk, limits)
    }
}
