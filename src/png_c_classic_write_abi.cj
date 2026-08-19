package libpng4cj

import std.collection.ArrayList

private let PNG_C_CLASSIC_IO_WRITING = UInt32(0x0002)
private let PNG_C_CLASSIC_IO_SIGNATURE = UInt32(0x0010)
private let PNG_C_CLASSIC_IO_CHUNK_HEADER = UInt32(0x0020)
private let PNG_C_CLASSIC_IO_CHUNK_DATA = UInt32(0x0040)
private let PNG_C_CLASSIC_IO_CHUNK_CRC = UInt32(0x0080)
private let PNG_C_CLASSIC_WRITE_SIGNATURE = [
    UInt8(137), UInt8(80), UInt8(78), UInt8(71),
    UInt8(13), UInt8(10), UInt8(26), UInt8(10)
]

private class PngCClassicWriteCallbackSnapshot {
    let state: PngCClassicReadState
    let ioPtr: CPointer<Unit>
    let writeFn: CPointer<Unit>
    let flushFn: CPointer<Unit>

    init(
        state: PngCClassicReadState,
        ioPtr: CPointer<Unit>,
        writeFn: CPointer<Unit>,
        flushFn: CPointer<Unit>
    ) {
        this.state = state
        this.ioPtr = ioPtr
        this.writeFn = writeFn
        this.flushFn = flushFn
    }
}

private func pngCClassicBeginWriteCallback(
    pngPtr: CPointer<Unit>, ioState: UInt32, chunkType: UInt32
): Option<PngCClassicWriteCallbackSnapshot> {
    if (pngPtr.isNull()) { return None }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (!state.writeOwner || state.destroying ||
                    state.writeCallbackActive) {
                    None
                } else {
                    state.writeCallbackActive = true
                    state.ioState = ioState
                    state.ioChunkType = chunkType
                    Some(PngCClassicWriteCallbackSnapshot(
                        state, state.ioPtr, state.writeFn, state.flushFn
                    ))
                }
            case None => None
        }
    }
}

private func pngCClassicEndWriteCallback(
    state: PngCClassicReadState
): Unit {
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        state.writeCallbackActive = false
    }
}

private func pngCClassicInvokeWriteCallback(
    pngPtr: CPointer<Unit>,
    snapshot: PngCClassicWriteCallbackSnapshot,
    data: CPointer<UInt8>,
    length: UIntNative
): Bool {
    if (!snapshot.writeFn.isNull()) {
        let function = CFunc<(
            CPointer<Unit>, CPointer<UInt8>, UIntNative
        ) -> Unit>(snapshot.writeFn)
        unsafe { function(pngPtr, data, length) }
        return true
    }
    unsafe {
        !snapshot.ioPtr.isNull() &&
            fwrite(data, UIntNative(1), length, snapshot.ioPtr) == length
    }
}

private func pngCClassicWritePointer(
    pngPtr: CPointer<Unit>,
    data: CPointer<UInt8>,
    length: UIntNative,
    ioState: UInt32,
    chunkType: UInt32
): Unit {
    if (length == UIntNative(0)) { return }
    match (pngCClassicBeginWriteCallback(pngPtr, ioState, chunkType)) {
        case Some(snapshot) =>
            let success = try {
                pngCClassicInvokeWriteCallback(
                    pngPtr, snapshot, data, length
                )
            } finally {
                pngCClassicEndWriteCallback(snapshot.state)
            }
            if (!success) { pngCClassicErrorText(pngPtr, "Write Error") }
        case None => ()
    }
}

private func pngCClassicWriteBytes(
    pngPtr: CPointer<Unit>,
    bytes: Array<Byte>,
    ioState: UInt32,
    chunkType: UInt32
): Unit {
    if (bytes.size == Int64(0)) { return }
    unsafe {
        let raw = acquireArrayRawData(bytes)
        try {
            pngCClassicWritePointer(
                pngPtr, raw.pointer, UIntNative(bytes.size),
                ioState, chunkType
            )
        } finally {
            releaseArrayRawData(raw)
        }
    }
}

func pngCClassicWriteEncodedBytes(
    pngPtr: CPointer<Unit>, bytes: Array<Byte>
): Unit {
    pngCClassicWriteBytes(
        pngPtr, bytes, PNG_C_CLASSIC_IO_WRITING, UInt32(0)
    )
}

