package libpng4cj.tests

import libpng4cj.*

private let EXT_RGBA_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private let EXT_ICC_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x60, 0x68, 0x61, 0x00, 0x02, 0x26,
    0x20, 0xce, 0xcd, 0x2b, 0x29, 0x0a, 0x72, 0x77, 0x52, 0x88,
    0x88, 0x8c, 0x52, 0x60, 0x40, 0x02, 0x89, 0xc9, 0xc5, 0x05,
    0x0c, 0x78, 0xc1, 0xb7, 0x6b, 0x0c, 0x8c, 0x20, 0xfa, 0xb2,
    0x2e, 0x7e, 0x75, 0xd8, 0x01, 0x00, 0x46, 0x94, 0x08, 0xe2
]

private let EXT_BAD_ICC_SIGNATURE_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x60, 0x68, 0x61, 0x00, 0x02, 0x26,
    0x20, 0xce, 0xcd, 0x2b, 0x29, 0x0a, 0x72, 0x77, 0x52, 0x88,
    0x88, 0x8c, 0x52, 0x60, 0x40, 0x06, 0xc9, 0xc5, 0x05, 0x0c,
    0x78, 0xc1, 0xb7, 0x6b, 0x0c, 0x8c, 0x20, 0xfa, 0xb2, 0x2e,
    0x7e, 0x75, 0xd8, 0x01, 0x00, 0x22, 0x34, 0x08, 0x81
]

private let EXT_BAD_ICC_TAG_TABLE_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x60, 0x68, 0x61, 0x00, 0x02, 0x26,
    0x20, 0xce, 0xcd, 0x2b, 0x29, 0x0a, 0x72, 0x77, 0x52, 0x88,
    0x88, 0x8c, 0x52, 0x60, 0x40, 0x02, 0x89, 0xc9, 0xc5, 0x05,
    0x0c, 0x78, 0xc1, 0xb7, 0x6b, 0x0c, 0x8c, 0x20, 0xfa, 0xb2,
    0x2e, 0x7e, 0x75, 0x58, 0x01, 0x23, 0x00, 0x46, 0x95, 0x08,
    0xe3
]

private let EXT_ZTXT_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x4b, 0xce, 0xcf, 0x2d, 0x28, 0x4a, 0x2d, 0x2e,
    0x4e, 0x4d, 0x51, 0x28, 0x49, 0xad, 0x28, 0x01, 0x00, 0x31,
    0x50, 0x06, 0x1b
]

private let EXT_ITXT_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x7b, 0xb2, 0x63, 0xed, 0xb3, 0x69,
    0xed, 0x00, 0x10, 0x0f, 0x04, 0x4d
]

private let EXT_LIMIT_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x73, 0x74, 0xa4, 0x3d, 0x00, 0x00,
    0x02, 0xe9, 0x19, 0x65
]

private func joinExtendedBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
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

