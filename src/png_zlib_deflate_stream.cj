package libpng4cj

private let ZLIB_DEFLATE_OK: Int32 = Int32(0)
private let ZLIB_DEFLATE_STREAM_END: Int32 = Int32(1)
private let ZLIB_DEFLATE_STREAM_ERROR: Int32 = Int32(-2)
private let ZLIB_DEFLATE_DATA_ERROR: Int32 = Int32(-3)
private let ZLIB_DEFLATE_MEMORY_ERROR: Int32 = Int32(-4)
private let ZLIB_DEFLATE_BUFFER_ERROR: Int32 = Int32(-5)
private let ZLIB_DEFLATE_VERSION_ERROR: Int32 = Int32(-6)
private let ZLIB_DEFLATE_NO_FLUSH: Int32 = Int32(0)
private let ZLIB_DEFLATE_FINISH: Int32 = Int32(4)

foreign func deflateInit_(
    stream: CPointer<PngZStreamNative>,
    level: Int32,
    version: CString,
    streamSize: Int32
): Int32
foreign func deflate(stream: CPointer<PngZStreamNative>, flush: Int32): Int32
foreign func deflateEnd(stream: CPointer<PngZStreamNative>): Int32

private func pngDeflateFailure(status: Int32): Nothing {
    let detail = if (status == ZLIB_DEFLATE_STREAM_ERROR) {
        "zlib incremental deflate state is invalid"
    } else if (status == ZLIB_DEFLATE_MEMORY_ERROR) {
        "zlib incremental deflate could not allocate memory"
    } else if (status == ZLIB_DEFLATE_BUFFER_ERROR) {
        "zlib incremental deflate made no progress"
    } else if (status == ZLIB_DEFLATE_VERSION_ERROR) {
        "zlib incremental deflate ABI version does not match"
    } else {
        "zlib incremental deflate failed with status ${status}"
    }
    throw PngFormatException(ZlibFailure, -1, detail)
}

public class PngIncrementalDeflater {
    private let maxOutputBytes: UInt64
    private let outputChunkBytes: Int64
    private let stream: CPointer<PngZStreamNative>
    private var totalInputValue: UInt64 = UInt64(0)
    private var totalOutputValue: UInt64 = UInt64(0)
    private var finishedValue: Bool = false
    private var closedValue: Bool = false

    public init(
        level: Int32,
        maxOutputBytes: UInt64,
        outputChunkBytes: Int64
    ) {
        if (level < Int32(-1) || level > Int32(9)) {
            throw PngFormatException(
                InvalidArgument, -1,
                "zlib compression level must be in -1..9"
            )
        }
        if (maxOutputBytes == UInt64(0) || maxOutputBytes > UInt64(Int64.Max)) {
            throw PngFormatException(
                InvalidArgument, -1,
                "maximum incremental deflate output must be in 1..Int64.Max"
            )
        }
        if (outputChunkBytes <= Int64(0) ||
            outputChunkBytes > Int64(UInt32.Max)) {
            throw PngFormatException(
                InvalidArgument, -1,
                "incremental deflate output chunk must be in 1..UInt32.Max"
            )
        }
        this.maxOutputBytes = maxOutputBytes
        this.outputChunkBytes = outputChunkBytes
        stream = unsafe { LibC.malloc<PngZStreamNative>(count: 1) }
        if (stream.isNull()) {
            throw PngFormatException(
                ZlibFailure, -1, "failed to allocate zlib deflate stream state"
            )
        }
        unsafe { stream.write(PngZStreamNative()) }
        let status = unsafe {
            deflateInit_(
                stream, level, zlibVersion(), Int32(sizeOf<PngZStreamNative>())
            )
        }
        if (status != ZLIB_DEFLATE_OK) {
            unsafe { LibC.free(stream) }
            pngDeflateFailure(status)
        }
    }

    public init(level: Int32, maxOutputBytes: UInt64) {
        this(level, maxOutputBytes, Int64(32_768))
    }

    public func totalInputBytes(): UInt64 {
        totalInputValue
    }

    public func totalOutputBytes(): UInt64 {
        totalOutputValue
    }

    public func finished(): Bool {
        finishedValue
    }

    public func closed(): Bool {
        closedValue
    }

    private func requireWritable(): Unit {
        if (closedValue) {
            throw PngFormatException(
                SessionClosed, -1, "incremental deflate stream is closed"
            )
        }
        if (finishedValue) {
            throw PngFormatException(
                InvalidArgument, -1, "incremental deflate stream is finished"
            )
        }
    }

