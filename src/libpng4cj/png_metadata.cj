package libpng4cj

class ParsedPngTransparency {
    let present: Bool
    let paletteAlpha: Array<Byte>
    let gray: UInt16
    let red: UInt16
    let green: UInt16
    let blue: UInt16

    init() {
        present = false
        paletteAlpha = Array<Byte>()
        gray = UInt16(0)
        red = UInt16(0)
        green = UInt16(0)
        blue = UInt16(0)
    }

    init(alpha: Array<Byte>) {
        present = true
        paletteAlpha = alpha.clone()
        gray = UInt16(0)
        red = UInt16(0)
        green = UInt16(0)
        blue = UInt16(0)
    }

    init(gray: UInt16) {
        present = true
        paletteAlpha = Array<Byte>()
        this.gray = gray
        red = UInt16(0)
        green = UInt16(0)
        blue = UInt16(0)
    }

    init(red: UInt16, green: UInt16, blue: UInt16) {
        present = true
        paletteAlpha = Array<Byte>()
        gray = UInt16(0)
        this.red = red
        this.green = green
        this.blue = blue
    }
}

public class PngReadMetadata {
    public let hasPalette: Bool
    public let hasTransparency: Bool
    public let transparentGray: UInt16
    public let transparentRed: UInt16
    public let transparentGreen: UInt16
    public let transparentBlue: UInt16
    private let ownedPalette: Array<Byte>
    private let ownedPaletteAlpha: Array<Byte>

    init(palette: Array<Byte>, transparency: ParsedPngTransparency) {
        ownedPalette = palette.clone()
        ownedPaletteAlpha = transparency.paletteAlpha.clone()
        hasPalette = ownedPalette.size != 0
        hasTransparency = transparency.present
        transparentGray = transparency.gray
        transparentRed = transparency.red
        transparentGreen = transparency.green
        transparentBlue = transparency.blue
    }

    public func palette(): Array<Byte> {
        ownedPalette.clone()
    }

    public func paletteAlpha(): Array<Byte> {
        ownedPaletteAlpha.clone()
    }

    public func paletteEntryCount(): Int64 {
        ownedPalette.size / 3
    }

    private func validatePaletteIndex(index: Int64): Unit {
        if (index < 0 || index >= paletteEntryCount()) {
            throw PngFormatException(
                PaletteIndexOutOfRange,
                index,
                "PNG palette index is outside the declared PLTE"
            )
        }
    }

    public func paletteEntry(index: Int64): Array<Byte> {
        validatePaletteIndex(index)
        copyByteRange(ownedPalette, index * 3, 3)
    }

    func paletteRed(index: Int64): UInt8 {
        validatePaletteIndex(index)
        ownedPalette[index * 3]
    }

    func paletteGreen(index: Int64): UInt8 {
        validatePaletteIndex(index)
        ownedPalette[index * 3 + 1]
    }

    func paletteBlue(index: Int64): UInt8 {
        validatePaletteIndex(index)
        ownedPalette[index * 3 + 2]
    }

    public func paletteAlphaAt(index: Int64): UInt8 {
        validatePaletteIndex(index)
        if (index < ownedPaletteAlpha.size) {
            ownedPaletteAlpha[index]
        } else {
            UInt8(0xff)
        }
    }
}

func parsePngTransparencyChunk(
    chunk: PngChunk,
    ihdr: PngIhdr,
    palette: Array<Byte>
): ParsedPngTransparency {
    let data = chunk.payload()
    match (ihdr.colorType) {
        case Grayscale =>
            if (chunk.length != UInt32(2)) {
                throw PngFormatException(
                    InvalidTransparency,
                    chunk.offset,
                    "grayscale tRNS length must be 2"
                )
            }
            ParsedPngTransparency(readUInt16Be(data, 0))
        case Truecolor =>
            if (chunk.length != UInt32(6)) {
                throw PngFormatException(
                    InvalidTransparency,
                    chunk.offset,
                    "truecolor tRNS length must be 6"
                )
            }
            ParsedPngTransparency(
                readUInt16Be(data, 0),
                readUInt16Be(data, 2),
                readUInt16Be(data, 4)
            )
        case Indexed =>
            let paletteEntries = palette.size / 3
            if (paletteEntries == 0) {
                throw PngFormatException(
                    InvalidTransparency,
                    chunk.offset,
                    "indexed tRNS requires PLTE first"
                )
            }
            if (data.size == 0 || data.size > paletteEntries) {
                throw PngFormatException(
                    InvalidTransparency,
                    chunk.offset,
                    "indexed tRNS must contain 1..PLTE-entry-count alpha values"
                )
            }
            ParsedPngTransparency(data)
        case GrayscaleAlpha =>
            throw PngFormatException(
                InvalidTransparency,
                chunk.offset,
                "tRNS is not allowed for grayscale-alpha PNG images"
            )
        case TruecolorAlpha =>
            throw PngFormatException(
                InvalidTransparency,
                chunk.offset,
                "tRNS is not allowed for truecolor-alpha PNG images"
            )
    }
}
