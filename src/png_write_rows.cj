package libpng4cj

import std.collection.ArrayList

private func pngNoopMissingStreamingOutput(): Unit {}

public class PngRowWriteSession {
    private let writer: PngWriteSession
    private let ihdr: PngIhdr
    private let initialization: PngWriteTransformInitialization
    private let writeControls: PngWriteControlInitialization
    private let limits: PngWriteLimits
    private let paletteEntryCount: Int64
    private let expectedRowsValue: UInt32
    private let expectedRowBytesValue: UInt64
    private let rowsValue = ArrayList<Array<Byte>>()
    private var previousRowValue: Array<Byte>
    private var streamingOutputValue: ?PngIncrementalWriteOutput = None
    private var adam7SpoolValue: ?PngAdam7WriteSpool = None
    private var acceptedRowsValue: UInt32 = UInt32(0)
    private var stateValue: PngWriteState = WriteOpen

    public init(
        width: UInt32,
        height: UInt32,
        bitDepth: UInt8,
        colorType: PngColorType,
        interlaceMethod: PngInterlaceMethod,
        palette: Array<Byte>,
        metadata: PngWriteMetadata,
        controls: PngWriteControlState,
        limits: PngWriteLimits
    ) {
        this(
            width, height, bitDepth, colorType, interlaceMethod, palette,
            metadata, PngWriteTransformState(bitDepth, colorType), controls,
            limits
        )
    }

    public init(
        width: UInt32,
        height: UInt32,
        bitDepth: UInt8,
        colorType: PngColorType,
        palette: Array<Byte>,
        metadata: PngWriteMetadata,
        controls: PngWriteControlState,
        limits: PngWriteLimits
    ) {
        this(
            width, height, bitDepth, colorType, None, palette, metadata,
            controls, limits
        )
    }

    public init(
        width: UInt32,
        height: UInt32,
        bitDepth: UInt8,
        colorType: PngColorType,
        interlaceMethod: PngInterlaceMethod,
        palette: Array<Byte>,
        metadata: PngWriteMetadata,
        transforms: PngWriteTransformState,
        controls: PngWriteControlState,
        limits: PngWriteLimits
    ) {
        writer = PngWriteSession(
            width, height, bitDepth, colorType, interlaceMethod, palette,
            metadata, transforms, controls, limits
        )
        ihdr = writer.incrementalWriteHeader()
        initialization = writer.initializedTransforms()
        writeControls = writer.incrementalWriteControls()
        this.limits = limits
        paletteEntryCount = palette.size / Int64(3)
        expectedRowsValue = height
        expectedRowBytesValue = initialization.sourceRowBytes(width)
        previousRowValue = Array<Byte>(Int64(ihdr.rowBytes), repeat: UInt8(0))
    }

    public init(
        width: UInt32,
        height: UInt32,
        bitDepth: UInt8,
        colorType: PngColorType,
        interlaceMethod: PngInterlaceMethod,
        palette: Array<Byte>,
        metadata: PngWriteMetadata,
        transforms: PngWriteTransformState,
        strategy: PngWriteFilterStrategy,
        compressionLevel: Int32,
        limits: PngWriteLimits
    ) {
        this(
            width, height, bitDepth, colorType, interlaceMethod, palette,
            metadata, transforms,
            PngWriteControlState(strategy, compressionLevel), limits
        )
    }

    public init(
        width: UInt32,
        height: UInt32,
        bitDepth: UInt8,
        colorType: PngColorType,
        interlaceMethod: PngInterlaceMethod,
        palette: Array<Byte>,
        metadata: PngWriteMetadata,
        strategy: PngWriteFilterStrategy,
        compressionLevel: Int32,
        limits: PngWriteLimits
    ) {
        this(
            width, height, bitDepth, colorType, interlaceMethod, palette,
            metadata, PngWriteTransformState(bitDepth, colorType), strategy,
            compressionLevel, limits
        )
    }

