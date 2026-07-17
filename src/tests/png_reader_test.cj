package libpng4cj.tests

import libpng4cj.*

private func appendBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
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

private func makeChunk(chunkType: Array<Byte>, data: Array<Byte>): Array<Byte> {
    let length = writeUInt32Be(UInt32(data.size))
    let crc = writeUInt32Be(pngChunkCrc32(chunkType, data))
    appendBytes(appendBytes(appendBytes(length, chunkType), data), crc)
}

private func makeCorruptChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    let chunk = makeChunk(chunkType, data)
    chunk[chunk.size - 1] = chunk[chunk.size - 1] ^ UInt8(1)
    chunk
}

private func makeIhdrData(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8,
    colorType: UInt8,
    compression: UInt8,
    filter: UInt8,
    interlace: UInt8
): Array<Byte> {
    let out = Array<Byte>(13, repeat: 0)
    let widthBytes = writeUInt32Be(width)
    let heightBytes = writeUInt32Be(height)
    var index: Int64 = 0
    while (index < 4) {
        out[index] = widthBytes[index]
        out[index + 4] = heightBytes[index]
        index += 1
    }
    out[8] = bitDepth
    out[9] = colorType
    out[10] = compression
    out[11] = filter
    out[12] = interlace
    out
}

private func makePngWithIhdr(data: Array<Byte>): Array<Byte> {
    appendBytes(PNG_SIGNATURE, makeChunk(PNG_CHUNK_IHDR, data))
}

private func expectIhdrError(bytes: Array<Byte>, expected: PngErrorKind): Unit {
    try {
        readPngIhdr(bytes)
        @Fail("expected PNG header parsing to fail")
    } catch (e: PngFormatException) {
        @Assert(e.kind.toString(), expected.toString())
    }
}

private func assertValidColorDepth(bitDepth: UInt8, colorType: UInt8, channels: UInt8): Unit {
    let data = makeIhdrData(UInt32(3), UInt32(2), bitDepth, colorType, UInt8(0), UInt8(0), UInt8(0))
    let ihdr = readPngIhdr(makePngWithIhdr(data))
    @Assert(ihdr.channels, channels)
    @Assert(ihdr.pixelDepth, UInt16(bitDepth) * UInt16(channels))
}

@Test
public class PngReaderTestSuite {
    @TestCase
    public func matchesVendoredPngtestIhdrOracle(): Unit {
        let upstreamHeader: Array<Byte> = [
            0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
            0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x5b, 0x00, 0x00, 0x00, 0x45,
            0x08, 0x06, 0x00, 0x00, 0x01, 0x52, 0xed, 0xaa, 0xe4
        ]
        let ihdr = readPngIhdr(upstreamHeader)
        @Assert(ihdr.width, UInt32(91))
        @Assert(ihdr.height, UInt32(69))
        @Assert(ihdr.bitDepth, UInt8(8))
        @Assert(ihdr.colorType.toString(), "TRUECOLOR_ALPHA")
        @Assert(ihdr.interlaceMethod.toString(), "ADAM7")
        @Assert(ihdr.rowBytes, UInt64(364))
    }

    @TestCase
    public func readsIhdrAndOwnsInput(): Unit {
        let data = makeIhdrData(UInt32(13), UInt32(7), UInt8(8), UInt8(6), UInt8(0), UInt8(0), UInt8(0))
        let png = makePngWithIhdr(data)
        let session = PngReadSession(png)
        png[0] = UInt8(0)

        let ihdr = session.readIhdr()
        @Assert(ihdr.width, UInt32(13))
        @Assert(ihdr.height, UInt32(7))
        @Assert(ihdr.colorType.toString(), "TRUECOLOR_ALPHA")
        @Assert(ihdr.channels, UInt8(4))
        @Assert(ihdr.pixelDepth, UInt16(32))
        @Assert(ihdr.rowBytes, UInt64(52))
        @Assert(session.position(), Int64(33))
        @Assert(session.remaining(), Int64(0))
    }

