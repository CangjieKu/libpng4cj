package libpng4cj

import std.collection.ArrayList

class PngIncrementalIdatWriter {
    private let cursor: PngWriteEmissionCursor
    private let deflater: PngIncrementalDeflater
    private let idatChunkBytes: Int64
    private let pending = ArrayList<Byte>()
    private var finishedValue: Bool = false
    private var closedValue: Bool = false

    init(
        cursor: PngWriteEmissionCursor,
        controls: PngWriteControlInitialization,
        maxCompressedBytes: UInt64,
        idatChunkBytes: UInt32
    ) {
        this.cursor = cursor
        this.idatChunkBytes = Int64(idatChunkBytes)
        deflater = PngIncrementalDeflater(controls, maxCompressedBytes)
    }

    private func emitFullChunks(): Unit {
        if (pending.size < idatChunkBytes) {
            return
        }
        let bytes = pending.toArray()
        var offset: Int64 = Int64(0)
        while (bytes.size - offset >= idatChunkBytes) {
            emitPngWriteIdat(
                cursor, copyByteRange(bytes, offset, idatChunkBytes)
            )
            offset += idatChunkBytes
        }
        pending.clear()
        while (offset < bytes.size) {
            pending.add(bytes[offset])
            offset += Int64(1)
        }
    }

    private func acceptCompressed(bytes: Array<Byte>): Unit {
        appendWriteBytes(pending, bytes)
        emitFullChunks()
    }

    func push(filteredFrame: Array<Byte>): Unit {
        if (finishedValue || closedValue) {
            throw PngFormatException(
                InvalidArgument, -1, "incremental IDAT writer is not open"
            )
        }
        deflater.push(filteredFrame, { bytes => acceptCompressed(bytes) })
    }

    func finish(): Unit {
        if (finishedValue || closedValue) {
            throw PngFormatException(
                InvalidArgument, -1, "incremental IDAT writer is not open"
            )
        }
        try {
            deflater.finish({ bytes => acceptCompressed(bytes) })
            if (pending.size > Int64(0)) {
                emitPngWriteIdat(cursor, pending.toArray())
                pending.clear()
            }
            finishedValue = true
        } finally {
            deflater.close()
            closedValue = true
        }
    }

    func close(): Unit {
        if (closedValue) {
            return
        }
        deflater.close()
        closedValue = true
    }
}

class PngIncrementalWriteOutput {
    private let cursor: PngWriteEmissionCursor
    private let metadataPlan: PngWriteMetadataPlan
    private let idat: PngIncrementalIdatWriter
    private var finishedValue: Bool = false
    private var closedValue: Bool = false

    init(
        ihdr: PngIhdr,
        palette: Array<Byte>,
        metadataPlan: PngWriteMetadataPlan,
        controls: PngWriteControlInitialization,
        limits: PngWriteLimits,
        sink: PngWriteSink
    ) {
        this.metadataPlan = metadataPlan
        cursor = PngWriteEmissionCursor(
            { context, bytes => sink.emit(context, bytes) },
            { context => sink.flush(context) },
            limits.maxOutputBytes
        )
        idat = PngIncrementalIdatWriter(
            cursor, controls, limits.maxCompressedBytes,
            limits.idatChunkBytes
        )
        try {
            emitPngWritePrefix(cursor, ihdr, palette, metadataPlan)
        } catch (error: Exception) {
            idat.close()
            closedValue = true
            throw error
        }
    }

    func pushFilteredFrame(frame: Array<Byte>): Unit {
        if (finishedValue || closedValue) {
            throw PngFormatException(
                InvalidArgument, -1, "incremental PNG output is not open"
            )
        }
        idat.push(frame)
    }

    func finish(): PngWriteSinkResult {
        if (finishedValue || closedValue) {
            throw PngFormatException(
                InvalidArgument, -1, "incremental PNG output is not open"
            )
        }
        try {
            idat.finish()
            let result = finishPngWriteEmission(cursor, metadataPlan)
            finishedValue = true
            closedValue = true
            result
        } catch (error: Exception) {
            try {
                close()
            } catch (_: Exception) {}
            throw error
        }
    }

    func close(): Unit {
        if (closedValue) {
            return
        }
        idat.close()
        closedValue = true
    }
}
