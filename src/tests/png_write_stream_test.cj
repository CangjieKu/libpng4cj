package libpng4cj.tests

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private class IncrementalWriteProbe {
    let output = ArrayList<Byte>()
    var idatCount: UInt64 = UInt64(0)
    var flushCount: UInt64 = UInt64(0)

    func receive(context: PngWriteOutputContext, bytes: Array<Byte>): Unit {
        for (value in bytes) {
            output.add(value)
        }
        if (context.kind == WriteOutputChunk &&
            context.chunkType() == PNG_CHUNK_IDAT) {
            idatCount += UInt64(1)
        }
    }

    func flush(context: PngWriteFlushContext): Unit {
        if (context.bytesWritten == UInt64(output.size)) {
            flushCount += UInt64(1)
        }
    }
}

private func incrementalRows(): Array<Array<Byte>> {
    let first = Array<Byte>(Int64(64), repeat: UInt8(0))
    let second = Array<Byte>(Int64(64), repeat: UInt8(0))
    var index: Int64 = Int64(0)
    while (index < Int64(64)) {
        first[index] = UInt8((index * Int64(37) + Int64(11)) % Int64(251))
        second[index] = UInt8((index * Int64(53) + Int64(7)) % Int64(253))
        index += Int64(1)
    }
    [first, second]
}

private func incrementalMetadata(): PngWriteMetadata {
    let metadata = PngWriteMetadata()
    metadata.setGamma(UInt32(45455))
    metadata.setUnknownChunkPolicy(WriteUnknownAll)
    metadata.addUnknownChunk(PngUnknownChunk(
        [UInt8(0x76), UInt8(0x70), UInt8(0x41), UInt8(0x67)],
        [UInt8(9), UInt8(8), UInt8(7)], AfterIdat
    ))
    metadata
}

private func incrementalLimits(maxCompressedBytes: UInt64): PngWriteLimits {
    PngWriteLimits(
        UInt64(4096), UInt64(4096), maxCompressedBytes,
        UInt64(4096), UInt64(4096), UInt64(8192), UInt32(1)
    )
}

private func incrementalRowWriter(
    metadata: PngWriteMetadata,
    limits: PngWriteLimits
): PngRowWriteSession {
    PngRowWriteSession(
        UInt32(64), UInt32(2), UInt8(8), Grayscale,
        Array<Byte>(), metadata, WriteFilterAdaptive, Int32(6), limits
    )
}

