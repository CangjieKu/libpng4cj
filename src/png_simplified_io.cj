package libpng4cj

import std.collection.ArrayList
import std.fs.*
import std.io.*

public let PNG_DEFAULT_MAX_SIMPLIFIED_INPUT_BYTES: UInt64 = UInt64(512_000_000)
public let PNG_DEFAULT_SIMPLIFIED_READ_BUFFER_BYTES: UInt32 = UInt32(64_000)

public class PngSimplifiedIoLimits {
    public let maxInputBytes: UInt64
    public let readBufferBytes: UInt32

    public init(maxInputBytes: UInt64, readBufferBytes: UInt32) {
        if (maxInputBytes == UInt64(0) || maxInputBytes > UInt64(Int64.Max)) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified input byte limit must be in 1..Int64.Max"
            )
        }
        if (readBufferBytes == UInt32(0) ||
            readBufferBytes > UInt32(16_000_000)) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified read buffer size must be in 1..16000000"
            )
        }
        this.maxInputBytes = maxInputBytes
        this.readBufferBytes = readBufferBytes
    }

    public init(maxInputBytes: UInt64) {
        this(maxInputBytes, PNG_DEFAULT_SIMPLIFIED_READ_BUFFER_BYTES)
    }

    public init() {
        this(
            PNG_DEFAULT_MAX_SIMPLIFIED_INPUT_BYTES,
            PNG_DEFAULT_SIMPLIFIED_READ_BUFFER_BYTES
        )
    }
}

private func pngSimplifiedIoFailure(
    stage: String,
    offset: Int64,
    error: Exception
): PngFormatException {
    PngFormatException(
        IoFailure, offset,
        "simplified PNG ${stage} failed: ${error.message}"
    )
}

private func pngAppendSimplifiedBytes(
    output: ArrayList<Byte>,
    bytes: Array<Byte>,
    count: Int64
): Unit {
    var index: Int64 = Int64(0)
    while (index < count) {
        output.add(bytes[index])
        index += Int64(1)
    }
}

func pngReadSimplifiedStreamBytes(
    input: InputStream,
    limits: PngSimplifiedIoLimits
): Array<Byte> {
    let output = ArrayList<Byte>()
    let buffer = Array<Byte>(Int64(limits.readBufferBytes), repeat: UInt8(0))
    var total: UInt64 = UInt64(0)
    while (true) {
        let count = try {
            input.read(buffer)
        } catch (error: Exception) {
            throw pngSimplifiedIoFailure("read", Int64(total), error)
        }
        if (count < Int64(0) || count > buffer.size) {
            throw PngFormatException(
                IoFailure, Int64(total),
                "simplified PNG read returned an invalid byte count"
            )
        }
        if (count == Int64(0)) { break }
        let incoming = UInt64(count)
        if (incoming > limits.maxInputBytes - total) {
            throw PngFormatException(
                DecodeLimitExceeded, Int64(total),
                "simplified PNG input exceeds the configured byte limit"
            )
        }
        pngAppendSimplifiedBytes(output, buffer, count)
        total += incoming
    }
    output.toArray()
}

private func pngOpenSimplifiedFile(
    path: String,
    mode: OpenMode,
    stage: String
): File {
    try {
        File(path, mode)
    } catch (error: Exception) {
        throw pngSimplifiedIoFailure("${stage} open '${path}'", -1, error)
    }
}

private func pngCloseSimplifiedFileQuietly(file: File): Unit {
    try {
        file.close()
    } catch (_: Exception) {}
}

private func pngCloseSimplifiedFile(file: File, path: String): Unit {
    try {
        file.close()
    } catch (error: Exception) {
        throw pngSimplifiedIoFailure("close '${path}'", -1, error)
    }
}

func pngReadSimplifiedFileBytes(
    path: String,
    limits: PngSimplifiedIoLimits
): Array<Byte> {
    let file = pngOpenSimplifiedFile(path, Read, "read")
    let bytes = try {
        pngReadSimplifiedStreamBytes(file, limits)
    } catch (error: PngFormatException) {
        pngCloseSimplifiedFileQuietly(file)
        throw error
    }
    pngCloseSimplifiedFile(file, path)
    bytes
}

