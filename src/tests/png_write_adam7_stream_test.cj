package libpng4cj.tests

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private class Adam7StreamProbe {
    let bytes = ArrayList<Byte>()
    var idatCount: UInt64 = UInt64(0)
    var flushCount: UInt64 = UInt64(0)

    func receive(context: PngWriteOutputContext, emitted: Array<Byte>): Unit {
        for (value in emitted) {
            bytes.add(value)
        }
        if (context.kind == WriteOutputChunk &&
            context.chunkType() == PNG_CHUNK_IDAT) {
            idatCount += UInt64(1)
        }
    }

    func flush(context: PngWriteFlushContext): Unit {
        if (context.bytesWritten == UInt64(bytes.size)) {
            flushCount += UInt64(1)
        }
    }
}

private func adam7StreamSink(probe: Adam7StreamProbe): PngWriteSink {
    let sink = PngWriteSink()
    sink.setWriteCallback({ context, bytes => probe.receive(context, bytes) })
    sink.setFlushCallback({ context => probe.flush(context) })
    sink
}

private func adam7StreamControls(): PngWriteControlState {
    let controls = PngWriteControlState()
    controls.setFilters(true, true, true, true, true)
    controls.setCompressionLevel(Int32(4))
    controls.setCompressionMemoryLevel(Int32(7))
    controls.setCompressionWindowBits(Int32(13))
    controls.setCompressionStrategy(WriteCompressionFiltered)
    controls.setCompressionBufferBytes(Int64(3))
    controls
}

private func adam7StreamLimits(maxFilteredBytes: UInt64): PngWriteLimits {
    PngWriteLimits(
        UInt64(65536), maxFilteredBytes, UInt64(65536), UInt64(65536),
        UInt64(65536), UInt64(131072), UInt32(2)
    )
}

private func adam7GrayRows(): Array<Array<Byte>> {
    let rows = ArrayList<Array<Byte>>()
    var y: Int64 = Int64(0)
    while (y < Int64(9)) {
        let row = Array<Byte>(Int64(9), repeat: UInt8(0))
        var x: Int64 = Int64(0)
        while (x < Int64(9)) {
            row[x] = UInt8((y * Int64(29) + x * Int64(17)) % Int64(251))
            x += Int64(1)
        }
        rows.add(row)
        y += Int64(1)
    }
    rows.toArray()
}

private func adam7PackedRows(): Array<Array<Byte>> {
    [
        [UInt8(0xaa), UInt8(0x80)], [UInt8(0x55), UInt8(0x00)],
        [UInt8(0xf0), UInt8(0x80)], [UInt8(0x0f), UInt8(0x00)],
        [UInt8(0xcc), UInt8(0x80)], [UInt8(0x33), UInt8(0x00)],
        [UInt8(0x99), UInt8(0x80)], [UInt8(0x66), UInt8(0x00)],
        [UInt8(0xff), UInt8(0x80)]
    ]
}

private func adam7Rgb16Rows(): Array<Array<Byte>> {
    let rows = ArrayList<Array<Byte>>()
    var y: Int64 = Int64(0)
    while (y < Int64(9)) {
        let row = Array<Byte>(Int64(18), repeat: UInt8(0))
        var index: Int64 = Int64(0)
        while (index < row.size) {
            row[index] = UInt8((y * Int64(31) + index * Int64(7)) % Int64(256))
            index += Int64(1)
        }
        rows.add(row)
        y += Int64(1)
    }
    rows.toArray()
}

private func streamAdam7Rows(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8,
    colorType: PngColorType,
    rows: Array<Array<Byte>>,
    controls: PngWriteControlState,
    limits: PngWriteLimits
): Array<Byte> {
    let session = PngRowWriteSession(
        width, height, bitDepth, colorType, Adam7, Array<Byte>(),
        PngWriteMetadata(), controls, limits
    )
    let probe = Adam7StreamProbe()
    session.startTo(adam7StreamSink(probe))
    @Assert(probe.bytes.size > Int64(0), true)
    for (row in rows) {
        session.writeRow(row)
    }
    @Assert(probe.idatCount, UInt64(0))
    let result = session.finishTo()
    @Assert(probe.idatCount > UInt64(0), true)
    @Assert(probe.flushCount, UInt64(1))
    @Assert(result.bytesWritten, UInt64(probe.bytes.size))
    probe.bytes.toArray()
}

