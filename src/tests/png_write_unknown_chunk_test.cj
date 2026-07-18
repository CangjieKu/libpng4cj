package libpng4cj.tests

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private let UNKNOWN_SAFE_ANCILLARY: Array<Byte> = [
    UInt8(0x76), UInt8(0x70), UInt8(0x41), UInt8(0x67)
]
private let UNKNOWN_UNSAFE_ANCILLARY: Array<Byte> = [
    UInt8(0x76), UInt8(0x70), UInt8(0x42), UInt8(0x47)
]
private let UNKNOWN_SAFE_CRITICAL: Array<Byte> = [
    UInt8(0x56), UInt8(0x50), UInt8(0x43), UInt8(0x67)
]
private let UNKNOWN_UNSAFE_CRITICAL: Array<Byte> = [
    UInt8(0x56), UInt8(0x50), UInt8(0x44), UInt8(0x47)
]

private class UnknownWriteSinkProbe {
    let output = ArrayList<Byte>()
    var emissionCount: UInt64 = UInt64(0)
    var flushCount: UInt64 = UInt64(0)

    func receive(context: PngWriteOutputContext, bytes: Array<Byte>): Unit {
        for (value in bytes) {
            output.add(value)
        }
        emissionCount += UInt64(1)
    }

    func flush(context: PngWriteFlushContext): Unit {
        if (context.bytesWritten == UInt64(output.size) &&
            context.emissionCount == emissionCount) {
            flushCount += UInt64(1)
        }
    }
}

private func unknownWritePalette(): Array<Byte> {
    [
        UInt8(0), UInt8(0), UInt8(0),
        UInt8(255), UInt8(255), UInt8(255)
    ]
}

private func newUnknownWriteSession(
    metadata: PngWriteMetadata,
    limits: PngWriteLimits
): PngWriteSession {
    PngWriteSession(
        UInt32(1), UInt32(1), UInt8(8), Indexed,
        unknownWritePalette(), metadata, WriteFilterNone, Int32(6), limits
    )
}

private func unknownWriteRows(): Array<Array<Byte>> {
    [[UInt8(0)]]
}

private func readWrittenChunkTypes(png: Array<Byte>): Array<Array<Byte>> {
    let types = ArrayList<Array<Byte>>()
    let session = PngReadSession(png)
    var complete: Bool = false
    while (!complete) {
        let chunk = session.readNextChunk()
        let chunkType = chunk.chunkType()
        types.add(chunkType)
        if (chunkType == PNG_CHUNK_IEND) {
            complete = true
        }
    }
    types.toArray()
}

private func writtenTypesContain(
    types: Array<Array<Byte>>,
    expected: Array<Byte>
): Bool {
    for (chunkType in types) {
        if (chunkType == expected) {
            return true
        }
    }
    false
}

