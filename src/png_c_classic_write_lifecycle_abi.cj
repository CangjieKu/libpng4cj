package libpng4cj

private let PNG_C_WRITE_FILTER_NONE = Int32(0x08)
private let PNG_C_WRITE_FILTER_SUB = Int32(0x10)
private let PNG_C_WRITE_FILTER_UP = Int32(0x20)
private let PNG_C_WRITE_FILTER_AVG = Int32(0x40)
private let PNG_C_WRITE_FILTER_PAETH = Int32(0x80)

private func pngCClassicWriteColorType(value: Int32): Option<PngColorType> {
    match (value) {
        case 0 => Some(Grayscale)
        case 2 => Some(Truecolor)
        case 3 => Some(Indexed)
        case 4 => Some(GrayscaleAlpha)
        case 6 => Some(TruecolorAlpha)
        case _ => Option<PngColorType>.None
    }
}

private func pngCClassicWriteInterlace(value: Int32): Option<PngInterlaceMethod> {
    match (value) {
        case 0 => Some(None)
        case 1 => Some(Adam7)
        case _ => Option<PngInterlaceMethod>.None
    }
}

private func pngCClassicBeginWriteControlMutation(
    pngPtr: CPointer<Unit>
): Option<(PngCClassicReadState, PngWriteControlState)> {
    if (pngPtr.isNull()) { return None }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (!state.writeOwner || state.destroying ||
                    state.readOperationActive || state.writeCallbackActive ||
                    state.signatureWritten || state.rowWriter.isSome()) {
                    None
                } else {
                    state.readOperationActive = true
                    Some((state, state.writeControls))
                }
            case None => None
        }
    }
}

private func pngCClassicEndWriteControlMutation(
    state: PngCClassicReadState
): Unit {
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        state.readOperationActive = false
    }
}

private func pngCClassicMutateWriteControl(
    pngPtr: CPointer<Unit>, action: (PngWriteControlState) -> Unit
): Unit {
    match (pngCClassicBeginWriteControlMutation(pngPtr)) {
        case Some((state, controls)) =>
            var message = ""
            try { action(controls) } catch (error: Exception) {
                message = error.message
            } finally {
                pngCClassicEndWriteControlMutation(state)
            }
            if (message != "") { pngCClassicErrorText(pngPtr, message) }
        case None => ()
    }
}

@C
public func png_set_IHDR(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    width: UInt32, height: UInt32, bitDepth: Int32, colorType: Int32,
    interlaceMethod: Int32, compressionMethod: Int32, filterMethod: Int32
): Unit {
    if (!pngCClassicInfoMatchesOwner(pngPtr, infoPtr)) { return }
    match ((
        pngCClassicWriteColorType(colorType),
        pngCClassicWriteInterlace(interlaceMethod)
    )) {
        case (Some(color), Some(interlace)) =>
            if (bitDepth < Int32(0) || bitDepth > Int32(255) ||
                compressionMethod != Int32(0) || filterMethod != Int32(0)) {
                pngCClassicErrorText(pngPtr, "Invalid IHDR data")
                return
            }
            var message = ""
            synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
                match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
                    case Some(state) =>
                        if (state.writeOwner && !state.destroying &&
                            !state.readOperationActive &&
                            !state.signatureWritten && state.rowWriter.isNone()) {
                            try {
                                state.writeIhdr = Some(PngIhdr(
                                    width, height, UInt8(bitDepth), color,
                                    UInt8(0), UInt8(0), interlace
                                ))
                                state.writeInfoHandle = infoPtr.toUIntNative()
                            } catch (error: Exception) {
                                message = error.message
                            }
                        }
                    case None => ()
                }
            }
            if (message != "") { pngCClassicErrorText(pngPtr, message) }
        case _ => pngCClassicErrorText(pngPtr, "Invalid IHDR data")
    }
}

@C
public func png_set_PLTE(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>,
    palette: CPointer<UInt8>, count: Int32
): Unit {
    if (!pngCClassicInfoMatchesOwner(pngPtr, infoPtr) ||
        palette.isNull() || count <= Int32(0) || count > Int32(256)) {
        return
    }
    let bytes = Array<Byte>(Int64(count) * Int64(3), repeat: UInt8(0))
    var index = Int64(0)
    while (index < bytes.size) {
        bytes[index] = unsafe { palette.read(index) }
        index += Int64(1)
    }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.writeOwner && !state.destroying &&
                    !state.readOperationActive && !state.signatureWritten &&
                    state.rowWriter.isNone() &&
                    state.writeInfoHandle == infoPtr.toUIntNative()) {
                    state.writePalette = bytes
                }
            case None => ()
        }
    }
}

