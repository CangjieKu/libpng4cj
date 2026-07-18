package libpng4cj

import std.convert.*
import std.math.floor

private let PNG_C_EXT_INFO_cHRM = UInt32(0x0004)
private let PNG_C_EXT_INFO_hIST = UInt32(0x0040)
private let PNG_C_EXT_INFO_tIME = UInt32(0x0200)
private let PNG_C_EXT_INFO_pCAL = UInt32(0x0400)
private let PNG_C_EXT_INFO_iCCP = UInt32(0x1000)
private let PNG_C_EXT_INFO_sCAL = UInt32(0x4000)
private let PNG_C_EXT_INFO_eXIf = UInt32(0x10000)

private class PngCClassicXyz {
    let success: Bool
    let redX: Int32
    let redY: Int32
    let redZ: Int32
    let greenX: Int32
    let greenY: Int32
    let greenZ: Int32
    let blueX: Int32
    let blueY: Int32
    let blueZ: Int32

    init(success: Bool, values: Array<Int32>) {
        this.success = success
        redX = values[0]
        redY = values[1]
        redZ = values[2]
        greenX = values[3]
        greenY = values[4]
        greenZ = values[5]
        blueX = values[6]
        blueY = values[7]
        blueZ = values[8]
    }
}

private func pngCClassicEmptyXyz(): PngCClassicXyz {
    PngCClassicXyz(false, Array<Int32>(9, repeat: Int32(0)))
}

private func pngCClassicCheckedSub(
    left: Int32, right: Int32
): PngFixedMulDivResult {
    let value = Int64(left) - Int64(right)
    if (value < Int64(-2147483648) || value > Int64(2147483647)) {
        PngFixedMulDivResult(false, Int32(0))
    } else {
        PngFixedMulDivResult(true, Int32(value))
    }
}

private func pngCClassicScaleFixed(value: Float64): PngFixedMulDivResult {
    let rounded = floor(Float64(100000.0) * value + Float64(0.5))
    if (rounded > Float64(2147483647.0) ||
        rounded < Float64(-2147483648.0)) {
        PngFixedMulDivResult(false, Int32(0))
    } else {
        PngFixedMulDivResult(true, Int32(rounded))
    }
}

private func pngCClassicXyzFromChromaticities(
    value: PngChromaticities
): PngCClassicXyz {
    let limit = Int32(110000)
    if (value.redX < Int32(0) || value.redX > limit ||
        value.redY < Int32(0) || value.redY > limit - value.redX ||
        value.greenX < Int32(0) || value.greenX > limit ||
        value.greenY < Int32(0) || value.greenY > limit - value.greenX ||
        value.blueX < Int32(0) || value.blueX > limit ||
        value.blueY < Int32(0) || value.blueY > limit - value.blueX ||
        value.whiteX < Int32(0) || value.whiteX > limit ||
        value.whiteY < Int32(5) || value.whiteY > limit - value.whiteX) {
        return pngCClassicEmptyXyz()
    }

    let left0 = pngMulDivFixed(
        value.greenX - value.blueX,
        value.redY - value.blueY,
        Int32(8)
    )
    let right0 = pngMulDivFixed(
        value.greenY - value.blueY,
        value.redX - value.blueX,
        Int32(8)
    )
    if (!left0.success || !right0.success) {
        return pngCClassicEmptyXyz()
    }
    let denominator = pngCClassicCheckedSub(left0.value, right0.value)
    if (!denominator.success) { return pngCClassicEmptyXyz() }

    let left1 = pngMulDivFixed(
        value.greenX - value.blueX,
        value.whiteY - value.blueY,
        Int32(8)
    )
    let right1 = pngMulDivFixed(
        value.greenY - value.blueY,
        value.whiteX - value.blueX,
        Int32(8)
    )
    if (!left1.success || !right1.success) {
        return pngCClassicEmptyXyz()
    }
    let redNumerator = pngCClassicCheckedSub(left1.value, right1.value)
    if (!redNumerator.success) { return pngCClassicEmptyXyz() }
    let redInverse = pngMulDivFixed(
        value.whiteY, denominator.value, redNumerator.value
    )
    if (!redInverse.success || redInverse.value <= value.whiteY) {
        return pngCClassicEmptyXyz()
    }

    let left2 = pngMulDivFixed(
        value.redY - value.blueY,
        value.whiteX - value.blueX,
        Int32(8)
    )
    let right2 = pngMulDivFixed(
        value.redX - value.blueX,
        value.whiteY - value.blueY,
        Int32(8)
    )
    if (!left2.success || !right2.success) {
        return pngCClassicEmptyXyz()
    }
    let greenNumerator = pngCClassicCheckedSub(left2.value, right2.value)
    if (!greenNumerator.success) { return pngCClassicEmptyXyz() }
    let greenInverse = pngMulDivFixed(
        value.whiteY, denominator.value, greenNumerator.value
    )
    if (!greenInverse.success || greenInverse.value <= value.whiteY) {
        return pngCClassicEmptyXyz()
    }

    let whiteScale = pngReciprocalFixed(value.whiteY)
    let redScale = pngReciprocalFixed(redInverse.value)
    let greenScale = pngReciprocalFixed(greenInverse.value)
    if (whiteScale == Int32(0) || redScale == Int32(0) ||
        greenScale == Int32(0)) {
        return pngCClassicEmptyXyz()
    }
    let afterRed = pngCClassicCheckedSub(whiteScale, redScale)
    if (!afterRed.success) { return pngCClassicEmptyXyz() }
    let blueScale = pngCClassicCheckedSub(afterRed.value, greenScale)
    if (!blueScale.success || blueScale.value <= Int32(0)) {
        return pngCClassicEmptyXyz()
    }

    let values = Array<Int32>(9, repeat: Int32(0))
    let products = [
        pngMulDivFixed(value.redX, PNG_FP_1, redInverse.value),
        pngMulDivFixed(value.redY, PNG_FP_1, redInverse.value),
        pngMulDivFixed(
            PNG_FP_1 - value.redX - value.redY,
            PNG_FP_1,
            redInverse.value
        ),
        pngMulDivFixed(value.greenX, PNG_FP_1, greenInverse.value),
        pngMulDivFixed(value.greenY, PNG_FP_1, greenInverse.value),
        pngMulDivFixed(
            PNG_FP_1 - value.greenX - value.greenY,
            PNG_FP_1,
            greenInverse.value
        ),
        pngMulDivFixed(value.blueX, blueScale.value, PNG_FP_1),
        pngMulDivFixed(value.blueY, blueScale.value, PNG_FP_1),
        pngMulDivFixed(
            PNG_FP_1 - value.blueX - value.blueY,
            blueScale.value,
            PNG_FP_1
        )
    ]
    var index = Int64(0)
    while (index < products.size) {
        if (!products[index].success) { return pngCClassicEmptyXyz() }
        values[index] = products[index].value
        index += Int64(1)
    }
    PngCClassicXyz(true, values)
}

