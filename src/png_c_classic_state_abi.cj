package libpng4cj

import std.collection.HashMap
import std.sync.Mutex

foreign func abort(): Unit

private class PngCClassicReadState {
    var errorPtr: CPointer<Unit>
    var errorFn: CPointer<Unit>
    var warningFn: CPointer<Unit>
    var memPtr: CPointer<Unit>
    var mallocFn: CPointer<Unit>
    var freeFn: CPointer<Unit>

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
    }
}

private class PngCClassicInfoState {
    let owner: UIntNative

    init(owner: UIntNative) {
        this.owner = owner
    }
}

private let PNG_C_CLASSIC_REGISTRY_MUTEX = Mutex()
private let PNG_C_CLASSIC_READ_REGISTRY =
    HashMap<UIntNative, PngCClassicReadState>()
private let PNG_C_CLASSIC_INFO_REGISTRY =
    HashMap<UIntNative, PngCClassicInfoState>()

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

private func pngCClassicRegisterRead(
    state: PngCClassicReadState
): CPointer<Unit> {
    let token = unsafe { LibC.malloc<UInt8>() }
    if (token.isNull()) { return CPointer<Unit>() }
    let handle = CPointer<Unit>(token)
    try {
        synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
            PNG_C_CLASSIC_READ_REGISTRY[handle.toUIntNative()] = state
        }
        handle
    } catch (_: Exception) {
        unsafe { LibC.free(handle) }
        CPointer<Unit>()
    }
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
    pngCClassicRegisterRead(PngCClassicReadState(
        errorPtr, errorFn, warningFn, memPtr, mallocFn, freeFn
    ))
}

private func pngCClassicReadExists(handle: CPointer<Unit>): Bool {
    if (handle.isNull()) { return false }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        PNG_C_CLASSIC_READ_REGISTRY.get(handle.toUIntNative()).isSome()
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

private func pngCClassicRegisterInfo(
    owner: CPointer<Unit>
): CPointer<Unit> {
    if (!pngCClassicReadExists(owner)) { return CPointer<Unit>() }
    let token = unsafe { LibC.malloc<UInt8>() }
    if (token.isNull()) { return CPointer<Unit>() }
    let handle = CPointer<Unit>(token)
    try {
        var registered = false
        synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
            if (PNG_C_CLASSIC_READ_REGISTRY.get(owner.toUIntNative()).isSome()) {
                PNG_C_CLASSIC_INFO_REGISTRY[handle.toUIntNative()] =
                    PngCClassicInfoState(owner.toUIntNative())
                registered = true
            }
        }
        if (registered) {
            handle
        } else {
            unsafe { LibC.free(handle) }
            CPointer<Unit>()
        }
    } catch (_: Exception) {
        unsafe { LibC.free(handle) }
        CPointer<Unit>()
    }
}

private func pngCClassicReleaseInfo(
    owner: CPointer<Unit>, infoPtrPtr: CPointer<CPointer<Unit>>
): Unit {
    if (owner.isNull() || infoPtrPtr.isNull()) { return }
    let handle = unsafe { infoPtrPtr.read() }
    if (handle.isNull()) { return }

    var released = false
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_INFO_REGISTRY.get(handle.toUIntNative())) {
            case Some(state) =>
                if (state.owner == owner.toUIntNative() &&
                    PNG_C_CLASSIC_READ_REGISTRY.get(state.owner).isSome()) {
                    PNG_C_CLASSIC_INFO_REGISTRY.remove(handle.toUIntNative())
                    released = true
                }
            case None => ()
        }
    }
    if (released) {
        unsafe {
            infoPtrPtr.write(CPointer<Unit>())
            LibC.free(handle)
        }
    }
}

private func pngCClassicReleaseRead(
    pngPtrPtr: CPointer<CPointer<Unit>>
): Unit {
    if (pngPtrPtr.isNull()) { return }
    let handle = unsafe { pngPtrPtr.read() }
    if (handle.isNull()) { return }

    var released = false
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.remove(handle.toUIntNative())) {
            case Some(_) => released = true
            case None => ()
        }
    }
    if (released) {
        unsafe {
            pngPtrPtr.write(CPointer<Unit>())
            LibC.free(handle)
        }
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
            case Some(state) => state.memPtr
            case None => CPointer<Unit>()
        }
    }
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