private func pngWriteSimplifiedStreamBytes(
    output: OutputStream,
    bytes: Array<Byte>
): Unit {
    try {
        output.write(bytes)
    } catch (error: Exception) {
        throw pngSimplifiedIoFailure("write", -1, error)
    }
    try {
        output.flush()
    } catch (error: Exception) {
        throw pngSimplifiedIoFailure("flush", -1, error)
    }
}

private func pngWriteSimplifiedFileBytes(
    path: String,
    bytes: Array<Byte>
): Unit {
    let file = pngOpenSimplifiedFile(path, Write, "write")
    try {
        pngWriteSimplifiedStreamBytes(file, bytes)
    } catch (error: PngFormatException) {
        pngCloseSimplifiedFileQuietly(file)
        throw error
    }
    pngCloseSimplifiedFile(file, path)
}

public func beginPngImageReadFromStream(
    input: InputStream,
    limits: PngReadLimits,
    ioLimits: PngSimplifiedIoLimits
): PngImage {
    let image = PngImage()
    image.beginReadFromStream(input, limits, ioLimits)
    image
}

public func beginPngImageReadFromStream(
    input: InputStream,
    limits: PngReadLimits
): PngImage {
    beginPngImageReadFromStream(input, limits, PngSimplifiedIoLimits())
}

public func beginPngImageReadFromStream(input: InputStream): PngImage {
    beginPngImageReadFromStream(input, PngReadLimits())
}

public func beginPngImageReadFromFile(
    path: String,
    limits: PngReadLimits,
    ioLimits: PngSimplifiedIoLimits
): PngImage {
    let image = PngImage()
    image.beginReadFromFile(path, limits, ioLimits)
    image
}

public func beginPngImageReadFromFile(
    path: String,
    limits: PngReadLimits
): PngImage {
    beginPngImageReadFromFile(path, limits, PngSimplifiedIoLimits())
}

public func beginPngImageReadFromFile(path: String): PngImage {
    beginPngImageReadFromFile(path, PngReadLimits())
}

public func writePngImageToStream(
    image: PngImageBuffer,
    output: OutputStream,
    metadata: PngWriteMetadata,
    controls: PngWriteControlState,
    interlaceMethod: PngInterlaceMethod,
    limits: PngWriteLimits
): Unit {
    pngWriteSimplifiedStreamBytes(
        output,
        writePngImageToMemory(
            image, metadata, controls, interlaceMethod, limits
        )
    )
}

public func writePngImageToStream(
    image: PngImageBuffer,
    output: OutputStream,
    interlaceMethod: PngInterlaceMethod
): Unit {
    writePngImageToStream(
        image, output, PngWriteMetadata(), PngWriteControlState(),
        interlaceMethod, PngWriteLimits()
    )
}

public func writePngImageToStream(
    image: PngImageBuffer,
    output: OutputStream
): Unit {
    writePngImageToStream(image, output, None)
}

public func writePngImageToFile(
    image: PngImageBuffer,
    path: String,
    metadata: PngWriteMetadata,
    controls: PngWriteControlState,
    interlaceMethod: PngInterlaceMethod,
    limits: PngWriteLimits
): Unit {
    pngWriteSimplifiedFileBytes(
        path,
        writePngImageToMemory(
            image, metadata, controls, interlaceMethod, limits
        )
    )
}

public func writePngImageToFile(
    image: PngImageBuffer,
    path: String,
    interlaceMethod: PngInterlaceMethod
): Unit {
    writePngImageToFile(
        image, path, PngWriteMetadata(), PngWriteControlState(),
        interlaceMethod, PngWriteLimits()
    )
}

public func writePngImageToFile(image: PngImageBuffer, path: String): Unit {
    writePngImageToFile(image, path, None)
}

public func writePngLinearImageToStream(
    image: PngLinearImageBuffer,
    output: OutputStream,
    convertTo8Bit: Bool,
    metadata: PngWriteMetadata,
    controls: PngWriteControlState,
    interlaceMethod: PngInterlaceMethod,
    limits: PngWriteLimits
): Unit {
    pngWriteSimplifiedStreamBytes(
        output,
        writePngLinearImageToMemory(
            image, convertTo8Bit, metadata, controls, interlaceMethod, limits
        )
    )
}