private func pngCClassicWriteXyzFixed(
    xyz: PngCClassicXyz,
    redX: CPointer<Int32>, redY: CPointer<Int32>, redZ: CPointer<Int32>,
    greenX: CPointer<Int32>, greenY: CPointer<Int32>, greenZ: CPointer<Int32>,
    blueX: CPointer<Int32>, blueY: CPointer<Int32>, blueZ: CPointer<Int32>
): Unit {
    unsafe {
        if (!redX.isNull()) { redX.write(xyz.redX) }
        if (!redY.isNull()) { redY.write(xyz.redY) }
        if (!redZ.isNull()) { redZ.write(xyz.redZ) }
        if (!greenX.isNull()) { greenX.write(xyz.greenX) }
        if (!greenY.isNull()) { greenY.write(xyz.greenY) }
        if (!greenZ.isNull()) { greenZ.write(xyz.greenZ) }
        if (!blueX.isNull()) { blueX.write(xyz.blueX) }
        if (!blueY.isNull()) { blueY.write(xyz.blueY) }
        if (!blueZ.isNull()) { blueZ.write(xyz.blueZ) }
    }
}

private func pngCClassicWriteXyz(
    xyz: PngCClassicXyz,
    redX: CPointer<Float64>, redY: CPointer<Float64>, redZ: CPointer<Float64>,
    greenX: CPointer<Float64>, greenY: CPointer<Float64>, greenZ: CPointer<Float64>,
    blueX: CPointer<Float64>, blueY: CPointer<Float64>, blueZ: CPointer<Float64>
): Unit {
    let values = [
        xyz.redX, xyz.redY, xyz.redZ,
        xyz.greenX, xyz.greenY, xyz.greenZ,
        xyz.blueX, xyz.blueY, xyz.blueZ
    ]
    let outputs = [redX, redY, redZ, greenX, greenY, greenZ, blueX, blueY, blueZ]
    var index = Int64(0)
    while (index < outputs.size) {
        if (!outputs[index].isNull()) {
            unsafe {
                outputs[index].write(
                    Float64(values[index]) / Float64(100000.0)
                )
            }
        }
        index += Int64(1)
    }
}

