package libpng4cj

import std.collection.ArrayList

public enum PngTextKind <: Equatable<PngTextKind> & ToString {
    | Latin1Uncompressed
    | Latin1Compressed
    | Utf8Uncompressed
    | Utf8Compressed

    public operator func ==(right: PngTextKind): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngTextKind): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Latin1Uncompressed => 0
            case Latin1Compressed => 1
            case Utf8Uncompressed => 2
            case Utf8Compressed => 3
        }
    }

    public func toString(): String {
        match (this) {
            case Latin1Uncompressed => "LATIN1_UNCOMPRESSED"
            case Latin1Compressed => "LATIN1_COMPRESSED"
            case Utf8Uncompressed => "UTF8_UNCOMPRESSED"
            case Utf8Compressed => "UTF8_COMPRESSED"
        }
    }
}

public class PngTextEntry {
    public let kind: PngTextKind
    private let ownedKeyword: Array<Byte>
    private let ownedText: Array<Byte>
    private let ownedLanguageTag: Array<Byte>
    private let ownedTranslatedKeyword: Array<Byte>

    init() {
        kind = Latin1Uncompressed
        ownedKeyword = Array<Byte>()
        ownedText = Array<Byte>()
        ownedLanguageTag = Array<Byte>()
        ownedTranslatedKeyword = Array<Byte>()
    }

    init(
        kind: PngTextKind,
        keyword: Array<Byte>,
        text: Array<Byte>,
        languageTag: Array<Byte>,
        translatedKeyword: Array<Byte>
    ) {
        this.kind = kind
        ownedKeyword = keyword.clone()
        ownedText = text.clone()
        ownedLanguageTag = languageTag.clone()
        ownedTranslatedKeyword = translatedKeyword.clone()
    }

    public func keyword(): Array<Byte> {
        ownedKeyword.clone()
    }

    public func text(): Array<Byte> {
        ownedText.clone()
    }

    public func languageTag(): Array<Byte> {
        ownedLanguageTag.clone()
    }

    public func translatedKeyword(): Array<Byte> {
        ownedTranslatedKeyword.clone()
    }
}

public class PngIccProfile {
    private let ownedName: Array<Byte>
    private let ownedProfile: Array<Byte>

    init() {
        ownedName = Array<Byte>()
        ownedProfile = Array<Byte>()
    }

    init(name: Array<Byte>, profile: Array<Byte>) {
        ownedName = name.clone()
        ownedProfile = profile.clone()
    }

    public func name(): Array<Byte> {
        ownedName.clone()
    }

    public func profile(): Array<Byte> {
        ownedProfile.clone()
    }

    public func profileLength(): Int64 {
        ownedProfile.size
    }
}

public class PngModificationTime {
    public let year: UInt16
    public let month: UInt8
    public let day: UInt8
    public let hour: UInt8
    public let minute: UInt8
    public let second: UInt8

    init() {
        year = UInt16(0)
        month = UInt8(0)
        day = UInt8(0)
        hour = UInt8(0)
        minute = UInt8(0)
        second = UInt8(0)
    }

    init(year: UInt16, month: UInt8, day: UInt8, hour: UInt8, minute: UInt8, second: UInt8) {
        this.year = year
        this.month = month
        this.day = day
        this.hour = hour
        this.minute = minute
        this.second = second
    }
}

public enum PngUnknownChunkPolicy <: Equatable<PngUnknownChunkPolicy> & ToString {
    | Discard
    | RetainAncillary
    | RetainAll

    public operator func ==(right: PngUnknownChunkPolicy): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngUnknownChunkPolicy): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Discard => 0
            case RetainAncillary => 1
            case RetainAll => 2
        }
    }

    public func toString(): String {
        match (this) {
            case Discard => "DISCARD"
            case RetainAncillary => "RETAIN_ANCILLARY"
            case RetainAll => "RETAIN_ALL"
        }
    }
}

public enum PngUnknownChunkLocation <: Equatable<PngUnknownChunkLocation> & ToString {
    | AfterIhdr
    | AfterPlte
    | AfterIdat

    public operator func ==(right: PngUnknownChunkLocation): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngUnknownChunkLocation): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case AfterIhdr => 0
            case AfterPlte => 1
            case AfterIdat => 2
        }
    }

    public func toString(): String {
        match (this) {
            case AfterIhdr => "AFTER_IHDR"
            case AfterPlte => "AFTER_PLTE"
            case AfterIdat => "AFTER_IDAT"
        }
    }
}

