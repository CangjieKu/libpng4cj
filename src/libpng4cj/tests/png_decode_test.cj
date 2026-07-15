package libpng4cj.tests

import libpng4cj.*

private let TEST_RGB_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0xe4, 0x12, 0x91, 0x03, 0x02, 0x26,
    0x56, 0x30, 0x00, 0x00, 0x06, 0x79, 0x00, 0xb8
]

private func joinDecodeBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: 0)
    var index: Int64 = 0
    while (index < left.size) {
        out[index] = left[index]
        index += 1
    }
    var rightIndex: Int64 = 0
    while (rightIndex < right.size) {
        out[left.size + rightIndex] = right[rightIndex]
        rightIndex += 1
    }
    out
}

private func decodeRange(bytes: Array<Byte>, offset: Int64, length: Int64): Array<Byte> {
    let out = Array<Byte>(length, repeat: 0)
    var index: Int64 = 0
    while (index < length) {
        out[index] = bytes[offset + index]
        index += 1
    }
    out
}

private func makeDecodeChunk(chunkType: Array<Byte>, data: Array<Byte>): Array<Byte> {
    joinDecodeBytes(
        joinDecodeBytes(
            joinDecodeBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makeDecodeIhdr(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8,
    colorType: UInt8,
    interlace: UInt8
): Array<Byte> {
    let data = Array<Byte>(13, repeat: 0)
    let widthBytes = writeUInt32Be(width)
    let heightBytes = writeUInt32Be(height)
    var index: Int64 = 0
    while (index < 4) {
        data[index] = widthBytes[index]
        data[index + 4] = heightBytes[index]
        index += 1
    }
    data[8] = bitDepth
    data[9] = colorType
    data[12] = interlace
    makeDecodeChunk(PNG_CHUNK_IHDR, data)
}

private func makeDecodePng(chunks: Array<Array<Byte>>): Array<Byte> {
    var out = PNG_SIGNATURE.clone()
    var index: Int64 = 0
    while (index < chunks.size) {
        out = joinDecodeBytes(out, chunks[index])
        index += 1
    }
    out
}

private func expectDecodeError(bytes: Array<Byte>, expected: PngErrorKind): Unit {
    try {
        decodePngNonInterlaced(bytes)
        @Fail("expected non-interlaced PNG decode to fail")
    } catch (e: PngFormatException) {
        @Assert(e.kind.toString(), expected.toString())
    }
}

@Test
public class PngDecodeTestSuite {
    @TestCase
    public func inflatesExactZlibStream(): Unit {
        let compressed: Array<Byte> = [
            0x78, 0x9c, 0xcb, 0x48, 0xcd, 0xc9, 0xc9,
            0x07, 0x00, 0x06, 0x2c, 0x02, 0x15
        ]
        let expected: Array<Byte> = [0x68, 0x65, 0x6c, 0x6c, 0x6f]
        @Assert(inflatePngZlibExact(compressed, 5), expected)
    }

    @TestCase
    public func reversesAllPngRowFilters(): Unit {
        let zeros3: Array<Byte> = [0, 0, 0]
        let noneInput: Array<Byte> = [1, 2, 3]
        let noneExpected: Array<Byte> = [1, 2, 3]
        let subInput: Array<Byte> = [10, 20, 30, 30, 30, 30]
        let subPrevious: Array<Byte> = [0, 0, 0, 0, 0, 0]
        let subExpected: Array<Byte> = [10, 20, 30, 40, 50, 60]
        let upInput: Array<Byte> = [5, 5, 5, 5, 5, 5]
        let upPrevious: Array<Byte> = [10, 20, 30, 40, 50, 60]
        let upExpected: Array<Byte> = [15, 25, 35, 45, 55, 65]
        let averageInput: Array<Byte> = [15, 20, 25]
        let averagePrevious: Array<Byte> = [10, 20, 30]
        let averageExpected: Array<Byte> = [20, 40, 60]
        let paethInput: Array<Byte> = [5, 5, 10]
        let paethPrevious: Array<Byte> = [10, 20, 30]
        let paethExpected: Array<Byte> = [15, 25, 40]
        @Assert(
            unfilterPngRow(PNG_FILTER_NONE, noneInput, zeros3, 1),
            noneExpected
        )
        @Assert(
            unfilterPngRow(PNG_FILTER_SUB, subInput, subPrevious, 3),
            subExpected
        )
        @Assert(
            unfilterPngRow(PNG_FILTER_UP, upInput, upPrevious, 3),
            upExpected
        )
        @Assert(
            unfilterPngRow(PNG_FILTER_AVERAGE, averageInput, averagePrevious, 1),
            averageExpected
        )
        @Assert(
            unfilterPngRow(PNG_FILTER_PAETH, paethInput, paethPrevious, 1),
            paethExpected
        )
    }

    @TestCase
    public func decodesSplitIdatRgbRows(): Unit {
        let firstIdat = makeDecodeChunk(PNG_CHUNK_IDAT, decodeRange(TEST_RGB_ZLIB, 0, 8))
        let secondIdat = makeDecodeChunk(PNG_CHUNK_IDAT, decodeRange(TEST_RGB_ZLIB, 8, 9))
        let png = makeDecodePng([
            makeDecodeIhdr(UInt32(2), UInt32(2), UInt8(8), UInt8(2), UInt8(0)),
            firstIdat,
            secondIdat,
            makeDecodeChunk(PNG_CHUNK_IEND, [])
        ])
        let decoded = decodePngNonInterlaced(png)
        let firstExpected: Array<Byte> = [10, 20, 30, 40, 50, 60]
        let secondExpected: Array<Byte> = [15, 25, 35, 45, 55, 65]
        @Assert(decoded.rowCount(), Int64(2))
        @Assert(decoded.row(0), firstExpected)
        @Assert(decoded.row(1), secondExpected)
        let mutableRow = decoded.row(0)
        mutableRow[0] = UInt8(0xff)
        @Assert(decoded.row(0), firstExpected)
    }

    @TestCase
    public func decodesPackedIndexedRowWithPalette(): Unit {
        let indexedZlib: Array<Byte> = [
            0x78, 0x9c, 0x63, 0x58, 0x05, 0x00, 0x00, 0xac, 0x00, 0xab
        ]
        let palette: Array<Byte> = [0, 0, 0, 0xff, 0xff, 0xff]
        let png = makeDecodePng([
            makeDecodeIhdr(UInt32(8), UInt32(1), UInt8(1), UInt8(3), UInt8(0)),
            makeDecodeChunk(PNG_CHUNK_PLTE, palette),
            makeDecodeChunk(PNG_CHUNK_IDAT, indexedZlib),
            makeDecodeChunk(PNG_CHUNK_IEND, [])
        ])
        let expected: Array<Byte> = [0xaa]
        @Assert(decodePngNonInterlaced(png).row(0), expected)
    }

    @TestCase
    public func rejectsCorruptShortOversizedAndTrailingZlibData(): Unit {
        let corrupt = TEST_RGB_ZLIB.clone()
        corrupt[5] = corrupt[5] ^ UInt8(0x40)
        expectDecodeError(
            makeDecodePng([
                makeDecodeIhdr(UInt32(2), UInt32(2), UInt8(8), UInt8(2), UInt8(0)),
                makeDecodeChunk(PNG_CHUNK_IDAT, corrupt),
                makeDecodeChunk(PNG_CHUNK_IEND, [])
            ]),
            ZlibFailure
        )

        expectDecodeError(
            makeDecodePng([
                makeDecodeIhdr(UInt32(2), UInt32(3), UInt8(8), UInt8(2), UInt8(0)),
                makeDecodeChunk(PNG_CHUNK_IDAT, TEST_RGB_ZLIB),
                makeDecodeChunk(PNG_CHUNK_IEND, [])
            ]),
            InflatedSizeMismatch
        )

        expectDecodeError(
            makeDecodePng([
                makeDecodeIhdr(UInt32(1), UInt32(1), UInt8(8), UInt8(2), UInt8(0)),
                makeDecodeChunk(PNG_CHUNK_IDAT, TEST_RGB_ZLIB),
                makeDecodeChunk(PNG_CHUNK_IEND, [])
            ]),
            InflatedSizeMismatch
        )

        let trailing = joinDecodeBytes(TEST_RGB_ZLIB, [0])
        expectDecodeError(
            makeDecodePng([
                makeDecodeIhdr(UInt32(2), UInt32(2), UInt8(8), UInt8(2), UInt8(0)),
                makeDecodeChunk(PNG_CHUNK_IDAT, trailing),
                makeDecodeChunk(PNG_CHUNK_IEND, [])
            ]),
            TrailingCompressedData
        )
    }

    @TestCase
    public func enforcesIdatAndIendOrdering(): Unit {
        let textType: Array<Byte> = [0x74, 0x45, 0x58, 0x74]
        expectDecodeError(
            makeDecodePng([
                makeDecodeIhdr(UInt32(2), UInt32(2), UInt8(8), UInt8(2), UInt8(0)),
                makeDecodeChunk(PNG_CHUNK_IDAT, decodeRange(TEST_RGB_ZLIB, 0, 8)),
                makeDecodeChunk(textType, [0, 1]),
                makeDecodeChunk(PNG_CHUNK_IDAT, decodeRange(TEST_RGB_ZLIB, 8, 9)),
                makeDecodeChunk(PNG_CHUNK_IEND, [])
            ]),
            NonConsecutiveIdat
        )

        expectDecodeError(
            makeDecodePng([
                makeDecodeIhdr(UInt32(2), UInt32(2), UInt8(8), UInt8(2), UInt8(0)),
                makeDecodeChunk(PNG_CHUNK_IDAT, TEST_RGB_ZLIB)
            ]),
            MissingIend
        )

        expectDecodeError(
            makeDecodePng([
                makeDecodeIhdr(UInt32(1), UInt32(1), UInt8(8), UInt8(2), UInt8(0)),
                makeDecodeChunk(PNG_CHUNK_IEND, [])
            ]),
            MissingIdat
        )

        expectDecodeError(
            makeDecodePng([
                makeDecodeIhdr(UInt32(2), UInt32(2), UInt8(8), UInt8(2), UInt8(0)),
                makeDecodeChunk(PNG_CHUNK_IDAT, TEST_RGB_ZLIB),
                makeDecodeChunk(PNG_CHUNK_IEND, [0])
            ]),
            InvalidIend
        )
    }

    @TestCase
    public func rejectsUnsupportedCriticalPaletteInterlaceAndTrailingData(): Unit {
        let unknownCritical: Array<Byte> = [0x41, 0x42, 0x43, 0x44]
        expectDecodeError(
            makeDecodePng([
                makeDecodeIhdr(UInt32(2), UInt32(2), UInt8(8), UInt8(2), UInt8(0)),
                makeDecodeChunk(unknownCritical, []),
                makeDecodeChunk(PNG_CHUNK_IDAT, TEST_RGB_ZLIB),
                makeDecodeChunk(PNG_CHUNK_IEND, [])
            ]),
            UnsupportedCriticalChunk
        )

        expectDecodeError(
            makeDecodePng([
                makeDecodeIhdr(UInt32(8), UInt32(1), UInt8(1), UInt8(3), UInt8(0)),
                makeDecodeChunk(PNG_CHUNK_IDAT, [1, 2, 3]),
                makeDecodeChunk(PNG_CHUNK_IEND, [])
            ]),
            InvalidPalette
        )

        expectDecodeError(
            makeDecodePng([
                makeDecodeIhdr(UInt32(2), UInt32(2), UInt8(8), UInt8(2), UInt8(1)),
                makeDecodeChunk(PNG_CHUNK_IDAT, TEST_RGB_ZLIB),
                makeDecodeChunk(PNG_CHUNK_IEND, [])
            ]),
            UnsupportedInterlace
        )

        let valid = makeDecodePng([
            makeDecodeIhdr(UInt32(2), UInt32(2), UInt8(8), UInt8(2), UInt8(0)),
            makeDecodeChunk(PNG_CHUNK_IDAT, TEST_RGB_ZLIB),
            makeDecodeChunk(PNG_CHUNK_IEND, [])
        ])
        expectDecodeError(joinDecodeBytes(valid, [0]), TrailingData)
    }

    @TestCase
    public func enforcesCompressedAndInflatedLimitsAndFilterValue(): Unit {
        let png = makeDecodePng([
            makeDecodeIhdr(UInt32(2), UInt32(2), UInt8(8), UInt8(2), UInt8(0)),
            makeDecodeChunk(PNG_CHUNK_IDAT, TEST_RGB_ZLIB),
            makeDecodeChunk(PNG_CHUNK_IEND, [])
        ])
        try {
            decodePngNonInterlaced(
                png,
                PngReadLimits(UInt32(1024), UInt32(100), UInt32(100), UInt64(16), UInt64(1024))
            )
            @Fail("compressed limit should reject IDAT")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "DECODE_LIMIT_EXCEEDED")
        }
        try {
            decodePngNonInterlaced(
                png,
                PngReadLimits(UInt32(1024), UInt32(100), UInt32(100), UInt64(1024), UInt64(13))
            )
            @Fail("inflated limit should reject row allocation")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "DECODE_LIMIT_EXCEEDED")
        }
        try {
            unfilterPngRow(UInt8(5), [1], [0], 1)
            @Fail("invalid filter value should fail")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_FILTER")
        }
    }
}
