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

private class PngCClassicStaticStrings {
    let copyright: CString
    let version: CString
    let headerVersion: CString

    init() {
        copyright = unsafe { LibC.mallocCString(
            "\nlibpng version 1.6.58\n" +
            "Copyright (c) 2018-2026 Cosmin Truta\n" +
            "Copyright (c) 1998-2002,2004,2006-2018 Glenn Randers-Pehrson\n" +
            "Copyright (c) 1996-1997 Andreas Dilger\n" +
            "Copyright (c) 1995-1996 Guy Eric Schalnat, Group 42, Inc.\n"
        ) }
        version = unsafe { LibC.mallocCString("1.6.58") }
        headerVersion = unsafe {
            LibC.mallocCString(" libpng version 1.6.58\n\n")
        }
    }
}

private let PNG_C_CLASSIC_STATIC_STRINGS = PngCClassicStaticStrings()

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
    var nextRow = Int64(0)
    var readEndComplete = false
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
    var metadataBacking: Option<PngCClassicMetadataBacking> = None

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

private class PngCClassicMetadataBacking {
    let signature: CPointer<Unit>
    let palette: CPointer<Unit>
    let paletteCount: Int32
    let transparency: CPointer<Unit>
    let transparencyCount: Int32
    let significantBits: CPointer<Unit>
    let background: CPointer<Unit>
    let transparentColor: CPointer<Unit>

    init(
        signature: CPointer<Unit>,
        palette: CPointer<Unit>,
        paletteCount: Int32,
        transparency: CPointer<Unit>,
        transparencyCount: Int32,
        significantBits: CPointer<Unit>,
        background: CPointer<Unit>,
        transparentColor: CPointer<Unit>
    ) {
        this.signature = signature
        this.palette = palette
        this.paletteCount = paletteCount
        this.transparency = transparency
        this.transparencyCount = transparencyCount
        this.significantBits = significantBits
        this.background = background
        this.transparentColor = transparentColor
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

private func pngCClassicAllocateMetadataBlock(
    pngPtr: CPointer<Unit>,
    state: PngCClassicReadState,
    allocator: PngCClassicAllocatorSnapshot,
    size: UIntNative
): CPointer<Unit> {
    let pointer = pngCClassicAllocateWith(pngPtr, state, allocator, size)
    if (pointer.isNull()) {
        throw PngFormatException(
            AllocationFailure, -1, "Out of memory"
        )
    }
    unsafe { memset(pointer, Int32(0), size) }
    pointer
}

private func pngCClassicCopyMetadataBytes(
    target: CPointer<Unit>, bytes: Array<Byte>
): Unit {
    if (target.isNull()) { return }
    let output = unsafe { CPointer<UInt8>(target) }
    var index = Int64(0)
    while (index < bytes.size) {
        unsafe { output.write(index, bytes[index]) }
        index += Int64(1)
    }
}

private func pngCClassicWriteColor16(
    target: CPointer<Unit>,
    index: UInt8,
    red: UInt16,
    green: UInt16,
    blue: UInt16,
    gray: UInt16
): Unit {
    if (target.isNull()) { return }
    let bytes = unsafe { CPointer<UInt8>(target) }
    let samples = unsafe { CPointer<UInt16>(target) }
    unsafe {
        bytes.write(Int64(0), index)
        samples.write(Int64(1), red)
        samples.write(Int64(2), green)
        samples.write(Int64(3), blue)
        samples.write(Int64(4), gray)
    }
}

private func pngCClassicBuildMetadataBacking(
    pngPtr: CPointer<Unit>,
    state: PngCClassicReadState,
    allocator: PngCClassicAllocatorSnapshot,
    decoded: PngDecodedRows
): PngCClassicMetadataBacking {
    var signature = CPointer<Unit>()
    var palette = CPointer<Unit>()
    var transparency = CPointer<Unit>()
    var significantBits = CPointer<Unit>()
    var background = CPointer<Unit>()
    var transparentColor = CPointer<Unit>()
    let metadata = decoded.metadata
    let paletteBytes = metadata.palette()
    let alphaBytes = metadata.paletteAlpha()
    try {
        signature = pngCClassicAllocateMetadataBlock(
            pngPtr, state, allocator, UIntNative(PNG_SIGNATURE.size)
        )
        pngCClassicCopyMetadataBytes(signature, PNG_SIGNATURE)
        if (paletteBytes.size > Int64(0)) {
            palette = pngCClassicAllocateMetadataBlock(
                pngPtr, state, allocator, UIntNative(paletteBytes.size)
            )
            pngCClassicCopyMetadataBytes(palette, paletteBytes)
        }
        if (alphaBytes.size > Int64(0)) {
            transparency = pngCClassicAllocateMetadataBlock(
                pngPtr, state, allocator, UIntNative(alphaBytes.size)
            )
            pngCClassicCopyMetadataBytes(transparency, alphaBytes)
        }
        if (metadata.hasSignificantBits) {
            significantBits = pngCClassicAllocateMetadataBlock(
                pngPtr, state, allocator, UIntNative(5)
            )
            let values = unsafe { CPointer<UInt8>(significantBits) }
            unsafe {
                values.write(Int64(0), metadata.significantBits.red)
                values.write(Int64(1), metadata.significantBits.green)
                values.write(Int64(2), metadata.significantBits.blue)
                values.write(Int64(3), metadata.significantBits.gray)
                values.write(Int64(4), metadata.significantBits.alpha)
            }
        }
        if (metadata.hasBackground) {
            background = pngCClassicAllocateMetadataBlock(
                pngPtr, state, allocator, UIntNative(10)
            )
            pngCClassicWriteColor16(
                background,
                metadata.background.index,
                metadata.background.red,
                metadata.background.green,
                metadata.background.blue,
                metadata.background.gray
            )
        }
        if (metadata.hasTransparency) {
            transparentColor = pngCClassicAllocateMetadataBlock(
                pngPtr, state, allocator, UIntNative(10)
            )
            pngCClassicWriteColor16(
                transparentColor,
                UInt8(0),
                metadata.transparentRed,
                metadata.transparentGreen,
                metadata.transparentBlue,
                metadata.transparentGray
            )
        }
        PngCClassicMetadataBacking(
            signature,
            palette,
            Int32(paletteBytes.size / Int64(3)),
            transparency,
            if (alphaBytes.size > Int64(0)) {
                Int32(alphaBytes.size)
            } else if (metadata.hasTransparency) {
                Int32(1)
            } else {
                Int32(0)
            },
            significantBits,
            background,
            transparentColor
        )
    } catch (error: Exception) {
        pngCClassicFreeWith(pngPtr, state, allocator, transparentColor)
        pngCClassicFreeWith(pngPtr, state, allocator, background)
        pngCClassicFreeWith(pngPtr, state, allocator, significantBits)
        pngCClassicFreeWith(pngPtr, state, allocator, transparency)
        pngCClassicFreeWith(pngPtr, state, allocator, palette)
        pngCClassicFreeWith(pngPtr, state, allocator, signature)
        throw error
    }
}

private func pngCClassicFreeMetadataBacking(
    owner: CPointer<Unit>, infoState: PngCClassicInfoState
): Unit {
    match (infoState.metadataBacking) {
        case Some(backing) =>
            pngCClassicFreeWith(
                owner, infoState.readState, infoState.allocator,
                backing.transparentColor
            )
            pngCClassicFreeWith(
                owner, infoState.readState, infoState.allocator,
                backing.background
            )
            pngCClassicFreeWith(
                owner, infoState.readState, infoState.allocator,
                backing.significantBits
            )
            pngCClassicFreeWith(
                owner, infoState.readState, infoState.allocator,
                backing.transparency
            )
            pngCClassicFreeWith(
                owner, infoState.readState, infoState.allocator,
                backing.palette
            )
            pngCClassicFreeWith(
                owner, infoState.readState, infoState.allocator,
                backing.signature
            )
        case None => ()
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
            pngCClassicFreeMetadataBacking(owner, infoState)
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
    PngCClassicReadState, PngCClassicAllocatorSnapshot,
    CPointer<Unit>, CPointer<Unit>, UInt8
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
                            Some((
                                state, infoState.allocator,
                                state.ioPtr, state.readFn, state.sigBytes
                            ))
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
    decoded: Option<PngDecodedRows>,
    backing: Option<PngCClassicMetadataBacking>
): Unit {
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(_) =>
                match (decoded) {
                    case Some(value) =>
                        state.decodedRows = Some(value)
                        state.decodedInfoHandle = infoPtr.toUIntNative()
                        match (PNG_C_CLASSIC_INFO_REGISTRY.get(
                            infoPtr.toUIntNative()
                        )) {
                            case Some(infoState) =>
                                infoState.metadataBacking = backing
                            case None => ()
                        }
                    case None => ()
                }
                state.readOperationActive = false
            case None => state.readOperationActive = false
        }
    }
}

private class PngCClassicMetadataAccess {
    let state: PngCClassicReadState
    let ihdr: PngIhdr
    let metadata: PngReadMetadata
    let backing: PngCClassicMetadataBacking

