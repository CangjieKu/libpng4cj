package libpng4cj

private let ZLIB_OK: Int32 = Int32(0)
private let ZLIB_DATA_ERROR: Int32 = Int32(-3)
private let ZLIB_MEMORY_ERROR: Int32 = Int32(-4)
private let ZLIB_BUFFER_ERROR: Int32 = Int32(-5)

private class BoundedInflateAttempt {
    let status: Int32
    let output: Array<Byte>
    let actualOutput: Int64
    let consumedInput: Int64

    init(status: Int32, output: Array<Byte>, actualOutput: Int64, consumedInput: Int64) {
        this.status = status
        this.output = output
        this.actualOutput = actualOutput
        this.consumedInput = consumedInput
    }
}

@When[os != "Windows"]
foreign func uncompress2(
    destination: CPointer<UInt8>,
    destinationLength: CPointer<UIntNative>,
    source: CPointer<UInt8>,
    sourceLength: CPointer<UIntNative>
): Int32

@When[os == "Windows"]
foreign func uncompress2(
    destination: CPointer<UInt8>,
    destinationLength: CPointer<UInt32>,
    source: CPointer<UInt8>,
    sourceLength: CPointer<UInt32>
): Int32

private func throwZlibStatus(status: Int32): Nothing {
    let detail = if (status == ZLIB_DATA_ERROR) {
        "zlib stream is corrupt or incomplete"
    } else if (status == ZLIB_MEMORY_ERROR) {
        "zlib could not allocate memory"
    } else if (status == ZLIB_BUFFER_ERROR) {
        "zlib output exceeds the expected PNG size"
    } else {
        "zlib failed with status ${status}"
    }
    throw PngFormatException(ZlibFailure, -1, detail)
}

private func validateInflateResult(
    status: Int32,
    actualOutput: Int64,
    expectedOutput: Int64,
    consumedInput: Int64,
    availableInput: Int64
): Unit {
    if (status != ZLIB_OK) {
        if (status == ZLIB_BUFFER_ERROR && actualOutput == expectedOutput) {
            throw PngFormatException(
                InflatedSizeMismatch,
                -1,
                "zlib stream expands beyond the expected PNG row bytes"
            )
        }
        throwZlibStatus(status)
    }
    if (actualOutput != expectedOutput) {
        throw PngFormatException(
            InflatedSizeMismatch,
            -1,
            "zlib output size does not match PNG row geometry"
        )
    }
    if (consumedInput != availableInput) {
        throw PngFormatException(
            TrailingCompressedData,
            consumedInput,
            "IDAT contains bytes after the end of the zlib stream"
        )
    }
}

@When[os != "Windows"]
private func inflateZlibExactNative(compressed: Array<Byte>, expectedSize: Int64): Array<Byte> {
    let output = Array<Byte>(expectedSize, repeat: 0)
    var status: Int32 = Int32(0)
    var actualOutput: Int64 = 0
    var consumedInput: Int64 = 0
    unsafe {
        let destinationLength = LibC.malloc<UIntNative>(count: 1)
        let sourceLength = LibC.malloc<UIntNative>(count: 1)
        if (destinationLength.isNull() || sourceLength.isNull()) {
            if (!sourceLength.isNull()) {
                LibC.free(sourceLength)
            }
            if (!destinationLength.isNull()) {
                LibC.free(destinationLength)
            }
            throw PngFormatException(ZlibFailure, -1, "failed to allocate zlib length state")
        }
        let inputRaw = acquireArrayRawData(compressed)
        let outputRaw = acquireArrayRawData(output)
        try {
            destinationLength.write(UIntNative(expectedSize))
            sourceLength.write(UIntNative(compressed.size))
            status = uncompress2(
                outputRaw.pointer,
                destinationLength,
                inputRaw.pointer,
                sourceLength
            )
            actualOutput = Int64(destinationLength.read())
            consumedInput = Int64(sourceLength.read())
        } finally {
            releaseArrayRawData(outputRaw)
            releaseArrayRawData(inputRaw)
            LibC.free(sourceLength)
            LibC.free(destinationLength)
        }
    }
    validateInflateResult(status, actualOutput, expectedSize, consumedInput, compressed.size)
    output
}

