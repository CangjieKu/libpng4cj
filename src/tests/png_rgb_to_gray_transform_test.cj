package libpng4cj.tests

import libpng4cj.*

private let GRAY_RGB8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0xe0, 0x12, 0x91, 0xd3, 0x30,
    0xb2, 0x01, 0x00, 0x02, 0x37, 0x00, 0xd3
]

private let GRAY_EQUAL_RGB8_ZLIB: Array<Byte> = [
    0x78, 0x01, 0x01, 0x04, 0x00, 0xfb, 0xff,
    0x00, 0x07, 0x07, 0x07, 0x00, 0x2e, 0x00, 0x16
]

private let GRAY_RGBA8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private let GRAY_RGBA16_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private let GRAY_GRAY_ALPHA8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0xe7, 0xe0, 0xe4, 0x02,
    0x00, 0x00, 0x55, 0x00, 0x23
]

private let GRAY_INDEXED1_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x70, 0x00, 0x00, 0x00, 0x42, 0x00, 0x41
]

private func joinGrayBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
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

private func makeGrayChunk(chunkType: Array<Byte>, data: Array<Byte>): Array<Byte> {
    joinGrayBytes(
        joinGrayBytes(
            joinGrayBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makeGrayIhdr(width: UInt32, bitDepth: UInt8, colorType: UInt8): Array<Byte> {
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
    makeGrayChunk(PNG_CHUNK_IHDR, data)
}

private func makeGrayPng(
    width: UInt32,
    bitDepth: UInt8,
    colorType: UInt8,
    beforeIdat: Array<Array<Byte>>,
    compressed: Array<Byte>
): Array<Byte> {
    var out = joinGrayBytes(PNG_SIGNATURE, makeGrayIhdr(width, bitDepth, colorType))
    var index: Int64 = 0
    while (index < beforeIdat.size) {
        out = joinGrayBytes(out, beforeIdat[index])
        index += 1
    }
    out = joinGrayBytes(out, makeGrayChunk(PNG_CHUNK_IDAT, compressed))
    joinGrayBytes(out, makeGrayChunk(PNG_CHUNK_IEND, []))
}

@Test
public class PngRgbToGrayTransformTestSuite {
    @TestCase
    public func convertsWithHistoricalAndCustomFixedCoefficients(): Unit {
        let png = makeGrayPng(
            UInt32(2), UInt8(8), UInt8(2), [], GRAY_RGB8_ZLIB
        )
        let decoded = decodePngNonInterlaced(png)
        let defaults = PngRgbToGrayTransform()
        let historical = transformPngRowsToGray8(decoded, defaults)
        let historicalExpected: Array<Byte> = [18, 48]
        @Assert(historical.layout.toString(), "G")
        @Assert(historical.channelCount, UInt8(1))
        @Assert(historical.hadNonGrayPixels, true)
        @Assert(historical.row(0), historicalExpected)
        @Assert(defaults.customCoefficientsAccepted, false)

        let redOnly = PngRgbToGrayTransform(Convert, UInt32(100000), UInt32(0))
        let custom = transformPngRowsToGray8(decoded, redOnly)
        let customExpected: Array<Byte> = [10, 40]
        @Assert(redOnly.redCoefficient, UInt16(32768))
        @Assert(redOnly.greenCoefficient, UInt16(0))
        @Assert(redOnly.blueCoefficient, UInt16(0))
        @Assert(redOnly.customCoefficientsAccepted, true)
        @Assert(custom.row(0), customExpected)

        let rec709Weights = PngRgbToGrayTransform(
            Convert, UInt32(21268), UInt32(71514)
        )
        @Assert(rec709Weights.redCoefficient, UInt16(6969))
        @Assert(rec709Weights.greenCoefficient, UInt16(23433))
        @Assert(rec709Weights.blueCoefficient, UInt16(2366))
        @Assert(rec709Weights.customCoefficientsAccepted, true)
    }

    @TestCase
    public func ignoresInvalidFixedCoefficientsLikeUpstreamSetter(): Unit {
        let outOfRange = PngRgbToGrayTransform(
            Convert, UInt32(70000), UInt32(30001)
        )
        @Assert(outOfRange.redCoefficient, UInt16(6968))
        @Assert(outOfRange.greenCoefficient, UInt16(23434))
        @Assert(outOfRange.blueCoefficient, UInt16(2366))
        @Assert(outOfRange.customCoefficientsAccepted, false)

        let negative = PngRgbToGrayTransform(Convert, Int64(-1), Int64(50000))
        @Assert(negative.redCoefficient, UInt16(6968))
        @Assert(negative.greenCoefficient, UInt16(23434))
        @Assert(negative.blueCoefficient, UInt16(2366))
        @Assert(negative.customCoefficientsAccepted, false)

        let png = makeGrayPng(
            UInt32(2), UInt8(8), UInt8(2), [], GRAY_RGB8_ZLIB
        )
        let rows = transformPngRowsToGray8(decodePngNonInterlaced(png), outOfRange)
        let expected: Array<Byte> = [18, 48]
        @Assert(rows.row(0), expected)
    }

    @TestCase
    public func preservesEqualRgbAndEnforcesStrictPolicy(): Unit {
        let equal = makeGrayPng(
            UInt32(1), UInt8(8), UInt8(2), [], GRAY_EQUAL_RGB8_ZLIB
        )
        let strictEqual = transformPngRowsToGray8(
            decodePngNonInterlaced(equal), PngRgbToGrayTransform(RequireGray)
        )
        let expected: Array<Byte> = [7]
        @Assert(strictEqual.row(0), expected)
        @Assert(strictEqual.hadNonGrayPixels, false)

        let nongray = makeGrayPng(
            UInt32(2), UInt8(8), UInt8(2), [], GRAY_RGB8_ZLIB
        )
        try {
            transformPngRowsToGray8(
                decodePngNonInterlaced(nongray), PngRgbToGrayTransform(RequireGray)
            )
            @Fail("strict RGB-to-gray policy should reject nongray pixels")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "RGB_TO_GRAY_MISMATCH")
        }
    }

    @TestCase
    public func preservesAlphaAndResolvesGrayLayouts(): Unit {
        let rgba = makeGrayPng(
            UInt32(2), UInt8(8), UInt8(6), [], GRAY_RGBA8_ZLIB
        )
        let decoded = decodePngNonInterlaced(rgba)
        let transform = PngRgbToGrayTransform()

        let natural = transformPngRowsToGray8(decoded, transform)
        let naturalExpected: Array<Byte> = [1, 4, 5, 8]
        @Assert(natural.layout.toString(), "GA")
        @Assert(natural.row(0), naturalExpected)

        let swapped = transformPngRowsToGray8(
            decoded, transform, [SwapAlpha]
        )
        let swappedExpected: Array<Byte> = [4, 1, 8, 5]
        @Assert(swapped.layout.toString(), "AG")
        @Assert(swapped.row(0), swappedExpected)

        let strippedFiller = transformPngRowsToGray8(
            decoded,
            transform,
            PngRowShapeTransform(true, FillerAfter, UInt16(0xaa)),
            [SwapAlpha, Bgr]
        )
        let fillerExpected: Array<Byte> = [1, 0xaa, 5, 0xaa]
        @Assert(strippedFiller.layout.toString(), "GX")
        @Assert(strippedFiller.row(0), fillerExpected)

        let fillerBefore = transformPngRowsToGray8(
            decoded,
            transform,
            PngRowShapeTransform(true, FillerBefore, UInt16(0xbb)),
            []
        )
        let beforeExpected: Array<Byte> = [0xbb, 1, 0xbb, 5]
        @Assert(fillerBefore.layout.toString(), "XG")
        @Assert(fillerBefore.row(0), beforeExpected)
    }

    @TestCase
    public func handlesPaletteAndExistingGrayscaleSources(): Unit {
        let indexed = makeGrayPng(
            UInt32(2),
            UInt8(1),
            UInt8(3),
            [makeGrayChunk(PNG_CHUNK_PLTE, [10, 20, 30, 40, 50, 60])],
            GRAY_INDEXED1_ZLIB
        )
        let paletteRows = transformPngRowsToGray8(
            decodePngNonInterlaced(indexed), PngRgbToGrayTransform()
        )
        let paletteExpected: Array<Byte> = [18, 48]
        @Assert(paletteRows.row(0), paletteExpected)
        @Assert(paletteRows.hadNonGrayPixels, true)

        let grayAlpha = makeGrayPng(
            UInt32(2), UInt8(8), UInt8(4), [], GRAY_GRAY_ALPHA8_ZLIB
        )
        let grayRows = transformPngRowsToGray8(
            decodePngNonInterlaced(grayAlpha), PngRgbToGrayTransform(RequireGray)
        )
        let grayExpected: Array<Byte> = [7, 8, 9, 10]
        @Assert(grayRows.layout.toString(), "GA")
        @Assert(grayRows.row(0), grayExpected)
        @Assert(grayRows.hadNonGrayPixels, false)
    }

    @TestCase
    public func preservesTrnsDerivedAlphaUnlessStripped(): Unit {
        let transparency: Array<Byte> = [0x00, 0x0a, 0x00, 0x14, 0x00, 0x1e]
        let png = makeGrayPng(
            UInt32(2),
            UInt8(8),
            UInt8(2),
            [makeGrayChunk(PNG_CHUNK_tRNS, transparency)],
            GRAY_RGB8_ZLIB
        )
        let decoded = decodePngNonInterlaced(png)
        let transform = PngRgbToGrayTransform()
        let natural = transformPngRowsToGray8(decoded, transform)
        let naturalExpected: Array<Byte> = [18, 0, 48, 0xff]
        @Assert(natural.layout.toString(), "GA")
        @Assert(natural.row(0), naturalExpected)

        let stripped = transformPngRowsToGray8(
            decoded,
            transform,
            PngRowShapeTransform(true),
            [InvertAlpha, SwapAlpha]
        )
        let strippedExpected: Array<Byte> = [18, 48]
        @Assert(stripped.layout.toString(), "G")
        @Assert(stripped.row(0), strippedExpected)
    }

    @TestCase
    public func roundsUInt16BeforeExplicitReduction(): Unit {
        let rgba16 = makeGrayPng(
            UInt32(1), UInt8(16), UInt8(6), [], GRAY_RGBA16_ZLIB
        )
        let decoded = decodePngNonInterlaced(rgba16)
        let transform = PngRgbToGrayTransform()

        let rows16 = transformPngRowsToGray16(decoded, transform)
        let expected16: Array<UInt16> = [UInt16(700), UInt16(0x0708)]
        @Assert(rows16.layout.toString(), "GA")
        @Assert(rows16.row(0), expected16)
        @Assert(rows16.hadNonGrayPixels, true)

        let stripped = transformPngRowsToGray8(decoded, Strip, transform)
        let stripExpected: Array<Byte> = [0x02, 0x07]
        @Assert(stripped.row(0), stripExpected)

        let scaled = transformPngRowsToGray8(decoded, Scale, transform)
        let scaleExpected: Array<Byte> = [0x03, 0x07]
        @Assert(scaled.row(0), scaleExpected)
    }

    @TestCase
    public func preservesRgbToGrayInvertAndSbitOrder(): Unit {
        let png = makeGrayPng(
            UInt32(2),
            UInt8(8),
            UInt8(2),
            [makeGrayChunk(PNG_CHUNK_sBIT, [5, 6, 7])],
            GRAY_RGB8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [
            UnshiftSignificantBits, InvertMonochrome, Bgr
        ]
        let rows = transformPngRowsToGray8(
            decodePngNonInterlaced(png), PngRgbToGrayTransform(), transforms
        )
        let expected: Array<Byte> = [59, 51]
        @Assert(rows.row(0), expected)
        @Assert(rows.metadata.hasSignificantBits, true)
        @Assert(rows.metadata.significantBits.green, UInt8(6))
    }

    @TestCase
    public func appliesAlphaInvertShiftAndSwapAfterGrayConversion(): Unit {
        let png = makeGrayPng(
            UInt32(2),
            UInt8(8),
            UInt8(6),
            [makeGrayChunk(PNG_CHUNK_sBIT, [5, 6, 7, 4])],
            GRAY_RGBA8_ZLIB
        )
        let transforms: Array<PngReadChannelTransform> = [
            SwapAlpha, UnshiftSignificantBits, InvertAlpha, InvertMonochrome
        ]
        let rows = transformPngRowsToGray8(
            decodePngNonInterlaced(png), PngRgbToGrayTransform(), transforms
        )
        let expected: Array<Byte> = [15, 63, 15, 62]
        @Assert(rows.layout.toString(), "AG")
        @Assert(rows.row(0), expected)
    }

    @TestCase
    public func keepsOrdinalsLimitsAndOwnershipStable(): Unit {
        @Assert(PixelXbgr.ordinalValue(), Int64(9))
        @Assert(PixelGray.ordinalValue(), Int64(10))
        @Assert(PixelGrayAlpha.ordinalValue(), Int64(11))
        @Assert(PixelAlphaGray.ordinalValue(), Int64(12))
        @Assert(PixelGrayx.ordinalValue(), Int64(13))
        @Assert(PixelXgray.ordinalValue(), Int64(14))
        @Assert(RgbToGrayMismatch.ordinalValue(), Int64(35))

        let png = makeGrayPng(
            UInt32(2), UInt8(8), UInt8(2), [], GRAY_RGB8_ZLIB
        )
        let decoded = decodePngNonInterlaced(png)
        let exact = transformPngRowsToGray8(
            decoded,
            PngReadLimits(
                UInt32(1024),
                UInt32(100),
                UInt32(100),
                UInt64(1024),
                UInt64(1024),
                UInt64(2)
            ),
            PngRgbToGrayTransform(),
            PngRowShapeTransform(false),
            []
        )
        let expected: Array<Byte> = [18, 48]
        let mutable = exact.row(0)
        mutable[0] = 0
        @Assert(exact.row(0), expected)

        try {
            transformPngRowsToGray8(
                decoded,
                PngReadLimits(
                    UInt32(1024),
                    UInt32(100),
                    UInt32(100),
                    UInt64(1024),
                    UInt64(1024),
                    UInt64(1)
                ),
                PngRgbToGrayTransform(),
                PngRowShapeTransform(false),
                []
            )
            @Fail("grayscale output limit should use the final channel count")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "DECODE_LIMIT_EXCEEDED")
        }
    }

    @TestCase
    public func projectsStatefulRgbToGraySetterIntoExistingRowCore(): Unit {
        let png = makeGrayPng(
            UInt32(2), UInt8(8), UInt8(2), [], GRAY_RGB8_ZLIB
        )
        let decoded = decodePngNonInterlaced(png)
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(
            state.setRgbToGrayFixed(Convert, UInt32(100000), UInt32(0)),
            true
        )
        let rows = transformPngRowsToGray8(decoded, state.rgbToGrayTransform())
        let expected: Array<Byte> = [10, 40]
        @Assert(rows.row(0), expected)
    }
}
