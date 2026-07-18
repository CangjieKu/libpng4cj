package libpng4cj.tests

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private class RowWriteSinkProbe {
    let output = ArrayList<Byte>()
    var flushCount: UInt64 = UInt64(0)

    func receive(context: PngWriteOutputContext, bytes: Array<Byte>): Unit {
        for (value in bytes) {
            output.add(value)
        }
    }

    func flush(context: PngWriteFlushContext): Unit {
        if (context.bytesWritten == UInt64(output.size)) {
            flushCount += UInt64(1)
        }
    }
}

private func expectRowWriteFailure(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected row writer operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

private func rgbaRowWriter(interlaceMethod: PngInterlaceMethod): PngRowWriteSession {
    PngRowWriteSession(
        UInt32(2), UInt32(2), UInt8(8), TruecolorAlpha, interlaceMethod,
        Array<Byte>(), PngWriteMetadata(), WriteFilterAdaptive, Int32(6),
        PngWriteLimits()
    )
}

@Test
public class PngWriteRowsTestSuite {
    @TestCase
    public func acceptsCopyOwnedRowsAndFinishesNonInterlacedOutput(): Unit {
        let metadata = PngWriteMetadata()
        metadata.setUnknownChunkPolicy(WriteUnknownAll)
        metadata.addUnknownChunk(PngUnknownChunk(
            [UInt8(0x76), UInt8(0x70), UInt8(0x41), UInt8(0x67)],
            [UInt8(9), UInt8(8)], AfterIhdr
        ))
        let session = PngRowWriteSession(
            UInt32(2), UInt32(2), UInt8(8), TruecolorAlpha,
            Array<Byte>(), metadata, WriteFilterNone, Int32(6), PngWriteLimits()
        )
        metadata.setUnknownChunkPolicy(WriteUnknownSafeToCopy)

        let first: Array<Byte> = [
            UInt8(255), UInt8(0), UInt8(0), UInt8(255),
            UInt8(0), UInt8(255), UInt8(0), UInt8(255)
        ]
        let second: Array<Byte> = [
            UInt8(0), UInt8(0), UInt8(255), UInt8(255),
            UInt8(255), UInt8(255), UInt8(255), UInt8(255)
        ]
        session.writeRow(first)
        first[0] = UInt8(0)
        @Assert(session.expectedRowCount(), UInt32(2))
        @Assert(session.acceptedRowCount(), UInt32(1))
        @Assert(session.remainingRowCount(), UInt32(1))
        @Assert(session.expectedRowBytes(), UInt64(8))
        session.writeRow(second)

        let decoded = decodePngNonInterlaced(session.finish(), RetainAll)
        @Assert(session.state(), WriteCompleted)
        @Assert(decoded.rows()[0][0], UInt8(255))
        @Assert(decoded.metadata.unknownChunkCount(), Int64(1))
        @Assert(
            decoded.metadata.unknownChunk(0).payload(),
            [UInt8(9), UInt8(8)]
        )
    }

    @TestCase
    public func reusesAdam7PreparationAndMatchesCustomSinkOutput(): Unit {
        let expectedSession = rgbaRowWriter(Adam7)
        let sinkSession = rgbaRowWriter(Adam7)
        let rows: Array<Array<Byte>> = [
            [
                UInt8(1), UInt8(2), UInt8(3), UInt8(255),
                UInt8(4), UInt8(5), UInt8(6), UInt8(255)
            ],
            [
                UInt8(7), UInt8(8), UInt8(9), UInt8(255),
                UInt8(10), UInt8(11), UInt8(12), UInt8(255)
            ]
        ]
        for (row in rows) {
            expectedSession.writeRow(row)
            sinkSession.writeRow(row)
        }
        let expected = expectedSession.finish()

        let probe = RowWriteSinkProbe()
        let sink = PngWriteSink()
        sink.setWriteCallback({ context, bytes => probe.receive(context, bytes) })
        sink.setFlushCallback({ context => probe.flush(context) })
        let result = sinkSession.finishTo(sink)

        @Assert(probe.output.toArray(), expected)
        @Assert(result.bytesWritten, UInt64(expected.size))
        @Assert(result.flushCount, UInt64(1))
        @Assert(probe.flushCount, UInt64(1))
        @Assert(decodePng(expected).rows(), rows)
    }

    @TestCase
    public func validatesTransformSourceShapeBeforePackedFinalization(): Unit {
        let transforms = PngWriteTransformState(UInt8(2), Indexed)
        @Assert(transforms.setPacking(), true)
        let palette: Array<Byte> = [
            UInt8(0), UInt8(0), UInt8(0),
            UInt8(85), UInt8(85), UInt8(85),
            UInt8(170), UInt8(170), UInt8(170),
            UInt8(255), UInt8(255), UInt8(255)
        ]
        let session = PngRowWriteSession(
            UInt32(4), UInt32(1), UInt8(2), Indexed, palette,
            PngWriteMetadata(), transforms, WriteFilterNone, Int32(6),
            PngWriteLimits()
        )
        @Assert(session.expectedRowBytes(), UInt64(4))
        session.writeRow([UInt8(0), UInt8(1), UInt8(2), UInt8(3)])
        @Assert(
            decodePngNonInterlaced(session.finish()).rows(),
            [[UInt8(0x1b)]]
        )
    }

    @TestCase
    public func rejectsMalformedExcessAndEarlyFinishWithFailedState(): Unit {
        let malformed = rgbaRowWriter(PngInterlaceMethod.None)
        expectRowWriteFailure({ =>
            malformed.writeRow([UInt8(1)])
        }, InvalidArgument)
        @Assert(malformed.state(), WriteFailed)

        let early = rgbaRowWriter(PngInterlaceMethod.None)
        early.writeRow(Array<Byte>(Int64(8), repeat: UInt8(0)))
        expectRowWriteFailure({ =>
            early.finish()
            ()
        }, InvalidArgument)
        @Assert(early.state(), WriteFailed)

        let excess = PngRowWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale,
            Array<Byte>(), WriteFilterNone, Int32(6), PngWriteLimits()
        )
        excess.writeRow([UInt8(1)])
        expectRowWriteFailure({ =>
            excess.writeRow([UInt8(2)])
        }, InvalidArgument)
        @Assert(excess.state(), WriteFailed)
    }

    @TestCase
    public func rejectsReentrantMutationAndPostTerminalCalls(): Unit {
        let session = rgbaRowWriter(PngInterlaceMethod.None)
        session.writeRow(Array<Byte>(Int64(8), repeat: UInt8(0)))
        session.writeRow(Array<Byte>(Int64(8), repeat: UInt8(1)))
        let sink = PngWriteSink()
        sink.setWriteCallback({ context, bytes =>
            session.close()
        })
        expectRowWriteFailure({ =>
            session.finishTo(sink)
            ()
        }, InvalidArgument)
        @Assert(session.state(), WriteFailed)

        let completed = rgbaRowWriter(PngInterlaceMethod.None)
        completed.writeRow(Array<Byte>(Int64(8), repeat: UInt8(0)))
        completed.writeRow(Array<Byte>(Int64(8), repeat: UInt8(1)))
        completed.finish()
        expectRowWriteFailure({ =>
            completed.writeRow(Array<Byte>(Int64(8), repeat: UInt8(2)))
        }, InvalidArgument)
        completed.close()
        @Assert(completed.state(), WriteClosed)
        expectRowWriteFailure({ =>
            completed.finish()
            ()
        }, SessionClosed)
    }
}
