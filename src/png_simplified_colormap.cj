package libpng4cj

public enum PngColormapFormat <: Equatable<PngColormapFormat> & ToString {
    | ColormapRgb8
    | ColormapBgr8
    | ColormapRgba8
    | ColormapArgb8
    | ColormapBgra8
    | ColormapAbgr8

    public operator func ==(right: PngColormapFormat): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngColormapFormat): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case ColormapRgb8 => Int64(0)
            case ColormapBgr8 => Int64(1)
            case ColormapRgba8 => Int64(2)
            case ColormapArgb8 => Int64(3)
            case ColormapBgra8 => Int64(4)
            case ColormapAbgr8 => Int64(5)
        }
    }

    public func channelCount(): UInt8 {
        match (this) {
            case ColormapRgb8 | ColormapBgr8 => UInt8(3)
            case _ => UInt8(4)
        }
    }

    public func hasAlpha(): Bool { channelCount() == UInt8(4) }

    public func toString(): String {
        match (this) {
            case ColormapRgb8 => "RGB8_COLORMAP"
            case ColormapBgr8 => "BGR8_COLORMAP"
            case ColormapRgba8 => "RGBA8_COLORMAP"
            case ColormapArgb8 => "ARGB8_COLORMAP"
            case ColormapBgra8 => "BGRA8_COLORMAP"
            case ColormapAbgr8 => "ABGR8_COLORMAP"
        }
    }
}

private func pngColormapPixelCount(width: UInt32, height: UInt32): Int64 {
    let count = UInt64(width) * UInt64(height)
    if (count == UInt64(0) || count > UInt64(Int64.Max)) {
        throw PngFormatException(
            DecodeLimitExceeded, -1,
            "simplified colormap pixel count exceeds Int64"
        )
    }
    Int64(count)
}

public class PngColormapImageBuffer {
    public let width: UInt32
    public let height: UInt32
    public let format: PngColormapFormat
    public let rowStride: Int64
    public let entryChannels: UInt8
    public let entryCount: UInt16
    private let ownedIndices: Array<Byte>
    private let ownedColormap: Array<Byte>

    public init(
        width: UInt32,
        height: UInt32,
        format: PngColormapFormat,
        indices: Array<Byte>,
        colormap: Array<Byte>
    ) {
        let pixels = pngColormapPixelCount(width, height)
        if (indices.size != pixels) {
            throw PngFormatException(
                InvalidArgument, -1,
                "simplified colormap index length does not match image shape"
            )
        }
        let channels = Int64(format.channelCount())
        if (colormap.size == Int64(0) || colormap.size % channels != Int64(0)) {
            throw PngFormatException(
                InvalidPalette, -1,
                "simplified colormap requires complete entry components"
            )
        }
        let entries = colormap.size / channels
        if (entries < Int64(1) || entries > Int64(256)) {
            throw PngFormatException(
                InvalidPalette, -1,
                "simplified colormap requires 1..256 entries"
            )
        }
        var index: Int64 = Int64(0)
        while (index < indices.size) {
            if (Int64(indices[index]) >= entries) {
                throw PngFormatException(
                    PaletteIndexOutOfRange, index,
                    "simplified colormap index is outside the entry table"
                )
            }
            index += Int64(1)
        }
        this.width = width
        this.height = height
        this.format = format
        rowStride = Int64(width)
        entryChannels = format.channelCount()
        entryCount = UInt16(entries)
        ownedIndices = indices.clone()
        ownedColormap = colormap.clone()
    }

    public func indexByteCount(): Int64 { ownedIndices.size }
    public func colormapByteCount(): Int64 { ownedColormap.size }
    public func indices(): Array<Byte> { ownedIndices.clone() }
    public func colormap(): Array<Byte> { ownedColormap.clone() }

    public func row(index: Int64): Array<Byte> {
        if (index < Int64(0) || index >= Int64(height)) {
            throw PngFormatException(
                InvalidArgument, index,
                "simplified colormap row index is out of bounds"
            )
        }
        copyByteRange(ownedIndices, index * rowStride, rowStride)
    }

    public func entry(index: Int64): Array<Byte> {
        if (index < Int64(0) || index >= Int64(entryCount)) {
            throw PngFormatException(
                InvalidArgument, index,
                "simplified colormap entry index is out of bounds"
            )
        }
        copyByteRange(
            ownedColormap,
            index * Int64(entryChannels),
            Int64(entryChannels)
        )
    }
}