public class PngUnknownChunk {
    public let location: PngUnknownChunkLocation
    private let ownedType: Array<Byte>
    private let ownedData: Array<Byte>

    init(chunkType: Array<Byte>, data: Array<Byte>, location: PngUnknownChunkLocation) {
        ownedType = chunkType.clone()
        ownedData = data.clone()
        this.location = location
    }

    public func chunkType(): Array<Byte> {
        ownedType.clone()
    }

    public func payload(): Array<Byte> {
        ownedData.clone()
    }

    public func isSafeToCopy(): Bool {
        (ownedType[3] & UInt8(0x20)) != UInt8(0)
    }
}

class ParsedExtendedMetadata {
    var hasIccProfile: Bool = false
    var iccProfile: PngIccProfile = PngIccProfile()
    var hasModificationTime: Bool = false
    var modificationTime: PngModificationTime = PngModificationTime()
    private let text = ArrayList<PngTextEntry>()
    private let unknown = ArrayList<PngUnknownChunk>()

    func addText(entry: PngTextEntry): Unit {
        text.add(entry)
    }

    func textEntries(): Array<PngTextEntry> {
        text.toArray()
    }

    func addUnknown(chunk: PngUnknownChunk): Unit {
        unknown.add(chunk)
    }

    func unknownChunks(): Array<PngUnknownChunk> {
        unknown.toArray()
    }
}

private func findZero(bytes: Array<Byte>, start: Int64): Int64 {
    var index = start
    while (index < bytes.size && bytes[index] != UInt8(0)) {
        index += 1
    }
    index
}

private func copyUntilZero(bytes: Array<Byte>, start: Int64): Array<Byte> {
    let end = findZero(bytes, start)
    copyByteRange(bytes, start, end - start)
}

private func validateIccProfile(profile: Array<Byte>, ihdr: PngIhdr, limits: PngReadLimits): Unit {
    if (profile.size < 132) {
        throw PngFormatException(InvalidIccProfile, -1, "ICC profile is shorter than 132 bytes")
    }
    let declaredLength = readUInt32Be(profile, 0)
    if (UInt64(declaredLength) > UInt64(limits.maxChunkBytes)) {
        throw PngFormatException(DecodeLimitExceeded, -1, "ICC profile exceeds configured chunk-byte limit")
    }
    if (Int64(declaredLength) != profile.size) {
        throw PngFormatException(InvalidIccProfile, -1, "ICC profile length does not match decompressed data")
    }
    if (profile[8] > UInt8(3) && (declaredLength & UInt32(3)) != UInt32(0)) {
        throw PngFormatException(InvalidIccProfile, -1, "ICC v4 profile length must be a multiple of four")
    }
    let tagCount = readUInt32Be(profile, 128)
    if (tagCount > UInt32(357_913_930) ||
        UInt64(declaredLength) < UInt64(132) + UInt64(tagCount) * UInt64(12)) {
        throw PngFormatException(InvalidIccProfile, -1, "ICC tag table is truncated")
    }
    if (readUInt32Be(profile, 64) >= UInt32(0xffff)) {
        throw PngFormatException(InvalidIccProfile, -1, "ICC rendering intent exceeds the 16-bit limit")
    }
    if (readUInt32Be(profile, 36) != UInt32(0x6163_7370)) {
        throw PngFormatException(InvalidIccProfile, -1, "ICC profile signature is not acsp")
    }

    let colorSpace = readUInt32Be(profile, 16)
    if (ihdr.colorType == Grayscale || ihdr.colorType == GrayscaleAlpha) {
        if (colorSpace != UInt32(0x4752_4159)) {
            throw PngFormatException(InvalidIccProfile, -1, "grayscale PNG requires a GRAY ICC profile")
        }
    } else if (colorSpace != UInt32(0x5247_4220)) {
        throw PngFormatException(InvalidIccProfile, -1, "color PNG requires an RGB ICC profile")
    }

    let profileClass = readUInt32Be(profile, 12)
    if (profileClass == UInt32(0x6162_7374) || profileClass == UInt32(0x6c69_6e6b)) {
        throw PngFormatException(InvalidIccProfile, -1, "ICC profile class cannot be embedded in a PNG")
    }
    let pcs = readUInt32Be(profile, 20)
    if (pcs != UInt32(0x5859_5a20) && pcs != UInt32(0x4c61_6220)) {
        throw PngFormatException(InvalidIccProfile, -1, "ICC PCS must be XYZ or Lab")
    }

    var index: UInt32 = UInt32(0)
    while (index < tagCount) {
        let offset = Int64(132) + Int64(index) * 12
        let tagStart = readUInt32Be(profile, offset + 4)
        let tagLength = readUInt32Be(profile, offset + 8)
        if (tagStart > declaredLength || tagLength > declaredLength - tagStart) {
            throw PngFormatException(InvalidIccProfile, offset, "ICC profile tag lies outside the profile")
        }
        index += UInt32(1)
    }
}

