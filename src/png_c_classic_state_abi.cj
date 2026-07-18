package libpng4cj

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex

foreign func abort(): Unit
foreign func malloc(size: UIntNative): CPointer<Unit>
foreign func free(pointer: CPointer<Unit>): Unit
foreign func memset(
    destination: CPointer<Unit>, value: Int32, size: UIntNative
): CPointer<Unit>

private let PNG_C_CLASSIC_STRUCT_SIZE = UIntNative(1224)
private let PNG_C_CLASSIC_INFO_SIZE = UIntNative(352)
private let PNG_C_CLASSIC_MAX_INPUT_BYTES = UInt64(512_000_000)
private let PNG_C_CLASSIC_SIGNATURE = [
    UInt8(137), UInt8(80), UInt8(78), UInt8(71),
    UInt8(13), UInt8(10), UInt8(26), UInt8(10)
]

private class PngCClassicAllocatorSnapshot {
    let memPtr: CPointer<Unit>
    let mallocFn: CPointer<Unit>
    let freeFn: CPointer<Unit>

    init(
        memPtr: CPointer<Unit>,
        mallocFn: CPointer<Unit>,
        freeFn: CPointer<Unit>
    ) {
        this.memPtr = memPtr
        this.mallocFn = mallocFn
        this.freeFn = freeFn
    }
}

private class PngCClassicReadState {
    var errorPtr: CPointer<Unit>
    var errorFn: CPointer<Unit>
    var warningFn: CPointer<Unit>
    var memPtr: CPointer<Unit>
    var mallocFn: CPointer<Unit>
    var freeFn: CPointer<Unit>
    var allocatorCallbackActive = false
    var allocatorCallbackMemPtr = CPointer<Unit>()
    var ioPtr = CPointer<Unit>()
    var readFn = CPointer<Unit>()
    var sigBytes = UInt8(0)
    var readOperationActive = false
    var decodedRows: Option<PngDecodedRows> = None
    var decodedInfoHandle = UIntNative(0)
    var destroying = false
    let allocatorMutex = Mutex()
    let selfAllocator: PngCClassicAllocatorSnapshot

    init(
        errorPtr: CPointer<Unit>,
        errorFn: CPointer<Unit>,
        warningFn: CPointer<Unit>,
        memPtr: CPointer<Unit>,
        mallocFn: CPointer<Unit>,
        freeFn: CPointer<Unit>
    ) {
        this.errorPtr = errorPtr
        this.errorFn = errorFn
        this.warningFn = warningFn
        this.memPtr = memPtr
        this.mallocFn = mallocFn
        this.freeFn = freeFn
        selfAllocator = PngCClassicAllocatorSnapshot(memPtr, mallocFn, freeFn)
    }
}

private class PngCClassicInfoState {
    let owner: UIntNative
    let readState: PngCClassicReadState
    let allocator: PngCClassicAllocatorSnapshot

    init(
        owner: UIntNative,
        readState: PngCClassicReadState,
        allocator: PngCClassicAllocatorSnapshot
    ) {
        this.owner = owner
        this.readState = readState
        this.allocator = allocator
    }
}

private class PngCClassicTrackedAllocation {
    let owner: UIntNative
    let readState: PngCClassicReadState
    let allocator: PngCClassicAllocatorSnapshot
    var released = false

    init(
        owner: UIntNative,
        readState: PngCClassicReadState,
        allocator: PngCClassicAllocatorSnapshot
    ) {
        this.owner = owner
        this.readState = readState
        this.allocator = allocator
    }
}

private let PNG_C_CLASSIC_REGISTRY_MUTEX = Mutex()
private let PNG_C_CLASSIC_READ_REGISTRY =
    HashMap<UIntNative, PngCClassicReadState>()
private let PNG_C_CLASSIC_INFO_REGISTRY =
    HashMap<UIntNative, PngCClassicInfoState>()
private let PNG_C_CLASSIC_ALLOCATION_REGISTRY =
    HashMap<UIntNative, PngCClassicTrackedAllocation>()

private func pngCClassicDefaultAllocate(size: UIntNative): CPointer<Unit> {
    unsafe { malloc(size) }
}

private func pngCClassicDefaultFree(pointer: CPointer<Unit>): Unit {
    unsafe { free(pointer) }
}