private func pngColormapWriteEntry(
    colormap: Array<Byte>,
    entry: Int64,
    format: PngColormapFormat,
    red: UInt8,
    green: UInt8,
    blue: UInt8,
    alpha: UInt8
): Unit {
    let offset = entry * Int64(format.channelCount())
    match (format) {
        case ColormapRgb8 =>
            colormap[offset] = red
            colormap[offset + Int64(1)] = green
            colormap[offset + Int64(2)] = blue
        case ColormapBgr8 =>
            colormap[offset] = blue
            colormap[offset + Int64(1)] = green
            colormap[offset + Int64(2)] = red
        case ColormapRgba8 =>
            colormap[offset] = red
            colormap[offset + Int64(1)] = green
            colormap[offset + Int64(2)] = blue
            colormap[offset + Int64(3)] = alpha
        case ColormapArgb8 =>
            colormap[offset] = alpha
            colormap[offset + Int64(1)] = red
            colormap[offset + Int64(2)] = green
            colormap[offset + Int64(3)] = blue
        case ColormapBgra8 =>
            colormap[offset] = blue
            colormap[offset + Int64(1)] = green
            colormap[offset + Int64(2)] = red
            colormap[offset + Int64(3)] = alpha
        case ColormapAbgr8 =>
            colormap[offset] = alpha
            colormap[offset + Int64(1)] = blue
            colormap[offset + Int64(2)] = green
            colormap[offset + Int64(3)] = red
    }
}

private func pngColormapReadEntry(
    colormap: Array<Byte>,
    entry: Int64,
    format: PngColormapFormat
): (UInt8, UInt8, UInt8, UInt8) {
    let offset = entry * Int64(format.channelCount())
    match (format) {
        case ColormapRgb8 =>
            (colormap[offset], colormap[offset + Int64(1)],
                colormap[offset + Int64(2)], UInt8(255))
        case ColormapBgr8 =>
            (colormap[offset + Int64(2)], colormap[offset + Int64(1)],
                colormap[offset], UInt8(255))
        case ColormapRgba8 =>
            (colormap[offset], colormap[offset + Int64(1)],
                colormap[offset + Int64(2)], colormap[offset + Int64(3)])
        case ColormapArgb8 =>
            (colormap[offset + Int64(1)], colormap[offset + Int64(2)],
                colormap[offset + Int64(3)], colormap[offset])
        case ColormapBgra8 =>
            (colormap[offset + Int64(2)], colormap[offset + Int64(1)],
                colormap[offset], colormap[offset + Int64(3)])
        case ColormapAbgr8 =>
            (colormap[offset + Int64(3)], colormap[offset + Int64(2)],
                colormap[offset + Int64(1)], colormap[offset])
    }
}

private func pngColormapDiv51(value: UInt8): UInt8 {
    UInt8((UInt32(value) * UInt32(5) + UInt32(130)) >> UInt32(8))
}

private func pngColormapRgbIndex(red: UInt8, green: UInt8, blue: UInt8): UInt8 {
    UInt8(
        UInt32(6) * (
            UInt32(6) * UInt32(pngColormapDiv51(red)) +
            UInt32(pngColormapDiv51(green))
        ) + UInt32(pngColormapDiv51(blue))
    )
}

private func pngColormapCompose(
    foreground: UInt8,
    alpha: UInt8,
    background: UInt8
): UInt8 {
    let numerator =
        UInt32(foreground) * UInt32(alpha) +
        UInt32(background) * (UInt32(255) - UInt32(alpha)) + UInt32(127)
    UInt8(numerator / UInt32(255))
}

private func pngColormapGrayMap(
    format: PngColormapFormat,
    alphaAt: Int64
): Array<Byte> {
    let output = Array<Byte>(
        Int64(256) * Int64(format.channelCount()), repeat: UInt8(0)
    )
    var entry: Int64 = Int64(0)
    while (entry < Int64(256)) {
        let value = UInt8(entry)
        pngColormapWriteEntry(
            output, entry, format, value, value, value,
            if (entry == alphaAt) { UInt8(0) } else { UInt8(255) }
        )
        entry += Int64(1)
    }
    output
}

