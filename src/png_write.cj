package libpng4cj

import std.collection.ArrayList

public let PNG_DEFAULT_MAX_WRITE_OUTPUT_BYTES: UInt64 = UInt64(512_000_000)
public let PNG_DEFAULT_MAX_WRITE_FILTERED_BYTES: UInt64 = UInt64(512_000_000)
public let PNG_DEFAULT_MAX_WRITE_COMPRESSED_BYTES: UInt64 = UInt64(256_000_000)
public let PNG_DEFAULT_WRITE_IDAT_CHUNK_BYTES: UInt32 = UInt32(1_048_576)

public enum PngWriteState <: Equatable<PngWriteState> & ToString {
    | WriteOpen
    | WriteFinalizing
    | WriteCompleted
    | WriteFailed
    | WriteClosed

    public operator func ==(right: PngWriteState): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngWriteState): Bool {
        !(this == right)
    }

    private func ordinalValue(): Int64 {
        match (this) {
            case WriteOpen => 0
            case WriteFinalizing => 1
            case WriteCompleted => 2
            case WriteFailed => 3
            case WriteClosed => 4
        }
    }

    public func toString(): String {
        match (this) {
            case WriteOpen => "OPEN"
            case WriteFinalizing => "FINALIZING"
            case WriteCompleted => "COMPLETED"
            case WriteFailed => "FAILED"
            case WriteClosed => "CLOSED"
        }
    }
}

public enum PngWriteFilterStrategy <: Equatable<PngWriteFilterStrategy> & ToString {
    | WriteFilterNone
    | WriteFilterSub
    | WriteFilterUp
    | WriteFilterAverage
    | WriteFilterPaeth
    | WriteFilterAdaptive

    public operator func ==(right: PngWriteFilterStrategy): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngWriteFilterStrategy): Bool {
        !(this == right)
    }

    private func ordinalValue(): Int64 {
        match (this) {
            case WriteFilterNone => 0
            case WriteFilterSub => 1
            case WriteFilterUp => 2
            case WriteFilterAverage => 3
            case WriteFilterPaeth => 4
            case WriteFilterAdaptive => 5
        }
    }

    public func toString(): String {
        match (this) {
            case WriteFilterNone => "NONE"
            case WriteFilterSub => "SUB"
            case WriteFilterUp => "UP"
            case WriteFilterAverage => "AVERAGE"
            case WriteFilterPaeth => "PAETH"
            case WriteFilterAdaptive => "ADAPTIVE"
        }
    }
}

public class PngWriteLimits {
    public let maxFilteredBytes: UInt64
    public let maxOutputBytes: UInt64
    public let maxCompressedBytes: UInt64
    public let idatChunkBytes: UInt32

    public init(
        maxFilteredBytes: UInt64,
        maxCompressedBytes: UInt64,
        maxOutputBytes: UInt64,
        idatChunkBytes: UInt32
    ) {
        validateWriteByteLimit(maxFilteredBytes, "filtered PNG row limit")
        validateWriteByteLimit(maxCompressedBytes, "compressed PNG byte limit")
        validateWriteByteLimit(maxOutputBytes, "encoded PNG output limit")
        if (idatChunkBytes == UInt32(0) || idatChunkBytes > PNG_UINT_31_MAX) {
            throw PngFormatException(InvalidArgument, -1, "IDAT chunk size must be in 1..PNG_UINT_31_MAX")
        }
        this.maxFilteredBytes = maxFilteredBytes
        this.maxCompressedBytes = maxCompressedBytes
        this.maxOutputBytes = maxOutputBytes
        this.idatChunkBytes = idatChunkBytes
    }

    public init(maxOutputBytes: UInt64, maxCompressedBytes: UInt64, idatChunkBytes: UInt32) {
        this(
            PNG_DEFAULT_MAX_WRITE_FILTERED_BYTES,
            maxCompressedBytes,
            maxOutputBytes,
            idatChunkBytes
        )
    }

    public init() {
        maxFilteredBytes = PNG_DEFAULT_MAX_WRITE_FILTERED_BYTES
        maxOutputBytes = PNG_DEFAULT_MAX_WRITE_OUTPUT_BYTES
        maxCompressedBytes = PNG_DEFAULT_MAX_WRITE_COMPRESSED_BYTES
        idatChunkBytes = PNG_DEFAULT_WRITE_IDAT_CHUNK_BYTES
    }
}

private func validateWriteByteLimit(value: UInt64, label: String): Unit {
    if (value == UInt64(0) || value > UInt64(Int64.Max)) {
        throw PngFormatException(InvalidArgument, -1, "${label} must be in 1..Int64.Max")
    }
}