private func pngCClassicCompatibleVersion(userPngVer: CString): Bool {
    if (userPngVer.isNull()) { return false }
    let chars = userPngVer.getChars()
    unsafe {
        chars.read(Int64(0)) == UInt8(49) &&
            chars.read(Int64(1)) == UInt8(46) &&
            chars.read(Int64(2)) == UInt8(54) &&
            chars.read(Int64(3)) == UInt8(46)
    }
}

private func pngCClassicRegisterReadAlias(
    handle: CPointer<Unit>, state: PngCClassicReadState
): Bool {
    if (handle.isNull()) { return false }
    try {
        synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
            let key = handle.toUIntNative()
            if (PNG_C_CLASSIC_READ_REGISTRY.get(key).isSome() ||
                PNG_C_CLASSIC_INFO_REGISTRY.get(key).isSome()) {
                return false
            }
            match (PNG_C_CLASSIC_ALLOCATION_REGISTRY.get(key)) {
                case Some(allocation) =>
                    if (!allocation.released) { return false }
                case None => ()
            }
            PNG_C_CLASSIC_READ_REGISTRY[key] = state
        }
        true
    } catch (_: Exception) {
        false
    }
}

private func pngCClassicRemoveReadAlias(handle: CPointer<Unit>): Unit {
    if (handle.isNull()) { return }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        PNG_C_CLASSIC_READ_REGISTRY.remove(handle.toUIntNative())
    }
}

private func pngCClassicCurrentAllocator(
    handle: CPointer<Unit>
): Option<(PngCClassicReadState, PngCClassicAllocatorSnapshot)> {
    if (handle.isNull()) { return None }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(handle.toUIntNative())) {
            case Some(state) =>
                if (state.destroying) {
                    None
                } else {
                    Some((state, PngCClassicAllocatorSnapshot(
                        state.memPtr, state.mallocFn, state.freeFn
                    )))
                }
            case None => None
        }
    }
}

private func pngCClassicBeginAllocatorCallback(
    handle: CPointer<Unit>,
    state: PngCClassicReadState,
    memPtr: CPointer<Unit>
): Bool {
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        if (PNG_C_CLASSIC_READ_REGISTRY.get(
            handle.toUIntNative()
        ).isNone()) {
            return false
        }
        state.allocatorCallbackMemPtr = memPtr
        state.allocatorCallbackActive = true
        true
    }
}

private func pngCClassicEndAllocatorCallback(
    state: PngCClassicReadState
): Unit {
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        state.allocatorCallbackActive = false
        state.allocatorCallbackMemPtr = CPointer<Unit>()
    }
}

private func pngCClassicAllocateWith(
    handle: CPointer<Unit>,
    state: PngCClassicReadState,
    allocator: PngCClassicAllocatorSnapshot,
    size: UIntNative
): CPointer<Unit> {
    if (allocator.mallocFn.isNull()) {
        return pngCClassicDefaultAllocate(size)
    }
    synchronized(state.allocatorMutex) {
        if (!pngCClassicBeginAllocatorCallback(
            handle, state, allocator.memPtr
        )) {
            return CPointer<Unit>()
        }
        try {
            let function = CFunc<(
                CPointer<Unit>, UIntNative
            ) -> CPointer<Unit>>(allocator.mallocFn)
            unsafe { function(handle, size) }
        } finally {
            pngCClassicEndAllocatorCallback(state)
        }
    }
}

private func pngCClassicFreeWith(
    handle: CPointer<Unit>,
    state: PngCClassicReadState,
    allocator: PngCClassicAllocatorSnapshot,
    pointer: CPointer<Unit>
): Unit {
    if (pointer.isNull()) { return }
    if (allocator.freeFn.isNull()) {
        pngCClassicDefaultFree(pointer)
        return
    }
    synchronized(state.allocatorMutex) {
        if (!pngCClassicBeginAllocatorCallback(
            handle, state, allocator.memPtr
        )) {
            return
        }
        try {
            let function = CFunc<(
                CPointer<Unit>, CPointer<Unit>
            ) -> Unit>(allocator.freeFn)
            unsafe { function(handle, pointer) }
        } finally {
            pngCClassicEndAllocatorCallback(state)
        }
    }
}

