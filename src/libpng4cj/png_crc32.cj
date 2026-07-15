package libpng4cj

private let PNG_CRC_POLYNOMIAL: UInt32 = UInt32(0xedb88320)
private let PNG_CRC_INITIAL: UInt32 = UInt32(0xffff_ffff)

private func updateCrc32(crcValue: UInt32, bytes: Array<Byte>): UInt32 {
    var crc = crcValue
    var index = 0
    while (index < bytes.size) {
        crc = crc ^ UInt32(bytes[index])
        var bit = 0
        while (bit < 8) {
            if ((crc & UInt32(1)) == UInt32(1)) {
                crc = (crc >> 1) ^ PNG_CRC_POLYNOMIAL
            } else {
                crc = crc >> 1
            }
            bit += 1
        }
        index += 1
    }
    crc
}

public func pngCrc32(bytes: Array<Byte>): UInt32 {
    updateCrc32(PNG_CRC_INITIAL, bytes) ^ PNG_CRC_INITIAL
}

public func pngChunkCrc32(chunkType: Array<Byte>, data: Array<Byte>): UInt32 {
    if (!isValidChunkType(chunkType)) {
        throw PngFormatException("PNG chunk type must contain four ASCII letters")
    }
    let afterType = updateCrc32(PNG_CRC_INITIAL, chunkType)
    updateCrc32(afterType, data) ^ PNG_CRC_INITIAL
}