@When[os == "Windows"]
private func inflateZlibExactNative(compressed: Array<Byte>, expectedSize: Int64): Array<Byte> {
    if (expectedSize > Int64(UInt32.Max) || compressed.size > Int64(UInt32.Max)) {
        throw PngFormatException(DecodeLimitExceeded, -1, "Windows zlib call exceeds 32-bit uLong")
    }
    let output = Array<Byte>(expectedSize, repeat: 0)
    var status: Int32 = Int32(0)
    var actualOutput: Int64 = 0
    var consumedInput: Int64 = 0
    unsafe {
        let destinationLength = LibC.malloc<UInt32>(count: 1)
        let sourceLength = LibC.malloc<UInt32>(count: 1)
        if (destinationLength.isNull() || sourceLength.isNull()) {
            if (!sourceLength.isNull()) {
                LibC.free(sourceLength)
            }
            if (!destinationLength.isNull()) {
                LibC.free(destinationLength)
            }
            throw PngFormatException(ZlibFailure, -1, "failed to allocate zlib length state")
        }
        let inputRaw = acquireArrayRawData(compressed)
        let outputRaw = acquireArrayRawData(output)
        try {
            destinationLength.write(UInt32(expectedSize))
            sourceLength.write(UInt32(compressed.size))
            status = uncompress2(
                outputRaw.pointer,
                destinationLength,
                inputRaw.pointer,
                sourceLength
            )
            actualOutput = Int64(destinationLength.read())
            consumedInput = Int64(sourceLength.read())
        } finally {
            releaseArrayRawData(outputRaw)
            releaseArrayRawData(inputRaw)
            LibC.free(sourceLength)
            LibC.free(destinationLength)
        }
    }
    validateInflateResult(status, actualOutput, expectedSize, consumedInput, compressed.size)
    output
}

public func inflatePngZlibExact(compressed: Array<Byte>, expectedSize: Int64): Array<Byte> {
    if (compressed.size == 0) {
        throw PngFormatException(ZlibFailure, -1, "IDAT does not contain a zlib stream")
    }
    if (expectedSize <= 0) {
        throw PngFormatException(InvalidArgument, -1, "expected inflate size must be positive")
    }
    inflateZlibExactNative(compressed, expectedSize)
}

@When[os != "Windows"]
private func attemptBoundedInflate(compressed: Array<Byte>, capacity: Int64): BoundedInflateAttempt {
    let output = Array<Byte>(capacity, repeat: 0)
    var status: Int32 = Int32(0)
    var actualOutput: Int64 = 0
    var consumedInput: Int64 = 0
    unsafe {
        let destinationLength = LibC.malloc<UIntNative>(count: 1)
        let sourceLength = LibC.malloc<UIntNative>(count: 1)
        if (destinationLength.isNull() || sourceLength.isNull()) {
            if (!sourceLength.isNull()) {
                LibC.free(sourceLength)
            }
            if (!destinationLength.isNull()) {
                LibC.free(destinationLength)
            }
            throw PngFormatException(ZlibFailure, -1, "failed to allocate bounded zlib length state")
        }
        let inputRaw = acquireArrayRawData(compressed)
        let outputRaw = acquireArrayRawData(output)
        try {
            destinationLength.write(UIntNative(capacity))
            sourceLength.write(UIntNative(compressed.size))
            status = uncompress2(outputRaw.pointer, destinationLength, inputRaw.pointer, sourceLength)
            actualOutput = Int64(destinationLength.read())
            consumedInput = Int64(sourceLength.read())
        } finally {
            releaseArrayRawData(outputRaw)
            releaseArrayRawData(inputRaw)
            LibC.free(sourceLength)
            LibC.free(destinationLength)
        }
    }
    BoundedInflateAttempt(status, output, actualOutput, consumedInput)
}