    public init(
        width: UInt32,
        height: UInt32,
        bitDepth: UInt8,
        colorType: PngColorType,
        palette: Array<Byte>,
        metadata: PngWriteMetadata,
        transforms: PngWriteTransformState,
        strategy: PngWriteFilterStrategy,
        compressionLevel: Int32,
        limits: PngWriteLimits
    ) {
        this(
            width, height, bitDepth, colorType, None, palette, metadata,
            transforms, strategy, compressionLevel, limits
        )
    }

    public init(
        width: UInt32,
        height: UInt32,
        bitDepth: UInt8,
        colorType: PngColorType,
        palette: Array<Byte>,
        metadata: PngWriteMetadata,
        strategy: PngWriteFilterStrategy,
        compressionLevel: Int32,
        limits: PngWriteLimits
    ) {
        this(
            width, height, bitDepth, colorType, None, palette, metadata,
            strategy, compressionLevel, limits
        )
    }

    public init(
        width: UInt32,
        height: UInt32,
        bitDepth: UInt8,
        colorType: PngColorType,
        interlaceMethod: PngInterlaceMethod,
        palette: Array<Byte>,
        strategy: PngWriteFilterStrategy,
        compressionLevel: Int32,
        limits: PngWriteLimits
    ) {
        this(
            width, height, bitDepth, colorType, interlaceMethod, palette,
            PngWriteMetadata(), strategy, compressionLevel, limits
        )
    }

    public init(
        width: UInt32,
        height: UInt32,
        bitDepth: UInt8,
        colorType: PngColorType,
        palette: Array<Byte>,
        strategy: PngWriteFilterStrategy,
        compressionLevel: Int32,
        limits: PngWriteLimits
    ) {
        this(
            width, height, bitDepth, colorType, None, palette, strategy,
            compressionLevel, limits
        )
    }

    public func state(): PngWriteState {
        stateValue
    }

    public func expectedRowCount(): UInt32 {
        expectedRowsValue
    }

    public func acceptedRowCount(): UInt32 {
        acceptedRowsValue
    }

    public func remainingRowCount(): UInt32 {
        expectedRowsValue - acceptedRowsValue
    }

    public func expectedRowBytes(): UInt64 {
        expectedRowBytesValue
    }

    private func requireOpen(operation: String): Unit {
        if (stateValue == WriteClosed) {
            throw PngFormatException(SessionClosed, -1, "PNG row writer is closed")
        }
        if (stateValue != WriteOpen) {
            throw PngFormatException(
                InvalidArgument, -1,
                "PNG row writer cannot ${operation} in ${stateValue.toString()} state"
            )
        }
    }

    private func validateStreamingGeometry(): Unit {
        let transformedRowBytes = initialization.outputRowBytes(ihdr.width)
        if (UInt64(ihdr.height) > limits.maxTransformedBytes / transformedRowBytes) {
            throw PngFormatException(
                DecodeLimitExceeded, -1,
                "transformed PNG rows exceed configured transformed-byte limit"
            )
        }
        if (ihdr.interlaceMethod == Adam7) {
            expectedAdam7FilteredWriteSize(ihdr, limits.maxFilteredBytes)
        } else {
            let filteredRowBytes = ihdr.rowBytes + UInt64(1)
            if (UInt64(ihdr.height) > limits.maxFilteredBytes / filteredRowBytes) {
                throw PngFormatException(
                    DecodeLimitExceeded, -1,
                    "filtered PNG rows exceed configured input limit"
                )
            }
        }
    }

    private func output(): PngIncrementalWriteOutput {
        match (streamingOutputValue) {
            case Some(value) => value
            case None => throw PngFormatException(
                InvalidArgument, -1, "incremental PNG sink is not started"
            )
        }
    }

    private func hasStreamingOutput(): Bool {
        match (streamingOutputValue) {
            case Some(_) => true
            case None => false
        }
    }