private func expectIncrementalWriteFailure(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected incremental PNG write to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

@Test
public class PngWriteStreamTestSuite {
    @TestCase
    public func deflatesFragmentedInputIntoAValidBoundedStream(): Unit {
        let input: Array<Byte> = [
            UInt8(1), UInt8(2), UInt8(3), UInt8(4), UInt8(5), UInt8(6),
            UInt8(7), UInt8(8), UInt8(9), UInt8(10), UInt8(11), UInt8(12)
        ]
        let compressed = ArrayList<Byte>()
        let deflater = PngIncrementalDeflater(Int32(6), UInt64(256), Int64(2))
        deflater.push(copyByteRange(input, Int64(0), Int64(5)), { bytes =>
            for (value in bytes) {
                compressed.add(value)
            }
        })
        deflater.push(copyByteRange(input, Int64(5), Int64(7)), { bytes =>
            for (value in bytes) {
                compressed.add(value)
            }
        })
        deflater.finish({ bytes =>
            for (value in bytes) {
                compressed.add(value)
            }
        })
        @Assert(deflater.totalInputBytes(), UInt64(input.size))
        @Assert(deflater.totalOutputBytes(), UInt64(compressed.size))
        @Assert(deflater.finished(), true)
        deflater.close()
        @Assert(deflater.closed(), true)
        @Assert(
            inflatePngZlibExact(compressed.toArray(), input.size),
            input
        )
    }

    @TestCase
    public func emitsIdatDuringRowIntakeAndMatchesDeferredAndMemoryOutput(): Unit {
        let rows = incrementalRows()
        let limits = incrementalLimits(UInt64(4096))

        let memory = incrementalRowWriter(incrementalMetadata(), limits)
        let deferred = incrementalRowWriter(incrementalMetadata(), limits)
        for (row in rows) {
            memory.writeRow(row)
            deferred.writeRow(row)
        }
        let expected = memory.finish()

        let deferredProbe = IncrementalWriteProbe()
        let deferredSink = PngWriteSink()
        deferredSink.setWriteCallback({ context, bytes =>
            deferredProbe.receive(context, bytes)
        })
        deferredSink.setFlushCallback({ context => deferredProbe.flush(context) })
        deferred.finishTo(deferredSink)

        let early = incrementalRowWriter(incrementalMetadata(), limits)
        let earlyProbe = IncrementalWriteProbe()
        let earlySink = PngWriteSink()
        earlySink.setWriteCallback({ context, bytes =>
            earlyProbe.receive(context, bytes)
        })
        earlySink.setFlushCallback({ context => earlyProbe.flush(context) })
        early.startTo(earlySink)
        @Assert(earlyProbe.idatCount, UInt64(0))
        early.writeRow(rows[0])
        @Assert(earlyProbe.idatCount > UInt64(0), true)
        @Assert(earlyProbe.flushCount, UInt64(0))
        early.writeRow(rows[1])
        let result = early.finishTo()

        @Assert(deferredProbe.output.toArray(), expected)
        @Assert(earlyProbe.output.toArray(), expected)
        @Assert(result.bytesWritten, UInt64(expected.size))
        @Assert(result.flushCount, UInt64(1))
        @Assert(earlyProbe.flushCount, UInt64(1))
        let decoded = decodePngNonInterlaced(expected, RetainAll)
        @Assert(decoded.rows(), rows)
        @Assert(decoded.metadata.gamma, UInt32(45455))
        @Assert(decoded.metadata.unknownChunkCount(), Int64(1))
    }

    @TestCase
    public func marksStreamingSinkReentryAndCompressedLimitFailures(): Unit {
        let rows = incrementalRows()
        let session = incrementalRowWriter(
            incrementalMetadata(), incrementalLimits(UInt64(4096))
        )
        let sink = PngWriteSink()
        sink.setWriteCallback({ context, bytes =>
            if (context.kind == WriteOutputChunk &&
                context.chunkType() == PNG_CHUNK_IDAT) {
                session.close()
            }
        })
        session.startTo(sink)
        expectIncrementalWriteFailure({ => session.writeRow(rows[0]) }, InvalidArgument)
        @Assert(session.state(), WriteFailed)

        let limited = incrementalRowWriter(
            PngWriteMetadata(), incrementalLimits(UInt64(1))
        )
        let limitedSink = PngWriteSink()
        limited.startTo(limitedSink)
        expectIncrementalWriteFailure({ => limited.writeRow(rows[0]) }, DecodeLimitExceeded)
        @Assert(limited.state(), WriteFailed)
    }

    @TestCase
    public func startsAdam7SinkAndFinishesThroughPassSpooling(): Unit {
        let session = PngRowWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale, Adam7,
            Array<Byte>(), PngWriteMetadata(), WriteFilterNone, Int32(6),
            PngWriteLimits()
        )
        let probe = IncrementalWriteProbe()
        let sink = PngWriteSink()
        sink.setWriteCallback({ context, bytes => probe.receive(context, bytes) })
        sink.setFlushCallback({ context => probe.flush(context) })
        session.startTo(sink)
        @Assert(probe.output.size > Int64(0), true)
        @Assert(probe.idatCount, UInt64(0))
        session.writeRow([UInt8(17)])
        @Assert(probe.idatCount, UInt64(0))
        let result = session.finishTo()
        @Assert(probe.idatCount > UInt64(0), true)
        @Assert(probe.flushCount, UInt64(1))
        @Assert(result.bytesWritten, UInt64(probe.output.size))
        @Assert(decodePng(probe.output.toArray()).rows(), [[UInt8(17)]])

        let compatible = PngRowWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale, Adam7,
            Array<Byte>(), PngWriteMetadata(), WriteFilterNone, Int32(6),
            PngWriteLimits()
        )
        compatible.writeRow([UInt8(17)])
        @Assert(decodePng(compatible.finish()).rows(), [[UInt8(17)]])
    }
}
