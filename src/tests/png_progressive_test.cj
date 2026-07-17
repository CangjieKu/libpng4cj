package libpng4cj.tests

import std.collection.ArrayList
import std.fs.*
import libpng4cj.*

private func progressiveFixture(name: String): Array<Byte> {
    File.readFrom("test/fixtures/pngsuite/${name}")
}

private func progressiveFeedOneByte(reader: PngProgressiveReader, bytes: Array<Byte>): Unit {
    var index: Int64 = 0
    while (index < bytes.size) {
        reader.feed([bytes[index]])
        index += 1
    }
}

private func progressiveFeedIrregular(reader: PngProgressiveReader, bytes: Array<Byte>): Unit {
    let widths: Array<Int64> = [1, 7, 3, 29, 2, 11]
    var offset: Int64 = 0
    var widthIndex: Int64 = 0
    while (offset < bytes.size) {
        let requested = widths[widthIndex % widths.size]
        let remaining = bytes.size - offset
        let length = if (requested < remaining) { requested } else { remaining }
        reader.feed(copyByteRange(bytes, offset, length))
        offset += length
        widthIndex += 1
    }
}

private func expectProgressiveError(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected progressive reader operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind.toString(), expected.toString())
    }
}

private class ProgressiveProbe {
    let events = ArrayList<String>()
    let adam7PassSeen = Array<Bool>(Int64(7), repeat: false)
    var infoSeen: Bool = false
    var rowCount: Int64 = 0
    var replacedCount: Int64 = 0
    var activeCount: Int64 = 0
    var endCalled: Bool = false
}

@Test
public class PngProgressiveTestSuite {
    @TestCase
    public func feedsOneByteAndOrdersInfoRowsThenEnd(): Unit {
        let bytes = progressiveFixture("basn2c08.png")
        let expected = decodePng(bytes)
        let reader = PngProgressiveReader()
        let probe = ProgressiveProbe()
        reader.setInfoCallback({
            ihdr, _ =>
                @Assert(ihdr.interlaceMethod.encodedValue(), UInt8(0))
                probe.infoSeen = true
                probe.events.add("info")
        })
        reader.setRowCallback({
            context, row =>
                @Assert(probe.infoSeen, true)
                @Assert(context.rowNumber, UInt32(probe.rowCount))
                @Assert(context.passNumber, Int64(0))
                @Assert(context.canonicalCombined, false)
                if (row.size > Int64(0)) {
                    row[0] = UInt8(0)
                }
                probe.rowCount += 1
                probe.events.add("row")
        })
        reader.setEndCallback({
            _, _ =>
                @Assert(probe.rowCount, expected.rowCount())
                probe.events.add("end")
        })

        progressiveFeedOneByte(reader, bytes)
        @Assert(reader.receivedBytes(), UInt64(bytes.size))
        @Assert(probe.infoSeen, true)
        @Assert(probe.rowCount, expected.rowCount())
        @Assert(probe.events[probe.events.size - Int64(1)], "end")
        let decoded = reader.finish()
        @Assert(decoded.rows(), expected.rows())
        @Assert(reader.state(), ProgressiveCompleted)
        @Assert(probe.events[0], "info")
        @Assert(probe.events[probe.events.size - Int64(1)], "end")
        @Assert(probe.rowCount, decoded.rowCount())
    }