private func pngCClassicCallback(
    handle: CPointer<Unit>, warning: Bool
): CPointer<Unit> {
    if (handle.isNull()) { return CPointer<Unit>() }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(handle.toUIntNative())) {
            case Some(state) =>
                if (warning) { state.warningFn } else { state.errorFn }
            case None => CPointer<Unit>()
        }
    }
}

private func pngCClassicInvokeCallback(
    handle: CPointer<Unit>, message: CString, warning: Bool
): Bool {
    let callback = pngCClassicCallback(handle, warning)
    if (callback.isNull()) { return false }
    let function = CFunc<(CPointer<Unit>, CString) -> Unit>(callback)
    unsafe { function(handle, message) }
    true
}

private func pngCClassicDefaultDiagnostic(
    kind: String, message: CString, fallback: String
): Unit {
    try {
        let text = if (message.isNull()) {
            fallback
        } else {
            message.toString()
        }
        eprintln("libpng ${kind}: ${text}")
    } catch (_: Exception) {
        ()
    }
}

private func pngCClassicWarningText(
    handle: CPointer<Unit>, message: String
): Unit {
    let text = unsafe { LibC.mallocCString(message) }
    try {
        unsafe { png_warning(handle, text) }
    } finally {
        unsafe { LibC.free(text) }
    }
}

private func pngCClassicErrorText(
    handle: CPointer<Unit>, message: String
): Unit {
    let text = unsafe { LibC.mallocCString(message) }
    unsafe { png_error(handle, text) }
}

private func pngCClassicCreateRead(
    userPngVer: CString,
    errorPtr: CPointer<Unit>,
    errorFn: CPointer<Unit>,
    warningFn: CPointer<Unit>,
    memPtr: CPointer<Unit>,
    mallocFn: CPointer<Unit>,
    freeFn: CPointer<Unit>
): CPointer<Unit> {
    if (!pngCClassicCompatibleVersion(userPngVer)) {
        return CPointer<Unit>()
    }

    let state = PngCClassicReadState(
        errorPtr, errorFn, warningFn, memPtr, mallocFn, freeFn
    )
    let creationHandle = pngCClassicDefaultAllocate(UIntNative(1))
    if (!pngCClassicRegisterReadAlias(creationHandle, state)) {
        if (!creationHandle.isNull()) {
            pngCClassicDefaultFree(creationHandle)
        }
        return CPointer<Unit>()
    }

    let handle = pngCClassicAllocateWith(
        creationHandle, state, state.selfAllocator,
        PNG_C_CLASSIC_STRUCT_SIZE
    )
    if (handle.isNull()) {
        pngCClassicWarningText(creationHandle, "Out of memory")
        pngCClassicRemoveReadAlias(creationHandle)
        pngCClassicDefaultFree(creationHandle)
        return CPointer<Unit>()
    }

    if (!pngCClassicRegisterReadAlias(handle, state)) {
        pngCClassicFreeWith(
            creationHandle, state, state.selfAllocator, handle
        )
        pngCClassicRemoveReadAlias(creationHandle)
        pngCClassicDefaultFree(creationHandle)
        return CPointer<Unit>()
    }

    pngCClassicRemoveReadAlias(creationHandle)
    pngCClassicDefaultFree(creationHandle)
    handle
}

private func pngCClassicRegisterInfo(
    owner: CPointer<Unit>
): CPointer<Unit> {
    let allocationContext = pngCClassicCurrentAllocator(owner)
    match (allocationContext) {
        case Some((state, allocator)) =>
            let handle = pngCClassicAllocateWith(
                owner, state, allocator, PNG_C_CLASSIC_INFO_SIZE
            )
            if (handle.isNull()) { return CPointer<Unit>() }
            var registered = false
            try {
                synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
                    let key = handle.toUIntNative()
                    if (PNG_C_CLASSIC_READ_REGISTRY.get(key).isNone() &&
                        PNG_C_CLASSIC_INFO_REGISTRY.get(key).isNone()) {
                        PNG_C_CLASSIC_INFO_REGISTRY[key] =
                            PngCClassicInfoState(
                                owner.toUIntNative(), state, allocator
                            )
                        registered = true
                    }
                }
            } catch (_: Exception) {
                ()
            }
            if (registered) {
                unsafe { memset(handle, Int32(0), PNG_C_CLASSIC_INFO_SIZE) }
                handle
            } else {
                pngCClassicFreeWith(owner, state, allocator, handle)
                CPointer<Unit>()
            }
        case None => CPointer<Unit>()
    }
}

