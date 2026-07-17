package libpng4cj

import std.collection.ArrayList

public let PNG_DEFAULT_MAX_PROGRESSIVE_INPUT_BYTES: UInt64 = UInt64(512_000_000)

public enum PngProgressiveReaderState <: Equatable<PngProgressiveReaderState> & ToString {
    | ProgressiveOpen
    | ProgressivePaused
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
            case ProgressivePaused => 1
            case ProgressiveFinalizing => 2
            case ProgressiveCompleted => 3
            case ProgressiveFailed => 4
            case ProgressiveClosed => 5
        }
    }

    public func toString(): String {
        match (this) {
            case ProgressiveOpen => "OPEN"
            case ProgressivePaused => "PAUSED"
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
    public let passRowNumber: UInt32
    public let imageRowNumber: UInt32
    public let interlaceMethod: PngInterlaceMethod
    public let canonicalCombined: Bool
    public let passRowPresent: Bool

    public init(
        rowNumber: UInt32,
        passNumber: Int64,
        interlaceMethod: PngInterlaceMethod,
        canonicalCombined: Bool
    ) {
        this.rowNumber = rowNumber
        this.passNumber = passNumber
        passRowNumber = rowNumber
        imageRowNumber = rowNumber
        this.interlaceMethod = interlaceMethod
        this.canonicalCombined = canonicalCombined
        passRowPresent = true
    }

    init(
        rowNumber: UInt32,
        passNumber: Int64,
        passRowNumber: UInt32,
        imageRowNumber: UInt32,
        interlaceMethod: PngInterlaceMethod,
        canonicalCombined: Bool,
        passRowPresent: Bool
    ) {
        this.rowNumber = rowNumber
        this.passNumber = passNumber
        this.passRowNumber = passRowNumber
        this.imageRowNumber = imageRowNumber
        this.interlaceMethod = interlaceMethod
        this.canonicalCombined = canonicalCombined
        this.passRowPresent = passRowPresent
    }
}

private enum PngProgressiveParsePhase <: Equatable<PngProgressiveParsePhase> {
    | ProgressiveSignature
    | ProgressiveChunkHeader
    | ProgressiveChunkData
    | ProgressiveChunkCrc
    | ProgressiveStreamDone

    public operator func ==(right: PngProgressiveParsePhase): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ProgressiveSignature => 0
            case ProgressiveChunkHeader => 1
            case ProgressiveChunkData => 2
            case ProgressiveChunkCrc => 3
            case ProgressiveStreamDone => 4
        }
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

private func appendProgressiveBytes(
    output: ArrayList<Byte>,
    bytes: Array<Byte>,
    offset: Int64,
    length: Int64
): Unit {
    var index: Int64 = 0
    while (index < length) {
        output.add(bytes[offset + index])
        index += 1
    }
}

private func appendProgressiveListBytes(
    output: ArrayList<Byte>,
    bytes: ArrayList<Byte>,
    offset: Int64,
    length: Int64
): Unit {
    var index: Int64 = 0
    while (index < length) {
        output.add(bytes[offset + index])
        index += 1
    }
}

public class PngProgressiveReader {
    private let limits: PngReadLimits
    private let maxInputBytes: UInt64
    private var unknownPolicy: PngUnknownChunkPolicy = Discard
    private var criticalCrcAction: PngCrcAction = CrcErrorQuit
    private var ancillaryCrcAction: PngCrcAction = CrcWarnDiscard
    private var stateValue: PngProgressiveReaderState = ProgressiveOpen
    private var receivedValue: UInt64 = UInt64(0)
    private var processedValue: UInt64 = UInt64(0)
    private var lastUnconsumedValue: UInt64 = UInt64(0)
    private var retainedInput = Array<Byte>()
    private var phase: PngProgressiveParsePhase = ProgressiveSignature
    private var signatureBytes = ArrayList<Byte>()
    private var headerBytes = ArrayList<Byte>()
    private var currentChunkLength: UInt32 = UInt32(0)
    private var currentChunkType = Array<Byte>()
    private var currentChunkOffset: Int64 = Int64(0)
    private var currentChunkDataReceived: UInt32 = UInt32(0)
    private var currentChunkData = ArrayList<Byte>()
    private var currentChunkCrcBytes = ArrayList<Byte>()
    private var currentChunkCrcState: UInt32 = pngCrc32Start()
    private var chunkCount: Int64 = Int64(0)
    private var seenPalette: Bool = false
    private var seenTransparency: Bool = false
    private var seenIdat: Bool = false
    private var idatEnded: Bool = false
    private var seenIend: Bool = false
    private var compressedSize: UInt64 = UInt64(0)
    private var palette = Array<Byte>()
    private var transparency = ParsedPngTransparency()
    private let metadataBuilder = PngMetadataBuilder()
    private let ihdrValues = ArrayList<PngIhdr>()
    private let inflaterValues = ArrayList<PngIncrementalInflater>()
    private let resultValues = ArrayList<PngDecodedRows>()
    private var expectedInflatedBytes: UInt64 = UInt64(0)
    private var rowsValue = Array<Array<Byte>>()
    private var rowFrame = ArrayList<Byte>()
    private var inflatedPending = ArrayList<Byte>()
    private var inflatedPendingOffset: Int64 = Int64(0)
    private var previousRow = Array<Byte>()
    private var nextRowNumber: UInt32 = UInt32(0)
    private var adam7Pass: Int64 = Int64(0)
    private var adam7PassRow: UInt32 = UInt32(0)
    private var infoDelivered: Bool = false
    private var endDelivered: Bool = false
    private var parseDone: Bool = false
    private var processingValue: Bool = false
    private var callbackValue: Bool = false
    private var pauseRequested: Bool = false
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

    public func processedBytes(): UInt64 {
        processedValue
    }

    public func lastUnconsumedBytes(): UInt64 {
        lastUnconsumedValue
    }

    private func currentIhdr(): PngIhdr {
        if (ihdrValues.size != Int64(1)) {
            throw PngFormatException(MissingIhdr, Int64(processedValue), "PNG IHDR is not available")
        }
        ihdrValues[0]
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

    private func requireConfigurable(): Unit {
        requireOpen("configure")
        if (receivedValue != UInt64(0) || processedValue != UInt64(0)) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "progressive chunk policy must be configured before the first feed"
            )
        }
    }

    private func requireCallbackRegistration(): Unit {
        if (stateValue == ProgressiveClosed) {
            throw PngFormatException(SessionClosed, -1, "progressive reader is closed")
        }
        if ((stateValue != ProgressiveOpen && stateValue != ProgressivePaused) || processingValue) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "cannot register callback in ${stateValue.toString()} state"
            )
        }
    }

    public func setUnknownChunkPolicy(policy: PngUnknownChunkPolicy): Unit {
        requireConfigurable()
        unknownPolicy = policy
    }

    public func setCrcAction(
        criticalAction: PngCrcAction,
        ancillaryAction: PngCrcAction
    ): Unit {
        requireConfigurable()
        if (criticalAction != CrcNoChange) {
            criticalCrcAction = match (criticalAction) {
                case CrcWarnUse => CrcWarnUse
                case CrcQuietUse => CrcQuietUse
                case _ => CrcErrorQuit
            }
        }
        if (ancillaryAction != CrcNoChange) {
            ancillaryCrcAction = match (ancillaryAction) {
                case CrcWarnUse => CrcWarnUse
                case CrcQuietUse => CrcQuietUse
                case CrcErrorQuit => CrcErrorQuit
                case _ => CrcWarnDiscard
            }
        }
    }

    public func setInfoCallback(callback: (PngIhdr, PngReadMetadata) -> Unit): Unit {
        requireCallbackRegistration()
        infoCallbackEnabled = true
        infoCallbackValue = callback
    }

    public func setRowCallback(
        callback: (PngProgressiveRowContext, Array<Byte>) -> Unit
    ): Unit {
        requireCallbackRegistration()
        rowCallbackEnabled = true
        rowCallbackValue = callback
    }

    public func setEndCallback(callback: (PngIhdr, PngReadMetadata) -> Unit): Unit {
        requireCallbackRegistration()
        endCallbackEnabled = true
        endCallbackValue = callback
    }

    public func pause(): Unit {
        if (!callbackValue || stateValue != ProgressiveOpen) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "progressive pause is only valid from an active callback"
            )
        }
        pauseRequested = true
    }

    private func invokeInfo(metadata: PngReadMetadata): Unit {
        if (infoDelivered) {
            return
        }
        infoDelivered = true
        if (infoCallbackEnabled) {
            callbackValue = true
            try {
                infoCallbackValue(currentIhdr(), metadata)
            } finally {
                callbackValue = false
            }
        }
    }

    private func invokeRow(context: PngProgressiveRowContext, row: Array<Byte>): Unit {
        if (rowCallbackEnabled) {
            callbackValue = true
            try {
                rowCallbackValue(context, row.clone())
            } finally {
                callbackValue = false
            }
        }
    }

    private func invokeEnd(metadata: PngReadMetadata): Unit {
        if (endDelivered) {
            return
        }
        endDelivered = true
        if (endCallbackEnabled) {
            callbackValue = true
            try {
                endCallbackValue(currentIhdr(), metadata)
            } finally {
                callbackValue = false
            }
        }
    }

    private func closeInflaterNoThrow(): Unit {
        if (inflaterValues.size == Int64(1)) {
            try {
                inflaterValues[0].close()
            } catch (_: Exception) {}
        }
    }

    private func fail(error: Exception): Nothing {
        closeInflaterNoThrow()
        retainedInput = Array<Byte>()
        inflatedPending = ArrayList<Byte>()
        rowFrame = ArrayList<Byte>()
        stateValue = ProgressiveFailed
        throw error
    }

    private func initializeRows(ihdr: PngIhdr): Unit {
        rowsValue = Array<Array<Byte>>(Int64(ihdr.height), repeat: Array<Byte>())
        var index: Int64 = 0
        while (index < rowsValue.size) {
            rowsValue[index] = Array<Byte>(Int64(ihdr.rowBytes), repeat: UInt8(0))
            index += 1
        }
        if (ihdr.interlaceMethod == None) {
            previousRow = Array<Byte>(Int64(ihdr.rowBytes), repeat: UInt8(0))
        } else {
            advanceAdam7Pass()
        }
    }

    private func advanceAdam7Pass(): Unit {
        if (ihdrValues.size != Int64(1)) {
            return
        }
        let ihdr = currentIhdr()
        while (adam7Pass < Int64(7)) {
            let geometry = pngAdam7PassGeometry(ihdr, adam7Pass)
            if (geometry.width > UInt32(0) && geometry.height > UInt32(0)) {
                if (adam7PassRow == UInt32(0)) {
                    previousRow = Array<Byte>(Int64(geometry.rowBytes), repeat: UInt8(0))
                }
                return
            }
            adam7Pass += 1
            adam7PassRow = UInt32(0)
        }
        previousRow = Array<Byte>()
    }

    private func expectedRowFrameBytes(): Int64 {
        let ihdr = currentIhdr()
        if (ihdr.interlaceMethod == None) {
            if (nextRowNumber >= ihdr.height) {
                throw PngFormatException(
                    InflatedSizeMismatch,
                    -1,
                    "zlib stream contains more rows than PNG geometry"
                )
            }
            return Int64(ihdr.rowBytes) + Int64(1)
        }
        advanceAdam7Pass()
        if (adam7Pass >= Int64(7)) {
            throw PngFormatException(
                InflatedSizeMismatch,
                -1,
                "zlib stream contains more Adam7 rows than PNG geometry"
            )
        }
        Int64(pngAdam7PassGeometry(ihdr, adam7Pass).rowBytes) + Int64(1)
    }

    private func processCompleteRowFrame(): Unit {
        let ihdr = currentIhdr()
        let frame = rowFrame.toArray()
        rowFrame = ArrayList<Byte>()
        if (ihdr.interlaceMethod == None) {
            let filtered = copyByteRange(frame, Int64(1), frame.size - Int64(1))
            let decoded = unfilterPngRow(
                frame[0],
                filtered,
                previousRow,
                pngFilterBytesPerPixel(ihdr)
            )
            let rowNumber = nextRowNumber
            rowsValue[Int64(rowNumber)] = decoded.clone()
            previousRow = decoded
            nextRowNumber += UInt32(1)
            invokeRow(
                PngProgressiveRowContext(
                    rowNumber,
                    Int64(0),
                    rowNumber,
                    rowNumber,
                    None,
                    false,
                    true
                ),
                decoded
            )
            return
        }

        let geometry = pngAdam7PassGeometry(ihdr, adam7Pass)
        let filtered = copyByteRange(frame, Int64(1), frame.size - Int64(1))
        let decoded = unfilterPngRow(
            frame[0],
            filtered,
            previousRow,
            pngFilterBytesPerPixel(ihdr)
        )
        let imageRow = geometry.startY + adam7PassRow * geometry.stepY
        let combined = pngProgressiveCombineRow(
            rowsValue[Int64(imageRow)],
            decoded,
            ihdr,
            adam7Pass
        )
        rowsValue[Int64(imageRow)] = combined.clone()
        previousRow = decoded
        invokeRow(
            PngProgressiveRowContext(
                imageRow,
                adam7Pass,
                adam7PassRow,
                imageRow,
                Adam7,
                true,
                true
            ),
            combined
        )
        adam7PassRow += UInt32(1)
        if (adam7PassRow >= geometry.height) {
            adam7Pass += 1
            adam7PassRow = UInt32(0)
            advanceAdam7Pass()
        }
    }

    private func drainInflatedPending(): Unit {
        while (inflatedPendingOffset < inflatedPending.size && !pauseRequested) {
            let needed = expectedRowFrameBytes() - rowFrame.size
            let available = inflatedPending.size - inflatedPendingOffset
            let take = if (needed < available) { needed } else { available }
            appendProgressiveListBytes(
                rowFrame,
                inflatedPending,
                inflatedPendingOffset,
                take
            )
            inflatedPendingOffset += take
            if (rowFrame.size == expectedRowFrameBytes()) {
                processCompleteRowFrame()
            }
        }
        if (inflatedPendingOffset == inflatedPending.size) {
            inflatedPending = ArrayList<Byte>()
            inflatedPendingOffset = Int64(0)
        }
    }

    private func acceptInflated(bytes: Array<Byte>): Bool {
        appendProgressiveBytes(inflatedPending, bytes, Int64(0), bytes.size)
        drainInflatedPending()
        !pauseRequested
    }

    private func prepareIdat(): Unit {
        if (idatEnded) {
            throw PngFormatException(
                NonConsecutiveIdat,
                currentChunkOffset,
                "IDAT chunks must be consecutive"
            )
        }
        let ihdr = currentIhdr()
        if (ihdr.colorType == Indexed && !seenPalette) {
            throw PngFormatException(
                InvalidPalette,
                currentChunkOffset,
                "indexed PNG requires PLTE before IDAT"
            )
        }
        if (!seenIdat) {
            let expected = if (ihdr.interlaceMethod == Adam7) {
                pngAdam7ExpectedInflatedSize(ihdr, limits)
            } else {
                expectedNonInterlacedInflatedSize(ihdr, limits)
            }
            expectedInflatedBytes = UInt64(expected)
            inflaterValues.add(PngIncrementalInflater(limits.maxInflatedBytes))
            seenIdat = true
            invokeInfo(metadataBuilder.build(palette, transparency))
        }
    }

    private func beginChunkHeader(): Unit {
        let header = headerBytes.toArray()
        let length = readUInt32Be(header, Int64(0))
        if (length > PNG_UINT_31_MAX) {
            throw PngFormatException(
                InvalidChunkLength,
                currentChunkOffset,
                "PNG chunk length exceeds 31 bits"
            )
        }
        if (length > limits.maxChunkBytes) {
            throw PngFormatException(
                ChunkTooLarge,
                currentChunkOffset,
                "PNG chunk exceeds configured memory limit"
            )
        }
        let chunkType = copyByteRange(header, Int64(4), Int64(4))
        if (!isValidChunkType(chunkType)) {
            throw PngFormatException(
                InvalidChunkType,
                currentChunkOffset + Int64(4),
                "PNG chunk type is invalid"
            )
        }
        if (chunkCount == Int64(0) && !sameBytes(chunkType, PNG_CHUNK_IHDR)) {
            throw PngFormatException(
                IhdrOutOfOrder,
                currentChunkOffset + Int64(4),
                "IHDR must be the first PNG chunk"
            )
        }
        if (sameBytes(chunkType, PNG_CHUNK_IHDR) && chunkCount != Int64(0)) {
            let kind = if (ihdrValues.size == Int64(1)) { DuplicateIhdr } else { IhdrOutOfOrder }
            throw PngFormatException(kind, currentChunkOffset + Int64(4), "IHDR is not unique and first")
        }

        currentChunkLength = length
        currentChunkType = chunkType
        currentChunkDataReceived = UInt32(0)
        currentChunkData = ArrayList<Byte>()
        currentChunkCrcBytes = ArrayList<Byte>()
        currentChunkCrcState = pngCrc32Update(pngCrc32Start(), currentChunkType)
        headerBytes = ArrayList<Byte>()
        phase = if (length == UInt32(0)) { ProgressiveChunkCrc } else { ProgressiveChunkData }
        if (sameBytes(currentChunkType, PNG_CHUNK_IDAT)) {
            prepareIdat()
        }
    }

    private func shouldUseCurrentChunk(expectedCrc: UInt32): Bool {
        let actualCrc = pngCrc32Finish(currentChunkCrcState)
        if (expectedCrc == actualCrc) {
            return true
        }
        let action = if (isCriticalChunk(currentChunkType)) {
            criticalCrcAction
        } else {
            ancillaryCrcAction
        }
        if (action == CrcErrorQuit) {
            throw PngFormatException(
                CrcMismatch,
                currentChunkOffset + Int64(8) + Int64(currentChunkLength),
                "PNG chunk CRC does not match"
            )
        }
        action != CrcWarnDiscard
    }

    private func finalizeImage(chunk: PngChunk): Unit {
        if (chunk.length != UInt32(0)) {
            throw PngFormatException(InvalidIend, chunk.offset, "IEND chunk length must be zero")
        }
        if (!seenIdat || inflaterValues.size != Int64(1)) {
            throw PngFormatException(MissingIdat, chunk.offset, "PNG reached IEND before IDAT")
        }
        drainInflatedPending()
        inflaterValues[0].finish()
        if (inflaterValues[0].totalOutputBytes() != expectedInflatedBytes || rowFrame.size != Int64(0)) {
            throw PngFormatException(
                InflatedSizeMismatch,
                -1,
                "zlib output size does not match PNG row geometry"
            )
        }
        let ihdr = currentIhdr()
        if (ihdr.interlaceMethod == None && nextRowNumber != ihdr.height) {
            throw PngFormatException(InflatedSizeMismatch, -1, "PNG row count is incomplete")
        }
        if (ihdr.interlaceMethod == Adam7) {
            advanceAdam7Pass()
            if (adam7Pass < Int64(7)) {
                throw PngFormatException(InflatedSizeMismatch, -1, "Adam7 pass rows are incomplete")
            }
        }
        inflaterValues[0].close()
        let metadata = metadataBuilder.build(palette, transparency)
        resultValues.add(PngDecodedRows(ihdr, metadata, rowsValue))
        seenIend = true
        parseDone = true
        phase = ProgressiveStreamDone
        invokeEnd(metadata)
    }

    private func processCurrentChunk(expectedCrc: UInt32): Unit {
        let useChunk = shouldUseCurrentChunk(expectedCrc)
        let chunk = PngChunk(
            currentChunkLength,
            currentChunkType,
            currentChunkData.toArray(),
            expectedCrc,
            expectedCrc == pngCrc32Finish(currentChunkCrcState),
            currentChunkOffset
        )
        chunkCount += Int64(1)
        if (!useChunk) {
            return
        }
        if (chunk.isType(PNG_CHUNK_IHDR)) {
            if (ihdrValues.size != Int64(0)) {
                throw PngFormatException(DuplicateIhdr, chunk.offset, "PNG contains more than one IHDR chunk")
            }
            let ihdr = parsePngIhdr(chunk, limits)
            ihdrValues.add(ihdr)
            initializeRows(ihdr)
            return
        }
        if (chunk.isType(PNG_CHUNK_IDAT)) {
            return
        }
        if (chunk.isType(PNG_CHUNK_IEND)) {
            finalizeImage(chunk)
            return
        }

        let ihdr = currentIhdr()
        if (chunk.isType(PNG_CHUNK_PLTE)) {
            if (seenPalette) {
                throw PngFormatException(InvalidPalette, chunk.offset, "PNG contains more than one PLTE chunk")
            }
            if (seenTransparency) {
                throw PngFormatException(InvalidTransparency, chunk.offset, "PLTE must precede tRNS")
            }
            if (metadataBuilder.hasBackground()) {
                throw PngFormatException(MetadataOutOfOrder, chunk.offset, "PLTE must precede bKGD")
            }
            if (seenIdat) {
                throw PngFormatException(InvalidPalette, chunk.offset, "PLTE must appear before IDAT")
            }
            validatePaletteChunk(chunk, ihdr)
            palette = chunk.payload()
            seenPalette = true
            return
        }
        if (chunk.isType(PNG_CHUNK_tRNS)) {
            if (seenTransparency) {
                throw PngFormatException(
                    InvalidTransparency,
                    chunk.offset,
                    "PNG contains more than one tRNS chunk"
                )
            }
            if (seenIdat) {
                throw PngFormatException(InvalidTransparency, chunk.offset, "tRNS must appear before IDAT")
            }
            transparency = parsePngTransparencyChunk(chunk, ihdr, palette)
            seenTransparency = true
            return
        }
        if (metadataBuilder.handleChunk(chunk, ihdr, seenPalette, seenIdat, palette, limits)) {
            if (seenIdat) {
                idatEnded = true
            }
            return
        }
        if (seenIdat) {
            idatEnded = true
        }
        let retained = metadataBuilder.retainUnknown(chunk, seenPalette, seenIdat, unknownPolicy)
        if (isCriticalChunk(chunk.chunkType()) && !retained) {
            throw PngFormatException(
                UnsupportedCriticalChunk,
                chunk.offset,
                "PNG contains an unsupported critical chunk"
            )
        }
    }

    private func resetAfterChunk(): Unit {
        currentChunkLength = UInt32(0)
        currentChunkType = Array<Byte>()
        currentChunkDataReceived = UInt32(0)
        currentChunkData = ArrayList<Byte>()
        currentChunkCrcBytes = ArrayList<Byte>()
        currentChunkCrcState = pngCrc32Start()
        if (!parseDone) {
            phase = ProgressiveChunkHeader
        }
    }

    private func processInput(bytes: Array<Byte>): Int64 {
        var index: Int64 = Int64(0)
        processingValue = true
        try {
            drainInflatedPending()
            while (index < bytes.size && !pauseRequested) {
                if (phase == ProgressiveStreamDone) {
                    throw PngFormatException(
                        TrailingData,
                        Int64(processedValue),
                        "PNG contains bytes after IEND"
                    )
                }
                if (phase == ProgressiveSignature) {
                    signatureBytes.add(bytes[index])
                    index += Int64(1)
                    processedValue += UInt64(1)
                    if (signatureBytes.size == PNG_SIGNATURE.size) {
                        if (!isPngSignature(signatureBytes.toArray())) {
                            throw PngFormatException(
                                InvalidSignature,
                                Int64(0),
                                "input does not start with a PNG signature"
                            )
                        }
                        signatureBytes = ArrayList<Byte>()
                        phase = ProgressiveChunkHeader
                    }
                    continue
                }
                if (phase == ProgressiveChunkHeader) {
                    if (headerBytes.size == Int64(0)) {
                        currentChunkOffset = Int64(processedValue)
                    }
                    headerBytes.add(bytes[index])
                    index += Int64(1)
                    processedValue += UInt64(1)
                    if (headerBytes.size == Int64(8)) {
                        beginChunkHeader()
                    }
                    continue
                }
                if (phase == ProgressiveChunkData) {
                    let remaining = Int64(currentChunkLength - currentChunkDataReceived)
                    let available = bytes.size - index
                    let take = if (remaining < available) { remaining } else { available }
                    if (sameBytes(currentChunkType, PNG_CHUNK_IDAT)) {
                        let nextCompressed = compressedSize + UInt64(take)
                        if (nextCompressed < compressedSize || nextCompressed > limits.maxCompressedBytes) {
                            throw PngFormatException(
                                DecodeLimitExceeded,
                                currentChunkOffset,
                                "combined IDAT data exceeds configured compressed-byte limit"
                            )
                        }
                        if (inflaterValues[0].ended()) {
                            throw PngFormatException(
                                TrailingCompressedData,
                                Int64(processedValue),
                                "IDAT contains bytes after the end of the zlib stream"
                            )
                        }
                        let segment = copyByteRange(bytes, index, take)
                        let consumed = inflaterValues[0].push(segment, { output => acceptInflated(output) })
                        if (consumed > Int64(0)) {
                            let used = copyByteRange(segment, Int64(0), consumed)
                            currentChunkCrcState = pngCrc32Update(currentChunkCrcState, used)
                            currentChunkDataReceived += UInt32(consumed)
                            compressedSize += UInt64(consumed)
                            index += consumed
                            processedValue += UInt64(consumed)
                        }
                        if (consumed < take && !pauseRequested) {
                            throw PngFormatException(
                                TrailingCompressedData,
                                Int64(processedValue),
                                "IDAT contains bytes after the end of the zlib stream"
                            )
                        }
                    } else {
                        let segment = copyByteRange(bytes, index, take)
                        appendProgressiveBytes(currentChunkData, segment, Int64(0), segment.size)
                        currentChunkCrcState = pngCrc32Update(currentChunkCrcState, segment)
                        currentChunkDataReceived += UInt32(take)
                        index += take
                        processedValue += UInt64(take)
                    }
                    if (currentChunkDataReceived == currentChunkLength) {
                        phase = ProgressiveChunkCrc
                    }
                    continue
                }
                if (phase == ProgressiveChunkCrc) {
                    currentChunkCrcBytes.add(bytes[index])
                    index += Int64(1)
                    processedValue += UInt64(1)
                    if (currentChunkCrcBytes.size == Int64(4)) {
                        let expectedCrc = readUInt32Be(currentChunkCrcBytes.toArray(), Int64(0))
                        processCurrentChunk(expectedCrc)
                        resetAfterChunk()
                    }
                    continue
                }
            }
        } finally {
            processingValue = false
        }
        index
    }

    private func updateStateAfterProcessing(): Unit {
        if (pauseRequested) {
            stateValue = ProgressivePaused
        } else if (stateValue != ProgressiveFailed && stateValue != ProgressiveClosed) {
            stateValue = ProgressiveOpen
        }
    }

    public func feedAvailable(bytes: Array<Byte>): Int64 {
        requireOpen("feed")
        if (retainedInput.size != Int64(0)) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "resume retained progressive input before feeding new bytes"
            )
        }
        if (UInt64(bytes.size) > maxInputBytes - receivedValue) {
            stateValue = ProgressiveFailed
            throw PngFormatException(
                DecodeLimitExceeded,
                -1,
                "progressive input exceeds configured byte limit"
            )
        }
        pauseRequested = false
        try {
            let consumed = processInput(bytes)
            receivedValue += UInt64(consumed)
            lastUnconsumedValue = UInt64(bytes.size - consumed)
            updateStateAfterProcessing()
            consumed
        } catch (error: Exception) {
            fail(error)
        }
    }

    public func feed(bytes: Array<Byte>): Unit {
        requireOpen("feed")
        if (retainedInput.size != Int64(0)) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "resume retained progressive input before feeding new bytes"
            )
        }
        let next = receivedValue + UInt64(bytes.size)
        if (next < receivedValue || next > maxInputBytes) {
            stateValue = ProgressiveFailed
            throw PngFormatException(
                DecodeLimitExceeded,
                -1,
                "progressive input exceeds configured byte limit"
            )
        }
        pauseRequested = false
        receivedValue = next
        try {
            let consumed = processInput(bytes)
            lastUnconsumedValue = UInt64(bytes.size - consumed)
            if (consumed < bytes.size) {
                retainedInput = copyByteRange(bytes, consumed, bytes.size - consumed)
            }
            updateStateAfterProcessing()
        } catch (error: Exception) {
            fail(error)
        }
    }

    public func resume(): Unit {
        if (stateValue == ProgressiveClosed) {
            throw PngFormatException(SessionClosed, -1, "progressive reader is closed")
        }
        if (stateValue != ProgressivePaused) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "progressive reader is not paused"
            )
        }
        stateValue = ProgressiveOpen
        pauseRequested = false
        try {
            drainInflatedPending()
            if (!pauseRequested && retainedInput.size > Int64(0)) {
                let input = retainedInput
                retainedInput = Array<Byte>()
                let consumed = processInput(input)
                if (consumed < input.size) {
                    retainedInput = copyByteRange(input, consumed, input.size - consumed)
                }
            }
            lastUnconsumedValue = UInt64(retainedInput.size)
            updateStateAfterProcessing()
        } catch (error: Exception) {
            fail(error)
        }
    }

    public func finish(): PngDecodedRows {
        requireOpen("finish")
        stateValue = ProgressiveFinalizing
        try {
            if (retainedInput.size != Int64(0)) {
                throw PngFormatException(
                    InvalidArgument,
                    -1,
                    "progressive reader still has paused input to resume"
                )
            }
            if (!parseDone || resultValues.size != Int64(1)) {
                throw PngFormatException(
                    TruncatedInput,
                    Int64(processedValue),
                    "PNG progressive stream ended before a complete IEND chunk"
                )
            }
            stateValue = ProgressiveCompleted
            resultValues[0]
        } catch (error: Exception) {
            fail(error)
        }
    }

    public func close(): Unit {
        if (processingValue || stateValue == ProgressiveFinalizing) {
            throw PngFormatException(
                InvalidArgument,
                -1,
                "cannot close progressive reader while callbacks are active"
            )
        }
        closeInflaterNoThrow()
        retainedInput = Array<Byte>()
        inflatedPending = ArrayList<Byte>()
        rowFrame = ArrayList<Byte>()
        rowsValue = Array<Array<Byte>>()
        receivedValue = UInt64(0)
        lastUnconsumedValue = UInt64(0)
        stateValue = ProgressiveClosed
    }
}
