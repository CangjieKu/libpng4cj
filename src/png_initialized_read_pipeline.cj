package libpng4cj

public class PngRgbToGrayRowResult {
    public let info: PngReadRowInfo
    public let hadNonGrayPixels: Bool
    private let ownedRow: Array<Byte>

    init(
        info: PngReadRowInfo,
        row: Array<Byte>,
        hadNonGrayPixels: Bool
    ) {
        this.info = info
        this.hadNonGrayPixels = hadNonGrayPixels
        ownedRow = row.clone()
    }

    public func row(): Array<Byte> {
        ownedRow.clone()
    }
}

public class PngInitializedReadRowResult {
    public let info: PngReadRowInfo
    public let hadNonGrayPixels: Bool
    private let ownedRow: Array<Byte>

    init(
        info: PngReadRowInfo,
        row: Array<Byte>,
        hadNonGrayPixels: Bool
    ) {
        this.info = info
        this.hadNonGrayPixels = hadNonGrayPixels
        ownedRow = row.clone()
    }

    public func row(): Array<Byte> {
        ownedRow.clone()
    }
}

public class PngInitializedReadRowsResult {
    public let info: PngReadRowInfo
    public let hadNonGrayPixels: Bool
    private let ownedRows: Array<Array<Byte>>

    init(
        info: PngReadRowInfo,
        rows: Array<Array<Byte>>,
        hadNonGrayPixels: Bool
    ) {
        this.info = info
        this.hadNonGrayPixels = hadNonGrayPixels
        ownedRows = Array<Array<Byte>>(rows.size, repeat: Array<Byte>())
        var index: Int64 = 0
        while (index < rows.size) {
            ownedRows[index] = rows[index].clone()
            index += 1
        }
    }

    public func rowCount(): Int64 {
        ownedRows.size
    }

    public func row(index: Int64): Array<Byte> {
        if (index < 0 || index >= ownedRows.size) {
            throw PngFormatException(
                InvalidArgument,
                index,
                "initialized PNG result row index is out of bounds"
            )
        }
        ownedRows[index].clone()
    }

    public func rows(): Array<Array<Byte>> {
        let output = Array<Array<Byte>>(
            ownedRows.size,
            repeat: Array<Byte>()
        )
        var index: Int64 = 0
        while (index < ownedRows.size) {
            output[index] = ownedRows[index].clone()
            index += 1
        }
        output
    }
}

private func pngRgbToGraySupported(rowInfo: PngReadRowInfo): Bool {
    let colorShape = (rowInfo.colorType == Truecolor &&
        rowInfo.channels == UInt8(3)) ||
        (rowInfo.colorType == TruecolorAlpha &&
        rowInfo.channels == UInt8(4))
    let sampleDepth = rowInfo.bitDepth == UInt8(8) ||
        rowInfo.bitDepth == UInt8(16)
    colorShape && sampleDepth && rowInfo.width > UInt32(0)
}

private func pngRgbToGrayOutputInfo(rowInfo: PngReadRowInfo): PngReadRowInfo {
    let outputType = if (rowInfo.colorType == TruecolorAlpha) {
        GrayscaleAlpha
    } else {
        Grayscale
    }
    PngReadRowInfo(rowInfo.width, rowInfo.bitDepth, outputType)
}

private func pngRgbToGrayMismatch(
    transform: PngRgbToGrayTransform,
    pixel: Int64
): Unit {
    if (transform.policy == RequireGray) {
        throw PngFormatException(
            RgbToGrayMismatch,
            pixel,
            "RGB-to-gray strict policy encountered a nongray pixel"
        )
    }
}

private func pngRgbToGray8Value(
    red: Byte,
    green: Byte,
    blue: Byte,
    transform: PngRgbToGrayTransform
): Byte {
    let weighted = UInt32(transform.redCoefficient) * UInt32(red) +
        UInt32(transform.greenCoefficient) * UInt32(green) +
        UInt32(transform.blueCoefficient) * UInt32(blue)
    UInt8(weighted >> 15)
}

