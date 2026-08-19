package libpng4cj

private func pngCClassicMutateWriteMetadata(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    action: (PngWriteMetadata) -> Unit
): Unit {
    if (!pngCClassicInfoMatchesOwner(pngPtr, infoPtr)) { return }
    var context: Option<(PngCClassicReadState, PngWriteMetadata)> = None
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                let infoHandle = infoPtr.toUIntNative()
                if (state.writeOwner && !state.destroying &&
                    !state.readOperationActive && !state.writeCallbackActive &&
                    !state.signatureWritten && state.rowWriter.isNone() &&
                    (state.writeInfoHandle == UIntNative(0) ||
                        state.writeInfoHandle == infoHandle)) {
                    state.readOperationActive = true
                    state.writeInfoHandle = infoHandle
                    context = Some((state, state.writeMetadata))
                }
            case None => ()
        }
    }
    match (context) {
        case Some((state, metadata)) =>
            var message = ""
            try { action(metadata) } catch (error: Exception) {
                message = error.message
            } finally {
                synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
                    state.readOperationActive = false
                }
            }
            if (message != "") { pngCClassicErrorText(pngPtr, message) }
        case None => ()
    }
}

private func pngCClassicReadColor16(
    value: CPointer<Unit>
): Option<PngBackground> {
    if (value.isNull()) { return None }
    let bytes = unsafe { CPointer<UInt8>(value) }
    let samples = unsafe { CPointer<UInt16>(value) }
    unsafe {
        Some(PngBackground(
            bytes.read(Int64(0)), samples.read(Int64(4)),
            samples.read(Int64(1)), samples.read(Int64(2)),
            samples.read(Int64(3))
        ))
    }
}

private func pngCClassicSrgbIntent(value: Int32): Option<PngSrgbIntent> {
    match (value) {
        case 0 => Some(Perceptual)
        case 1 => Some(RelativeColorimetric)
        case 2 => Some(Saturation)
        case 3 => Some(AbsoluteColorimetric)
        case _ => Option<PngSrgbIntent>.None
    }
}

@C
public func png_set_bKGD(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    background: CPointer<Unit>
): Unit {
    match (pngCClassicReadColor16(background)) {
        case Some(value) => pngCClassicMutateWriteMetadata(
            pngPtr, infoPtr, { metadata =>
                metadata.backgroundValue = PngBackground(value)
                metadata.hasBackgroundValue = true
            }
        )
        case None => ()
    }
}

@C
public func png_set_cHRM_fixed(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    whiteX: Int32, whiteY: Int32, redX: Int32, redY: Int32,
    greenX: Int32, greenY: Int32, blueX: Int32, blueY: Int32
): Unit {
    pngCClassicMutateWriteMetadata(pngPtr, infoPtr, { metadata =>
        metadata.chromaticitiesValue = PngChromaticities(
            whiteX, whiteY, redX, redY, greenX, greenY, blueX, blueY
        )
        metadata.hasChromaticitiesValue = true
    })
}

@C
public func png_set_cICP(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    colorPrimaries: UInt8, transferFunction: UInt8,
    matrixCoefficients: UInt8, fullRangeFlag: UInt8
): Unit {
    pngCClassicMutateWriteMetadata(pngPtr, infoPtr, { metadata =>
        metadata.cicpValue = PngCodingIndependentCodePoints(
            colorPrimaries, transferFunction, matrixCoefficients, fullRangeFlag
        )
        metadata.hasCicpValue = true
    })
}

@C
public func png_set_cLLI_fixed(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    maximumContentLightLevel: UInt32,
    maximumFrameAverageLightLevel: UInt32
): Unit {
    pngCClassicMutateWriteMetadata(pngPtr, infoPtr, { metadata =>
        metadata.contentLightLevelValue = PngContentLightLevel(
            maximumContentLightLevel, maximumFrameAverageLightLevel
        )
        metadata.hasContentLightLevelValue = true
    })
}

@C
public func png_set_eXIf_1(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    length: UInt32, exif: CPointer<UInt8>
): Unit {
    if ((length > UInt32(0) && exif.isNull()) ||
        UInt64(length) > UInt64(512_000_000)) { return }
    let bytes = Array<Byte>(Int64(length), repeat: UInt8(0))
    var index = Int64(0)
    while (index < bytes.size) {
        bytes[index] = unsafe { exif.read(index) }
        index += Int64(1)
    }
    pngCClassicMutateWriteMetadata(pngPtr, infoPtr, { metadata =>
        metadata.exifValue = bytes
        metadata.exifPlacementValue = WriteBeforeIdat
        metadata.hasExifValue = true
    })
}

@C
public func png_set_gAMA_fixed(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>, gamma: Int32
): Unit {
    if (gamma <= Int32(0)) { return }
    pngCClassicMutateWriteMetadata(pngPtr, infoPtr, { metadata =>
        metadata.gammaValue = UInt32(gamma)
        metadata.hasGammaValue = true
    })
}

