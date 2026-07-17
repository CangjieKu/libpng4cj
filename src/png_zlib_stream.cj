package libpng4cj

private let ZLIB_STREAM_END: Int32 = Int32(1)
private let ZLIB_STREAM_ERROR: Int32 = Int32(-2)
private let ZLIB_STREAM_DATA_ERROR: Int32 = Int32(-3)
private let ZLIB_STREAM_MEMORY_ERROR: Int32 = Int32(-4)
private let ZLIB_STREAM_BUFFER_ERROR: Int32 = Int32(-5)
private let ZLIB_STREAM_VERSION_ERROR: Int32 = Int32(-6)
private let ZLIB_NO_FLUSH: Int32 = Int32(0)

@When[os != "Windows"]
@C
struct PngZStreamNative {
    var nextIn: CPointer<UInt8> = CPointer<UInt8>()
    var availIn: UInt32 = UInt32(0)
    var totalIn: UIntNative = UIntNative(0)
    var nextOut: CPointer<UInt8> = CPointer<UInt8>()
    var availOut: UInt32 = UInt32(0)
    var totalOut: UIntNative = UIntNative(0)
    var message: CPointer<UInt8> = CPointer<UInt8>()
    var state: CPointer<Unit> = CPointer<Unit>()
    var allocate: CPointer<Unit> = CPointer<Unit>()
    var release: CPointer<Unit> = CPointer<Unit>()
    var opaque: CPointer<Unit> = CPointer<Unit>()
    var dataType: Int32 = Int32(0)
    var adler: UIntNative = UIntNative(0)
    var reserved: UIntNative = UIntNative(0)
}

@When[os == "Windows"]
@C
struct PngZStreamNative {
    var nextIn: CPointer<UInt8> = CPointer<UInt8>()
    var availIn: UInt32 = UInt32(0)
    var totalIn: UInt32 = UInt32(0)
    var nextOut: CPointer<UInt8> = CPointer<UInt8>()
    var availOut: UInt32 = UInt32(0)
    var totalOut: UInt32 = UInt32(0)
    var message: CPointer<UInt8> = CPointer<UInt8>()
    var state: CPointer<Unit> = CPointer<Unit>()
    var allocate: CPointer<Unit> = CPointer<Unit>()
    var release: CPointer<Unit> = CPointer<Unit>()
    var opaque: CPointer<Unit> = CPointer<Unit>()
    var dataType: Int32 = Int32(0)
    var adler: UInt32 = UInt32(0)
    var reserved: UInt32 = UInt32(0)
}

foreign func zlibVersion(): CString
foreign func inflateInit_(
    stream: CPointer<PngZStreamNative>,
    version: CString,
    streamSize: Int32
): Int32
foreign func inflate(stream: CPointer<PngZStreamNative>, flush: Int32): Int32
foreign func inflateEnd(stream: CPointer<PngZStreamNative>): Int32

private func pngStreamingZlibFailure(status: Int32): Nothing {
    let detail = if (status == ZLIB_STREAM_ERROR) {
        "zlib incremental stream state is invalid"
    } else if (status == ZLIB_STREAM_DATA_ERROR) {
        "zlib incremental stream is corrupt"
    } else if (status == ZLIB_STREAM_MEMORY_ERROR) {
        "zlib incremental stream could not allocate memory"
    } else if (status == ZLIB_STREAM_BUFFER_ERROR) {
        "zlib incremental stream made no progress"
    } else if (status == ZLIB_STREAM_VERSION_ERROR) {
        "zlib incremental stream ABI version does not match"
    } else {
        "zlib incremental stream failed with status ${status}"
    }
    throw PngFormatException(ZlibFailure, -1, detail)
}

public class PngIncrementalInflater {
    private let maxOutputBytes: UInt64
    private let outputChunkBytes: Int64
    private let stream: CPointer<PngZStreamNative>
    private var totalInputValue: UInt64 = UInt64(0)
    private var totalOutputValue: UInt64 = UInt64(0)
    private var endedValue: Bool = false
    private var closedValue: Bool = false

