package libpng4cj.tests

import libpng4cj.*

private let ANCILLARY_RGBA_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private func joinAncillaryBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: UInt8(0))
    var index: Int64 = 0
    while (index < left.size) {
        out[index] = left[index]
        index += 1
    }
    index = 0
    while (index < right.size) {
        out[left.size + index] = right[index]
        index += 1
    }
    out
}

private func ancillaryBytes(bytes: Array<Byte>): Array<Byte> {
    bytes
}

private func writeAncillaryUInt16(value: UInt16): Array<Byte> {
    [UInt8(value >> UInt16(8)), UInt8(value & UInt16(0xff))]
}

private func appendAncillaryUInt16(bytes: Array<Byte>, value: UInt16): Array<Byte> {
    joinAncillaryBytes(bytes, writeAncillaryUInt16(value))
}

private func makeAncillaryChunk(chunkType: Array<Byte>, data: Array<Byte>): Array<Byte> {
    joinAncillaryBytes(
        joinAncillaryBytes(
            joinAncillaryBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makeAncillaryIhdr(): Array<Byte> {
    let data = Array<Byte>(13, repeat: UInt8(0))
    let width = writeUInt32Be(UInt32(2))
    let height = writeUInt32Be(UInt32(1))
    var index: Int64 = 0
    while (index < 4) {
        data[index] = width[index]
        data[index + 4] = height[index]
        index += 1
    }
    data[8] = UInt8(8)
    data[9] = UInt8(6)
    makeAncillaryChunk(PNG_CHUNK_IHDR, data)
}

private func makeAncillaryPng(
    beforeIdat: Array<Array<Byte>>,
    afterIdat: Array<Array<Byte>>
): Array<Byte> {
    var out = joinAncillaryBytes(PNG_SIGNATURE, makeAncillaryIhdr())
    var index: Int64 = 0
    while (index < beforeIdat.size) {
        out = joinAncillaryBytes(out, beforeIdat[index])
        index += 1
    }
    out = joinAncillaryBytes(out, makeAncillaryChunk(PNG_CHUNK_IDAT, ANCILLARY_RGBA_ZLIB))
    index = 0
    while (index < afterIdat.size) {
        out = joinAncillaryBytes(out, afterIdat[index])
        index += 1
    }
    joinAncillaryBytes(out, makeAncillaryChunk(PNG_CHUNK_IEND, []))
}

private func makeAncillaryPng(beforeIdat: Array<Array<Byte>>): Array<Byte> {
    makeAncillaryPng(beforeIdat, [])
}

private func makeMasteringDisplayData(): Array<Byte> {
    var out = Array<Byte>()
    out = appendAncillaryUInt16(out, UInt16(32000))
    out = appendAncillaryUInt16(out, UInt16(16500))
    out = appendAncillaryUInt16(out, UInt16(15000))
    out = appendAncillaryUInt16(out, UInt16(30000))
    out = appendAncillaryUInt16(out, UInt16(7500))
    out = appendAncillaryUInt16(out, UInt16(3000))
    out = appendAncillaryUInt16(out, UInt16(15635))
    out = appendAncillaryUInt16(out, UInt16(16450))
    out = joinAncillaryBytes(out, writeUInt32Be(UInt32(10_000_000)))
    joinAncillaryBytes(out, writeUInt32Be(UInt32(50)))
}

private func makeCalibrationData(): Array<Byte> {
    var out: Array<Byte> = [0x63, 0x61, 0x6c, 0x00]
    out = joinAncillaryBytes(out, writeUInt32Be(UInt32(0xffff_ffff)))
    out = joinAncillaryBytes(out, writeUInt32Be(UInt32(100)))
    out = joinAncillaryBytes(out, [0x00, 0x02, 0x6d, 0x00])
    out = joinAncillaryBytes(out, [0x31, 0x2e, 0x30, 0x00])
    joinAncillaryBytes(out, [0x32, 0x45, 0x31])
}

private func makeSuggestedPaletteData(name: Array<Byte>, depth: UInt8): Array<Byte> {
    var out = joinAncillaryBytes(name, [0x00, depth])
    if (depth == UInt8(8)) {
        out = joinAncillaryBytes(out, [10, 20, 30, 40])
        joinAncillaryBytes(out, writeAncillaryUInt16(UInt16(500)))
    } else {
        out = appendAncillaryUInt16(out, UInt16(1000))
        out = appendAncillaryUInt16(out, UInt16(2000))
        out = appendAncillaryUInt16(out, UInt16(3000))
        out = appendAncillaryUInt16(out, UInt16(4000))
        appendAncillaryUInt16(out, UInt16(600))
    }
}

private func expectAncillaryError(bytes: Array<Byte>, expected: PngErrorKind): Unit {
    try {
        decodePngNonInterlaced(bytes)
        @Fail("expected ancillary metadata decode to fail")
    } catch (e: PngFormatException) {
        @Assert(e.kind.toString(), expected.toString())
    }
}

private func expectDuplicateAncillary(chunkType: Array<Byte>, data: Array<Byte>): Unit {
    let chunk = makeAncillaryChunk(chunkType, data)
    expectAncillaryError(makeAncillaryPng([chunk, chunk]), DuplicateMetadata)
}

@Test
public class PngAncillaryMetadataTestSuite {
    @TestCase
    public func retainsAllRemainingAncillaryMetadataAcrossReadSurfaces(): Unit {
        let cicp = makeAncillaryChunk(PNG_CHUNK_cICP, [1, 13, 0, 1])
        let clli = makeAncillaryChunk(
            PNG_CHUNK_cLLI,
            joinAncillaryBytes(writeUInt32Be(UInt32(10_000)), writeUInt32Be(UInt32(5_000)))
        )
        let mdcv = makeAncillaryChunk(PNG_CHUNK_mDCV, makeMasteringDisplayData())
        let offsets = makeAncillaryChunk(
            PNG_CHUNK_oFFs,
            joinAncillaryBytes(
                joinAncillaryBytes(writeUInt32Be(UInt32(0xffff_fff9)), writeUInt32Be(UInt32(12))),
                [2]
            )
        )
        let calibration = makeAncillaryChunk(PNG_CHUNK_pCAL, makeCalibrationData())
        let scale = makeAncillaryChunk(
            PNG_CHUNK_sCAL,
            [0x01, 0x2e, 0x35, 0x00, 0x32, 0x45, 0x31]
        )
        let splt8 = makeAncillaryChunk(
            PNG_CHUNK_sPLT,
            makeSuggestedPaletteData([0x64, 0x69, 0x73, 0x70, 0x6c, 0x61, 0x79], UInt8(8))
        )
        let splt16 = makeAncillaryChunk(
            PNG_CHUNK_sPLT,
            makeSuggestedPaletteData([0x70, 0x72, 0x69, 0x6e, 0x74], UInt8(16))
        )
        let palette = makeAncillaryChunk(PNG_CHUNK_PLTE, [1, 2, 3, 4, 5, 6])
        let histogram = makeAncillaryChunk(PNG_CHUNK_hIST, [0, 9, 0, 10])
        let exifData: Array<Byte> = [0x49, 0x49, 0x2a, 0x00, 0x08, 0, 0, 0]
        let exif = makeAncillaryChunk(PNG_CHUNK_eXIf, exifData)
        let png = makeAncillaryPng(
            [cicp, clli, mdcv, offsets, calibration, scale, splt8, splt16, palette, histogram],
            [exif]
        )

        let metadata = decodePngNonInterlaced(png, RetainAncillary).metadata
        @Assert(metadata.hasCodingIndependentCodePoints, true)
        @Assert(metadata.codingIndependentCodePoints.colorPrimaries, UInt8(1))
        @Assert(metadata.codingIndependentCodePoints.transferFunction, UInt8(13))
        @Assert(metadata.codingIndependentCodePoints.fullRangeFlag, UInt8(1))
        @Assert(metadata.hasContentLightLevel, true)
        @Assert(metadata.contentLightLevel.maximumContentLightLevel, UInt32(10_000))
        @Assert(metadata.contentLightLevel.maximumFrameAverageLightLevel, UInt32(5_000))
        @Assert(metadata.hasMasteringDisplayColorVolume, true)
        @Assert(metadata.masteringDisplayColorVolume.chromaticities.redX, Int32(64_000))
        @Assert(metadata.masteringDisplayColorVolume.chromaticities.whiteY, Int32(32_900))
        @Assert(metadata.masteringDisplayColorVolume.maximumDisplayLuminance, UInt32(10_000_000))
        @Assert(metadata.hasImageOffset, true)
        @Assert(metadata.imageOffset.x, Int32(-7))
        @Assert(metadata.imageOffset.y, Int32(12))
        @Assert(metadata.imageOffset.unit, UInt8(2))
        @Assert(metadata.hasPixelCalibration, true)
        @Assert(metadata.pixelCalibration.purpose(), ancillaryBytes([0x63, 0x61, 0x6c]))
        @Assert(metadata.pixelCalibration.x0, Int32(-1))
        @Assert(metadata.pixelCalibration.x1, Int32(100))
        @Assert(metadata.pixelCalibration.units(), ancillaryBytes([0x6d]))
        @Assert(metadata.pixelCalibration.parameterCount(), Int64(2))
        @Assert(metadata.pixelCalibration.parameter(1), ancillaryBytes([0x32, 0x45, 0x31]))
        @Assert(metadata.hasPhysicalScale, true)
        @Assert(metadata.physicalScale.width(), ancillaryBytes([0x2e, 0x35]))
        @Assert(metadata.physicalScale.height(), ancillaryBytes([0x32, 0x45, 0x31]))
        @Assert(metadata.hasHistogram, true)
        @Assert(metadata.histogram(), [UInt16(9), UInt16(10)])
        @Assert(metadata.hasExif, true)
        @Assert(metadata.exif(), exifData)
        @Assert(metadata.suggestedPaletteCount(), Int64(2))
        @Assert(metadata.suggestedPalette(0).sampleDepth, UInt8(8))
        @Assert(metadata.suggestedPalette(0).entry(0).red, UInt16(10))
        @Assert(metadata.suggestedPalette(0).entry(0).frequency, UInt16(500))
        @Assert(metadata.suggestedPalette(1).sampleDepth, UInt8(16))
        @Assert(metadata.suggestedPalette(1).entry(0).blue, UInt16(3000))
        @Assert(metadata.unknownChunkCount(), Int64(0))

        @Assert(decodePngRgba8NonInterlaced(png).metadata.hasExif, true)
        @Assert(
            decodePngRgba16NonInterlaced(png).metadata.suggestedPaletteCount(),
            Int64(2)
        )
    }

    @TestCase
    public func returnsCopyOwnedAncillaryArrays(): Unit {
        let palette = makeAncillaryChunk(PNG_CHUNK_PLTE, [1, 2, 3])
        let histogram = makeAncillaryChunk(PNG_CHUNK_hIST, [0, 9])
        let calibration = makeAncillaryChunk(PNG_CHUNK_pCAL, makeCalibrationData())
        let splt = makeAncillaryChunk(
            PNG_CHUNK_sPLT,
            makeSuggestedPaletteData([0x6f, 0x77, 0x6e, 0x65, 0x64], UInt8(8))
        )
        let exifData: Array<Byte> = [0x4d, 0x4d, 0x00, 0x2a, 0, 0, 0, 8]
        let metadata = decodePngNonInterlaced(makeAncillaryPng(
            [calibration, splt, palette, histogram],
            [makeAncillaryChunk(PNG_CHUNK_eXIf, exifData)]
        )).metadata

        let mutableExif = metadata.exif()
        mutableExif[0] = UInt8(0)
        @Assert(metadata.exif(), exifData)
        let mutableHistogram = metadata.histogram()
        mutableHistogram[0] = UInt16(0)
        @Assert(metadata.histogram(), [UInt16(9)])
        let mutablePurpose = metadata.pixelCalibration.purpose()
        mutablePurpose[0] = UInt8(0)
        @Assert(metadata.pixelCalibration.purpose(), ancillaryBytes([0x63, 0x61, 0x6c]))
        let mutableParameters = metadata.pixelCalibration.parameters()
        mutableParameters[0][0] = UInt8(0)
        @Assert(metadata.pixelCalibration.parameter(0), ancillaryBytes([0x31, 0x2e, 0x30]))
        let mutableName = metadata.suggestedPalette(0).name()
        mutableName[0] = UInt8(0)
        @Assert(
            metadata.suggestedPalette(0).name(),
            ancillaryBytes([0x6f, 0x77, 0x6e, 0x65, 0x64])
        )
    }

    @TestCase
    public func rejectsDuplicateSingleInstanceAncillaryChunks(): Unit {
        expectDuplicateAncillary(PNG_CHUNK_cICP, [1, 13, 0, 1])
        expectDuplicateAncillary(
            PNG_CHUNK_cLLI,
            joinAncillaryBytes(writeUInt32Be(UInt32(1)), writeUInt32Be(UInt32(2)))
        )
        expectDuplicateAncillary(PNG_CHUNK_mDCV, makeMasteringDisplayData())
        expectDuplicateAncillary(PNG_CHUNK_eXIf, [0x49, 0x49, 0x2a, 0x00])
        expectDuplicateAncillary(PNG_CHUNK_oFFs, [0, 0, 0, 1, 0, 0, 0, 2, 0])
        expectDuplicateAncillary(PNG_CHUNK_pCAL, makeCalibrationData())
        expectDuplicateAncillary(PNG_CHUNK_sCAL, [1, 0x31, 0, 0x32])

        let palette = makeAncillaryChunk(PNG_CHUNK_PLTE, [1, 2, 3])
        let histogram = makeAncillaryChunk(PNG_CHUNK_hIST, [0, 1])
        expectAncillaryError(makeAncillaryPng([palette, histogram, histogram]), DuplicateMetadata)
    }

    @TestCase
    public func enforcesAncillaryOrderingAndAllowsExifAfterIdat(): Unit {
        let palette = makeAncillaryChunk(PNG_CHUNK_PLTE, [1, 2, 3])
        expectAncillaryError(
            makeAncillaryPng([palette, makeAncillaryChunk(PNG_CHUNK_cICP, [1, 13, 0, 1])]),
            MetadataOutOfOrder
        )
        expectAncillaryError(
            makeAncillaryPng([makeAncillaryChunk(PNG_CHUNK_hIST, [0, 1]), palette]),
            MetadataOutOfOrder
        )
        expectAncillaryError(
            makeAncillaryPng([], [makeAncillaryChunk(PNG_CHUNK_oFFs, [0, 0, 0, 1, 0, 0, 0, 2, 0])]),
            MetadataOutOfOrder
        )
        expectAncillaryError(
            makeAncillaryPng([], [makeAncillaryChunk(PNG_CHUNK_pCAL, makeCalibrationData())]),
            MetadataOutOfOrder
        )
        expectAncillaryError(
            makeAncillaryPng([], [makeAncillaryChunk(PNG_CHUNK_sCAL, [1, 0x31, 0, 0x32])]),
            MetadataOutOfOrder
        )
        expectAncillaryError(
            makeAncillaryPng([], [makeAncillaryChunk(
                PNG_CHUNK_sPLT,
                makeSuggestedPaletteData([0x70], UInt8(8))
            )]),
            MetadataOutOfOrder
        )

        let exif = makeAncillaryChunk(PNG_CHUNK_eXIf, [0x49, 0x49, 0x2a, 0x00])
        @Assert(decodePngNonInterlaced(makeAncillaryPng([], [exif])).metadata.hasExif, true)
    }

    @TestCase
    public func rejectsMalformedAncillaryFieldsAndLengths(): Unit {
        expectAncillaryError(
            makeAncillaryPng([makeAncillaryChunk(PNG_CHUNK_cICP, [1, 13, 1, 1])]),
            InvalidMetadata
        )
        expectAncillaryError(
            makeAncillaryPng([makeAncillaryChunk(PNG_CHUNK_cLLI, [0, 0, 0, 1])]),
            InvalidMetadata
        )
        expectAncillaryError(
            makeAncillaryPng([makeAncillaryChunk(PNG_CHUNK_mDCV, [0, 1])]),
            InvalidMetadata
        )
        expectAncillaryError(
            makeAncillaryPng([], [makeAncillaryChunk(PNG_CHUNK_eXIf, [0x49, 0x49, 0, 0])]),
            InvalidMetadata
        )
        let palette = makeAncillaryChunk(PNG_CHUNK_PLTE, [1, 2, 3, 4, 5, 6])
        expectAncillaryError(
            makeAncillaryPng([palette, makeAncillaryChunk(PNG_CHUNK_hIST, [0, 1])]),
            InvalidMetadata
        )
        expectAncillaryError(
            makeAncillaryPng([makeAncillaryChunk(PNG_CHUNK_oFFs, [0, 1])]),
            InvalidMetadata
        )

        let badCalibration = joinAncillaryBytes(
            makeCalibrationData(),
            [0x00, 0x33]
        )
        expectAncillaryError(
            makeAncillaryPng([makeAncillaryChunk(PNG_CHUNK_pCAL, badCalibration)]),
            InvalidMetadata
        )
        expectAncillaryError(
            makeAncillaryPng([makeAncillaryChunk(PNG_CHUNK_sCAL, [3, 0x31, 0, 0x32])]),
            InvalidMetadata
        )
        expectAncillaryError(
            makeAncillaryPng([makeAncillaryChunk(PNG_CHUNK_sCAL, [1, 0x30, 0, 0x32])]),
            InvalidMetadata
        )
        expectAncillaryError(
            makeAncillaryPng([makeAncillaryChunk(
                PNG_CHUNK_sPLT,
                makeSuggestedPaletteData([0x20, 0x62, 0x61, 0x64], UInt8(8))
            )]),
            InvalidMetadata
        )
        expectAncillaryError(
            makeAncillaryPng([makeAncillaryChunk(PNG_CHUNK_sPLT, [0x70, 0, 9, 1, 2, 3])]),
            InvalidMetadata
        )
    }

    @TestCase
    public func acceptsPcalFinalParameterWithOrWithoutChunkTerminator(): Unit {
        let unterminated = makeCalibrationData()
        let terminated = joinAncillaryBytes(unterminated, [UInt8(0)])

        @Assert(
            decodePngNonInterlaced(makeAncillaryPng([
                makeAncillaryChunk(PNG_CHUNK_pCAL, unterminated)
            ])).metadata.pixelCalibration.parameter(1),
            ancillaryBytes([0x32, 0x45, 0x31])
        )
        @Assert(
            decodePngNonInterlaced(makeAncillaryPng([
                makeAncillaryChunk(PNG_CHUNK_pCAL, terminated)
            ])).metadata.pixelCalibration.parameter(1),
            ancillaryBytes([0x32, 0x45, 0x31])
        )
    }
}