private func appendWriteBytes(target: ArrayList<Byte>, bytes: Array<Byte>): Unit {
    var index: Int64 = Int64(0)
    while (index < bytes.size) {
        target.add(bytes[index])
        index += Int64(1)
    }
}

private func validWriteColorDepth(colorType: PngColorType, bitDepth: UInt8): Bool {
    match (colorType) {
        case Grayscale => bitDepth == UInt8(1) || bitDepth == UInt8(2) ||
            bitDepth == UInt8(4) || bitDepth == UInt8(8) || bitDepth == UInt8(16)
        case Indexed => bitDepth == UInt8(1) || bitDepth == UInt8(2) ||
            bitDepth == UInt8(4) || bitDepth == UInt8(8)
        case Truecolor => bitDepth == UInt8(8) || bitDepth == UInt8(16)
        case GrayscaleAlpha => bitDepth == UInt8(8) || bitDepth == UInt8(16)
        case TruecolorAlpha => bitDepth == UInt8(8) || bitDepth == UInt8(16)
    }
}

private func validateWriteHeader(width: UInt32, height: UInt32, bitDepth: UInt8, colorType: PngColorType): PngIhdr {
    if (width == UInt32(0) || width > PNG_UINT_31_MAX ||
        height == UInt32(0) || height > PNG_UINT_31_MAX) {
        throw PngFormatException(InvalidIhdr, -1, "PNG write dimensions must be in 1..PNG_UINT_31_MAX")
    }
    if (!validWriteColorDepth(colorType, bitDepth)) {
        throw PngFormatException(InvalidIhdr, -1, "PNG write color type and bit depth are incompatible")
    }
    PngIhdr(width, height, bitDepth, colorType, UInt8(0), UInt8(0), None)
}

private func makeWriteChunk(chunkType: Array<Byte>, data: Array<Byte>): Array<Byte> {
    if (!isValidChunkType(chunkType) || data.size > Int64(PNG_UINT_31_MAX)) {
        throw PngFormatException(InvalidArgument, -1, "PNG write chunk is invalid or too large")
    }
    let out = ArrayList<Byte>()
    appendWriteBytes(out, writeUInt32Be(UInt32(data.size)))
    appendWriteBytes(out, chunkType)
    appendWriteBytes(out, data)
    appendWriteBytes(out, writeUInt32Be(pngChunkCrc32(chunkType, data)))
    out.toArray()
}

private func makeWriteIhdr(ihdr: PngIhdr): Array<Byte> {
    let data = ArrayList<Byte>()
    appendWriteBytes(data, writeUInt32Be(ihdr.width))
    appendWriteBytes(data, writeUInt32Be(ihdr.height))
    data.add(ihdr.bitDepth)
    data.add(ihdr.colorType.encodedValue())
    data.add(UInt8(0))
    data.add(UInt8(0))
    data.add(UInt8(0))
    makeWriteChunk(PNG_CHUNK_IHDR, data.toArray())
}

private func addWriteOutputSize(total: UInt64, amount: UInt64, limit: UInt64): UInt64 {
    if (amount > limit || total > limit - amount) {
        throw PngFormatException(DecodeLimitExceeded, -1, "encoded PNG exceeds configured output limit")
    }
    total + amount
}

private func addRepeatedWriteOutputSize(
    total: UInt64,
    amount: UInt64,
    count: UInt64,
    limit: UInt64
): UInt64 {
    if (total > limit) {
        throw PngFormatException(DecodeLimitExceeded, -1, "encoded PNG exceeds configured output limit")
    }
    if (amount == UInt64(0)) {
        return total
    }
    if (count > (limit - total) / amount) {
        throw PngFormatException(DecodeLimitExceeded, -1, "encoded PNG exceeds configured output limit")
    }
    total + amount * count
}

private func expectedWriteOutputSize(
    paletteBytes: UInt64,
    compressedBytes: UInt64,
    idatChunkBytes: UInt32,
    limit: UInt64
): UInt64 {
    let chunkBytes = UInt64(idatChunkBytes)
    let idatCount = compressedBytes / chunkBytes +
        if (compressedBytes % chunkBytes == UInt64(0)) { UInt64(0) } else { UInt64(1) }
    var total = addWriteOutputSize(UInt64(0), UInt64(PNG_SIGNATURE.size), limit)
    total = addWriteOutputSize(total, UInt64(25), limit)
    if (paletteBytes > UInt64(0)) {
        total = addWriteOutputSize(total, UInt64(12), limit)
        total = addWriteOutputSize(total, paletteBytes, limit)
    }
    total = addWriteOutputSize(total, compressedBytes, limit)
    total = addRepeatedWriteOutputSize(total, UInt64(12), idatCount, limit)
    addWriteOutputSize(total, UInt64(12), limit)
}