@C
public func png_set_compression_buffer_size(
    pngPtr: CPointer<Unit>, size: UIntNative
): Unit {
    pngCClassicMutateWriteControl(pngPtr, { controls =>
        controls.setCompressionBufferBytes(Int64(size))
    })
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.writeOwner && !state.signatureWritten) {
                    state.compressionBufferSize = size
                }
            case None => ()
        }
    }
}

@C
public func png_set_compression_level(
    pngPtr: CPointer<Unit>, level: Int32
): Unit {
    pngCClassicMutateWriteControl(
        pngPtr, { controls => controls.setCompressionLevel(level) }
    )
}

@C
public func png_set_compression_mem_level(
    pngPtr: CPointer<Unit>, level: Int32
): Unit {
    pngCClassicMutateWriteControl(
        pngPtr, { controls => controls.setCompressionMemoryLevel(level) }
    )
}

@C
public func png_set_compression_window_bits(
    pngPtr: CPointer<Unit>, bits: Int32
): Unit {
    pngCClassicMutateWriteControl(
        pngPtr, { controls => controls.setCompressionWindowBits(bits) }
    )
}

@C
public func png_set_compression_method(
    pngPtr: CPointer<Unit>, method: Int32
): Unit {
    pngCClassicMutateWriteControl(
        pngPtr, { controls => controls.setCompressionMethod(method) }
    )
}

@C
public func png_set_compression_strategy(
    pngPtr: CPointer<Unit>, strategy: Int32
): Unit {
    let value: Option<PngWriteCompressionStrategy> = match (strategy) {
        case 0 => Some(WriteCompressionDefault)
        case 1 => Some(WriteCompressionFiltered)
        case 2 => Some(WriteCompressionHuffmanOnly)
        case 3 => Some(WriteCompressionRle)
        case 4 => Some(WriteCompressionFixed)
        case _ => Option<PngWriteCompressionStrategy>.None
    }
    match (value) {
        case Some(resolved) => pngCClassicMutateWriteControl(
            pngPtr, { controls => controls.setCompressionStrategy(resolved) }
        )
        case None => pngCClassicErrorText(
            pngPtr, "invalid zlib compression strategy"
        )
    }
}

@C
public func png_set_filter(
    pngPtr: CPointer<Unit>, method: Int32, filters: Int32
): Unit {
    if (method != Int32(0)) {
        pngCClassicErrorText(pngPtr, "Unknown custom filter method")
        return
    }
    pngCClassicMutateWriteControl(pngPtr, { controls =>
        if (filters == Int32(0)) {
            controls.useDefaultFilters()
        } else {
            controls.setFilters(
                (filters & PNG_C_WRITE_FILTER_NONE) != Int32(0),
                (filters & PNG_C_WRITE_FILTER_SUB) != Int32(0),
                (filters & PNG_C_WRITE_FILTER_UP) != Int32(0),
                (filters & PNG_C_WRITE_FILTER_AVG) != Int32(0),
                (filters & PNG_C_WRITE_FILTER_PAETH) != Int32(0)
            )
        }
    })
}

