package libpng4cj

public enum PngErrorKind <: Equatable<PngErrorKind> & ToString {
    | InvalidArgument
    | SessionClosed
    | InvalidSignature
    | TruncatedInput
    | InvalidChunkLength
    | ChunkTooLarge
    | InvalidChunkType
    | CrcMismatch
    | MissingIhdr
    | DuplicateIhdr
    | IhdrOutOfOrder
    | InvalidIhdr
    | DecodeLimitExceeded
    | ZlibFailure
    | InflatedSizeMismatch
    | TrailingCompressedData
    | MissingIdat
    | NonConsecutiveIdat
    | MissingIend
    | InvalidIend
    | TrailingData
    | UnsupportedCriticalChunk
    | InvalidPalette
    | UnsupportedInterlace
    | InvalidFilter
    | InvalidData
    | InvalidTransparency
    | UnsupportedTransform
    | PaletteIndexOutOfRange
    | InvalidMetadata
    | DuplicateMetadata
    | MetadataOutOfOrder
    | InvalidIccProfile
    | InvalidTextMetadata
    | InvalidTimeMetadata
    | RgbToGrayMismatch
    | AllocationFailure

    public operator func ==(right: PngErrorKind): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngErrorKind): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case InvalidArgument => 0
            case SessionClosed => 1
            case InvalidSignature => 2
            case TruncatedInput => 3
            case InvalidChunkLength => 4
            case ChunkTooLarge => 5
            case InvalidChunkType => 6
            case CrcMismatch => 7
            case MissingIhdr => 8
            case DuplicateIhdr => 9
            case IhdrOutOfOrder => 10
            case InvalidIhdr => 11
            case DecodeLimitExceeded => 12
            case ZlibFailure => 13
            case InflatedSizeMismatch => 14
            case TrailingCompressedData => 15
            case MissingIdat => 16
            case NonConsecutiveIdat => 17
            case MissingIend => 18
            case InvalidIend => 19
            case TrailingData => 20
            case UnsupportedCriticalChunk => 21
            case InvalidPalette => 22
            case UnsupportedInterlace => 23
            case InvalidFilter => 24
            case InvalidData => 25
            case InvalidTransparency => 26
            case UnsupportedTransform => 27
            case PaletteIndexOutOfRange => 28
            case InvalidMetadata => 29
            case DuplicateMetadata => 30
            case MetadataOutOfOrder => 31
            case InvalidIccProfile => 32
            case InvalidTextMetadata => 33
            case InvalidTimeMetadata => 34
            case RgbToGrayMismatch => 35
            case AllocationFailure => 36
        }
    }

    public func toString(): String {
        match (this) {
            case InvalidArgument => "INVALID_ARGUMENT"
            case SessionClosed => "SESSION_CLOSED"
            case InvalidSignature => "INVALID_SIGNATURE"
            case TruncatedInput => "TRUNCATED_INPUT"
            case InvalidChunkLength => "INVALID_CHUNK_LENGTH"
            case ChunkTooLarge => "CHUNK_TOO_LARGE"
            case InvalidChunkType => "INVALID_CHUNK_TYPE"
            case CrcMismatch => "CRC_MISMATCH"
            case MissingIhdr => "MISSING_IHDR"
            case DuplicateIhdr => "DUPLICATE_IHDR"
            case IhdrOutOfOrder => "IHDR_OUT_OF_ORDER"
            case InvalidIhdr => "INVALID_IHDR"
            case DecodeLimitExceeded => "DECODE_LIMIT_EXCEEDED"
            case ZlibFailure => "ZLIB_FAILURE"
            case InflatedSizeMismatch => "INFLATED_SIZE_MISMATCH"
            case TrailingCompressedData => "TRAILING_COMPRESSED_DATA"
            case MissingIdat => "MISSING_IDAT"
            case NonConsecutiveIdat => "NON_CONSECUTIVE_IDAT"
            case MissingIend => "MISSING_IEND"
            case InvalidIend => "INVALID_IEND"
            case TrailingData => "TRAILING_DATA"
            case UnsupportedCriticalChunk => "UNSUPPORTED_CRITICAL_CHUNK"
            case InvalidPalette => "INVALID_PALETTE"
            case UnsupportedInterlace => "UNSUPPORTED_INTERLACE"
            case InvalidFilter => "INVALID_FILTER"
            case InvalidData => "INVALID_DATA"
            case InvalidTransparency => "INVALID_TRANSPARENCY"
            case UnsupportedTransform => "UNSUPPORTED_TRANSFORM"
            case PaletteIndexOutOfRange => "PALETTE_INDEX_OUT_OF_RANGE"
            case InvalidMetadata => "INVALID_METADATA"
            case DuplicateMetadata => "DUPLICATE_METADATA"
            case MetadataOutOfOrder => "METADATA_OUT_OF_ORDER"
            case InvalidIccProfile => "INVALID_ICC_PROFILE"
            case InvalidTextMetadata => "INVALID_TEXT_METADATA"
            case InvalidTimeMetadata => "INVALID_TIME_METADATA"
            case RgbToGrayMismatch => "RGB_TO_GRAY_MISMATCH"
            case AllocationFailure => "ALLOCATION_FAILURE"
        }
    }
}

public class PngFormatException <: Exception {
    public let kind: PngErrorKind
    public let offset: Int64

    public PngFormatException(kind: PngErrorKind, offset: Int64, message: String) {
        super(message)
        this.kind = kind
        this.offset = offset
    }
}