    @TestCase
    public func derivesPackedRowBytesAndAdam7(): Unit {
        let data = makeIhdrData(UInt32(13), UInt32(9), UInt8(1), UInt8(3), UInt8(0), UInt8(0), UInt8(1))
        let ihdr = readPngIhdr(makePngWithIhdr(data))
        @Assert(ihdr.colorType.toString(), "INDEXED")
        @Assert(ihdr.interlaceMethod.toString(), "ADAM7")
        @Assert(ihdr.channels, UInt8(1))
        @Assert(ihdr.pixelDepth, UInt16(1))
        @Assert(ihdr.rowBytes, UInt64(2))
    }

    @TestCase
    public func acceptsEveryPngColorDepthCombination(): Unit {
        assertValidColorDepth(UInt8(1), UInt8(0), UInt8(1))
        assertValidColorDepth(UInt8(2), UInt8(0), UInt8(1))
        assertValidColorDepth(UInt8(4), UInt8(0), UInt8(1))
        assertValidColorDepth(UInt8(8), UInt8(0), UInt8(1))
        assertValidColorDepth(UInt8(16), UInt8(0), UInt8(1))
        assertValidColorDepth(UInt8(8), UInt8(2), UInt8(3))
        assertValidColorDepth(UInt8(16), UInt8(2), UInt8(3))
        assertValidColorDepth(UInt8(1), UInt8(3), UInt8(1))
        assertValidColorDepth(UInt8(2), UInt8(3), UInt8(1))
        assertValidColorDepth(UInt8(4), UInt8(3), UInt8(1))
        assertValidColorDepth(UInt8(8), UInt8(3), UInt8(1))
        assertValidColorDepth(UInt8(8), UInt8(4), UInt8(2))
        assertValidColorDepth(UInt8(16), UInt8(4), UInt8(2))
        assertValidColorDepth(UInt8(8), UInt8(6), UInt8(4))
        assertValidColorDepth(UInt8(16), UInt8(6), UInt8(4))
    }

    @TestCase
    public func returnsCopyOwnedChunkPayload(): Unit {
        let data = makeIhdrData(UInt32(1), UInt32(1), UInt8(8), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
        let chunk = PngReadSession(makePngWithIhdr(data)).readNextChunk()
        let first = chunk.payload()
        first[0] = UInt8(0xff)
        let second = chunk.payload()
        @Assert(second[0], UInt8(0))
        @Assert(second[3], UInt8(1))
    }

    @TestCase
    public func rejectsInvalidSignatureMissingIhdrAndTruncation(): Unit {
        let badSignature: Array<Byte> = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x00]
        expectIhdrError(badSignature, InvalidSignature)
        expectIhdrError(PNG_SIGNATURE, MissingIhdr)
        expectIhdrError(appendBytes(PNG_SIGNATURE, [0x00, 0x00, 0x00]), TruncatedInput)
    }

    @TestCase
    public func rejectsInvalidChunkLengthTypeAndConfiguredLimit(): Unit {
        let highLength: Array<Byte> = [
            0x80, 0x00, 0x00, 0x00, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x00
        ]
        expectIhdrError(appendBytes(PNG_SIGNATURE, highLength), InvalidChunkLength)

        let badType: Array<Byte> = [
            0x00, 0x00, 0x00, 0x00, 0x49, 0x48, 0x31, 0x52,
            0x00, 0x00, 0x00, 0x00
        ]
        expectIhdrError(appendBytes(PNG_SIGNATURE, badType), InvalidChunkType)

        let data = makeIhdrData(UInt32(1), UInt32(1), UInt8(8), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
        let limits = PngReadLimits(UInt32(12), UInt32(100), UInt32(100))
        try {
            readPngIhdr(makePngWithIhdr(data), limits)
            @Fail("configured chunk limit should reject IHDR")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "CHUNK_TOO_LARGE")
        }
    }