private func pngColormapRgbCube(format: PngColormapFormat): Array<Byte> {
    let output = Array<Byte>(
        Int64(216) * Int64(format.channelCount()), repeat: UInt8(0)
    )
    var entry: Int64 = Int64(0)
    var red: UInt8 = UInt8(0)
    while (red < UInt8(6)) {
        var green: UInt8 = UInt8(0)
        while (green < UInt8(6)) {
            var blue: UInt8 = UInt8(0)
            while (blue < UInt8(6)) {
                pngColormapWriteEntry(
                    output, entry, format,
                    red * UInt8(51), green * UInt8(51), blue * UInt8(51),
                    UInt8(255)
                )
                entry += Int64(1)
                blue += UInt8(1)
            }
            green += UInt8(1)
        }
        red += UInt8(1)
    }
    output
}

private func pngColormapRgbAlphaMap(
    format: PngColormapFormat
): Array<Byte> {
    let output = Array<Byte>(
        Int64(244) * Int64(format.channelCount()), repeat: UInt8(0)
    )
    let cube = pngColormapRgbCube(format)
    var index: Int64 = Int64(0)
    while (index < cube.size) {
        output[index] = cube[index]
        index += Int64(1)
    }
    pngColormapWriteEntry(
        output, Int64(216), format,
        UInt8(255), UInt8(255), UInt8(255), UInt8(0)
    )
    var entry: Int64 = Int64(217)
    let levels: Array<UInt8> = [UInt8(0), UInt8(127), UInt8(255)]
    for (red in levels) {
        for (green in levels) {
            for (blue in levels) {
                pngColormapWriteEntry(
                    output, entry, format, red, green, blue, UInt8(128)
                )
                entry += Int64(1)
            }
        }
    }
    output
}

private func pngColormapRgbBackgroundMap(
    format: PngColormapFormat,
    background: PngSrgbColor8
): Array<Byte> {
    let output = Array<Byte>(
        Int64(244) * Int64(format.channelCount()), repeat: UInt8(0)
    )
    let cube = pngColormapRgbCube(format)
    var index: Int64 = Int64(0)
    while (index < cube.size) {
        output[index] = cube[index]
        index += Int64(1)
    }
    pngColormapWriteEntry(
        output, Int64(216), format,
        background.red, background.green, background.blue, UInt8(255)
    )
    var entry: Int64 = Int64(217)
    let levels: Array<UInt8> = [UInt8(0), UInt8(127), UInt8(255)]
    for (red in levels) {
        for (green in levels) {
            for (blue in levels) {
                pngColormapWriteEntry(
                    output, entry, format,
                    pngColormapCompose(red, UInt8(128), background.red),
                    pngColormapCompose(green, UInt8(128), background.green),
                    pngColormapCompose(blue, UInt8(128), background.blue),
                    UInt8(255)
                )
                entry += Int64(1)
            }
        }
    }
    output
}

private func pngColormapGaMap(
    format: PngColormapFormat,
    background: PngSrgbColor8,
    removeAlpha: Bool
): Array<Byte> {
    let output = Array<Byte>(
        Int64(256) * Int64(format.channelCount()), repeat: UInt8(0)
    )
    var entry: Int64 = Int64(0)
    while (entry < Int64(231)) {
        let gray = UInt8(
            (UInt32(entry) * UInt32(256) + UInt32(115)) / UInt32(231)
        )
        pngColormapWriteEntry(
            output, entry, format, gray, gray, gray, UInt8(255)
        )
        entry += Int64(1)
    }
    pngColormapWriteEntry(
        output, entry, format,
        if (removeAlpha) { background.red } else { UInt8(255) },
        if (removeAlpha) { background.green } else { UInt8(255) },
        if (removeAlpha) { background.blue } else { UInt8(255) },
        if (removeAlpha) { UInt8(255) } else { UInt8(0) }
    )
    entry += Int64(1)
    var alphaLevel: UInt8 = UInt8(1)
    while (alphaLevel < UInt8(5)) {
        var grayLevel: UInt8 = UInt8(0)
        while (grayLevel < UInt8(6)) {
            let gray = grayLevel * UInt8(51)
            let alpha = alphaLevel * UInt8(51)
            pngColormapWriteEntry(
                output, entry, format,
                if (removeAlpha) {
                    pngColormapCompose(gray, alpha, background.red)
                } else { gray },
                if (removeAlpha) {
                    pngColormapCompose(gray, alpha, background.green)
                } else { gray },
                if (removeAlpha) {
                    pngColormapCompose(gray, alpha, background.blue)
                } else { gray },
                if (removeAlpha) { UInt8(255) } else { alpha }
            )
            entry += Int64(1)
            grayLevel += UInt8(1)
        }
        alphaLevel += UInt8(1)
    }
    output
}

