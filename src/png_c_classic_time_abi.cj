// libpng4cj classic png_time RFC1123 conversion C ABI.
//
// Translates the upstream png.c::png_convert_to_rfc1123_buffer and the
// deprecated png.c::png_convert_to_rfc1123 entry that uses a per-owner
// time_buffer. The pure buffer function takes a 7-byte png_time C struct and
// writes "DD MMM YYYY HH:MM:SS +0000" (29 bytes) into a caller buffer. The
// owner variant uses PngCClassicReadState::timeBuffer and returns its address.
//
// The tIME data flow is already translated: PngModificationTime carries the
// same six fields, png_get_tIME exposes them as a 7-byte C struct, and the
// write side serializes them. This module adds only the RFC1123 formatting
// bridge and the per-owner buffer.

package libpng4cj

private let PNG_C_CLASSIC_RFC1123_MONTHS: Array<UInt8> = [
    UInt8(74), UInt8(97), UInt8(110),  // Jan
    UInt8(70), UInt8(101), UInt8(98),  // Feb
    UInt8(77), UInt8(97), UInt8(114),  // Mar
    UInt8(65), UInt8(112), UInt8(114), // Apr
    UInt8(77), UInt8(97), UInt8(121),  // May
    UInt8(74), UInt8(117), UInt8(110), // Jun
    UInt8(74), UInt8(117), UInt8(108), // Jul
    UInt8(65), UInt8(117), UInt8(103), // Aug
    UInt8(83), UInt8(101), UInt8(112), // Sep
    UInt8(79), UInt8(99), UInt8(116),  // Oct
    UInt8(78), UInt8(111), UInt8(118), // Nov
    UInt8(68), UInt8(101), UInt8(99)   // Dec
]

private let PNG_C_CLASSIC_RFC1123_SPACE = UInt8(32)
private let PNG_C_CLASSIC_RFC1123_COLON = UInt8(58)
private let PNG_C_CLASSIC_RFC1123_PLUS = UInt8(43)
private let PNG_C_CLASSIC_RFC1123_ZERO = UInt8(48)

private func pngCClassicWriteDecimal(
    buffer: CPointer<UInt8>,
    pos: Int64,
    value: UInt32,
    width: Int64
): Int64 {
    var localPos = pos
    var digits = Array<UInt8>(width, repeat: PNG_C_CLASSIC_RFC1123_ZERO)
    var remaining = value
    var index = width - Int64(1)
    while (index >= Int64(0)) {
        digits[index] = PNG_C_CLASSIC_RFC1123_ZERO + UInt8(remaining % UInt32(10))
        remaining = remaining / UInt32(10)
        index -= Int64(1)
    }
    var write = Int64(0)
    while (write < width && localPos < Int64(29)) {
        unsafe { buffer.write(localPos, digits[write]) }
        localPos += Int64(1)
        write += Int64(1)
    }
    localPos
}

// Writes the decimal expansion of value without zero padding, matching
// upstream PNG_NUMBER_FORMAT_u used for day and year fields.
private func pngCClassicWriteDecimalUnpadded(
    buffer: CPointer<UInt8>,
    pos: Int64,
    value: UInt32
): Int64 {
    var localPos = pos
    // Year fits in 4 digits, day fits in 2; 5 bytes is a safe scratch size.
    var scratch = Array<UInt8>(5, repeat: UInt8(0))
    var count = Int64(0)
    var remaining = value
    if (remaining == UInt32(0)) {
        scratch[0] = PNG_C_CLASSIC_RFC1123_ZERO
        count = Int64(1)
    } else {
        while (remaining > UInt32(0) && count < Int64(5)) {
            scratch[count] = PNG_C_CLASSIC_RFC1123_ZERO + UInt8(remaining % UInt32(10))
            remaining = remaining / UInt32(10)
            count += Int64(1)
        }
    }
    // scratch holds digits in reverse order; emit them from high to low.
    var index = count - Int64(1)
    while (index >= Int64(0) && localPos < Int64(29)) {
        unsafe { buffer.write(localPos, scratch[index]) }
        localPos += Int64(1)
        index -= Int64(1)
    }
    localPos
}

private func pngCClassicAppendByte(
    buffer: CPointer<UInt8>,
    pos: Int64,
    value: UInt8
): Int64 {
    var localPos = pos
    if (localPos < Int64(29)) {
        unsafe { buffer.write(localPos, value) }
        localPos += Int64(1)
    }
    localPos
}

