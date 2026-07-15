package libpng4cj.tests

import libpng4cj.*

private let PALETTE_GRAY_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x90, 0x06, 0x00, 0x00, 0x1d, 0x00, 0x1c
]

private let GRAY1_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x88, 0x02, 0x00, 0x00, 0x5c, 0x00, 0x5b
]

private let INDEXED4_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x10, 0x02, 0x00, 0x00, 0x14, 0x00, 0x13
]

private let RGB8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0xe0, 0x12, 0x91, 0xd3, 0x30,
    0xb2, 0x01, 0x00, 0x02, 0x37, 0x00, 0xd3
]

private let GRAY_ALPHA8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0xe7, 0xe0, 0xe4, 0x02,
    0x00, 0x00, 0x55, 0x00, 0x23
]

private let RGBA8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private let GRAY16_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x10, 0x32, 0x01, 0x00, 0x00, 0x5b, 0x00, 0x47
]

private let GRAY16_TWO_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x10, 0x32, 0x59, 0x7d, 0x16,
    0x00, 0x03, 0x0c, 0x01, 0xbf
]

private let RGB16_TWO_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x13, 0x14, 0x12, 0x16, 0x11, 0x15, 0x03,
    0x00, 0x02, 0x4b, 0x00, 0x8b
]

private let GRAY_ALPHA16_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x10, 0x32, 0x09, 0xab, 0x00,
    0x00, 0x02, 0x0d, 0x01, 0x15
]

private let RGBA16_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private let REDUCE16_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0xf8, 0xff, 0x9f, 0x01,
    0x00, 0x05, 0x00, 0x01, 0xff
]

private func joinTransformBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
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