    @TestCase
    public func rejectsCrcMismatchWithoutAdvancingCursor(): Unit {
        let data = makeIhdrData(UInt32(1), UInt32(1), UInt8(8), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
        let png = makePngWithIhdr(data)
        png[png.size - 1] = png[png.size - 1] ^ UInt8(1)
        let session = PngReadSession(png)
        try {
            session.readIhdr()
            @Fail("CRC mismatch should fail")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "CRC_MISMATCH")
            @Assert(session.position(), Int64(8))
        }
    }

    @TestCase
    public func preservesFrozenCrcActionIdentitiesAndReplacement(): Unit {
        @Assert(CrcDefault.ordinalValue(), Int64(0))
        @Assert(CrcErrorQuit.ordinalValue(), Int64(1))
        @Assert(CrcWarnDiscard.ordinalValue(), Int64(2))
        @Assert(CrcWarnUse.ordinalValue(), Int64(3))
        @Assert(CrcQuietUse.ordinalValue(), Int64(4))
        @Assert(CrcNoChange.ordinalValue(), Int64(5))

        let data = makeIhdrData(
            UInt32(1), UInt32(1), UInt8(8), UInt8(0), UInt8(0), UInt8(0), UInt8(0)
        )
        let session = PngReadSession(makePngWithIhdr(data))
        @Assert(session.criticalCrcAction(), CrcErrorQuit)
        @Assert(session.ancillaryCrcAction(), CrcWarnDiscard)
        session.setCrcAction(CrcWarnUse, CrcQuietUse)
        @Assert(session.criticalCrcAction(), CrcWarnUse)
        @Assert(session.ancillaryCrcAction(), CrcQuietUse)
        session.setCrcAction(CrcNoChange, CrcNoChange)
        @Assert(session.criticalCrcAction(), CrcWarnUse)
        @Assert(session.ancillaryCrcAction(), CrcQuietUse)
        session.setCrcAction(CrcWarnDiscard, CrcDefault)
        @Assert(session.criticalCrcAction(), CrcErrorQuit)
        @Assert(session.ancillaryCrcAction(), CrcWarnDiscard)
        @Assert(session.invalidCriticalDiscardWarning(), true)
        @Assert(session.crcWarningCount(), Int64(1))
    }