private func makeExtendedChunk(chunkType: Array<Byte>, data: Array<Byte>): Array<Byte> {
    joinExtendedBytes(
        joinExtendedBytes(
            joinExtendedBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makeExtendedIhdr(colorType: UInt8): Array<Byte> {
    let data = Array<Byte>(13, repeat: 0)
    let width = writeUInt32Be(UInt32(2))
    let height = writeUInt32Be(UInt32(1))
    var index: Int64 = 0
    while (index < 4) {
        data[index] = width[index]
        data[index + 4] = height[index]
        index += 1
    }
    data[8] = UInt8(8)
    data[9] = colorType
    makeExtendedChunk(PNG_CHUNK_IHDR, data)
}

private func makeExtendedPng(
    colorType: UInt8,
    beforeIdat: Array<Array<Byte>>,
    afterIdat: Array<Array<Byte>>
): Array<Byte> {
    var out = joinExtendedBytes(PNG_SIGNATURE, makeExtendedIhdr(colorType))
    var index: Int64 = 0
    while (index < beforeIdat.size) {
        out = joinExtendedBytes(out, beforeIdat[index])
        index += 1
    }
    out = joinExtendedBytes(out, makeExtendedChunk(PNG_CHUNK_IDAT, EXT_RGBA_ZLIB))
    index = 0
    while (index < afterIdat.size) {
        out = joinExtendedBytes(out, afterIdat[index])
        index += 1
    }
    joinExtendedBytes(out, makeExtendedChunk(PNG_CHUNK_IEND, []))
}

private func makeExtendedPng(
    beforeIdat: Array<Array<Byte>>,
    afterIdat: Array<Array<Byte>>
): Array<Byte> {
    makeExtendedPng(UInt8(6), beforeIdat, afterIdat)
}

private func makeExtendedPng(beforeIdat: Array<Array<Byte>>): Array<Byte> {
    makeExtendedPng(beforeIdat, [])
}

private func makeExtendedPngFromChunks(chunks: Array<Array<Byte>>): Array<Byte> {
    var out = PNG_SIGNATURE.clone()
    var index: Int64 = 0
    while (index < chunks.size) {
        out = joinExtendedBytes(out, chunks[index])
        index += 1
    }
    out
}

private func makeValidIccProfile(): Array<Byte> {
    let profile = Array<Byte>(132, repeat: 0)
    let length = writeUInt32Be(UInt32(132))
    var index: Int64 = 0
    while (index < 4) {
        profile[index] = length[index]
        index += 1
    }
    profile[8] = UInt8(2)
    profile[12] = UInt8(0x6d)
    profile[13] = UInt8(0x6e)
    profile[14] = UInt8(0x74)
    profile[15] = UInt8(0x72)
    profile[16] = UInt8(0x52)
    profile[17] = UInt8(0x47)
    profile[18] = UInt8(0x42)
    profile[19] = UInt8(0x20)
    profile[20] = UInt8(0x58)
    profile[21] = UInt8(0x59)
    profile[22] = UInt8(0x5a)
    profile[23] = UInt8(0x20)
    profile[36] = UInt8(0x61)
    profile[37] = UInt8(0x63)
    profile[38] = UInt8(0x73)
    profile[39] = UInt8(0x70)
    let d50: Array<Byte> = [
        0x00, 0x00, 0xf6, 0xd6, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0xd3, 0x2d
    ]
    index = 0
    while (index < d50.size) {
        profile[68 + index] = d50[index]
        index += 1
    }
    profile
}

private func makeIccChunk(compressed: Array<Byte>): Array<Byte> {
    makeExtendedChunk(
        PNG_CHUNK_iCCP,
        joinExtendedBytes([0x49, 0x43, 0x43, 0x00, 0x00], compressed)
    )
}

private func expectExtendedError(bytes: Array<Byte>, expected: PngErrorKind): Unit {
    try {
        decodePngNonInterlaced(bytes)
        @Fail("expected extended PNG metadata decode to fail")
    } catch (e: PngFormatException) {
        @Assert(e.kind.toString(), expected.toString())
    }
}

@Test
public class PngExtendedMetadataTestSuite {
    @TestCase
    public func retainsIccTextAndTimeAcrossReadSurfaces(): Unit {
        let text = makeExtendedChunk(
            PNG_CHUNK_tEXt,
            [0x54, 0x69, 0x74, 0x6c, 0x65, 0x00, 0x70, 0x6c, 0x61, 0x69, 0x6e]
        )
        let ztxt = makeExtendedChunk(
            PNG_CHUNK_zTXt,
            joinExtendedBytes([0x43, 0x6f, 0x6d, 0x6d, 0x65, 0x6e, 0x74, 0x00, 0x00], EXT_ZTXT_ZLIB)
        )
        let itxt = makeExtendedChunk(
            PNG_CHUNK_iTXt,
            [
                0x4e, 0x61, 0x6d, 0x65, 0x00, 0x00, 0x4d,
                0x65, 0x6e, 0x00, 0x4e, 0x61, 0x6d, 0x65,
                0x00, 0x75, 0x74, 0x66, 0x38
            ]
        )
        let compressedItxt = makeExtendedChunk(
            PNG_CHUNK_iTXt,
            joinExtendedBytes([0x44, 0x65, 0x73, 0x63, 0x00, 0x01, 0x00, 0x00, 0x00], EXT_ITXT_ZLIB)
        )
        let time = makeExtendedChunk(PNG_CHUNK_tIME, [0x07, 0xea, 0x07, 0x0f, 0x0c, 0x22, 0x3c])
        let png = makeExtendedPng(
            [makeIccChunk(EXT_ICC_ZLIB), text, ztxt, itxt],
            [compressedItxt, time]
        )

        let metadata = decodePngNonInterlaced(png).metadata
        let expectedIccName: Array<Byte> = [0x49, 0x43, 0x43]
        let expectedTitle: Array<Byte> = [0x54, 0x69, 0x74, 0x6c, 0x65]
        let expectedPlainText: Array<Byte> = [0x70, 0x6c, 0x61, 0x69, 0x6e]
        let expectedCompressedText: Array<Byte> = [
            0x63, 0x6f, 0x6d, 0x70, 0x72, 0x65, 0x73, 0x73,
            0x65, 0x64, 0x20, 0x74, 0x65, 0x78, 0x74
        ]
        let expectedLanguageTag: Array<Byte> = [0x65, 0x6e]
        let expectedTranslatedKeyword: Array<Byte> = [0x4e, 0x61, 0x6d, 0x65]
        let expectedUtf8Text: Array<Byte> = [0xe4, 0xb8, 0xad, 0xe6, 0x96, 0x87]
        @Assert(metadata.hasIccProfile, true)
        @Assert(metadata.iccProfile.name(), expectedIccName)
        @Assert(metadata.iccProfile.profile(), makeValidIccProfile())
        @Assert(metadata.textEntryCount(), Int64(4))
        @Assert(metadata.textEntry(0).kind.toString(), "LATIN1_UNCOMPRESSED")
        @Assert(metadata.textEntry(0).keyword(), expectedTitle)
        @Assert(metadata.textEntry(0).text(), expectedPlainText)
        @Assert(metadata.textEntry(1).kind.toString(), "LATIN1_COMPRESSED")
        @Assert(metadata.textEntry(1).text(), expectedCompressedText)
        @Assert(metadata.textEntry(2).kind.toString(), "UTF8_UNCOMPRESSED")
        @Assert(metadata.textEntry(2).languageTag(), expectedLanguageTag)
        @Assert(metadata.textEntry(2).translatedKeyword(), expectedTranslatedKeyword)
        @Assert(metadata.textEntry(3).kind.toString(), "UTF8_COMPRESSED")
        @Assert(metadata.textEntry(3).text(), expectedUtf8Text)
        @Assert(metadata.hasModificationTime, true)
        @Assert(metadata.modificationTime.year, UInt16(2026))
        @Assert(metadata.modificationTime.second, UInt8(60))

        let mutableProfile = metadata.iccProfile.profile()
        mutableProfile[0] = UInt8(0)
        @Assert(metadata.iccProfile.profile(), makeValidIccProfile())
        let mutableText = metadata.textEntry(0).text()
        mutableText[0] = UInt8(0)
        @Assert(metadata.textEntry(0).text(), expectedPlainText)

        @Assert(decodePngRgba8NonInterlaced(png).metadata.textEntryCount(), Int64(4))
        @Assert(decodePngRgba16NonInterlaced(png).metadata.hasIccProfile, true)
    }

    @TestCase
    public func appliesExplicitUnknownChunkPoliciesAndLocations(): Unit {
        let beforePalette = makeExtendedChunk([0x76, 0x70, 0x41, 0x67], [1])
        let palette = makeExtendedChunk(PNG_CHUNK_PLTE, [0, 0, 0])
        let afterPalette = makeExtendedChunk([0x76, 0x70, 0x41, 0x47], [2])
        let afterIdat = makeExtendedChunk([0x76, 0x70, 0x42, 0x67], [3])
        let png = makeExtendedPng([beforePalette, palette, afterPalette], [afterIdat])

        @Assert(decodePngNonInterlaced(png).metadata.unknownChunkCount(), Int64(0))
        let retained = decodePngNonInterlaced(png, RetainAncillary).metadata
        @Assert(retained.unknownChunkCount(), Int64(3))
        @Assert(retained.unknownChunk(0).location.toString(), "AFTER_IHDR")
        @Assert(retained.unknownChunk(1).location.toString(), "AFTER_PLTE")
        @Assert(retained.unknownChunk(2).location.toString(), "AFTER_IDAT")
        @Assert(retained.unknownChunk(0).isSafeToCopy(), true)
        @Assert(retained.unknownChunk(1).isSafeToCopy(), false)
        let mutablePayload = retained.unknownChunk(0).payload()
        mutablePayload[0] = UInt8(9)
        let expectedAncillaryPayload: Array<Byte> = [1]
        @Assert(retained.unknownChunk(0).payload(), expectedAncillaryPayload)
        let mutableType = retained.unknownChunk(0).chunkType()
        mutableType[0] = UInt8(0)
        let expectedAncillaryType: Array<Byte> = [0x76, 0x70, 0x41, 0x67]
        @Assert(retained.unknownChunk(0).chunkType(), expectedAncillaryType)
        @Assert(
            decodePngRgba8NonInterlaced(png, RetainAncillary).metadata.unknownChunkCount(),
            Int64(3)
        )
        @Assert(
            decodePngRgba16NonInterlaced(png, RetainAncillary).metadata.unknownChunkCount(),
            Int64(3)
        )

        let critical = makeExtendedPng([makeExtendedChunk([0x56, 0x70, 0x41, 0x67], [4])])
        expectExtendedError(critical, UnsupportedCriticalChunk)
        try {
            decodePngNonInterlaced(critical, RetainAncillary)
            @Fail("RetainAncillary must not retain unknown critical chunks")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "UNSUPPORTED_CRITICAL_CHUNK")
        }
        let retainedCritical = decodePngNonInterlaced(critical, RetainAll).metadata
        @Assert(retainedCritical.unknownChunkCount(), Int64(1))
        let expectedCriticalPayload: Array<Byte> = [4]
        @Assert(retainedCritical.unknownChunk(0).payload(), expectedCriticalPayload)
    }

    @TestCase
    public func rejectsIccOrderingPrefixesAndCompression(): Unit {
        let icc = makeIccChunk(EXT_ICC_ZLIB)
        expectExtendedError(makeExtendedPng([icc, icc]), DuplicateMetadata)
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_PLTE, [0, 0, 0]), icc]),
            MetadataOutOfOrder
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_iCCP, [0, 0, 1])]),
            InvalidIccProfile
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_iCCP, joinExtendedBytes([0x49, 0x00, 0x01], EXT_ICC_ZLIB))]),
            InvalidIccProfile
        )
        expectExtendedError(
            makeExtendedPng([makeIccChunk([1, 2, 3, 4])]),
            ZlibFailure
        )
        expectExtendedError(
            makeExtendedPng([makeIccChunk(joinExtendedBytes(EXT_ICC_ZLIB, [0]))]),
            TrailingCompressedData
        )
    }

    @TestCase
    public func rejectsInvalidIccProfileSecurityFieldsAndLimits(): Unit {
        let shortProfileCompressed: Array<Byte> = [0x78, 0x9c, 0x63, 0x60, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01]
        expectExtendedError(makeExtendedPng([makeIccChunk(shortProfileCompressed)]), InvalidIccProfile)

        expectExtendedError(
            makeExtendedPng([makeIccChunk(EXT_BAD_ICC_SIGNATURE_ZLIB)]),
            InvalidIccProfile
        )
        expectExtendedError(
            makeExtendedPng([makeIccChunk(EXT_BAD_ICC_TAG_TABLE_ZLIB)]),
            InvalidIccProfile
        )

        expectExtendedError(
            makeExtendedPng(UInt8(0), [makeIccChunk(EXT_ICC_ZLIB)], []),
            InvalidIccProfile
        )
        try {
            decodePngNonInterlaced(
                makeExtendedPng([makeIccChunk(EXT_ICC_ZLIB)]),
                PngReadLimits(UInt32(100), UInt32(100), UInt32(100))
            )
            @Fail("ICC decompressed profile limit should fail")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "DECODE_LIMIT_EXCEEDED")
        }
    }

    @TestCase
    public func rejectsMalformedCompressedAndInternationalText(): Unit {
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_tEXt, [0])]),
            InvalidTextMetadata
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_zTXt, [0, 0, 1])]),
            InvalidTextMetadata
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_zTXt, [0x4b, 0, 1, 1, 2])]),
            InvalidTextMetadata
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_zTXt, [0x4b, 0, 0, 1, 2])]),
            ZlibFailure
        )
        expectExtendedError(
            makeExtendedPng([
                makeExtendedChunk(
                    PNG_CHUNK_zTXt,
                    joinExtendedBytes([0x4b, 0x00, 0x00], joinExtendedBytes(EXT_ZTXT_ZLIB, [0]))
                )
            ]),
            TrailingCompressedData
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_iTXt, [0x4b, 0, 2, 0, 0, 0])]),
            InvalidTextMetadata
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_iTXt, [0x4b, 0, 1, 1, 0, 0, 1])]),
            InvalidTextMetadata
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_iTXt, [0x4b, 0, 0, 0, 0, 1])]),
            InvalidTextMetadata
        )
    }

    @TestCase
    public func enforcesCompressedTextLimit(): Unit {
        let png = makeExtendedPng([
            makeExtendedChunk(
                PNG_CHUNK_zTXt,
                joinExtendedBytes([0x4b, 0x00, 0x00], EXT_LIMIT_ZLIB)
            )
        ])
        try {
            decodePngNonInterlaced(
                png,
                PngReadLimits(UInt32(32), UInt32(100), UInt32(100))
            )
            @Fail("compressed text output limit should fail")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "DECODE_LIMIT_EXCEEDED")
        }
    }

    @TestCase
    public func validatesTimeAndEndsIdatSequence(): Unit {
        let validTime = makeExtendedChunk(PNG_CHUNK_tIME, [0x07, 0xea, 1, 1, 0, 0, 0])
        expectExtendedError(makeExtendedPng([], [validTime, validTime]), DuplicateMetadata)
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_tIME, [0, 1, 1])]),
            InvalidTimeMetadata
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_tIME, [0x07, 0xea, 13, 1, 0, 0, 0])]),
            InvalidTimeMetadata
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_tIME, [0x07, 0xea, 1, 0, 0, 0, 0])]),
            InvalidTimeMetadata
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_tIME, [0x07, 0xea, 1, 32, 0, 0, 0])]),
            InvalidTimeMetadata
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_tIME, [0x07, 0xea, 1, 1, 24, 0, 0])]),
            InvalidTimeMetadata
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_tIME, [0x07, 0xea, 1, 1, 0, 60, 0])]),
            InvalidTimeMetadata
        )
        expectExtendedError(
            makeExtendedPng([makeExtendedChunk(PNG_CHUNK_tIME, [0x07, 0xea, 1, 1, 0, 0, 61])]),
            InvalidTimeMetadata
        )

        let splitIdat = makeExtendedPngFromChunks([
            makeExtendedIhdr(UInt8(6)),
            makeExtendedChunk(PNG_CHUNK_IDAT, EXT_RGBA_ZLIB),
            validTime,
            makeExtendedChunk(PNG_CHUNK_IDAT, EXT_RGBA_ZLIB),
            makeExtendedChunk(PNG_CHUNK_IEND, [])
        ])
        expectExtendedError(splitIdat, NonConsecutiveIdat)
    }
}
