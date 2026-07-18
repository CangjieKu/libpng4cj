package libpng4cj.tests

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private class WriteSinkProbe {
    let contexts = ArrayList<PngWriteOutputContext>()
    let emissions = ArrayList<Array<Byte>>()
    var flushContext: ?PngWriteFlushContext = None
    var firstCount: Int64 = Int64(0)
    var secondCount: Int64 = Int64(0)
    var calls: Int64 = Int64(0)
    var flushCount: Int64 = Int64(0)

    func receive(context: PngWriteOutputContext, bytes: Array<Byte>): Unit {
        contexts.add(context)
        emissions.add(bytes.clone())
    }

    func flush(context: PngWriteFlushContext): Unit {
        flushCount += Int64(1)
        flushContext = Some(context)
    }

    func bytes(): Array<Byte> {
        let out = ArrayList<Byte>()
        for (emission in emissions) {
            for (value in emission) {
                out.add(value)
            }
        }
        out.toArray()
    }
}

private func expectWriteSinkFailure(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected PNG write sink operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

private func newSinkTestSession(limits: PngWriteLimits): PngWriteSession {
    let metadata = PngWriteMetadata()
    metadata.setGamma(UInt32(45455))
    PngWriteSession(
        UInt32(2), UInt32(2), UInt8(8), Grayscale,
        Array<Byte>(), metadata, WriteFilterAdaptive, Int32(6), limits
    )
}

private func sinkTestRows(): Array<Array<Byte>> {
    [[UInt8(1), UInt8(2)], [UInt8(3), UInt8(4)]]
}

@Test
public class PngWriteSinkTestSuite {
    @TestCase
    public func streamsMemoryEquivalentFramesAndFlushesAfterIend(): Unit {
        let limits = PngWriteLimits(
            UInt64(4096), UInt64(4096), UInt64(4096), UInt32(2)
        )
        let expected = newSinkTestSession(limits).write(sinkTestRows())
        let probe = WriteSinkProbe()
        let sink = PngWriteSink()
        sink.setWriteCallback({ context, bytes => probe.receive(context, bytes) })
        sink.setFlushCallback({ context => probe.flush(context) })
        let session = newSinkTestSession(limits)
        let result = session.writeTo(sinkTestRows(), sink)

        @Assert(session.state(), WriteCompleted)
        @Assert(probe.bytes(), expected)
        @Assert(result.bytesWritten, UInt64(expected.size))
        @Assert(result.emissionCount, UInt64(probe.contexts.size))
        @Assert(result.flushCount, UInt64(1))
        @Assert(probe.flushCount, Int64(1))
        @Assert(probe.contexts[0].kind, WriteOutputSignature)
        @Assert(probe.contexts[0].chunkType(), Array<Byte>())
        @Assert(probe.contexts[1].chunkType(), PNG_CHUNK_IHDR)
        @Assert(
            probe.contexts[probe.contexts.size - Int64(1)].chunkType(),
            PNG_CHUNK_IEND
        )
        @Assert(
            probe.contexts[probe.contexts.size - Int64(1)].finalOutput,
            true
        )

        var index: Int64 = Int64(0)
        while (index < probe.contexts.size) {
            let context = probe.contexts[index]
            @Assert(context.sequenceNumber, UInt64(index))
            if (index == Int64(0)) {
                @Assert(context.bytesBefore, UInt64(0))
            } else {
                @Assert(
                    context.bytesBefore,
                    probe.contexts[index - Int64(1)].bytesAfter
                )
            }
            index += Int64(1)
        }
        match (probe.flushContext) {
            case Some(context) =>
                @Assert(context.bytesWritten, result.bytesWritten)
                @Assert(context.emissionCount, result.emissionCount)
            case None => @Fail("expected final PNG sink flush")
        }
    }

    @TestCase
    public func ownsCallbackDataAndSupportsLiveReplacementAndIdentity(): Unit {
        let probe = WriteSinkProbe()
        let sink = PngWriteSink()
        let second: (PngWriteOutputContext, Array<Byte>) -> Unit = {
            context, bytes =>
                probe.secondCount += Int64(1)
                probe.receive(context, bytes)
        }
        let first: (PngWriteOutputContext, Array<Byte>) -> Unit = {
            context, bytes =>
                probe.firstCount += Int64(1)
                probe.receive(context, bytes)
                if (context.kind == WriteOutputChunk) {
                    let chunkType = context.chunkType()
                    chunkType[0] = UInt8(0)
                    @Assert(context.chunkType(), PNG_CHUNK_IHDR)
                    bytes[0] = UInt8(0)
                    sink.setWriteCallback(second)
                    sink.setFlushCallback({ context => probe.flush(context) })
                }
        }
        sink.setWriteCallback(first)
        sink.setFlushCallback({ _ => probe.calls += Int64(1) })
        let result = newSinkTestSession(PngWriteLimits()).writeTo(
            sinkTestRows(), sink
        )
        @Assert(probe.firstCount, Int64(2))
        @Assert(probe.secondCount, Int64(result.emissionCount) - Int64(2))
        @Assert(probe.flushCount, Int64(1))
        @Assert(probe.calls, Int64(0))
        @Assert(decodePngNonInterlaced(probe.bytes()).rows(), sinkTestRows())

        let identity = PngWriteSink()
        identity.setWriteCallback()
        identity.setFlushCallback()
        let identityResult = newSinkTestSession(PngWriteLimits()).writeTo(
            sinkTestRows(), identity
        )
        @Assert(identityResult.bytesWritten > UInt64(0), true)
        @Assert(identityResult.emissionCount > UInt64(0), true)
        @Assert(identityResult.flushCount, UInt64(1))
    }

    @TestCase
    public func marksSinkAndFlushExceptionsAsWriterFailure(): Unit {
        let sinkFailureProbe = WriteSinkProbe()
        let sinkFailure = PngWriteSink()
        sinkFailure.setWriteCallback({ _, _ =>
            throw PngFormatException(InvalidData, -1, "sink failure")
        })
        sinkFailure.setFlushCallback({ context => sinkFailureProbe.flush(context) })
        let sinkSession = newSinkTestSession(PngWriteLimits())
        expectWriteSinkFailure({ =>
            sinkSession.writeTo(sinkTestRows(), sinkFailure)
            ()
        }, InvalidData)
        @Assert(sinkSession.state(), WriteFailed)
        @Assert(sinkFailureProbe.flushCount, Int64(0))

        let flushFailureProbe = WriteSinkProbe()
        let flushFailure = PngWriteSink()
        flushFailure.setFlushCallback({ context =>
            flushFailureProbe.flush(context)
            throw PngFormatException(InvalidData, -1, "flush failure")
        })
        let flushSession = newSinkTestSession(PngWriteLimits())
        expectWriteSinkFailure({ =>
            flushSession.writeTo(sinkTestRows(), flushFailure)
            ()
        }, InvalidData)
        @Assert(flushSession.state(), WriteFailed)
        @Assert(flushFailureProbe.flushCount, Int64(1))
    }

    @TestCase
    public func rejectsReentrantCloseAndPreflightsLimitsBeforeEmission(): Unit {
        let reentrantSink = PngWriteSink()
        let reentrantSession = newSinkTestSession(PngWriteLimits())
        reentrantSink.setWriteCallback({ _, _ => reentrantSession.close() })
        expectWriteSinkFailure({ =>
            reentrantSession.writeTo(sinkTestRows(), reentrantSink)
            ()
        }, InvalidArgument)
        @Assert(reentrantSession.state(), WriteFailed)

        let reentrantWriteSink = PngWriteSink()
        let reentrantWriteSession = newSinkTestSession(PngWriteLimits())
        reentrantWriteSink.setWriteCallback({ _, _ =>
            reentrantWriteSession.write(sinkTestRows())
            ()
        })
        expectWriteSinkFailure({ =>
            reentrantWriteSession.writeTo(sinkTestRows(), reentrantWriteSink)
            ()
        }, InvalidArgument)
        @Assert(reentrantWriteSession.state(), WriteFailed)

        let reentrantFlushSink = PngWriteSink()
        let reentrantFlushSession = newSinkTestSession(PngWriteLimits())
        reentrantFlushSink.setFlushCallback({ _ => reentrantFlushSession.close() })
        expectWriteSinkFailure({ =>
            reentrantFlushSession.writeTo(sinkTestRows(), reentrantFlushSink)
            ()
        }, InvalidArgument)
        @Assert(reentrantFlushSession.state(), WriteFailed)

        let probe = WriteSinkProbe()
        let limitedSink = PngWriteSink()
        limitedSink.setWriteCallback({ _, _ => probe.calls += Int64(1) })
        let limitedSession = newSinkTestSession(
            PngWriteLimits(UInt64(4096), UInt64(4096), UInt64(45), UInt32(4))
        )
        expectWriteSinkFailure({ =>
            limitedSession.writeTo(sinkTestRows(), limitedSink)
            ()
        }, DecodeLimitExceeded)
        @Assert(probe.calls, Int64(0))
        @Assert(limitedSession.state(), WriteFailed)
    }
}