    init(
        state: PngCClassicReadState,
        ihdr: PngIhdr,
        metadata: PngReadMetadata,
        backing: PngCClassicMetadataBacking
    ) {
        this.state = state
        this.ihdr = ihdr
        this.metadata = metadata
        this.backing = backing
    }
}

private func pngCClassicBeginMetadataAccess(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Option<PngCClassicMetadataAccess> {
    if (pngPtr.isNull() || infoPtr.isNull()) { return None }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                match (PNG_C_CLASSIC_INFO_REGISTRY.get(
                    infoPtr.toUIntNative()
                )) {
                    case Some(infoState) =>
                        if (state.destroying || state.readOperationActive ||
                            infoState.owner != pngPtr.toUIntNative() ||
                            state.decodedInfoHandle != infoPtr.toUIntNative()) {
                            None
                        } else {
                            match ((state.decodedRows, infoState.metadataBacking)) {
                                case (Some(decoded), Some(backing)) =>
                                    state.readOperationActive = true
                                    Some(PngCClassicMetadataAccess(
                                        state, decoded.ihdr,
                                        decoded.metadata, backing
                                    ))
                                case _ => None
                            }
                        }
                    case None => None
                }
            case None => None
        }
    }
}

private func pngCClassicEndMetadataAccess(
    state: PngCClassicReadState
): Unit {
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        state.readOperationActive = false
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

private class PngCClassicRowTake {
    let row: Option<Array<Byte>>
    let error: String

    init(row: Option<Array<Byte>>, error: String) {
        this.row = row
        this.error = error
    }
}

private func pngCClassicTakeRow(
    pngPtr: CPointer<Unit>
): PngCClassicRowTake {
    if (pngPtr.isNull()) {
        return PngCClassicRowTake(None, "")
    }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.destroying || state.readOperationActive) {
                    PngCClassicRowTake(None, "")
                } else if (state.readEndComplete) {
                    PngCClassicRowTake(None, "Read Error")
                } else {
                    match (state.decodedRows) {
                        case Some(decoded) =>
                            if (state.nextRow >= decoded.rowCount()) {
                                PngCClassicRowTake(None, "Not enough image data")
                            } else {
                                let row = decoded.row(state.nextRow)
                                state.nextRow += Int64(1)
                                PngCClassicRowTake(Some(row), "")
                            }
                        case None => PngCClassicRowTake(
                            None, "Invalid attempt to read row data"
                        )
                    }
                }
            case None => PngCClassicRowTake(None, "")
        }
    }
}

