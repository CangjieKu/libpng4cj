package libpng4cj

private let PNG_WRITE_FILTER_MASK_NONE: UInt8 = UInt8(0x08)
private let PNG_WRITE_FILTER_MASK_SUB: UInt8 = UInt8(0x10)
private let PNG_WRITE_FILTER_MASK_UP: UInt8 = UInt8(0x20)
private let PNG_WRITE_FILTER_MASK_AVERAGE: UInt8 = UInt8(0x40)
private let PNG_WRITE_FILTER_MASK_PAETH: UInt8 = UInt8(0x80)
private let PNG_WRITE_FILTER_MASK_ALL: UInt8 = UInt8(0xf8)

public enum PngWriteCompressionStrategy <:
    Equatable<PngWriteCompressionStrategy> & ToString {
    | WriteCompressionDefault
    | WriteCompressionFiltered
    | WriteCompressionHuffmanOnly
    | WriteCompressionRle
    | WriteCompressionFixed

    public operator func ==(right: PngWriteCompressionStrategy): Bool {
        zlibValue() == right.zlibValue()
    }

    public operator func !=(right: PngWriteCompressionStrategy): Bool {
        !(this == right)
    }

    func zlibValue(): Int32 {
        match (this) {
            case WriteCompressionDefault => Int32(0)
            case WriteCompressionFiltered => Int32(1)
            case WriteCompressionHuffmanOnly => Int32(2)
            case WriteCompressionRle => Int32(3)
            case WriteCompressionFixed => Int32(4)
        }
    }

    public func toString(): String {
        match (this) {
            case WriteCompressionDefault => "DEFAULT"
            case WriteCompressionFiltered => "FILTERED"
            case WriteCompressionHuffmanOnly => "HUFFMAN_ONLY"
            case WriteCompressionRle => "RLE"
            case WriteCompressionFixed => "FIXED"
        }
    }
}

public enum PngWriteFilterHeuristic <:
    Equatable<PngWriteFilterHeuristic> & ToString {
    | WriteHeuristicDefault
    | WriteHeuristicUnweighted

    public operator func ==(right: PngWriteFilterHeuristic): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngWriteFilterHeuristic): Bool {
        !(this == right)
    }

    private func ordinalValue(): Int64 {
        match (this) {
            case WriteHeuristicDefault => Int64(0)
            case WriteHeuristicUnweighted => Int64(1)
        }
    }

    public func toString(): String {
        match (this) {
            case WriteHeuristicDefault => "DEFAULT"
            case WriteHeuristicUnweighted => "UNWEIGHTED"
        }
    }
}

public class PngWriteControlState {
    private var filterMaskValue: UInt8 = UInt8(0)
    private var heuristicValue: PngWriteFilterHeuristic = WriteHeuristicDefault
    private var compressionLevelValue: Int32 = Int32(-1)
    private var compressionMemoryLevelValue: Int32 = Int32(8)
    private var compressionWindowBitsValue: Int32 = Int32(15)
    private var compressionMethodValue: Int32 = Int32(8)
    private var compressionStrategyValue: PngWriteCompressionStrategy =
        WriteCompressionDefault
    private var customCompressionStrategyValue: Bool = false
    private var compressionBufferBytesValue: Int64 = Int64(32_768)

    public init() {}

    public init(strategy: PngWriteFilterStrategy, compressionLevel: Int32) {
        setFilter(strategy)
        compressionLevelValue = compressionLevel
    }

    public func setFilter(strategy: PngWriteFilterStrategy): Unit {
        filterMaskValue = match (strategy) {
            case WriteFilterNone => PNG_WRITE_FILTER_MASK_NONE
            case WriteFilterSub => PNG_WRITE_FILTER_MASK_SUB
            case WriteFilterUp => PNG_WRITE_FILTER_MASK_UP
            case WriteFilterAverage => PNG_WRITE_FILTER_MASK_AVERAGE
            case WriteFilterPaeth => PNG_WRITE_FILTER_MASK_PAETH
            case WriteFilterAdaptive => PNG_WRITE_FILTER_MASK_ALL
        }
    }

    public func useDefaultFilters(): Unit {
        filterMaskValue = UInt8(0)
    }

    public func setFilters(
        none: Bool,
        sub: Bool,
        up: Bool,
        average: Bool,
        paeth: Bool
    ): Unit {
        var mask = UInt8(0)
        if (none) { mask |= PNG_WRITE_FILTER_MASK_NONE }
        if (sub) { mask |= PNG_WRITE_FILTER_MASK_SUB }
        if (up) { mask |= PNG_WRITE_FILTER_MASK_UP }
        if (average) { mask |= PNG_WRITE_FILTER_MASK_AVERAGE }
        if (paeth) { mask |= PNG_WRITE_FILTER_MASK_PAETH }
        if (mask == UInt8(0)) {
            throw PngFormatException(
                InvalidArgument, -1, "at least one PNG write filter is required"
            )
        }
        filterMaskValue = mask
    }

    public func setFilterHeuristic(heuristic: PngWriteFilterHeuristic): Unit {
        heuristicValue = heuristic
    }

    public func setCompressionLevel(level: Int32): Unit {
        if (level < Int32(-1) || level > Int32(9)) {
            throw PngFormatException(
                InvalidArgument, -1, "zlib compression level must be in -1..9"
            )
        }
        compressionLevelValue = level
    }

    public func setCompressionMemoryLevel(level: Int32): Unit {
        if (level < Int32(1) || level > Int32(9)) {
            throw PngFormatException(
                InvalidArgument, -1, "zlib compression memory level must be in 1..9"
            )
        }
        compressionMemoryLevelValue = level
    }

