package libpng4cj

public class PngPaletteIndexCheckResult {
    public let info: PngReadRowInfo
    public let maximumPaletteIndex: Int64
    public let checked: Bool
    private let ownedRow: Array<Byte>

    init(
        info: PngReadRowInfo,
        row: Array<Byte>,
        maximumPaletteIndex: Int64,
        checked: Bool
    ) {
        this.info = info
        this.maximumPaletteIndex = maximumPaletteIndex
        this.checked = checked
        ownedRow = row.clone()
    }

    public func row(): Array<Byte> {
        ownedRow.clone()
    }

    public func hasInvalidIndex(paletteEntryCount: Int64): Bool {
        checked && paletteEntryCount > 0 &&
            maximumPaletteIndex >= paletteEntryCount
    }
}

private func pngPaletteIndexCapacity(bitDepth: UInt8): Int64 {
    match (bitDepth) {
        case 1 => 2
        case 2 => 4
        case 4 => 16
        case 8 => 256
        case _ => 0
    }
}

private func pngPaletteIndexAt(
    row: Array<Byte>,
    bitDepth: UInt8,
    pixel: UInt64
): Int64 {
    if (bitDepth == UInt8(8)) {
        return Int64(row[Int64(pixel)])
    }
    let bitOffset = pixel * UInt64(bitDepth)
    let sourceOffset = Int64(bitOffset / UInt64(8))
    let shift = UInt32(8) - UInt32(bitDepth) -
        UInt32(bitOffset % UInt64(8))
    let mask = UInt32(pngPaletteIndexCapacity(bitDepth) - 1)
    Int64((UInt32(row[sourceOffset]) >> shift) & mask)
}

public func pngDoCheckPaletteIndexes(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    paletteEntryCount: Int64
): PngPaletteIndexCheckResult {
    pngDoCheckPaletteIndexes(rowInfo, row, paletteEntryCount, Int64(0))
}

public func pngDoCheckPaletteIndexes(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    paletteEntryCount: Int64,
    currentMaximumPaletteIndex: Int64
): PngPaletteIndexCheckResult {
    validatePngTransformRowLength(rowInfo, row)
    if (currentMaximumPaletteIndex < 0) {
        throw PngFormatException(
            InvalidArgument,
            currentMaximumPaletteIndex,
            "current PNG maximum palette index must be non-negative"
        )
    }

    let capacity = pngPaletteIndexCapacity(rowInfo.bitDepth)
    let supported = rowInfo.colorType == Indexed &&
        rowInfo.channels == UInt8(1) && capacity > 0 &&
        rowInfo.width > UInt32(0)
    if (!supported || paletteEntryCount <= 0 ||
        paletteEntryCount >= capacity) {
        return PngPaletteIndexCheckResult(
            rowInfo, row, currentMaximumPaletteIndex, false
        )
    }

    var maximum = currentMaximumPaletteIndex
    var pixel: UInt64 = UInt64(0)
    while (pixel < UInt64(rowInfo.width)) {
        let value = pngPaletteIndexAt(row, rowInfo.bitDepth, pixel)
        if (value > maximum) {
            maximum = value
        }
        pixel += UInt64(1)
    }
    PngPaletteIndexCheckResult(rowInfo, row, maximum, true)
}

public func applyInitializedPngPaletteIndexCheckStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngPaletteIndexCheckResult {
    applyInitializedPngPaletteIndexCheckStage(
        initialization, rowInfo, row, Int64(0)
    )
}

public func applyInitializedPngPaletteIndexCheckStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    currentMaximumPaletteIndex: Int64
): PngPaletteIndexCheckResult {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.hasStage(ReadStagePaletteIndexCheck)) {
        return PngPaletteIndexCheckResult(
            rowInfo, row, currentMaximumPaletteIndex, false
        )
    }
    pngDoCheckPaletteIndexes(
        rowInfo,
        row,
        initialization.paletteEntryCount(),
        currentMaximumPaletteIndex
    )
}