    private func outputCapacity(): Int64 {
        let remaining = maxOutputBytes - totalOutputValue
        if (remaining == UInt64(0)) {
            return Int64(1)
        }
        if (remaining < UInt64(outputChunkBytes)) {
            return Int64(remaining)
        }
        outputChunkBytes
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

    private func acceptOutput(
        output: Array<Byte>,
        produced: Int64,
        limitProbe: Bool,
        sink: (Array<Byte>) -> Unit
    ): Unit {
        if (limitProbe && produced > Int64(0)) {
            throw PngFormatException(
                DecodeLimitExceeded, -1,
                "incremental compressed PNG output exceeds configured limit"
            )
        }
        totalOutputValue += UInt64(produced)
        if (produced > Int64(0)) {
            sink(copyByteRange(output, Int64(0), produced))
        }
    }

    public func push(input: Array<Byte>, sink: (Array<Byte>) -> Unit): Unit {
        requireWritable()
        if (input.size == Int64(0)) {
            return
        }
        if (input.size > Int64(UInt32.Max)) {
            throw PngFormatException(
                DecodeLimitExceeded, -1,
                "incremental deflate input exceeds UInt32 per-call capacity"
            )
        }

        unsafe {
            let inputRaw = acquireArrayRawData(input)
            try {
                var native = stream.read()
                native.nextIn = inputRaw.pointer
                native.availIn = UInt32(input.size)
                stream.write(native)

                while (stream.read().availIn > UInt32(0)) {
                    let limitProbe = totalOutputValue == maxOutputBytes
                    let capacity = outputCapacity()
                    let output = Array<Byte>(capacity, repeat: UInt8(0))
                    let outputRaw = acquireArrayRawData(output)
                    var status: Int32 = ZLIB_DEFLATE_OK
                    var produced: Int64 = Int64(0)
                    var consumed: Int64 = Int64(0)
                    try {
                        native = stream.read()
                        let availableBefore = native.availIn
                        native.nextOut = outputRaw.pointer
                        native.availOut = UInt32(capacity)
                        stream.write(native)
                        status = deflate(stream, ZLIB_DEFLATE_NO_FLUSH)
                        native = stream.read()
                        produced = capacity - Int64(native.availOut)
                        consumed = Int64(availableBefore - native.availIn)
                    } finally {
                        releaseArrayRawData(outputRaw)
                    }

                    if (status != ZLIB_DEFLATE_OK) {
                        pngDeflateFailure(status)
                    }
                    totalInputValue += UInt64(consumed)
                    acceptOutput(output, produced, limitProbe, sink)
                    if (consumed == Int64(0) && produced == Int64(0)) {
                        pngDeflateFailure(ZLIB_DEFLATE_BUFFER_ERROR)
                    }
                }
            } finally {
                clearNativeBuffers()
                releaseArrayRawData(inputRaw)
            }
        }
    }

    public func finish(sink: (Array<Byte>) -> Unit): Unit {
        requireWritable()
        var ended: Bool = false
        while (!ended) {
            let limitProbe = totalOutputValue == maxOutputBytes
            let capacity = outputCapacity()
            let output = Array<Byte>(capacity, repeat: UInt8(0))
            var status: Int32 = ZLIB_DEFLATE_OK
            var produced: Int64 = Int64(0)
            unsafe {
                let outputRaw = acquireArrayRawData(output)
                try {
                    var native = stream.read()
                    native.nextIn = CPointer<UInt8>()
                    native.availIn = UInt32(0)
                    native.nextOut = outputRaw.pointer
                    native.availOut = UInt32(capacity)
                    stream.write(native)
                    status = deflate(stream, ZLIB_DEFLATE_FINISH)
                    native = stream.read()
                    produced = capacity - Int64(native.availOut)
                } finally {
                    clearNativeBuffers()
                    releaseArrayRawData(outputRaw)
                }
            }
            if (status != ZLIB_DEFLATE_OK &&
                status != ZLIB_DEFLATE_STREAM_END) {
                pngDeflateFailure(status)
            }
            acceptOutput(output, produced, limitProbe, sink)
            ended = status == ZLIB_DEFLATE_STREAM_END
            if (!ended && produced == Int64(0)) {
                pngDeflateFailure(ZLIB_DEFLATE_BUFFER_ERROR)
            }
        }
        finishedValue = true
    }

    public func close(): Unit {
        if (closedValue) {
            return
        }
        clearNativeBuffers()
        let status = unsafe { deflateEnd(stream) }
        unsafe { LibC.free(stream) }
        closedValue = true
        if (status != ZLIB_DEFLATE_OK &&
            !(status == ZLIB_DEFLATE_DATA_ERROR && !finishedValue)) {
            pngDeflateFailure(status)
        }
    }
}
