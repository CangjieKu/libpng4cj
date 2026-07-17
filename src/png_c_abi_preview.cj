package libpng4cj

public let PNG_C_ABI_PREVIEW_VERSION: UInt32 = UInt32(1)
public let PNG_C_ABI_PREVIEW_MAX_INPUT_BYTES: UInt64 = UInt64(268435456)
public let PNG_C_ABI_PREVIEW_CAPABILITIES: UInt64 = UInt64(15)

private let PNG_C_ABI_OK: Int32 = Int32(0)
private let PNG_C_ABI_INVALID_ARGUMENT: Int32 = Int32(1)
private let PNG_C_ABI_BUFFER_TOO_SMALL: Int32 = Int32(2)
private let PNG_C_ABI_DECODE_ERROR: Int32 = Int32(3)
private let PNG_C_ABI_INTERNAL_ERROR: Int32 = Int32(4)

private let PNG_C_ABI_LIBPNG_VERSION: String = "1.6.58"

private func pngCAbiClearMessage(message: CPointer<UInt8>, capacity: UInt64): Unit {
    if (!message.isNull() && capacity > UInt64(0)) {
        unsafe { message.write(Int64(0), UInt8(0)) }
    }
}

private func pngCAbiWriteMessage(
    message: CPointer<UInt8>,
    capacity: UInt64,
    text: String
): Unit {
    if (message.isNull() || capacity == UInt64(0)) {
        return
    }
    let encoded = text.toArray()
    let available = capacity - UInt64(1)
    let count = if (UInt64(encoded.size) < available) {
        UInt64(encoded.size)
    } else {
        available
    }
    var index: UInt64 = UInt64(0)
    while (index < count) {
        unsafe { message.write(Int64(index), encoded[Int64(index)]) }
        index += UInt64(1)
    }
    unsafe { message.write(Int64(count), UInt8(0)) }
}

private func pngCAbiWriteText(
    output: CPointer<UInt8>,
    capacity: UInt64,
    required: CPointer<UIntNative>,
    text: String
): Int32 {
    if (required.isNull()) {
        return PNG_C_ABI_INVALID_ARGUMENT
    }
    let encoded = text.toArray()
    let needed = UInt64(encoded.size) + UInt64(1)
    unsafe { required.write(UIntNative(needed)) }
    if (output.isNull() || capacity < needed) {
        return PNG_C_ABI_BUFFER_TOO_SMALL
    }
    var index: UInt64 = UInt64(0)
    while (index < UInt64(encoded.size)) {
        unsafe { output.write(Int64(index), encoded[Int64(index)]) }
        index += UInt64(1)
    }
    unsafe { output.write(Int64(encoded.size), UInt8(0)) }
    PNG_C_ABI_OK
}

private func pngCAbiClearDecodeOutputs(
    width: CPointer<UInt32>,
    height: CPointer<UInt32>,
    stride: CPointer<UIntNative>,
    required: CPointer<UIntNative>,
    errorKind: CPointer<Int32>,
    errorOffset: CPointer<Int64>
): Unit {
    unsafe {
        if (!width.isNull()) { width.write(UInt32(0)) }
        if (!height.isNull()) { height.write(UInt32(0)) }
        if (!stride.isNull()) { stride.write(UIntNative(0)) }
        if (!required.isNull()) { required.write(UIntNative(0)) }
        if (!errorKind.isNull()) { errorKind.write(Int32(-1)) }
        if (!errorOffset.isNull()) { errorOffset.write(Int64(-1)) }
    }
}

private func pngCAbiReadInput(input: CPointer<UInt8>, length: UInt64): Array<Byte> {
    let bytes = Array<Byte>(Int64(length), repeat: UInt8(0))
    var index: UInt64 = UInt64(0)
    while (index < length) {
        bytes[Int64(index)] = unsafe { input.read(Int64(index)) }
        index += UInt64(1)
    }
    bytes
}

@C
public func png4cj_preview_abi_version(): UInt32 {
    PNG_C_ABI_PREVIEW_VERSION
}

@C
public func png4cj_capabilities(): UInt64 {
    PNG_C_ABI_PREVIEW_CAPABILITIES
}

@C
public func png4cj_libpng_version(
    output: CPointer<UInt8>,
    outputCapacity: UIntNative,
    required: CPointer<UIntNative>
): Int32 {
    pngCAbiWriteText(
        output,
        UInt64(outputCapacity),
        required,
        PNG_C_ABI_LIBPNG_VERSION
    )
}

