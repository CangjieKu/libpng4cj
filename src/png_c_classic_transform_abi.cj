package libpng4cj

private func pngCClassicBeginReadTransformMutation(
    pngPtr: CPointer<Unit>
): Option<(PngCClassicReadState, PngReadTransformState)> {
    if (pngPtr.isNull()) { return None }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.writeOwner || state.destroying ||
                    state.readOperationActive || state.transformedRows.isSome()) {
                    None
                } else {
                    state.readOperationActive = true
                    Some((state, state.readTransforms))
                }
            case None => None
        }
    }
}

private func pngCClassicEndReadTransformMutation(
    state: PngCClassicReadState
): Unit {
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        state.readOperationActive = false
    }
}

private func pngCClassicMutateReadTransform(
    pngPtr: CPointer<Unit>,
    action: (PngReadTransformState) -> Bool
): Unit {
    match (pngCClassicBeginReadTransformMutation(pngPtr)) {
        case Some((state, transforms)) =>
            var message = ""
            try {
                action(transforms)
            } catch (error: Exception) {
                message = error.message
            } finally {
                pngCClassicEndReadTransformMutation(state)
            }
            if (message != "") { pngCClassicErrorText(pngPtr, message) }
        case None => ()
    }
}

private func pngCClassicInfoBelongsToOwner(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Bool {
    if (pngPtr.isNull() || infoPtr.isNull()) { return false }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.writeOwner || state.destroying) { return false }
                state.decodedInfoHandle == infoPtr.toUIntNative()
            case None => false
        }
    }
}

func pngCClassicEnsureReadTransforms(pngPtr: CPointer<Unit>): String {
    if (pngPtr.isNull()) { return "" }
    var context: Option<(PngCClassicReadState, PngDecodedRows)> = None
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (!state.writeOwner && !state.destroying &&
                    !state.readOperationActive && state.transformedRows.isNone()) {
                    match (state.decodedRows) {
                        case Some(decoded) =>
                            state.readOperationActive = true
                            context = Some((state, decoded))
                        case None => ()
                    }
                }
            case None => ()
        }
    }

    match (context) {
        case Some((state, decoded)) =>
            var result: Option<PngInitializedReadRowsResult> = None
            var message = ""
            try {
                result = Some(transformPngRowsInitialized(
                    decoded, state.readTransforms
                ))
            } catch (error: Exception) {
                message = error.message
            }
            synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
                match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
                    case Some(_) =>
                        if (!state.destroying) {
                            match (result) {
                                case Some(value) =>
                                    state.transformedRows = Some(value)
                                    state.paletteMax = Int32(value.maximumPaletteIndex)
                                    state.rgbToGrayStatus = if (value.hadNonGrayPixels) {
                                        UInt8(1)
                                    } else {
                                        UInt8(0)
                                    }
                                case None => ()
                            }
                        }
                    case None => ()
                }
                state.readOperationActive = false
            }
            message
        case None => ""
    }
}

private func pngCClassicBackground(
    color: CPointer<Unit>
): Option<PngBackground> {
    if (color.isNull()) { return None }
    let bytes = unsafe { CPointer<UInt8>(color) }
    let samples = unsafe { CPointer<UInt16>(color) }
    Some(PngBackground(
        unsafe { bytes.read(Int64(0)) },
        unsafe { samples.read(Int64(4)) },
        unsafe { samples.read(Int64(1)) },
        unsafe { samples.read(Int64(2)) },
        unsafe { samples.read(Int64(3)) }
    ))
}

private func pngCClassicBackgroundGamma(code: Int32): PngBackgroundGammaCode {
    match (code) {
        case 1 => BackgroundGammaScreen
        case 2 => BackgroundGammaFile
        case 3 => BackgroundGammaUnique
        case _ => BackgroundGammaUnknown
    }
}

private func pngCClassicRgbToGrayPolicy(action: Int32): PngRgbToGrayPolicy {
    if (action == Int32(3)) { RequireGray } else { Convert }
}

@C
public func png_set_expand(pngPtr: CPointer<Unit>): Unit {
    pngCClassicMutateReadTransform(pngPtr, { state => state.setExpand() })
}

@C
public func png_set_expand_gray_1_2_4_to_8(pngPtr: CPointer<Unit>): Unit {
    pngCClassicMutateReadTransform(
        pngPtr, { state => state.setExpandGrayOneTwoFourToEight() }
    )
}

