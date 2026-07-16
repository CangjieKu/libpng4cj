package libpng4cj.tests

import libpng4cj.*

private let SHAPE_RGB8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0xe0, 0x12, 0x91, 0xd3, 0x30,
    0xb2, 0x01, 0x00, 0x02, 0x37, 0x00, 0xd3
]

private let SHAPE_RGBA8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private let SHAPE_RGBA16_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private func joinShapeBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
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

private func makeShapeChunk(chunkType: Array<Byte>, data: Array<Byte>): Array<Byte> {
    joinShapeBytes(
        joinShapeBytes(
            joinShapeBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makeShapeIhdr(width: UInt32, bitDepth: UInt8, colorType: UInt8): Array<Byte> {
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
    makeShapeChunk(PNG_CHUNK_IHDR, data)
}

private func makeShapePng(
    width: UInt32,
    bitDepth: UInt8,
    colorType: UInt8,
    beforeIdat: Array<Array<Byte>>,
    compressed: Array<Byte>
): Array<Byte> {
    var out = joinShapeBytes(PNG_SIGNATURE, makeShapeIhdr(width, bitDepth, colorType))
    var index: Int64 = 0
    while (index < beforeIdat.size) {
        out = joinShapeBytes(out, beforeIdat[index])
        index += 1
    }
    out = joinShapeBytes(out, makeShapeChunk(PNG_CHUNK_IDAT, compressed))
    joinShapeBytes(out, makeShapeChunk(PNG_CHUNK_IEND, []))
}

@Test
public class PngRowShapeTransformTestSuite {
    @TestCase
    public func returnsNaturalRgbAndRgbaShapes(): Unit {
        let rgb = makeShapePng(
            UInt32(2), UInt8(8), UInt8(2), [], SHAPE_RGB8_ZLIB
        )
        let naturalRgb = transformPngRowsToPixels8(
            decodePngNonInterlaced(rgb),
            PngRowShapeTransform(false)
        )
        let expectedRgb: Array<Byte> = [10, 20, 30, 40, 50, 60]
        @Assert(naturalRgb.layout.toString(), "RGB")
        @Assert(naturalRgb.channelCount, UInt8(3))
        @Assert(naturalRgb.row(0), expectedRgb)

        let bgrTransforms: Array<PngReadChannelTransform> = [Bgr]
        let naturalBgr = transformPngRowsToPixels8(
            decodePngNonInterlaced(rgb),
            PngRowShapeTransform(false),
            bgrTransforms
        )
        let expectedBgr: Array<Byte> = [30, 20, 10, 60, 50, 40]
        @Assert(naturalBgr.layout.toString(), "BGR")
        @Assert(naturalBgr.channelCount, UInt8(3))
        @Assert(naturalBgr.row(0), expectedBgr)

        let mutableRgb = naturalRgb.row(0)
        mutableRgb[0] = 0
        @Assert(naturalRgb.row(0), expectedRgb)

        let rgba = makeShapePng(
            UInt32(2), UInt8(8), UInt8(6), [], SHAPE_RGBA8_ZLIB
        )
        let naturalRgba = transformPngRowsToPixels8(
            decodePngNonInterlaced(rgba),
            PngRowShapeTransform(false)
        )
        let expectedRgba: Array<Byte> = [1, 2, 3, 4, 5, 6, 7, 8]
        @Assert(naturalRgba.layout.toString(), "RGBA")
        @Assert(naturalRgba.channelCount, UInt8(4))
        @Assert(naturalRgba.row(0), expectedRgba)
    }

    @TestCase
    public func distinguishesFillerAndAddedAlphaLayouts(): Unit {
        let png = makeShapePng(
            UInt32(2), UInt8(8), UInt8(2), [], SHAPE_RGB8_ZLIB
        )
        let decoded = decodePngNonInterlaced(png)

        let fillerBefore = transformPngRowsToPixels8(
            decoded,
            PngRowShapeTransform(false, FillerBefore, UInt16(0x01aa))
        )
        let fillerAfter = transformPngRowsToPixels8(
            decoded,
            PngRowShapeTransform(false, FillerAfter, UInt16(0x01bb))
        )
        let alphaBefore = transformPngRowsToPixels8(
            decoded,
            PngRowShapeTransform(false, AlphaBefore, UInt16(0x01cc))
        )
        let alphaAfter = transformPngRowsToPixels8(
            decoded,
            PngRowShapeTransform(false, AlphaAfter, UInt16(0x01dd))
        )

        let expectedFillerBefore: Array<Byte> = [
            0xaa, 10, 20, 30,
            0xaa, 40, 50, 60
        ]
        let expectedFillerAfter: Array<Byte> = [
            10, 20, 30, 0xbb,
            40, 50, 60, 0xbb
        ]
        let expectedAlphaBefore: Array<Byte> = [
            0xcc, 10, 20, 30,
            0xcc, 40, 50, 60
        ]
        let expectedAlphaAfter: Array<Byte> = [
            10, 20, 30, 0xdd,
            40, 50, 60, 0xdd
        ]

        @Assert(fillerBefore.layout.toString(), "XRGB")
        @Assert(fillerBefore.row(0), expectedFillerBefore)
        @Assert(fillerAfter.layout.toString(), "RGBX")
        @Assert(fillerAfter.row(0), expectedFillerAfter)
        @Assert(alphaBefore.layout.toString(), "ARGB")
        @Assert(alphaBefore.row(0), expectedAlphaBefore)
        @Assert(alphaAfter.layout.toString(), "RGBA")
        @Assert(alphaAfter.row(0), expectedAlphaAfter)
    }

    @TestCase
    public func stripsExistingAlphaToRgb(): Unit {
        let png = makeShapePng(
            UInt32(2), UInt8(8), UInt8(6), [], SHAPE_RGBA8_ZLIB
        )
        let transformed = transformPngRowsToPixels8(
            decodePngNonInterlaced(png),
            PngRowShapeTransform(true)
        )
        let expected: Array<Byte> = [1, 2, 3, 5, 6, 7]
        @Assert(transformed.layout.toString(), "RGB")
        @Assert(transformed.channelCount, UInt8(3))
        @Assert(transformed.row(0), expected)
    }

    @TestCase
    public func existingAlphaSuppressesFiller(): Unit {
        let png = makeShapePng(
            UInt32(2), UInt8(8), UInt8(6), [], SHAPE_RGBA8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [SwapAlpha]
        let transformed = transformPngRowsToPixels8(
            decodePngNonInterlaced(png),
            PngRowShapeTransform(false, FillerBefore, UInt16(0xaa)),
            transforms
        )
        let expected: Array<Byte> = [4, 1, 2, 3, 8, 5, 6, 7]
        @Assert(transformed.layout.toString(), "ARGB")
        @Assert(transformed.row(0), expected)
    }

    @TestCase
    public func stripThenAddsPlainFillerWithoutAlphaSwap(): Unit {
        let png = makeShapePng(
            UInt32(2), UInt8(8), UInt8(6), [], SHAPE_RGBA8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [SwapAlpha, Bgr]
        let transformed = transformPngRowsToPixels8(
            decodePngNonInterlaced(png),
            PngRowShapeTransform(true, FillerBefore, UInt16(0xaa)),
            transforms
        )
        let expected: Array<Byte> = [
            0xaa, 3, 2, 1,
            0xaa, 7, 6, 5
        ]
        @Assert(transformed.layout.toString(), "XBGR")
        @Assert(transformed.row(0), expected)
    }

    @TestCase
    public func addedAlphaSkipsInvertButParticipatesInSwap(): Unit {
        let png = makeShapePng(
            UInt32(2), UInt8(8), UInt8(2), [], SHAPE_RGB8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [InvertAlpha, SwapAlpha]
        let transformed = transformPngRowsToPixels8(
            decodePngNonInterlaced(png),
            PngRowShapeTransform(false, AlphaAfter, UInt16(0x80)),
            transforms
        )
        let expected: Array<Byte> = [
            0x80, 10, 20, 30,
            0x80, 40, 50, 60
        ]
        @Assert(transformed.layout.toString(), "ARGB")
        @Assert(transformed.row(0), expected)
    }

    @TestCase
    public func alphaBeforeMovesAfterWhenSwapped(): Unit {
        let png = makeShapePng(
            UInt32(2), UInt8(8), UInt8(2), [], SHAPE_RGB8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [SwapAlpha]
        let transformed = transformPngRowsToPixels8(
            decodePngNonInterlaced(png),
            PngRowShapeTransform(false, AlphaBefore, UInt16(0x80)),
            transforms
        )
        let expected: Array<Byte> = [
            10, 20, 30, 0x80,
            40, 50, 60, 0x80
        ]
        @Assert(transformed.layout.toString(), "RGBA")
        @Assert(transformed.row(0), expected)
    }

    @TestCase
    public func stripsTrnsDerivedAlpha(): Unit {
        let transparency: Array<Byte> = [0x00, 0x0a, 0x00, 0x14, 0x00, 0x1e]
        let png = makeShapePng(
            UInt32(2),
            UInt8(8),
            UInt8(2),
            [makeShapeChunk(PNG_CHUNK_tRNS, transparency)],
            SHAPE_RGB8_ZLIB
        )
        let natural = transformPngRowsToPixels8(
            decodePngNonInterlaced(png),
            PngRowShapeTransform(false)
        )
        let stripped = transformPngRowsToPixels8(
            decodePngNonInterlaced(png),
            PngRowShapeTransform(true)
        )
        let expectedNatural: Array<Byte> = [10, 20, 30, 0, 40, 50, 60, 0xff]
        let expectedStripped: Array<Byte> = [10, 20, 30, 40, 50, 60]
        @Assert(natural.layout.toString(), "RGBA")
        @Assert(natural.row(0), expectedNatural)
        @Assert(stripped.layout.toString(), "RGB")
        @Assert(stripped.row(0), expectedStripped)
    }

    @TestCase
    public func appliesShapesToRgba16AndReducedOutput(): Unit {
        let png = makeShapePng(
            UInt32(1), UInt8(16), UInt8(6), [], SHAPE_RGBA16_ZLIB
        )
        let decoded = decodePngNonInterlaced(png)
        let shape = PngRowShapeTransform(true, AlphaAfter, UInt16(0x1234))
        let transforms: Array<PngReadChannelTransform> = [Bgr, SwapAlpha]
        let transformed16 = transformPngRowsToPixels16(decoded, shape, transforms)
        let expected16: Array<UInt16> = [0x1234, 0x0506, 0x0304, 0x0102]
        @Assert(transformed16.layout.toString(), "ABGR")
        @Assert(transformed16.row(0), expected16)

        let transformed8 = transformPngRowsToPixels8(decoded, Strip, shape, transforms)
        let expected8: Array<Byte> = [0x34, 0x05, 0x03, 0x01]
        @Assert(transformed8.layout.toString(), "ABGR")
        @Assert(transformed8.row(0), expected8)

        let mutableRow = transformed16.row(0)
        mutableRow[0] = UInt16(0)
        @Assert(transformed16.row(0), expected16)
    }

    @TestCase
    public func limitsFinalPixelShapeBytes(): Unit {
        let png = makeShapePng(
            UInt32(2), UInt8(8), UInt8(2), [], SHAPE_RGB8_ZLIB
        )
        let exact = transformPngRowsToPixels8(
            decodePngNonInterlaced(png),
            PngReadLimits(
                UInt32(1024),
                UInt32(100),
                UInt32(100),
                UInt64(1024),
                UInt64(1024),
                UInt64(6)
            ),
            PngRowShapeTransform(false),
            []
        )
        let expected: Array<Byte> = [10, 20, 30, 40, 50, 60]
        @Assert(exact.row(0), expected)

        try {
            transformPngRowsToPixels8(
                decodePngNonInterlaced(png),
                PngReadLimits(
                    UInt32(1024),
                    UInt32(100),
                    UInt32(100),
                    UInt64(1024),
                    UInt64(1024),
                    UInt64(5)
                ),
                PngRowShapeTransform(false),
                []
            )
            @Fail("final pixel shape limit should reject RGB rows")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "DECODE_LIMIT_EXCEEDED")
        }
    }

    @TestCase
    public func keepsFillerAndAddedAlphaOutsideSignificantBitShift(): Unit {
        let rgb = makeShapePng(
            UInt32(2),
            UInt8(8),
            UInt8(2),
            [makeShapeChunk(PNG_CHUNK_sBIT, [5, 6, 7])],
            SHAPE_RGB8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [
            UnshiftSignificantBits, InvertAlpha
        ]
        let addedAlpha = transformPngRowsToPixels8(
            decodePngNonInterlaced(rgb),
            PngRowShapeTransform(false, AlphaBefore, UInt16(0x80)),
            transforms
        )
        let expectedAddedAlpha: Array<Byte> = [
            0x80, 1, 5, 15,
            0x80, 5, 12, 30
        ]
        @Assert(addedAlpha.layout.toString(), "ARGB")
        @Assert(addedAlpha.row(0), expectedAddedAlpha)

        let rgba = makeShapePng(
            UInt32(2),
            UInt8(8),
            UInt8(6),
            [makeShapeChunk(PNG_CHUNK_sBIT, [5, 6, 7, 4])],
            SHAPE_RGBA8_ZLIB
        )
        let strippedWithFiller = transformPngRowsToPixels8(
            decodePngNonInterlaced(rgba),
            PngRowShapeTransform(true, FillerBefore, UInt16(0xaa)),
            transforms
        )
        let expectedFiller: Array<Byte> = [
            0xaa, 0, 0, 1,
            0xaa, 0, 1, 3
        ]
        @Assert(strippedWithFiller.layout.toString(), "XRGB")
        @Assert(strippedWithFiller.row(0), expectedFiller)
    }

    @TestCase
    public func projectsSimpleSetterStateIntoExistingRowShapeBehavior(): Unit {
        let rgba = makeShapePng(
            UInt32(2), UInt8(8), UInt8(6), [], SHAPE_RGBA8_ZLIB
        )
        let state = PngReadTransformState()
        @Assert(state.setStripAlpha(), true)
        let stripped = transformPngRowsToPixels8(
            decodePngNonInterlaced(rgba),
            state.rowShapeTransform()
        )
        let expected: Array<Byte> = [1, 2, 3, 5, 6, 7]
        @Assert(stripped.layout.toString(), "RGB")
        @Assert(stripped.row(0), expected)
    }
}
