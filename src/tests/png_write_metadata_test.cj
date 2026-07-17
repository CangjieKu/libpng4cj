package libpng4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private func expectMetadataWriteFailure(action: () -> Unit, expected: PngErrorKind): Unit {
    try {
        action()
        @Fail("expected PNG metadata write operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

private func setTestUInt32(bytes: Array<Byte>, offset: Int64, value: UInt32): Unit {
    bytes[offset] = UInt8((value >> UInt32(24)) & UInt32(0xff))
    bytes[offset + 1] = UInt8((value >> UInt32(16)) & UInt32(0xff))
    bytes[offset + 2] = UInt8((value >> UInt32(8)) & UInt32(0xff))
    bytes[offset + 3] = UInt8(value & UInt32(0xff))
}

private func makeWriteMetadataIccProfile(): Array<Byte> {
    let profile = Array<Byte>(Int64(132), repeat: UInt8(0))
    setTestUInt32(profile, Int64(0), UInt32(132))
    profile[8] = UInt8(2)
    setTestUInt32(profile, Int64(12), UInt32(0x6d6e_7472))
    setTestUInt32(profile, Int64(16), UInt32(0x5247_4220))
    setTestUInt32(profile, Int64(20), UInt32(0x5859_5a20))
    setTestUInt32(profile, Int64(36), UInt32(0x6163_7370))
    setTestUInt32(profile, Int64(64), UInt32(0))
    setTestUInt32(profile, Int64(128), UInt32(0))
    profile
}

private func makeAllWriteMetadata(): PngWriteMetadata {
    let metadata = PngWriteMetadata()
    metadata.setTransparency(PngWriteTransparency(UInt16(7), UInt16(8), UInt16(9)))
    metadata.setGamma(UInt32(45455))
    metadata.setChromaticities(PngChromaticities(
        Int32(31270), Int32(32900), Int32(64000), Int32(33000),
        Int32(30000), Int32(60000), Int32(15000), Int32(6000)
    ))
    metadata.setSrgb(Saturation)
    metadata.setSignificantBits(PngSignificantBits(
        UInt8(0), UInt8(8), UInt8(7), UInt8(6), UInt8(0)
    ))
    metadata.setBackground(PngBackground(
        UInt8(0), UInt16(0), UInt16(10), UInt16(20), UInt16(30)
    ))
    metadata.setPhysicalDimensions(PngPhysicalDimensions(
        UInt32(3780), UInt32(3780), UInt8(1)
    ))
    metadata.setCodingIndependentCodePoints(PngCodingIndependentCodePoints(
        UInt8(1), UInt8(13), UInt8(0), UInt8(1)
    ))
    metadata.setContentLightLevel(PngContentLightLevel(UInt32(1000), UInt32(400)))
    metadata.setMasteringDisplayColorVolume(PngMasteringDisplayColorVolume(
        PngChromaticities(
            Int32(31270), Int32(32900), Int32(64000), Int32(33000),
            Int32(30000), Int32(60000), Int32(15000), Int32(6000)
        ),
        UInt32(10_000_000),
        UInt32(500)
    ))
    metadata.setIccProfile(PngIccProfile([UInt8(0x49), UInt8(0x43), UInt8(0x43)], makeWriteMetadataIccProfile()))
    metadata.setExif(
        [UInt8(0x49), UInt8(0x49), UInt8(0x2a), UInt8(0x00)],
        WriteAfterIdat
    )
    metadata.setHistogram([UInt16(9), UInt16(10)])
    metadata.setImageOffset(PngImageOffset(Int32(-4), Int32(7), UInt8(1)))
    metadata.setPixelCalibration(PngPixelCalibration(
        [UInt8(0x43), UInt8(0x61), UInt8(0x6c)],
        Int32(-2), Int32(8), UInt8(0),
        [UInt8(0x75)],
        [[UInt8(0x31)], [UInt8(0x32)]]
    ))
    metadata.setPhysicalScale(PngPhysicalScale(
        UInt8(1), [UInt8(0x31), UInt8(0x2e), UInt8(0x35)], [UInt8(0x32)]
    ))
    metadata.setModificationTime(PngModificationTime(
        UInt16(2026), UInt8(7), UInt8(17), UInt8(22), UInt8(30), UInt8(59)
    ), WriteAfterIdat)
    metadata.addSuggestedPalette(PngSuggestedPalette(
        [UInt8(0x50), UInt8(0x31)], UInt8(8),
        [PngSuggestedPaletteEntry(
            UInt16(1), UInt16(2), UInt16(3), UInt16(4), UInt16(5)
        )]
    ))
    metadata.addSuggestedPalette(PngSuggestedPalette(
        [UInt8(0x50), UInt8(0x32)], UInt8(16),
        [PngSuggestedPaletteEntry(
            UInt16(1000), UInt16(2000), UInt16(3000), UInt16(4000), UInt16(5000)
        )]
    ))
    metadata.addText(PngTextEntry(
        Latin1Uncompressed,
        [UInt8(0x41), UInt8(0x75), UInt8(0x74), UInt8(0x68), UInt8(0x6f), UInt8(0x72)],
        [UInt8(0x43), UInt8(0x61), UInt8(0x6e), UInt8(0x67), UInt8(0x6a), UInt8(0x69), UInt8(0x65)],
        Array<Byte>(), Array<Byte>()
    ), WriteBeforeIdat)
    metadata.addText(PngTextEntry(
        Utf8Compressed,
        [UInt8(0x54), UInt8(0x69), UInt8(0x74), UInt8(0x6c), UInt8(0x65)],
        [UInt8(0xe5), UInt8(0x85), UInt8(0x83), UInt8(0xe6), UInt8(0x95), UInt8(0xb0), UInt8(0xe6), UInt8(0x8d), UInt8(0xae)],
        [UInt8(0x7a), UInt8(0x68)],
        [UInt8(0xe6), UInt8(0xa0), UInt8(0x87), UInt8(0xe9), UInt8(0xa2), UInt8(0x98)]
    ), WriteAfterIdat)
    metadata
}

private func metadataPalette(): Array<Byte> {
    [
        UInt8(1), UInt8(2), UInt8(3),
        UInt8(4), UInt8(5), UInt8(6)
    ]
}

private func encodeAllMetadata(metadata: PngWriteMetadata): Array<Byte> {
    encodePngPacked(
        UInt32(1), UInt32(1), UInt8(8), Truecolor,
        [[UInt8(11), UInt8(12), UInt8(13)]],
        metadataPalette(), metadata,
        WriteFilterNone, Int32(6), PngWriteLimits()
    )
}

private func assertAllMetadata(metadata: PngReadMetadata): Unit {
    @Assert(metadata.hasTransparency, true)
    @Assert(metadata.transparentRed, UInt16(7))
    @Assert(metadata.transparentGreen, UInt16(8))
    @Assert(metadata.transparentBlue, UInt16(9))
    @Assert(metadata.hasGamma, true)
    @Assert(metadata.gamma, UInt32(45455))
    @Assert(metadata.hasChromaticities, true)
    @Assert(metadata.chromaticities.whiteX, Int32(31270))
    @Assert(metadata.hasSrgb, true)
    @Assert(metadata.srgbIntent, Saturation)
    @Assert(metadata.hasSignificantBits, true)
    @Assert(metadata.significantBits.green, UInt8(7))
    @Assert(metadata.hasBackground, true)
    @Assert(metadata.background.blue, UInt16(30))
    @Assert(metadata.hasPhysicalDimensions, true)
    @Assert(metadata.physicalDimensions.pixelsPerUnitX, UInt32(3780))
    @Assert(metadata.hasCodingIndependentCodePoints, true)
    @Assert(metadata.codingIndependentCodePoints.transferFunction, UInt8(13))
    @Assert(metadata.hasContentLightLevel, true)
    @Assert(metadata.contentLightLevel.maximumFrameAverageLightLevel, UInt32(400))
    @Assert(metadata.hasMasteringDisplayColorVolume, true)
    @Assert(metadata.masteringDisplayColorVolume.chromaticities.redX, Int32(64000))
    @Assert(metadata.hasIccProfile, true)
    @Assert(metadata.iccProfile.name(), [UInt8(0x49), UInt8(0x43), UInt8(0x43)])
    @Assert(metadata.iccProfile.profile(), makeWriteMetadataIccProfile())
    @Assert(metadata.hasExif, true)
    @Assert(metadata.exif(), [UInt8(0x49), UInt8(0x49), UInt8(0x2a), UInt8(0x00)])
    @Assert(metadata.hasHistogram, true)
    @Assert(metadata.histogram(), [UInt16(9), UInt16(10)])
    @Assert(metadata.hasImageOffset, true)
    @Assert(metadata.imageOffset.x, Int32(-4))
    @Assert(metadata.hasPixelCalibration, true)
    @Assert(metadata.pixelCalibration.parameters(), [[UInt8(0x31)], [UInt8(0x32)]])
    @Assert(metadata.hasPhysicalScale, true)
    @Assert(metadata.physicalScale.width(), [UInt8(0x31), UInt8(0x2e), UInt8(0x35)])
    @Assert(metadata.hasModificationTime, true)
    @Assert(metadata.modificationTime.second, UInt8(59))
    @Assert(metadata.suggestedPaletteCount(), Int64(2))
    @Assert(metadata.suggestedPalette(0).name(), [UInt8(0x50), UInt8(0x31)])
    @Assert(metadata.suggestedPalette(1).sampleDepth, UInt8(16))
    @Assert(metadata.textEntryCount(), Int64(2))
    @Assert(metadata.textEntry(0).kind, Latin1Uncompressed)
    @Assert(metadata.textEntry(1).kind, Utf8Compressed)
    @Assert(metadata.textEntry(1).languageTag(), [UInt8(0x7a), UInt8(0x68)])
}

@Test
public class PngWriteMetadataTestSuite {
    @TestCase
    public func emitsFrozenMetadataOrderAndValidCrcs(): Unit {
        let encoded = encodeAllMetadata(makeAllWriteMetadata())
        let reader = PngReadSession(encoded)
        let expected: Array<Array<Byte>> = [
            PNG_CHUNK_IHDR,
            PNG_CHUNK_sBIT,
            PNG_CHUNK_cLLI,
            PNG_CHUNK_mDCV,
            PNG_CHUNK_cICP,
            PNG_CHUNK_iCCP,
            PNG_CHUNK_sRGB,
            PNG_CHUNK_gAMA,
            PNG_CHUNK_cHRM,
            PNG_CHUNK_PLTE,
            PNG_CHUNK_tRNS,
            PNG_CHUNK_bKGD,
            PNG_CHUNK_hIST,
            PNG_CHUNK_oFFs,
            PNG_CHUNK_pCAL,
            PNG_CHUNK_sCAL,
            PNG_CHUNK_pHYs,
            PNG_CHUNK_sPLT,
            PNG_CHUNK_sPLT,
            PNG_CHUNK_tEXt,
            PNG_CHUNK_IDAT,
            PNG_CHUNK_tIME,
            PNG_CHUNK_iTXt,
            PNG_CHUNK_eXIf,
            PNG_CHUNK_IEND
        ]
        var index: Int64 = Int64(0)
        while (index < expected.size) {
            let chunk = reader.readNextChunk()
            @Assert(chunk.chunkType(), expected[index])
            @Assert(chunk.crcValid, true)
            index += Int64(1)
        }
        @Assert(reader.remaining(), Int64(0))
    }

    @TestCase
    public func roundTripsEveryTypedMetadataFamily(): Unit {
        let decoded = decodePngNonInterlaced(encodeAllMetadata(makeAllWriteMetadata()))
        @Assert(decoded.rows(), [[UInt8(11), UInt8(12), UInt8(13)]])
        @Assert(decoded.metadata.palette(), metadataPalette())
        assertAllMetadata(decoded.metadata)
    }

    @TestCase
    public func encodesColorTypeSpecificTransparencySignificanceAndBackground(): Unit {
        let indexed = PngWriteMetadata()
        indexed.setTransparency(PngWriteTransparency([UInt8(0), UInt8(128)]))
        indexed.setSignificantBits(PngSignificantBits(
            UInt8(0), UInt8(5), UInt8(6), UInt8(7), UInt8(0)
        ))
        indexed.setBackground(PngBackground(
            UInt8(1), UInt16(0), UInt16(0), UInt16(0), UInt16(0)
        ))
        indexed.setHistogram([UInt16(3), UInt16(4)])
        let indexedDecoded = decodePngNonInterlaced(encodeIndexedPngPacked(
            UInt32(2), UInt32(1), UInt8(1), [[UInt8(0x40)]], metadataPalette(), indexed
        ))
        @Assert(indexedDecoded.metadata.paletteAlpha(), [UInt8(0), UInt8(128)])
        @Assert(indexedDecoded.metadata.significantBits.red, UInt8(5))
        @Assert(indexedDecoded.metadata.background.index, UInt8(1))
        @Assert(indexedDecoded.metadata.histogram(), [UInt16(3), UInt16(4)])

        let grayscale = PngWriteMetadata()
        grayscale.setTransparency(PngWriteTransparency(UInt16(3)))
        grayscale.setSignificantBits(PngSignificantBits(
            UInt8(3), UInt8(0), UInt8(0), UInt8(0), UInt8(0)
        ))
        grayscale.setBackground(PngBackground(
            UInt8(0), UInt16(4), UInt16(0), UInt16(0), UInt16(0)
        ))
        let grayscaleDecoded = decodePngNonInterlaced(encodePngPacked(
            UInt32(1), UInt32(1), UInt8(4), Grayscale, [[UInt8(0x30)]], grayscale
        ))
        @Assert(grayscaleDecoded.metadata.transparentGray, UInt16(3))
        @Assert(grayscaleDecoded.metadata.significantBits.gray, UInt8(3))
        @Assert(grayscaleDecoded.metadata.background.gray, UInt16(4))

        let alphaSignificance = PngWriteMetadata()
        alphaSignificance.setSignificantBits(PngSignificantBits(
            UInt8(0), UInt8(8), UInt8(7), UInt8(6), UInt8(5)
        ))
        let alphaDecoded = decodePngNonInterlaced(encodePngPacked(
            UInt32(1), UInt32(1), UInt8(8), TruecolorAlpha,
            [[UInt8(1), UInt8(2), UInt8(3), UInt8(4)]], alphaSignificance
        ))
        @Assert(alphaDecoded.metadata.significantBits.alpha, UInt8(5))
    }

    @TestCase
    public func decodeWriteDecodeRetainsTypedMetadata(): Unit {
        let first = decodePngNonInterlaced(encodeAllMetadata(makeAllWriteMetadata()))
        let copied = PngWriteMetadata(first.metadata, first.ihdr.colorType)
        let secondBytes = encodePngPacked(
            first.ihdr.width, first.ihdr.height, first.ihdr.bitDepth, first.ihdr.colorType,
            first.rows(), first.metadata.palette(), copied,
            WriteFilterAdaptive, Int32(6), PngWriteLimits()
        )
        let second = decodePngNonInterlaced(secondBytes)
        @Assert(second.rows(), first.rows())
        @Assert(second.metadata.palette(), first.metadata.palette())
        assertAllMetadata(second.metadata)
    }

    @TestCase
    public func snapshotsCallerOwnedMetadataBeforeWrite(): Unit {
        let exif = [UInt8(0x49), UInt8(0x49), UInt8(0x2a), UInt8(0x00)]
        let text = [UInt8(0x6f), UInt8(0x6b)]
        let metadata = PngWriteMetadata()
        metadata.setExif(exif, WriteBeforeIdat)
        metadata.addText(PngTextEntry(
            Latin1Uncompressed, [UInt8(0x4b)], text, Array<Byte>(), Array<Byte>()
        ), WriteBeforeIdat)
        let writer = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale,
            Array<Byte>(), metadata, WriteFilterNone, Int32(6), PngWriteLimits()
        )
        exif[0] = UInt8(0)
        text[0] = UInt8(0)
        metadata.addText(PngTextEntry(
            Latin1Uncompressed, [UInt8(0x58)], [UInt8(0x59)], Array<Byte>(), Array<Byte>()
        ), WriteAfterIdat)

        let decoded = decodePngNonInterlaced(writer.write([[UInt8(7)]]))
        @Assert(decoded.metadata.exif(), [UInt8(0x49), UInt8(0x49), UInt8(0x2a), UInt8(0x00)])
        @Assert(decoded.metadata.textEntryCount(), Int64(1))
        @Assert(decoded.metadata.textEntry(0).text(), [UInt8(0x6f), UInt8(0x6b)])
    }

    @TestCase
    public func rejectsMalformedTypedMetadata(): Unit {
        let duplicate = PngWriteMetadata()
        duplicate.setGamma(UInt32(1))
        expectMetadataWriteFailure({ => duplicate.setGamma(UInt32(2)) }, DuplicateMetadata)

        let alphaTransparency = PngWriteMetadata()
        alphaTransparency.setTransparency(PngWriteTransparency(UInt16(1)))
        expectMetadataWriteFailure({ =>
            encodePngPacked(
                UInt32(1), UInt32(1), UInt8(8), GrayscaleAlpha,
                [[UInt8(1), UInt8(2)]], alphaTransparency
            ); ()
        }, InvalidTransparency)

        let invalidText = PngWriteMetadata()
        invalidText.addText(PngTextEntry(
            Latin1Compressed, [UInt8(0x20)], [UInt8(0)], Array<Byte>(), Array<Byte>()
        ), WriteBeforeIdat)
        expectMetadataWriteFailure({ =>
            encodePngPacked(
                UInt32(1), UInt32(1), UInt8(8), Grayscale, [[UInt8(1)]], invalidText
            ); ()
        }, InvalidTextMetadata)

        let invalidCalibration = PngWriteMetadata()
        invalidCalibration.setPixelCalibration(PngPixelCalibration(
            [UInt8(0x43)], Int32(0), Int32(1), UInt8(0), Array<Byte>(), [[UInt8(0x31)]]
        ))
        expectMetadataWriteFailure({ =>
            encodePngPacked(
                UInt32(1), UInt32(1), UInt8(8), Grayscale, [[UInt8(1)]], invalidCalibration
            ); ()
        }, InvalidMetadata)

        let invalidIcc = makeWriteMetadataIccProfile()
        invalidIcc[36] = UInt8(0)
        let invalidProfile = PngWriteMetadata()
        invalidProfile.setIccProfile(PngIccProfile([UInt8(0x49)], invalidIcc))
        expectMetadataWriteFailure({ =>
            encodePngPacked(
                UInt32(1), UInt32(1), UInt8(8), Truecolor,
                [[UInt8(1), UInt8(2), UInt8(3)]], invalidProfile
            ); ()
        }, InvalidIccProfile)
    }

    @TestCase
    public func enforcesRawCompressedAndFinalMetadataLimits(): Unit {
        let metadata = PngWriteMetadata()
        metadata.addText(PngTextEntry(
            Latin1Compressed,
            [UInt8(0x4b)],
            Array<Byte>(Int64(128), repeat: UInt8(0x41)),
            Array<Byte>(), Array<Byte>()
        ), WriteBeforeIdat)
        expectMetadataWriteFailure({ =>
            encodePngPacked(
                UInt32(1), UInt32(1), UInt8(8), Grayscale, [[UInt8(1)]],
                Array<Byte>(), metadata, WriteFilterNone, Int32(6),
                PngWriteLimits(
                    UInt64(4096), UInt64(4096), UInt64(32), UInt64(4096),
                    UInt64(4096), UInt32(1024)
                )
            ); ()
        }, DecodeLimitExceeded)
        expectMetadataWriteFailure({ =>
            encodePngPacked(
                UInt32(1), UInt32(1), UInt8(8), Grayscale, [[UInt8(1)]],
                Array<Byte>(), metadata, WriteFilterNone, Int32(6),
                PngWriteLimits(
                    UInt64(4096), UInt64(4096), UInt64(4096), UInt64(1),
                    UInt64(4096), UInt32(1024)
                )
            ); ()
        }, DecodeLimitExceeded)
        expectMetadataWriteFailure({ =>
            encodePngPacked(
                UInt32(1), UInt32(1), UInt8(8), Grayscale, [[UInt8(1)]],
                Array<Byte>(), metadata, WriteFilterNone, Int32(6),
                PngWriteLimits(
                    UInt64(4096), UInt64(4096), UInt64(4096), UInt64(4096),
                    UInt64(64), UInt32(1024)
                )
            ); ()
        }, DecodeLimitExceeded)
    }
}