public func writePngLinearImageToStream(
    image: PngLinearImageBuffer,
    output: OutputStream,
    convertTo8Bit: Bool,
    interlaceMethod: PngInterlaceMethod
): Unit {
    writePngLinearImageToStream(
        image, output, convertTo8Bit, PngWriteMetadata(),
        PngWriteControlState(), interlaceMethod, PngWriteLimits()
    )
}

public func writePngLinearImageToStream(
    image: PngLinearImageBuffer,
    output: OutputStream,
    convertTo8Bit: Bool
): Unit {
    writePngLinearImageToStream(image, output, convertTo8Bit, None)
}

public func writePngLinearImageToStream(
    image: PngLinearImageBuffer,
    output: OutputStream
): Unit {
    writePngLinearImageToStream(image, output, false)
}

public func writePngLinearImageToFile(
    image: PngLinearImageBuffer,
    path: String,
    convertTo8Bit: Bool,
    metadata: PngWriteMetadata,
    controls: PngWriteControlState,
    interlaceMethod: PngInterlaceMethod,
    limits: PngWriteLimits
): Unit {
    pngWriteSimplifiedFileBytes(
        path,
        writePngLinearImageToMemory(
            image, convertTo8Bit, metadata, controls, interlaceMethod, limits
        )
    )
}

public func writePngLinearImageToFile(
    image: PngLinearImageBuffer,
    path: String,
    convertTo8Bit: Bool,
    interlaceMethod: PngInterlaceMethod
): Unit {
    writePngLinearImageToFile(
        image, path, convertTo8Bit, PngWriteMetadata(),
        PngWriteControlState(), interlaceMethod, PngWriteLimits()
    )
}

public func writePngLinearImageToFile(
    image: PngLinearImageBuffer,
    path: String,
    convertTo8Bit: Bool
): Unit {
    writePngLinearImageToFile(image, path, convertTo8Bit, None)
}

public func writePngLinearImageToFile(
    image: PngLinearImageBuffer,
    path: String
): Unit {
    writePngLinearImageToFile(image, path, false)
}

public func writePngColormapImageToStream(
    image: PngColormapImageBuffer,
    output: OutputStream,
    metadata: PngWriteMetadata,
    controls: PngWriteControlState,
    interlaceMethod: PngInterlaceMethod,
    limits: PngWriteLimits
): Unit {
    pngWriteSimplifiedStreamBytes(
        output,
        writePngColormapImageToMemory(
            image, metadata, controls, interlaceMethod, limits
        )
    )
}

public func writePngColormapImageToStream(
    image: PngColormapImageBuffer,
    output: OutputStream,
    interlaceMethod: PngInterlaceMethod
): Unit {
    writePngColormapImageToStream(
        image, output, PngWriteMetadata(), PngWriteControlState(),
        interlaceMethod, PngWriteLimits()
    )
}

public func writePngColormapImageToStream(
    image: PngColormapImageBuffer,
    output: OutputStream
): Unit {
    writePngColormapImageToStream(image, output, None)
}

public func writePngColormapImageToFile(
    image: PngColormapImageBuffer,
    path: String,
    metadata: PngWriteMetadata,
    controls: PngWriteControlState,
    interlaceMethod: PngInterlaceMethod,
    limits: PngWriteLimits
): Unit {
    pngWriteSimplifiedFileBytes(
        path,
        writePngColormapImageToMemory(
            image, metadata, controls, interlaceMethod, limits
        )
    )
}

public func writePngColormapImageToFile(
    image: PngColormapImageBuffer,
    path: String,
    interlaceMethod: PngInterlaceMethod
): Unit {
    writePngColormapImageToFile(
        image, path, PngWriteMetadata(), PngWriteControlState(),
        interlaceMethod, PngWriteLimits()
    )
}

public func writePngColormapImageToFile(
    image: PngColormapImageBuffer,
    path: String
): Unit {
    writePngColormapImageToFile(image, path, None)
}