private func validateWritePalette(ihdr: PngIhdr, palette: Array<Byte>): Unit {
    if (palette.size == Int64(0)) {
        if (ihdr.colorType == Indexed) {
            throw PngFormatException(InvalidPalette, -1, "indexed PNG write requires a palette")
        }
        return
    }
    if (ihdr.colorType == Grayscale || ihdr.colorType == GrayscaleAlpha) {
        throw PngFormatException(InvalidPalette, -1, "grayscale PNG writes cannot contain PLTE")
    }
    if (palette.size % Int64(3) != Int64(0)) {
        throw PngFormatException(InvalidPalette, -1, "PNG write palette requires RGB triples")
    }
    let entries = palette.size / Int64(3)
    if (entries > Int64(256)) {
        throw PngFormatException(InvalidPalette, -1, "PNG write palette exceeds 256 entries")
    }
    if (ihdr.colorType == Indexed) {
        let capacity = Int64(UInt32(1) << UInt32(ihdr.bitDepth))
        if (entries > capacity) {
            throw PngFormatException(InvalidPalette, -1, "indexed PNG palette exceeds bit-depth capacity")
        }
    }
}

private func filterTypeForStrategy(strategy: PngWriteFilterStrategy): UInt8 {
    match (strategy) {
        case WriteFilterNone => PNG_FILTER_NONE
        case WriteFilterSub => PNG_FILTER_SUB
        case WriteFilterUp => PNG_FILTER_UP
        case WriteFilterAverage => PNG_FILTER_AVERAGE
        case WriteFilterPaeth => PNG_FILTER_PAETH
        case WriteFilterAdaptive => PNG_FILTER_NONE
    }
}

private func filteredByteScore(bytes: Array<Byte>): UInt64 {
    var score: UInt64 = UInt64(0)
    var index: Int64 = Int64(0)
    while (index < bytes.size) {
        let value = UInt64(bytes[index])
        score += if (value < UInt64(128)) { value } else { UInt64(256) - value }
        index += Int64(1)
    }
    score
}

private class SelectedWriteFilter {
    let filterType: UInt8
    let bytes: Array<Byte>

    init(filterType: UInt8, bytes: Array<Byte>) {
        this.filterType = filterType
        this.bytes = bytes
    }
}

private func selectWriteFilter(
    strategy: PngWriteFilterStrategy,
    row: Array<Byte>,
    previous: Array<Byte>,
    bytesPerPixel: Int64
): SelectedWriteFilter {
    if (strategy != WriteFilterAdaptive) {
        let filterType = filterTypeForStrategy(strategy)
        return SelectedWriteFilter(filterType, filterPngRow(filterType, row, previous, bytesPerPixel))
    }
    var selectedType = PNG_FILTER_NONE
    var selected = filterPngRow(selectedType, row, previous, bytesPerPixel)
    var selectedScore = filteredByteScore(selected)
    var filterType = PNG_FILTER_SUB
    while (filterType <= PNG_FILTER_PAETH) {
        let candidate = filterPngRow(filterType, row, previous, bytesPerPixel)
        let score = filteredByteScore(candidate)
        if (score < selectedScore) {
            selectedType = filterType
            selected = candidate
            selectedScore = score
        }
        filterType += UInt8(1)
    }
    SelectedWriteFilter(selectedType, selected)
}

private func buildFilteredWriteRows(
    ihdr: PngIhdr,
    rows: Array<Array<Byte>>,
    strategy: PngWriteFilterStrategy,
    maxCompressedInput: UInt64,
    paletteEntryCount: Int64
): Array<Byte> {
    if (rows.size != Int64(ihdr.height)) {
        throw PngFormatException(InvalidArgument, -1, "PNG write row count does not match height")
    }
    let frameBytes = ihdr.rowBytes + UInt64(1)
    if (UInt64(ihdr.height) > maxCompressedInput / frameBytes) {
        throw PngFormatException(DecodeLimitExceeded, -1, "filtered PNG rows exceed configured input limit")
    }
    let out = ArrayList<Byte>()
    let bytesPerPixel = pngFilterBytesPerPixel(ihdr)
    var previous = Array<Byte>(Int64(ihdr.rowBytes), repeat: UInt8(0))
    var rowIndex: Int64 = Int64(0)
    while (rowIndex < rows.size) {
        let row = rows[rowIndex]
        if (UInt64(row.size) != ihdr.rowBytes) {
            throw PngFormatException(InvalidArgument, rowIndex, "PNG write row length does not match IHDR geometry")
        }
        if (ihdr.colorType == Indexed && paletteEntryCount > Int64(0)) {
            var pixel: UInt64 = UInt64(0)
            while (pixel < UInt64(ihdr.width)) {
                let value = if (ihdr.bitDepth == UInt8(8)) {
                    Int64(row[Int64(pixel)])
                } else {
                    let bitOffset = pixel * UInt64(ihdr.bitDepth)
                    let sourceOffset = Int64(bitOffset / UInt64(8))
                    let shift = UInt32(8) - UInt32(ihdr.bitDepth) -
                        UInt32(bitOffset % UInt64(8))
                    let mask = (UInt32(1) << UInt32(ihdr.bitDepth)) - UInt32(1)
                    Int64((UInt32(row[sourceOffset]) >> shift) & mask)
                }
                if (value >= paletteEntryCount) {
                    throw PngFormatException(
                        PaletteIndexOutOfRange,
                        rowIndex,
                        "PNG write row references an index outside PLTE"
                    )
                }
                pixel += UInt64(1)
            }
        }
        let selected = selectWriteFilter(strategy, row, previous, bytesPerPixel)
        out.add(selected.filterType)
        appendWriteBytes(out, selected.bytes)
        previous = row.clone()
        rowIndex += Int64(1)
    }
    out.toArray()
}

