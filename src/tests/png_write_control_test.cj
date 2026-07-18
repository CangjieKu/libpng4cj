package libpng4cj.tests

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private func appendWriteControlBytes(
    target: ArrayList<Byte>,
    bytes: Array<Byte>
): Unit {
    for (value in bytes) {
        target.add(value)
    }
}

private func writeControlIdatPayload(encoded: Array<Byte>): Array<Byte> {
    let reader = PngReadSession(encoded)
    let compressed = ArrayList<Byte>()
    var done = false
    while (!done) {
        let chunk = reader.readNextChunk()
        if (chunk.isType(PNG_CHUNK_IDAT)) {
            appendWriteControlBytes(compressed, chunk.payload())
        } else if (chunk.isType(PNG_CHUNK_IEND)) {
            done = true
        }
    }
    compressed.toArray()
}

private func inflateWriteControlRows(encoded: Array<Byte>): Array<Byte> {
    let decoded = decodePng(encoded)
    let expected = Int64(
        (decoded.ihdr.rowBytes + UInt64(1)) * UInt64(decoded.ihdr.height)
    )
    inflatePngZlibExact(writeControlIdatPayload(encoded), expected)
}

private func writeControlRows(): Array<Array<Byte>> {
    [
        [
            UInt8(3), UInt8(7), UInt8(11), UInt8(19), UInt8(23), UInt8(29),
            UInt8(31), UInt8(37), UInt8(41), UInt8(43), UInt8(47), UInt8(53)
        ],
        [
            UInt8(5), UInt8(8), UInt8(13), UInt8(21), UInt8(34), UInt8(55),
            UInt8(89), UInt8(144), UInt8(233), UInt8(121), UInt8(98), UInt8(76)
        ],
        [
            UInt8(2), UInt8(4), UInt8(8), UInt8(16), UInt8(32), UInt8(64),
            UInt8(128), UInt8(255), UInt8(127), UInt8(63), UInt8(31), UInt8(15)
        ]
    ]
}

private func configuredWriteControls(): PngWriteControlState {
    let controls = PngWriteControlState()
    controls.setFilters(true, true, true, false, true)
    controls.setFilterHeuristic(WriteHeuristicUnweighted)
    controls.setCompressionLevel(Int32(4))
    controls.setCompressionMemoryLevel(Int32(7))
    controls.setCompressionWindowBits(Int32(13))
    controls.setCompressionMethod(Int32(8))
    controls.setCompressionStrategy(WriteCompressionRle)
    controls.setCompressionBufferBytes(Int64(5))
    controls
}

