package libpng4cj

import std.collection.ArrayList

public let PNG_DEFAULT_MAX_PROGRESSIVE_INPUT_BYTES: UInt64 = UInt64(512_000_000)

public enum PngProgressiveReaderState <: Equatable<PngProgressiveReaderState> & ToString {
    | ProgressiveOpen
    | ProgressiveFinalizing
    | ProgressiveCompleted
    | ProgressiveFailed
    | ProgressiveClosed

    public operator func ==(right: PngProgressiveReaderState): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngProgressiveReaderState): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ProgressiveOpen => 0
            case ProgressiveFinalizing => 1
            case ProgressiveCompleted => 2
            case ProgressiveFailed => 3
            case ProgressiveClosed => 4
        }
    }

    public func toString(): String {
        match (this) {
            case ProgressiveOpen => "OPEN"
            case ProgressiveFinalizing => "FINALIZING"
            case ProgressiveCompleted => "COMPLETED"
            case ProgressiveFailed => "FAILED"
            case ProgressiveClosed => "CLOSED"
        }
    }
}

public class PngProgressiveRowContext {
    public let rowNumber: UInt32
    public let passNumber: Int64
    public let interlaceMethod: PngInterlaceMethod
    public let canonicalCombined: Bool

    public init(
        rowNumber: UInt32,
        passNumber: Int64,
        interlaceMethod: PngInterlaceMethod,
        canonicalCombined: Bool
    ) {
        this.rowNumber = rowNumber
        this.passNumber = passNumber
        this.interlaceMethod = interlaceMethod
        this.canonicalCombined = canonicalCombined
    }
}

private func pngProgressiveNoInfo(
    ihdr: PngIhdr,
    metadata: PngReadMetadata
): Unit {}

private func pngProgressiveNoRow(
    context: PngProgressiveRowContext,
    row: Array<Byte>
): Unit {}

private func pngProgressiveNoEnd(
    ihdr: PngIhdr,
    metadata: PngReadMetadata
): Unit {}

public class PngProgressiveReader {
    private let limits: PngReadLimits
    private let maxInputBytes: UInt64
    private var unknownPolicy: PngUnknownChunkPolicy = Discard
    private var criticalCrcAction: PngCrcAction = CrcNoChange
    private var ancillaryCrcAction: PngCrcAction = CrcNoChange
    private var stateValue: PngProgressiveReaderState = ProgressiveOpen
    private var receivedValue: UInt64 = UInt64(0)
    private var input = ArrayList<Byte>()
    private var infoCallbackEnabled: Bool = false
    private var rowCallbackEnabled: Bool = false
    private var endCallbackEnabled: Bool = false
    private var infoCallbackValue: (PngIhdr, PngReadMetadata) -> Unit = pngProgressiveNoInfo
    private var rowCallbackValue: (PngProgressiveRowContext, Array<Byte>) -> Unit =
        pngProgressiveNoRow
    private var endCallbackValue: (PngIhdr, PngReadMetadata) -> Unit = pngProgressiveNoEnd

    public init(limits: PngReadLimits, maxInputBytes: UInt64) {
        if (maxInputBytes == UInt64(0) || maxInputBytes > UInt64(Int64.Max)) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "maximum progressive input size must be in 1..Int64.Max"
            )
        }
        this.limits = limits
        this.maxInputBytes = maxInputBytes
    }

    public init(limits: PngReadLimits) {
        this.limits = limits
        maxInputBytes = PNG_DEFAULT_MAX_PROGRESSIVE_INPUT_BYTES
    }

    public init() {
        limits = PngReadLimits()
        maxInputBytes = PNG_DEFAULT_MAX_PROGRESSIVE_INPUT_BYTES
    }

    public func state(): PngProgressiveReaderState {
        stateValue
    }

    public func receivedBytes(): UInt64 {
        receivedValue
    }

    private func requireOpen(action: String): Unit {
        if (stateValue == ProgressiveClosed) {
            throw PngFormatException(SessionClosed, -1, "progressive reader is closed")
        }
        if (stateValue != ProgressiveOpen) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "cannot ${action} progressive reader in ${stateValue.toString()} state"
            )
        }
    }

    public func setUnknownChunkPolicy(policy: PngUnknownChunkPolicy): Unit {
        requireOpen("configure")
        unknownPolicy = policy
    }

    public func setCrcAction(
        criticalAction: PngCrcAction,
        ancillaryAction: PngCrcAction
    ): Unit {
        requireOpen("configure")
        criticalCrcAction = criticalAction
        ancillaryCrcAction = ancillaryAction
    }

    public func setInfoCallback(callback: (PngIhdr, PngReadMetadata) -> Unit): Unit {
        requireOpen("register callback on")
        infoCallbackEnabled = true
        infoCallbackValue = callback
    }

    public func setRowCallback(
        callback: (PngProgressiveRowContext, Array<Byte>) -> Unit
    ): Unit {
        requireOpen("register callback on")
        rowCallbackEnabled = true
        rowCallbackValue = callback
    }

    public func setEndCallback(callback: (PngIhdr, PngReadMetadata) -> Unit): Unit {
        requireOpen("register callback on")
        endCallbackEnabled = true
        endCallbackValue = callback
    }

    public func feed(bytes: Array<Byte>): Unit {
        requireOpen("feed")
        let next = receivedValue + UInt64(bytes.size)
        if (next < receivedValue || next > maxInputBytes) {
            stateValue = ProgressiveFailed
            throw PngFormatException(
                DecodeLimitExceeded,
                -1,
                "progressive input exceeds configured byte limit"
            )
        }
        var index: Int64 = 0
        while (index < bytes.size) {
            input.add(bytes[index])
            index += 1
        }
        receivedValue = next
    }

    public func finish(): PngDecodedRows {
        requireOpen("finish")
        stateValue = ProgressiveFinalizing
        try {
            let decoded = decodePng(
                input.toArray(),
                limits,
                unknownPolicy,
                criticalCrcAction,
                ancillaryCrcAction
            )
            input = ArrayList<Byte>()
            if (infoCallbackEnabled) {
                infoCallbackValue(decoded.ihdr, decoded.metadata)
            }
            let combined = decoded.ihdr.interlaceMethod == Adam7
            let passNumber = if (combined) { Int64(-1) } else { Int64(0) }
            var rowIndex: Int64 = 0
            while (rowIndex < decoded.rowCount()) {
                if (rowCallbackEnabled) {
                    rowCallbackValue(
                        PngProgressiveRowContext(
                            UInt32(rowIndex),
                            passNumber,
                            decoded.ihdr.interlaceMethod,
                            combined
                        ),
                        decoded.row(rowIndex)
                    )
                }
                rowIndex += 1
            }
            if (endCallbackEnabled) {
                endCallbackValue(decoded.ihdr, decoded.metadata)
            }
            stateValue = ProgressiveCompleted
            return decoded
        } catch (error: Exception) {
            input = ArrayList<Byte>()
            stateValue = ProgressiveFailed
            throw error
        }
    }

    public func close(): Unit {
        if (stateValue == ProgressiveFinalizing) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "cannot close progressive reader while callbacks are finalizing"
            )
        }
        input = ArrayList<Byte>()
        receivedValue = UInt64(0)
        stateValue = ProgressiveClosed
    }
}