@C
public func png_get_cHRM_XYZ_fixed(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    redX: CPointer<Int32>, redY: CPointer<Int32>, redZ: CPointer<Int32>,
    greenX: CPointer<Int32>, greenY: CPointer<Int32>, greenZ: CPointer<Int32>,
    blueX: CPointer<Int32>, blueY: CPointer<Int32>, blueZ: CPointer<Int32>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasChromaticities) { return UInt32(0) }
                let xyz = pngCClassicXyzFromChromaticities(
                    access.metadata.chromaticities
                )
                if (!xyz.success) { return UInt32(0) }
                pngCClassicWriteXyzFixed(
                    xyz, redX, redY, redZ,
                    greenX, greenY, greenZ,
                    blueX, blueY, blueZ
                )
                PNG_C_EXT_INFO_cHRM
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_cHRM_XYZ(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    redX: CPointer<Float64>, redY: CPointer<Float64>, redZ: CPointer<Float64>,
    greenX: CPointer<Float64>, greenY: CPointer<Float64>, greenZ: CPointer<Float64>,
    blueX: CPointer<Float64>, blueY: CPointer<Float64>, blueZ: CPointer<Float64>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasChromaticities) { return UInt32(0) }
                let xyz = pngCClassicXyzFromChromaticities(
                    access.metadata.chromaticities
                )
                if (!xyz.success) { return UInt32(0) }
                pngCClassicWriteXyz(
                    xyz, redX, redY, redZ,
                    greenX, greenY, greenZ,
                    blueX, blueY, blueZ
                )
                PNG_C_EXT_INFO_cHRM
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_eXIf(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    exif: CPointer<CPointer<UInt8>>
): UInt32 {
    pngCClassicWarningText(
        pngPtr, "png_get_eXIf does not work; use png_get_eXIf_1"
    )
    UInt32(0)
}

@C
public func png_get_eXIf_1(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    length: CPointer<UInt32>, exif: CPointer<CPointer<UInt8>>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasExif ||
                    !access.metadata.exifBeforeIdat || exif.isNull() ||
                    length.isNull() || access.backing.exif.isNull()) {
                    return UInt32(0)
                }
                unsafe {
                    length.write(access.backing.exifLength)
                    exif.write(CPointer<UInt8>(access.backing.exif))
                }
                PNG_C_EXT_INFO_eXIf
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_hIST(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    histogram: CPointer<CPointer<UInt16>>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasHistogram || histogram.isNull() ||
                    access.backing.histogram.isNull()) {
                    return UInt32(0)
                }
                unsafe {
                    histogram.write(CPointer<UInt16>(access.backing.histogram))
                }
                PNG_C_EXT_INFO_hIST
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_iCCP(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    name: CPointer<CPointer<UInt8>>, compression: CPointer<Int32>,
    profile: CPointer<CPointer<UInt8>>, length: CPointer<UInt32>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasIccProfile || name.isNull() ||
                    profile.isNull() || length.isNull() ||
                    access.backing.iccName.isNull() ||
                    access.backing.iccProfile.isNull()) {
                    return UInt32(0)
                }
                unsafe {
                    name.write(CPointer<UInt8>(access.backing.iccName))
                    profile.write(CPointer<UInt8>(access.backing.iccProfile))
                    length.write(access.backing.iccProfileLength)
                    if (!compression.isNull()) { compression.write(Int32(0)) }
                }
                PNG_C_EXT_INFO_iCCP
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_pCAL(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    purpose: CPointer<CPointer<UInt8>>, x0: CPointer<Int32>,
    x1: CPointer<Int32>, equation: CPointer<Int32>,
    count: CPointer<Int32>, units: CPointer<CPointer<UInt8>>,
    parameters: CPointer<CPointer<CPointer<UInt8>>>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasPixelCalibration || purpose.isNull() ||
                    x0.isNull() || x1.isNull() || equation.isNull() ||
                    count.isNull() || units.isNull() || parameters.isNull()) {
                    return UInt32(0)
                }
                let value = access.metadata.pixelCalibration
                unsafe {
                    purpose.write(CPointer<UInt8>(access.backing.calibrationPurpose))
                    x0.write(value.x0)
                    x1.write(value.x1)
                    equation.write(Int32(value.equationType))
                    count.write(access.backing.calibrationParameterCount)
                    units.write(CPointer<UInt8>(access.backing.calibrationUnits))
                    parameters.write(
                        CPointer<CPointer<UInt8>>(
                            access.backing.calibrationParameters
                        )
                    )
                }
                PNG_C_EXT_INFO_pCAL
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_rows(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): CPointer<CPointer<UInt8>> {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            pngCClassicEndMetadataAccess(access.state)
            CPointer<CPointer<UInt8>>()
        case None => CPointer<CPointer<UInt8>>()
    }
}

