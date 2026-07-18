package libpng4cj

import std.collection.ArrayList

public enum PngWriteOutputKind <: Equatable<PngWriteOutputKind> & ToString {
    | WriteOutputSignature
    | WriteOutputChunk

    public operator func ==(right: PngWriteOutputKind): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngWriteOutputKind): Bool {
        !(this == right)
    }

    private func ordinalValue(): Int64 {
        match (this) {
            case WriteOutputSignature => Int64(0)
            case WriteOutputChunk => Int64(1)
        }
    }

    public func toString(): String {
        match (this) {
            case WriteOutputSignature => "SIGNATURE"
            case WriteOutputChunk => "CHUNK"
        }
    }
}

public class PngWriteOutputContext {
    public let sequenceNumber: UInt64
    public let kind: PngWriteOutputKind
    public let bytesBefore: UInt64
    public let bytesAfter: UInt64
    public let finalOutput: Bool
    private let ownedChunkType: Array<Byte>

    init(
        sequenceNumber: UInt64,
        kind: PngWriteOutputKind,
        chunkType: Array<Byte>,
        bytesBefore: UInt64,
        bytesAfter: UInt64,
        finalOutput: Bool
    ) {
        this.sequenceNumber = sequenceNumber
        this.kind = kind
        ownedChunkType = chunkType.clone()
        this.bytesBefore = bytesBefore
        this.bytesAfter = bytesAfter
        this.finalOutput = finalOutput
    }

    public func chunkType(): Array<Byte> {
        ownedChunkType.clone()
    }
}

public class PngWriteFlushContext {
    public let bytesWritten: UInt64
    public let emissionCount: UInt64

    init(bytesWritten: UInt64, emissionCount: UInt64) {
        this.bytesWritten = bytesWritten
        this.emissionCount = emissionCount
    }
}

public class PngWriteSinkResult {
    public let bytesWritten: UInt64
    public let emissionCount: UInt64
    public let flushCount: UInt64

    init(bytesWritten: UInt64, emissionCount: UInt64, flushCount: UInt64) {
        this.bytesWritten = bytesWritten
        this.emissionCount = emissionCount
        this.flushCount = flushCount
    }
}

private func pngDiscardWriteOutput(
    context: PngWriteOutputContext,
    bytes: Array<Byte>
): Unit {}

private func pngNoopWriteFlush(context: PngWriteFlushContext): Unit {}

public class PngWriteSink {
    private var writeCallbackValue:
        (PngWriteOutputContext, Array<Byte>) -> Unit = pngDiscardWriteOutput
    private var flushCallbackValue:
        (PngWriteFlushContext) -> Unit = pngNoopWriteFlush

    public init() {}

    public func setWriteCallback(): Unit {
        writeCallbackValue = pngDiscardWriteOutput
    }

    public func setWriteCallback(
        callback: (PngWriteOutputContext, Array<Byte>) -> Unit
    ): Unit {
        writeCallbackValue = callback
    }

    public func setFlushCallback(): Unit {
        flushCallbackValue = pngNoopWriteFlush
    }

    public func setFlushCallback(callback: (PngWriteFlushContext) -> Unit): Unit {
        flushCallbackValue = callback
    }

    func emit(context: PngWriteOutputContext, bytes: Array<Byte>): Unit {
        let callback = writeCallbackValue
        callback(context, bytes.clone())
    }

    func flush(context: PngWriteFlushContext): Unit {
        let callback = flushCallbackValue
        callback(context)
    }
}

class PngPreparedWriteOutput {
    let ihdr: PngIhdr
    let palette: Array<Byte>
    let metadataPlan: PngWriteMetadataPlan
    let compressed: Array<Byte>
    let idatChunkBytes: UInt32
    let expectedOutput: UInt64

    init(
        ihdr: PngIhdr,
        palette: Array<Byte>,
        metadataPlan: PngWriteMetadataPlan,
        compressed: Array<Byte>,
        idatChunkBytes: UInt32,
        expectedOutput: UInt64
    ) {
        this.ihdr = ihdr
        this.palette = palette
        this.metadataPlan = metadataPlan
        this.compressed = compressed
        this.idatChunkBytes = idatChunkBytes
        this.expectedOutput = expectedOutput
    }
}

private class PngWriteEmissionCursor {
    private let writeAction: (PngWriteOutputContext, Array<Byte>) -> Unit
    private let flushAction: (PngWriteFlushContext) -> Unit
    private var bytesWrittenValue: UInt64 = UInt64(0)
    private var emissionCountValue: UInt64 = UInt64(0)
    private var flushCountValue: UInt64 = UInt64(0)

