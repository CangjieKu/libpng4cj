package libpng4cj

public class PngReadRowInfo {
    public let width: UInt32
    public let bitDepth: UInt8
    public let colorType: PngColorType
    public let channels: UInt8
    public let pixelDepth: UInt16
    public let rowBytes: UInt64

    public init(width: UInt32, bitDepth: UInt8, colorType: PngColorType) {
        this.width = width
        this.bitDepth = bitDepth
        this.colorType = colorType
        channels = colorType.channels()
        pixelDepth = UInt16(bitDepth) * UInt16(channels)
        rowBytes = (UInt64(width) * UInt64(pixelDepth) + UInt64(7)) / UInt64(8)
    }

    public init(ihdr: PngIhdr) {
        width = ihdr.width
        bitDepth = ihdr.bitDepth
        colorType = ihdr.colorType
        channels = ihdr.channels
        pixelDepth = ihdr.pixelDepth
        rowBytes = ihdr.rowBytes
    }
}

public class PngReadTransformRow {
    public let info: PngReadRowInfo
    private let ownedRow: Array<Byte>

    init(info: PngReadRowInfo, row: Array<Byte>) {
        this.info = info
        ownedRow = row.clone()
    }

    public func row(): Array<Byte> {
        ownedRow.clone()
    }
}

func validatePngTransformRowLength(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): Unit {
    if (UInt64(row.size) != rowInfo.rowBytes) {
        throw PngFormatException(
            InvalidArgument,
            row.size,
            "PNG transform row length does not match row info"
        )
    }
}

private func pngGrayToRgbOutputInfo(rowInfo: PngReadRowInfo): PngReadRowInfo {
    let outputColorType = match (rowInfo.colorType) {
        case Grayscale => Truecolor
        case GrayscaleAlpha => TruecolorAlpha
        case _ => rowInfo.colorType
    }
    PngReadRowInfo(rowInfo.width, rowInfo.bitDepth, outputColorType)
}

private func pngDoGrayToRgb8(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): Array<Byte> {
    let width = Int64(rowInfo.width)
    if (rowInfo.colorType == Grayscale) {
        let output = Array<Byte>(width * 3, repeat: 0)
        var pixel: Int64 = 0
        while (pixel < width) {
            let gray = row[pixel]
            let outputOffset = pixel * 3
            output[outputOffset] = gray
            output[outputOffset + 1] = gray
            output[outputOffset + 2] = gray
            pixel += 1
        }
        return output
    }

    let output = Array<Byte>(width * 4, repeat: 0)
    var pixel: Int64 = 0
    while (pixel < width) {
        let sourceOffset = pixel * 2
        let outputOffset = pixel * 4
        let gray = row[sourceOffset]
        output[outputOffset] = gray
        output[outputOffset + 1] = gray
        output[outputOffset + 2] = gray
        output[outputOffset + 3] = row[sourceOffset + 1]
        pixel += 1
    }
    output
}

private func pngDoGrayToRgb16(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): Array<Byte> {
    let width = Int64(rowInfo.width)
    if (rowInfo.colorType == Grayscale) {
        let output = Array<Byte>(width * 6, repeat: 0)
        var pixel: Int64 = 0
        while (pixel < width) {
            let sourceOffset = pixel * 2
            let outputOffset = pixel * 6
            let high = row[sourceOffset]
            let low = row[sourceOffset + 1]
            output[outputOffset] = high
            output[outputOffset + 1] = low
            output[outputOffset + 2] = high
            output[outputOffset + 3] = low
            output[outputOffset + 4] = high
            output[outputOffset + 5] = low
            pixel += 1
        }
        return output
    }

    let output = Array<Byte>(width * 8, repeat: 0)
    var pixel: Int64 = 0
    while (pixel < width) {
        let sourceOffset = pixel * 4
        let outputOffset = pixel * 8
        let grayHigh = row[sourceOffset]
        let grayLow = row[sourceOffset + 1]
        output[outputOffset] = grayHigh
        output[outputOffset + 1] = grayLow
        output[outputOffset + 2] = grayHigh
        output[outputOffset + 3] = grayLow
        output[outputOffset + 4] = grayHigh
        output[outputOffset + 5] = grayLow
        output[outputOffset + 6] = row[sourceOffset + 2]
        output[outputOffset + 7] = row[sourceOffset + 3]
        pixel += 1
    }
    output
}

public func pngDoGrayToRgb(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (rowInfo.bitDepth < UInt8(8) ||
        (rowInfo.colorType != Grayscale && rowInfo.colorType != GrayscaleAlpha)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = if (rowInfo.bitDepth == UInt8(8)) {
        pngDoGrayToRgb8(rowInfo, row)
    } else {
        pngDoGrayToRgb16(rowInfo, row)
    }
    PngReadTransformRow(pngGrayToRgbOutputInfo(rowInfo), output)
}

public func applyInitializedPngGrayToRgbStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageGrayToRgb)) {
        return PngReadTransformRow(rowInfo, row)
    }
    pngDoGrayToRgb(rowInfo, row)
}