@C
public func png_get_sCAL_s(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    unit: CPointer<Int32>, width: CPointer<CPointer<UInt8>>,
    height: CPointer<CPointer<UInt8>>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasPhysicalScale || unit.isNull() ||
                    width.isNull() || height.isNull()) {
                    return UInt32(0)
                }
                unsafe {
                    unit.write(Int32(access.metadata.physicalScale.unit))
                    width.write(CPointer<UInt8>(access.backing.scaleWidth))
                    height.write(CPointer<UInt8>(access.backing.scaleHeight))
                }
                PNG_C_EXT_INFO_sCAL
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_sCAL(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    unit: CPointer<Int32>, width: CPointer<Float64>, height: CPointer<Float64>
): UInt32 {
    if (unit.isNull() || width.isNull() || height.isNull()) { return UInt32(0) }
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasPhysicalScale ||
                    access.backing.scaleWidth.isNull() ||
                    access.backing.scaleHeight.isNull()) {
                    return UInt32(0)
                }
                let widthValue = Float64.parse(
                    CString(CPointer<UInt8>(access.backing.scaleWidth)).toString()
                )
                let heightValue = Float64.parse(
                    CString(CPointer<UInt8>(access.backing.scaleHeight)).toString()
                )
                unsafe {
                    unit.write(Int32(access.metadata.physicalScale.unit))
                    width.write(widthValue)
                    height.write(heightValue)
                }
                PNG_C_EXT_INFO_sCAL
            } catch (_: Exception) {
                UInt32(0)
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_sCAL_fixed(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    unit: CPointer<Int32>, width: CPointer<Int32>, height: CPointer<Int32>
): UInt32 {
    if (unit.isNull() || width.isNull() || height.isNull()) { return UInt32(0) }
    var fixedError = ""
    let status = match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasPhysicalScale ||
                    access.backing.scaleWidth.isNull() ||
                    access.backing.scaleHeight.isNull()) {
                    return UInt32(0)
                }
                let widthValue = Float64.parse(
                    CString(CPointer<UInt8>(access.backing.scaleWidth)).toString()
                )
                let heightValue = Float64.parse(
                    CString(CPointer<UInt8>(access.backing.scaleHeight)).toString()
                )
                let fixedWidth = pngCClassicScaleFixed(widthValue)
                let fixedHeight = pngCClassicScaleFixed(heightValue)
                if (!fixedWidth.success) {
                    fixedError = "fixed point overflow in sCAL width"
                    UInt32(0)
                } else if (!fixedHeight.success) {
                    fixedError = "fixed point overflow in sCAL height"
                    UInt32(0)
                } else {
                    unsafe {
                        unit.write(Int32(access.metadata.physicalScale.unit))
                        width.write(fixedWidth.value)
                        height.write(fixedHeight.value)
                    }
                    PNG_C_EXT_INFO_sCAL
                }
            } catch (_: Exception) {
                UInt32(0)
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
    if (fixedError != "") {
        pngCClassicErrorText(pngPtr, fixedError)
    }
    status
}

@C
public func png_get_sPLT(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    palettes: CPointer<CPointer<Unit>>
): Int32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (palettes.isNull()) { return Int32(0) }
                unsafe { palettes.write(access.backing.suggestedPalettes) }
                access.backing.suggestedPaletteCount
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => Int32(0)
    }
}

@C
public func png_get_tIME(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    time: CPointer<CPointer<Unit>>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasModificationTime ||
                    !access.metadata.modificationTimeBeforeIdat ||
                    time.isNull() || access.backing.modificationTime.isNull()) {
                    return UInt32(0)
                }
                unsafe { time.write(access.backing.modificationTime) }
                PNG_C_EXT_INFO_tIME
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_text(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    text: CPointer<CPointer<Unit>>, count: CPointer<Int32>
): Int32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                let value = access.backing.textEntryCount
                if (value > Int32(0)) {
                    unsafe {
                        if (!text.isNull()) { text.write(access.backing.textEntries) }
                        if (!count.isNull()) { count.write(value) }
                    }
                    value
                } else {
                    unsafe { if (!count.isNull()) { count.write(Int32(0)) } }
                    Int32(0)
                }
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None =>
            unsafe { if (!count.isNull()) { count.write(Int32(0)) } }
            Int32(0)
    }
}

@C
public func png_get_unknown_chunks(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    chunks: CPointer<CPointer<Unit>>
): Int32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (chunks.isNull()) { return Int32(0) }
                unsafe { chunks.write(access.backing.unknownChunks) }
                access.backing.unknownChunkCount
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => Int32(0)
    }
}