private func parseIccProfile(
    chunk: PngChunk,
    ihdr: PngIhdr,
    limits: PngReadLimits
): PngIccProfile {
    let data = chunk.payload()
    let keywordEnd = findZero(data, 0)
    if (keywordEnd < 1 || keywordEnd > 79) {
        throw PngFormatException(InvalidIccProfile, chunk.offset, "iCCP keyword length must be in 1..79")
    }
    if (keywordEnd + 2 >= data.size) {
        throw PngFormatException(InvalidIccProfile, chunk.offset, "iCCP compressed profile is truncated")
    }
    if (data[keywordEnd + 1] != UInt8(0)) {
        throw PngFormatException(InvalidIccProfile, chunk.offset, "iCCP compression method must be zero")
    }
    let compressed = copyByteRange(data, keywordEnd + 2, data.size - keywordEnd - 2)
    let profile = inflatePngZlibBounded(compressed, Int64(limits.maxChunkBytes))
    validateIccProfile(profile, ihdr, limits)
    PngIccProfile(copyByteRange(data, 0, keywordEnd), profile)
}

private func parseTextChunk(chunk: PngChunk, limits: PngReadLimits): PngTextEntry {
    let data = chunk.payload()
    if (chunk.isType(PNG_CHUNK_tEXt)) {
        if (data.size < 2) {
            throw PngFormatException(InvalidTextMetadata, chunk.offset, "tEXt length must be at least 2")
        }
        let keywordEnd = findZero(data, 0)
        if (keywordEnd == data.size) {
            return PngTextEntry(Latin1Uncompressed, data, [], [], [])
        }
        PngTextEntry(
            Latin1Uncompressed,
            copyByteRange(data, 0, keywordEnd),
            copyUntilZero(data, keywordEnd + 1),
            [],
            []
        )
    } else if (chunk.isType(PNG_CHUNK_zTXt)) {
        let keywordEnd = findZero(data, 0)
        if (keywordEnd < 1 || keywordEnd > 79) {
            throw PngFormatException(InvalidTextMetadata, chunk.offset, "zTXt keyword length must be in 1..79")
        }
        if (keywordEnd + 2 >= data.size) {
            throw PngFormatException(InvalidTextMetadata, chunk.offset, "zTXt compressed text is truncated")
        }
        if (data[keywordEnd + 1] != UInt8(0)) {
            throw PngFormatException(InvalidTextMetadata, chunk.offset, "zTXt compression method must be zero")
        }
        let prefixSize = keywordEnd + 2
        let maximum = Int64(limits.maxChunkBytes) - prefixSize - 1
        let inflated = inflatePngZlibBounded(
            copyByteRange(data, prefixSize, data.size - prefixSize),
            maximum
        )
        PngTextEntry(
            Latin1Compressed,
            copyByteRange(data, 0, keywordEnd),
            copyUntilZero(inflated, 0),
            [],
            []
        )
    } else {
        if (data.size < 6) {
            throw PngFormatException(InvalidTextMetadata, chunk.offset, "iTXt length must be at least 6")
        }
        let keywordEnd = findZero(data, 0)
        if (keywordEnd < 1 || keywordEnd > 79 || keywordEnd + 5 > data.size) {
            throw PngFormatException(InvalidTextMetadata, chunk.offset, "iTXt keyword or prefix is invalid")
        }
        let compressed = data[keywordEnd + 1] == UInt8(1)
        if (data[keywordEnd + 1] != UInt8(0) && data[keywordEnd + 1] != UInt8(1)) {
            throw PngFormatException(InvalidTextMetadata, chunk.offset, "iTXt compression flag must be zero or one")
        }
        if (compressed && data[keywordEnd + 2] != UInt8(0)) {
            throw PngFormatException(InvalidTextMetadata, chunk.offset, "compressed iTXt method must be zero")
        }

        let languageStart = keywordEnd + 3
        let languageEnd = findZero(data, languageStart)
        if (languageEnd >= data.size) {
            throw PngFormatException(InvalidTextMetadata, chunk.offset, "iTXt language tag is not terminated")
        }
        let translatedStart = languageEnd + 1
        let translatedEnd = findZero(data, translatedStart)
        if (translatedEnd >= data.size) {
            throw PngFormatException(InvalidTextMetadata, chunk.offset, "iTXt translated keyword is not terminated")
        }
        let textStart = translatedEnd + 1
        var text = Array<Byte>()
        var kind = Utf8Uncompressed
        if (compressed) {
            if (textStart >= data.size) {
                throw PngFormatException(InvalidTextMetadata, chunk.offset, "compressed iTXt text is missing")
            }
            let maximum = Int64(limits.maxChunkBytes) - textStart - 1
            let inflated = inflatePngZlibBounded(
                copyByteRange(data, textStart, data.size - textStart),
                maximum
            )
            text = copyUntilZero(inflated, 0)
            kind = Utf8Compressed
        } else {
            text = copyUntilZero(data, textStart)
        }
        PngTextEntry(
            kind,
            copyByteRange(data, 0, keywordEnd),
            text,
            copyByteRange(data, languageStart, languageEnd - languageStart),
            copyByteRange(data, translatedStart, translatedEnd - translatedStart)
        )
    }
}