private func pngCClassicReleaseInfo(
    owner: CPointer<Unit>, infoPtrPtr: CPointer<CPointer<Unit>>
): Unit {
    if (owner.isNull() || infoPtrPtr.isNull()) { return }
    let handle = unsafe { infoPtrPtr.read() }
    if (handle.isNull()) { return }

    var released: Option<PngCClassicInfoState> = None
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_INFO_REGISTRY.get(handle.toUIntNative())) {
            case Some(infoState) =>
                if (infoState.owner == owner.toUIntNative() &&
                    PNG_C_CLASSIC_READ_REGISTRY.get(
                        infoState.owner
                    ).isSome()) {
                    let key = handle.toUIntNative()
                    PNG_C_CLASSIC_INFO_REGISTRY.remove(key)
                    if (infoState.readState.decodedInfoHandle == key) {
                        infoState.readState.decodedInfoHandle = UIntNative(0)
                    }
                    unsafe { infoPtrPtr.write(CPointer<Unit>()) }
                    released = Some(infoState)
                }
            case None => ()
        }
    }
    match (released) {
        case Some(infoState) =>
            pngCClassicFreeWith(
                owner, infoState.readState, infoState.allocator, handle
            )
        case None => ()
    }
}

private func pngCClassicReleaseRead(
    pngPtrPtr: CPointer<CPointer<Unit>>
): Unit {
    if (pngPtrPtr.isNull()) { return }
    let handle = unsafe { pngPtrPtr.read() }
    if (handle.isNull()) { return }

    var released: Option<PngCClassicReadState> = None
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(handle.toUIntNative())) {
            case Some(state) =>
                if (!state.destroying && !state.allocatorCallbackActive &&
                    !state.readOperationActive) {
                    state.destroying = true
                    unsafe { pngPtrPtr.write(CPointer<Unit>()) }
                    released = Some(state)
                }
            case None => ()
        }
    }
    match (released) {
        case Some(state) =>
            pngCClassicFreeWith(
                handle, state, state.selfAllocator, handle
            )
            pngCClassicRemoveReadAlias(handle)
        case None => ()
    }
}

private func pngCClassicBeginReadInfo(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Option<(
    PngCClassicReadState, CPointer<Unit>, CPointer<Unit>, UInt8
)> {
    if (pngPtr.isNull() || infoPtr.isNull()) { return None }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                match (PNG_C_CLASSIC_INFO_REGISTRY.get(
                    infoPtr.toUIntNative()
                )) {
                    case Some(infoState) =>
                        if (infoState.owner != pngPtr.toUIntNative() ||
                            state.destroying || state.readOperationActive ||
                            state.decodedRows.isSome()) {
                            None
                        } else {
                            state.readOperationActive = true
                            Some((state, state.ioPtr, state.readFn, state.sigBytes))
                        }
                    case None => None
                }
            case None => None
        }
    }
}

private func pngCClassicEndReadInfo(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    state: PngCClassicReadState,
    decoded: Option<PngDecodedRows>
): Unit {
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(_) =>
                match (decoded) {
                    case Some(value) =>
                        state.decodedRows = Some(value)
                        state.decodedInfoHandle = infoPtr.toUIntNative()
                    case None => ()
                }
                state.readOperationActive = false
            case None => state.readOperationActive = false
        }
    }
}

private func pngCClassicDecodedIhdr(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Option<PngIhdr> {
    if (pngPtr.isNull() || infoPtr.isNull()) { return None }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                match (PNG_C_CLASSIC_INFO_REGISTRY.get(
                    infoPtr.toUIntNative()
                )) {
                    case Some(infoState) =>
                        if (state.destroying ||
                            infoState.owner != pngPtr.toUIntNative() ||
                            state.decodedInfoHandle != infoPtr.toUIntNative()) {
                            None
                        } else {
                            match (state.decodedRows) {
                                case Some(decoded) => Some(decoded.ihdr)
                                case None => None
                            }
                        }
                    case None => None
                }
            case None => None
        }
    }
}