    private func closeStreamingOutputAfterFailure(): Unit {
        match (streamingOutputValue) {
            case Some(value) =>
                try {
                    value.close()
                } catch (_: Exception) {}
            case None => pngNoopMissingStreamingOutput()
        }
    }

    private func adam7Spool(): PngAdam7WriteSpool {
        match (adam7SpoolValue) {
            case Some(value) => value
            case None => throw PngFormatException(
                InvalidArgument, -1, "Adam7 write spool is not started"
            )
        }
    }

    private func beginStreaming(sink: PngWriteSink): Unit {
        validateStreamingGeometry()
        if (ihdr.interlaceMethod == Adam7) {
            adam7SpoolValue = Some(PngAdam7WriteSpool(
                ihdr, writeControls, limits.maxFilteredBytes
            ))
        }
        let next = PngIncrementalWriteOutput(
            ihdr, writer.incrementalWritePalette(),
            writer.incrementalWriteMetadataPlan(), writeControls, limits,
            sink
        )
        streamingOutputValue = Some(next)
    }

    public func startTo(sink: PngWriteSink): Unit {
        requireOpen("start streaming output")
        if (acceptedRowsValue != UInt32(0)) {
            stateValue = WriteFailed
            throw PngFormatException(
                InvalidArgument, -1,
                "PNG row writer must start its sink before accepting rows"
            )
        }
        stateValue = WriteFinalizing
        try {
            beginStreaming(sink)
            stateValue = WriteOpen
        } catch (error: Exception) {
            stateValue = WriteFailed
            throw error
        }
    }

    private func pushStreamingRow(row: Array<Byte>, rowIndex: UInt32): Unit {
        let transformed = applyInitializedPngWriteTransforms(
            initialization, ihdr.width, row,
            PngWriteUserTransformContext(rowIndex, ihdr.interlaceMethod)
        ).row()
        validateWritePaletteRow(
            ihdr, transformed, paletteEntryCount, Int64(rowIndex)
        )
        let selected = selectWriteFilter(
            writeControls, transformed, previousRowValue,
            pngFilterBytesPerPixel(ihdr)
        )
        let frame = ArrayList<Byte>()
        frame.add(selected.filterType)
        appendWriteBytes(frame, selected.bytes)
        output().pushFilteredFrame(frame.toArray())
        previousRowValue = transformed.clone()
    }

    private func spoolStreamingAdam7Row(
        row: Array<Byte>,
        rowIndex: UInt32
    ): Unit {
        let transformed = applyInitializedPngWriteTransforms(
            initialization, ihdr.width, row,
            PngWriteUserTransformContext(rowIndex, ihdr.interlaceMethod)
        ).row()
        validateWritePaletteRow(
            ihdr, transformed, paletteEntryCount, Int64(rowIndex)
        )
        adam7Spool().addTransformedRow(transformed, rowIndex)
    }

    public func writeRow(row: Array<Byte>): Unit {
        requireOpen("accept rows")
        if (acceptedRowsValue >= expectedRowsValue) {
            stateValue = WriteFailed
            throw PngFormatException(
                InvalidArgument, Int64(acceptedRowsValue),
                "PNG row writer received more rows than the configured height"
            )
        }
        if (UInt64(row.size) != expectedRowBytesValue) {
            stateValue = WriteFailed
            throw PngFormatException(
                InvalidArgument, Int64(acceptedRowsValue),
                "PNG row writer input row length does not match the configured source shape"
            )
        }
        let owned = row.clone()
        match (streamingOutputValue) {
            case Some(_) =>
                stateValue = WriteFinalizing
                try {
                    if (ihdr.interlaceMethod == Adam7) {
                        spoolStreamingAdam7Row(owned, acceptedRowsValue)
                    } else {
                        pushStreamingRow(owned, acceptedRowsValue)
                    }
                    acceptedRowsValue += UInt32(1)
                    stateValue = WriteOpen
                } catch (error: Exception) {
                    closeStreamingOutputAfterFailure()
                    stateValue = WriteFailed
                    throw error
                }
            case None =>
                rowsValue.add(owned)
                acceptedRowsValue += UInt32(1)
        }
    }