private func pngCClassicAppendMonth(
    buffer: CPointer<UInt8>,
    pos: Int64,
    month: UInt8
): Int64 {
    var localPos = pos
    let offset = (Int64(month) - Int64(1)) * Int64(3)
    var write = Int64(0)
    while (write < Int64(3) && localPos < Int64(29)) {
        unsafe { buffer.write(localPos, PNG_C_CLASSIC_RFC1123_MONTHS[offset + write]) }
        localPos += Int64(1)
        write += Int64(1)
    }
    localPos
}

// Reads the 7-byte png_time C struct and formats it into buffer.
// Returns true on success, false on invalid input or NULL buffer.
private func pngCClassicFormatRfc1123(
    buffer: CPointer<UInt8>,
    ptime: CPointer<Unit>
): Bool {
    if (buffer.isNull() || ptime.isNull()) {
        return false
    }
    let words = unsafe { CPointer<UInt16>(ptime) }
    let bytes = unsafe { CPointer<UInt8>(ptime) }
    let year = unsafe { words.read(Int64(0)) }
    let month = unsafe { bytes.read(Int64(2)) }
    let day = unsafe { bytes.read(Int64(3)) }
    let hour = unsafe { bytes.read(Int64(4)) }
    let minute = unsafe { bytes.read(Int64(5)) }
    let second = unsafe { bytes.read(Int64(6)) }
    // Range validation matches upstream png_convert_to_rfc1123_buffer.
    if (year > UInt16(9999) ||
        month == UInt8(0) || month > UInt8(12) ||
        day == UInt8(0) || day > UInt8(31) ||
        hour > UInt8(23) || minute > UInt8(59) ||
        second > UInt8(60)) {
        return false
    }
    var index = Int64(0)
    while (index < Int64(29)) {
        unsafe { buffer.write(index, UInt8(0)) }
        index += Int64(1)
    }
    var pos = Int64(0)
    pos = pngCClassicWriteDecimalUnpadded(buffer, pos, UInt32(day))
    pos = pngCClassicAppendByte(buffer, pos, PNG_C_CLASSIC_RFC1123_SPACE)
    pos = pngCClassicAppendMonth(buffer, pos, month)
    pos = pngCClassicAppendByte(buffer, pos, PNG_C_CLASSIC_RFC1123_SPACE)
    pos = pngCClassicWriteDecimalUnpadded(buffer, pos, UInt32(year))
    pos = pngCClassicAppendByte(buffer, pos, PNG_C_CLASSIC_RFC1123_SPACE)
    pos = pngCClassicWriteDecimal(buffer, pos, UInt32(hour), Int64(2))
    pos = pngCClassicAppendByte(buffer, pos, PNG_C_CLASSIC_RFC1123_COLON)
    pos = pngCClassicWriteDecimal(buffer, pos, UInt32(minute), Int64(2))
    pos = pngCClassicAppendByte(buffer, pos, PNG_C_CLASSIC_RFC1123_COLON)
    pos = pngCClassicWriteDecimal(buffer, pos, UInt32(second), Int64(2))
    // " +0000" reliably terminates the buffer, matching upstream.
    pos = pngCClassicAppendByte(buffer, pos, PNG_C_CLASSIC_RFC1123_SPACE)
    pos = pngCClassicAppendByte(buffer, pos, PNG_C_CLASSIC_RFC1123_PLUS)
    pos = pngCClassicAppendByte(buffer, pos, PNG_C_CLASSIC_RFC1123_ZERO)
    pos = pngCClassicAppendByte(buffer, pos, PNG_C_CLASSIC_RFC1123_ZERO)
    pos = pngCClassicAppendByte(buffer, pos, PNG_C_CLASSIC_RFC1123_ZERO)
    pos = pngCClassicAppendByte(buffer, pos, PNG_C_CLASSIC_RFC1123_ZERO)
    true
}

@C
public func png_convert_to_rfc1123_buffer(
    out: CPointer<UInt8>,
    ptime: CPointer<Unit>
): Int32 {
    if (out.isNull()) {
        return Int32(0)
    }
    if (!pngCClassicFormatRfc1123(out, ptime)) {
        return Int32(0)
    }
    Int32(1)
}

@C
public func png_convert_to_rfc1123(
    pngPtr: CPointer<Unit>,
    ptime: CPointer<Unit>
): CPointer<UInt8> {
    if (pngPtr.isNull()) {
        return CPointer<UInt8>()
    }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.destroying || state.timeBuffer.isNull()) {
                    return CPointer<UInt8>()
                }
                let buffer = unsafe { CPointer<UInt8>(state.timeBuffer) }
                if (!pngCClassicFormatRfc1123(buffer, ptime)) {
                    return CPointer<UInt8>()
                }
                buffer
            case None =>
                CPointer<UInt8>()
        }
    }
}
