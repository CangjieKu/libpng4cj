package libpng4cj

public enum PngCrcAction <: Equatable<PngCrcAction> & ToString {
    | CrcDefault
    | CrcErrorQuit
    | CrcWarnDiscard
    | CrcWarnUse
    | CrcQuietUse
    | CrcNoChange

    public operator func ==(right: PngCrcAction): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngCrcAction): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case CrcDefault => 0
            case CrcErrorQuit => 1
            case CrcWarnDiscard => 2
            case CrcWarnUse => 3
            case CrcQuietUse => 4
            case CrcNoChange => 5
        }
    }

    public func toString(): String {
        match (this) {
            case CrcDefault => "DEFAULT"
            case CrcErrorQuit => "ERROR_QUIT"
            case CrcWarnDiscard => "WARN_DISCARD"
            case CrcWarnUse => "WARN_USE"
            case CrcQuietUse => "QUIET_USE"
            case CrcNoChange => "NO_CHANGE"
        }
    }
}