    private func requireAllRows(): Unit {
        if (acceptedRowsValue != expectedRowsValue) {
            stateValue = WriteFailed
            throw PngFormatException(
                InvalidArgument, Int64(acceptedRowsValue),
                "PNG row writer cannot finish before every configured row is accepted"
            )
        }
    }

    public func finish(): Array<Byte> {
        requireOpen("finish")
        requireAllRows()
        if (ihdr.interlaceMethod == Adam7) {
            stateValue = WriteFinalizing
            try {
                let output = writer.write(rowsValue.toArray())
                stateValue = WriteCompleted
                return output
            } catch (error: Exception) {
                stateValue = WriteFailed
                throw error
            }
        }
        if (hasStreamingOutput()) {
            stateValue = WriteFailed
            throw PngFormatException(
                InvalidArgument, -1,
                "PNG row writer with a started sink must finish through finishTo()"
            )
        }
        let bytes = ArrayList<Byte>()
        let sink = PngWriteSink()
        sink.setWriteCallback({ _, emitted => appendWriteBytes(bytes, emitted) })
        stateValue = WriteFinalizing
        try {
            beginStreaming(sink)
            var rowIndex: Int64 = Int64(0)
            while (rowIndex < rowsValue.size) {
                pushStreamingRow(rowsValue[rowIndex], UInt32(rowIndex))
                rowIndex += Int64(1)
            }
            output().finish()
            stateValue = WriteCompleted
            bytes.toArray()
        } catch (error: Exception) {
            stateValue = WriteFailed
            throw error
        }
    }

    public func finishTo(): PngWriteSinkResult {
        requireOpen("finish")
        requireAllRows()
        match (streamingOutputValue) {
            case Some(_) =>
                stateValue = WriteFinalizing
                try {
                    if (ihdr.interlaceMethod == Adam7) {
                        adam7Spool().pushFilteredFrames(output())
                    }
                    let result = output().finish()
                    stateValue = WriteCompleted
                    result
                } catch (error: Exception) {
                    closeStreamingOutputAfterFailure()
                    stateValue = WriteFailed
                    throw error
                }
            case None =>
                stateValue = WriteFailed
                throw PngFormatException(
                    InvalidArgument, -1,
                    "PNG row writer has no started sink to finish"
                )
        }
    }

    public func finishTo(sink: PngWriteSink): PngWriteSinkResult {
        requireOpen("finish")
        requireAllRows()
        if (hasStreamingOutput()) {
            stateValue = WriteFailed
            throw PngFormatException(
                InvalidArgument, -1,
                "PNG row writer sink is already started; use finishTo()"
            )
        }
        if (ihdr.interlaceMethod == Adam7) {
            stateValue = WriteFinalizing
            try {
                let result = writer.writeTo(rowsValue.toArray(), sink)
                stateValue = WriteCompleted
                return result
            } catch (error: Exception) {
                stateValue = WriteFailed
                throw error
            }
        }
        stateValue = WriteFinalizing
        try {
            beginStreaming(sink)
            var rowIndex: Int64 = Int64(0)
            while (rowIndex < rowsValue.size) {
                pushStreamingRow(rowsValue[rowIndex], UInt32(rowIndex))
                rowIndex += Int64(1)
            }
            let result = output().finish()
            stateValue = WriteCompleted
            result
        } catch (error: Exception) {
            stateValue = WriteFailed
            throw error
        }
    }

    public func close(): Unit {
        if (stateValue == WriteFinalizing) {
            throw PngFormatException(
                InvalidArgument, -1,
                "cannot close PNG row writer while write callbacks are active"
            )
        }
        match (streamingOutputValue) {
            case Some(output) => output.close()
            case None => pngNoopMissingStreamingOutput()
        }
        writer.close()
        stateValue = WriteClosed
    }
}