    public func setCompressionWindowBits(bits: Int32): Unit {
        if (bits < Int32(8)) {
            compressionWindowBitsValue = Int32(8)
        } else if (bits > Int32(15)) {
            compressionWindowBitsValue = Int32(15)
        } else {
            compressionWindowBitsValue = bits
        }
    }

    public func setCompressionMethod(method: Int32): Unit {
        if (method != Int32(8)) {
            throw PngFormatException(
                InvalidArgument, -1, "PNG requires zlib compression method 8"
            )
        }
        compressionMethodValue = method
    }

    public func setCompressionStrategy(
        strategy: PngWriteCompressionStrategy
    ): Unit {
        compressionStrategyValue = strategy
        customCompressionStrategyValue = true
    }

    public func useAutomaticCompressionStrategy(): Unit {
        compressionStrategyValue = WriteCompressionDefault
        customCompressionStrategyValue = false
    }

    public func setCompressionBufferBytes(bytes: Int64): Unit {
        if (bytes <= Int64(0) || bytes > Int64(UInt32.Max)) {
            throw PngFormatException(
                InvalidArgument, -1,
                "zlib write buffer must be in 1..UInt32.Max"
            )
        }
        compressionBufferBytesValue = bytes
    }

    public func compressionLevel(): Int32 { compressionLevelValue }
    public func compressionMemoryLevel(): Int32 { compressionMemoryLevelValue }
    public func compressionWindowBits(): Int32 { compressionWindowBitsValue }
    public func compressionMethod(): Int32 { compressionMethodValue }
    public func compressionBufferBytes(): Int64 { compressionBufferBytesValue }
    public func filterHeuristic(): PngWriteFilterHeuristic { heuristicValue }

    func initializeFor(ihdr: PngIhdr): PngWriteControlInitialization {
        var mask = filterMaskValue
        if (mask == UInt8(0)) {
            mask = if (ihdr.colorType == Indexed || ihdr.bitDepth < UInt8(8)) {
                PNG_WRITE_FILTER_MASK_NONE
            } else {
                PNG_WRITE_FILTER_MASK_ALL
            }
        }
        if (ihdr.height == UInt32(1)) {
            var horizontal = UInt8(0)
            if ((mask & PNG_WRITE_FILTER_MASK_NONE) != UInt8(0)) {
                horizontal |= PNG_WRITE_FILTER_MASK_NONE
            }
            if ((mask & PNG_WRITE_FILTER_MASK_SUB) != UInt8(0)) {
                horizontal |= PNG_WRITE_FILTER_MASK_SUB
            }
            mask = horizontal
        }
        if (ihdr.width == UInt32(1)) {
            var vertical = UInt8(0)
            if ((mask & PNG_WRITE_FILTER_MASK_NONE) != UInt8(0)) {
                vertical |= PNG_WRITE_FILTER_MASK_NONE
            }
            if ((mask & PNG_WRITE_FILTER_MASK_UP) != UInt8(0)) {
                vertical |= PNG_WRITE_FILTER_MASK_UP
            }
            mask = vertical
        }
        if (mask == UInt8(0)) {
            mask = PNG_WRITE_FILTER_MASK_NONE
        }
        let resolvedStrategy = if (customCompressionStrategyValue) {
            compressionStrategyValue
        } else if (mask != PNG_WRITE_FILTER_MASK_NONE) {
            WriteCompressionFiltered
        } else {
            WriteCompressionDefault
        }
        PngWriteControlInitialization(
            mask, heuristicValue, compressionLevelValue,
            compressionMemoryLevelValue, compressionWindowBitsValue,
            compressionMethodValue, resolvedStrategy,
            compressionBufferBytesValue
        )
    }
}

class PngWriteControlInitialization {
    let filterMask: UInt8
    let heuristic: PngWriteFilterHeuristic
    let compressionLevel: Int32
    let compressionMemoryLevel: Int32
    let compressionWindowBits: Int32
    let compressionMethod: Int32
    let compressionStrategy: PngWriteCompressionStrategy
    let compressionBufferBytes: Int64

    init(
        filterMask: UInt8,
        heuristic: PngWriteFilterHeuristic,
        compressionLevel: Int32,
        compressionMemoryLevel: Int32,
        compressionWindowBits: Int32,
        compressionMethod: Int32,
        compressionStrategy: PngWriteCompressionStrategy,
        compressionBufferBytes: Int64
    ) {
        this.filterMask = filterMask
        this.heuristic = heuristic
        this.compressionLevel = compressionLevel
        this.compressionMemoryLevel = compressionMemoryLevel
        this.compressionWindowBits = compressionWindowBits
        this.compressionMethod = compressionMethod
        this.compressionStrategy = compressionStrategy
        this.compressionBufferBytes = compressionBufferBytes
    }

    func allows(filterType: UInt8): Bool {
        let bit = if (filterType == PNG_FILTER_NONE) {
            PNG_WRITE_FILTER_MASK_NONE
        } else if (filterType == PNG_FILTER_SUB) {
            PNG_WRITE_FILTER_MASK_SUB
        } else if (filterType == PNG_FILTER_UP) {
            PNG_WRITE_FILTER_MASK_UP
        } else if (filterType == PNG_FILTER_AVERAGE) {
            PNG_WRITE_FILTER_MASK_AVERAGE
        } else if (filterType == PNG_FILTER_PAETH) {
            PNG_WRITE_FILTER_MASK_PAETH
        } else {
            UInt8(0)
        }
        bit != UInt8(0) && (filterMask & bit) != UInt8(0)
    }
}