@C
public func png_set_hIST(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    histogram: CPointer<UInt16>
): Unit {
    if (histogram.isNull()) { return }
    var count = Int64(0)
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) => count = state.writePalette.size / Int64(3)
            case None => ()
        }
    }
    if (count <= Int64(0) || count > Int64(256)) { return }
    let values = Array<UInt16>(count, repeat: UInt16(0))
    var index = Int64(0)
    while (index < count) {
        values[index] = unsafe { histogram.read(index) }
        index += Int64(1)
    }
    pngCClassicMutateWriteMetadata(pngPtr, infoPtr, { metadata =>
        metadata.histogramValue = values
        metadata.hasHistogramValue = true
    })
}

@C
public func png_set_mDCV_fixed(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    whiteX: Int32, whiteY: Int32, redX: Int32, redY: Int32,
    greenX: Int32, greenY: Int32, blueX: Int32, blueY: Int32,
    maximumDisplayLuminance: UInt32,
    minimumDisplayLuminance: UInt32
): Unit {
    pngCClassicMutateWriteMetadata(pngPtr, infoPtr, { metadata =>
        metadata.masteringDisplayValue = PngMasteringDisplayColorVolume(
            PngChromaticities(
                whiteX, whiteY, redX, redY,
                greenX, greenY, blueX, blueY
            ),
            maximumDisplayLuminance, minimumDisplayLuminance
        )
        metadata.hasMasteringDisplayValue = true
    })
}

@C
public func png_set_oFFs(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    offsetX: Int32, offsetY: Int32, unitType: Int32
): Unit {
    if (unitType < Int32(0) || unitType > Int32(1)) { return }
    pngCClassicMutateWriteMetadata(pngPtr, infoPtr, { metadata =>
        metadata.imageOffsetValue = PngImageOffset(
            offsetX, offsetY, UInt8(unitType)
        )
        metadata.hasImageOffsetValue = true
    })
}

@C
public func png_set_pHYs(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    resolutionX: UInt32, resolutionY: UInt32, unitType: Int32
): Unit {
    if (unitType < Int32(0) || unitType > Int32(1)) { return }
    pngCClassicMutateWriteMetadata(pngPtr, infoPtr, { metadata =>
        metadata.physicalDimensionsValue = PngPhysicalDimensions(
            resolutionX, resolutionY, UInt8(unitType)
        )
        metadata.hasPhysicalDimensionsValue = true
    })
}

@C
public func png_set_sBIT(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    significantBits: CPointer<UInt8>
): Unit {
    if (significantBits.isNull()) { return }
    let value = unsafe { PngSignificantBits(
        significantBits.read(Int64(3)), significantBits.read(Int64(0)),
        significantBits.read(Int64(1)), significantBits.read(Int64(2)),
        significantBits.read(Int64(4))
    ) }
    pngCClassicMutateWriteMetadata(pngPtr, infoPtr, { metadata =>
        metadata.significantBitsValue = value
        metadata.hasSignificantBitsValue = true
    })
}

@C
public func png_set_sRGB(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>, intent: Int32
): Unit {
    match (pngCClassicSrgbIntent(intent)) {
        case Some(value) => pngCClassicMutateWriteMetadata(
            pngPtr, infoPtr, { metadata =>
                metadata.srgbValue = value
                metadata.hasSrgbValue = true
            }
        )
        case None => ()
    }
}

@C
public func png_set_tIME(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    time: CPointer<Unit>
): Unit {
    if (time.isNull()) { return }
    let words = unsafe { CPointer<UInt16>(time) }
    let bytes = unsafe { CPointer<UInt8>(time) }
    let value = unsafe { PngModificationTime(
        words.read(Int64(0)), bytes.read(Int64(2)), bytes.read(Int64(3)),
        bytes.read(Int64(4)), bytes.read(Int64(5)), bytes.read(Int64(6))
    ) }
    pngCClassicMutateWriteMetadata(pngPtr, infoPtr, { metadata =>
        metadata.modificationTimeValue = value
        metadata.modificationTimePlacementValue = WriteBeforeIdat
        metadata.hasModificationTimeValue = true
    })
}

@C
public func png_set_tRNS(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    alpha: CPointer<UInt8>, count: Int32, color: CPointer<Unit>
): Unit {
    var value: Option<PngWriteTransparency> = None
    if (count > Int32(0) && count <= Int32(256) && !alpha.isNull()) {
        let bytes = Array<Byte>(Int64(count), repeat: UInt8(0))
        var index = Int64(0)
        while (index < bytes.size) {
            bytes[index] = unsafe { alpha.read(index) }
            index += Int64(1)
        }
        value = Some(PngWriteTransparency(bytes))
    } else {
        match (pngCClassicReadColor16(color)) {
            case Some(resolved) =>
                var colorType = Int32(-1)
                synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
                    match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
                        case Some(state) => match (state.writeIhdr) {
                            case Some(ihdr) => colorType = Int32(ihdr.colorType.encodedValue())
                            case None => ()
                        }
                        case None => ()
                    }
                }
                if (colorType == Int32(0)) {
                    value = Some(PngWriteTransparency(resolved.gray))
                } else if (colorType == Int32(2)) {
                    value = Some(PngWriteTransparency(
                        resolved.red, resolved.green, resolved.blue
                    ))
                }
            case None => ()
        }
    }
    match (value) {
        case Some(resolved) => pngCClassicMutateWriteMetadata(
            pngPtr, infoPtr, { metadata =>
                metadata.transparencyValue = resolved
                metadata.hasTransparencyValue = true
            }
        )
        case None => ()
    }
}