private func parseModificationTime(chunk: PngChunk): PngModificationTime {
    if (chunk.length != UInt32(7)) {
        throw PngFormatException(InvalidTimeMetadata, chunk.offset, "tIME length must be 7")
    }
    let data = chunk.payload()
    if (data[2] == UInt8(0) || data[2] > UInt8(12) ||
        data[3] == UInt8(0) || data[3] > UInt8(31) ||
        data[4] > UInt8(23) || data[5] > UInt8(59) || data[6] > UInt8(60)) {
        throw PngFormatException(InvalidTimeMetadata, chunk.offset, "tIME contains an invalid calendar value")
    }
    PngModificationTime(readUInt16Be(data, 0), data[2], data[3], data[4], data[5], data[6])
}

func handleExtendedMetadataChunk(
    parsed: ParsedExtendedMetadata,
    chunk: PngChunk,
    ihdr: PngIhdr,
    seenPalette: Bool,
    seenIdat: Bool,
    limits: PngReadLimits
): Bool {
    if (chunk.isType(PNG_CHUNK_iCCP)) {
        if (seenPalette || seenIdat) {
            throw PngFormatException(MetadataOutOfOrder, chunk.offset, "iCCP must precede PLTE and IDAT")
        }
        if (parsed.hasIccProfile) {
            throw PngFormatException(DuplicateMetadata, chunk.offset, "PNG contains more than one iCCP chunk")
        }
        parsed.iccProfile = parseIccProfile(chunk, ihdr, limits)
        parsed.hasIccProfile = true
        return true
    }
    if (chunk.isType(PNG_CHUNK_tEXt) || chunk.isType(PNG_CHUNK_zTXt) || chunk.isType(PNG_CHUNK_iTXt)) {
        parsed.addText(parseTextChunk(chunk, limits))
        return true
    }
    if (chunk.isType(PNG_CHUNK_tIME)) {
        if (parsed.hasModificationTime) {
            throw PngFormatException(DuplicateMetadata, chunk.offset, "PNG contains more than one tIME chunk")
        }
        parsed.modificationTime = parseModificationTime(chunk)
        parsed.hasModificationTime = true
        return true
    }
    false
}

func unknownChunkLocation(seenPalette: Bool, seenIdat: Bool): PngUnknownChunkLocation {
    if (seenIdat) {
        AfterIdat
    } else if (seenPalette) {
        AfterPlte
    } else {
        AfterIhdr
    }
}

func shouldRetainUnknown(chunk: PngChunk, policy: PngUnknownChunkPolicy): Bool {
    match (policy) {
        case Discard => false
        case RetainAncillary => !isCriticalChunk(chunk.chunkType())
        case RetainAll => true
    }
}
