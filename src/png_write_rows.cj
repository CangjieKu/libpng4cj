package libpng4cj

import std.collection.ArrayList

public class PngRowWriteSession {
    private let writer: PngWriteSession
    private let expectedRowsValue: UInt32
    private let expectedRowBytesValue: UInt64
    private let rowsValue = ArrayList<Array<Byte>>()
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
        transforms: PngWriteTransformState,
        strategy: PngWriteFilterStrategy,
        compressionLevel: Int32,
        limits: PngWriteLimits
    ) {
        writer = PngWriteSession(
            width, height, bitDepth, colorType, interlaceMethod, palette,
            metadata, transforms, strategy, compressionLevel, limits
        )
        expectedRowsValue = height
        expectedRowBytesValue = writer.initializedTransforms().sourceRowBytes(width)
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
        rowsValue.add(row.clone())
        acceptedRowsValue += UInt32(1)
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
        stateValue = WriteFinalizing
        try {
            let output = writer.write(rowsValue.toArray())
            stateValue = WriteCompleted
            output
        } catch (error: Exception) {
            stateValue = WriteFailed
            throw error
        }
    }

    public func finishTo(sink: PngWriteSink): PngWriteSinkResult {
        requireOpen("finish")
        requireAllRows()
        stateValue = WriteFinalizing
        try {
            let result = writer.writeTo(rowsValue.toArray(), sink)
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
        writer.close()
        stateValue = WriteClosed
    }
}
