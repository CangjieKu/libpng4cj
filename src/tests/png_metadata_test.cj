package libpng4cj.tests

import libpng4cj.*

private let METADATA_RGBA_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private let METADATA_INDEXED_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x70, 0x00, 0x00, 0x00, 0x42, 0x00, 0x41
]

private func joinMetadataBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
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

private func makeMetadataChunk(chunkType: Array<Byte>, data: Array<Byte>): Array<Byte> {
    joinMetadataBytes(
        joinMetadataBytes(
            joinMetadataBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makeMetadataIhdr(bitDepth: UInt8, colorType: UInt8): Array<Byte> {
    let data = Array<Byte>(13, repeat: 0)
    let width = writeUInt32Be(UInt32(2))
    let height = writeUInt32Be(UInt32(1))
    var index: Int64 = 0
    while (index < 4) {
        data[index] = width[index]
        data[index + 4] = height[index]
        index += 1
    }
    data[8] = bitDepth
    data[9] = colorType
    makeMetadataChunk(PNG_CHUNK_IHDR, data)
}

private func makeMetadataPng(
    bitDepth: UInt8,
    colorType: UInt8,
    beforeIdat: Array<Array<Byte>>,
    afterIdat: Array<Array<Byte>>
): Array<Byte> {
    var out = joinMetadataBytes(PNG_SIGNATURE, makeMetadataIhdr(bitDepth, colorType))
    var index: Int64 = 0
    while (index < beforeIdat.size) {
        out = joinMetadataBytes(out, beforeIdat[index])
        index += 1
    }
    out = joinMetadataBytes(out, makeMetadataChunk(PNG_CHUNK_IDAT, METADATA_RGBA_ZLIB))
    index = 0
    while (index < afterIdat.size) {
        out = joinMetadataBytes(out, afterIdat[index])
        index += 1
    }
    joinMetadataBytes(out, makeMetadataChunk(PNG_CHUNK_IEND, []))
}

private func makeMetadataPng(beforeIdat: Array<Array<Byte>>): Array<Byte> {
    makeMetadataPng(UInt8(8), UInt8(6), beforeIdat, [])
}

private func makeIndexedMetadataPng(beforeIdat: Array<Array<Byte>>): Array<Byte> {
    var out = joinMetadataBytes(PNG_SIGNATURE, makeMetadataIhdr(UInt8(1), UInt8(3)))
    var index: Int64 = 0
    while (index < beforeIdat.size) {
        out = joinMetadataBytes(out, beforeIdat[index])
        index += 1
    }
    out = joinMetadataBytes(out, makeMetadataChunk(PNG_CHUNK_IDAT, METADATA_INDEXED_ZLIB))
    joinMetadataBytes(out, makeMetadataChunk(PNG_CHUNK_IEND, []))
}

private func appendMetadataUInt32(bytes: Array<Byte>, value: UInt32): Array<Byte> {
    joinMetadataBytes(bytes, writeUInt32Be(value))
}

private func standardChromaticities(last: UInt32): Array<Byte> {
    var out = Array<Byte>()
    out = appendMetadataUInt32(out, UInt32(31270))
    out = appendMetadataUInt32(out, UInt32(32900))
    out = appendMetadataUInt32(out, UInt32(64000))
    out = appendMetadataUInt32(out, UInt32(33000))
    out = appendMetadataUInt32(out, UInt32(30000))
    out = appendMetadataUInt32(out, UInt32(60000))
    out = appendMetadataUInt32(out, UInt32(15000))
    appendMetadataUInt32(out, last)
}

private func expectMetadataError(bytes: Array<Byte>, expected: PngErrorKind): Unit {
    try {
        decodePngNonInterlaced(bytes)
        @Fail("expected PNG metadata decode to fail")
    } catch (e: PngFormatException) {
        @Assert(e.kind.toString(), expected.toString())
    }
}

private func expectDuplicateMetadata(chunkType: Array<Byte>, data: Array<Byte>): Unit {
    let chunk = makeMetadataChunk(chunkType, data)
    expectMetadataError(makeMetadataPng([chunk, chunk]), DuplicateMetadata)
}

private func expectMetadataAfterPalette(chunkType: Array<Byte>, data: Array<Byte>): Unit {
    let palette = makeMetadataChunk(PNG_CHUNK_PLTE, [0, 0, 0])
    expectMetadataError(
        makeMetadataPng([palette, makeMetadataChunk(chunkType, data)]),
        MetadataOutOfOrder
    )
}

@Test
public class PngMetadataTestSuite {
    @TestCase
    public func retainsAllFixedMetadataAcrossReadSurfaces(): Unit {
        let gamma = makeMetadataChunk(PNG_CHUNK_gAMA, writeUInt32Be(UInt32(45455)))
        let chromaticities = makeMetadataChunk(
            PNG_CHUNK_cHRM,
            standardChromaticities(UInt32(0xffff_ffff))
        )
        let srgb = makeMetadataChunk(PNG_CHUNK_sRGB, [2])
        let significant = makeMetadataChunk(PNG_CHUNK_sBIT, [8, 7, 6, 5])
        let palette = makeMetadataChunk(PNG_CHUNK_PLTE, [0, 0, 0])
        let background = makeMetadataChunk(PNG_CHUNK_bKGD, [0, 10, 0, 20, 0, 30])
        let physical = makeMetadataChunk(
            PNG_CHUNK_pHYs,
            joinMetadataBytes(
                joinMetadataBytes(writeUInt32Be(UInt32(3780)), writeUInt32Be(UInt32(3781))),
                [7]
            )
        )
        let png = makeMetadataPng([
            gamma,
            chromaticities,
            srgb,
            significant,
            palette,
            background,
            physical
        ])

        let raw = decodePngNonInterlaced(png).metadata
        @Assert(raw.hasGamma, true)
        @Assert(raw.gamma, UInt32(45455))
        @Assert(raw.hasChromaticities, true)
        @Assert(raw.chromaticities.whiteX, Int32(31270))
        @Assert(raw.chromaticities.blueY, Int32(-1))
        @Assert(raw.hasSrgb, true)
        @Assert(raw.srgbIntent.toString(), "SATURATION")
        @Assert(raw.hasSignificantBits, true)
        @Assert(raw.significantBits.red, UInt8(8))
        @Assert(raw.significantBits.alpha, UInt8(5))
        @Assert(raw.hasBackground, true)
        @Assert(raw.background.red, UInt16(10))
        @Assert(raw.background.green, UInt16(20))
        @Assert(raw.background.blue, UInt16(30))
        @Assert(raw.hasPhysicalDimensions, true)
        @Assert(raw.physicalDimensions.pixelsPerUnitX, UInt32(3780))
        @Assert(raw.physicalDimensions.pixelsPerUnitY, UInt32(3781))
        @Assert(raw.physicalDimensions.unit, UInt8(7))

        let rgba8 = decodePngRgba8NonInterlaced(png).metadata
        let rgba16 = decodePngRgba16NonInterlaced(png).metadata
        @Assert(rgba8.gamma, UInt32(45455))
        @Assert(rgba8.background.blue, UInt16(30))
        @Assert(rgba16.srgbIntent.toString(), "SATURATION")
        @Assert(rgba16.physicalDimensions.unit, UInt8(7))
    }

    @TestCase
    public func rejectsDuplicateFixedMetadataChunks(): Unit {
        expectDuplicateMetadata(PNG_CHUNK_gAMA, writeUInt32Be(UInt32(0)))
        expectDuplicateMetadata(PNG_CHUNK_cHRM, standardChromaticities(UInt32(6000)))
        expectDuplicateMetadata(PNG_CHUNK_sRGB, [0])
        expectDuplicateMetadata(PNG_CHUNK_sBIT, [8, 8, 8, 8])
        expectDuplicateMetadata(PNG_CHUNK_bKGD, [0, 1, 0, 2, 0, 3])
        expectDuplicateMetadata(
            PNG_CHUNK_pHYs,
            joinMetadataBytes(joinMetadataBytes(writeUInt32Be(UInt32(1)), writeUInt32Be(UInt32(2))), [1])
        )
    }

    @TestCase
    public func retainsIndexedSignificanceAndBackground(): Unit {
        let png = makeIndexedMetadataPng([
            makeMetadataChunk(PNG_CHUNK_sBIT, [8, 7, 6]),
            makeMetadataChunk(PNG_CHUNK_PLTE, [10, 20, 30, 40, 50, 60]),
            makeMetadataChunk(PNG_CHUNK_bKGD, [1])
        ])
        let metadata = decodePngNonInterlaced(png).metadata
        @Assert(metadata.significantBits.red, UInt8(8))
        @Assert(metadata.significantBits.green, UInt8(7))
        @Assert(metadata.significantBits.blue, UInt8(6))
        @Assert(metadata.significantBits.alpha, UInt8(8))
        @Assert(metadata.background.index, UInt8(1))
        @Assert(metadata.background.red, UInt16(40))
        @Assert(metadata.background.green, UInt16(50))
        @Assert(metadata.background.blue, UInt16(60))
    }

    @TestCase
    public func enforcesPaletteAndIdatOrdering(): Unit {
        expectMetadataAfterPalette(PNG_CHUNK_gAMA, writeUInt32Be(UInt32(45455)))
        expectMetadataAfterPalette(PNG_CHUNK_cHRM, standardChromaticities(UInt32(6000)))
        expectMetadataAfterPalette(PNG_CHUNK_sRGB, [0])
        expectMetadataAfterPalette(PNG_CHUNK_sBIT, [8, 8, 8, 8])

        expectMetadataError(
            makeMetadataPng(UInt8(8), UInt8(6), [], [makeMetadataChunk(PNG_CHUNK_bKGD, [0, 1, 0, 2, 0, 3])]),
            MetadataOutOfOrder
        )
        expectMetadataError(
            makeMetadataPng(
                UInt8(8),
                UInt8(6),
                [makeMetadataChunk(PNG_CHUNK_gAMA, writeUInt32Be(UInt32(45455)))],
                [makeMetadataChunk(PNG_CHUNK_gAMA, writeUInt32Be(UInt32(45455)))]
            ),
            MetadataOutOfOrder
        )
        expectMetadataError(
            makeMetadataPng(
                UInt8(8),
                UInt8(6),
                [],
                [makeMetadataChunk(PNG_CHUNK_pHYs, [0, 0, 0, 1, 0, 0, 0, 2, 1])]
            ),
            MetadataOutOfOrder
        )
    }

    @TestCase
    public func rejectsInvalidFixedLengths(): Unit {
        expectMetadataError(makeMetadataPng([makeMetadataChunk(PNG_CHUNK_gAMA, [0, 0, 0])]), InvalidMetadata)
        expectMetadataError(makeMetadataPng([makeMetadataChunk(PNG_CHUNK_cHRM, Array<Byte>(31, repeat: 0))]), InvalidMetadata)
        expectMetadataError(makeMetadataPng([makeMetadataChunk(PNG_CHUNK_sRGB, [])]), InvalidMetadata)
        expectMetadataError(makeMetadataPng([makeMetadataChunk(PNG_CHUNK_sBIT, [8, 8, 8])]), InvalidMetadata)
        expectMetadataError(makeMetadataPng([makeMetadataChunk(PNG_CHUNK_bKGD, [0, 1])]), InvalidMetadata)
        expectMetadataError(makeMetadataPng([makeMetadataChunk(PNG_CHUNK_pHYs, Array<Byte>(8, repeat: 0))]), InvalidMetadata)
    }

    @TestCase
    public func rejectsInvalidColorMetadataValues(): Unit {
        expectMetadataError(
            makeMetadataPng([makeMetadataChunk(PNG_CHUNK_gAMA, writeUInt32Be(UInt32(0x8000_0000)))]),
            InvalidMetadata
        )
        let invalidChromaticities = joinMetadataBytes(
            writeUInt32Be(UInt32(0x8000_0000)),
            Array<Byte>(28, repeat: 0)
        )
        expectMetadataError(
            makeMetadataPng([makeMetadataChunk(PNG_CHUNK_cHRM, invalidChromaticities)]),
            InvalidMetadata
        )
        expectMetadataError(
            makeMetadataPng([makeMetadataChunk(PNG_CHUNK_sRGB, [4])]),
            InvalidMetadata
        )
    }

    @TestCase
    public func validatesSignificantBitsAgainstSourceDepth(): Unit {
        expectMetadataError(
            makeMetadataPng(UInt8(2), UInt8(0), [makeMetadataChunk(PNG_CHUNK_sBIT, [0])], []),
            InvalidMetadata
        )
        expectMetadataError(
            makeMetadataPng(UInt8(2), UInt8(0), [makeMetadataChunk(PNG_CHUNK_sBIT, [3])], []),
            InvalidMetadata
        )
        expectMetadataError(
            makeMetadataPng(UInt8(2), UInt8(0), [makeMetadataChunk(PNG_CHUNK_sBIT, [1, 1])], []),
            InvalidMetadata
        )
        expectMetadataError(
            makeMetadataPng(UInt8(1), UInt8(3), [makeMetadataChunk(PNG_CHUNK_sBIT, [9, 8, 8])], []),
            InvalidMetadata
        )
    }

    @TestCase
    public func validatesIndexedBackgroundAgainstPalette(): Unit {
        expectMetadataError(
            makeMetadataPng(UInt8(1), UInt8(3), [makeMetadataChunk(PNG_CHUNK_bKGD, [0])], []),
            MetadataOutOfOrder
        )
        expectMetadataError(
            makeMetadataPng(
                UInt8(1),
                UInt8(3),
                [
                    makeMetadataChunk(PNG_CHUNK_PLTE, [10, 20, 30]),
                    makeMetadataChunk(PNG_CHUNK_bKGD, [1])
                ],
                []
            ),
            InvalidMetadata
        )
        expectMetadataError(
            makeMetadataPng(UInt8(2), UInt8(0), [makeMetadataChunk(PNG_CHUNK_bKGD, [0, 4])], []),
            InvalidMetadata
        )
        expectMetadataError(
            makeMetadataPng(UInt8(8), UInt8(2), [makeMetadataChunk(PNG_CHUNK_bKGD, [1, 0, 0, 0, 0, 0])], []),
            InvalidMetadata
        )
    }
}