private func pngColormapGaIndex(gray: UInt8, alpha: UInt8): UInt8 {
    if (alpha > UInt8(229)) {
        return UInt8(
            (UInt32(231) * UInt32(gray) + UInt32(128)) >> UInt32(8)
        )
    }
    if (alpha < UInt8(26)) { return UInt8(231) }
    UInt8(
        UInt32(226) + UInt32(6) * UInt32(pngColormapDiv51(alpha)) +
        UInt32(pngColormapDiv51(gray))
    )
}

private func pngColormapRgbAlphaIndex(
    red: UInt8,
    green: UInt8,
    blue: UInt8,
    alpha: UInt8
): UInt8 {
    if (alpha >= UInt8(196)) {
        return pngColormapRgbIndex(red, green, blue)
    }
    if (alpha < UInt8(64)) { return UInt8(216) }
    var index: UInt16 = UInt16(217)
    if ((red & UInt8(0x80)) != UInt8(0)) { index += UInt16(9) }
    if ((red & UInt8(0x40)) != UInt8(0)) { index += UInt16(9) }
    if ((green & UInt8(0x80)) != UInt8(0)) { index += UInt16(3) }
    if ((green & UInt8(0x40)) != UInt8(0)) { index += UInt16(3) }
    if ((blue & UInt8(0x80)) != UInt8(0)) { index += UInt16(1) }
    if ((blue & UInt8(0x40)) != UInt8(0)) { index += UInt16(1) }
    UInt8(index)
}

private func pngColormapPackedIndex(
    row: Array<Byte>,
    pixel: UInt32,
    bitDepth: UInt8
): UInt8 {
    if (bitDepth == UInt8(8)) { return row[Int64(pixel)] }
    let bitOffset = UInt64(pixel) * UInt64(bitDepth)
    let sourceOffset = Int64(bitOffset / UInt64(8))
    let shift = UInt32(8) - UInt32(bitDepth) -
        UInt32(bitOffset % UInt64(8))
    let mask = (UInt32(1) << UInt32(bitDepth)) - UInt32(1)
    UInt8((UInt32(row[sourceOffset]) >> shift) & mask)
}

private func pngColormapDirectIndexed(
    decoded: PngDecodedRows,
    format: PngColormapFormat,
    background: PngSrgbColor8
): PngColormapImageBuffer {
    let entries = decoded.metadata.paletteEntryCount()
    let colormap = Array<Byte>(
        entries * Int64(format.channelCount()), repeat: UInt8(0)
    )
    var entry: Int64 = Int64(0)
    while (entry < entries) {
        let rgb = decoded.metadata.paletteEntry(entry)
        let alpha = decoded.metadata.paletteAlphaAt(entry)
        let red = if (format.hasAlpha()) {
            rgb[0]
        } else { pngColormapCompose(rgb[0], alpha, background.red) }
        let green = if (format.hasAlpha()) {
            rgb[1]
        } else { pngColormapCompose(rgb[1], alpha, background.green) }
        let blue = if (format.hasAlpha()) {
            rgb[2]
        } else { pngColormapCompose(rgb[2], alpha, background.blue) }
        pngColormapWriteEntry(
            colormap, entry, format, red, green, blue,
            if (format.hasAlpha()) { alpha } else { UInt8(255) }
        )
        entry += Int64(1)
    }
    let indices = Array<Byte>(
        pngColormapPixelCount(decoded.ihdr.width, decoded.ihdr.height),
        repeat: UInt8(0)
    )
    var output: Int64 = Int64(0)
    var rowIndex: Int64 = Int64(0)
    while (rowIndex < decoded.rowCount()) {
        let row = decoded.row(rowIndex)
        var pixel: UInt32 = UInt32(0)
        while (pixel < decoded.ihdr.width) {
            let index = pngColormapPackedIndex(
                row, pixel, decoded.ihdr.bitDepth
            )
            if (Int64(index) >= entries) {
                throw PngFormatException(
                    PaletteIndexOutOfRange, rowIndex,
                    "indexed PNG references an entry outside PLTE"
                )
            }
            indices[output] = index
            output += Int64(1)
            pixel += UInt32(1)
        }
        rowIndex += Int64(1)
    }
    PngColormapImageBuffer(
        decoded.ihdr.width, decoded.ihdr.height, format, indices, colormap
    )
}