private func pngCClassicChunkType(
    chunkName: CPointer<UInt8>
): Option<(UInt32, Array<Byte>)> {
    if (chunkName.isNull()) { return None }
    let bytes = Array<Byte>(Int64(4), repeat: UInt8(0))
    var index = Int64(0)
    while (index < Int64(4)) {
        bytes[index] = unsafe { chunkName.read(index) }
        index += Int64(1)
    }
    Some((
        (UInt32(bytes[Int64(0)]) << 24) |
            (UInt32(bytes[Int64(1)]) << 16) |
            (UInt32(bytes[Int64(2)]) << 8) |
            UInt32(bytes[Int64(3)]),
        bytes
    ))
}

private func pngCClassicCrcUpdatePointer(
    crcValue: UInt32,
    data: CPointer<UInt8>,
    length: UIntNative
): UInt32 {
    var crc = crcValue
    var index = UIntNative(0)
    while (index < length) {
        crc = crc ^ UInt32(unsafe { data.read(Int64(index)) })
        var bit = Int32(0)
        while (bit < Int32(8)) {
            crc = if ((crc & UInt32(1)) == UInt32(1)) {
                (crc >> 1) ^ UInt32(0xedb8_8320)
            } else {
                crc >> 1
            }
            bit += Int32(1)
        }
        index += UIntNative(1)
    }
    crc
}

@C
public func png_set_write_fn(
    pngPtr: CPointer<Unit>,
    ioPtr: CPointer<Unit>,
    writeDataFn: CPointer<Unit>,
    outputFlushFn: CPointer<Unit>
): Unit {
    if (pngPtr.isNull()) { return }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.writeOwner && !state.destroying &&
                    !state.writeCallbackActive &&
                    !state.writeChunkActive && !state.signatureWritten) {
                    state.ioPtr = ioPtr
                    state.writeFn = writeDataFn
                    state.flushFn = outputFlushFn
                }
            case None => ()
        }
    }
}

@C
public func png_write_sig(pngPtr: CPointer<Unit>): Unit {
    if (pngPtr.isNull()) { return }
    var start = Int32(-1)
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.writeOwner && !state.destroying &&
                    !state.writeCallbackActive &&
                    !state.writeChunkActive && !state.signatureWritten) {
                    state.signatureWritten = true
                    start = Int32(state.sigBytes)
                }
            case None => ()
        }
    }
    if (start < Int32(0)) { return }
    let bytes = ArrayList<Byte>()
    var index = Int64(start)
    while (index < Int64(8)) {
        bytes.add(PNG_C_CLASSIC_WRITE_SIGNATURE[index])
        index += Int64(1)
    }
    pngCClassicWriteBytes(
        pngPtr, bytes.toArray(),
        PNG_C_CLASSIC_IO_WRITING | PNG_C_CLASSIC_IO_SIGNATURE,
        UInt32(0)
    )
}

@C
public func png_write_chunk_start(
    pngPtr: CPointer<Unit>,
    chunkName: CPointer<UInt8>,
    length: UInt32
): Unit {
    if (pngPtr.isNull()) { return }
    if (length > PNG_UINT_31_MAX) {
        pngCClassicErrorText(pngPtr, "length exceeds PNG maximum")
        return
    }
    match (pngCClassicChunkType(chunkName)) {
        case Some((chunkType, typeBytes)) =>
            var accepted = false
            var sequencingError = false
            synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
                match (PNG_C_CLASSIC_READ_REGISTRY.get(
                    pngPtr.toUIntNative()
                )) {
                    case Some(state) =>
                        if (state.writeOwner && !state.destroying &&
                            !state.writeCallbackActive) {
                            if (state.writeChunkActive) {
                                sequencingError = true
                            } else {
                                state.writeChunkActive = true
                                state.writeChunkRemaining = UInt64(length)
                                state.writeChunkCrc = pngCrc32Update(
                                    pngCrc32Start(), typeBytes
                                )
                                state.ioChunkType = chunkType
                                accepted = true
                            }
                        }
                    case None => ()
                }
            }
            if (sequencingError) {
                pngCClassicErrorText(
                    pngPtr, "png_write_chunk_start: chunk already active"
                )
                return
            }
            if (!accepted) { return }
            let header = Array<Byte>(Int64(8), repeat: UInt8(0))
            let lengthBytes = writeUInt32Be(length)
            var index = Int64(0)
            while (index < Int64(4)) {
                header[index] = lengthBytes[index]
                header[index + Int64(4)] = typeBytes[index]
                index += Int64(1)
            }
            pngCClassicWriteBytes(
                pngPtr, header,
                PNG_C_CLASSIC_IO_WRITING |
                    PNG_C_CLASSIC_IO_CHUNK_HEADER,
                chunkType
            )
        case None =>
            pngCClassicErrorText(pngPtr, "Invalid chunk type")
    }
}

