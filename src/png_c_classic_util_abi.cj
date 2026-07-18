package libpng4cj

private let PNG_C_LIBPNG_VERSION: UInt32 = UInt32(10658)
private let PNG_C_UINT32_SIGN_BIT: UInt32 = UInt32(0x8000_0000)
private let PNG_C_UINT32_MASK: UInt32 = UInt32(0xffff_ffff)

private func pngCReadUInt32(buffer: CPointer<UInt8>): UInt32 {
    (UInt32(unsafe { buffer.read(Int64(0)) }) << UInt32(24)) |
        (UInt32(unsafe { buffer.read(Int64(1)) }) << UInt32(16)) |
        (UInt32(unsafe { buffer.read(Int64(2)) }) << UInt32(8)) |
        UInt32(unsafe { buffer.read(Int64(3)) })
}

private func pngCWriteUInt32(buffer: CPointer<UInt8>, value: UInt32): Unit {
    unsafe {
        buffer.write(Int64(0), UInt8((value >> UInt32(24)) & UInt32(0xff)))
        buffer.write(Int64(1), UInt8((value >> UInt32(16)) & UInt32(0xff)))
        buffer.write(Int64(2), UInt8((value >> UInt32(8)) & UInt32(0xff)))
        buffer.write(Int64(3), UInt8(value & UInt32(0xff)))
    }
}

@C
public func png_access_version_number(): UInt32 {
    PNG_C_LIBPNG_VERSION
}

@C
public func png_sig_cmp(
    signature: CPointer<UInt8>,
    start: UIntNative,
    count: UIntNative
): Int32 {
    var checked = UInt64(count)
    let offset = UInt64(start)
    if (checked > UInt64(PNG_SIGNATURE.size)) {
        checked = UInt64(PNG_SIGNATURE.size)
    } else if (checked < UInt64(1)) {
        return Int32(-1)
    }
    if (offset > UInt64(7)) {
        return Int32(-1)
    }
    if (offset + checked > UInt64(PNG_SIGNATURE.size)) {
        checked = UInt64(PNG_SIGNATURE.size) - offset
    }

    var index = UInt64(0)
    while (index < checked) {
        let actual = unsafe { signature.read(Int64(offset + index)) }
        let expected = PNG_SIGNATURE[Int64(offset + index)]
        if (actual != expected) {
            return Int32(actual) - Int32(expected)
        }
        index += UInt64(1)
    }
    Int32(0)
}

@C
public func png_get_uint_32(buffer: CPointer<UInt8>): UInt32 {
    pngCReadUInt32(buffer)
}

@C
public func png_get_uint_16(buffer: CPointer<UInt8>): UInt16 {
    (UInt16(unsafe { buffer.read(Int64(0)) }) << UInt16(8)) |
        UInt16(unsafe { buffer.read(Int64(1)) })
}

@C
public func png_get_int_32(buffer: CPointer<UInt8>): Int32 {
    var value = pngCReadUInt32(buffer)
    if ((value & PNG_C_UINT32_SIGN_BIT) == UInt32(0)) {
        return Int32(value)
    }

    value = (value ^ PNG_C_UINT32_MASK) + UInt32(1)
    if ((value & PNG_C_UINT32_SIGN_BIT) == UInt32(0)) {
        return -Int32(value)
    }
    Int32(0)
}

@C
public func png_save_uint_32(buffer: CPointer<UInt8>, value: UInt32): Unit {
    pngCWriteUInt32(buffer, value)
}

@C
public func png_save_int_32(buffer: CPointer<UInt8>, value: Int32): Unit {
    let encoded = if (value >= Int32(0)) {
        UInt32(value)
    } else if (value == Int32(-2147483647) - Int32(1)) {
        PNG_C_UINT32_SIGN_BIT
    } else {
        let magnitude = UInt32(-value)
        (magnitude ^ PNG_C_UINT32_MASK) + UInt32(1)
    }
    pngCWriteUInt32(buffer, encoded)
}

@C
public func png_save_uint_16(buffer: CPointer<UInt8>, value: UInt32): Unit {
    unsafe {
        buffer.write(Int64(0), UInt8((value >> UInt32(8)) & UInt32(0xff)))
        buffer.write(Int64(1), UInt8(value & UInt32(0xff)))
    }
}