private func makeTransformChunk(chunkType: Array<Byte>, data: Array<Byte>): Array<Byte> {
    joinTransformBytes(
        joinTransformBytes(
            joinTransformBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makeTransformIhdr(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8,
    colorType: UInt8
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
    makeTransformChunk(PNG_CHUNK_IHDR, data)
}

private func makeTransformPng(chunks: Array<Array<Byte>>): Array<Byte> {
    var out = PNG_SIGNATURE.clone()
    var index: Int64 = 0
    while (index < chunks.size) {
        out = joinTransformBytes(out, chunks[index])
        index += 1
    }
    out
}

private func makeTransformImage(
    width: UInt32,
    bitDepth: UInt8,
    colorType: UInt8,
    beforeIdat: Array<Array<Byte>>,
    compressed: Array<Byte>
): Array<Byte> {
    var chunks = Array<Array<Byte>>(beforeIdat.size + 3, repeat: Array<Byte>())
    chunks[0] = makeTransformIhdr(width, UInt32(1), bitDepth, colorType)
    var index: Int64 = 0
    while (index < beforeIdat.size) {
        chunks[index + 1] = beforeIdat[index]
        index += 1
    }
    chunks[chunks.size - 2] = makeTransformChunk(PNG_CHUNK_IDAT, compressed)
    chunks[chunks.size - 1] = makeTransformChunk(PNG_CHUNK_IEND, [])
    makeTransformPng(chunks)
}

private func expectTransformError(bytes: Array<Byte>, expected: PngErrorKind): Unit {
    try {
        decodePngRgba8NonInterlaced(bytes)
        @Fail("expected RGBA8 PNG decode to fail")
    } catch (e: PngFormatException) {
        @Assert(e.kind.toString(), expected.toString())
    }
}

@Test
public class PngTransformTestSuite {
    @TestCase
    public func expandsPaletteTransparencyAndOwnsResults(): Unit {
        let palette: Array<Byte> = [
            0xff, 0x00, 0x00,
            0x00, 0xff, 0x00,
            0x00, 0x00, 0xff,
            0xff, 0xff, 0xff
        ]
        let alpha: Array<Byte> = [0x00, 0x80]
        let png = makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(3),
            [
                makeTransformChunk(PNG_CHUNK_PLTE, palette),
                makeTransformChunk(PNG_CHUNK_tRNS, alpha)
            ],
            PALETTE_GRAY_ZLIB
        )
        let decoded = decodePngRgba8NonInterlaced(png)
        let expected: Array<Byte> = [
            0xff, 0x00, 0x00, 0x00,
            0x00, 0xff, 0x00, 0x80,
            0x00, 0x00, 0xff, 0xff,
            0xff, 0xff, 0xff, 0xff
        ]
        let firstPaletteEntry: Array<Byte> = [0xff, 0x00, 0x00]
        @Assert(decoded.row(0), expected)
        @Assert(decoded.metadata.hasPalette, true)
        @Assert(decoded.metadata.hasTransparency, true)
        @Assert(decoded.metadata.paletteEntryCount(), Int64(4))
        @Assert(decoded.metadata.paletteEntry(0), firstPaletteEntry)
        @Assert(decoded.metadata.paletteAlphaAt(2), UInt8(0xff))

        let mutableRow = decoded.row(0)
        mutableRow[0] = UInt8(0)
        @Assert(decoded.row(0), expected)
        let mutablePalette = decoded.metadata.palette()
        mutablePalette[0] = UInt8(0)
        @Assert(decoded.metadata.paletteEntry(0), firstPaletteEntry)
    }

    @TestCase
    public func expandsSubByteGrayAndRgbColorKeys(): Unit {
        let grayTransparency: Array<Byte> = [0x00, 0x02]
        let grayPng = makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(0),
            [makeTransformChunk(PNG_CHUNK_tRNS, grayTransparency)],
            PALETTE_GRAY_ZLIB
        )
        let grayExpected: Array<Byte> = [
            0x00, 0x00, 0x00, 0xff,
            0x55, 0x55, 0x55, 0xff,
            0xaa, 0xaa, 0xaa, 0x00,
            0xff, 0xff, 0xff, 0xff
        ]
        @Assert(decodePngRgba8NonInterlaced(grayPng).row(0), grayExpected)

        let rgbTransparency: Array<Byte> = [0x00, 0x0a, 0x00, 0x14, 0x00, 0x1e]
        let rgbPng = makeTransformImage(
            UInt32(2),
            UInt8(8),
            UInt8(2),
            [makeTransformChunk(PNG_CHUNK_tRNS, rgbTransparency)],
            RGB8_ZLIB
        )
        let rgbExpected: Array<Byte> = [
            10, 20, 30, 0,
            40, 50, 60, 0xff
        ]
        @Assert(decodePngRgba8NonInterlaced(rgbPng).row(0), rgbExpected)
    }

    @TestCase
    public func unpacksOneAndFourBitSamples(): Unit {
        let gray1 = makeTransformImage(
            UInt32(8), UInt8(1), UInt8(0), [], GRAY1_ZLIB
        )
        let gray1Expected: Array<Byte> = [
            0x00, 0x00, 0x00, 0xff,
            0xff, 0xff, 0xff, 0xff,
            0x00, 0x00, 0x00, 0xff,
            0xff, 0xff, 0xff, 0xff,
            0xff, 0xff, 0xff, 0xff,
            0x00, 0x00, 0x00, 0xff,
            0xff, 0xff, 0xff, 0xff,
            0x00, 0x00, 0x00, 0xff
        ]
        @Assert(decodePngRgba8NonInterlaced(gray1).row(0), gray1Expected)

        let palette: Array<Byte> = [
            0x00, 0x00, 0x00,
            0xff, 0x00, 0x00,
            0x00, 0xff, 0x00
        ]
        let indexed4 = makeTransformImage(
            UInt32(2),
            UInt8(4),
            UInt8(3),
            [makeTransformChunk(PNG_CHUNK_PLTE, palette)],
            INDEXED4_ZLIB
        )
        let indexed4Expected: Array<Byte> = [
            0xff, 0x00, 0x00, 0xff,
            0x00, 0xff, 0x00, 0xff
        ]
        @Assert(decodePngRgba8NonInterlaced(indexed4).row(0), indexed4Expected)
    }

    @TestCase
    public func preservesExistingGrayAndTruecolorAlpha(): Unit {
        let grayAlphaPng = makeTransformImage(
            UInt32(2), UInt8(8), UInt8(4), [], GRAY_ALPHA8_ZLIB
        )
        let grayAlphaExpected: Array<Byte> = [7, 7, 7, 8, 9, 9, 9, 10]
        @Assert(decodePngRgba8NonInterlaced(grayAlphaPng).row(0), grayAlphaExpected)

        let rgbaPng = makeTransformImage(
            UInt32(2), UInt8(8), UInt8(6), [], RGBA8_ZLIB
        )
        let rgbaExpected: Array<Byte> = [1, 2, 3, 4, 5, 6, 7, 8]
        @Assert(decodePngRgba8NonInterlaced(rgbaPng).row(0), rgbaExpected)
    }

    @TestCase
    public func rejectsInvalidTransparencyAndPaletteIndexes(): Unit {
        let grayTransparency: Array<Byte> = [0x00, 0x02]
        let duplicateTransparency = makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(0),
            [
                makeTransformChunk(PNG_CHUNK_tRNS, grayTransparency),
                makeTransformChunk(PNG_CHUNK_tRNS, grayTransparency)
            ],
            PALETTE_GRAY_ZLIB
        )
        expectTransformError(duplicateTransparency, InvalidTransparency)

        let alphaColorTransparency = makeTransformImage(
            UInt32(2),
            UInt8(8),
            UInt8(6),
            [makeTransformChunk(PNG_CHUNK_tRNS, grayTransparency)],
            RGBA8_ZLIB
        )
        expectTransformError(alphaColorTransparency, InvalidTransparency)

        let invalidGrayLength = makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(0),
            [makeTransformChunk(PNG_CHUNK_tRNS, [0])],
            PALETTE_GRAY_ZLIB
        )
        expectTransformError(invalidGrayLength, InvalidTransparency)

        let indexedBeforePalette = makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(3),
            [
                makeTransformChunk(PNG_CHUNK_tRNS, [0]),
                makeTransformChunk(PNG_CHUNK_PLTE, [0, 0, 0])
            ],
            PALETTE_GRAY_ZLIB
        )
        expectTransformError(indexedBeforePalette, InvalidTransparency)

        let shortPalette: Array<Byte> = [0, 0, 0, 0xff, 0xff, 0xff]
        let tooManyAlpha = makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(3),
            [
                makeTransformChunk(PNG_CHUNK_PLTE, shortPalette),
                makeTransformChunk(PNG_CHUNK_tRNS, [0, 1, 2])
            ],
            PALETTE_GRAY_ZLIB
        )
        expectTransformError(tooManyAlpha, InvalidTransparency)

        let transparencyAfterIdat = makeTransformPng([
            makeTransformIhdr(UInt32(4), UInt32(1), UInt8(2), UInt8(0)),
            makeTransformChunk(PNG_CHUNK_IDAT, PALETTE_GRAY_ZLIB),
            makeTransformChunk(PNG_CHUNK_tRNS, grayTransparency),
            makeTransformChunk(PNG_CHUNK_IEND, [])
        ])
        expectTransformError(transparencyAfterIdat, InvalidTransparency)

        let outOfRangeIndex = makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(3),
            [makeTransformChunk(PNG_CHUNK_PLTE, shortPalette)],
            PALETTE_GRAY_ZLIB
        )
        expectTransformError(outOfRangeIndex, PaletteIndexOutOfRange)
    }

    @TestCase
    public func rejectsUndefined16BitReductionAndTransformedLimit(): Unit {
        let gray16 = makeTransformImage(
            UInt32(1), UInt8(16), UInt8(0), [], GRAY16_ZLIB
        )
        expectTransformError(gray16, UnsupportedTransform)

        let gray2 = makeTransformImage(
            UInt32(4), UInt8(2), UInt8(0), [], PALETTE_GRAY_ZLIB
        )
        try {
            decodePngRgba8NonInterlaced(
                gray2,
                PngReadLimits(
                    UInt32(1024),
                    UInt32(100),
                    UInt32(100),
                    UInt64(1024),
                    UInt64(1024),
                    UInt64(15)
                )
            )
            @Fail("transformed-byte limit should reject RGBA8 rows")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "DECODE_LIMIT_EXCEEDED")
        }
    }

    @TestCase
    public func preservesGrayAndRgb16Transparency(): Unit {
        let grayTransparency: Array<Byte> = [0x12, 0x34]
        let gray16 = makeTransformImage(
            UInt32(2),
            UInt8(16),
            UInt8(0),
            [makeTransformChunk(PNG_CHUNK_tRNS, grayTransparency)],
            GRAY16_TWO_ZLIB
        )
        let grayExpected: Array<UInt16> = [
            0x1234, 0x1234, 0x1234, 0x0000,
            0xabcd, 0xabcd, 0xabcd, 0xffff
        ]
        @Assert(decodePngRgba16NonInterlaced(gray16).row(0), grayExpected)

        let rgbTransparency: Array<Byte> = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06]
        let rgb16 = makeTransformImage(
            UInt32(2),
            UInt8(16),
            UInt8(2),
            [makeTransformChunk(PNG_CHUNK_tRNS, rgbTransparency)],
            RGB16_TWO_ZLIB
        )
        let rgbExpected: Array<UInt16> = [
            0x0102, 0x0304, 0x0506, 0x0000,
            0x1112, 0x1314, 0x1516, 0xffff
        ]
        @Assert(decodePngRgba16NonInterlaced(rgb16).row(0), rgbExpected)
    }

    @TestCase
    public func preservesGrayAlphaAndRgba16Ownership(): Unit {
        let grayAlpha16 = makeTransformImage(
            UInt32(1), UInt8(16), UInt8(4), [], GRAY_ALPHA16_ZLIB
        )
        let grayAlphaExpected: Array<UInt16> = [0x1234, 0x1234, 0x1234, 0x5678]
        @Assert(decodePngRgba16NonInterlaced(grayAlpha16).row(0), grayAlphaExpected)

        let rgba16 = makeTransformImage(
            UInt32(1), UInt8(16), UInt8(6), [], RGBA16_ZLIB
        )
        let rgbaExpected: Array<UInt16> = [0x0102, 0x0304, 0x0506, 0x0708]
        let decoded = decodePngRgba16NonInterlaced(rgba16)
        @Assert(decoded.row(0), rgbaExpected)
        let mutableRow = decoded.row(0)
        mutableRow[0] = UInt16(0)
        @Assert(decoded.row(0), rgbaExpected)
    }

    @TestCase
    public func expandsEightBitAndPaletteChannelsTo16(): Unit {
        let rgb8 = makeTransformImage(
            UInt32(2), UInt8(8), UInt8(2), [], RGB8_ZLIB
        )
        let rgbExpected: Array<UInt16> = [
            0x0a0a, 0x1414, 0x1e1e, 0xffff,
            0x2828, 0x3232, 0x3c3c, 0xffff
        ]
        @Assert(decodePngRgba16NonInterlaced(rgb8).row(0), rgbExpected)

        let palette: Array<Byte> = [
            0xff, 0x00, 0x00,
            0x00, 0xff, 0x00,
            0x00, 0x00, 0xff,
            0xff, 0xff, 0xff
        ]
        let alpha: Array<Byte> = [0x00, 0x80]
        let indexed = makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(3),
            [
                makeTransformChunk(PNG_CHUNK_PLTE, palette),
                makeTransformChunk(PNG_CHUNK_tRNS, alpha)
            ],
            PALETTE_GRAY_ZLIB
        )
        let paletteExpected: Array<UInt16> = [
            0xffff, 0x0000, 0x0000, 0x0000,
            0x0000, 0xffff, 0x0000, 0x8080,
            0x0000, 0x0000, 0xffff, 0xffff,
            0xffff, 0xffff, 0xffff, 0xffff
        ]
        @Assert(decodePngRgba16NonInterlaced(indexed).row(0), paletteExpected)
    }

    @TestCase
    public func appliesExplicitStripAndScale16To8(): Unit {
        let gray16 = makeTransformImage(
            UInt32(2), UInt8(16), UInt8(0), [], REDUCE16_ZLIB
        )
        let stripExpected: Array<Byte> = [
            0, 0, 0, 0xff,
            0xff, 0xff, 0xff, 0xff
        ]
        let scaleExpected: Array<Byte> = [
            1, 1, 1, 0xff,
            0xfe, 0xfe, 0xfe, 0xff
        ]
        @Assert(decodePngRgba8NonInterlaced(gray16, Strip).row(0), stripExpected)
        @Assert(decodePngRgba8NonInterlaced(gray16, Scale).row(0), scaleExpected)
    }

    @TestCase
    public func enforcesRgba16TransformedLimit(): Unit {
        let gray16 = makeTransformImage(
            UInt32(1), UInt8(16), UInt8(0), [], GRAY16_ZLIB
        )
        try {
            decodePngRgba16NonInterlaced(
                gray16,
                PngReadLimits(
                    UInt32(1024),
                    UInt32(100),
                    UInt32(100),
                    UInt64(1024),
                    UInt64(1024),
                    UInt64(7)
                )
            )
            @Fail("transformed-byte limit should reject RGBA16 rows")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "DECODE_LIMIT_EXCEEDED")
        }
    }
}
