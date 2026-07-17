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
    public let maximumPaletteIndex: Int64
    public let hasInvalidPaletteIndex: Bool
    private let ownedRow: Array<Byte>

    init(
        info: PngReadRowInfo,
        row: Array<Byte>,
        hadNonGrayPixels: Bool,
        maximumPaletteIndex: Int64,
        hasInvalidPaletteIndex: Bool
    ) {
        this.info = info
        this.hadNonGrayPixels = hadNonGrayPixels
        this.maximumPaletteIndex = maximumPaletteIndex
        this.hasInvalidPaletteIndex = hasInvalidPaletteIndex
        ownedRow = row.clone()
    }

    public func row(): Array<Byte> {
        ownedRow.clone()
    }
}

public class PngInitializedReadRowsResult {
    public let info: PngReadRowInfo
    public let hadNonGrayPixels: Bool
    public let maximumPaletteIndex: Int64
    public let hasInvalidPaletteIndex: Bool
    private let ownedRows: Array<Array<Byte>>

    init(
        info: PngReadRowInfo,
        rows: Array<Array<Byte>>,
        hadNonGrayPixels: Bool,
        maximumPaletteIndex: Int64,
        hasInvalidPaletteIndex: Bool
    ) {
        this.info = info
        this.hadNonGrayPixels = hadNonGrayPixels
        this.maximumPaletteIndex = maximumPaletteIndex
        this.hasInvalidPaletteIndex = hasInvalidPaletteIndex
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

private func pngRgbToGrayGamma8Value(
    red: Byte,
    green: Byte,
    blue: Byte,
    transform: PngRgbToGrayTransform,
    toLinear: PngGamma8BitTable,
    fromLinear: PngGamma8BitTable
): Byte {
    let linearRed = toLinear.value(red)
    let linearGreen = toLinear.value(green)
    let linearBlue = toLinear.value(blue)
    let weighted = UInt32(transform.redCoefficient) * UInt32(linearRed) +
        UInt32(transform.greenCoefficient) * UInt32(linearGreen) +
        UInt32(transform.blueCoefficient) * UInt32(linearBlue) + UInt32(16384)
    fromLinear.value(UInt8(weighted >> 15))
}

private func pngRgbToGrayGamma16Value(
    red: UInt16,
    green: UInt16,
    blue: UInt16,
    transform: PngRgbToGrayTransform,
    toLinear: PngGamma16BitTable,
    fromLinear: PngGamma16BitTable
): UInt16 {
    let linearRed = toLinear.value(red)
    let linearGreen = toLinear.value(green)
    let linearBlue = toLinear.value(blue)
    let weighted = UInt64(transform.redCoefficient) * UInt64(linearRed) +
        UInt64(transform.greenCoefficient) * UInt64(linearGreen) +
        UInt64(transform.blueCoefficient) * UInt64(linearBlue) + UInt64(16384)
    fromLinear.value(UInt16(weighted >> 15))
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

private func pngDoRgbToGrayGammaRow8(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    transform: PngRgbToGrayTransform,
    tables: PngGamma8BitTables
): PngRgbToGrayRowResult {
    let withAlpha = rowInfo.channels == UInt8(4)
    let sourceChannels = Int64(rowInfo.channels)
    let outputChannels = if (withAlpha) { Int64(2) } else { Int64(1) }
    let output = Array<Byte>(
        Int64(rowInfo.width) * outputChannels,
        repeat: 0
    )
    let direct = tables.direct()
    let toLinear = tables.toLinear()
    let fromLinear = tables.fromLinear()
    var hadNonGrayPixels = false
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let sourceOffset = pixel * sourceChannels
        let red = row[sourceOffset]
        let green = row[sourceOffset + 1]
        let blue = row[sourceOffset + 2]
        let equal = red == green && red == blue
        if (!equal) {
            hadNonGrayPixels = true
            pngRgbToGrayMismatch(transform, pixel)
        }
        let outputOffset = pixel * outputChannels
        output[outputOffset] = if (equal) {
            direct.value(red)
        } else {
            pngRgbToGrayGamma8Value(
                red, green, blue, transform, toLinear, fromLinear
            )
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

private func pngDoRgbToGrayGammaRow16(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    transform: PngRgbToGrayTransform,
    tables: PngGamma16BitTables
): PngRgbToGrayRowResult {
    let withAlpha = rowInfo.channels == UInt8(4)
    let sourceChannels = Int64(rowInfo.channels)
    let outputChannels = if (withAlpha) { Int64(2) } else { Int64(1) }
    let output = Array<Byte>(
        Int64(rowInfo.width) * outputChannels * 2,
        repeat: 0
    )
    let direct = tables.direct()
    let toLinear = tables.toLinear()
    let fromLinear = tables.fromLinear()
    var hadNonGrayPixels = false
    var pixel: Int64 = 0
    while (pixel < Int64(rowInfo.width)) {
        let sourceOffset = pixel * sourceChannels * 2
        let red = pngReadNetworkUInt16(row, sourceOffset)
        let green = pngReadNetworkUInt16(row, sourceOffset + 2)
        let blue = pngReadNetworkUInt16(row, sourceOffset + 4)
        let equal = red == green && red == blue
        if (!equal) {
            hadNonGrayPixels = true
            pngRgbToGrayMismatch(transform, pixel)
        }
        let gray = if (equal) {
            direct.value(red)
        } else {
            pngRgbToGrayGamma16Value(
                red, green, blue, transform, toLinear, fromLinear
            )
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
    if (!pngRgbToGraySupported(rowInfo)) {
        return PngRgbToGrayRowResult(rowInfo, row, false)
    }
    let transform = initialization.rgbToGrayTransform()
    if (rowInfo.bitDepth == UInt8(8) &&
        initialization.gamma8BitLinearTablesBuilt()) {
        return pngDoRgbToGrayGammaRow8(
            rowInfo,
            row,
            transform,
            initialization.gamma8BitTables()
        )
    }
    if (rowInfo.bitDepth == UInt8(16) &&
        initialization.gamma16BitLinearTablesBuilt()) {
        return pngDoRgbToGrayGammaRow16(
            rowInfo,
            row,
            transform,
            initialization.gamma16BitTables()
        )
    }
    pngDoRgbToGray(rowInfo, row, transform)
}

private func applyInitializedPngReadStagesWithPaletteMaximum(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    currentMaximumPaletteIndex: Int64,
    context: PngReadUserTransformContext
): PngInitializedReadRowResult {
    let expanded = applyInitializedPngExpandStage(initialization, rowInfo, row)
    let stripped = applyInitializedPngStripAlphaStage(
        initialization, expanded.info, expanded.row()
    )
    let gray = applyInitializedPngRgbToGrayStage(
        initialization, stripped.info, stripped.row()
    )
    let grayToRgb = applyInitializedPngGrayToRgbBeforeComposeStage(
        initialization, gray.info, gray.row()
    )
    let composed = applyInitializedPngComposeStage(
        initialization, grayToRgb.info, grayToRgb.row()
    )
    let gammaCorrected = applyInitializedPngGammaStage(
        initialization, composed.info, composed.row()
    )
    let strippedAfterCompose = applyInitializedPngStripAlphaAfterComposeStage(
        initialization, gammaCorrected.info, gammaCorrected.row()
    )
    let encodedAlpha = applyInitializedPngEncodeAlphaStage(
        initialization,
        strippedAfterCompose.info,
        strippedAfterCompose.row()
    )
    let reduced = applyInitializedPng16To8Stages(
        initialization,
        encodedAlpha.info,
        encodedAlpha.row()
    )
    let quantized = applyInitializedPngQuantizeStage(
        initialization, reduced.info, reduced.row()
    )
    let expanded16 = applyInitializedPngExpand16Stage(
        initialization, quantized.info, quantized.row()
    )
    let grayToRgbAfterExpand16 = applyInitializedPngGrayToRgbAfterExpand16Stage(
        initialization,
        expanded16.info,
        expanded16.row()
    )
    let invertedMono = applyInitializedPngInvertMonoStage(
        initialization,
        grayToRgbAfterExpand16.info,
        grayToRgbAfterExpand16.row()
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
    let paletteChecked = applyInitializedPngPaletteIndexCheckStage(
        initialization,
        unpacked.info,
        unpacked.row(),
        currentMaximumPaletteIndex
    )
    let bgr = applyInitializedPngBgrStage(
        initialization, paletteChecked.info, paletteChecked.row()
    )
    let packSwapped = applyInitializedPngPackSwapStage(
        initialization, bgr.info, bgr.row()
    )
    let filled = applyInitializedPngFillerStage(
        initialization, packSwapped.info, packSwapped.row()
    )
    let swappedAlpha = applyInitializedPngSwapAlphaAfterFillerStage(
        initialization,
        filled.info,
        filled.row(),
        filled.info.channels != packSwapped.info.channels
    )
    let byteSwapped = applyInitializedPngByteSwapStage(
        initialization, swappedAlpha.info, swappedAlpha.row()
    )
    let userTransformed = applyInitializedPngReadUserTransformStage(
        initialization,
        byteSwapped.info,
        byteSwapped.row(),
        context
    )
    PngInitializedReadRowResult(
        userTransformed.info,
        userTransformed.row(),
        gray.hadNonGrayPixels,
        paletteChecked.maximumPaletteIndex,
        paletteChecked.hasInvalidIndex(initialization.paletteEntryCount())
    )
}

public func applyInitializedPngReadStages(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngInitializedReadRowResult {
    applyInitializedPngReadStagesWithPaletteMaximum(
        initialization,
        rowInfo,
        row,
        Int64(0),
        PngReadUserTransformContext(UInt32(0), UInt8(0))
    )
}

public func applyInitializedPngReadStages(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    context: PngReadUserTransformContext
): PngInitializedReadRowResult {
    applyInitializedPngReadStagesWithPaletteMaximum(
        initialization,
        rowInfo,
        row,
        Int64(0),
        context
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
    var maximumPaletteIndex: Int64 = 0
    var hasInvalidPaletteIndex = false
    var index: Int64 = 0
    while (index < rows.size) {
        let transformed = applyInitializedPngReadStagesWithPaletteMaximum(
            initialization,
            sourceInfo,
            decoded.row(index),
            maximumPaletteIndex,
            PngReadUserTransformContext(UInt32(index), UInt8(0))
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
        maximumPaletteIndex = transformed.maximumPaletteIndex
        hasInvalidPaletteIndex = hasInvalidPaletteIndex ||
            transformed.hasInvalidPaletteIndex
        index += 1
    }
    PngInitializedReadRowsResult(
        outputInfo,
        rows,
        hadNonGrayPixels,
        maximumPaletteIndex,
        hasInvalidPaletteIndex
    )
}

public func transformPngRowsInitialized(
    decoded: PngDecodedRows,
    state: PngReadTransformState
): PngInitializedReadRowsResult {
    transformPngRowsInitialized(decoded, state, PngReadLimits())
}