    public init(maxOutputBytes: UInt64, outputChunkBytes: Int64) {
        if (maxOutputBytes == UInt64(0) || maxOutputBytes > UInt64(Int64.Max)) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "maximum incremental inflate output must be in 1..Int64.Max"
            )
        }
        if (outputChunkBytes <= 0 || outputChunkBytes > Int64(UInt32.Max)) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "incremental inflate output chunk must be in 1..UInt32.Max"
            )
        }
        this.maxOutputBytes = maxOutputBytes
        this.outputChunkBytes = outputChunkBytes
        stream = unsafe { LibC.malloc<PngZStreamNative>(count: 1) }
        if (stream.isNull()) {
            throw PngFormatException(ZlibFailure, -1, "failed to allocate zlib stream state")
        }
        unsafe { stream.write(PngZStreamNative()) }
        let status = unsafe {
            inflateInit_(stream, zlibVersion(), Int32(sizeOf<PngZStreamNative>()))
        }
        if (status != Int32(0)) {
            unsafe { LibC.free(stream) }
            pngStreamingZlibFailure(status)
        }
    }

    public init(maxOutputBytes: UInt64) {
        this(maxOutputBytes, Int64(32_768))
    }

    public func totalInputBytes(): UInt64 {
        totalInputValue
    }

    public func totalOutputBytes(): UInt64 {
        totalOutputValue
    }

    public func ended(): Bool {
        endedValue
    }

    public func closed(): Bool {
        closedValue
    }

    private func requireOpen(): Unit {
        if (closedValue) {
            throw PngFormatException(SessionClosed, -1, "incremental zlib stream is closed")
        }
    }

    private func clearNativeBuffers(): Unit {
        unsafe {
            var native = stream.read()
            native.nextIn = CPointer<UInt8>()
            native.availIn = UInt32(0)
            native.nextOut = CPointer<UInt8>()
            native.availOut = UInt32(0)
            stream.write(native)
        }
    }

    public func push(
        input: Array<Byte>,
        sink: (Array<Byte>) -> Bool
    ): Int64 {
        requireOpen()
        if (endedValue || input.size == 0) {
            return Int64(0)
        }
        if (input.size > Int64(UInt32.Max)) {
            throw PngFormatException(
                DecodeLimitExceeded,
                -1,
                "incremental zlib input exceeds UInt32 per-call capacity"
            )
        }

        var consumed: Int64 = 0
        unsafe {
            let inputRaw = acquireArrayRawData(input)
            try {
                var native = stream.read()
                native.nextIn = inputRaw.pointer
                native.availIn = UInt32(input.size)
                stream.write(native)

                while (consumed < input.size && !endedValue) {
                    let remainingLimit = maxOutputBytes - totalOutputValue
                    let limitProbe = remainingLimit == UInt64(0)
                    let capacity = if (limitProbe) {
                        Int64(1)
                    } else if (remainingLimit < UInt64(outputChunkBytes)) {
                        Int64(remainingLimit)
                    } else {
                        outputChunkBytes
                    }
                    let output = Array<Byte>(capacity, repeat: UInt8(0))
                    let outputRaw = acquireArrayRawData(output)
                    var status: Int32 = Int32(0)
                    var produced: Int64 = 0
                    var consumedNow: Int64 = 0
                    try {
                        native = stream.read()
                        let availableBefore = native.availIn
                        native.nextOut = outputRaw.pointer
                        native.availOut = UInt32(capacity)
                        stream.write(native)
                        status = inflate(stream, ZLIB_NO_FLUSH)
                        native = stream.read()
                        produced = capacity - Int64(native.availOut)
                        consumedNow = Int64(availableBefore - native.availIn)
                    } finally {
                        releaseArrayRawData(outputRaw)
                    }

                    consumed += consumedNow
                    totalInputValue += UInt64(consumedNow)
                    if (limitProbe && produced > 0) {
                        throw PngFormatException(
                            DecodeLimitExceeded,
                            -1,
                            "incremental zlib output exceeds configured limit"
                        )
                    }
                    totalOutputValue += UInt64(produced)
                    if (status != Int32(0) && status != ZLIB_STREAM_END &&
                        status != ZLIB_STREAM_BUFFER_ERROR) {
                        pngStreamingZlibFailure(status)
                    }
                    if (status == ZLIB_STREAM_END) {
                        endedValue = true
                    }
                    if (produced > 0) {
                        if (!sink(copyByteRange(output, 0, produced))) {
                            return consumed
                        }
                    }
                    if (status == ZLIB_STREAM_END) {
                        return consumed
                    }
                    if (consumedNow == 0 && produced == 0) {
                        if (stream.read().availIn == UInt32(0)) {
                            return consumed
                        }
                        pngStreamingZlibFailure(ZLIB_STREAM_BUFFER_ERROR)
                    }
                    if (stream.read().availIn == UInt32(0)) {
                        return consumed
                    }
                }
            } finally {
                clearNativeBuffers()
                releaseArrayRawData(inputRaw)
            }
        }
        consumed
    }

    public func finish(): Unit {
        requireOpen()
        if (!endedValue) {
            throw PngFormatException(ZlibFailure, -1, "incremental zlib stream is incomplete")
        }
    }

    public func close(): Unit {
        if (closedValue) {
            return
        }
        clearNativeBuffers()
        let status = unsafe { inflateEnd(stream) }
        unsafe { LibC.free(stream) }
        closedValue = true
        if (status != Int32(0)) {
            pngStreamingZlibFailure(status)
        }
    }
}