private func expectWriteControlFailure(action: () -> Unit): Unit {
    try {
        action()
        @Fail("expected PNG write control mutation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, InvalidArgument)
    }
}

private class WriteControlSinkProbe {
    let bytes = ArrayList<Byte>()

    func receive(output: Array<Byte>): Unit {
        appendWriteControlBytes(bytes, output)
    }
}

private func writeControlSink(probe: WriteControlSinkProbe): PngWriteSink {
    let sink = PngWriteSink()
    sink.setWriteCallback({ _, bytes => probe.receive(bytes) })
    sink
}

@Test
public class PngWriteControlTestSuite {
    @TestCase
    public func appliesFilterSubsetsAndOnePixelFallbacks(): Unit {
        let subset = PngWriteControlState()
        subset.setFilters(false, true, false, false, true)
        let rows: Array<Array<Byte>> = [
            [UInt8(10), UInt8(20), UInt8(30)],
            [UInt8(12), UInt8(22), UInt8(32)]
        ]
        let encoded = encodePngPacked(
            UInt32(3), UInt32(2), UInt8(8), Grayscale, rows,
            Array<Byte>(), PngWriteMetadata(), subset, PngWriteLimits()
        )
        let filtered = inflateWriteControlRows(encoded)
        @Assert(
            filtered[0] == PNG_FILTER_SUB || filtered[0] == PNG_FILTER_PAETH,
            true
        )
        @Assert(
            filtered[4] == PNG_FILTER_SUB || filtered[4] == PNG_FILTER_PAETH,
            true
        )
        @Assert(decodePngNonInterlaced(encoded).rows(), rows)

        let narrow = PngWriteControlState()
        narrow.setFilter(WriteFilterSub)
        let narrowEncoded = encodePngPacked(
            UInt32(1), UInt32(3), UInt8(8), Grayscale,
            [[UInt8(1)], [UInt8(2)], [UInt8(3)]],
            Array<Byte>(), PngWriteMetadata(), narrow, PngWriteLimits()
        )
        let narrowFiltered = inflateWriteControlRows(narrowEncoded)
        @Assert(narrowFiltered[0], PNG_FILTER_NONE)
        @Assert(narrowFiltered[2], PNG_FILTER_NONE)
        @Assert(narrowFiltered[4], PNG_FILTER_NONE)

        let flat = PngWriteControlState()
        flat.setFilter(WriteFilterUp)
        let flatEncoded = encodePngPacked(
            UInt32(3), UInt32(1), UInt8(8), Grayscale,
            [[UInt8(1), UInt8(2), UInt8(3)]],
            Array<Byte>(), PngWriteMetadata(), flat, PngWriteLimits()
        )
        @Assert(inflateWriteControlRows(flatEncoded)[0], PNG_FILTER_NONE)
    }

    @TestCase
    public func defaultsPackedAndIndexedImagesToNoFilter(): Unit {
        let controls = PngWriteControlState()
        controls.setFilter(WriteFilterPaeth)
        controls.useDefaultFilters()
        let palette: Array<Byte> = [
            UInt8(0), UInt8(0), UInt8(0),
            UInt8(255), UInt8(255), UInt8(255)
        ]
        let rows: Array<Array<Byte>> = [[UInt8(0x55)], [UInt8(0xaa)]]
        let encoded = encodePngPacked(
            UInt32(8), UInt32(2), UInt8(1), Indexed, rows, palette,
            PngWriteMetadata(), controls, PngWriteLimits()
        )
        let filtered = inflateWriteControlRows(encoded)
        @Assert(filtered[0], PNG_FILTER_NONE)
        @Assert(filtered[2], PNG_FILTER_NONE)
        @Assert(decodePngNonInterlaced(encoded).rows(), rows)
    }

    @TestCase
    public func acceptsEveryCompressionStrategyAndValidatesSetters(): Unit {
        let rows = writeControlRows()
        let strategies = [
            WriteCompressionDefault, WriteCompressionFiltered,
            WriteCompressionHuffmanOnly, WriteCompressionRle,
            WriteCompressionFixed
        ]
        for (strategy in strategies) {
            let controls = PngWriteControlState()
            controls.setFilter(WriteFilterAdaptive)
            controls.setCompressionLevel(Int32(9))
            controls.setCompressionMemoryLevel(Int32(1))
            controls.setCompressionWindowBits(Int32(8))
            controls.setCompressionMethod(Int32(8))
            controls.setCompressionStrategy(strategy)
            controls.setCompressionBufferBytes(Int64(3))
            let encoded = encodePngPacked(
                UInt32(4), UInt32(3), UInt8(8), Truecolor, rows,
                Array<Byte>(), PngWriteMetadata(), controls, PngWriteLimits()
            )
            @Assert(decodePngNonInterlaced(encoded).rows(), rows)
            @Assert(
                encoded,
                encodePngPacked(
                    UInt32(4), UInt32(3), UInt8(8), Truecolor, rows,
                    Array<Byte>(), PngWriteMetadata(), controls,
                    PngWriteLimits()
                )
            )
        }

        let automatic = PngWriteControlState()
        automatic.setFilter(WriteFilterNone)
        automatic.setCompressionStrategy(WriteCompressionFixed)
        automatic.useAutomaticCompressionStrategy()
        automatic.setCompressionBufferBytes(Int64(3))
        let ordinary = PngWriteControlState()
        ordinary.setFilter(WriteFilterNone)
        ordinary.setCompressionBufferBytes(Int64(3))
        @Assert(
            encodePngPacked(
                UInt32(4), UInt32(3), UInt8(8), Truecolor, rows,
                Array<Byte>(), PngWriteMetadata(), automatic, PngWriteLimits()
            ),
            encodePngPacked(
                UInt32(4), UInt32(3), UInt8(8), Truecolor, rows,
                Array<Byte>(), PngWriteMetadata(), ordinary, PngWriteLimits()
            )
        )

        let controls = PngWriteControlState()
        controls.setCompressionWindowBits(Int32(1))
        @Assert(controls.compressionWindowBits(), Int32(8))
        controls.setCompressionWindowBits(Int32(99))
        @Assert(controls.compressionWindowBits(), Int32(15))
        controls.setFilterHeuristic(WriteHeuristicUnweighted)
        @Assert(controls.filterHeuristic(), WriteHeuristicUnweighted)
        expectWriteControlFailure({ => controls.setFilters(false, false, false, false, false) })
        expectWriteControlFailure({ => controls.setCompressionLevel(Int32(10)) })
        expectWriteControlFailure({ => controls.setCompressionMemoryLevel(Int32(0)) })
        expectWriteControlFailure({ => controls.setCompressionMethod(Int32(7)) })
        expectWriteControlFailure({ => controls.setCompressionBufferBytes(Int64(0)) })
    }

    @TestCase
    public func freezesControlsAcrossAllWritePaths(): Unit {
        let rows = writeControlRows()
        let limits = PngWriteLimits(
            UInt64(4096), UInt64(4096), UInt64(4096), UInt64(4096),
            UInt64(4096), UInt64(16384), UInt32(2)
        )
        let controls = configuredWriteControls()
        let memory = PngWriteSession(
            UInt32(4), UInt32(3), UInt8(8), Truecolor,
            Array<Byte>(), PngWriteMetadata(), controls, limits
        )
        let sinkWriter = PngWriteSession(
            UInt32(4), UInt32(3), UInt8(8), Truecolor,
            Array<Byte>(), PngWriteMetadata(), controls, limits
        )
        let deferred = PngRowWriteSession(
            UInt32(4), UInt32(3), UInt8(8), Truecolor,
            Array<Byte>(), PngWriteMetadata(), controls, limits
        )
        let deferredSink = PngRowWriteSession(
            UInt32(4), UInt32(3), UInt8(8), Truecolor,
            Array<Byte>(), PngWriteMetadata(), controls, limits
        )
        let early = PngRowWriteSession(
            UInt32(4), UInt32(3), UInt8(8), Truecolor,
            Array<Byte>(), PngWriteMetadata(), controls, limits
        )

        controls.setFilter(WriteFilterNone)
        controls.setCompressionLevel(Int32(0))
        controls.setCompressionStrategy(WriteCompressionFixed)
        controls.setCompressionBufferBytes(Int64(64))

        let expected = memory.write(rows)
        let wholeProbe = WriteControlSinkProbe()
        sinkWriter.writeTo(rows, writeControlSink(wholeProbe))

        for (row in rows) {
            deferred.writeRow(row)
            deferredSink.writeRow(row)
        }
        let deferredBytes = deferred.finish()
        let deferredProbe = WriteControlSinkProbe()
        deferredSink.finishTo(writeControlSink(deferredProbe))

        let earlyProbe = WriteControlSinkProbe()
        early.startTo(writeControlSink(earlyProbe))
        for (row in rows) {
            early.writeRow(row)
        }
        early.finishTo()

        @Assert(wholeProbe.bytes.toArray(), expected)
        @Assert(deferredBytes, expected)
        @Assert(deferredProbe.bytes.toArray(), expected)
        @Assert(earlyProbe.bytes.toArray(), expected)
        @Assert(decodePngNonInterlaced(expected).rows(), rows)

        let adam7Controls = configuredWriteControls()
        let adam7 = encodePngPackedAdam7(
            UInt32(4), UInt32(3), UInt8(8), Truecolor, rows,
            Array<Byte>(), PngWriteMetadata(), adam7Controls, limits
        )
        @Assert(decodePng(adam7).rows(), rows)
        @Assert(
            adam7,
            encodePngPackedAdam7(
                UInt32(4), UInt32(3), UInt8(8), Truecolor, rows,
                Array<Byte>(), PngWriteMetadata(), adam7Controls, limits
            )
        )
    }
}
