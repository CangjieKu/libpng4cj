package libpng4cj

import std.collection.HashMap
import std.sync.Mutex

foreign func abort(): Unit
foreign func malloc(size: UIntNative): CPointer<Unit>
foreign func free(pointer: CPointer<Unit>): Unit
foreign func memset(
    destination: CPointer<Unit>, value: Int32, size: UIntNative
): CPointer<Unit>

private let PNG_C_CLASSIC_STRUCT_SIZE = UIntNative(1224)
private let PNG_C_CLASSIC_INFO_SIZE = UIntNative(352)

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
                    PNG_C_CLASSIC_INFO_REGISTRY.remove(handle.toUIntNative())
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
                if (!state.destroying && !state.allocatorCallbackActive) {
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