    init(
        writeAction: (PngWriteOutputContext, Array<Byte>) -> Unit,
        flushAction: (PngWriteFlushContext) -> Unit
    ) {
        this.writeAction = writeAction
        this.flushAction = flushAction
    }

    func emit(
        kind: PngWriteOutputKind,
        chunkType: Array<Byte>,
        bytes: Array<Byte>,
        finalOutput: Bool
    ): Unit {
        let before = bytesWrittenValue
        let after = before + UInt64(bytes.size)
        let context = PngWriteOutputContext(
            emissionCountValue, kind, chunkType, before, after, finalOutput
        )
        writeAction(context, bytes)
        bytesWrittenValue = after
        emissionCountValue += UInt64(1)
    }

    func flush(): Unit {
        flushAction(PngWriteFlushContext(bytesWrittenValue, emissionCountValue))
        flushCountValue += UInt64(1)
    }

    func result(): PngWriteSinkResult {
        PngWriteSinkResult(bytesWrittenValue, emissionCountValue, flushCountValue)
    }
}

private func emitWriteMetadataRegion(
    cursor: PngWriteEmissionCursor,
    chunks: Array<Array<Byte>>
): Unit {
    var index: Int64 = Int64(0)
    while (index < chunks.size) {
        let chunk = chunks[index]
        cursor.emit(
            WriteOutputChunk,
            copyByteRange(chunk, Int64(4), Int64(4)),
            chunk,
            false
        )
        index += Int64(1)
    }
}

private func emitPreparedPngWriteOutput(
    prepared: PngPreparedWriteOutput,
    writeAction: (PngWriteOutputContext, Array<Byte>) -> Unit,
    flushAction: (PngWriteFlushContext) -> Unit
): PngWriteSinkResult {
    let cursor = PngWriteEmissionCursor(writeAction, flushAction)
    cursor.emit(
        WriteOutputSignature, Array<Byte>(), PNG_SIGNATURE, false
    )
    cursor.emit(
        WriteOutputChunk, PNG_CHUNK_IHDR, makeWriteIhdr(prepared.ihdr), false
    )
    emitWriteMetadataRegion(cursor, prepared.metadataPlan.beforePalette())
    if (prepared.palette.size > Int64(0)) {
        cursor.emit(
            WriteOutputChunk, PNG_CHUNK_PLTE,
            makeWriteChunk(PNG_CHUNK_PLTE, prepared.palette), false
        )
    }
    emitWriteMetadataRegion(cursor, prepared.metadataPlan.afterPalette())

    var offset: Int64 = Int64(0)
    while (offset < prepared.compressed.size) {
        let remaining = prepared.compressed.size - offset
        let take = if (remaining < Int64(prepared.idatChunkBytes)) {
            remaining
        } else {
            Int64(prepared.idatChunkBytes)
        }
        cursor.emit(
            WriteOutputChunk, PNG_CHUNK_IDAT,
            makeWriteChunk(
                PNG_CHUNK_IDAT,
                copyByteRange(prepared.compressed, offset, take)
            ),
            false
        )
        offset += take
    }
    emitWriteMetadataRegion(cursor, prepared.metadataPlan.afterIdat())
    cursor.emit(
        WriteOutputChunk, PNG_CHUNK_IEND,
        makeWriteChunk(PNG_CHUNK_IEND, Array<Byte>()), true
    )

    let beforeFlush = cursor.result()
    if (beforeFlush.bytesWritten != prepared.expectedOutput) {
        throw PngFormatException(
            InvalidArgument, -1,
            "emitted PNG size does not match planned chunk structure"
        )
    }
    cursor.flush()
    cursor.result()
}

func collectPreparedPngWriteOutput(
    prepared: PngPreparedWriteOutput
): Array<Byte> {
    let out = ArrayList<Byte>()
    emitPreparedPngWriteOutput(
        prepared,
        { _, bytes => appendWriteBytes(out, bytes) },
        { _ => }
    )
    out.toArray()
}

func writePreparedPngOutputToSink(
    prepared: PngPreparedWriteOutput,
    sink: PngWriteSink
): PngWriteSinkResult {
    emitPreparedPngWriteOutput(
        prepared,
        { context, bytes => sink.emit(context, bytes) },
        { context => sink.flush(context) }
    )
}