@C
public func png_set_palette_to_rgb(pngPtr: CPointer<Unit>): Unit {
    pngCClassicMutateReadTransform(
        pngPtr, { state => state.setPaletteToRgb() }
    )
}

@C
public func png_set_tRNS_to_alpha(pngPtr: CPointer<Unit>): Unit {
    pngCClassicMutateReadTransform(
        pngPtr, { state => state.setTransparencyToAlpha() }
    )
}

@C
public func png_set_expand_16(pngPtr: CPointer<Unit>): Unit {
    pngCClassicMutateReadTransform(pngPtr, { state => state.setExpand16() })
}

@C
public func png_set_gray_to_rgb(pngPtr: CPointer<Unit>): Unit {
    pngCClassicMutateReadTransform(pngPtr, { state => state.setGrayToRgb() })
}

@C
public func png_set_rgb_to_gray_fixed(
    pngPtr: CPointer<Unit>, errorAction: Int32,
    red: Int32, green: Int32
): Unit {
    pngCClassicMutateReadTransform(pngPtr, { state =>
        state.setRgbToGrayFixed(
            pngCClassicRgbToGrayPolicy(errorAction),
            Int64(red), Int64(green)
        )
    })
}

@C
public func png_set_rgb_to_gray(
    pngPtr: CPointer<Unit>, errorAction: Int32,
    red: Float64, green: Float64
): Unit {
    pngCClassicMutateReadTransform(pngPtr, { state =>
        state.setRgbToGray(
            pngCClassicRgbToGrayPolicy(errorAction), red, green
        )
    })
}

@C
public func png_set_strip_alpha(pngPtr: CPointer<Unit>): Unit {
    pngCClassicMutateReadTransform(pngPtr, { state => state.setStripAlpha() })
}

@C
public func png_set_scale_16(pngPtr: CPointer<Unit>): Unit {
    pngCClassicMutateReadTransform(pngPtr, { state => state.setScale16() })
}

@C
public func png_set_strip_16(pngPtr: CPointer<Unit>): Unit {
    pngCClassicMutateReadTransform(pngPtr, { state => state.setStrip16() })
}

@C
public func png_set_gamma_fixed(
    pngPtr: CPointer<Unit>, screenGamma: Int32, fileGamma: Int32
): Unit {
    pngCClassicMutateReadTransform(pngPtr, { state =>
        state.setGammaFixed(screenGamma, fileGamma)
    })
}

@C
public func png_set_gamma(
    pngPtr: CPointer<Unit>, screenGamma: Float64, fileGamma: Float64
): Unit {
    pngCClassicMutateReadTransform(pngPtr, { state =>
        state.setGamma(screenGamma, fileGamma)
    })
}

@C
public func png_set_background_fixed(
    pngPtr: CPointer<Unit>, background: CPointer<Unit>,
    gammaCode: Int32, needExpand: Int32, backgroundGamma: Int32
): Unit {
    match (pngCClassicBackground(background)) {
        case Some(value) => pngCClassicMutateReadTransform(pngPtr, { state =>
            state.setBackgroundFixed(
                value, pngCClassicBackgroundGamma(gammaCode),
                Int64(needExpand), backgroundGamma
            )
        })
        case None => ()
    }
}

@C
public func png_set_background(
    pngPtr: CPointer<Unit>, background: CPointer<Unit>,
    gammaCode: Int32, needExpand: Int32, backgroundGamma: Float64
): Unit {
    match (pngCClassicBackground(background)) {
        case Some(value) => pngCClassicMutateReadTransform(pngPtr, { state =>
            state.setBackground(
                value, pngCClassicBackgroundGamma(gammaCode),
                Int64(needExpand), backgroundGamma
            )
        })
        case None => ()
    }
}

@C
public func png_set_check_for_invalid_index(
    pngPtr: CPointer<Unit>, allowed: Int32
): Unit {
    pngCClassicMutateReadTransform(pngPtr, { state =>
        state.setCheckForInvalidIndex(Int64(allowed))
    })
}

@C
public func png_start_read_image(pngPtr: CPointer<Unit>): Unit {
    let message = pngCClassicEnsureReadTransforms(pngPtr)
    if (message != "") { pngCClassicErrorText(pngPtr, message) }
}

@C
public func png_read_update_info(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Unit {
    if (!pngCClassicInfoBelongsToOwner(pngPtr, infoPtr)) { return }
    let message = pngCClassicEnsureReadTransforms(pngPtr)
    if (message != "") { pngCClassicErrorText(pngPtr, message) }
}