private func pngRgbToGray16Value(
    red: UInt16,
    green: UInt16,
    blue: UInt16,
    transform: PngRgbToGrayTransform
): UInt16 {
    let weighted = UInt32(transform.redCoefficient) * UInt32(red) +
        UInt32(transform.greenCoefficient) * UInt32(green) +
        UInt32(transform.blueCoefficient) * UInt32(blue) + UInt32(16384)
    UInt16(weighted >> 15)
}

private func pngReadNetworkUInt16(row: Array<Byte>, offset: Int64): UInt16 {
    (UInt16(row[offset]) << 8) | UInt16(row[offset + 1])
}

private func pngWriteNetworkUInt16(
    output: Array<Byte>,
    offset: Int64,
    value: UInt16
): Unit {
    output[offset] = UInt8(value >> 8)
    output[offset + 1] = UInt8(value & UInt16(0xff))
}

private func pngDoRgbToGrayRow8(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    transform: PngRgbToGrayTransform
): PngRgbToGrayRowResult {
    let withAlpha = rowInfo.channels == UInt8(4)
    let sourceChannels = Int64(rowInfo.channels)
    let outputChannels = if (withAlpha) { Int64(2) } else { Int64(1) }
    let output = Array<Byte>(
        Int64(rowInfo.width) * outputChannels,
        repeat: 0
    )
    var hadNonGrayPixels = false
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let sourceOffset = pixel * sourceChannels
        let red = row[sourceOffset]
        let green = row[sourceOffset + 1]
        let blue = row[sourceOffset + 2]
        let equal = red == green && green == blue
        if (!equal) {
            hadNonGrayPixels = true
            pngRgbToGrayMismatch(transform, pixel)
        }
        let outputOffset = pixel * outputChannels
        output[outputOffset] = if (equal) {
            red
        } else {
            pngRgbToGray8Value(red, green, blue, transform)
        }
        if (withAlpha) {
            output[outputOffset + 1] = row[sourceOffset + 3]
        }
        pixel += 1
    }
    PngRgbToGrayRowResult(
        pngRgbToGrayOutputInfo(rowInfo),
        output,
        hadNonGrayPixels
    )
}

private func pngDoRgbToGrayRow16(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    transform: PngRgbToGrayTransform
): PngRgbToGrayRowResult {
    let withAlpha = rowInfo.channels == UInt8(4)
    let sourceChannels = Int64(rowInfo.channels)
    let outputChannels = if (withAlpha) { Int64(2) } else { Int64(1) }
    let output = Array<Byte>(
        Int64(rowInfo.width) * outputChannels * 2,
        repeat: 0
    )
    var hadNonGrayPixels = false
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let sourceOffset = pixel * sourceChannels * 2
        let red = pngReadNetworkUInt16(row, sourceOffset)
        let green = pngReadNetworkUInt16(row, sourceOffset + 2)
        let blue = pngReadNetworkUInt16(row, sourceOffset + 4)
        let equal = red == green && green == blue
        if (!equal) {
            hadNonGrayPixels = true
            pngRgbToGrayMismatch(transform, pixel)
        }
        let gray = if (equal) {
            red
        } else {
            pngRgbToGray16Value(red, green, blue, transform)
        }
        let outputOffset = pixel * outputChannels * 2
        pngWriteNetworkUInt16(output, outputOffset, gray)
        if (withAlpha) {
            output[outputOffset + 2] = row[sourceOffset + 6]
            output[outputOffset + 3] = row[sourceOffset + 7]
        }
        pixel += 1
    }
    PngRgbToGrayRowResult(
        pngRgbToGrayOutputInfo(rowInfo),
        output,
        hadNonGrayPixels
    )
}

public func pngDoRgbToGray(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    transform: PngRgbToGrayTransform
): PngRgbToGrayRowResult {
    validatePngTransformRowLength(rowInfo, row)
    if (!pngRgbToGraySupported(rowInfo)) {
        return PngRgbToGrayRowResult(rowInfo, row, false)
    }
    if (rowInfo.bitDepth == UInt8(8)) {
        return pngDoRgbToGrayRow8(rowInfo, row, transform)
    }
    pngDoRgbToGrayRow16(rowInfo, row, transform)
}

public func applyInitializedPngRgbToGrayStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngRgbToGrayRowResult {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStageRgbToGray)) {
        return PngRgbToGrayRowResult(rowInfo, row, false)
    }
    pngDoRgbToGray(rowInfo, row, initialization.rgbToGrayTransform())
}

public func applyInitializedPngReadStages(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngInitializedReadRowResult {
    let expanded = applyInitializedPngExpandStage(initialization, rowInfo, row)
    let stripped = applyInitializedPngStripAlphaStage(
        initialization, expanded.info, expanded.row()
    )
    let gray = applyInitializedPngRgbToGrayStage(
        initialization, stripped.info, stripped.row()
    )
    let grayToRgb = applyInitializedPngGrayToRgbStage(
        initialization, gray.info, gray.row()
    )
    let reduced = applyInitializedPng16To8Stages(
        initialization, grayToRgb.info, grayToRgb.row()
    )
    let quantized = applyInitializedPngQuantizeStage(
        initialization, reduced.info, reduced.row()
    )
    let expanded16 = applyInitializedPngExpand16Stage(
        initialization, quantized.info, quantized.row()
    )
    let invertedMono = applyInitializedPngInvertMonoStage(
        initialization, expanded16.info, expanded16.row()
    )
    let invertedAlpha = applyInitializedPngInvertAlphaStage(
        initialization, invertedMono.info, invertedMono.row()
    )
    let unshifted = applyInitializedPngUnshiftStage(
        initialization, invertedAlpha.info, invertedAlpha.row()
    )
    let unpacked = applyInitializedPngUnpackStage(
        initialization, unshifted.info, unshifted.row()
    )
    let bgr = applyInitializedPngBgrStage(
        initialization, unpacked.info, unpacked.row()
    )
    let filled = applyInitializedPngFillerStage(
        initialization, bgr.info, bgr.row()
    )
    let swappedAlpha = applyInitializedPngSwapAlphaAfterFillerStage(
        initialization,
        filled.info,
        filled.row(),
        filled.info.channels != bgr.info.channels
    )
    PngInitializedReadRowResult(
        swappedAlpha.info,
        swappedAlpha.row(),
        gray.hadNonGrayPixels
    )
}

private func validateInitializedRowsLimit(
    rowInfo: PngReadRowInfo,
    rowCount: Int64,
    limits: PngReadLimits
): Unit {
    let count = UInt64(rowCount)
    if (rowInfo.rowBytes > limits.maxTransformedBytes ||
        count > limits.maxTransformedBytes / rowInfo.rowBytes) {
        throw PngFormatException(
            DecodeLimitExceeded,
            -1,
            "initialized PNG rows exceed configured transformed-byte limit"
        )
    }
}

public func transformPngRowsInitialized(
    decoded: PngDecodedRows,
    state: PngReadTransformState,
    limits: PngReadLimits
): PngInitializedReadRowsResult {
    let initialization = initializePngReadTransformations(state, decoded)
    let sourceInfo = PngReadRowInfo(decoded.ihdr)
    let rows = Array<Array<Byte>>(
        decoded.rowCount(),
        repeat: Array<Byte>()
    )
    var outputInfo = sourceInfo
    var hadNonGrayPixels = false
    var index: Int64 = 0
    while (index < rows.size) {
        let transformed = applyInitializedPngReadStages(
            initialization,
            sourceInfo,
            decoded.row(index)
        )
        if (index == 0) {
            validateInitializedRowsLimit(
                transformed.info,
                decoded.rowCount(),
                limits
            )
        }
        outputInfo = transformed.info
        rows[index] = transformed.row()
        hadNonGrayPixels = hadNonGrayPixels || transformed.hadNonGrayPixels
        index += 1
    }
    PngInitializedReadRowsResult(outputInfo, rows, hadNonGrayPixels)
}

public func transformPngRowsInitialized(
    decoded: PngDecodedRows,
    state: PngReadTransformState
): PngInitializedReadRowsResult {
    transformPngRowsInitialized(decoded, state, PngReadLimits())
}
