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
    | InvalidData

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
            case InvalidData => 12
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
            case InvalidData => "INVALID_DATA"
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