@C
public func png_write_chunk_data(
    pngPtr: CPointer<Unit>,
    data: CPointer<UInt8>,
    length: UIntNative
): Unit {
    if (pngPtr.isNull()) { return }
    if (length > UIntNative(0) && data.isNull()) {
        pngCClassicErrorText(pngPtr, "Invalid chunk data")
        return
    }
    if (length == UIntNative(0)) { return }

    var chunkType = UInt32(0)
    var accepted = false
    var sequencingError = false
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.writeOwner && !state.destroying &&
                    !state.writeCallbackActive) {
                    if (!state.writeChunkActive ||
                        UInt64(length) > state.writeChunkRemaining) {
                        sequencingError = true
                    } else {
                        chunkType = state.ioChunkType
                        accepted = true
                    }
                }
            case None => ()
        }
    }
    if (sequencingError) {
        pngCClassicErrorText(
            pngPtr, "png_write_chunk_data: declared length exceeded"
        )
        return
    }
    if (!accepted) { return }

    match (pngCClassicBeginWriteCallback(
        pngPtr,
        PNG_C_CLASSIC_IO_WRITING | PNG_C_CLASSIC_IO_CHUNK_DATA,
        chunkType
    )) {
        case Some(snapshot) =>
            let success = try {
                let written = pngCClassicInvokeWriteCallback(
                    pngPtr, snapshot, data, length
                )
                if (written) {
                    let crc = pngCClassicCrcUpdatePointer(
                        snapshot.state.writeChunkCrc, data, length
                    )
                    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
                        snapshot.state.writeChunkCrc = crc
                        snapshot.state.writeChunkRemaining -= UInt64(length)
                    }
                }
                written
            } finally {
                pngCClassicEndWriteCallback(snapshot.state)
            }
            if (!success) { pngCClassicErrorText(pngPtr, "Write Error") }
        case None => ()
    }
}

@C
public func png_write_chunk_end(pngPtr: CPointer<Unit>): Unit {
    if (pngPtr.isNull()) { return }
    var chunkType = UInt32(0)
    var crc = UInt32(0)
    var accepted = false
    var sequencingError = false
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.writeOwner && !state.destroying &&
                    !state.writeCallbackActive) {
                    if (!state.writeChunkActive ||
                        state.writeChunkRemaining != UInt64(0)) {
                        sequencingError = true
                    } else {
                        chunkType = state.ioChunkType
                        crc = pngCrc32Finish(state.writeChunkCrc)
                        accepted = true
                    }
                }
            case None => ()
        }
    }
    if (sequencingError) {
        pngCClassicErrorText(
            pngPtr, "png_write_chunk_end: declared length not satisfied"
        )
        return
    }
    if (!accepted) { return }
    pngCClassicWriteBytes(
        pngPtr, writeUInt32Be(crc),
        PNG_C_CLASSIC_IO_WRITING | PNG_C_CLASSIC_IO_CHUNK_CRC,
        chunkType
    )
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.writeOwner) {
                    state.writeChunkActive = false
                    state.writeChunkRemaining = UInt64(0)
                }
            case None => ()
        }
    }
}

@C
public func png_write_chunk(
    pngPtr: CPointer<Unit>,
    chunkName: CPointer<UInt8>,
    data: CPointer<UInt8>,
    length: UIntNative
): Unit {
    if (pngPtr.isNull()) { return }
    if (length > UIntNative(PNG_UINT_31_MAX)) {
        pngCClassicErrorText(pngPtr, "length exceeds PNG maximum")
        return
    }
    unsafe {
        png_write_chunk_start(pngPtr, chunkName, UInt32(length))
        png_write_chunk_data(pngPtr, data, length)
        png_write_chunk_end(pngPtr)
    }
}

@C
public func png_write_flush(pngPtr: CPointer<Unit>): Unit {
    if (pngPtr.isNull()) { return }
    var chunkType = UInt32(0)
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) => chunkType = state.ioChunkType
            case None => ()
        }
    }
    match (pngCClassicBeginWriteCallback(
        pngPtr, PNG_C_CLASSIC_IO_WRITING, chunkType
    )) {
        case Some(snapshot) =>
            let success = try {
                if (!snapshot.flushFn.isNull()) {
                    let function = CFunc<(CPointer<Unit>) -> Unit>(
                        snapshot.flushFn
                    )
                    unsafe { function(pngPtr) }
                    true
                } else if (snapshot.writeFn.isNull()) {
                    unsafe {
                        !snapshot.ioPtr.isNull() &&
                            fflush(snapshot.ioPtr) == Int32(0)
                    }
                } else {
                    true
                }
            } finally {
                pngCClassicEndWriteCallback(snapshot.state)
            }
            if (!success) { pngCClassicErrorText(pngPtr, "Flush Error") }
        case None => ()
    }
}