    @TestCase
    public func feedsAdam7IrregularlyAndUsesCanonicalCombinedContext(): Unit {
        let bytes = progressiveFixture("ibasn3p04.png")
        let reader = PngProgressiveReader()
        let probe = ProgressiveProbe()
        reader.setInfoCallback({
            ihdr, metadata =>
                @Assert(ihdr.interlaceMethod, Adam7)
                @Assert(metadata.hasPalette, true)
                @Assert(metadata.paletteEntryCount() > Int64(0), true)
                probe.infoSeen = true
        })
        reader.setRowCallback({
            _, _ => probe.replacedCount += 1
        })
        reader.setRowCallback({
            context, _ =>
                @Assert(probe.infoSeen, true)
                @Assert(context.interlaceMethod, Adam7)
                @Assert(context.passNumber >= Int64(0), true)
                @Assert(context.passNumber < Int64(7), true)
                @Assert(context.rowNumber, context.imageRowNumber)
                @Assert(context.passRowPresent, true)
                @Assert(context.canonicalCombined, true)
                probe.adam7PassSeen[context.passNumber] = true
                probe.activeCount += 1
        })
        reader.setEndCallback({
            _, metadata =>
                @Assert(metadata.hasPalette, true)
                @Assert(probe.activeCount > Int64(0), true)
                probe.endCalled = true
        })
        progressiveFeedIrregular(reader, bytes)
        var pass: Int64 = 0
        while (pass < Int64(7)) {
            @Assert(probe.adam7PassSeen[pass], true)
            pass += 1
        }
        @Assert(probe.endCalled, true)
        let decoded = reader.finish()
        @Assert(decoded.ihdr.interlaceMethod, Adam7)
        @Assert(decoded.metadata.hasPalette, true)
        @Assert(probe.replacedCount, Int64(0))
        @Assert(probe.activeCount > decoded.rowCount(), true)
        @Assert(decoded.rows(), decodePng(bytes).rows())
    }

    @TestCase
    public func retainsInputOwnershipAndUnknownChunkConfiguration(): Unit {
        let bytes = progressiveFixture("basn0g02.png")
        let mutable = bytes.clone()
        let reader = PngProgressiveReader()
        reader.setUnknownChunkPolicy(RetainAncillary)
        reader.setCrcAction(CrcNoChange, CrcNoChange)
        reader.feed(mutable)
        mutable[0] = UInt8(0)
        @Assert(reader.finish().rows(), decodePng(bytes).rows())
    }

    @TestCase
    public func rejectsLimitsTruncationAndInvalidLifecycle(): Unit {
        let bytes = progressiveFixture("basn2c08.png")
        let limited = PngProgressiveReader(PngReadLimits(), UInt64(3))
        expectProgressiveError({=> limited.feed([1, 2, 3, 4])}, DecodeLimitExceeded)
        @Assert(limited.state(), ProgressiveFailed)

        let truncated = PngProgressiveReader()
        truncated.feed(copyByteRange(bytes, Int64(0), bytes.size - Int64(1)))
        expectProgressiveError({=> truncated.finish(); ()}, TruncatedInput)
        @Assert(truncated.state(), ProgressiveFailed)

        let completed = PngProgressiveReader()
        completed.feed(bytes)
        completed.finish()
        expectProgressiveError({=> completed.feed([0])}, InvalidArgument)
        expectProgressiveError({=> completed.finish(); ()}, InvalidArgument)
        @Assert(completed.state(), ProgressiveCompleted)

        completed.close()
        @Assert(completed.state(), ProgressiveClosed)
        @Assert(completed.receivedBytes(), UInt64(0))
        expectProgressiveError({=> completed.feed([0])}, SessionClosed)
    }

    @TestCase
    public func marksCallbackFailuresAndStopsBeforeEnd(): Unit {
        let bytes = progressiveFixture("basn2c08.png")
        let reader = PngProgressiveReader()
        let probe = ProgressiveProbe()
        reader.setRowCallback({
            _, _ => throw PngFormatException(InvalidData, -1, "callback failure")
        })
        reader.setEndCallback({
            _, _ => probe.endCalled = true
        })
        expectProgressiveError({=> reader.feed(bytes); reader.finish(); ()}, InvalidData)
        @Assert(reader.state(), ProgressiveFailed)
        @Assert(probe.endCalled, false)

        let reentrant = PngProgressiveReader()
        reentrant.setInfoCallback({
            _, _ => reentrant.close()
        })
        expectProgressiveError({=> reentrant.feed(bytes)}, InvalidArgument)
        @Assert(reentrant.state(), ProgressiveFailed)
    }
}