private func expectAdam7StreamFailure(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected Adam7 streaming write to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

@Test
public class PngWriteAdam7StreamTestSuite {
    @TestCase
    public func matchesMemoryDeferredAndEarlyOutput(): Unit {
        let rows = adam7GrayRows()
        let controls = adam7StreamControls()
        let limits = adam7StreamLimits(UInt64(65536))
        let memory = PngRowWriteSession(
            UInt32(9), UInt32(9), UInt8(8), Grayscale, Adam7,
            Array<Byte>(), PngWriteMetadata(), controls, limits
        )
        let deferred = PngRowWriteSession(
            UInt32(9), UInt32(9), UInt8(8), Grayscale, Adam7,
            Array<Byte>(), PngWriteMetadata(), controls, limits
        )
        for (row in rows) {
            memory.writeRow(row)
            deferred.writeRow(row)
        }
        let expected = memory.finish()
        let deferredProbe = Adam7StreamProbe()
        deferred.finishTo(adam7StreamSink(deferredProbe))
        let early = streamAdam7Rows(
            UInt32(9), UInt32(9), UInt8(8), Grayscale, rows, controls, limits
        )
        @Assert(deferredProbe.bytes.toArray(), expected)
        @Assert(early, expected)
        @Assert(decodePng(early).rows(), rows)
    }

    @TestCase
    public func streamsPackedAndSixteenBitPassGeometry(): Unit {
        let controls = adam7StreamControls()
        let limits = adam7StreamLimits(UInt64(65536))
        let packedRows = adam7PackedRows()
        let packed = streamAdam7Rows(
            UInt32(9), UInt32(9), UInt8(1), Grayscale, packedRows,
            controls, limits
        )
        @Assert(
            packed,
            encodePngPackedAdam7(
                UInt32(9), UInt32(9), UInt8(1), Grayscale, packedRows,
                Array<Byte>(), PngWriteMetadata(), controls, limits
            )
        )
        @Assert(decodePng(packed).rows(), packedRows)

        let rgb16Rows = adam7Rgb16Rows()
        let rgb16 = streamAdam7Rows(
            UInt32(3), UInt32(9), UInt8(16), Truecolor, rgb16Rows,
            controls, limits
        )
        @Assert(
            rgb16,
            encodePngPackedAdam7(
                UInt32(3), UInt32(9), UInt8(16), Truecolor, rgb16Rows,
                Array<Byte>(), PngWriteMetadata(), controls, limits
            )
        )
        @Assert(decodePng(rgb16).rows(), rgb16Rows)
    }

    @TestCase
    public func preflightsSpoolLimitsAndStopsAfterSinkFailure(): Unit {
        let limited = PngRowWriteSession(
            UInt32(9), UInt32(9), UInt8(8), Grayscale, Adam7,
            Array<Byte>(), PngWriteMetadata(), adam7StreamControls(),
            adam7StreamLimits(UInt64(1))
        )
        let untouched = Adam7StreamProbe()
        expectAdam7StreamFailure(
            { => limited.startTo(adam7StreamSink(untouched)) },
            DecodeLimitExceeded
        )
        @Assert(untouched.bytes.size, Int64(0))
        @Assert(limited.state(), WriteFailed)

        let rows = adam7GrayRows()
        let failed = PngRowWriteSession(
            UInt32(9), UInt32(9), UInt8(8), Grayscale, Adam7,
            Array<Byte>(), PngWriteMetadata(), adam7StreamControls(),
            adam7StreamLimits(UInt64(65536))
        )
        let failureProbe = Adam7StreamProbe()
        let sink = PngWriteSink()
        sink.setWriteCallback({ context, _ =>
            if (context.kind == WriteOutputChunk &&
                context.chunkType() == PNG_CHUNK_IDAT) {
                throw PngFormatException(InvalidData, -1, "Adam7 sink failure")
            }
        })
        sink.setFlushCallback({ context => failureProbe.flush(context) })
        failed.startTo(sink)
        for (row in rows) {
            failed.writeRow(row)
        }
        expectAdam7StreamFailure({ =>
            failed.finishTo()
            ()
        }, InvalidData)
        @Assert(failed.state(), WriteFailed)
        @Assert(failureProbe.flushCount, UInt64(0))
    }
}