private func pngCClassicReadExact(
    pngPtr: CPointer<Unit>,
    ioPtr: CPointer<Unit>,
    readFn: CPointer<Unit>,
    length: Int64
): Array<Byte> {
    if (length < Int64(0)) {
        throw PngFormatException(
            InvalidArgument, -1, "classic read length must be non-negative"
        )
    }
    let bytes = Array<Byte>(length, repeat: UInt8(0))
    if (length == Int64(0)) { return bytes }
    unsafe {
        let raw = acquireArrayRawData(bytes)
        try {
            if (!readFn.isNull()) {
                let function = CFunc<(
                    CPointer<Unit>, CPointer<UInt8>, UIntNative
                ) -> Unit>(readFn)
                function(pngPtr, raw.pointer, UIntNative(length))
            } else {
                if (ioPtr.isNull() || fread(
                    raw.pointer, UIntNative(1), UIntNative(length), ioPtr
                ) != UIntNative(length)) {
                    throw PngFormatException(
                        TruncatedInput, -1, "Read Error"
                    )
                }
            }
        } finally {
            releaseArrayRawData(raw)
        }
    }
    bytes
}

private func pngCClassicAppendInput(
    output: ArrayList<Byte>, bytes: Array<Byte>, total: UInt64
): UInt64 {
    let next = total + UInt64(bytes.size)
    if (next < total || next > PNG_C_CLASSIC_MAX_INPUT_BYTES) {
        throw PngFormatException(
            DecodeLimitExceeded, -1,
            "classic input exceeds the configured byte limit"
        )
    }
    var index: Int64 = Int64(0)
    while (index < bytes.size) {
        output.add(bytes[index])
        index += Int64(1)
    }
    next
}

private func pngCClassicCaptureInput(
    pngPtr: CPointer<Unit>,
    ioPtr: CPointer<Unit>,
    readFn: CPointer<Unit>,
    sigBytes: UInt8
): Array<Byte> {
    let input = ArrayList<Byte>()
    var total = UInt64(0)
    var prefix: Int64 = Int64(0)
    while (prefix < Int64(sigBytes)) {
        input.add(PNG_C_CLASSIC_SIGNATURE[prefix])
        prefix += Int64(1)
        total += UInt64(1)
    }
    let signatureTail = pngCClassicReadExact(
        pngPtr, ioPtr, readFn, Int64(8) - Int64(sigBytes)
    )
    total = pngCClassicAppendInput(input, signatureTail, total)

    var done = false
    while (!done) {
        if (UInt64(8) > PNG_C_CLASSIC_MAX_INPUT_BYTES - total) {
            throw PngFormatException(
                DecodeLimitExceeded, -1,
                "classic input exceeds the configured byte limit"
            )
        }
        let header = pngCClassicReadExact(
            pngPtr, ioPtr, readFn, Int64(8)
        )
        total = pngCClassicAppendInput(input, header, total)
        let length = readUInt32Be(header, Int64(0))
        if (length > PNG_UINT_31_MAX) {
            throw PngFormatException(
                ChunkTooLarge, -1, "PNG chunk length exceeds 31-bit limit"
            )
        }
        let bodySize = UInt64(length) + UInt64(4)
        if (bodySize > PNG_C_CLASSIC_MAX_INPUT_BYTES - total) {
            throw PngFormatException(
                DecodeLimitExceeded, -1,
                "classic input exceeds the configured byte limit"
            )
        }
        let payloadAndCrc = pngCClassicReadExact(
            pngPtr, ioPtr, readFn, Int64(bodySize)
        )
        total = pngCClassicAppendInput(input, payloadAndCrc, total)
        done = header[Int64(4)] == UInt8(73) &&
            header[Int64(5)] == UInt8(69) &&
            header[Int64(6)] == UInt8(78) &&
            header[Int64(7)] == UInt8(68)
    }
    input.toArray()
}

private func pngCClassicAllocateTracked(
    pngPtr: CPointer<Unit>, size: UIntNative
): CPointer<Unit> {
    match (pngCClassicCurrentAllocator(pngPtr)) {
        case Some((state, allocator)) =>
            let pointer = pngCClassicAllocateWith(
                pngPtr, state, allocator, size
            )
            if (pointer.isNull()) { return CPointer<Unit>() }
            var registered = false
            try {
                synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
                    let key = pointer.toUIntNative()
                    if (PNG_C_CLASSIC_READ_REGISTRY.get(key).isNone() &&
                        PNG_C_CLASSIC_INFO_REGISTRY.get(key).isNone()) {
                        PNG_C_CLASSIC_ALLOCATION_REGISTRY[key] =
                            PngCClassicTrackedAllocation(
                                pngPtr.toUIntNative(), state, allocator
                            )
                        registered = true
                    }
                }
            } catch (_: Exception) {
                ()
            }
            if (registered) {
                pointer
            } else {
                pngCClassicFreeWith(pngPtr, state, allocator, pointer)
                CPointer<Unit>()
            }
        case None => CPointer<Unit>()
    }
}

