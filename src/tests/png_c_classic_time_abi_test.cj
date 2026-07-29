package libpng4cj.tests

import libpng4cj.*

// Builds a 7-byte png_time C struct in native endian and returns it as a
// CPointer<Unit> so it can be passed straight to the @C entry points.
private func makePngTime(
    year: UInt16,
    month: UInt8,
    day: UInt8,
    hour: UInt8,
    minute: UInt8,
    second: UInt8
): CPointer<Unit> {
    unsafe {
        let bytes = LibC.malloc<UInt8>(count: 7)
        let words = CPointer<UInt16>(bytes)
        words.write(Int64(0), year)
        bytes.write(Int64(2), month)
        bytes.write(Int64(3), day)
        bytes.write(Int64(4), hour)
        bytes.write(Int64(5), minute)
        bytes.write(Int64(6), second)
        CPointer<Unit>(bytes)
    }
}

private func freePngTime(ptime: CPointer<Unit>): Unit {
    if (ptime.isNull()) { return }
    unsafe { LibC.free(ptime) }
}

private func makeOutBuffer(): CPointer<UInt8> {
    unsafe {
        let buffer = LibC.malloc<UInt8>(count: 29)
        var index = Int64(0)
        while (index < Int64(29)) {
            buffer.write(index, UInt8(0))
            index += Int64(1)
        }
        buffer
    }
}

private func freeOutBuffer(buffer: CPointer<UInt8>): Unit {
    if (buffer.isNull()) { return }
    unsafe { LibC.free(buffer) }
}

private func readOutBytes(buffer: CPointer<UInt8>): Array<UInt8> {
    let bytes = Array<UInt8>(29, repeat: UInt8(0))
    unsafe {
        var index = Int64(0)
        while (index < Int64(29)) {
            bytes[index] = buffer.read(index)
            index += Int64(1)
        }
    }
    bytes
}

private func readOutString(buffer: CPointer<UInt8>): String {
    let bytes = readOutBytes(buffer)
    let chars = Array<Rune>(29, repeat: Rune(0))
    var count = 0
    while (count < 29) {
        let value = bytes[Int64(count)]
        if (value == UInt8(0)) {
            break
        }
        chars[count] = Rune(UInt32(value))
        count += 1
    }
    if (count == 0) { return String() }
    String(chars.slice(Int64(0), Int64(count)))
}

@Test
public class PngClassicTimeAbiTestSuite {
    @TestCase
    public func formatsValidDateAsRfc1123(): Unit {
        let ptime = makePngTime(UInt16(2023), UInt8(4), UInt8(15), UInt8(12), UInt8(34), UInt8(56))
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
        @Assert(result, Int32(1))
        @Assert(readOutString(out), "15 Apr 2023 12:34:56 +0000")
        freeOutBuffer(out)
        freePngTime(ptime)
    }

    @TestCase
    public func formatsYearZeroBoundary(): Unit {
        let ptime = makePngTime(UInt16(0), UInt8(1), UInt8(1), UInt8(0), UInt8(0), UInt8(0))
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
        @Assert(result, Int32(1))
        @Assert(readOutString(out), "1 Jan 0 00:00:00 +0000")
        freeOutBuffer(out)
        freePngTime(ptime)
    }

    @TestCase
    public func formatsYear9999Boundary(): Unit {
        let ptime = makePngTime(UInt16(9999), UInt8(12), UInt8(31), UInt8(23), UInt8(59), UInt8(60))
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
        @Assert(result, Int32(1))
        @Assert(readOutString(out), "31 Dec 9999 23:59:60 +0000")
        freeOutBuffer(out)
        freePngTime(ptime)
    }

    @TestCase
    public func formatsAllMonthNames(): Unit {
        let expected = [
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        ]
        var month = UInt8(1)
        while (month <= UInt8(12)) {
            let ptime = makePngTime(UInt16(2024), month, UInt8(5), UInt8(6), UInt8(7), UInt8(8))
            let out = makeOutBuffer()
            let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
            @Assert(result, Int32(1))
            let expectedString = "5 " + expected[Int64(month) - Int64(1)] + " 2024 06:07:08 +0000"
            @Assert(readOutString(out), expectedString)
            freeOutBuffer(out)
            freePngTime(ptime)
            month += UInt8(1)
        }
    }

    @TestCase
    public func rejectsYearOverflow(): Unit {
        let ptime = makePngTime(UInt16(10_000), UInt8(1), UInt8(1), UInt8(0), UInt8(0), UInt8(0))
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
        @Assert(result, Int32(0))
        freeOutBuffer(out)
        freePngTime(ptime)
    }

    @TestCase
    public func rejectsMonthZero(): Unit {
        let ptime = makePngTime(UInt16(2024), UInt8(0), UInt8(1), UInt8(0), UInt8(0), UInt8(0))
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
        @Assert(result, Int32(0))
        freeOutBuffer(out)
        freePngTime(ptime)
    }