private func pngCClassicStartRowWriter(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Unit {
    if (!pngCClassicInfoMatchesOwner(pngPtr, infoPtr)) { return }
    var context: Option<(
        PngCClassicReadState, PngIhdr, Array<Byte>, PngWriteMetadata
    )> = None
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.writeOwner && !state.destroying &&
                    !state.readOperationActive && !state.signatureWritten &&
                    state.rowWriter.isNone() &&
                    state.writeInfoHandle == infoPtr.toUIntNative()) {
                    match (state.writeIhdr) {
                        case Some(ihdr) =>
                            state.readOperationActive = true
                            state.signatureWritten = true
                            context = Some((
                                state, ihdr, state.writePalette.clone(),
                                pngSnapshotWriteMetadata(state.writeMetadata)
                            ))
                        case None => ()
                    }
                }
            case None => ()
        }
    }
    match (context) {
        case Some((state, ihdr, palette, metadata)) =>
            var writer: Option<PngRowWriteSession> = None
            var sink: Option<PngWriteSink> = None
            var message = ""
            try {
                let nextSink = PngWriteSink()
                nextSink.setWriteCallback({ _, bytes =>
                    pngCClassicWriteEncodedBytes(pngPtr, bytes)
                })
                nextSink.setFlushCallback({ _ =>
                    unsafe { png_write_flush(pngPtr) }
                })
                let nextWriter = PngRowWriteSession(
                    ihdr.width, ihdr.height, ihdr.bitDepth, ihdr.colorType,
                    ihdr.interlaceMethod, palette, metadata,
                    state.writeControls, PngWriteLimits()
                )
                nextWriter.startTo(nextSink)
                writer = Some(nextWriter)
                sink = Some(nextSink)
            } catch (error: Exception) {
                message = error.message
            }
            synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
                match (writer) {
                    case Some(value) =>
                        state.rowWriter = Some(value)
                        state.rowWriterSink = sink
                    case None => state.signatureWritten = false
                }
                state.readOperationActive = false
            }
            if (message != "") { pngCClassicErrorText(pngPtr, message) }
        case None => ()
    }
}

@C
public func png_write_info(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Unit {
    pngCClassicStartRowWriter(pngPtr, infoPtr)
}

private func pngCClassicWriteLifecycleRow(
    pngPtr: CPointer<Unit>, row: CPointer<UInt8>
): Bool {
    if (pngPtr.isNull() || row.isNull()) { return false }
    var context: Option<(PngCClassicReadState, PngRowWriteSession)> = None
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.writeOwner && !state.destroying &&
                    !state.readOperationActive && !state.writeCallbackActive) {
                    match (state.rowWriter) {
                        case Some(writer) =>
                            state.readOperationActive = true
                            context = Some((state, writer))
                        case None => ()
                    }
                }
            case None => ()
        }
    }
    match (context) {
        case Some((state, writer)) =>
            var message = ""
            try {
                let length = Int64(writer.expectedRowBytes())
                let bytes = Array<Byte>(length, repeat: UInt8(0))
                var index = Int64(0)
                while (index < length) {
                    bytes[index] = unsafe { row.read(index) }
                    index += Int64(1)
                }
                writer.writeRow(bytes)
            } catch (error: Exception) {
                message = error.message
            } finally {
                synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
                    state.readOperationActive = false
                }
            }
            if (message != "") {
                pngCClassicErrorText(pngPtr, message)
                return false
            }
            true
        case None => false
    }
}

@C
public func png_write_row(
    pngPtr: CPointer<Unit>, row: CPointer<UInt8>
): Unit {
    pngCClassicWriteLifecycleRow(pngPtr, row)
}

@C
public func png_write_rows(
    pngPtr: CPointer<Unit>, rows: CPointer<CPointer<UInt8>>, count: UInt32
): Unit {
    if (rows.isNull()) { return }
    var index = UInt32(0)
    while (index < count) {
        if (!pngCClassicWriteLifecycleRow(
            pngPtr, unsafe { rows.read(Int64(index)) }
        )) { return }
        index += UInt32(1)
    }
}

@C
public func png_write_image(
    pngPtr: CPointer<Unit>, rows: CPointer<CPointer<UInt8>>
): Unit {
    if (pngPtr.isNull() || rows.isNull()) { return }
    var count = UInt32(0)
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                match (state.rowWriter) {
                    case Some(writer) => count = writer.remainingRowCount()
                    case None => ()
                }
            case None => ()
        }
    }
    unsafe { png_write_rows(pngPtr, rows, count) }
}

@C
public func png_write_end(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Unit {
    if (!infoPtr.isNull() && !pngCClassicInfoMatchesOwner(pngPtr, infoPtr)) {
        return
    }
    var context: Option<(PngCClassicReadState, PngRowWriteSession)> = None
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.writeOwner && !state.destroying &&
                    !state.readOperationActive && !state.writeCallbackActive) {
                    match (state.rowWriter) {
                        case Some(writer) =>
                            state.readOperationActive = true
                            context = Some((state, writer))
                        case None => ()
                    }
                }
            case None => ()
        }
    }
    match (context) {
        case Some((state, writer)) =>
            var message = ""
            try { writer.finishTo() } catch (error: Exception) {
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
