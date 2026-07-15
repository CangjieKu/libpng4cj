package libpng4cj.tests

import libpng4cj.*

private let CHANNEL_RGB8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0xe0, 0x12, 0x91, 0xd3, 0x30,
    0xb2, 0x01, 0x00, 0x02, 0x37, 0x00, 0xd3
]

private let CHANNEL_GRAY_ALPHA8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0xe7, 0xe0, 0xe4, 0x02,
    0x00, 0x00, 0x55, 0x00, 0x23
]

private let CHANNEL_RGBA8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private let CHANNEL_RGBA16_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private let CHANNEL_INDEXED1_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x70, 0x00, 0x00, 0x00, 0x42, 0x00, 0x41
]

private let CHANNEL_GRAY1_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x88, 0x02, 0x00, 0x00, 0x5c, 0x00, 0x5b
]

private func joinChannelBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
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

private func makeChannelChunk(chunkType: Array<Byte>, data: Array<Byte>): Array<Byte> {
    joinChannelBytes(
        joinChannelBytes(
            joinChannelBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makeChannelIhdr(width: UInt32, bitDepth: UInt8, colorType: UInt8): Array<Byte> {
    let data = Array<Byte>(13, repeat: 0)
    let widthBytes = writeUInt32Be(width)
    let heightBytes = writeUInt32Be(UInt32(1))
    var index: Int64 = 0
    while (index < 4) {
        data[index] = widthBytes[index]
        data[index + 4] = heightBytes[index]
        index += 1
    }
    data[8] = bitDepth
    data[9] = colorType
    makeChannelChunk(PNG_CHUNK_IHDR, data)
}

private func makeChannelPng(
    width: UInt32,
    bitDepth: UInt8,
    colorType: UInt8,
    beforeIdat: Array<Array<Byte>>,
    compressed: Array<Byte>
): Array<Byte> {
    var out = joinChannelBytes(PNG_SIGNATURE, makeChannelIhdr(width, bitDepth, colorType))
    var index: Int64 = 0
    while (index < beforeIdat.size) {
        out = joinChannelBytes(out, beforeIdat[index])
        index += 1
    }
    out = joinChannelBytes(out, makeChannelChunk(PNG_CHUNK_IDAT, compressed))
    joinChannelBytes(out, makeChannelChunk(PNG_CHUNK_IEND, []))
}

@Test
public class PngChannelTransformTestSuite {
    @TestCase
    public func preservesDefaultRgbaLayout(): Unit {
        let png = makeChannelPng(
            UInt32(2), UInt8(8), UInt8(6), [], CHANNEL_RGBA8_ZLIB
        )
        let expected: Array<Byte> = [1, 2, 3, 4, 5, 6, 7, 8]
        let decoded = decodePngRgba8NonInterlaced(png)
        @Assert(decoded.layout.toString(), "RGBA")
        @Assert(decoded.row(0), expected)
    }

    @TestCase
    public func appliesLateTransformsInFrozenOrder(): Unit {
        let png = makeChannelPng(
            UInt32(2), UInt8(8), UInt8(6), [], CHANNEL_RGBA8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [
            SwapAlpha, Bgr, InvertAlpha, InvertMonochrome
        ]
        let expected: Array<Byte> = [
            251, 3, 2, 1,
            247, 7, 6, 5
        ]
        let transformed = transformPngRowsToRgba8(
            decodePngNonInterlaced(png),
            transforms
        )
        @Assert(transformed.layout.toString(), "ABGR")
        @Assert(transformed.row(0), expected)
    }

    @TestCase
    public func invertsGrayscaleWithoutChangingAlpha(): Unit {
        let png = makeChannelPng(
            UInt32(2), UInt8(8), UInt8(4), [], CHANNEL_GRAY_ALPHA8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [InvertMonochrome]
        let expected: Array<Byte> = [
            248, 248, 248, 8,
            246, 246, 246, 10
        ]
        let transformed = transformPngRowsToRgba8(
            decodePngNonInterlaced(png),
            transforms
        )
        @Assert(transformed.layout.toString(), "RGBA")
        @Assert(transformed.row(0), expected)
    }

    @TestCase
    public func ignoresAlphaTransformsForOpaqueSource(): Unit {
        let png = makeChannelPng(
            UInt32(2), UInt8(8), UInt8(2), [], CHANNEL_RGB8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [
            SwapAlpha, InvertAlpha, Bgr
        ]
        let expected: Array<Byte> = [
            30, 20, 10, 255,
            60, 50, 40, 255
        ]
        let transformed = transformPngRowsToRgba8(
            decodePngNonInterlaced(png),
            transforms
        )
        @Assert(transformed.layout.toString(), "BGRA")
        @Assert(transformed.row(0), expected)
    }

    @TestCase
    public func treatsTrnsAsSemanticAlpha(): Unit {
        let transparency: Array<Byte> = [0x00, 0x0a, 0x00, 0x14, 0x00, 0x1e]
        let png = makeChannelPng(
            UInt32(2),
            UInt8(8),
            UInt8(2),
            [makeChannelChunk(PNG_CHUNK_tRNS, transparency)],
            CHANNEL_RGB8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [InvertAlpha, SwapAlpha]
        let expected: Array<Byte> = [
            255, 10, 20, 30,
            0, 40, 50, 60
        ]
        let transformed = transformPngRowsToRgba8(
            decodePngNonInterlaced(png),
            transforms
        )
        @Assert(transformed.layout.toString(), "ARGB")
        @Assert(transformed.row(0), expected)
    }

    @TestCase
    public func appliesChannelTransformsToRgba16AndReducedRgba8(): Unit {
        let png = makeChannelPng(
            UInt32(1), UInt8(16), UInt8(6), [], CHANNEL_RGBA16_ZLIB
        )
        let decoded = decodePngNonInterlaced(png)
        let transforms: Array<PngReadChannelTransform> = [
            Bgr, SwapAlpha, InvertAlpha
        ]
        let expected16: Array<UInt16> = [0xf8f7, 0x0506, 0x0304, 0x0102]
        let transformed16 = transformPngRowsToRgba16(decoded, transforms)
        @Assert(transformed16.layout.toString(), "ABGR")
        @Assert(transformed16.row(0), expected16)

        let expected8: Array<Byte> = [0xf8, 0x05, 0x03, 0x01]
        let transformed8 = transformPngRowsToRgba8(decoded, Strip, transforms)
        @Assert(transformed8.layout.toString(), "ABGR")
        @Assert(transformed8.row(0), expected8)

        let mutableRow = transformed16.row(0)
        mutableRow[0] = UInt16(0)
        @Assert(transformed16.row(0), expected16)
    }

    @TestCase
    public func treatsMissingAndFullDepthSignificanceAsNoOp(): Unit {
        @Assert(Bgr.ordinalValue(), Int64(2))
        @Assert(SwapAlpha.ordinalValue(), Int64(3))
        @Assert(UnshiftSignificantBits.ordinalValue(), Int64(4))

        let plain = makeChannelPng(
            UInt32(2), UInt8(8), UInt8(6), [], CHANNEL_RGBA8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [UnshiftSignificantBits]
        let expected: Array<Byte> = [1, 2, 3, 4, 5, 6, 7, 8]
        @Assert(
            transformPngRowsToRgba8(decodePngNonInterlaced(plain), transforms).row(0),
            expected
        )

        let fullDepth = makeChannelPng(
            UInt32(2),
            UInt8(8),
            UInt8(6),
            [makeChannelChunk(PNG_CHUNK_sBIT, [8, 8, 8, 8])],
            CHANNEL_RGBA8_ZLIB
        )
        @Assert(
            transformPngRowsToRgba8(decodePngNonInterlaced(fullDepth), transforms).row(0),
            expected
        )
    }

    @TestCase
    public func unshiftsBeforeBgrAndAlphaSwap(): Unit {
        let transparency: Array<Byte> = [0x00, 0x0a, 0x00, 0x14, 0x00, 0x1e]
        let png = makeChannelPng(
            UInt32(2),
            UInt8(8),
            UInt8(2),
            [
                makeChannelChunk(PNG_CHUNK_sBIT, [5, 6, 7]),
                makeChannelChunk(PNG_CHUNK_tRNS, transparency)
            ],
            CHANNEL_RGB8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [
            SwapAlpha, Bgr, UnshiftSignificantBits
        ]
        let expected: Array<Byte> = [
            0, 15, 5, 1,
            0xff, 30, 12, 5
        ]
        let transformed = transformPngRowsToRgba8(
            decodePngNonInterlaced(png), transforms
        )
        @Assert(transformed.layout.toString(), "ABGR")
        @Assert(transformed.row(0), expected)
    }

    @TestCase
    public func unshiftsAfterMonochromeAndAlphaInversion(): Unit {
        let png = makeChannelPng(
            UInt32(2),
            UInt8(8),
            UInt8(4),
            [makeChannelChunk(PNG_CHUNK_sBIT, [4, 3])],
            CHANNEL_GRAY_ALPHA8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [
            UnshiftSignificantBits, InvertAlpha, InvertMonochrome
        ]
        let expected: Array<Byte> = [
            15, 15, 15, 7,
            15, 15, 15, 7
        ]
        @Assert(
            transformPngRowsToRgba8(decodePngNonInterlaced(png), transforms).row(0),
            expected
        )
    }

    @TestCase
    public func unshiftsExpandedPaletteColors(): Unit {
        let png = makeChannelPng(
            UInt32(2),
            UInt8(1),
            UInt8(3),
            [
                makeChannelChunk(PNG_CHUNK_sBIT, [4, 5, 6]),
                makeChannelChunk(PNG_CHUNK_PLTE, [10, 20, 30, 40, 50, 60])
            ],
            CHANNEL_INDEXED1_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [UnshiftSignificantBits]
        let expected: Array<Byte> = [
            0, 2, 7, 0xff,
            2, 6, 15, 0xff
        ]
        @Assert(
            transformPngRowsToRgba8(decodePngNonInterlaced(png), transforms).row(0),
            expected
        )

        let gray = makeChannelPng(
            UInt32(8),
            UInt8(1),
            UInt8(0),
            [makeChannelChunk(PNG_CHUNK_sBIT, [1])],
            CHANNEL_GRAY1_ZLIB
        )
        let expectedGray: Array<Byte> = [
            0, 0, 0, 0xff,
            1, 1, 1, 0xff,
            0, 0, 0, 0xff,
            1, 1, 1, 0xff,
            1, 1, 1, 0xff,
            0, 0, 0, 0xff,
            1, 1, 1, 0xff,
            0, 0, 0, 0xff
        ]
        @Assert(
            transformPngRowsToRgba8(decodePngNonInterlaced(gray), transforms).row(0),
            expectedGray
        )
    }

    @TestCase
    public func usesActualOutputDepthForNativeAndReducedRows(): Unit {
        let png = makeChannelPng(
            UInt32(1),
            UInt8(16),
            UInt8(6),
            [makeChannelChunk(PNG_CHUNK_sBIT, [12, 10, 8, 4])],
            CHANNEL_RGBA16_ZLIB
        )
        let decoded = decodePngNonInterlaced(png)
        let transforms: Array<PngReadChannelTransform> = [UnshiftSignificantBits]

        let expected16: Array<UInt16> = [0x0010, 0x000c, 0x0005, 0x0000]
        let transformed16 = transformPngRowsToRgba16(decoded, transforms)
        @Assert(transformed16.row(0), expected16)
        @Assert(transformed16.metadata.significantBits.red, UInt8(12))

        let expected8: Array<Byte> = [0x01, 0x03, 0x05, 0x00]
        @Assert(transformPngRowsToRgba8(decoded, Strip, transforms).row(0), expected8)
        @Assert(transformPngRowsToRgba8(decoded, Scale, transforms).row(0), expected8)
    }
}