private func pngColormapChargeResult(
    width: UInt32,
    height: UInt32,
    colormapBytes: Int64,
    limits: PngReadLimits
): Unit {
    let pixels = UInt64(pngColormapPixelCount(width, height))
    let mapBytes = UInt64(colormapBytes)
    if (pixels > limits.maxTransformedBytes ||
        mapBytes > limits.maxTransformedBytes - pixels) {
        throw PngFormatException(
            DecodeLimitExceeded, -1,
            "simplified colormap result exceeds transformed-byte limit"
        )
    }
}

func pngImageConvertColormap(
    bytes: Array<Byte>,
    limits: PngReadLimits,
    format: PngColormapFormat,
    background: PngSrgbColor8
): PngColormapImageBuffer {
    let decoded = decodePng(bytes, limits)
    if (decoded.ihdr.colorType == Indexed) {
        let direct = pngColormapDirectIndexed(decoded, format, background)
        pngColormapChargeResult(
            direct.width, direct.height, direct.colormapByteCount(), limits
        )
        return direct
    }
    let rgba = transformPngRowsToRgba8(decoded, limits, Scale)
    let semanticAlpha =
        decoded.ihdr.colorType == GrayscaleAlpha ||
        decoded.ihdr.colorType == TruecolorAlpha ||
        decoded.metadata.hasTransparency
    let grayscale =
        decoded.ihdr.colorType == Grayscale ||
        decoded.ihdr.colorType == GrayscaleAlpha
    let removeAlpha = semanticAlpha && !format.hasAlpha()
    let backgroundIsGray =
        background.red == background.green && background.green == background.blue
    var colormap: Array<Byte>
    var mode: UInt8
    if (grayscale && semanticAlpha && format.hasAlpha()) {
        colormap = pngColormapGaMap(format, background, false)
        mode = UInt8(1)
    } else if (grayscale && semanticAlpha && removeAlpha && !backgroundIsGray) {
        colormap = pngColormapGaMap(format, background, true)
        mode = UInt8(1)
    } else if (grayscale) {
        colormap = pngColormapGrayMap(format, Int64(-1))
        mode = UInt8(0)
    } else if (semanticAlpha && format.hasAlpha()) {
        colormap = pngColormapRgbAlphaMap(format)
        mode = UInt8(3)
    } else if (semanticAlpha && removeAlpha) {
        let cubeIndex = Int64(pngColormapRgbIndex(
            background.red, background.green, background.blue
        ))
        let cube = pngColormapRgbCube(format)
        let (cubeRed, cubeGreen, cubeBlue, _) =
            pngColormapReadEntry(cube, cubeIndex, format)
        if (cubeRed == background.red && cubeGreen == background.green &&
            cubeBlue == background.blue) {
            colormap = cube
            mode = UInt8(2)
        } else {
            colormap = pngColormapRgbBackgroundMap(format, background)
            mode = UInt8(3)
        }
    } else {
        colormap = pngColormapRgbCube(format)
        mode = UInt8(2)
    }
    pngColormapChargeResult(
        rgba.ihdr.width, UInt32(rgba.rowCount()), colormap.size, limits
    )
    let indices = Array<Byte>(
        pngColormapPixelCount(rgba.ihdr.width, UInt32(rgba.rowCount())),
        repeat: UInt8(0)
    )
    var output: Int64 = Int64(0)
    var rowIndex: Int64 = Int64(0)
    while (rowIndex < rgba.rowCount()) {
        let row = rgba.row(rowIndex)
        var offset: Int64 = Int64(0)
        while (offset < row.size) {
            let red = row[offset]
            let green = row[offset + Int64(1)]
            let blue = row[offset + Int64(2)]
            let alpha = row[offset + Int64(3)]
            indices[output] = if (mode == UInt8(0)) {
                if (removeAlpha) {
                    pngColormapCompose(red, alpha, background.red)
                } else { red }
            } else if (mode == UInt8(1)) {
                pngColormapGaIndex(red, alpha)
            } else if (mode == UInt8(2)) {
                let mappedRed = if (removeAlpha) {
                    pngColormapCompose(red, alpha, background.red)
                } else { red }
                let mappedGreen = if (removeAlpha) {
                    pngColormapCompose(green, alpha, background.green)
                } else { green }
                let mappedBlue = if (removeAlpha) {
                    pngColormapCompose(blue, alpha, background.blue)
                } else { blue }
                pngColormapRgbIndex(mappedRed, mappedGreen, mappedBlue)
            } else {
                pngColormapRgbAlphaIndex(red, green, blue, alpha)
            }
            output += Int64(1)
            offset += Int64(4)
        }
        rowIndex += Int64(1)
    }
    PngColormapImageBuffer(
        rgba.ihdr.width, UInt32(rgba.rowCount()), format, indices, colormap
    )
}

