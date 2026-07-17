package libpng4cj.tests

import std.collection.ArrayList
import std.fs.*
import libpng4cj.*

private func progressiveStreamFixture(name: String): Array<Byte> {
    File.readFrom("test/fixtures/pngsuite/${name}")
}

private class ProgressiveStreamProbe {
    var infoCount: Int64 = Int64(0)
    var rowCount: Int64 = Int64(0)
    var endCount: Int64 = Int64(0)
    var pauseOnFirstRow: Bool = false
}

private func expectProgressiveStreamError(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected progressive stream operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind.toString(), expected.toString())
    }
}

private func corruptFirstIdatCrc(bytes: Array<Byte>): Array<Byte> {
    let out = bytes.clone()
    var offset: Int64 = PNG_SIGNATURE.size
    while (offset + Int64(12) <= out.size) {
        let length = Int64(readUInt32Be(out, offset))
        let chunkType = copyByteRange(out, offset + Int64(4), Int64(4))
        if (sameBytes(chunkType, PNG_CHUNK_IDAT)) {
            let crcOffset = offset + Int64(8) + length
            out[crcOffset] = out[crcOffset] ^ UInt8(1)
            return out
        }
        offset += length + Int64(12)
    }
    throw PngFormatException(InvalidData, -1, "fixture does not contain IDAT")
}

@Test
public class PngProgressiveStreamTestSuite {
    @TestCase
    public func emitsInfoAndRowsBeforeTheCompleteInputArrives(): Unit {
        let bytes = progressiveStreamFixture("basn2c08.png")
        let reader = PngProgressiveReader()
        let probe = ProgressiveStreamProbe()
        reader.setInfoCallback({ _, _ => probe.infoCount += Int64(1) })
        reader.setRowCallback({ _, _ => probe.rowCount += Int64(1) })
        reader.setEndCallback({ _, _ => probe.endCount += Int64(1) })

        var offset: Int64 = Int64(0)
        while (offset < bytes.size && probe.infoCount == Int64(0)) {
            reader.feed([bytes[offset]])
            offset += Int64(1)
        }
        @Assert(probe.infoCount, Int64(1))
        @Assert(offset < bytes.size, true)
        @Assert(probe.endCount, Int64(0))

        while (offset < bytes.size && probe.rowCount == Int64(0)) {
            reader.feed([bytes[offset]])
            offset += Int64(1)
        }
        @Assert(probe.rowCount > Int64(0), true)
        @Assert(offset < bytes.size, true)
        reader.feed(copyByteRange(bytes, offset, bytes.size - offset))
        @Assert(probe.endCount, Int64(1))
        @Assert(reader.finish().rows(), decodePng(bytes).rows())
    }

    @TestCase
    public func pausesWithUnconsumedInputAndResumesWithoutDuplicateRows(): Unit {
        let bytes = progressiveStreamFixture("basn2c08.png")
        let expected = decodePng(bytes)
        let reader = PngProgressiveReader()
        let probe = ProgressiveStreamProbe()
        probe.pauseOnFirstRow = true
        reader.setRowCallback({
            _, _ =>
                probe.rowCount += Int64(1)
                if (probe.pauseOnFirstRow) {
                    probe.pauseOnFirstRow = false
                    reader.pause()
                }
        })
        let consumed = reader.feedAvailable(bytes)
        @Assert(reader.state(), ProgressivePaused)
        @Assert(consumed > Int64(0), true)
        @Assert(consumed < bytes.size, true)
        @Assert(reader.lastUnconsumedBytes(), UInt64(bytes.size - consumed))
        @Assert(probe.rowCount, Int64(1))

        reader.resume()
        @Assert(reader.state(), ProgressiveOpen)
        reader.feed(copyByteRange(bytes, consumed, bytes.size - consumed))
        let decoded = reader.finish()
        @Assert(decoded.rows(), expected.rows())
        @Assert(probe.rowCount, expected.rowCount())
        @Assert(reader.receivedBytes(), UInt64(bytes.size))
    }

    @TestCase
    public func combinesPackedEightAndSixteenBitAdam7Rows(): Unit {
        let packedIhdr = readPngIhdr(progressiveStreamFixture("ibasn0g01.png"))
        let packed = pngProgressiveCombineRow(
            Array<Byte>(Int64(packedIhdr.rowBytes), repeat: UInt8(0)),
            [UInt8(0xa0)],
            packedIhdr,
            Int64(0)
        )
        @Assert(packed[0], UInt8(0x80))
        @Assert(packed[2], UInt8(0x80))
        @Assert(
            pngProgressiveCombineRow(packed, Array<Byte>(), packedIhdr, Int64(0)),
            packed
        )

        let eightIhdr = readPngIhdr(progressiveStreamFixture("ibasn2c08.png"))
        let eightGeometry = pngAdam7PassGeometry(eightIhdr, Int64(0))
        let eightPass = Array<Byte>(Int64(eightGeometry.rowBytes), repeat: UInt8(0x5a))
        let eight = pngProgressiveCombineRow(
            Array<Byte>(Int64(eightIhdr.rowBytes), repeat: UInt8(0)),
            eightPass,
            eightIhdr,
            Int64(0)
        )
        @Assert(eight[0], UInt8(0x5a))
        @Assert(eight[Int64(8) * Int64(3)], UInt8(0x5a))

        let sixteenIhdr = readPngIhdr(progressiveStreamFixture("ibasn6a16.png"))
        let sixteenGeometry = pngAdam7PassGeometry(sixteenIhdr, Int64(0))
        let sixteenPass = Array<Byte>(Int64(sixteenGeometry.rowBytes), repeat: UInt8(0x7c))
        let sixteen = pngProgressiveCombineRow(
            Array<Byte>(Int64(sixteenIhdr.rowBytes), repeat: UInt8(0)),
            sixteenPass,
            sixteenIhdr,
            Int64(0)
        )
        @Assert(sixteen[0], UInt8(0x7c))
        @Assert(sixteen[Int64(8) * Int64(8)], UInt8(0x7c))
    }

    @TestCase
    public func rejectsIncrementalCrcTrailingAndInflatedLimitFailures(): Unit {
        let bytes = progressiveStreamFixture("basn2c08.png")
        let crc = PngProgressiveReader()
        expectProgressiveStreamError({=> crc.feed(corruptFirstIdatCrc(bytes))}, CrcMismatch)
        @Assert(crc.state(), ProgressiveFailed)

        let trailing = PngProgressiveReader()
        let withTrailing = Array<Byte>(bytes.size + Int64(1), repeat: UInt8(0))
        var index: Int64 = Int64(0)
        while (index < bytes.size) {
            withTrailing[index] = bytes[index]
            index += Int64(1)
        }
        withTrailing[bytes.size] = UInt8(1)
        expectProgressiveStreamError({=> trailing.feed(withTrailing)}, TrailingData)

        let constrained = PngProgressiveReader(PngReadLimits(
            UInt32(8_000_000),
            UInt32(1_000_000),
            UInt32(1_000_000),
            PNG_DEFAULT_MAX_COMPRESSED_BYTES,
            UInt64(8)
        ))
        expectProgressiveStreamError({=> constrained.feed(bytes)}, DecodeLimitExceeded)
    }
}