@When[os == "Windows"]
private func attemptBoundedInflate(compressed: Array<Byte>, capacity: Int64): BoundedInflateAttempt {
    if (capacity > Int64(UInt32.Max) || compressed.size > Int64(UInt32.Max)) {
        throw PngFormatException(DecodeLimitExceeded, -1, "Windows bounded zlib call exceeds 32-bit uLong")
    }
    let output = Array<Byte>(capacity, repeat: 0)
    var status: Int32 = Int32(0)
    var actualOutput: Int64 = 0
    var consumedInput: Int64 = 0
    unsafe {
        let destinationLength = LibC.malloc<UInt32>(count: 1)
        let sourceLength = LibC.malloc<UInt32>(count: 1)
        if (destinationLength.isNull() || sourceLength.isNull()) {
            if (!sourceLength.isNull()) {
                LibC.free(sourceLength)
            }
            if (!destinationLength.isNull()) {
                LibC.free(destinationLength)
            }
            throw PngFormatException(ZlibFailure, -1, "failed to allocate bounded zlib length state")
        }
        let inputRaw = acquireArrayRawData(compressed)
        let outputRaw = acquireArrayRawData(output)
        try {
            destinationLength.write(UInt32(capacity))
            sourceLength.write(UInt32(compressed.size))
            status = uncompress2(outputRaw.pointer, destinationLength, inputRaw.pointer, sourceLength)
            actualOutput = Int64(destinationLength.read())
            consumedInput = Int64(sourceLength.read())
        } finally {
            releaseArrayRawData(outputRaw)
            releaseArrayRawData(inputRaw)
            LibC.free(sourceLength)
            LibC.free(destinationLength)
        }
    }
    BoundedInflateAttempt(status, output, actualOutput, consumedInput)
}

func inflatePngZlibBounded(compressed: Array<Byte>, maxOutput: Int64): Array<Byte> {
    if (compressed.size == 0) {
        throw PngFormatException(ZlibFailure, -1, "compressed metadata does not contain a zlib stream")
    }
    if (maxOutput < 0) {
        throw PngFormatException(InvalidArgument, -1, "maximum bounded inflate size cannot be negative")
    }

    var capacity: Int64 = 256
    if (compressed.size <= Int64.Max / 4 && compressed.size * 4 > capacity) {
        capacity = compressed.size * 4
    }
    if (maxOutput > 0 && capacity > maxOutput) {
        capacity = maxOutput
    }
    if (capacity == 0) {
        capacity = 1
    }

    while (true) {
        let attempt = attemptBoundedInflate(compressed, capacity)
        if (attempt.status == ZLIB_OK) {
            if (attempt.consumedInput != compressed.size) {
                throw PngFormatException(
                    TrailingCompressedData,
                    attempt.consumedInput,
                    "compressed metadata contains bytes after the zlib stream"
                )
            }
            if (attempt.actualOutput > maxOutput) {
                throw PngFormatException(
                    DecodeLimitExceeded,
                    -1,
                    "compressed metadata exceeds the configured chunk-byte limit"
                )
            }
            return copyByteRange(attempt.output, 0, attempt.actualOutput)
        }
        if (attempt.status != ZLIB_BUFFER_ERROR) {
            throwZlibStatus(attempt.status)
        }
        if (capacity >= maxOutput) {
            throw PngFormatException(
                DecodeLimitExceeded,
                -1,
                "compressed metadata exceeds the configured chunk-byte limit"
            )
        }
        let doubled = if (capacity > Int64.Max / 2) { Int64.Max } else { capacity * 2 }
        capacity = if (doubled > maxOutput) { maxOutput } else { doubled }
    }
    throw PngFormatException(ZlibFailure, -1, "bounded zlib inflate terminated unexpectedly")
}