@C
public func png_create_read_struct(
    userPngVer: CString,
    errorPtr: CPointer<Unit>,
    errorFn: CPointer<Unit>,
    warningFn: CPointer<Unit>
): CPointer<Unit> {
    pngCClassicCreateRead(
        userPngVer, errorPtr, errorFn, warningFn,
        CPointer<Unit>(), CPointer<Unit>(), CPointer<Unit>()
    )
}

@C
public func png_create_read_struct_2(
    userPngVer: CString,
    errorPtr: CPointer<Unit>,
    errorFn: CPointer<Unit>,
    warningFn: CPointer<Unit>,
    memPtr: CPointer<Unit>,
    mallocFn: CPointer<Unit>,
    freeFn: CPointer<Unit>
): CPointer<Unit> {
    pngCClassicCreateRead(
        userPngVer, errorPtr, errorFn, warningFn,
        memPtr, mallocFn, freeFn
    )
}

@C
public func png_create_info_struct(
    pngPtr: CPointer<Unit>
): CPointer<Unit> {
    pngCClassicRegisterInfo(pngPtr)
}

@C
public func png_destroy_info_struct(
    pngPtr: CPointer<Unit>, infoPtrPtr: CPointer<CPointer<Unit>>
): Unit {
    pngCClassicReleaseInfo(pngPtr, infoPtrPtr)
}

@C
public func png_destroy_read_struct(
    pngPtrPtr: CPointer<CPointer<Unit>>,
    infoPtrPtr: CPointer<CPointer<Unit>>,
    endInfoPtrPtr: CPointer<CPointer<Unit>>
): Unit {
    if (pngPtrPtr.isNull()) { return }
    let pngPtr = unsafe { pngPtrPtr.read() }
    if (pngPtr.isNull()) { return }
    pngCClassicReleaseInfo(pngPtr, endInfoPtrPtr)
    pngCClassicReleaseInfo(pngPtr, infoPtrPtr)
    pngCClassicReleaseRead(pngPtrPtr)
}

@C
public func png_set_error_fn(
    pngPtr: CPointer<Unit>,
    errorPtr: CPointer<Unit>,
    errorFn: CPointer<Unit>,
    warningFn: CPointer<Unit>
): Unit {
    if (pngPtr.isNull()) { return }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                state.errorPtr = errorPtr
                state.errorFn = errorFn
                state.warningFn = warningFn
            case None => ()
        }
    }
}

@C
public func png_get_error_ptr(
    pngPtr: CPointer<Unit>
): CPointer<Unit> {
    if (pngPtr.isNull()) { return CPointer<Unit>() }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) => state.errorPtr
            case None => CPointer<Unit>()
        }
    }
}

@C
public func png_set_mem_fn(
    pngPtr: CPointer<Unit>,
    memPtr: CPointer<Unit>,
    mallocFn: CPointer<Unit>,
    freeFn: CPointer<Unit>
): Unit {
    if (pngPtr.isNull()) { return }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                state.memPtr = memPtr
                state.mallocFn = mallocFn
                state.freeFn = freeFn
            case None => ()
        }
    }
}

@C
public func png_get_mem_ptr(
    pngPtr: CPointer<Unit>
): CPointer<Unit> {
    if (pngPtr.isNull()) { return CPointer<Unit>() }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.allocatorCallbackActive) {
                    state.allocatorCallbackMemPtr
                } else {
                    state.memPtr
                }
            case None => CPointer<Unit>()
        }
    }
}

@C
public func png_init_io(
    pngPtr: CPointer<Unit>, file: CPointer<Unit>
): Unit {
    if (pngPtr.isNull()) { return }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (!state.destroying && !state.readOperationActive) {
                    state.ioPtr = file
                    state.readFn = CPointer<Unit>()
                }
            case None => ()
        }
    }
}