    @TestCase
    public func usesOrRejectsCriticalCrcMismatchAsConfigured(): Unit {
        let data = makeIhdrData(
            UInt32(1), UInt32(1), UInt8(8), UInt8(0), UInt8(0), UInt8(0), UInt8(0)
        )
        let png = appendBytes(PNG_SIGNATURE, makeCorruptChunk(PNG_CHUNK_IHDR, data))

        let warningSession = PngReadSession(png)
        warningSession.setCrcAction(CrcWarnUse, CrcNoChange)
        let warningChunk = warningSession.readNextChunk()
        @Assert(warningChunk.crcValid, false)
        @Assert(warningSession.crcWarningCount(), Int64(1))
        @Assert(warningSession.position(), Int64(33))

        let quietSession = PngReadSession(png)
        quietSession.setCrcAction(CrcQuietUse, CrcNoChange)
        let quietChunk = quietSession.readNextChunk()
        @Assert(quietChunk.crcValid, false)
        @Assert(quietSession.crcWarningCount(), Int64(0))
        @Assert(quietSession.crcQuietUseCount(), Int64(1))

        let errorSession = PngReadSession(png)
        try {
            errorSession.readNextChunk()
            @Fail("default critical CRC action should reject corrupt IHDR")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "CRC_MISMATCH")
            @Assert(errorSession.position(), Int64(8))
        }
    }

    @TestCase
    public func discardsUsesOrRejectsAncillaryCrcMismatch(): Unit {
        let data = makeIhdrData(
            UInt32(1), UInt32(1), UInt8(8), UInt8(0), UInt8(0), UInt8(0), UInt8(0)
        )
        let ancillaryType: Array<Byte> = [0x76, 0x70, 0x41, 0x67]
        var png = makePngWithIhdr(data)
        png = appendBytes(png, makeCorruptChunk(ancillaryType, [1, 2, 3]))
        png = appendBytes(png, makeChunk(PNG_CHUNK_IEND, []))

        let discardSession = PngReadSession(png)
        discardSession.readIhdr()
        let afterDiscard = discardSession.readNextChunk()
        @Assert(afterDiscard.isType(PNG_CHUNK_IEND), true)
        @Assert(discardSession.crcWarningCount(), Int64(1))
        @Assert(discardSession.crcDiscardCount(), Int64(1))

        let warningSession = PngReadSession(png)
        warningSession.setCrcAction(CrcNoChange, CrcWarnUse)
        warningSession.readIhdr()
        let warningChunk = warningSession.readNextChunk()
        @Assert(warningChunk.isType(ancillaryType), true)
        @Assert(warningChunk.crcValid, false)
        @Assert(warningSession.crcWarningCount(), Int64(1))

        let quietSession = PngReadSession(png)
        quietSession.setCrcAction(CrcNoChange, CrcQuietUse)
        quietSession.readIhdr()
        @Assert(quietSession.readNextChunk().crcValid, false)
        @Assert(quietSession.crcQuietUseCount(), Int64(1))

        let errorSession = PngReadSession(png)
        errorSession.setCrcAction(CrcNoChange, CrcErrorQuit)
        errorSession.readIhdr()
        try {
            errorSession.readNextChunk()
            @Fail("ancillary ERROR_QUIT should reject a CRC mismatch")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "CRC_MISMATCH")
            @Assert(errorSession.position(), Int64(33))
        }
    }

    @TestCase
    public func appliesAncillaryCrcPolicyThroughHighLevelDecode(): Unit {
        let data = makeIhdrData(
            UInt32(1), UInt32(1), UInt8(8), UInt8(0), UInt8(0), UInt8(0), UInt8(0)
        )
        let ancillaryType: Array<Byte> = [0x76, 0x70, 0x41, 0x67]
        let compressed: Array<Byte> = [
            0x78, 0x9c, 0x63, 0x60, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01
        ]
        var png = makePngWithIhdr(data)
        png = appendBytes(png, makeCorruptChunk(ancillaryType, [7]))
        png = appendBytes(png, makeChunk(PNG_CHUNK_IDAT, compressed))
        png = appendBytes(png, makeChunk(PNG_CHUNK_IEND, []))

        let discarded = decodePngNonInterlaced(png)
        let expectedRow: Array<Byte> = [0]
        @Assert(discarded.row(0), expectedRow)
        let used = decodePngNonInterlaced(png, CrcNoChange, CrcWarnUse)
        @Assert(used.row(0), expectedRow)

        try {
            decodePngNonInterlaced(png, CrcNoChange, CrcErrorQuit)
            @Fail("high-level ancillary ERROR_QUIT should reject corrupt data")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "CRC_MISMATCH")
        }
    }

    @TestCase
    public func rejectsTruncatedChunkBeforeConfiguredCrcUse(): Unit {
        let data = makeIhdrData(
            UInt32(1), UInt32(1), UInt8(8), UInt8(0), UInt8(0), UInt8(0), UInt8(0)
        )
        let ancillaryType: Array<Byte> = [0x76, 0x70, 0x41, 0x67]
        let corruptChunk = makeCorruptChunk(ancillaryType, [1, 2, 3])
        let truncatedChunk = copyByteRange(
            corruptChunk,
            Int64(0),
            corruptChunk.size - 1
        )
        let png = appendBytes(makePngWithIhdr(data), truncatedChunk)
        let session = PngReadSession(png)
        session.setCrcAction(CrcNoChange, CrcQuietUse)
        session.readIhdr()

        try {
            session.readNextChunk()
            @Fail("truncated chunk framing should fail before CRC policy")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), "TRUNCATED_INPUT")
            @Assert(session.position(), Int64(33))
            @Assert(session.crcWarningCount(), Int64(0))
            @Assert(session.crcQuietUseCount(), Int64(0))
            @Assert(session.crcDiscardCount(), Int64(0))
        }
    }

    @TestCase
    public func enforcesIhdrPlacementAndUniqueness(): Unit {
        let iendType: Array<Byte> = [0x49, 0x45, 0x4e, 0x44]
        expectIhdrError(appendBytes(PNG_SIGNATURE, makeChunk(iendType, [])), IhdrOutOfOrder)

        let data = makeIhdrData(UInt32(1), UInt32(1), UInt8(8), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
        let twice = appendBytes(makePngWithIhdr(data), makeChunk(PNG_CHUNK_IHDR, data))
        let session = PngReadSession(twice)
        session.readIhdr()
        try {
            session.readNextChunk()
            @Fail("duplicate IHDR should fail")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "DUPLICATE_IHDR")
        }
    }

    @TestCase
    public func rejectsInvalidIhdrLengthDimensionsAndLimits(): Unit {
        expectIhdrError(makePngWithIhdr([0x00]), InvalidIhdr)
        expectIhdrError(
            makePngWithIhdr(makeIhdrData(UInt32(0), UInt32(1), UInt8(8), UInt8(0), UInt8(0), UInt8(0), UInt8(0))),
            InvalidIhdr
        )
        expectIhdrError(
            makePngWithIhdr(makeIhdrData(UInt32(0x8000_0000), UInt32(1), UInt8(8), UInt8(0), UInt8(0), UInt8(0), UInt8(0))),
            InvalidIhdr
        )

        let data = makeIhdrData(UInt32(101), UInt32(20), UInt8(8), UInt8(2), UInt8(0), UInt8(0), UInt8(0))
        let limits = PngReadLimits(UInt32(1024), UInt32(100), UInt32(100))
        try {
            readPngIhdr(makePngWithIhdr(data), limits)
            @Fail("dimension limit should reject IHDR")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "INVALID_IHDR")
        }
    }

    @TestCase
    public func rejectsInvalidIhdrColorDepthAndMethods(): Unit {
        expectIhdrError(
            makePngWithIhdr(makeIhdrData(UInt32(1), UInt32(1), UInt8(3), UInt8(0), UInt8(0), UInt8(0), UInt8(0))),
            InvalidIhdr
        )
        expectIhdrError(
            makePngWithIhdr(makeIhdrData(UInt32(1), UInt32(1), UInt8(4), UInt8(2), UInt8(0), UInt8(0), UInt8(0))),
            InvalidIhdr
        )
        expectIhdrError(
            makePngWithIhdr(makeIhdrData(UInt32(1), UInt32(1), UInt8(16), UInt8(3), UInt8(0), UInt8(0), UInt8(0))),
            InvalidIhdr
        )
        expectIhdrError(
            makePngWithIhdr(makeIhdrData(UInt32(1), UInt32(1), UInt8(8), UInt8(1), UInt8(0), UInt8(0), UInt8(0))),
            InvalidIhdr
        )
        expectIhdrError(
            makePngWithIhdr(makeIhdrData(UInt32(1), UInt32(1), UInt8(8), UInt8(2), UInt8(1), UInt8(0), UInt8(0))),
            InvalidIhdr
        )
        expectIhdrError(
            makePngWithIhdr(makeIhdrData(UInt32(1), UInt32(1), UInt8(8), UInt8(2), UInt8(0), UInt8(1), UInt8(0))),
            InvalidIhdr
        )
        expectIhdrError(
            makePngWithIhdr(makeIhdrData(UInt32(1), UInt32(1), UInt8(8), UInt8(2), UInt8(0), UInt8(0), UInt8(2))),
            InvalidIhdr
        )
    }

    @TestCase
    public func closedSessionRejectsFurtherReads(): Unit {
        let data = makeIhdrData(UInt32(1), UInt32(1), UInt8(8), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
        let session = PngReadSession(makePngWithIhdr(data))
        session.close()
        @Assert(session.isClosed(), true)
        try {
            session.readIhdr()
            @Fail("closed session should reject reads")
        } catch (e: PngFormatException) {
            @Assert(e.kind.toString(), "SESSION_CLOSED")
        }
    }
}
