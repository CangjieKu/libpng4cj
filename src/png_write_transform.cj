package libpng4cj

import std.collection.ArrayList

public enum PngWriteTransformApplicationError <:
    Equatable<PngWriteTransformApplicationError> & ToString {
    | NoWriteTransformApplicationError
    | InvalidWriteTransformTarget
    | InvalidAfterWriteInitialization

    public operator func ==(right: PngWriteTransformApplicationError): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngWriteTransformApplicationError): Bool {
        !(this == right)
    }

    private func ordinalValue(): Int64 {
        match (this) {
            case NoWriteTransformApplicationError => 0
            case InvalidWriteTransformTarget => 1
            case InvalidAfterWriteInitialization => 2
        }
    }

    public func toString(): String {
        match (this) {
            case NoWriteTransformApplicationError => "NONE"
            case InvalidWriteTransformTarget => "INVALID_TARGET"
            case InvalidAfterWriteInitialization => "INVALID_AFTER_INITIALIZATION"
        }
    }
}

public enum PngWriteFillerLocation <: Equatable<PngWriteFillerLocation> & ToString {
    | WriteFillerBefore
    | WriteFillerAfter

    public operator func ==(right: PngWriteFillerLocation): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngWriteFillerLocation): Bool {
        !(this == right)
    }

    private func ordinalValue(): Int64 {
        match (this) {
            case WriteFillerBefore => 0
            case WriteFillerAfter => 1
        }
    }

    public func toString(): String {
        match (this) {
            case WriteFillerBefore => "BEFORE"
            case WriteFillerAfter => "AFTER"
        }
    }
}

public enum PngWriteTransformStage <: Equatable<PngWriteTransformStage> & ToString {
    | WriteStageStripFiller
    | WriteStagePackSwap
    | WriteStagePack
    | WriteStageByteSwap
    | WriteStageShift
    | WriteStageSwapAlpha
    | WriteStageInvertAlpha
    | WriteStageBgr
    | WriteStageInvertMono

    public operator func ==(right: PngWriteTransformStage): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: PngWriteTransformStage): Bool {
        !(this == right)
    }

    private func ordinalValue(): Int64 {
        match (this) {
            case WriteStageStripFiller => 0
            case WriteStagePackSwap => 1
            case WriteStagePack => 2
            case WriteStageByteSwap => 3
            case WriteStageShift => 4
            case WriteStageSwapAlpha => 5
            case WriteStageInvertAlpha => 6
            case WriteStageBgr => 7
            case WriteStageInvertMono => 8
        }
    }

    public func toString(): String {
        match (this) {
            case WriteStageStripFiller => "STRIP_FILLER"
            case WriteStagePackSwap => "PACK_SWAP"
            case WriteStagePack => "PACK"
            case WriteStageByteSwap => "BYTE_SWAP"
            case WriteStageShift => "SHIFT"
            case WriteStageSwapAlpha => "SWAP_ALPHA"
            case WriteStageInvertAlpha => "INVERT_ALPHA"
            case WriteStageBgr => "BGR"
            case WriteStageInvertMono => "INVERT_MONO"
        }
    }
}

public class PngWriteTransformState {
    public let targetBitDepth: UInt8
    public let targetColorType: PngColorType
    private var initializedValue: Bool = false
    private var lastErrorValue: PngWriteTransformApplicationError =
        NoWriteTransformApplicationError
    private var packingValue: Bool = false
    private var packSwapValue: Bool = false
    private var invertMonoValue: Bool = false
    private var shiftValue: Bool = false
    private var shiftBitsValue: PngSignificantBits = PngSignificantBits()
    private var bgrValue: Bool = false
    private var swapAlphaValue: Bool = false
    private var invertAlphaValue: Bool = false
    private var byteSwapValue: Bool = false
    private var stripFillerValue: Bool = false
    private var fillerLocationValue: PngWriteFillerLocation = WriteFillerAfter

    public init(bitDepth: UInt8, colorType: PngColorType) {
        targetBitDepth = bitDepth
        targetColorType = colorType
    }

    private func canMutate(): Bool {
        if (initializedValue) {
            lastErrorValue = InvalidAfterWriteInitialization
            return false
        }
        true
    }

