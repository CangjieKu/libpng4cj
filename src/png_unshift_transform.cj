package libpng4cj

private class PngUnshiftPlan {
    let shifts: Array<UInt32>
    let hasShift: Bool

    init(shifts: Array<UInt32>) {
        this.shifts = shifts.clone()
        var active = false
        var index: Int64 = 0
        while (index < shifts.size) {
            if (shifts[index] != UInt32(0)) {
                active = true
                break
            }
            index += 1
        }
        hasShift = active
    }
}

private func pngUnshiftAmount(bitDepth: UInt8, significantBits: UInt8): UInt32 {
    let shift = Int64(bitDepth) - Int64(significantBits)
    if (shift <= 0 || shift >= Int64(bitDepth)) {
        return UInt32(0)
    }
    UInt32(shift)
}

private func pngUnshiftPlan(
    rowInfo: PngReadRowInfo,
    significantBits: PngSignificantBits
): PngUnshiftPlan {
    let shifts: Array<UInt32> = match (rowInfo.colorType) {
        case Grayscale => [
            pngUnshiftAmount(rowInfo.bitDepth, significantBits.gray)
        ]
        case GrayscaleAlpha => [
            pngUnshiftAmount(rowInfo.bitDepth, significantBits.gray),
            pngUnshiftAmount(rowInfo.bitDepth, significantBits.alpha)
        ]
        case Truecolor => [
            pngUnshiftAmount(rowInfo.bitDepth, significantBits.red),
            pngUnshiftAmount(rowInfo.bitDepth, significantBits.green),
            pngUnshiftAmount(rowInfo.bitDepth, significantBits.blue)
        ]
        case TruecolorAlpha => [
            pngUnshiftAmount(rowInfo.bitDepth, significantBits.red),
            pngUnshiftAmount(rowInfo.bitDepth, significantBits.green),
            pngUnshiftAmount(rowInfo.bitDepth, significantBits.blue),
            pngUnshiftAmount(rowInfo.bitDepth, significantBits.alpha)
        ]
        case Indexed => Array<UInt32>()
    }
    PngUnshiftPlan(shifts)
}

private func pngUnshiftSupported(rowInfo: PngReadRowInfo): Bool {
    if (rowInfo.colorType == Indexed ||
        rowInfo.channels != rowInfo.colorType.channels()) {
        return false
    }
    if (rowInfo.bitDepth == UInt8(2) || rowInfo.bitDepth == UInt8(4)) {
        return rowInfo.colorType == Grayscale
    }
    rowInfo.bitDepth == UInt8(8) || rowInfo.bitDepth == UInt8(16)
}

private func pngDoUnshiftPacked2(row: Array<Byte>): Array<Byte> {
    let output = row.clone()
    var offset: Int64 = 0
    while (offset < output.size) {
        output[offset] = UInt8((UInt32(output[offset]) >> 1) & UInt32(0x55))
        offset += 1
    }
    output
}

private func pngDoUnshiftPacked4(
    row: Array<Byte>,
    shift: UInt32
): Array<Byte> {
    let output = row.clone()
    let lowMask = UInt32(0x0f) >> shift
    let mask = lowMask | (lowMask << 4)
    var offset: Int64 = 0
    while (offset < output.size) {
        output[offset] = UInt8((UInt32(output[offset]) >> shift) & mask)
        offset += 1
    }
    output
}

private func pngDoUnshift8(
    row: Array<Byte>,
    shifts: Array<UInt32>
): Array<Byte> {
    let output = row.clone()
    var offset: Int64 = 0
    var channel: Int64 = 0
    while (offset < output.size) {
        output[offset] = UInt8(UInt32(output[offset]) >> shifts[channel])
        channel += 1
        if (channel >= shifts.size) {
            channel = 0
        }
        offset += 1
    }
    output
}

private func pngDoUnshift16(
    row: Array<Byte>,
    shifts: Array<UInt32>
): Array<Byte> {
    let output = row.clone()
    var offset: Int64 = 0
    var channel: Int64 = 0
    while (offset < output.size) {
        var value = (UInt32(output[offset]) << 8) |
            UInt32(output[offset + 1])
        value >>= shifts[channel]
        output[offset] = UInt8(value >> 8)
        output[offset + 1] = UInt8(value & UInt32(0xff))
        channel += 1
        if (channel >= shifts.size) {
            channel = 0
        }
        offset += 2
    }
    output
}

public func pngDoUnshift(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    significantBits: PngSignificantBits
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!pngUnshiftSupported(rowInfo)) {
        return PngReadTransformRow(rowInfo, row)
    }

    let plan = pngUnshiftPlan(rowInfo, significantBits)
    if (!plan.hasShift) {
        return PngReadTransformRow(rowInfo, row)
    }

    let output = match (rowInfo.bitDepth) {
        case 2 => pngDoUnshiftPacked2(row)
        case 4 => pngDoUnshiftPacked4(row, plan.shifts[0])
        case 8 => pngDoUnshift8(row, plan.shifts)
        case 16 => pngDoUnshift16(row, plan.shifts)
        case _ => row.clone()
    }
    PngReadTransformRow(rowInfo, output)
}

public func applySelectedPngUnshiftTransform(
    transforms: Array<PngReadChannelTransform>,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    significantBits: PngSignificantBits
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!hasPngReadChannelTransform(transforms, UnshiftSignificantBits)) {
        return PngReadTransformRow(rowInfo, row)
    }
    pngDoUnshift(rowInfo, row, significantBits)
}
