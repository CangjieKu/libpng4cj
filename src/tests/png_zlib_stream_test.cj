package libpng4cj.tests

import std.collection.ArrayList
import libpng4cj.*

private let STREAM_HELLO_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0xcb, 0x48, 0xcd, 0xc9, 0xc9,
    0x07, 0x00, 0x06, 0x2c, 0x02, 0x15
]

private func appendStreamBytes(output: ArrayList<Byte>, bytes: Array<Byte>): Unit {
    var index: Int64 = 0
    while (index < bytes.size) {
        output.add(bytes[index])
        index += 1
    }
}

private class StreamPauseProbe {
    var firstWindow: Bool = true
}

@Test
public class PngZlibStreamTestSuite {
    @TestCase
    public func inflatesFragmentedInputThroughBoundedOutputWindows(): Unit {
        let inflater = PngIncrementalInflater(UInt64(5), Int64(2))
        let output = ArrayList<Byte>()
        var index: Int64 = 0
        while (index < STREAM_HELLO_ZLIB.size) {
            let consumed = inflater.push([STREAM_HELLO_ZLIB[index]], {
                bytes =>
                    appendStreamBytes(output, bytes)
                    true
            })
            @Assert(consumed, Int64(1))
            index += 1
        }
        inflater.finish()
        @Assert(output.toArray(), [UInt8(0x68), 0x65, 0x6c, 0x6c, 0x6f])
        @Assert(inflater.totalInputBytes(), UInt64(STREAM_HELLO_ZLIB.size))
        @Assert(inflater.totalOutputBytes(), UInt64(5))
        inflater.close()
    }

    @TestCase
    public func reportsConsumedInputAndResumesWithoutDuplicateOutput(): Unit {
        let inflater = PngIncrementalInflater(UInt64(5), Int64(2))
        let output = ArrayList<Byte>()
        let probe = StreamPauseProbe()
        let consumed = inflater.push(STREAM_HELLO_ZLIB, {
            bytes =>
                appendStreamBytes(output, bytes)
                if (probe.firstWindow) {
                    probe.firstWindow = false
                    false
                } else {
                    true
                }
        })
        @Assert(consumed > Int64(0), true)
        @Assert(consumed < STREAM_HELLO_ZLIB.size, true)
        let remaining = copyByteRange(
            STREAM_HELLO_ZLIB,
            consumed,
            STREAM_HELLO_ZLIB.size - consumed
        )
        @Assert(inflater.push(remaining, {
            bytes =>
                appendStreamBytes(output, bytes)
                true
        }), remaining.size)
        inflater.finish()
        @Assert(output.toArray(), [UInt8(0x68), 0x65, 0x6c, 0x6c, 0x6f])
        @Assert(inflater.totalInputBytes(), UInt64(STREAM_HELLO_ZLIB.size))
        inflater.close()
    }

    @TestCase
    public func stopsAtStreamEndAndLeavesTrailingInputUnconsumed(): Unit {
        let input = Array<Byte>(STREAM_HELLO_ZLIB.size + Int64(2), repeat: UInt8(0))
        var index: Int64 = 0
        while (index < STREAM_HELLO_ZLIB.size) {
            input[index] = STREAM_HELLO_ZLIB[index]
            index += 1
        }
        input[STREAM_HELLO_ZLIB.size] = UInt8(0xaa)
        input[STREAM_HELLO_ZLIB.size + Int64(1)] = UInt8(0xbb)
        let inflater = PngIncrementalInflater(UInt64(5), Int64(8))
        let consumed = inflater.push(input, {_ => true})
        @Assert(consumed, STREAM_HELLO_ZLIB.size)
        @Assert(inflater.ended(), true)
        inflater.close()
    }

    @TestCase
    public func rejectsOutputBeyondTheConfiguredLimit(): Unit {
        let inflater = PngIncrementalInflater(UInt64(4), Int64(2))
        try {
            inflater.push(STREAM_HELLO_ZLIB, {_ => true})
            @Fail("incremental zlib output limit should fail")
        } catch (error: PngFormatException) {
            @Assert(error.kind, DecodeLimitExceeded)
        }
        inflater.close()
    }
}