    private func rejectTarget(): Bool {
        lastErrorValue = InvalidWriteTransformTarget
        false
    }

    private func accept(): Bool {
        lastErrorValue = NoWriteTransformApplicationError
        true
    }

    public func initialized(): Bool {
        initializedValue
    }

    public func lastApplicationError(): PngWriteTransformApplicationError {
        lastErrorValue
    }

    public func setPacking(): Bool {
        if (!canMutate()) { return false }
        if (targetBitDepth >= UInt8(8)) { return rejectTarget() }
        packingValue = true
        accept()
    }

    public func setPackSwap(): Bool {
        if (!canMutate()) { return false }
        if (targetBitDepth >= UInt8(8)) { return rejectTarget() }
        packSwapValue = true
        accept()
    }

    public func setInvertMono(): Bool {
        if (!canMutate()) { return false }
        invertMonoValue = true
        accept()
    }

    public func setShift(significantBits: PngSignificantBits): Bool {
        if (!canMutate()) { return false }
        if (!validWriteShiftBits(targetBitDepth, targetColorType, significantBits)) {
            return rejectTarget()
        }
        shiftBitsValue = cloneWriteSignificantBits(significantBits)
        shiftValue = true
        accept()
    }

    public func setBgr(): Bool {
        if (!canMutate()) { return false }
        bgrValue = true
        accept()
    }

    public func setSwapAlpha(): Bool {
        if (!canMutate()) { return false }
        swapAlphaValue = true
        accept()
    }

    public func setInvertAlpha(): Bool {
        if (!canMutate()) { return false }
        invertAlphaValue = true
        accept()
    }

    public func setByteSwap(): Bool {
        if (!canMutate()) { return false }
        if (targetBitDepth != UInt8(16)) { return rejectTarget() }
        byteSwapValue = true
        accept()
    }

    public func setStripFiller(location: PngWriteFillerLocation): Bool {
        if (!canMutate()) { return false }
        let supportedColor = targetColorType == Grayscale || targetColorType == Truecolor
        if (!supportedColor || targetBitDepth < UInt8(8)) { return rejectTarget() }
        fillerLocationValue = location
        stripFillerValue = true
        accept()
    }

    func initializeFor(ihdr: PngIhdr): PngWriteTransformInitialization {
        if (initializedValue) {
            throw PngFormatException(
                InvalidArgument, -1, "PNG write transform state is already initialized"
            )
        }
        if (ihdr.bitDepth != targetBitDepth || ihdr.colorType != targetColorType) {
            lastErrorValue = InvalidWriteTransformTarget
            throw PngFormatException(
                InvalidArgument, -1, "PNG write transform state does not match IHDR"
            )
        }
        initializedValue = true
        lastErrorValue = NoWriteTransformApplicationError
        PngWriteTransformInitialization(
            ihdr, packingValue, packSwapValue, invertMonoValue,
            shiftValue, shiftBitsValue, bgrValue, swapAlphaValue,
            invertAlphaValue, byteSwapValue, stripFillerValue,
            fillerLocationValue
        )
    }
}

public class PngWriteTransformInitialization {
    public let targetBitDepth: UInt8
    public let targetColorType: PngColorType
    public let sourceBitDepth: UInt8
    public let sourceChannels: UInt8
    private let packingValue: Bool
    private let packSwapValue: Bool
    private let invertMonoValue: Bool
    private let shiftValue: Bool
    private let shiftBitsValue: PngSignificantBits
    private let bgrValue: Bool
    private let swapAlphaValue: Bool
    private let invertAlphaValue: Bool
    private let byteSwapValue: Bool
    private let stripFillerValue: Bool
    private let fillerLocationValue: PngWriteFillerLocation
    private let stagesValue: Array<PngWriteTransformStage>