private func pngCClassicWriteRow(
    target: CPointer<UInt8>, row: Array<Byte>
): Unit {
    if (target.isNull()) { return }
    var index = Int64(0)
    while (index < row.size) {
        unsafe { target.write(index, row[index]) }
        index += Int64(1)
    }
}

private func pngCClassicReadOne(
    pngPtr: CPointer<Unit>,
    row: CPointer<UInt8>,
    displayRow: CPointer<UInt8>
): Bool {
    let taken = pngCClassicTakeRow(pngPtr)
    if (taken.error != "") {
        pngCClassicErrorText(pngPtr, taken.error)
        return false
    }
    match (taken.row) {
        case Some(value) =>
            pngCClassicWriteRow(row, value)
            pngCClassicWriteRow(displayRow, value)
        case None => ()
    }
    true
}

private func pngCClassicImageRowCount(
    pngPtr: CPointer<Unit>
): (Int64, String) {
    if (pngPtr.isNull()) { return (Int64(0), "") }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.destroying || state.readOperationActive) {
                    (Int64(0), "")
                } else if (state.readEndComplete) {
                    (Int64(0), "Read Error")
                } else {
                    match (state.decodedRows) {
                        case Some(decoded) =>
                            if (state.nextRow != Int64(0)) {
                                (Int64(0), "png_read_image may only be called once")
                            } else {
                                (decoded.rowCount(), "")
                            }
                        case None => (
                            Int64(0), "Invalid attempt to read row data"
                        )
                    }
                }
            case None => (Int64(0), "")
        }
    }
}