private func expectUnknownWriteFailure(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected unknown chunk write to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

@Test
public class PngWriteUnknownChunkTestSuite {
    @TestCase
    public func writesFrozenRegionsAndRoundTripsRetainedUnknownChunks(): Unit {
        let metadata = PngWriteMetadata()
        metadata.setGamma(UInt32(45455))
        metadata.setUnknownChunkPolicy(WriteUnknownAll)

        let firstType = UNKNOWN_SAFE_ANCILLARY.clone()
        let firstPayload: Array<Byte> = [UInt8(1), UInt8(2), UInt8(3)]
        metadata.addUnknownChunk(PngUnknownChunk(
            firstType, firstPayload, AfterIhdr
        ))
        metadata.addUnknownChunk(PngUnknownChunk(
            UNKNOWN_UNSAFE_ANCILLARY, [UInt8(4), UInt8(5)], AfterPlte
        ))
        metadata.addUnknownChunk(PngUnknownChunk(
            [UInt8(0x76), UInt8(0x70), UInt8(0x45), UInt8(0x67)],
            [UInt8(6)], AfterIdat
        ))
        firstType[0] = UInt8(0)
        firstPayload[0] = UInt8(0)

        let stored = metadata.unknownChunk(0)
        let mutableStoredType = stored.chunkType()
        let mutableStoredPayload = stored.payload()
        mutableStoredType[0] = UInt8(0)
        mutableStoredPayload[0] = UInt8(0)
        @Assert(metadata.unknownChunkCount(), Int64(3))
        @Assert(metadata.unknownChunk(0).chunkType(), UNKNOWN_SAFE_ANCILLARY)
        @Assert(
            metadata.unknownChunk(0).payload(),
            [UInt8(1), UInt8(2), UInt8(3)]
        )

        let png = newUnknownWriteSession(metadata, PngWriteLimits()).write(
            unknownWriteRows()
        )
        let expectedTypes: Array<Array<Byte>> = [
            PNG_CHUNK_IHDR,
            UNKNOWN_SAFE_ANCILLARY,
            PNG_CHUNK_gAMA,
            PNG_CHUNK_PLTE,
            UNKNOWN_UNSAFE_ANCILLARY,
            PNG_CHUNK_IDAT,
            [UInt8(0x76), UInt8(0x70), UInt8(0x45), UInt8(0x67)],
            PNG_CHUNK_IEND
        ]
        @Assert(readWrittenChunkTypes(png), expectedTypes)

        let decoded = decodePngNonInterlaced(png, RetainAll)
        @Assert(decoded.metadata.unknownChunkCount(), Int64(3))
        @Assert(decoded.metadata.unknownChunk(0).location, AfterIhdr)
        @Assert(decoded.metadata.unknownChunk(1).location, AfterPlte)
        @Assert(decoded.metadata.unknownChunk(2).location, AfterIdat)

        let rewritten = newUnknownWriteSession(
            PngWriteMetadata(decoded.metadata, Indexed), PngWriteLimits()
        ).write(decoded.rows())
        let decodedAgain = decodePngNonInterlaced(rewritten, RetainAll)
        @Assert(decodedAgain.metadata.unknownChunkCount(), Int64(3))
        @Assert(
            decodedAgain.metadata.unknownChunk(1).payload(),
            [UInt8(4), UInt8(5)]
        )
    }

    @TestCase
    public func appliesSafeAncillaryAndAllUnknownPolicies(): Unit {
        let metadata = PngWriteMetadata()
        metadata.addUnknownChunk(PngUnknownChunk(
            UNKNOWN_SAFE_ANCILLARY, [UInt8(1)], AfterIhdr
        ))
        metadata.addUnknownChunk(PngUnknownChunk(
            UNKNOWN_UNSAFE_ANCILLARY, [UInt8(2)], AfterIhdr
        ))
        metadata.addUnknownChunk(PngUnknownChunk(
            UNKNOWN_SAFE_CRITICAL, [UInt8(3)], AfterIhdr
        ))
        metadata.addUnknownChunk(PngUnknownChunk(
            UNKNOWN_UNSAFE_CRITICAL, [UInt8(4)], AfterIhdr
        ))

        let safeTypes = readWrittenChunkTypes(
            newUnknownWriteSession(metadata, PngWriteLimits()).write(unknownWriteRows())
        )
        @Assert(writtenTypesContain(safeTypes, UNKNOWN_SAFE_ANCILLARY), true)
        @Assert(writtenTypesContain(safeTypes, UNKNOWN_UNSAFE_ANCILLARY), false)
        @Assert(writtenTypesContain(safeTypes, UNKNOWN_SAFE_CRITICAL), true)
        @Assert(writtenTypesContain(safeTypes, UNKNOWN_UNSAFE_CRITICAL), false)

        metadata.setUnknownChunkPolicy(WriteUnknownAncillary)
        let ancillaryTypes = readWrittenChunkTypes(
            newUnknownWriteSession(metadata, PngWriteLimits()).write(unknownWriteRows())
        )
        @Assert(writtenTypesContain(ancillaryTypes, UNKNOWN_SAFE_ANCILLARY), true)
        @Assert(writtenTypesContain(ancillaryTypes, UNKNOWN_UNSAFE_ANCILLARY), true)
        @Assert(writtenTypesContain(ancillaryTypes, UNKNOWN_SAFE_CRITICAL), false)
        @Assert(writtenTypesContain(ancillaryTypes, UNKNOWN_UNSAFE_CRITICAL), false)

        metadata.setUnknownChunkPolicy(WriteUnknownAll)
        let allTypes = readWrittenChunkTypes(
            newUnknownWriteSession(metadata, PngWriteLimits()).write(unknownWriteRows())
        )
        @Assert(writtenTypesContain(allTypes, UNKNOWN_SAFE_ANCILLARY), true)
        @Assert(writtenTypesContain(allTypes, UNKNOWN_UNSAFE_ANCILLARY), true)
        @Assert(writtenTypesContain(allTypes, UNKNOWN_SAFE_CRITICAL), true)
        @Assert(writtenTypesContain(allTypes, UNKNOWN_UNSAFE_CRITICAL), true)
    }

    @TestCase
    public func rejectsMalformedReservedRecognizedAndOverLimitChunks(): Unit {
        let invalidType = PngWriteMetadata()
        invalidType.addUnknownChunk(PngUnknownChunk(
            [UInt8(0x76), UInt8(0x31), UInt8(0x41), UInt8(0x67)],
            [UInt8(1)], AfterIhdr
        ))
        let invalidSession = newUnknownWriteSession(invalidType, PngWriteLimits())
        expectUnknownWriteFailure({ =>
            invalidSession.write(unknownWriteRows())
            ()
        }, InvalidChunkType)
        @Assert(invalidSession.state(), WriteFailed)

        let reservedType = PngWriteMetadata()
        reservedType.addUnknownChunk(PngUnknownChunk(
            [UInt8(0x76), UInt8(0x70), UInt8(0x61), UInt8(0x47)],
            [UInt8(1)], AfterIhdr
        ))
        expectUnknownWriteFailure({ =>
            newUnknownWriteSession(reservedType, PngWriteLimits()).write(
                unknownWriteRows()
            )
            ()
        }, InvalidChunkType)

        let recognizedType = PngWriteMetadata()
        recognizedType.addUnknownChunk(PngUnknownChunk(
            PNG_CHUNK_gAMA, writeUInt32Be(UInt32(45455)), AfterIhdr
        ))
        let recognizedProbe = UnknownWriteSinkProbe()
        let recognizedSink = PngWriteSink()
        recognizedSink.setWriteCallback({ context, bytes =>
            recognizedProbe.receive(context, bytes)
        })
        recognizedSink.setFlushCallback({ context => recognizedProbe.flush(context) })
        let recognizedSession = newUnknownWriteSession(
            recognizedType, PngWriteLimits()
        )
        expectUnknownWriteFailure({ =>
            recognizedSession.writeTo(unknownWriteRows(), recognizedSink)
            ()
        }, DuplicateMetadata)
        @Assert(recognizedSession.state(), WriteFailed)
        @Assert(recognizedProbe.emissionCount, UInt64(0))
        @Assert(recognizedProbe.flushCount, UInt64(0))

        let limitedMetadata = PngWriteMetadata()
        limitedMetadata.addUnknownChunk(PngUnknownChunk(
            UNKNOWN_SAFE_ANCILLARY,
            [UInt8(1), UInt8(2), UInt8(3)], AfterIhdr
        ))
        let limited = PngWriteLimits(
            UInt64(4096), UInt64(4096), UInt64(4096), UInt64(2),
            UInt64(4096), UInt64(4096), UInt32(4)
        )
        expectUnknownWriteFailure({ =>
            newUnknownWriteSession(limitedMetadata, limited).write(unknownWriteRows())
            ()
        }, DecodeLimitExceeded)
    }

    @TestCase
    public func keepsMemoryAndCustomSinkOutputIdentical(): Unit {
        let metadata = PngWriteMetadata()
        metadata.setUnknownChunkPolicy(WriteUnknownAll)
        metadata.addUnknownChunk(PngUnknownChunk(
            UNKNOWN_UNSAFE_ANCILLARY,
            [UInt8(9), UInt8(8), UInt8(7)], AfterPlte
        ))
        let memorySession = newUnknownWriteSession(metadata, PngWriteLimits())
        let sinkSession = newUnknownWriteSession(metadata, PngWriteLimits())
        metadata.setUnknownChunkPolicy(WriteUnknownSafeToCopy)
        metadata.addUnknownChunk(PngUnknownChunk(
            [UInt8(0x76), UInt8(0x70), UInt8(0x46), UInt8(0x67)],
            [UInt8(6)], AfterIdat
        ))
        let expected = memorySession.write(unknownWriteRows())
        let expectedTypes = readWrittenChunkTypes(expected)
        @Assert(
            writtenTypesContain(expectedTypes, UNKNOWN_UNSAFE_ANCILLARY), true
        )
        @Assert(
            writtenTypesContain(
                expectedTypes,
                [UInt8(0x76), UInt8(0x70), UInt8(0x46), UInt8(0x67)]
            ),
            false
        )

        let probe = UnknownWriteSinkProbe()
        let sink = PngWriteSink()
        sink.setWriteCallback({ context, bytes => probe.receive(context, bytes) })
        sink.setFlushCallback({ context => probe.flush(context) })
        let result = sinkSession.writeTo(unknownWriteRows(), sink)
        @Assert(probe.output.toArray(), expected)
        @Assert(result.bytesWritten, UInt64(expected.size))
        @Assert(result.emissionCount, probe.emissionCount)
        @Assert(result.flushCount, UInt64(1))
        @Assert(probe.flushCount, UInt64(1))
    }
}