    init(
        ihdr: PngIhdr,
        packing: Bool,
        packSwap: Bool,
        invertMono: Bool,
        shift: Bool,
        shiftBits: PngSignificantBits,
        bgr: Bool,
        swapAlpha: Bool,
        invertAlpha: Bool,
        byteSwap: Bool,
        stripFiller: Bool,
        fillerLocation: PngWriteFillerLocation
    ) {
        targetBitDepth = ihdr.bitDepth
        targetColorType = ihdr.colorType
        sourceBitDepth = if (packing) { UInt8(8) } else { ihdr.bitDepth }
        sourceChannels = ihdr.channels + if (stripFiller) { UInt8(1) } else { UInt8(0) }
        packingValue = packing
        packSwapValue = packSwap
        invertMonoValue = invertMono
        shiftValue = shift
        shiftBitsValue = cloneWriteSignificantBits(shiftBits)
        bgrValue = bgr
        swapAlphaValue = swapAlpha
        invertAlphaValue = invertAlpha
        byteSwapValue = byteSwap
        stripFillerValue = stripFiller
        fillerLocationValue = fillerLocation

        let stages = ArrayList<PngWriteTransformStage>()
        if (stripFiller) { stages.add(WriteStageStripFiller) }
        if (packSwap) { stages.add(WriteStagePackSwap) }
        if (packing) { stages.add(WriteStagePack) }
        if (byteSwap) { stages.add(WriteStageByteSwap) }
        if (shift) { stages.add(WriteStageShift) }
        if (swapAlpha) { stages.add(WriteStageSwapAlpha) }
        if (invertAlpha) { stages.add(WriteStageInvertAlpha) }
        if (bgr) { stages.add(WriteStageBgr) }
        if (invertMono) { stages.add(WriteStageInvertMono) }
        stagesValue = stages.toArray()
    }

    public func stageCount(): Int64 { stagesValue.size }

    public func stage(index: Int64): PngWriteTransformStage {
        if (index < Int64(0) || index >= stagesValue.size) {
            throw PngFormatException(InvalidArgument, index, "PNG write transform stage index is invalid")
        }
        stagesValue[index]
    }

    public func sourceRowBytes(width: UInt32): UInt64 {
        (UInt64(width) * UInt64(sourceBitDepth) * UInt64(sourceChannels) + UInt64(7)) / UInt64(8)
    }

    public func outputRowBytes(width: UInt32): UInt64 {
        (UInt64(width) * UInt64(targetBitDepth) * UInt64(targetColorType.channels()) + UInt64(7)) / UInt64(8)
    }

    public func shiftSignificantBits(): PngSignificantBits {
        cloneWriteSignificantBits(shiftBitsValue)
    }

    func packingEnabled(): Bool { packingValue }
    func packSwapEnabled(): Bool { packSwapValue }
    func invertMonoEnabled(): Bool { invertMonoValue }
    func shiftEnabled(): Bool { shiftValue }
    func bgrEnabled(): Bool { bgrValue }
    func swapAlphaEnabled(): Bool { swapAlphaValue }
    func invertAlphaEnabled(): Bool { invertAlphaValue }
    func byteSwapEnabled(): Bool { byteSwapValue }
    func stripFillerEnabled(): Bool { stripFillerValue }
    func fillerLocation(): PngWriteFillerLocation { fillerLocationValue }
}

private func cloneWriteSignificantBits(value: PngSignificantBits): PngSignificantBits {
    PngSignificantBits(value.gray, value.red, value.green, value.blue, value.alpha)
}

private func validWriteShiftBits(
    bitDepth: UInt8,
    colorType: PngColorType,
    value: PngSignificantBits
): Bool {
    let colorValid = if (colorType == Truecolor || colorType == TruecolorAlpha || colorType == Indexed) {
        value.red > UInt8(0) && value.red <= bitDepth &&
            value.green > UInt8(0) && value.green <= bitDepth &&
            value.blue > UInt8(0) && value.blue <= bitDepth
    } else {
        value.gray > UInt8(0) && value.gray <= bitDepth
    }
    if (!colorValid) { return false }
    if (colorType == GrayscaleAlpha || colorType == TruecolorAlpha) {
        return value.alpha > UInt8(0) && value.alpha <= bitDepth
    }
    true
}