    @TestCase
    public func rejectsMonthOverflow(): Unit {
        let ptime = makePngTime(UInt16(2024), UInt8(13), UInt8(1), UInt8(0), UInt8(0), UInt8(0))
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
        @Assert(result, Int32(0))
        freeOutBuffer(out)
        freePngTime(ptime)
    }

    @TestCase
    public func rejectsDayZero(): Unit {
        let ptime = makePngTime(UInt16(2024), UInt8(1), UInt8(0), UInt8(0), UInt8(0), UInt8(0))
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
        @Assert(result, Int32(0))
        freeOutBuffer(out)
        freePngTime(ptime)
    }

    @TestCase
    public func rejectsDayOverflow(): Unit {
        let ptime = makePngTime(UInt16(2024), UInt8(1), UInt8(32), UInt8(0), UInt8(0), UInt8(0))
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
        @Assert(result, Int32(0))
        freeOutBuffer(out)
        freePngTime(ptime)
    }

    @TestCase
    public func rejectsHourOverflow(): Unit {
        let ptime = makePngTime(UInt16(2024), UInt8(1), UInt8(1), UInt8(24), UInt8(0), UInt8(0))
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
        @Assert(result, Int32(0))
        freeOutBuffer(out)
        freePngTime(ptime)
    }

    @TestCase
    public func rejectsMinuteOverflow(): Unit {
        let ptime = makePngTime(UInt16(2024), UInt8(1), UInt8(1), UInt8(0), UInt8(60), UInt8(0))
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
        @Assert(result, Int32(0))
        freeOutBuffer(out)
        freePngTime(ptime)
    }

    @TestCase
    public func rejectsSecondOverflow(): Unit {
        let ptime = makePngTime(UInt16(2024), UInt8(1), UInt8(1), UInt8(0), UInt8(0), UInt8(61))
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
        @Assert(result, Int32(0))
        freeOutBuffer(out)
        freePngTime(ptime)
    }

    @TestCase
    public func returnsZeroForNullOut(): Unit {
        let ptime = makePngTime(UInt16(2024), UInt8(1), UInt8(1), UInt8(0), UInt8(0), UInt8(0))
        let result = unsafe { png_convert_to_rfc1123_buffer(CPointer<UInt8>(), ptime) }
        @Assert(result, Int32(0))
        freePngTime(ptime)
    }

    @TestCase
    public func returnsZeroForNullPtime(): Unit {
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, CPointer<Unit>()) }
        @Assert(result, Int32(0))
        freeOutBuffer(out)
    }

    @TestCase
    public func ownerVariantReturnsNullForNullPngPtr(): Unit {
        let ptime = makePngTime(UInt16(2024), UInt8(1), UInt8(1), UInt8(0), UInt8(0), UInt8(0))
        let result = unsafe { png_convert_to_rfc1123(CPointer<Unit>(), ptime) }
        @Assert(result.isNull(), true)
        freePngTime(ptime)
    }

    @TestCase
    public func ownerVariantReturnsNullForUnknownHandle(): Unit {
        let ptime = makePngTime(UInt16(2024), UInt8(1), UInt8(1), UInt8(0), UInt8(0), UInt8(0))
        let dangling = unsafe { CPointer<Unit>(LibC.malloc<UInt8>(count: 1)) }
        let result = unsafe { png_convert_to_rfc1123(dangling, ptime) }
        @Assert(result.isNull(), true)
        unsafe { LibC.free(dangling) }
        freePngTime(ptime)
    }

    @TestCase
    public func ownerVariantReturnsNullForNullPtime(): Unit {
        let dangling = unsafe { CPointer<Unit>(LibC.malloc<UInt8>(count: 1)) }
        let result = unsafe { png_convert_to_rfc1123(dangling, CPointer<Unit>()) }
        @Assert(result.isNull(), true)
        unsafe { LibC.free(dangling) }
    }

    @TestCase
    public func bufferOutputIsExactly29BytesWithTerminator(): Unit {
        let ptime = makePngTime(UInt16(2026), UInt8(7), UInt8(25), UInt8(9), UInt8(30), UInt8(45))
        let out = makeOutBuffer()
        let result = unsafe { png_convert_to_rfc1123_buffer(out, ptime) }
        @Assert(result, Int32(1))
        let bytes = readOutBytes(out)
        @Assert(bytes.size, Int64(29))
        // "25 Jul 2026 09:30:45 +0000" occupies bytes[0..25], " +0000" is bytes[20..25].
        @Assert(bytes[Int64(20)], UInt8(32))  // space
        @Assert(bytes[Int64(21)], UInt8(43))  // '+'
        @Assert(bytes[Int64(22)], UInt8(48))  // '0'
        @Assert(bytes[Int64(23)], UInt8(48))  // '0'
        @Assert(bytes[Int64(24)], UInt8(48))  // '0'
        @Assert(bytes[Int64(25)], UInt8(48))  // '0'
        // Remaining bytes are NUL terminators.
        @Assert(bytes[Int64(26)], UInt8(0))
        @Assert(bytes[Int64(27)], UInt8(0))
        @Assert(bytes[Int64(28)], UInt8(0))
        freeOutBuffer(out)
        freePngTime(ptime)
    }
}