@C
public func png4cj_check_signature(
    input: CPointer<UInt8>,
    inputLength: UIntNative,
    result: CPointer<Int32>,
    message: CPointer<UInt8>,
    messageCapacity: UIntNative
): Int32 {
    let length = UInt64(inputLength)
    let messageLength = UInt64(messageCapacity)
    pngCAbiClearMessage(message, messageLength)
    if (result.isNull()) {
        pngCAbiWriteMessage(message, messageLength, "signature result pointer is null")
        return PNG_C_ABI_INVALID_ARGUMENT
    }
    unsafe { result.write(Int32(0)) }
    if (input.isNull() || length == UInt64(0) ||
        length > PNG_C_ABI_PREVIEW_MAX_INPUT_BYTES) {
        pngCAbiWriteMessage(message, messageLength, "signature input is null, empty, or exceeds the preview limit")
        return PNG_C_ABI_INVALID_ARGUMENT
    }
    let prefixLength = if (length < UInt64(PNG_SIGNATURE.size)) {
        length
    } else {
        UInt64(PNG_SIGNATURE.size)
    }
    let prefix = pngCAbiReadInput(input, prefixLength)
    unsafe { result.write(if (isPngSignature(prefix)) { Int32(1) } else { Int32(0) }) }
    PNG_C_ABI_OK
}

@C
public func png4cj_decode_rgba8(
    input: CPointer<UInt8>,
    inputLength: UIntNative,
    output: CPointer<UInt8>,
    outputCapacity: UIntNative,
    width: CPointer<UInt32>,
    height: CPointer<UInt32>,
    stride: CPointer<UIntNative>,
    required: CPointer<UIntNative>,
    errorKind: CPointer<Int32>,
    errorOffset: CPointer<Int64>,
    message: CPointer<UInt8>,
    messageCapacity: UIntNative
): Int32 {
    let length = UInt64(inputLength)
    let capacity = UInt64(outputCapacity)
    let messageLength = UInt64(messageCapacity)
    pngCAbiClearDecodeOutputs(width, height, stride, required, errorKind, errorOffset)
    pngCAbiClearMessage(message, messageLength)
    if (input.isNull() || length == UInt64(0) ||
        length > PNG_C_ABI_PREVIEW_MAX_INPUT_BYTES || width.isNull() ||
        height.isNull() || stride.isNull() || required.isNull()) {
        pngCAbiWriteMessage(message, messageLength, "decode arguments are invalid or exceed the preview limit")
        return PNG_C_ABI_INVALID_ARGUMENT
    }

    try {
        let decoded = decodePngRgba8(pngCAbiReadInput(input, length), Scale)
        let rowStride = UInt64(decoded.ihdr.width) * UInt64(4)
        let outputBytes = rowStride * UInt64(decoded.ihdr.height)
        unsafe {
            width.write(decoded.ihdr.width)
            height.write(decoded.ihdr.height)
            stride.write(UIntNative(rowStride))
            required.write(UIntNative(outputBytes))
        }
        if (output.isNull() || capacity < outputBytes) {
            pngCAbiWriteMessage(message, messageLength, "output buffer is smaller than the decoded RGBA8 image")
            return PNG_C_ABI_BUFFER_TOO_SMALL
        }

        var rowIndex: Int64 = 0
        var outputOffset: Int64 = 0
        while (rowIndex < decoded.rowCount()) {
            let row = decoded.row(rowIndex)
            var column: Int64 = 0
            while (column < row.size) {
                unsafe { output.write(outputOffset + column, row[column]) }
                column += 1
            }
            outputOffset += row.size
            rowIndex += 1
        }
        return PNG_C_ABI_OK
    } catch (error: PngFormatException) {
        unsafe {
            if (!errorKind.isNull()) { errorKind.write(Int32(error.kind.ordinalValue())) }
            if (!errorOffset.isNull()) { errorOffset.write(error.offset) }
        }
        pngCAbiWriteMessage(message, messageLength, error.message)
        return PNG_C_ABI_DECODE_ERROR
    } catch (error: Exception) {
        pngCAbiWriteMessage(message, messageLength, error.message)
        return PNG_C_ABI_INTERNAL_ERROR
    }
}