private func pngWritePack(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    targetBitDepth: UInt8
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (rowInfo.bitDepth != UInt8(8) || rowInfo.channels != UInt8(1) ||
        (targetBitDepth != UInt8(1) && targetBitDepth != UInt8(2) &&
        targetBitDepth != UInt8(4))) {
        return PngReadTransformRow(rowInfo, row)
    }
    let outputInfo = PngReadRowInfo(
        rowInfo.width, targetBitDepth, rowInfo.colorType, UInt8(1)
    )
    let output = Array<Byte>(Int64(outputInfo.rowBytes), repeat: UInt8(0))
    let mask = (UInt32(1) << UInt32(targetBitDepth)) - UInt32(1)
    var pixel: UInt64 = UInt64(0)
    while (pixel < UInt64(rowInfo.width)) {
        let value = if (targetBitDepth == UInt8(1)) {
            if (row[Int64(pixel)] == UInt8(0)) { UInt32(0) } else { UInt32(1) }
        } else {
            UInt32(row[Int64(pixel)]) & mask
        }
        let bitOffset = pixel * UInt64(targetBitDepth)
        let byteOffset = Int64(bitOffset / UInt64(8))
        let shift = UInt32(8) - UInt32(targetBitDepth) - UInt32(bitOffset % UInt64(8))
        output[byteOffset] = output[byteOffset] | UInt8(value << shift)
        pixel += UInt64(1)
    }
    PngReadTransformRow(outputInfo, output)
}

private func writeShiftComponents(rowInfo: PngReadRowInfo, bits: PngSignificantBits): Array<UInt8> {
    match (rowInfo.colorType) {
        case Grayscale => [bits.gray]
        case GrayscaleAlpha => [bits.gray, bits.alpha]
        case Truecolor => [bits.red, bits.green, bits.blue]
        case TruecolorAlpha => [bits.red, bits.green, bits.blue, bits.alpha]
        case Indexed => Array<UInt8>()
    }
}

private func repeatWriteSample(value: UInt32, depth: UInt8, significant: UInt8): UInt32 {
    var output: UInt32 = UInt32(0)
    var shift = Int64(depth) - Int64(significant)
    while (shift > -Int64(significant)) {
        if (shift > Int64(0)) {
            output |= value << UInt32(shift)
        } else {
            output |= value >> UInt32(-shift)
        }
        shift -= Int64(significant)
    }
    let mask = if (depth == UInt8(16)) { UInt32(0xffff) } else {
        (UInt32(1) << UInt32(depth)) - UInt32(1)
    }
    output & mask
}

private func pngWriteShiftPacked(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    significant: UInt8
): Array<Byte> {
    let output = row.clone()
    let depth = rowInfo.bitDepth
    let shiftStart = Int64(depth) - Int64(significant)
    let shiftMask = if (significant == UInt8(1) && depth == UInt8(2)) {
        UInt32(0x55)
    } else if (depth == UInt8(4) && significant == UInt8(3)) {
        UInt32(0x11)
    } else {
        UInt32(0xff)
    }
    var index: Int64 = Int64(0)
    while (index < output.size) {
        let value = UInt32(output[index])
        var expanded: UInt32 = UInt32(0)
        var shift = shiftStart
        while (shift > -Int64(significant)) {
            if (shift > Int64(0)) {
                expanded |= value << UInt32(shift)
            } else {
                expanded |= (value >> UInt32(-shift)) & shiftMask
            }
            shift -= Int64(significant)
        }
        output[index] = UInt8(expanded & UInt32(0xff))
        index += Int64(1)
    }
    output
}

private func pngWriteShift(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    bits: PngSignificantBits
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    let components = writeShiftComponents(rowInfo, bits)
    if (components.size == Int64(0)) {
        return PngReadTransformRow(rowInfo, row)
    }
    if (rowInfo.bitDepth < UInt8(8)) {
        return PngReadTransformRow(
            rowInfo,
            pngWriteShiftPacked(rowInfo, row, components[0])
        )
    }
    let output = row.clone()
    if (rowInfo.bitDepth == UInt8(8)) {
        var offset: Int64 = Int64(0)
        while (offset < output.size) {
            let channel = offset % components.size
            output[offset] = UInt8(repeatWriteSample(
                UInt32(output[offset]), UInt8(8), components[channel]
            ))
            offset += Int64(1)
        }
    } else if (rowInfo.bitDepth == UInt8(16)) {
        var component: Int64 = Int64(0)
        var offset: Int64 = Int64(0)
        while (offset < output.size) {
            let value = (UInt32(output[offset]) << UInt32(8)) |
                UInt32(output[offset + Int64(1)])
            let expanded = repeatWriteSample(value, UInt8(16), components[component])
            output[offset] = UInt8(expanded >> UInt32(8))
            output[offset + Int64(1)] = UInt8(expanded & UInt32(0xff))
            component += Int64(1)
            if (component >= components.size) { component = Int64(0) }
            offset += Int64(2)
        }
    }
    PngReadTransformRow(rowInfo, output)
}

