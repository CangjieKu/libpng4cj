package libpng4cj

public let PNG_SIGNATURE: Array<Byte> = [
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a
]

public let PNG_UINT_31_MAX: UInt32 = UInt32(0x7fff_ffff)

func copyByteRange(bytes: Array<Byte>, offset: Int64, length: Int64): Array<Byte> {
    if (offset < 0 || offset > bytes.size || length < 0 || length > bytes.size - offset) {
        throw PngFormatException(
            InvalidArgument,
            offset,
            "byte range exceeds source bounds"
        )
    }
    let out = Array<Byte>(length, repeat: 0)
    var index: Int64 = 0
    while (index < length) {
        out[index] = bytes[offset + index]
        index += 1
    }
    out
}

func sameBytes(left: Array<Byte>, right: Array<Byte>): Bool {
    if (left.size != right.size) {
        return false
    }
    var index: Int64 = 0
    while (index < left.size) {
        if (left[index] != right[index]) {
            return false
        }
        index += 1
    }
    true
}

public func isPngSignature(bytes: Array<Byte>): Bool {
    if (bytes.size < PNG_SIGNATURE.size) {
        return false
    }
    var i = 0
    while (i < PNG_SIGNATURE.size) {
        if (bytes[i] != PNG_SIGNATURE[i]) {
            return false
        }
        i += 1
    }
    true
}

public func readUInt32Be(bytes: Array<Byte>, offset: Int64): UInt32 {
    if (offset < 0 || offset > bytes.size || bytes.size - offset < 4) {
        throw PngFormatException(
            TruncatedInput,
            offset,
            "not enough bytes for a big-endian UInt32"
        )
    }
    (UInt32(bytes[offset]) << 24) |
        (UInt32(bytes[offset + 1]) << 16) |
        (UInt32(bytes[offset + 2]) << 8) |
        UInt32(bytes[offset + 3])
}

public func writeUInt32Be(value: UInt32): Array<Byte> {
    [
        UInt8((value >> 24) & UInt32(0xff)),
        UInt8((value >> 16) & UInt32(0xff)),
        UInt8((value >> 8) & UInt32(0xff)),
        UInt8(value & UInt32(0xff))
    ]
}

public func isValidChunkType(chunkType: Array<Byte>): Bool {
    if (chunkType.size != 4) {
        return false
    }
    var i = 0
    while (i < chunkType.size) {
        let value = chunkType[i]
        let upper = value >= UInt8(0x41) && value <= UInt8(0x5a)
        let lower = value >= UInt8(0x61) && value <= UInt8(0x7a)
        if (!upper && !lower) {
            return false
        }
        i += 1
    }
    true
}

public func isCriticalChunk(chunkType: Array<Byte>): Bool {
    if (!isValidChunkType(chunkType)) {
        throw PngFormatException(
            InvalidChunkType,
            -1,
            "PNG chunk type must contain four ASCII letters"
        )
    }
    (chunkType[0] & UInt8(0x20)) == UInt8(0)
}