@C
public func png_set_read_fn(
    pngPtr: CPointer<Unit>,
    ioPtr: CPointer<Unit>,
    readDataFn: CPointer<Unit>
): Unit {
    if (pngPtr.isNull()) { return }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (!state.destroying && !state.readOperationActive) {
                    state.ioPtr = ioPtr
                    state.readFn = readDataFn
                }
            case None => ()
        }
    }
}

@C
public func png_get_io_ptr(
    pngPtr: CPointer<Unit>
): CPointer<Unit> {
    if (pngPtr.isNull()) { return CPointer<Unit>() }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) => state.ioPtr
            case None => CPointer<Unit>()
        }
    }
}

@C
public func png_set_sig_bytes(
    pngPtr: CPointer<Unit>, numBytes: Int32
): Unit {
    if (pngPtr.isNull()) { return }
    if (numBytes > Int32(8)) {
        pngCClassicErrorText(pngPtr, "Too many bytes for PNG signature")
        return
    }
    let count = if (numBytes < Int32(0)) { UInt8(0) } else {
        UInt8(numBytes)
    }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (!state.destroying && !state.readOperationActive) {
                    state.sigBytes = count
                }
            case None => ()
        }
    }
}

@C
public func png_read_info(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Unit {
    match (pngCClassicBeginReadInfo(pngPtr, infoPtr)) {
        case Some((state, ioPtr, readFn, sigBytes)) =>
            try {
                let input = pngCClassicCaptureInput(
                    pngPtr, ioPtr, readFn, sigBytes
                )
                let decoded = decodePng(input)
                pngCClassicEndReadInfo(
                    pngPtr, infoPtr, state, Some(decoded)
                )
            } catch (error: Exception) {
                pngCClassicEndReadInfo(pngPtr, infoPtr, state, None)
                pngCClassicErrorText(pngPtr, error.message)
            }
        case None => ()
    }
}

@C
public func png_get_rowbytes(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UIntNative {
    match (pngCClassicDecodedIhdr(pngPtr, infoPtr)) {
        case Some(ihdr) => UIntNative(ihdr.rowBytes)
        case None => UIntNative(0)
    }
}

@C
public func png_get_channels(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt8 {
    match (pngCClassicDecodedIhdr(pngPtr, infoPtr)) {
        case Some(ihdr) => ihdr.channels
        case None => UInt8(0)
    }
}

@C
public func png_get_image_width(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt32 {
    match (pngCClassicDecodedIhdr(pngPtr, infoPtr)) {
        case Some(ihdr) => ihdr.width
        case None => UInt32(0)
    }
}

@C
public func png_get_image_height(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt32 {
    match (pngCClassicDecodedIhdr(pngPtr, infoPtr)) {
        case Some(ihdr) => ihdr.height
        case None => UInt32(0)
    }
}

@C
public func png_get_bit_depth(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt8 {
    match (pngCClassicDecodedIhdr(pngPtr, infoPtr)) {
        case Some(ihdr) => ihdr.bitDepth
        case None => UInt8(0)
    }
}

@C
public func png_get_color_type(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt8 {
    match (pngCClassicDecodedIhdr(pngPtr, infoPtr)) {
        case Some(ihdr) => ihdr.colorType.encodedValue()
        case None => UInt8(0)
    }
}

@C
public func png_get_filter_type(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt8 {
    match (pngCClassicDecodedIhdr(pngPtr, infoPtr)) {
        case Some(ihdr) => ihdr.filterMethod
        case None => UInt8(0)
    }
}

@C
public func png_get_interlace_type(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt8 {
    match (pngCClassicDecodedIhdr(pngPtr, infoPtr)) {
        case Some(ihdr) => ihdr.interlaceMethod.encodedValue()
        case None => UInt8(0)
    }
}

@C
public func png_get_compression_type(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt8 {
    match (pngCClassicDecodedIhdr(pngPtr, infoPtr)) {
        case Some(ihdr) => ihdr.compressionMethod
        case None => UInt8(0)
    }
}

@C
public func png_get_IHDR(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    width: CPointer<UInt32>,
    height: CPointer<UInt32>,
    bitDepth: CPointer<Int32>,
    colorType: CPointer<Int32>,
    interlaceType: CPointer<Int32>,
    compressionType: CPointer<Int32>,
    filterType: CPointer<Int32>
): UInt32 {
    match (pngCClassicDecodedIhdr(pngPtr, infoPtr)) {
        case Some(ihdr) =>
            unsafe {
                if (!width.isNull()) { width.write(ihdr.width) }
                if (!height.isNull()) { height.write(ihdr.height) }
                if (!bitDepth.isNull()) {
                    bitDepth.write(Int32(ihdr.bitDepth))
                }
                if (!colorType.isNull()) {
                    colorType.write(Int32(ihdr.colorType.encodedValue()))
                }
                if (!interlaceType.isNull()) {
                    interlaceType.write(Int32(
                        ihdr.interlaceMethod.encodedValue()
                    ))
                }
                if (!compressionType.isNull()) {
                    compressionType.write(Int32(ihdr.compressionMethod))
                }
                if (!filterType.isNull()) {
                    filterType.write(Int32(ihdr.filterMethod))
                }
            }
            UInt32(1)
        case None => UInt32(0)
    }
}

@C
public func png_malloc(
    pngPtr: CPointer<Unit>, size: UIntNative
): CPointer<Unit> {
    if (pngPtr.isNull()) { return CPointer<Unit>() }
    let pointer = pngCClassicAllocateTracked(pngPtr, size)
    if (pointer.isNull()) {
        pngCClassicErrorText(pngPtr, "Out of memory")
    }
    pointer
}

@C
public func png_calloc(
    pngPtr: CPointer<Unit>, size: UIntNative
): CPointer<Unit> {
    let pointer = unsafe { png_malloc(pngPtr, size) }
    if (!pointer.isNull()) {
        unsafe { memset(pointer, Int32(0), size) }
    }
    pointer
}

@C
public func png_malloc_warn(
    pngPtr: CPointer<Unit>, size: UIntNative
): CPointer<Unit> {
    if (pngPtr.isNull()) { return CPointer<Unit>() }
    let pointer = pngCClassicAllocateTracked(pngPtr, size)
    if (pointer.isNull()) {
        pngCClassicWarningText(pngPtr, "Out of memory")
    }
    pointer
}

@C
public func png_malloc_default(
    pngPtr: CPointer<Unit>, size: UIntNative
): CPointer<Unit> {
    if (pngPtr.isNull()) { return CPointer<Unit>() }
    pngCClassicDefaultAllocate(size)
}

@C
public func png_free(
    pngPtr: CPointer<Unit>, pointer: CPointer<Unit>
): Unit {
    if (pngPtr.isNull() || pointer.isNull()) { return }
    var tracked: Option<PngCClassicTrackedAllocation> = None
    var knownTracked = false
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_ALLOCATION_REGISTRY.get(
            pointer.toUIntNative()
        )) {
            case Some(allocation) =>
                knownTracked = true
                if (allocation.owner == pngPtr.toUIntNative()) {
                    if (!allocation.released) {
                        allocation.released = true
                        tracked = Some(allocation)
                    }
                }
            case None => ()
        }
    }
    match (tracked) {
        case Some(allocation) =>
            pngCClassicFreeWith(
                pngPtr, allocation.readState,
                allocation.allocator, pointer
            )
        case None =>
            if (knownTracked) { return }
            match (pngCClassicCurrentAllocator(pngPtr)) {
                case Some((state, allocator)) =>
                    pngCClassicFreeWith(
                        pngPtr, state, allocator, pointer
                    )
                case None => ()
            }
    }
}

@C
public func png_free_default(
    pngPtr: CPointer<Unit>, pointer: CPointer<Unit>
): Unit {
    if (pngPtr.isNull() || pointer.isNull()) { return }
    pngCClassicDefaultFree(pointer)
}

@C
public func png_warning(
    pngPtr: CPointer<Unit>, warningMessage: CString
): Unit {
    if (!pngCClassicInvokeCallback(pngPtr, warningMessage, true)) {
        pngCClassicDefaultDiagnostic("warning", warningMessage, "")
    }
}

@C
public func png_error(
    pngPtr: CPointer<Unit>, errorMessage: CString
): Unit {
    pngCClassicInvokeCallback(pngPtr, errorMessage, false)
    pngCClassicDefaultDiagnostic("error", errorMessage, "undefined")
    unsafe { abort() }
}