private func pngWriteSwapAlpha(
    rowInfo: PngReadRowInfo,
    row: Array<Byte>
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    let hasAlpha = rowInfo.colorType == GrayscaleAlpha || rowInfo.colorType == TruecolorAlpha
    if (!hasAlpha || (rowInfo.bitDepth != UInt8(8) && rowInfo.bitDepth != UInt8(16))) {
        return PngReadTransformRow(rowInfo, row)
    }
    let componentBytes = if (rowInfo.bitDepth == UInt8(16)) { Int64(2) } else { Int64(1) }
    let pixelBytes = Int64(rowInfo.channels) * componentBytes
    let colorBytes = pixelBytes - componentBytes
    let output = Array<Byte>(row.size, repeat: UInt8(0))
    var pixel: Int64 = Int64(0)
    while (pixel < Int64(rowInfo.width)) {
        let offset = pixel * pixelBytes
        var index: Int64 = Int64(0)
        while (index < colorBytes) {
            output[offset + index] = row[offset + componentBytes + index]
            index += Int64(1)
        }
        index = Int64(0)
        while (index < componentBytes) {
            output[offset + colorBytes + index] = row[offset + index]
            index += Int64(1)
        }
        pixel += Int64(1)
    }
    PngReadTransformRow(rowInfo, output)
}

func applyInitializedPngWriteTransforms(
    initialization: PngWriteTransformInitialization,
    width: UInt32,
    row: Array<Byte>
): PngReadTransformRow {
    var transformed = PngReadTransformRow(
        PngReadRowInfo(
            width, initialization.sourceBitDepth,
            initialization.targetColorType, initialization.sourceChannels
        ),
        row
    )
    if (initialization.stripFillerEnabled()) {
        transformed = pngDoStripChannel(
            transformed.info,
            transformed.row(),
            initialization.fillerLocation() == WriteFillerBefore
        )
    }
    if (initialization.packSwapEnabled()) {
        transformed = pngDoPackSwap(transformed.info, transformed.row())
    }
    if (initialization.packingEnabled()) {
        transformed = pngWritePack(
            transformed.info, transformed.row(), initialization.targetBitDepth
        )
    }
    if (initialization.byteSwapEnabled()) {
        transformed = pngDoSwap(transformed.info, transformed.row())
    }
    if (initialization.shiftEnabled()) {
        transformed = pngWriteShift(
            transformed.info, transformed.row(), initialization.shiftSignificantBits()
        )
    }
    if (initialization.swapAlphaEnabled()) {
        transformed = pngWriteSwapAlpha(transformed.info, transformed.row())
    }
    if (initialization.invertAlphaEnabled()) {
        transformed = pngDoReadInvertAlpha(transformed.info, transformed.row())
    }
    if (initialization.bgrEnabled()) {
        transformed = pngDoBgr(transformed.info, transformed.row())
    }
    if (initialization.invertMonoEnabled()) {
        transformed = pngDoInvertMono(transformed.info, transformed.row())
    }
    let expected = initialization.outputRowBytes(width)
    if (transformed.info.bitDepth != initialization.targetBitDepth ||
        transformed.info.colorType != initialization.targetColorType ||
        transformed.info.channels != initialization.targetColorType.channels() ||
        transformed.info.rowBytes != expected) {
        throw PngFormatException(
            InvalidArgument, -1, "PNG write transforms did not produce the IHDR row shape"
        )
    }
    transformed
}
