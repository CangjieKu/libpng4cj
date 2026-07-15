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

    @TestCase
    public func classifiesPaletteTransparencyDuringReadInitialization(): Unit {
        let palette: Array<Byte> = [
            0xff, 0x00, 0x00,
            0x00, 0xff, 0x00,
            0x00, 0x00, 0xff,
            0xff, 0xff, 0xff
        ]

        let opaque = decodePngNonInterlaced(makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(3),
            [
                makeTransformChunk(PNG_CHUNK_PLTE, palette),
                makeTransformChunk(PNG_CHUNK_tRNS, [0xff, 0xff])
            ],
            PALETTE_GRAY_ZLIB
        ))
        let opaqueState = PngReadTransformState()
        @Assert(opaqueState.setTransparencyToAlpha(), true)
        let opaqueInit = initializePngReadTransformations(opaqueState, opaque)
        @Assert(opaqueInit.usesPaletteInitializer, true)
        @Assert(opaqueInit.sourceHasTransparency, true)
        @Assert(opaqueInit.inputHasTransparency, false)
        @Assert(opaqueInit.inputHasAlpha, false)
        @Assert(opaqueInit.effectiveOutputHasAlpha, false)

        let binary = decodePngNonInterlaced(makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(3),
            [
                makeTransformChunk(PNG_CHUNK_PLTE, palette),
                makeTransformChunk(PNG_CHUNK_tRNS, [0x00, 0xff])
            ],
            PALETTE_GRAY_ZLIB
        ))
        let binaryState = PngReadTransformState()
        @Assert(binaryState.setTransparencyToAlpha(), true)
        let binaryInit = initializePngReadTransformations(binaryState, binary)
        @Assert(binaryInit.inputHasTransparency, true)
        @Assert(binaryInit.inputHasAlpha, false)
        @Assert(binaryInit.effectiveOutputHasAlpha, true)

        let partial = decodePngNonInterlaced(makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(3),
            [
                makeTransformChunk(PNG_CHUNK_PLTE, palette),
                makeTransformChunk(PNG_CHUNK_tRNS, [0x80])
            ],
            PALETTE_GRAY_ZLIB
        ))
        let partialState = PngReadTransformState()
        @Assert(partialState.setTransparencyToAlpha(), true)
        let partialInit = initializePngReadTransformations(partialState, partial)
        @Assert(partialInit.inputHasTransparency, true)
        @Assert(partialInit.inputHasAlpha, true)
        @Assert(partialInit.effectiveOutputHasAlpha, true)
    }

    @TestCase
    public func stripsEffectiveTrnsButRetainsInherentInputAlphaClassification(): Unit {
        let rgbTransparency: Array<Byte> = [0x00, 0x0a, 0x00, 0x14, 0x00, 0x1e]
        let rgb = decodePngNonInterlaced(makeTransformImage(
            UInt32(2),
            UInt8(8),
            UInt8(2),
            [makeTransformChunk(PNG_CHUNK_tRNS, rgbTransparency)],
            RGB8_ZLIB
        ))
        let rgbState = PngReadTransformState()
        @Assert(rgbState.setTransparencyToAlpha(), true)
        @Assert(rgbState.setStripAlpha(), true)
        let rgbInit = initializePngReadTransformations(rgbState, rgb)
        @Assert(rgbInit.usesPaletteInitializer, false)
        @Assert(rgbInit.sourceHasTransparency, true)
        @Assert(rgbInit.transparencyStripped, true)
        @Assert(rgbInit.inputHasTransparency, false)
        @Assert(rgbInit.inputHasAlpha, false)
        @Assert(rgbInit.effectiveTransparencyExpansion, false)
        @Assert(rgbInit.effectiveOutputHasAlpha, false)

        let rgba = decodePngNonInterlaced(makeTransformImage(
            UInt32(2), UInt8(8), UInt8(6), [], RGBA8_ZLIB
        ))
        let rgbaState = PngReadTransformState()
        @Assert(rgbaState.setStripAlpha(), true)
        let rgbaInit = initializePngReadTransformations(rgbaState, rgba)
        @Assert(rgbaInit.sourceHasTransparency, false)
        @Assert(rgbaInit.inputHasTransparency, false)
        @Assert(rgbaInit.inputHasAlpha, true)
        @Assert(rgbaInit.effectiveOutputHasAlpha, false)
    }

    @TestCase
    public func freezesTranslatedReadStageOrderAndOneShotLifecycle(): Unit {
        let decoded = decodePngNonInterlaced(makeTransformImage(
            UInt32(2), UInt8(16), UInt8(2), [], RGB16_TWO_ZLIB
        ))
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(state.setExpand(), true)
        @Assert(state.setStripAlpha(), true)
        @Assert(
            state.setRgbToGrayFixed(Convert, UInt32(21268), UInt32(71514)),
            true
        )
        @Assert(state.setGrayToRgb(), true)
        @Assert(state.setScale16(), true)
        @Assert(state.setStrip16(), true)
        @Assert(state.setExpand16(), true)

        let initialized = initializePngReadTransformations(state, decoded)
        let expectedStages: Array<String> = [
            "EXPAND",
            "STRIP_ALPHA",
            "RGB_TO_GRAY",
            "GRAY_TO_RGB",
            "SCALE_16_TO_8",
            "STRIP_16_TO_8",
            "EXPAND_16"
        ]
        @Assert(initialized.stageCount(), Int64(expectedStages.size))
        var index: Int64 = 0
        while (index < expectedStages.size) {
            @Assert(initialized.stage(index).toString(), expectedStages[index])
            index += 1
        }
        let mutableStages = initialized.stages()
        mutableStages[0] = ReadStageExpand16
        @Assert(initialized.stage(0).toString(), "EXPAND")
        @Assert(state.rowInitialized(), true)
        @Assert(state.sixteenToEightMode().toString(), "SCALE")
        @Assert(state.setExpand(), false)
        @Assert(
            state.lastApplicationError().toString(),
            "INVALID_AFTER_ROW_INITIALIZATION"
        )

        try {
            initializePngReadTransformations(state, decoded)
            @Fail("read transform initialization should be one-shot")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func translatesEightBitGrayToRgbRowBodies(): Unit {
        let grayInfo = PngReadRowInfo(UInt32(3), UInt8(8), Grayscale)
        let gray = pngDoGrayToRgb(grayInfo, [0x00, 0x7f, 0xff])
        let expectedGray: Array<Byte> = [
            0x00, 0x00, 0x00,
            0x7f, 0x7f, 0x7f,
            0xff, 0xff, 0xff
        ]
        @Assert(gray.row(), expectedGray)
        @Assert(gray.info.colorType.toString(), "TRUECOLOR")
        @Assert(gray.info.channels, UInt8(3))
        @Assert(gray.info.pixelDepth, UInt16(24))
        @Assert(gray.info.rowBytes, UInt64(9))

        let grayAlphaInfo = PngReadRowInfo(UInt32(2), UInt8(8), GrayscaleAlpha)
        let grayAlpha = pngDoGrayToRgb(grayAlphaInfo, [7, 8, 9, 10])
        let expectedGrayAlpha: Array<Byte> = [7, 7, 7, 8, 9, 9, 9, 10]
        @Assert(grayAlpha.row(), expectedGrayAlpha)
        @Assert(grayAlpha.info.colorType.toString(), "TRUECOLOR_ALPHA")
        @Assert(grayAlpha.info.channels, UInt8(4))
        @Assert(grayAlpha.info.pixelDepth, UInt16(32))
        @Assert(grayAlpha.info.rowBytes, UInt64(8))

        let mutable = grayAlpha.row()
        mutable[0] = UInt8(0)
        @Assert(grayAlpha.row(), expectedGrayAlpha)
    }

    @TestCase
    public func translatesSixteenBitGrayToRgbRowBodies(): Unit {
        let grayInfo = PngReadRowInfo(UInt32(2), UInt8(16), Grayscale)
        let gray = pngDoGrayToRgb(grayInfo, [0x12, 0x34, 0xab, 0xcd])
        let expectedGray: Array<Byte> = [
            0x12, 0x34, 0x12, 0x34, 0x12, 0x34,
            0xab, 0xcd, 0xab, 0xcd, 0xab, 0xcd
        ]
        @Assert(gray.row(), expectedGray)
        @Assert(gray.info.colorType.toString(), "TRUECOLOR")
        @Assert(gray.info.pixelDepth, UInt16(48))
        @Assert(gray.info.rowBytes, UInt64(12))

        let grayAlphaInfo = PngReadRowInfo(UInt32(1), UInt8(16), GrayscaleAlpha)
        let grayAlpha = pngDoGrayToRgb(grayAlphaInfo, [0x12, 0x34, 0x56, 0x78])
        let expectedGrayAlpha: Array<Byte> = [
            0x12, 0x34, 0x12, 0x34, 0x12, 0x34, 0x56, 0x78
        ]
        @Assert(grayAlpha.row(), expectedGrayAlpha)
        @Assert(grayAlpha.info.colorType.toString(), "TRUECOLOR_ALPHA")
        @Assert(grayAlpha.info.pixelDepth, UInt16(64))
        @Assert(grayAlpha.info.rowBytes, UInt64(8))
    }

    @TestCase
    public func gatesDirectAndInitializedGrayToRgbStages(): Unit {
        let packedInfo = PngReadRowInfo(UInt32(4), UInt8(2), Grayscale)
        let packed = pngDoGrayToRgb(packedInfo, [0x1b])
        let packedExpected: Array<Byte> = [0x1b]
        @Assert(packed.row(), packedExpected)
        @Assert(packed.info.colorType.toString(), "GRAYSCALE")
        @Assert(packed.info.rowBytes, UInt64(1))

        let colorInfo = PngReadRowInfo(UInt32(1), UInt8(8), Truecolor)
        let color = pngDoGrayToRgb(colorInfo, [1, 2, 3])
        let colorExpected: Array<Byte> = [1, 2, 3]
        @Assert(color.row(), colorExpected)
        @Assert(color.info.colorType.toString(), "TRUECOLOR")

        try {
            pngDoGrayToRgb(PngReadRowInfo(UInt32(2), UInt8(8), Grayscale), [1])
            @Fail("gray-to-RGB should reject a row length mismatch")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }

        let decoded = decodePngNonInterlaced(makeTransformImage(
            UInt32(2), UInt8(8), UInt8(4), [], GRAY_ALPHA8_ZLIB
        ))
        let disabledState = PngReadTransformState()
        let disabled = initializePngReadTransformations(disabledState, decoded)
        let unchanged = applyInitializedPngGrayToRgbStage(
            disabled,
            PngReadRowInfo(decoded.ihdr),
            decoded.row(0)
        )
        let unchangedExpected: Array<Byte> = [7, 8, 9, 10]
        @Assert(unchanged.row(), unchangedExpected)
        @Assert(unchanged.info.colorType.toString(), "GRAYSCALE_ALPHA")

        let enabledState = PngReadTransformState()
        @Assert(enabledState.setGrayToRgb(), true)
        let enabled = initializePngReadTransformations(enabledState, decoded)
        let transformed = applyInitializedPngGrayToRgbStage(
            enabled,
            PngReadRowInfo(decoded.ihdr),
            decoded.row(0)
        )
        let transformedExpected: Array<Byte> = [7, 7, 7, 8, 9, 9, 9, 10]
        @Assert(transformed.row(), transformedExpected)
        @Assert(transformed.info.colorType.toString(), "TRUECOLOR_ALPHA")
    }

    @TestCase
    public func projectsPaletteExpandInfoFromRetainedTrnsCount(): Unit {
        let palette: Array<Byte> = [
            0xff, 0x00, 0x00,
            0x00, 0xff, 0x00,
            0x00, 0x00, 0xff,
            0xff, 0xff, 0xff
        ]
        let opaque = decodePngNonInterlaced(makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(3),
            [
                makeTransformChunk(PNG_CHUNK_PLTE, palette),
                makeTransformChunk(PNG_CHUNK_tRNS, [0xff, 0xff])
            ],
            PALETTE_GRAY_ZLIB
        ))
        let opaqueState = PngReadTransformState()
        @Assert(opaqueState.setExpand(), true)
        let opaqueInit = initializePngReadTransformations(opaqueState, opaque)
        let opaqueInfo = projectPngReadTransformInfo(opaqueInit, opaque)
        @Assert(opaqueInit.inputHasTransparency, false)
        @Assert(opaqueInfo.colorType.toString(), "TRUECOLOR_ALPHA")
        @Assert(opaqueInfo.bitDepth, UInt8(8))
        @Assert(opaqueInfo.channels, UInt8(4))
        @Assert(opaqueInfo.pixelDepth, UInt16(32))
        @Assert(opaqueInfo.rowBytes, UInt64(16))
        @Assert(opaqueInfo.hasTransparency, false)

        let plain = decodePngNonInterlaced(makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(3),
            [makeTransformChunk(PNG_CHUNK_PLTE, palette)],
            PALETTE_GRAY_ZLIB
        ))
        let plainState = PngReadTransformState()
        @Assert(plainState.setExpand(), true)
        let plainInfo = projectPngReadTransformInfo(
            initializePngReadTransformations(plainState, plain),
            plain
        )
        @Assert(plainInfo.colorType.toString(), "TRUECOLOR")
        @Assert(plainInfo.rowBytes, UInt64(12))

        let stripState = PngReadTransformState()
        @Assert(stripState.setExpand(), true)
        @Assert(stripState.setStripAlpha(), true)
        let strippedInfo = projectPngReadTransformInfo(
            initializePngReadTransformations(stripState, opaque),
            opaque
        )
        @Assert(strippedInfo.colorType.toString(), "TRUECOLOR")
        @Assert(strippedInfo.rowBytes, UInt64(12))
        @Assert(strippedInfo.hasTransparency, false)
    }

    @TestCase
    public func projectsSubByteAndTrnsExpandInfo(): Unit {
        let grayTransparency: Array<Byte> = [0x00, 0x02]
        let gray = decodePngNonInterlaced(makeTransformImage(
            UInt32(4),
            UInt8(2),
            UInt8(0),
            [makeTransformChunk(PNG_CHUNK_tRNS, grayTransparency)],
            PALETTE_GRAY_ZLIB
        ))
        let depthOnlyState = PngReadTransformState()
        @Assert(depthOnlyState.setExpandGrayOneTwoFourToEight(), true)
        let depthOnly = projectPngReadTransformInfo(
            initializePngReadTransformations(depthOnlyState, gray),
            gray
        )
        @Assert(depthOnly.colorType.toString(), "GRAYSCALE")
        @Assert(depthOnly.bitDepth, UInt8(8))
        @Assert(depthOnly.rowBytes, UInt64(4))
        @Assert(depthOnly.hasTransparency, false)

        let alphaState = PngReadTransformState()
        @Assert(alphaState.setTransparencyToAlpha(), true)
        let alpha = projectPngReadTransformInfo(
            initializePngReadTransformations(alphaState, gray),
            gray
        )
        @Assert(alpha.colorType.toString(), "GRAYSCALE_ALPHA")
        @Assert(alpha.bitDepth, UInt8(8))
        @Assert(alpha.channels, UInt8(2))
        @Assert(alpha.rowBytes, UInt64(8))
        @Assert(alpha.hasTransparency, false)
    }

    @TestCase
    public func projectsAlphaAndBitDepthStages(): Unit {
        let grayAlpha = decodePngNonInterlaced(makeTransformImage(
            UInt32(1), UInt8(16), UInt8(4), [], GRAY_ALPHA16_ZLIB
        ))
        let stripAlphaState = PngReadTransformState()
        @Assert(stripAlphaState.setStripAlpha(), true)
        let stripAlpha = projectPngReadTransformInfo(
            initializePngReadTransformations(stripAlphaState, grayAlpha),
            grayAlpha
        )
        @Assert(stripAlpha.colorType.toString(), "GRAYSCALE")
        @Assert(stripAlpha.bitDepth, UInt8(16))
        @Assert(stripAlpha.channels, UInt8(1))
        @Assert(stripAlpha.rowBytes, UInt64(2))

        let scaleState = PngReadTransformState()
        @Assert(scaleState.setScale16(), true)
        let scale = projectPngReadTransformInfo(
            initializePngReadTransformations(scaleState, grayAlpha),
            grayAlpha
        )
        @Assert(scale.colorType.toString(), "GRAYSCALE_ALPHA")
        @Assert(scale.bitDepth, UInt8(8))
        @Assert(scale.rowBytes, UInt64(2))

        let roundTripState = PngReadTransformState()
        @Assert(roundTripState.setScale16(), true)
        @Assert(roundTripState.setStrip16(), true)
        @Assert(roundTripState.setExpand16(), true)
        let roundTrip = projectPngReadTransformInfo(
            initializePngReadTransformations(roundTripState, grayAlpha),
            grayAlpha
        )
        @Assert(roundTrip.bitDepth, UInt8(16))
        @Assert(roundTrip.pixelDepth, UInt16(32))
        @Assert(roundTrip.rowBytes, UInt64(4))
    }

    @TestCase
    public func preservesTransformInfoRgbGrayProjectionOrder(): Unit {
        let rgb = decodePngNonInterlaced(makeTransformImage(
            UInt32(2), UInt8(8), UInt8(2), [], RGB8_ZLIB
        ))
        let bothState = PngReadTransformState()
        bothState.markIhdrRead(rgb.ihdr)
        @Assert(
            bothState.setRgbToGrayFixed(Convert, UInt32(21268), UInt32(71514)),
            true
        )
        @Assert(bothState.setGrayToRgb(), true)
        let bothInit = initializePngReadTransformations(bothState, rgb)
        @Assert(bothInit.hasStage(ReadStageRgbToGray), true)
        @Assert(bothInit.hasStage(ReadStageGrayToRgb), true)
        let both = projectPngReadTransformInfo(bothInit, rgb)
        @Assert(both.colorType.toString(), "GRAYSCALE")
        @Assert(both.channels, UInt8(1))
        @Assert(both.pixelDepth, UInt16(8))
        @Assert(both.rowBytes, UInt64(2))

        let gray = decodePngNonInterlaced(makeTransformImage(
            UInt32(2), UInt8(8), UInt8(4), [], GRAY_ALPHA8_ZLIB
        ))
        let grayToRgbState = PngReadTransformState()
        @Assert(grayToRgbState.setGrayToRgb(), true)
        let grayToRgb = projectPngReadTransformInfo(
            initializePngReadTransformations(grayToRgbState, gray),
            gray
        )
        @Assert(grayToRgb.colorType.toString(), "TRUECOLOR_ALPHA")
        @Assert(grayToRgb.channels, UInt8(4))
        @Assert(grayToRgb.rowBytes, UInt64(8))
    }

    @TestCase
    public func scalesDirectSixteenBitRowsAcrossChannelTopologies(): Unit {
        let grayInput: Array<Byte> = [
            0x00, 0x00, 0x00, 0xff, 0xff, 0x00, 0xff, 0xff
        ]
        let gray = pngDoScale16To8(
            PngReadRowInfo(UInt32(4), UInt8(16), Grayscale), grayInput
        )
        let grayExpected: Array<Byte> = [0x00, 0x01, 0xfe, 0xff]
        @Assert(gray.row(), grayExpected)
        @Assert(gray.info.width, UInt32(4))
        @Assert(gray.info.bitDepth, UInt8(8))
        @Assert(gray.info.colorType.toString(), "GRAYSCALE")
        @Assert(gray.info.channels, UInt8(1))
        @Assert(gray.info.pixelDepth, UInt16(8))
        @Assert(gray.info.rowBytes, UInt64(4))

        let grayAlphaInput: Array<Byte> = [0x00, 0x80, 0x00, 0x81]
        let grayAlpha = pngDoScale16To8(
            PngReadRowInfo(UInt32(1), UInt8(16), GrayscaleAlpha),
            grayAlphaInput
        )
        let grayAlphaExpected: Array<Byte> = [0x00, 0x01]
        @Assert(grayAlpha.row(), grayAlphaExpected)
        @Assert(grayAlpha.info.channels, UInt8(2))
        @Assert(grayAlpha.info.pixelDepth, UInt16(16))
        @Assert(grayAlpha.info.rowBytes, UInt64(2))

        let rgbInput: Array<Byte> = [0x00, 0xff, 0xff, 0x00, 0xff, 0xff]
        let rgb = pngDoScale16To8(
            PngReadRowInfo(UInt32(1), UInt8(16), Truecolor), rgbInput
        )
        let rgbExpected: Array<Byte> = [0x01, 0xfe, 0xff]
        @Assert(rgb.row(), rgbExpected)
        @Assert(rgb.info.channels, UInt8(3))
        @Assert(rgb.info.pixelDepth, UInt16(24))
        @Assert(rgb.info.rowBytes, UInt64(3))

        let rgbaInput: Array<Byte> = [
            0x00, 0x00, 0x00, 0xff, 0xff, 0x00, 0xff, 0xff
        ]
        let rgba = pngDoScale16To8(
            PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha), rgbaInput
        )
        let rgbaExpected: Array<Byte> = [0x00, 0x01, 0xfe, 0xff]
        @Assert(rgba.row(), rgbaExpected)
        @Assert(rgba.info.channels, UInt8(4))
        @Assert(rgba.info.pixelDepth, UInt16(32))
        @Assert(rgba.info.rowBytes, UInt64(4))
    }

    @TestCase
    public func exhaustivelyMatchesDirectSixteenBitScaleArithmetic(): Unit {
        let width = UInt32(65536)
        let input = Array<Byte>(Int64(width) * 2, repeat: 0)
        var value: UInt32 = 0
        while (value <= UInt32(0xffff)) {
            let offset = Int64(value) * 2
            input[offset] = UInt8(value >> 8)
            input[offset + 1] = UInt8(value & UInt32(0xff))
            value += 1
        }

        let scaled = pngDoScale16To8(
            PngReadRowInfo(width, UInt8(16), Grayscale), input
        )
        let row = scaled.row()
        value = 0
        while (value <= UInt32(0xffff)) {
            @Assert(
                row[Int64(value)],
                UInt8((value + UInt32(128)) / UInt32(257))
            )
            value += 1
        }
    }

    @TestCase
    public func chopsDirectSixteenBitRowsAcrossChannelTopologies(): Unit {
        let gray = pngDoChop(
            PngReadRowInfo(UInt32(2), UInt8(16), Grayscale),
            [0x12, 0x34, 0xab, 0xcd]
        )
        let grayExpected: Array<Byte> = [0x12, 0xab]
        @Assert(gray.row(), grayExpected)
        @Assert(gray.info.rowBytes, UInt64(2))

        let grayAlpha = pngDoChop(
            PngReadRowInfo(UInt32(1), UInt8(16), GrayscaleAlpha),
            [0x12, 0x34, 0x56, 0x78]
        )
        let grayAlphaExpected: Array<Byte> = [0x12, 0x56]
        @Assert(grayAlpha.row(), grayAlphaExpected)
        @Assert(grayAlpha.info.pixelDepth, UInt16(16))

        let rgb = pngDoChop(
            PngReadRowInfo(UInt32(1), UInt8(16), Truecolor),
            [0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc]
        )
        let rgbExpected: Array<Byte> = [0x12, 0x56, 0x9a]
        @Assert(rgb.row(), rgbExpected)
        @Assert(rgb.info.pixelDepth, UInt16(24))

        let rgba = pngDoChop(
            PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha),
            [0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0]
        )
        let rgbaExpected: Array<Byte> = [0x12, 0x56, 0x9a, 0xde]
        @Assert(rgba.row(), rgbaExpected)
        @Assert(rgba.info.bitDepth, UInt8(8))
        @Assert(rgba.info.channels, UInt8(4))
        @Assert(rgba.info.pixelDepth, UInt16(32))
        @Assert(rgba.info.rowBytes, UInt64(4))
    }

    @TestCase
    public func keepsNonSixteenBitRowsCopyOwnedAndRejectsBadLengths(): Unit {
        let input: Array<Byte> = [1, 2, 3, 4]
        let scaled = pngDoScale16To8(
            PngReadRowInfo(UInt32(1), UInt8(8), TruecolorAlpha), input
        )
        let expected: Array<Byte> = [1, 2, 3, 4]
        input[0] = UInt8(9)
        @Assert(scaled.row(), expected)
        let mutable = scaled.row()
        mutable[1] = UInt8(9)
        @Assert(scaled.row(), expected)
        @Assert(scaled.info.bitDepth, UInt8(8))
        @Assert(scaled.info.rowBytes, UInt64(4))

        let packed = pngDoChop(
            PngReadRowInfo(UInt32(4), UInt8(2), Grayscale), [0x1b]
        )
        let packedExpected: Array<Byte> = [0x1b]
        @Assert(packed.row(), packedExpected)
        @Assert(packed.info.bitDepth, UInt8(2))
        @Assert(packed.info.rowBytes, UInt64(1))

        try {
            pngDoScale16To8(
                PngReadRowInfo(UInt32(2), UInt8(16), Grayscale), [0, 1, 2]
            )
            @Fail("scale16 should reject a 16-bit row length mismatch")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }

        try {
            pngDoChop(
                PngReadRowInfo(UInt32(2), UInt8(8), Truecolor), [0, 1, 2]
            )
            @Fail("chop should reject a non-16-bit row length mismatch")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func appliesInitializedSixteenBitStagesWithScalePrecedence(): Unit {
        let decoded = decodePngNonInterlaced(makeTransformImage(
            UInt32(2), UInt8(16), UInt8(2), [], RGB16_TWO_ZLIB
        ))
        let rowInfo = PngReadRowInfo(UInt32(1), UInt8(16), Truecolor)
        let input: Array<Byte> = [0x00, 0xff, 0xff, 0x00, 0xff, 0xff]

        let disabled = initializePngReadTransformations(
            PngReadTransformState(), decoded
        )
        let unchanged = applyInitializedPng16To8Stages(disabled, rowInfo, input)
        @Assert(unchanged.row(), input)
        @Assert(unchanged.info.bitDepth, UInt8(16))

        let scaleState = PngReadTransformState()
        @Assert(scaleState.setScale16(), true)
        let scale = applyInitializedPng16To8Stages(
            initializePngReadTransformations(scaleState, decoded), rowInfo, input
        )
        let scaleExpected: Array<Byte> = [0x01, 0xfe, 0xff]
        @Assert(scale.row(), scaleExpected)
        @Assert(scale.info.bitDepth, UInt8(8))

        let stripState = PngReadTransformState()
        @Assert(stripState.setStrip16(), true)
        let strip = applyInitializedPng16To8Stages(
            initializePngReadTransformations(stripState, decoded), rowInfo, input
        )
        let stripExpected: Array<Byte> = [0x00, 0xff, 0xff]
        @Assert(strip.row(), stripExpected)
        @Assert(strip.info.bitDepth, UInt8(8))

        let bothState = PngReadTransformState()
        @Assert(bothState.setStrip16(), true)
        @Assert(bothState.setScale16(), true)
        let both = applyInitializedPng16To8Stages(
            initializePngReadTransformations(bothState, decoded), rowInfo, input
        )
        @Assert(both.row(), scaleExpected)
        @Assert(both.info.bitDepth, UInt8(8))
        @Assert(both.info.pixelDepth, UInt16(24))
        @Assert(both.info.rowBytes, UInt64(3))
    }

    @TestCase
    public func invertsEightBitGrayAlphaAndRgbaRows(): Unit {
        let grayAlphaInfo = PngReadRowInfo(
            UInt32(2), UInt8(8), GrayscaleAlpha
        )
        let grayAlpha = pngDoReadInvertAlpha(
            grayAlphaInfo, [1, 2, 3, 4]
        )
        let grayAlphaExpected: Array<Byte> = [1, 0xfd, 3, 0xfb]
        @Assert(grayAlpha.row(), grayAlphaExpected)
        @Assert(grayAlpha.info.width, UInt32(2))
        @Assert(grayAlpha.info.bitDepth, UInt8(8))
        @Assert(grayAlpha.info.colorType.toString(), "GRAYSCALE_ALPHA")
        @Assert(grayAlpha.info.channels, UInt8(2))
        @Assert(grayAlpha.info.pixelDepth, UInt16(16))
        @Assert(grayAlpha.info.rowBytes, UInt64(4))

        let rgbaInfo = PngReadRowInfo(UInt32(2), UInt8(8), TruecolorAlpha)
        let rgba = pngDoReadInvertAlpha(
            rgbaInfo, [1, 2, 3, 4, 5, 6, 7, 8]
        )
        let rgbaExpected: Array<Byte> = [1, 2, 3, 0xfb, 5, 6, 7, 0xf7]
        @Assert(rgba.row(), rgbaExpected)
        @Assert(rgba.info.colorType.toString(), "TRUECOLOR_ALPHA")
        @Assert(rgba.info.channels, UInt8(4))
        @Assert(rgba.info.pixelDepth, UInt16(32))
        @Assert(rgba.info.rowBytes, UInt64(8))
    }

    @TestCase
    public func invertsSixteenBitAlphaWithoutChangingNetworkOrder(): Unit {
        let grayAlpha = pngDoReadInvertAlpha(
            PngReadRowInfo(UInt32(1), UInt8(16), GrayscaleAlpha),
            [0x12, 0x34, 0x56, 0x78]
        )
        let grayAlphaExpected: Array<Byte> = [0x12, 0x34, 0xa9, 0x87]
        @Assert(grayAlpha.row(), grayAlphaExpected)
        @Assert(grayAlpha.info.bitDepth, UInt8(16))
        @Assert(grayAlpha.info.pixelDepth, UInt16(32))
        @Assert(grayAlpha.info.rowBytes, UInt64(4))

        let rgba = pngDoReadInvertAlpha(
            PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha),
            [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
        )
        let rgbaExpected: Array<Byte> = [
            0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0xf8, 0xf7
        ]
        @Assert(rgba.row(), rgbaExpected)
        @Assert(rgba.info.pixelDepth, UInt16(64))
        @Assert(rgba.info.rowBytes, UInt64(8))
    }

    @TestCase
    public func swapsAlphaFirstAcrossEightAndSixteenBitRows(): Unit {
        let grayAlpha8 = pngDoReadSwapAlpha(
            PngReadRowInfo(UInt32(2), UInt8(8), GrayscaleAlpha),
            [1, 2, 3, 4]
        )
        let grayAlpha8Expected: Array<Byte> = [2, 1, 4, 3]
        @Assert(grayAlpha8.row(), grayAlpha8Expected)

        let rgba8 = pngDoReadSwapAlpha(
            PngReadRowInfo(UInt32(2), UInt8(8), TruecolorAlpha),
            [1, 2, 3, 4, 5, 6, 7, 8]
        )
        let rgba8Expected: Array<Byte> = [4, 1, 2, 3, 8, 5, 6, 7]
        @Assert(rgba8.row(), rgba8Expected)

        let grayAlpha16 = pngDoReadSwapAlpha(
            PngReadRowInfo(UInt32(1), UInt8(16), GrayscaleAlpha),
            [0x12, 0x34, 0x56, 0x78]
        )
        let grayAlpha16Expected: Array<Byte> = [0x56, 0x78, 0x12, 0x34]
        @Assert(grayAlpha16.row(), grayAlpha16Expected)

        let rgba16 = pngDoReadSwapAlpha(
            PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha),
            [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
        )
        let rgba16Expected: Array<Byte> = [
            0x07, 0x08, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06
        ]
        @Assert(rgba16.row(), rgba16Expected)
        @Assert(rgba16.info.bitDepth, UInt8(16))
        @Assert(rgba16.info.colorType.toString(), "TRUECOLOR_ALPHA")
        @Assert(rgba16.info.channels, UInt8(4))
        @Assert(rgba16.info.pixelDepth, UInt16(64))
        @Assert(rgba16.info.rowBytes, UInt64(8))
    }

    @TestCase
    public func keepsUnsupportedAlphaRowsOwnedAndRejectsBadLengths(): Unit {
        let input: Array<Byte> = [1, 2, 3]
        let opaque = pngDoReadInvertAlpha(
            PngReadRowInfo(UInt32(1), UInt8(8), Truecolor), input
        )
        let expected: Array<Byte> = [1, 2, 3]
        input[0] = UInt8(9)
        @Assert(opaque.row(), expected)
        let mutable = opaque.row()
        mutable[1] = UInt8(9)
        @Assert(opaque.row(), expected)

        let unsupported = pngDoReadSwapAlpha(
            PngReadRowInfo(UInt32(2), UInt8(4), GrayscaleAlpha),
            [0x12, 0x34]
        )
        let unsupportedExpected: Array<Byte> = [0x12, 0x34]
        @Assert(unsupported.row(), unsupportedExpected)
        @Assert(unsupported.info.bitDepth, UInt8(4))
        @Assert(unsupported.info.rowBytes, UInt64(2))

        try {
            pngDoReadSwapAlpha(
                PngReadRowInfo(UInt32(2), UInt8(8), TruecolorAlpha),
                [1, 2, 3, 4, 5, 6, 7]
            )
            @Fail("swap-alpha should reject a row length mismatch")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }

        let selected: Array<PngReadChannelTransform> = [InvertAlpha]
        try {
            applySelectedPngAlphaTransforms(
                selected,
                PngReadRowInfo(UInt32(2), UInt8(8), GrayscaleAlpha),
                [1, 2, 3]
            )
            @Fail("selected alpha transforms should validate row length")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func appliesSelectedAlphaTransformsInFrozenRelativeOrder(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(1), UInt8(8), TruecolorAlpha)
        let input: Array<Byte> = [10, 20, 30, 40]

        let disabledTransforms: Array<PngReadChannelTransform> = []
        let disabled = applySelectedPngAlphaTransforms(
            disabledTransforms, rowInfo, input
        )
        @Assert(disabled.row(), input)

        let invertTransforms: Array<PngReadChannelTransform> = [InvertAlpha]
        let inverted = applySelectedPngAlphaTransforms(
            invertTransforms, rowInfo, input
        )
        let invertExpected: Array<Byte> = [10, 20, 30, 215]
        @Assert(inverted.row(), invertExpected)

        let swapTransforms: Array<PngReadChannelTransform> = [SwapAlpha]
        let swapped = applySelectedPngAlphaTransforms(
            swapTransforms, rowInfo, input
        )
        let swapExpected: Array<Byte> = [40, 10, 20, 30]
        @Assert(swapped.row(), swapExpected)

        let reversedTransforms: Array<PngReadChannelTransform> = [
            SwapAlpha, InvertAlpha
        ]
        let both = applySelectedPngAlphaTransforms(
            reversedTransforms, rowInfo, input
        )
        let bothExpected: Array<Byte> = [215, 10, 20, 30]
        @Assert(both.row(), bothExpected)

        let duplicateTransforms: Array<PngReadChannelTransform> = [
            InvertAlpha, SwapAlpha, InvertAlpha, SwapAlpha
        ]
        let duplicate = applySelectedPngAlphaTransforms(
            duplicateTransforms, rowInfo, input
        )
        @Assert(duplicate.row(), bothExpected)
        @Assert(duplicate.info.width, UInt32(1))
        @Assert(duplicate.info.bitDepth, UInt8(8))
        @Assert(duplicate.info.colorType.toString(), "TRUECOLOR_ALPHA")
        @Assert(duplicate.info.channels, UInt8(4))
        @Assert(duplicate.info.pixelDepth, UInt16(32))
        @Assert(duplicate.info.rowBytes, UInt64(4))
    }

    @TestCase
    public func addsEightBitGrayFillerBeforeAndAfter(): Unit {
        let input: Array<Byte> = [1, 2]
        let rowInfo = PngReadRowInfo(UInt32(2), UInt8(8), Grayscale)
        let after = pngDoReadFiller(
            rowInfo, input, UInt32(0x12345678), true
        )
        let afterExpected: Array<Byte> = [1, 0x78, 2, 0x78]
        @Assert(after.row(), afterExpected)
        @Assert(after.info.width, UInt32(2))
        @Assert(after.info.bitDepth, UInt8(8))
        @Assert(after.info.colorType.toString(), "GRAYSCALE")
        @Assert(after.info.channels, UInt8(2))
        @Assert(after.info.pixelDepth, UInt16(16))
        @Assert(after.info.rowBytes, UInt64(4))

        let before = pngDoReadFiller(
            rowInfo, input, UInt32(0x12345678), false
        )
        let beforeExpected: Array<Byte> = [0x78, 1, 0x78, 2]
        @Assert(before.row(), beforeExpected)

        input[0] = UInt8(9)
        @Assert(after.row(), afterExpected)
        let mutable = before.row()
        mutable[0] = UInt8(9)
        @Assert(before.row(), beforeExpected)
    }

    @TestCase
    public func addsEightBitRgbFillerBeforeAndAfter(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(2), UInt8(8), Truecolor)
        let input: Array<Byte> = [1, 2, 3, 4, 5, 6]
        let after = pngDoReadFiller(
            rowInfo, input, UInt32(0xab), true
        )
        let afterExpected: Array<Byte> = [1, 2, 3, 0xab, 4, 5, 6, 0xab]
        @Assert(after.row(), afterExpected)
        @Assert(after.info.colorType.toString(), "TRUECOLOR")
        @Assert(after.info.channels, UInt8(4))
        @Assert(after.info.pixelDepth, UInt16(32))
        @Assert(after.info.rowBytes, UInt64(8))

        let before = pngDoReadFiller(
            rowInfo, input, UInt32(0xab), false
        )
        let beforeExpected: Array<Byte> = [0xab, 1, 2, 3, 0xab, 4, 5, 6]
        @Assert(before.row(), beforeExpected)
    }

    @TestCase
    public func addsSixteenBitGrayFillerInNetworkOrder(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(2), UInt8(16), Grayscale)
        let input: Array<Byte> = [0x01, 0x02, 0x03, 0x04]
        let after = pngDoReadFiller(
            rowInfo, input, UInt32(0x12345678), true
        )
        let afterExpected: Array<Byte> = [
            0x01, 0x02, 0x56, 0x78,
            0x03, 0x04, 0x56, 0x78
        ]
        @Assert(after.row(), afterExpected)
        @Assert(after.info.width, UInt32(2))
        @Assert(after.info.bitDepth, UInt8(16))
        @Assert(after.info.colorType.toString(), "GRAYSCALE")
        @Assert(after.info.channels, UInt8(2))
        @Assert(after.info.pixelDepth, UInt16(32))
        @Assert(after.info.rowBytes, UInt64(8))

        let before = pngDoReadFiller(
            rowInfo, input, UInt32(0x12345678), false
        )
        let beforeExpected: Array<Byte> = [
            0x56, 0x78, 0x01, 0x02,
            0x56, 0x78, 0x03, 0x04
        ]
        @Assert(before.row(), beforeExpected)
    }

    @TestCase
    public func addsSixteenBitRgbFillerInNetworkOrder(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(1), UInt8(16), Truecolor)
        let input: Array<Byte> = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06]
        let after = pngDoReadFiller(
            rowInfo, input, UInt32(0x12345678), true
        )
        let afterExpected: Array<Byte> = [
            0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x56, 0x78
        ]
        @Assert(after.row(), afterExpected)
        @Assert(after.info.colorType.toString(), "TRUECOLOR")
        @Assert(after.info.channels, UInt8(4))
        @Assert(after.info.pixelDepth, UInt16(64))
        @Assert(after.info.rowBytes, UInt64(8))

        let before = pngDoReadFiller(
            rowInfo, input, UInt32(0x12345678), false
        )
        let beforeExpected: Array<Byte> = [
            0x56, 0x78, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06
        ]
        @Assert(before.row(), beforeExpected)
    }

    @TestCase
    public func keepsUnsupportedAndAlreadyExpandedFillerRowsUnchanged(): Unit {
        let alpha = pngDoReadFiller(
            PngReadRowInfo(UInt32(1), UInt8(8), GrayscaleAlpha),
            [1, 2],
            UInt32(0xff),
            true
        )
        let alphaExpected: Array<Byte> = [1, 2]
        @Assert(alpha.row(), alphaExpected)
        @Assert(alpha.info.channels, UInt8(2))

        let indexed = pngDoReadFiller(
            PngReadRowInfo(UInt32(2), UInt8(8), Indexed),
            [1, 2],
            UInt32(0xff),
            true
        )
        let indexedExpected: Array<Byte> = [1, 2]
        @Assert(indexed.row(), indexedExpected)

        let packed = pngDoReadFiller(
            PngReadRowInfo(UInt32(2), UInt8(4), Grayscale),
            [0x12],
            UInt32(0xff),
            true
        )
        let packedExpected: Array<Byte> = [0x12]
        @Assert(packed.row(), packedExpected)

        let expandedInfo = PngReadRowInfo(
            UInt32(1), UInt8(8), Truecolor, UInt8(4)
        )
        let expanded = pngDoReadFiller(
            expandedInfo, [1, 2, 3, 4], UInt32(0xff), true
        )
        let expandedExpected: Array<Byte> = [1, 2, 3, 4]
        @Assert(expanded.row(), expandedExpected)
        @Assert(expanded.info.colorType.toString(), "TRUECOLOR")
        @Assert(expanded.info.channels, UInt8(4))
        @Assert(expanded.info.pixelDepth, UInt16(32))
        @Assert(expanded.info.rowBytes, UInt64(4))

        try {
            pngDoReadFiller(
                PngReadRowInfo(UInt32(2), UInt8(8), Truecolor),
                [1, 2, 3, 4, 5],
                UInt32(0xff),
                true
            )
            @Fail("read filler should reject a row length mismatch")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func adaptsExistingFillerAndAddAlphaModesWithoutInfoOverclaim(): Unit {
        let rowInfo = PngReadRowInfo(UInt32(1), UInt8(8), Truecolor)
        let input: Array<Byte> = [1, 2, 3]

        let none = applyPngReadFillerTransform(
            PngRowShapeTransform(false), rowInfo, input
        )
        @Assert(none.row(), input)
        @Assert(none.info.channels, UInt8(3))

        let fillerBefore = applyPngReadFillerTransform(
            PngRowShapeTransform(false, FillerBefore, UInt16(0x1234)),
            rowInfo,
            input
        )
        let beforeExpected: Array<Byte> = [0x34, 1, 2, 3]
        @Assert(fillerBefore.row(), beforeExpected)

        let fillerAfter = applyPngReadFillerTransform(
            PngRowShapeTransform(false, FillerAfter, UInt16(0x1234)),
            rowInfo,
            input
        )
        let afterExpected: Array<Byte> = [1, 2, 3, 0x34]
        @Assert(fillerAfter.row(), afterExpected)

        let alphaBefore = applyPngReadFillerTransform(
            PngRowShapeTransform(false, AlphaBefore, UInt16(0x1234)),
            rowInfo,
            input
        )
        @Assert(alphaBefore.row(), beforeExpected)
        @Assert(alphaBefore.info.colorType.toString(), "TRUECOLOR")
        @Assert(alphaBefore.info.channels, UInt8(4))

        let alphaAfter = applyPngReadFillerTransform(
            PngRowShapeTransform(false, AlphaAfter, UInt16(0x1234)),
            rowInfo,
            input
        )
        @Assert(alphaAfter.row(), afterExpected)
        @Assert(alphaAfter.info.colorType.toString(), "TRUECOLOR")
        @Assert(alphaAfter.info.channels, UInt8(4))
        @Assert(alphaAfter.info.pixelDepth, UInt16(32))
        @Assert(alphaAfter.info.rowBytes, UInt64(4))
    }
}