public class PngWriteSession {
    private let ihdr: PngIhdr
    private let palette: Array<Byte>
    private let strategy: PngWriteFilterStrategy
    private let compressionLevel: Int32
    private let limits: PngWriteLimits
    private var stateValue: PngWriteState = WriteOpen

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
        ihdr = validateWriteHeader(width, height, bitDepth, colorType)
        validateWritePalette(ihdr, palette)
        this.palette = palette.clone()
        this.strategy = strategy
        this.compressionLevel = compressionLevel
        this.limits = limits
    }

    public func state(): PngWriteState {
        stateValue
    }

    public func write(rows: Array<Array<Byte>>): Array<Byte> {
        if (stateValue == WriteClosed) {
            throw PngFormatException(SessionClosed, -1, "PNG writer is closed")
        }
        if (stateValue != WriteOpen) {
            throw PngFormatException(InvalidArgument, -1, "PNG writer cannot write in ${stateValue.toString()} state")
        }
        stateValue = WriteFinalizing
        try {
            let filtered = buildFilteredWriteRows(
                ihdr, rows, strategy, limits.maxFilteredBytes, palette.size / Int64(3)
            )
            let compressed = compressPngZlib(filtered, compressionLevel, limits.maxCompressedBytes)
            let expectedOutput = expectedWriteOutputSize(
                UInt64(palette.size), UInt64(compressed.size), limits.idatChunkBytes,
                limits.maxOutputBytes
            )
            let out = ArrayList<Byte>()
            appendWriteBytes(out, PNG_SIGNATURE)
            appendWriteBytes(out, makeWriteIhdr(ihdr))
            if (palette.size > Int64(0)) {
                appendWriteBytes(out, makeWriteChunk(PNG_CHUNK_PLTE, palette))
            }
            var offset: Int64 = Int64(0)
            while (offset < compressed.size) {
                let remaining = compressed.size - offset
                let take = if (remaining < Int64(limits.idatChunkBytes)) {
                    remaining
                } else {
                    Int64(limits.idatChunkBytes)
                }
                appendWriteBytes(out, makeWriteChunk(PNG_CHUNK_IDAT, copyByteRange(compressed, offset, take)))
                offset += take
            }
            appendWriteBytes(out, makeWriteChunk(PNG_CHUNK_IEND, Array<Byte>()))
            if (UInt64(out.size) != expectedOutput) {
                throw PngFormatException(InvalidArgument, -1, "encoded PNG size does not match planned chunk structure")
            }
            stateValue = WriteCompleted
            out.toArray()
        } catch (error: Exception) {
            stateValue = WriteFailed
            throw error
        }
    }

    public func close(): Unit {
        stateValue = WriteClosed
    }
}

public func encodePngPacked(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8,
    colorType: PngColorType,
    rows: Array<Array<Byte>>,
    palette: Array<Byte>,
    strategy: PngWriteFilterStrategy,
    compressionLevel: Int32,
    limits: PngWriteLimits
): Array<Byte> {
    PngWriteSession(
        width, height, bitDepth, colorType, palette, strategy,
        compressionLevel, limits
    ).write(rows)
}

public func encodePngPacked(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8,
    colorType: PngColorType,
    rows: Array<Array<Byte>>
): Array<Byte> {
    encodePngPacked(
        width, height, bitDepth, colorType, rows, Array<Byte>(),
        WriteFilterAdaptive, Int32(6), PngWriteLimits()
    )
}

public func encodeIndexedPngPacked(
    width: UInt32,
    height: UInt32,
    bitDepth: UInt8,
    rows: Array<Array<Byte>>,
    palette: Array<Byte>
): Array<Byte> {
    encodePngPacked(
        width, height, bitDepth, Indexed, rows, palette,
        WriteFilterAdaptive, Int32(6), PngWriteLimits()
    )
}