private func pngCClassicSealRead(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): String {
    if (pngPtr.isNull()) { return "" }
    synchronized(PNG_C_CLASSIC_REGISTRY_MUTEX) {
        match (PNG_C_CLASSIC_READ_REGISTRY.get(pngPtr.toUIntNative())) {
            case Some(state) =>
                if (state.destroying || state.readOperationActive) {
                    ""
                } else {
                    var infoValid = infoPtr.isNull()
                    if (!infoPtr.isNull()) {
                        match (PNG_C_CLASSIC_INFO_REGISTRY.get(
                            infoPtr.toUIntNative()
                        )) {
                            case Some(infoState) =>
                                infoValid = infoState.owner ==
                                    pngPtr.toUIntNative()
                            case None => ()
                        }
                    }
                    if (!infoValid) {
                        "png_read_end: invalid info pointer"
                    } else {
                        match (state.decodedRows) {
                            case Some(decoded) =>
                                state.nextRow = decoded.rowCount()
                                state.readEndComplete = true
                                ""
                            case None => "Invalid attempt to read end"
                        }
                    }
                }
            case None => ""
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
        case Some((state, allocator, ioPtr, readFn, sigBytes)) =>
            try {
                let input = pngCClassicCaptureInput(
                    pngPtr, ioPtr, readFn, sigBytes
                )
                let decoded = decodePng(input)
                let backing = pngCClassicBuildMetadataBacking(
                    pngPtr, state, allocator, decoded
                )
                pngCClassicEndReadInfo(
                    pngPtr, infoPtr, state, Some(decoded), Some(backing)
                )
            } catch (error: Exception) {
                pngCClassicEndReadInfo(
                    pngPtr, infoPtr, state, None, None
                )
                pngCClassicErrorText(pngPtr, error.message)
            }
        case None => ()
    }
}

@C
public func png_read_row(
    pngPtr: CPointer<Unit>,
    row: CPointer<UInt8>,
    displayRow: CPointer<UInt8>
): Unit {
    pngCClassicReadOne(pngPtr, row, displayRow)
}

@C
public func png_read_rows(
    pngPtr: CPointer<Unit>,
    rows: CPointer<CPointer<UInt8>>,
    displayRows: CPointer<CPointer<UInt8>>,
    numRows: UInt32
): Unit {
    if (pngPtr.isNull() || (rows.isNull() && displayRows.isNull())) { return }
    var index = UInt32(0)
    while (index < numRows) {
        let row = if (rows.isNull()) {
            CPointer<UInt8>()
        } else {
            unsafe { rows.read(Int64(index)) }
        }
        let displayRow = if (displayRows.isNull()) {
            CPointer<UInt8>()
        } else {
            unsafe { displayRows.read(Int64(index)) }
        }
        if (!pngCClassicReadOne(pngPtr, row, displayRow)) { return }
        index += UInt32(1)
    }
}

@C
public func png_read_image(
    pngPtr: CPointer<Unit>, image: CPointer<CPointer<UInt8>>
): Unit {
    if (pngPtr.isNull()) { return }
    if (image.isNull()) {
        pngCClassicErrorText(pngPtr, "png_read_image: invalid image pointer")
        return
    }
    let (rowCount, error) = pngCClassicImageRowCount(pngPtr)
    if (error != "") {
        pngCClassicErrorText(pngPtr, error)
        return
    }
    var index = Int64(0)
    while (index < rowCount) {
        let row = unsafe { image.read(index) }
        if (!pngCClassicReadOne(pngPtr, row, CPointer<UInt8>())) { return }
        index += Int64(1)
    }
}

@C
public func png_read_end(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Unit {
    let error = pngCClassicSealRead(pngPtr, infoPtr)
    if (error != "") { pngCClassicErrorText(pngPtr, error) }
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

private let PNG_C_INFO_gAMA = UInt32(0x0001)
private let PNG_C_INFO_sBIT = UInt32(0x0002)
private let PNG_C_INFO_cHRM = UInt32(0x0004)
private let PNG_C_INFO_PLTE = UInt32(0x0008)
private let PNG_C_INFO_tRNS = UInt32(0x0010)
private let PNG_C_INFO_bKGD = UInt32(0x0020)
private let PNG_C_INFO_hIST = UInt32(0x0040)
private let PNG_C_INFO_pHYs = UInt32(0x0080)
private let PNG_C_INFO_oFFs = UInt32(0x0100)
private let PNG_C_INFO_tIME = UInt32(0x0200)
private let PNG_C_INFO_pCAL = UInt32(0x0400)
private let PNG_C_INFO_sRGB = UInt32(0x0800)
private let PNG_C_INFO_iCCP = UInt32(0x1000)
private let PNG_C_INFO_sPLT = UInt32(0x2000)
private let PNG_C_INFO_sCAL = UInt32(0x4000)
private let PNG_C_INFO_eXIf = UInt32(0x10000)
private let PNG_C_INFO_cICP = UInt32(0x20000)
private let PNG_C_INFO_cLLI = UInt32(0x40000)
private let PNG_C_INFO_mDCV = UInt32(0x80000)
private let PNG_C_RESOLUTION_METER = UInt8(1)
private let PNG_C_OFFSET_PIXEL = UInt8(0)
private let PNG_C_OFFSET_MICROMETER = UInt8(1)
private let PNG_C_UINT31_MAX = UInt32(0x7fff_ffff)

private func pngCClassicRetainedValidMask(
    access: PngCClassicMetadataAccess
): UInt32 {
    let metadata = access.metadata
    var valid = UInt32(0)
    if (metadata.hasGamma) { valid |= PNG_C_INFO_gAMA }
    if (metadata.hasSignificantBits) { valid |= PNG_C_INFO_sBIT }
    if (metadata.hasChromaticities) { valid |= PNG_C_INFO_cHRM }
    if (metadata.hasPalette) { valid |= PNG_C_INFO_PLTE }
    if (metadata.hasTransparency &&
        access.backing.transparencyCount > Int32(0)) {
        valid |= PNG_C_INFO_tRNS
    }
    if (metadata.hasBackground) { valid |= PNG_C_INFO_bKGD }
    if (metadata.hasHistogram) { valid |= PNG_C_INFO_hIST }
    if (metadata.hasPhysicalDimensions) { valid |= PNG_C_INFO_pHYs }
    if (metadata.hasImageOffset) { valid |= PNG_C_INFO_oFFs }
    if (metadata.hasModificationTime && metadata.modificationTimeBeforeIdat) {
        valid |= PNG_C_INFO_tIME
    }
    if (metadata.hasPixelCalibration) { valid |= PNG_C_INFO_pCAL }
    if (metadata.hasSrgb) { valid |= PNG_C_INFO_sRGB }
    if (metadata.hasIccProfile) { valid |= PNG_C_INFO_iCCP }
    if (metadata.suggestedPaletteCount() > Int64(0)) {
        valid |= PNG_C_INFO_sPLT
    }
    if (metadata.hasPhysicalScale) { valid |= PNG_C_INFO_sCAL }
    if (metadata.hasExif && metadata.exifBeforeIdat) {
        valid |= PNG_C_INFO_eXIf
    }
    if (metadata.hasCodingIndependentCodePoints) { valid |= PNG_C_INFO_cICP }
    if (metadata.hasContentLightLevel) { valid |= PNG_C_INFO_cLLI }
    if (metadata.hasMasteringDisplayColorVolume) { valid |= PNG_C_INFO_mDCV }
    valid
}

private func pngCClassicPixelsPerMeter(
    metadata: PngReadMetadata, axis: UInt8
): UInt32 {
    if (!metadata.hasPhysicalDimensions) { return UInt32(0) }
    let value = metadata.physicalDimensions
    if (value.unit != PNG_C_RESOLUTION_METER) { return UInt32(0) }
    if (axis == UInt8(1)) { return value.pixelsPerUnitX }
    if (axis == UInt8(2)) { return value.pixelsPerUnitY }
    if (value.pixelsPerUnitX == value.pixelsPerUnitY) {
        value.pixelsPerUnitX
    } else {
        UInt32(0)
    }
}

private func pngCClassicPixelsPerInch(ppm: UInt32): UInt32 {
    if (ppm > PNG_C_UINT31_MAX) { return UInt32(0) }
    let converted = pngMulDivFixed(Int32(ppm), Int32(127), Int32(5000))
    if (converted.success && converted.value >= Int32(0)) {
        UInt32(converted.value)
    } else {
        UInt32(0)
    }
}

private func pngCClassicDpiFromPpm(ppm: UInt32): UInt32 {
    let scaled = UInt64(ppm) * UInt64(127) + UInt64(2500)
    UInt32(scaled / UInt64(5000))
}

private func pngCClassicOffset(
    metadata: PngReadMetadata, axis: UInt8, unit: UInt8
): Int32 {
    if (!metadata.hasImageOffset || metadata.imageOffset.unit != unit) {
        return Int32(0)
    }
    if (axis == UInt8(1)) {
        metadata.imageOffset.x
    } else {
        metadata.imageOffset.y
    }
}

private func pngCClassicOffsetInchesFixed(
    pngPtr: CPointer<Unit>, microns: Int32
): Int32 {
    let converted = pngMulDivFixed(microns, Int32(500), Int32(127))
    if (converted.success) { return converted.value }
    pngCClassicWarningText(pngPtr, "fixed point overflow ignored")
    Int32(0)
}

@C
public func png_get_valid(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>, flag: UInt32
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                pngCClassicRetainedValidMask(access) & flag
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_pixels_per_meter(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                pngCClassicPixelsPerMeter(access.metadata, UInt8(0))
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_x_pixels_per_meter(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                pngCClassicPixelsPerMeter(access.metadata, UInt8(1))
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_y_pixels_per_meter(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                pngCClassicPixelsPerMeter(access.metadata, UInt8(2))
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_pixel_aspect_ratio_fixed(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Int32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                let metadata = access.metadata
                if (!metadata.hasPhysicalDimensions) { return Int32(0) }
                let value = metadata.physicalDimensions
                if (value.pixelsPerUnitX == UInt32(0) ||
                    value.pixelsPerUnitY == UInt32(0) ||
                    value.pixelsPerUnitX > PNG_C_UINT31_MAX ||
                    value.pixelsPerUnitY > PNG_C_UINT31_MAX) {
                    return Int32(0)
                }
                let converted = pngMulDivFixed(
                    Int32(value.pixelsPerUnitY), PNG_FP_1,
                    Int32(value.pixelsPerUnitX)
                )
                if (converted.success) { converted.value } else { Int32(0) }
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => Int32(0)
    }
}

@C
public func png_get_x_offset_pixels(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Int32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                pngCClassicOffset(
                    access.metadata, UInt8(1), PNG_C_OFFSET_PIXEL
                )
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => Int32(0)
    }
}

@C
public func png_get_y_offset_pixels(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Int32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                pngCClassicOffset(
                    access.metadata, UInt8(2), PNG_C_OFFSET_PIXEL
                )
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => Int32(0)
    }
}

@C
public func png_get_x_offset_microns(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Int32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                pngCClassicOffset(
                    access.metadata, UInt8(1), PNG_C_OFFSET_MICROMETER
                )
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => Int32(0)
    }
}

@C
public func png_get_y_offset_microns(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Int32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                pngCClassicOffset(
                    access.metadata, UInt8(2), PNG_C_OFFSET_MICROMETER
                )
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => Int32(0)
    }
}

@C
public func png_get_signature(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): CPointer<UInt8> {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                unsafe { CPointer<UInt8>(access.backing.signature) }
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => CPointer<UInt8>()
    }
}

@C
public func png_get_pixels_per_inch(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt32 {
    pngCClassicPixelsPerInch(unsafe {
        png_get_pixels_per_meter(pngPtr, infoPtr)
    })
}

@C
public func png_get_x_pixels_per_inch(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt32 {
    pngCClassicPixelsPerInch(unsafe {
        png_get_x_pixels_per_meter(pngPtr, infoPtr)
    })
}

@C
public func png_get_y_pixels_per_inch(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): UInt32 {
    pngCClassicPixelsPerInch(unsafe {
        png_get_y_pixels_per_meter(pngPtr, infoPtr)
    })
}

@C
public func png_get_x_offset_inches_fixed(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Int32 {
    pngCClassicOffsetInchesFixed(
        pngPtr, unsafe { png_get_x_offset_microns(pngPtr, infoPtr) }
    )
}

@C
public func png_get_y_offset_inches_fixed(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Int32 {
    pngCClassicOffsetInchesFixed(
        pngPtr, unsafe { png_get_y_offset_microns(pngPtr, infoPtr) }
    )
}

@C
public func png_get_pHYs_dpi(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    resolutionX: CPointer<UInt32>,
    resolutionY: CPointer<UInt32>,
    unitType: CPointer<Int32>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasPhysicalDimensions) {
                    return UInt32(0)
                }
                let value = access.metadata.physicalDimensions
                var result = UInt32(0)
                unsafe {
                    if (!resolutionX.isNull()) {
                        resolutionX.write(value.pixelsPerUnitX)
                        result |= PNG_C_INFO_pHYs
                    }
                    if (!resolutionY.isNull()) {
                        resolutionY.write(value.pixelsPerUnitY)
                        result |= PNG_C_INFO_pHYs
                    }
                    if (!unitType.isNull()) {
                        unitType.write(Int32(value.unit))
                        result |= PNG_C_INFO_pHYs
                        if (value.unit == PNG_C_RESOLUTION_METER) {
                            if (!resolutionX.isNull()) {
                                resolutionX.write(pngCClassicDpiFromPpm(
                                    value.pixelsPerUnitX
                                ))
                            }
                            if (!resolutionY.isNull()) {
                                resolutionY.write(pngCClassicDpiFromPpm(
                                    value.pixelsPerUnitY
                                ))
                            }
                        }
                    }
                }
                result
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_pixel_aspect_ratio(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Float32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasPhysicalDimensions ||
                    access.metadata.physicalDimensions.pixelsPerUnitX ==
                        UInt32(0)) {
                    return Float32(0.0)
                }
                let value = access.metadata.physicalDimensions
                Float32(value.pixelsPerUnitY) / Float32(value.pixelsPerUnitX)
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => Float32(0.0)
    }
}

@C
public func png_get_x_offset_inches(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Float32 {
    Float32(unsafe { png_get_x_offset_microns(pngPtr, infoPtr) }) *
        Float32(0.00003937)
}

@C
public func png_get_y_offset_inches(
    pngPtr: CPointer<Unit>, infoPtr: CPointer<Unit>
): Float32 {
    Float32(unsafe { png_get_y_offset_microns(pngPtr, infoPtr) }) *
        Float32(0.00003937)
}

@C
public func png_get_copyright(pngPtr: CPointer<Unit>): CString {
    PNG_C_CLASSIC_STATIC_STRINGS.copyright
}

@C
public func png_get_header_ver(pngPtr: CPointer<Unit>): CString {
    PNG_C_CLASSIC_STATIC_STRINGS.version
}

@C
public func png_get_header_version(pngPtr: CPointer<Unit>): CString {
    PNG_C_CLASSIC_STATIC_STRINGS.headerVersion
}

@C
public func png_get_libpng_ver(pngPtr: CPointer<Unit>): CString {
    PNG_C_CLASSIC_STATIC_STRINGS.version
}

@C
public func png_get_gAMA_fixed(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    fileGamma: CPointer<Int32>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasGamma) { return UInt32(0) }
                if (!fileGamma.isNull()) {
                    unsafe { fileGamma.write(Int32(access.metadata.gamma)) }
                }
                PNG_C_INFO_gAMA
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_gAMA(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    fileGamma: CPointer<Float64>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasGamma) { return UInt32(0) }
                if (!fileGamma.isNull()) {
                    unsafe {
                        fileGamma.write(
                            Float64(access.metadata.gamma) / Float64(100000.0)
                        )
                    }
                }
                PNG_C_INFO_gAMA
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_cHRM_fixed(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    whiteX: CPointer<Int32>,
    whiteY: CPointer<Int32>,
    redX: CPointer<Int32>,
    redY: CPointer<Int32>,
    greenX: CPointer<Int32>,
    greenY: CPointer<Int32>,
    blueX: CPointer<Int32>,
    blueY: CPointer<Int32>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasChromaticities) { return UInt32(0) }
                let value = access.metadata.chromaticities
                unsafe {
                    if (!whiteX.isNull()) { whiteX.write(value.whiteX) }
                    if (!whiteY.isNull()) { whiteY.write(value.whiteY) }
                    if (!redX.isNull()) { redX.write(value.redX) }
                    if (!redY.isNull()) { redY.write(value.redY) }
                    if (!greenX.isNull()) { greenX.write(value.greenX) }
                    if (!greenY.isNull()) { greenY.write(value.greenY) }
                    if (!blueX.isNull()) { blueX.write(value.blueX) }
                    if (!blueY.isNull()) { blueY.write(value.blueY) }
                }
                PNG_C_INFO_cHRM
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_cHRM(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    whiteX: CPointer<Float64>,
    whiteY: CPointer<Float64>,
    redX: CPointer<Float64>,
    redY: CPointer<Float64>,
    greenX: CPointer<Float64>,
    greenY: CPointer<Float64>,
    blueX: CPointer<Float64>,
    blueY: CPointer<Float64>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasChromaticities) { return UInt32(0) }
                let value = access.metadata.chromaticities
                unsafe {
                    if (!whiteX.isNull()) {
                        whiteX.write(Float64(value.whiteX) / Float64(100000.0))
                    }
                    if (!whiteY.isNull()) {
                        whiteY.write(Float64(value.whiteY) / Float64(100000.0))
                    }
                    if (!redX.isNull()) {
                        redX.write(Float64(value.redX) / Float64(100000.0))
                    }
                    if (!redY.isNull()) {
                        redY.write(Float64(value.redY) / Float64(100000.0))
                    }
                    if (!greenX.isNull()) {
                        greenX.write(Float64(value.greenX) / Float64(100000.0))
                    }
                    if (!greenY.isNull()) {
                        greenY.write(Float64(value.greenY) / Float64(100000.0))
                    }
                    if (!blueX.isNull()) {
                        blueX.write(Float64(value.blueX) / Float64(100000.0))
                    }
                    if (!blueY.isNull()) {
                        blueY.write(Float64(value.blueY) / Float64(100000.0))
                    }
                }
                PNG_C_INFO_cHRM
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_oFFs(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    offsetX: CPointer<Int32>,
    offsetY: CPointer<Int32>,
    unitType: CPointer<Int32>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasImageOffset || offsetX.isNull() ||
                    offsetY.isNull() || unitType.isNull()) {
                    return UInt32(0)
                }
                let value = access.metadata.imageOffset
                unsafe {
                    offsetX.write(value.x)
                    offsetY.write(value.y)
                    unitType.write(Int32(value.unit))
                }
                PNG_C_INFO_oFFs
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_cICP(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    colorPrimaries: CPointer<UInt8>,
    transferFunction: CPointer<UInt8>,
    matrixCoefficients: CPointer<UInt8>,
    fullRangeFlag: CPointer<UInt8>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasCodingIndependentCodePoints ||
                    colorPrimaries.isNull() || transferFunction.isNull() ||
                    matrixCoefficients.isNull() || fullRangeFlag.isNull()) {
                    return UInt32(0)
                }
                let value = access.metadata.codingIndependentCodePoints
                unsafe {
                    colorPrimaries.write(value.colorPrimaries)
                    transferFunction.write(value.transferFunction)
                    matrixCoefficients.write(value.matrixCoefficients)
                    fullRangeFlag.write(value.fullRangeFlag)
                }
                PNG_C_INFO_cICP
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_cLLI_fixed(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    maximumContentLightLevel: CPointer<UInt32>,
    maximumFrameAverageLightLevel: CPointer<UInt32>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasContentLightLevel) { return UInt32(0) }
                let value = access.metadata.contentLightLevel
                unsafe {
                    if (!maximumContentLightLevel.isNull()) {
                        maximumContentLightLevel.write(
                            value.maximumContentLightLevel
                        )
                    }
                    if (!maximumFrameAverageLightLevel.isNull()) {
                        maximumFrameAverageLightLevel.write(
                            value.maximumFrameAverageLightLevel
                        )
                    }
                }
                PNG_C_INFO_cLLI
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_cLLI(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    maximumContentLightLevel: CPointer<Float64>,
    maximumFrameAverageLightLevel: CPointer<Float64>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasContentLightLevel) { return UInt32(0) }
                let value = access.metadata.contentLightLevel
                unsafe {
                    if (!maximumContentLightLevel.isNull()) {
                        maximumContentLightLevel.write(
                            Float64(value.maximumContentLightLevel) *
                                Float64(0.0001)
                        )
                    }
                    if (!maximumFrameAverageLightLevel.isNull()) {
                        maximumFrameAverageLightLevel.write(
                            Float64(value.maximumFrameAverageLightLevel) *
                                Float64(0.0001)
                        )
                    }
                }
                PNG_C_INFO_cLLI
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

private func pngCClassicWriteMdcvFixed(
    value: PngMasteringDisplayColorVolume,
    whiteX: CPointer<Int32>,
    whiteY: CPointer<Int32>,
    redX: CPointer<Int32>,
    redY: CPointer<Int32>,
    greenX: CPointer<Int32>,
    greenY: CPointer<Int32>,
    blueX: CPointer<Int32>,
    blueY: CPointer<Int32>,
    maximumDisplayLuminance: CPointer<UInt32>,
    minimumDisplayLuminance: CPointer<UInt32>
): Unit {
    let xy = value.chromaticities
    unsafe {
        if (!whiteX.isNull()) { whiteX.write(xy.whiteX) }
        if (!whiteY.isNull()) { whiteY.write(xy.whiteY) }
        if (!redX.isNull()) { redX.write(xy.redX) }
        if (!redY.isNull()) { redY.write(xy.redY) }
        if (!greenX.isNull()) { greenX.write(xy.greenX) }
        if (!greenY.isNull()) { greenY.write(xy.greenY) }
        if (!blueX.isNull()) { blueX.write(xy.blueX) }
        if (!blueY.isNull()) { blueY.write(xy.blueY) }
        if (!maximumDisplayLuminance.isNull()) {
            maximumDisplayLuminance.write(value.maximumDisplayLuminance)
        }
        if (!minimumDisplayLuminance.isNull()) {
            minimumDisplayLuminance.write(value.minimumDisplayLuminance)
        }
    }
}

@C
public func png_get_mDCV_fixed(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    whiteX: CPointer<Int32>,
    whiteY: CPointer<Int32>,
    redX: CPointer<Int32>,
    redY: CPointer<Int32>,
    greenX: CPointer<Int32>,
    greenY: CPointer<Int32>,
    blueX: CPointer<Int32>,
    blueY: CPointer<Int32>,
    maximumDisplayLuminance: CPointer<UInt32>,
    minimumDisplayLuminance: CPointer<UInt32>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasMasteringDisplayColorVolume) {
                    return UInt32(0)
                }
                pngCClassicWriteMdcvFixed(
                    access.metadata.masteringDisplayColorVolume,
                    whiteX, whiteY, redX, redY, greenX, greenY, blueX, blueY,
                    maximumDisplayLuminance, minimumDisplayLuminance
                )
                PNG_C_INFO_mDCV
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_mDCV(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    whiteX: CPointer<Float64>,
    whiteY: CPointer<Float64>,
    redX: CPointer<Float64>,
    redY: CPointer<Float64>,
    greenX: CPointer<Float64>,
    greenY: CPointer<Float64>,
    blueX: CPointer<Float64>,
    blueY: CPointer<Float64>,
    maximumDisplayLuminance: CPointer<Float64>,
    minimumDisplayLuminance: CPointer<Float64>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasMasteringDisplayColorVolume) {
                    return UInt32(0)
                }
                let value = access.metadata.masteringDisplayColorVolume
                let xy = value.chromaticities
                unsafe {
                    if (!whiteX.isNull()) {
                        whiteX.write(Float64(xy.whiteX) / Float64(100000.0))
                    }
                    if (!whiteY.isNull()) {
                        whiteY.write(Float64(xy.whiteY) / Float64(100000.0))
                    }
                    if (!redX.isNull()) {
                        redX.write(Float64(xy.redX) / Float64(100000.0))
                    }
                    if (!redY.isNull()) {
                        redY.write(Float64(xy.redY) / Float64(100000.0))
                    }
                    if (!greenX.isNull()) {
                        greenX.write(Float64(xy.greenX) / Float64(100000.0))
                    }
                    if (!greenY.isNull()) {
                        greenY.write(Float64(xy.greenY) / Float64(100000.0))
                    }
                    if (!blueX.isNull()) {
                        blueX.write(Float64(xy.blueX) / Float64(100000.0))
                    }
                    if (!blueY.isNull()) {
                        blueY.write(Float64(xy.blueY) / Float64(100000.0))
                    }
                    if (!maximumDisplayLuminance.isNull()) {
                        maximumDisplayLuminance.write(
                            Float64(value.maximumDisplayLuminance) *
                                Float64(0.0001)
                        )
                    }
                    if (!minimumDisplayLuminance.isNull()) {
                        minimumDisplayLuminance.write(
                            Float64(value.minimumDisplayLuminance) *
                                Float64(0.0001)
                        )
                    }
                }
                PNG_C_INFO_mDCV
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_sRGB(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    intent: CPointer<Int32>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasSrgb) { return UInt32(0) }
                if (!intent.isNull()) {
                    unsafe {
                        intent.write(Int32(
                            access.metadata.srgbIntent.encodedValue()
                        ))
                    }
                }
                PNG_C_INFO_sRGB
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_sBIT(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    significantBits: CPointer<CPointer<Unit>>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasSignificantBits ||
                    significantBits.isNull()) {
                    return UInt32(0)
                }
                unsafe { significantBits.write(access.backing.significantBits) }
                PNG_C_INFO_sBIT
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_bKGD(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    background: CPointer<CPointer<Unit>>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasBackground || background.isNull()) {
                    return UInt32(0)
                }
                unsafe { background.write(access.backing.background) }
                PNG_C_INFO_bKGD
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_pHYs(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    resolutionX: CPointer<UInt32>,
    resolutionY: CPointer<UInt32>,
    unitType: CPointer<Int32>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasPhysicalDimensions) {
                    return UInt32(0)
                }
                let value = access.metadata.physicalDimensions
                unsafe {
                    if (!resolutionX.isNull()) {
                        resolutionX.write(value.pixelsPerUnitX)
                    }
                    if (!resolutionY.isNull()) {
                        resolutionY.write(value.pixelsPerUnitY)
                    }
                    if (!unitType.isNull()) {
                        unitType.write(Int32(value.unit))
                    }
                }
                PNG_C_INFO_pHYs
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_PLTE(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    palette: CPointer<CPointer<Unit>>,
    paletteCount: CPointer<Int32>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasPalette || palette.isNull()) {
                    return UInt32(0)
                }
                unsafe {
                    palette.write(access.backing.palette)
                    if (!paletteCount.isNull()) {
                        paletteCount.write(access.backing.paletteCount)
                    }
                }
                PNG_C_INFO_PLTE
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
        case None => UInt32(0)
    }
}

@C
public func png_get_tRNS(
    pngPtr: CPointer<Unit>,
    infoPtr: CPointer<Unit>,
    transparency: CPointer<CPointer<Unit>>,
    transparencyCount: CPointer<Int32>,
    transparentColor: CPointer<CPointer<Unit>>
): UInt32 {
    match (pngCClassicBeginMetadataAccess(pngPtr, infoPtr)) {
        case Some(access) =>
            try {
                if (!access.metadata.hasTransparency) { return UInt32(0) }
                var result = UInt32(0)
                let paletteColor = access.ihdr.colorType == Indexed
                unsafe {
                    if (paletteColor) {
                        if (!transparency.isNull()) {
                            transparency.write(access.backing.transparency)
                            result |= PNG_C_INFO_tRNS
                        }
                        if (!transparentColor.isNull()) {
                            transparentColor.write(
                                access.backing.transparentColor
                            )
                        }
                    } else {
                        if (!transparentColor.isNull()) {
                            transparentColor.write(
                                access.backing.transparentColor
                            )
                            result |= PNG_C_INFO_tRNS
                        }
                        if (!transparency.isNull()) {
                            transparency.write(CPointer<Unit>())
                        }
                    }
                    if (!transparencyCount.isNull()) {
                        transparencyCount.write(
                            access.backing.transparencyCount
                        )
                        result |= PNG_C_INFO_tRNS
                    }
                }
                result
            } finally {
                pngCClassicEndMetadataAccess(access.state)
            }
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