private func pngColormapWriteBitDepth(entries: UInt16): UInt8 {
    if (entries <= UInt16(2)) { UInt8(1) }
    else if (entries <= UInt16(4)) { UInt8(2) }
    else if (entries <= UInt16(16)) { UInt8(4) }
    else { UInt8(8) }
}

private func pngColormapPackedRows(
    image: PngColormapImageBuffer,
    bitDepth: UInt8
): Array<Array<Byte>> {
    let rowBytes = Int64(
        (UInt64(image.width) * UInt64(bitDepth) + UInt64(7)) / UInt64(8)
    )
    let rows = Array<Array<Byte>>(Int64(image.height), repeat: Array<Byte>())
    var rowIndex: Int64 = Int64(0)
    while (rowIndex < rows.size) {
        let source = image.row(rowIndex)
        if (bitDepth == UInt8(8)) {
            rows[rowIndex] = source
        } else {
            let packed = Array<Byte>(rowBytes, repeat: UInt8(0))
            var pixel: Int64 = Int64(0)
            while (pixel < source.size) {
                let bitOffset = UInt64(pixel) * UInt64(bitDepth)
                let target = Int64(bitOffset / UInt64(8))
                let shift = UInt32(8) - UInt32(bitDepth) -
                    UInt32(bitOffset % UInt64(8))
                packed[target] |= UInt8(UInt32(source[pixel]) << shift)
                pixel += Int64(1)
            }
            rows[rowIndex] = packed
        }
        rowIndex += Int64(1)
    }
    rows
}

public func writePngColormapImageToMemory(
    image: PngColormapImageBuffer,
    metadata: PngWriteMetadata,
    controls: PngWriteControlState,
    interlaceMethod: PngInterlaceMethod,
    limits: PngWriteLimits
): Array<Byte> {
    if (metadata.hasTransparencyValue) {
        throw PngFormatException(
            InvalidArgument, -1,
            "simplified colormap writing derives tRNS from the colormap"
        )
    }
    let palette = Array<Byte>(
        Int64(image.entryCount) * Int64(3), repeat: UInt8(0)
    )
    let alpha = Array<Byte>(Int64(image.entryCount), repeat: UInt8(255))
    var entry: Int64 = Int64(0)
    var lastTransparent: Int64 = Int64(-1)
    let colormap = image.colormap()
    while (entry < Int64(image.entryCount)) {
        let (red, green, blue, valueAlpha) =
            pngColormapReadEntry(colormap, entry, image.format)
        palette[entry * Int64(3)] = red
        palette[entry * Int64(3) + Int64(1)] = green
        palette[entry * Int64(3) + Int64(2)] = blue
        alpha[entry] = valueAlpha
        if (valueAlpha != UInt8(255)) { lastTransparent = entry }
        entry += Int64(1)
    }
    let writeMetadata = PngWriteMetadata(metadata)
    if (lastTransparent >= Int64(0)) {
        writeMetadata.setTransparency(
            PngWriteTransparency(
                copyByteRange(alpha, Int64(0), lastTransparent + Int64(1))
            )
        )
    }
    let bitDepth = pngColormapWriteBitDepth(image.entryCount)
    PngWriteSession(
        image.width,
        image.height,
        bitDepth,
        Indexed,
        interlaceMethod,
        palette,
        writeMetadata,
        controls,
        limits
    ).write(pngColormapPackedRows(image, bitDepth))
}

public func writePngColormapImageToMemory(
    image: PngColormapImageBuffer,
    interlaceMethod: PngInterlaceMethod
): Array<Byte> {
    writePngColormapImageToMemory(
        image,
        PngWriteMetadata(),
        PngWriteControlState(),
        interlaceMethod,
        PngWriteLimits()
    )
}

public func writePngColormapImageToMemory(
    image: PngColormapImageBuffer
): Array<Byte> {
    writePngColormapImageToMemory(image, None)
}
