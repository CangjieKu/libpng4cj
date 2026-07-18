package libpng4cj

import std.collection.{ArrayList, HashMap}
import std.sync.{AtomicInt64, Mutex}

private let PNG_C_IMAGE_FORMAT_ALPHA: UInt32 = UInt32(0x01)
private let PNG_C_IMAGE_FORMAT_COLOR: UInt32 = UInt32(0x02)
private let PNG_C_IMAGE_FORMAT_LINEAR: UInt32 = UInt32(0x04)
private let PNG_C_IMAGE_FORMAT_COLORMAP: UInt32 = UInt32(0x08)
private let PNG_C_IMAGE_FORMAT_BGR: UInt32 = UInt32(0x10)
private let PNG_C_IMAGE_FORMAT_AFIRST: UInt32 = UInt32(0x20)
private let PNG_C_IMAGE_FORMAT_ASSOCIATED_ALPHA: UInt32 = UInt32(0x40)
private let PNG_C_IMAGE_FORMAT_MASK: UInt32 = UInt32(0x7f)

private let PNG_C_IMAGE_FLAG_COLORSPACE_NOT_SRGB: UInt32 = UInt32(0x01)
private let PNG_C_IMAGE_FLAG_FAST: UInt32 = UInt32(0x02)
private let PNG_C_IMAGE_FLAG_16BIT_SRGB: UInt32 = UInt32(0x04)
private let PNG_C_IMAGE_FLAG_MASK: UInt32 = UInt32(0x07)
private let PNG_C_IMAGE_MAX_MEMORY_BYTES: UInt64 = UInt64(268_435_456)
private let PNG_C_IMAGE_STDIO_BUFFER_BYTES: Int64 = Int64(64_000)

foreign func fopen(path: CString, mode: CString): CPointer<Unit>
foreign func fread(
    buffer: CPointer<UInt8>, size: UIntNative, count: UIntNative,
    file: CPointer<Unit>
): UIntNative
foreign func fwrite(
    buffer: CPointer<UInt8>, size: UIntNative, count: UIntNative,
    file: CPointer<Unit>
): UIntNative
foreign func fflush(file: CPointer<Unit>): Int32
foreign func ferror(file: CPointer<Unit>): Int32
foreign func fclose(file: CPointer<Unit>): Int32
foreign func remove(path: CString): Int32

@C
public struct PngCImage {
    var opaque = CPointer<Unit>()
    var version: UInt32 = UInt32(0)
    var width: UInt32 = UInt32(0)
    var height: UInt32 = UInt32(0)
    var format: UInt32 = UInt32(0)
    var flags: UInt32 = UInt32(0)
    var colormapEntries: UInt32 = UInt32(0)
    var warningOrError: UInt32 = UInt32(0)
    var message = VArray<UInt8, $64>(repeat: UInt8(0))
}

private class PngCImageReadState {
    let image: PngImage

    init(image: PngImage) {
        this.image = image
    }
}

private class PngCImageHeaderFacts {
    let format: UInt32
    let flags: UInt32
    let colormapEntries: UInt32

    init(format: UInt32, flags: UInt32, colormapEntries: UInt32) {
        this.format = format
        this.flags = flags
        this.colormapEntries = colormapEntries
    }
}

private let PNG_C_IMAGE_NEXT_ID = AtomicInt64(1)
private let PNG_C_IMAGE_REGISTRY_MUTEX = Mutex()
private let PNG_C_IMAGE_REGISTRY = HashMap<Int64, PngCImageReadState>()

private func pngCImageClearMessage(image: PngCImage): PngCImage {
    var output = image
    output.message = VArray<UInt8, $64>(repeat: UInt8(0))
    output
}

private func pngCImageSetMessage(image: PngCImage, message: String): PngCImage {
    var output = pngCImageClearMessage(image)
    let bytes = message.toArray()
    let count = if (bytes.size < Int64(63)) { bytes.size } else { Int64(63) }
    var index: Int64 = Int64(0)
    while (index < count) {
        output.message[index] = bytes[index]
        index += Int64(1)
    }
    output.message[count] = UInt8(0)
    output
}

private func pngCImageRecordError(image: PngCImage, message: String): PngCImage {
    var output = pngCImageSetMessage(image, message)
    output.warningOrError |= PNG_IMAGE_ERROR
    output
}

private func pngCImageWrite(image: CPointer<PngCImage>, value: PngCImage): Unit {
    unsafe { image.write(value) }
}

private func pngCImageFail(
    image: CPointer<PngCImage>,
    value: PngCImage,
    message: String
): Int32 {
    pngCImageWrite(image, pngCImageRecordError(value, message))
    Int32(0)
}

private func pngCImageReadInput(memory: CPointer<Unit>, size: UIntNative): Array<Byte> {
    let length = UInt64(size)
    if (memory.isNull() || length == UInt64(0) ||
        length > PNG_C_IMAGE_MAX_MEMORY_BYTES || length > UInt64(Int64.Max)) {
        throw PngFormatException(
            InvalidArgument, -1,
            "png_image_begin_read_from_memory: invalid argument"
        )
    }
    let input = unsafe { CPointer<UInt8>(memory) }
    let bytes = Array<Byte>(Int64(length), repeat: UInt8(0))
    var index: Int64 = Int64(0)
    while (index < bytes.size) {
        bytes[index] = unsafe { input.read(index) }
        index += Int64(1)
    }
    bytes
}

private func pngCImageAppendBytes(
    output: ArrayList<Byte>, bytes: Array<Byte>, count: Int64
): Unit {
    var index: Int64 = Int64(0)
    while (index < count) {
        output.add(bytes[index])
        index += Int64(1)
    }
}

private func pngCImageReadStdio(
    file: CPointer<Unit>, operation: String
): Array<Byte> {
    if (file.isNull()) {
        throw PngFormatException(
            InvalidArgument, -1, "${operation}: invalid argument"
        )
    }
    let output = ArrayList<Byte>()
    let buffer = Array<Byte>(PNG_C_IMAGE_STDIO_BUFFER_BYTES, repeat: UInt8(0))
    var total: UInt64 = UInt64(0)
    while (true) {
        var count = UIntNative(0)
        unsafe {
            let raw = acquireArrayRawData(buffer)
            try {
                count = fread(
                    raw.pointer, UIntNative(1), UIntNative(buffer.size), file
                )
            } finally {
                releaseArrayRawData(raw)
            }
        }
        let incoming = UInt64(count)
        if (incoming > PNG_C_IMAGE_MAX_MEMORY_BYTES - total) {
            throw PngFormatException(
                DecodeLimitExceeded, Int64(total),
                "${operation}: input exceeds the simplified ABI byte limit"
            )
        }
        if (incoming > UInt64(0)) {
            pngCImageAppendBytes(output, buffer, Int64(incoming))
            total += incoming
        }
        if (incoming < UInt64(buffer.size)) {
            if (unsafe { ferror(file) } != Int32(0)) {
                throw PngFormatException(
                    IoFailure, Int64(total), "${operation}: read error"
                )
            }
            break
        }
    }
    if (total == UInt64(0)) {
        throw PngFormatException(
            InvalidArgument, -1, "${operation}: empty input"
        )
    }
    output.toArray()
}

private func pngCImageOpen(fileName: CString, modeText: String): CPointer<Unit> {
    let mode = unsafe { LibC.mallocCString(modeText) }
    try {
        unsafe { fopen(fileName, mode) }
    } finally {
        unsafe { LibC.free(mode) }
    }
}

private func pngCImageCloseQuietly(file: CPointer<Unit>): Unit {
    if (file.isNotNull()) {
        unsafe { fclose(file) }
    }
}

private func pngCImageRemoveQuietly(fileName: CString): Unit {
    if (!fileName.isNull()) {
        unsafe { remove(fileName) }
    }
}

private func pngCImageWriteStdio(
    file: CPointer<Unit>, bytes: Array<Byte>, operation: String
): Unit {
    if (file.isNull()) {
        throw PngFormatException(
            InvalidArgument, -1, "${operation}: invalid argument"
        )
    }
    var written = UIntNative(0)
    unsafe {
        let raw = acquireArrayRawData(bytes)
        try {
            written = fwrite(
                raw.pointer, UIntNative(1), UIntNative(bytes.size), file
            )
        } finally {
            releaseArrayRawData(raw)
        }
    }
    if (UInt64(written) != UInt64(bytes.size) ||
        unsafe { ferror(file) } != Int32(0)) {
        throw PngFormatException(IoFailure, -1, "${operation}: write error")
    }
}

private func pngCImageChromaticityOutside(
    actual: Int32,
    expected: Int32
): Bool {
    let delta = if (actual >= expected) {
        Int64(actual) - Int64(expected)
    } else {
        Int64(expected) - Int64(actual)
    }
    delta > Int64(1000)
}

private func pngCImageChromaticitiesMatchSrgb(value: PngChromaticities): Bool {
    !pngCImageChromaticityOutside(value.whiteX, Int32(31270)) &&
    !pngCImageChromaticityOutside(value.whiteY, Int32(32900)) &&
    !pngCImageChromaticityOutside(value.redX, Int32(64000)) &&
    !pngCImageChromaticityOutside(value.redY, Int32(33000)) &&
    !pngCImageChromaticityOutside(value.greenX, Int32(30000)) &&
    !pngCImageChromaticityOutside(value.greenY, Int32(60000)) &&
    !pngCImageChromaticityOutside(value.blueX, Int32(15000)) &&
    !pngCImageChromaticityOutside(value.blueY, Int32(6000))
}

private func pngCImageHeaderFacts(
    bytes: Array<Byte>,
    limits: PngReadLimits
): PngCImageHeaderFacts {
    let session = PngReadSession(bytes, limits)
    let ihdr = session.readIhdr()
    var hasTransparency = false
    var paletteEntries = UInt32(0)
    var hasSrgb = false
    var hasCicp = false
    var chromaticities = None<PngChromaticities>
    var masteringChromaticities = None<PngChromaticities>
    while (!session.isClosed()) {
        let chunk = session.readNextChunk()
        if (chunk.isType(PNG_CHUNK_PLTE)) {
            if (chunk.length == UInt32(0) || chunk.length % UInt32(3) != UInt32(0)) {
                throw PngFormatException(
                    InvalidPalette, chunk.offset,
                    "PLTE length must be a non-zero multiple of three"
                )
            }
            paletteEntries = chunk.length / UInt32(3)
        } else if (chunk.isType(PNG_CHUNK_tRNS)) {
            hasTransparency = true
        } else if (chunk.isType(PNG_CHUNK_sRGB)) {
            hasSrgb = true
        } else if (chunk.isType(PNG_CHUNK_cICP)) {
            hasCicp = true
        } else if (chunk.isType(PNG_CHUNK_cHRM)) {
            let data = chunk.payload()
            if (data.size != Int64(32)) {
                throw PngFormatException(
                    InvalidMetadata, chunk.offset, "cHRM length must be 32"
                )
            }
            let values = Array<Int32>(Int64(8), repeat: Int32(0))
            var index: Int64 = Int64(0)
            while (index < values.size) {
                let encoded = readUInt32Be(data, index * Int64(4))
                if (encoded > UInt32(Int32.Max)) {
                    throw PngFormatException(
                        InvalidMetadata, chunk.offset,
                        "cHRM value exceeds PNG fixed-point range"
                    )
                }
                values[index] = Int32(encoded)
                index += Int64(1)
            }
            chromaticities = Some(PngChromaticities(
                values[0], values[1], values[2], values[3],
                values[4], values[5], values[6], values[7]
            ))
        } else if (chunk.isType(PNG_CHUNK_mDCV)) {
            let data = chunk.payload()
            if (data.size != Int64(24)) {
                throw PngFormatException(
                    InvalidMetadata, chunk.offset, "mDCV length must be 24"
                )
            }
            masteringChromaticities = Some(PngChromaticities(
                Int32(readUInt16Be(data, Int64(12))) * Int32(2),
                Int32(readUInt16Be(data, Int64(14))) * Int32(2),
                Int32(readUInt16Be(data, Int64(0))) * Int32(2),
                Int32(readUInt16Be(data, Int64(2))) * Int32(2),
                Int32(readUInt16Be(data, Int64(4))) * Int32(2),
                Int32(readUInt16Be(data, Int64(6))) * Int32(2),
                Int32(readUInt16Be(data, Int64(8))) * Int32(2),
                Int32(readUInt16Be(data, Int64(10))) * Int32(2)
            ))
        } else if (chunk.isType(PNG_CHUNK_IDAT)) {
            session.close()
        }
    }

    var format = UInt32(0)
    if (ihdr.colorType == Truecolor || ihdr.colorType == TruecolorAlpha ||
        ihdr.colorType == Indexed) {
        format |= PNG_C_IMAGE_FORMAT_COLOR
    }
    if (ihdr.colorType == GrayscaleAlpha || ihdr.colorType == TruecolorAlpha ||
        hasTransparency) {
        format |= PNG_C_IMAGE_FORMAT_ALPHA
    }
    if (ihdr.bitDepth == UInt8(16)) {
        format |= PNG_C_IMAGE_FORMAT_LINEAR
    }
    if (ihdr.colorType == Indexed) {
        format |= PNG_C_IMAGE_FORMAT_COLORMAP
    }

    let entries = match (ihdr.colorType) {
        case Grayscale => UInt32(1) << UInt32(ihdr.bitDepth)
        case Indexed => paletteEntries
        case _ => UInt32(256)
    }
    let selectedChromaticities = match (masteringChromaticities) {
        case Some(value) => Some(value)
        case None => if (hasCicp) {
            match (chromaticities) {
                case Some(value) => Some(value)
                case None => Some(PngChromaticities())
            }
        } else if (hasSrgb) {
            None<PngChromaticities>
        } else {
            chromaticities
        }
    }
    let colorspaceNotSrgb = match (selectedChromaticities) {
        case Some(value) => !pngCImageChromaticitiesMatchSrgb(value)
        case None => false
    }
    let flags = if ((format & PNG_C_IMAGE_FORMAT_COLOR) != UInt32(0) &&
        colorspaceNotSrgb) {
        PNG_C_IMAGE_FLAG_COLORSPACE_NOT_SRGB
    } else {
        UInt32(0)
    }
    PngCImageHeaderFacts(
        format,
        flags,
        if (entries > UInt32(256)) { UInt32(256) } else { entries }
    )
}

private func pngCImageRegister(state: PngCImageReadState): CPointer<Unit> {
    let id = PNG_C_IMAGE_NEXT_ID.fetchAdd(1)
    let memory = unsafe { LibC.malloc<Int64>() }
    if (memory.isNull()) {
        throw PngFormatException(
            DecodeLimitExceeded, -1, "png_image_read: out of memory"
        )
    }
    unsafe { memory.write(id) }
    synchronized(PNG_C_IMAGE_REGISTRY_MUTEX) {
        PNG_C_IMAGE_REGISTRY[id] = state
    }
    CPointer<Unit>(memory)
}

private func pngCImageTake(handle: CPointer<Unit>): ?PngCImageReadState {
    if (handle.isNull()) { return None<PngCImageReadState> }
    let id = unsafe { CPointer<Int64>(handle).read() }
    synchronized(PNG_C_IMAGE_REGISTRY_MUTEX) {
        PNG_C_IMAGE_REGISTRY.remove(id)
    }
}

private func pngCImageReleaseHandle(handle: CPointer<Unit>): ?PngCImageReadState {
    if (handle.isNull()) { return None<PngCImageReadState> }
    let state = pngCImageTake(handle)
    unsafe { LibC.free(handle) }
    state
}

private func pngCImageChannels(format: UInt32): UInt32 {
    (format & (PNG_C_IMAGE_FORMAT_COLOR | PNG_C_IMAGE_FORMAT_ALPHA)) + UInt32(1)
}

private func pngCImagePixelChannels(format: UInt32): UInt32 {
    if ((format & PNG_C_IMAGE_FORMAT_COLORMAP) != UInt32(0)) {
        UInt32(1)
    } else {
        pngCImageChannels(format)
    }
}

private func pngCImageComponentBytes(format: UInt32): UInt32 {
    if ((format & PNG_C_IMAGE_FORMAT_LINEAR) != UInt32(0)) {
        UInt32(2)
    } else {
        UInt32(1)
    }
}

private func pngCImageCheckedStride(
    image: PngCImage,
    rowStride: Int32,
    label: String
): Int64 {
    if ((image.format & !(PNG_C_IMAGE_FORMAT_MASK)) != UInt32(0)) {
        throw PngFormatException(
            InvalidArgument, -1, "${label}: unsupported format bits"
        )
    }
    let minimum = UInt64(image.width) * UInt64(pngCImagePixelChannels(image.format))
    if (minimum == UInt64(0) || minimum > UInt64(Int32.Max)) {
        throw PngFormatException(
            DecodeLimitExceeded, -1, "${label}: image row stride too large"
        )
    }
    let stride = if (rowStride == Int32(0)) { Int64(minimum) } else { Int64(rowStride) }
    let magnitude = if (stride < Int64(0)) { -stride } else { stride }
    if (magnitude < Int64(minimum)) {
        throw PngFormatException(
            InvalidArgument, -1, "${label}: supplied row stride too small"
        )
    }
    let bytes = UInt64(magnitude) * UInt64(image.height) *
        UInt64(pngCImageComponentBytes(image.format))
    if (bytes > UInt64(UInt32.Max) || bytes > PNG_DEFAULT_MAX_TRANSFORMED_BYTES) {
        throw PngFormatException(
            DecodeLimitExceeded, -1, "${label}: image too large"
        )
    }
    stride
}

private func pngCImageDirectFormat(format: UInt32): PngImageFormat {
    let color = (format & PNG_C_IMAGE_FORMAT_COLOR) != UInt32(0)
    let alpha = (format & PNG_C_IMAGE_FORMAT_ALPHA) != UInt32(0)
    let bgr = color && (format & PNG_C_IMAGE_FORMAT_BGR) != UInt32(0)
    let afirst = alpha && (format & PNG_C_IMAGE_FORMAT_AFIRST) != UInt32(0)
    if (!color) {
        if (!alpha) { ImageGray8 }
        else if (afirst) { ImageAlphaGray8 }
        else { ImageGrayAlpha8 }
    } else if (!alpha) {
        if (bgr) { ImageBgr8 } else { ImageRgb8 }
    } else if (bgr) {
        if (afirst) { ImageAbgr8 } else { ImageBgra8 }
    } else {
        if (afirst) { ImageArgb8 } else { ImageRgba8 }
    }
}

private func pngCImageLinearFormat(format: UInt32): PngLinearImageFormat {
    let color = (format & PNG_C_IMAGE_FORMAT_COLOR) != UInt32(0)
    let alpha = (format & PNG_C_IMAGE_FORMAT_ALPHA) != UInt32(0)
    let bgr = color && (format & PNG_C_IMAGE_FORMAT_BGR) != UInt32(0)
    let afirst = alpha && (format & PNG_C_IMAGE_FORMAT_AFIRST) != UInt32(0)
    if (!color) {
        if (!alpha) { LinearGray }
        else if (afirst) { LinearAlphaGray }
        else { LinearGrayAlpha }
    } else if (!alpha) {
        if (bgr) { LinearBgr } else { LinearRgb }
    } else if (bgr) {
        if (afirst) { LinearAbgr } else { LinearBgra }
    } else {
        if (afirst) { LinearArgb } else { LinearRgba }
    }
}

private func pngCImageColormapFormat(format: UInt32): PngColormapFormat {
    if ((format & PNG_C_IMAGE_FORMAT_COLOR) == UInt32(0) ||
        (format & PNG_C_IMAGE_FORMAT_LINEAR) != UInt32(0) ||
        (format & PNG_C_IMAGE_FORMAT_ASSOCIATED_ALPHA) != UInt32(0)) {
        throw PngFormatException(
            UnsupportedTransform, -1,
            "png_image color-map format is not supported"
        )
    }
    let alpha = (format & PNG_C_IMAGE_FORMAT_ALPHA) != UInt32(0)
    let bgr = (format & PNG_C_IMAGE_FORMAT_BGR) != UInt32(0)
    let afirst = alpha && (format & PNG_C_IMAGE_FORMAT_AFIRST) != UInt32(0)
    if (!alpha) {
        if (bgr) { ColormapBgr8 } else { ColormapRgb8 }
    } else if (bgr) {
        if (afirst) { ColormapAbgr8 } else { ColormapBgra8 }
    } else {
        if (afirst) { ColormapArgb8 } else { ColormapRgba8 }
    }
}

private func pngCImageBackground(background: CPointer<Unit>): PngSrgbColor8 {
    if (background.isNull()) { return PngSrgbColor8() }
    let bytes = unsafe { CPointer<UInt8>(background) }
    PngSrgbColor8(
        unsafe { bytes.read(Int64(0)) },
        unsafe { bytes.read(Int64(1)) },
        unsafe { bytes.read(Int64(2)) }
    )
}

private func pngCImageWriteBytes(output: CPointer<Unit>, bytes: Array<Byte>): Unit {
    let target = unsafe { CPointer<UInt8>(output) }
    var index: Int64 = Int64(0)
    while (index < bytes.size) {
        unsafe { target.write(index, bytes[index]) }
        index += Int64(1)
    }
}

private func pngCImageWriteComponents(
    output: CPointer<Unit>,
    components: Array<UInt16>
): Unit {
    let target = unsafe { CPointer<UInt16>(output) }
    var index: Int64 = Int64(0)
    while (index < components.size) {
        unsafe { target.write(index, components[index]) }
        index += Int64(1)
    }
}

private func pngCImageReadBytes(input: CPointer<Unit>, count: Int64): Array<Byte> {
    let source = unsafe { CPointer<UInt8>(input) }
    let output = Array<Byte>(count, repeat: UInt8(0))
    var index: Int64 = Int64(0)
    while (index < count) {
        output[index] = unsafe { source.read(index) }
        index += Int64(1)
    }
    output
}

private func pngCImageReadComponents(
    input: CPointer<Unit>,
    count: Int64
): Array<UInt16> {
    let source = unsafe { CPointer<UInt16>(input) }
    let output = Array<UInt16>(count, repeat: UInt16(0))
    var index: Int64 = Int64(0)
    while (index < count) {
        output[index] = unsafe { source.read(index) }
        index += Int64(1)
    }
    output
}

private func pngCImageFastControls(flags: UInt32): PngWriteControlState {
    let controls = PngWriteControlState()
    if ((flags & PNG_C_IMAGE_FLAG_FAST) != UInt32(0)) {
        controls.setFilter(WriteFilterNone)
        controls.setCompressionLevel(Int32(3))
    }
    controls
}

private func pngCImageWriteMetadata(image: PngCImage): PngWriteMetadata {
    let metadata = PngWriteMetadata()
    if ((image.flags & PNG_C_IMAGE_FLAG_COLORSPACE_NOT_SRGB) != UInt32(0)) {
        metadata.setGamma(UInt32(45455))
    } else {
        metadata.setSrgb(Perceptual)
    }
    metadata
}

private func pngCImageComposite8(
    foreground: UInt8,
    alpha: UInt8,
    background: UInt8
): UInt8 {
    UInt8(
        (UInt32(foreground) * UInt32(alpha) +
            UInt32(background) * (UInt32(255) - UInt32(alpha)) + UInt32(127)) /
        UInt32(255)
    )
}

private func pngCImageAssociate8(component: UInt8, alpha: UInt8): UInt8 {
    UInt8(
        (UInt32(component) * UInt32(alpha) + UInt32(127)) / UInt32(255)
    )
}

private func pngCImageGray8(red: UInt8, green: UInt8, blue: UInt8): UInt8 {
    UInt8(
        (UInt32(6968) * UInt32(red) + UInt32(23434) * UInt32(green) +
            UInt32(2366) * UInt32(blue) + UInt32(16384)) >> UInt32(15)
    )
}

private func pngCImageDirectBackground(
    target: CPointer<UInt8>,
    offset: Int64,
    format: UInt32,
    background: CPointer<Unit>
): (UInt8, UInt8, UInt8) {
    if (background.isNotNull()) {
        let solid = unsafe { CPointer<UInt8>(background) }
        return (
            unsafe { solid.read(Int64(0)) },
            unsafe { solid.read(Int64(1)) },
            unsafe { solid.read(Int64(2)) }
        )
    }
    if ((format & PNG_C_IMAGE_FORMAT_COLOR) == UInt32(0)) {
        let gray = unsafe { target.read(offset) }
        return (gray, gray, gray)
    }
    let bgr = (format & PNG_C_IMAGE_FORMAT_BGR) != UInt32(0)
    let first = unsafe { target.read(offset) }
    let green = unsafe { target.read(offset + Int64(1)) }
    let third = unsafe { target.read(offset + Int64(2)) }
    if (bgr) { (third, green, first) } else { (first, green, third) }
}

private func pngCImageWriteDirectPixel(
    target: CPointer<UInt8>,
    offset: Int64,
    format: UInt32,
    red: UInt8,
    green: UInt8,
    blue: UInt8,
    alpha: UInt8,
    background: CPointer<Unit>
): Unit {
    let color = (format & PNG_C_IMAGE_FORMAT_COLOR) != UInt32(0)
    let hasAlpha = (format & PNG_C_IMAGE_FORMAT_ALPHA) != UInt32(0)
    let bgr = color && (format & PNG_C_IMAGE_FORMAT_BGR) != UInt32(0)
    let afirst = hasAlpha && (format & PNG_C_IMAGE_FORMAT_AFIRST) != UInt32(0)
    let associated = hasAlpha &&
        (format & PNG_C_IMAGE_FORMAT_ASSOCIATED_ALPHA) != UInt32(0)
    if (!color) {
        var gray = pngCImageGray8(red, green, blue)
        if (!hasAlpha) {
            let backgroundGray = if (background.isNotNull()) {
                let solid = unsafe { CPointer<UInt8>(background) }
                unsafe { solid.read(Int64(1)) }
            } else {
                unsafe { target.read(offset) }
            }
            gray = pngCImageComposite8(gray, alpha, backgroundGray)
        } else if (associated) {
            gray = pngCImageAssociate8(gray, alpha)
        }
        if (!hasAlpha) {
            unsafe { target.write(offset, gray) }
        } else if (afirst) {
            unsafe {
                target.write(offset, alpha)
                target.write(offset + Int64(1), gray)
            }
        } else {
            unsafe {
                target.write(offset, gray)
                target.write(offset + Int64(1), alpha)
            }
        }
        return
    }
    var r = red
    var g = green
    var b = blue
    if (!hasAlpha) {
        let (backgroundRed, backgroundGreen, backgroundBlue) =
            pngCImageDirectBackground(target, offset, format, background)
        r = pngCImageComposite8(r, alpha, backgroundRed)
        g = pngCImageComposite8(g, alpha, backgroundGreen)
        b = pngCImageComposite8(b, alpha, backgroundBlue)
    } else if (associated) {
        r = pngCImageAssociate8(r, alpha)
        g = pngCImageAssociate8(g, alpha)
        b = pngCImageAssociate8(b, alpha)
    }
    let first = if (bgr) { b } else { r }
    let third = if (bgr) { r } else { b }
    if (!hasAlpha) {
        unsafe {
            target.write(offset, first)
            target.write(offset + Int64(1), g)
            target.write(offset + Int64(2), third)
        }
    } else if (afirst) {
        unsafe {
            target.write(offset, alpha)
            target.write(offset + Int64(1), first)
            target.write(offset + Int64(2), g)
            target.write(offset + Int64(3), third)
        }
    } else {
        unsafe {
            target.write(offset, first)
            target.write(offset + Int64(1), g)
            target.write(offset + Int64(2), third)
            target.write(offset + Int64(3), alpha)
        }
    }
}

private func pngCImageFinishDirect(
    state: PngCImageReadState,
    image: PngCImage,
    background: CPointer<Unit>,
    buffer: CPointer<Unit>,
    stride: Int64
): Unit {
    let result = state.image.finishRead(ImageRgba8)
    let target = unsafe { CPointer<UInt8>(buffer) }
    let channels = Int64(pngCImagePixelChannels(image.format))
    let absoluteStride = if (stride < Int64(0)) { -stride } else { stride }
    var rowIndex: Int64 = Int64(0)
    while (rowIndex < Int64(image.height)) {
        let source = result.row(rowIndex)
        let physicalRow = if (stride < Int64(0)) {
            Int64(image.height) - Int64(1) - rowIndex
        } else {
            rowIndex
        }
        let rowStart = physicalRow * absoluteStride
        var sourceOffset: Int64 = Int64(0)
        var targetOffset = rowStart
        while (sourceOffset < source.size) {
            pngCImageWriteDirectPixel(
                target, targetOffset, image.format,
                source[sourceOffset],
                source[sourceOffset + Int64(1)],
                source[sourceOffset + Int64(2)],
                source[sourceOffset + Int64(3)],
                background
            )
            sourceOffset += Int64(4)
            targetOffset += channels
        }
        rowIndex += Int64(1)
    }
}

private func pngCImageFinishLinear(
    state: PngCImageReadState,
    image: PngCImage,
    buffer: CPointer<Unit>,
    stride: Int64
): Unit {
    let format = pngCImageLinearFormat(image.format)
    let associated = (image.format & PNG_C_IMAGE_FORMAT_ASSOCIATED_ALPHA) != UInt32(0) &&
        (image.format & PNG_C_IMAGE_FORMAT_ALPHA) != UInt32(0)
    state.image.setAssume16BitSrgb(
        (image.flags & PNG_C_IMAGE_FLAG_16BIT_SRGB) != UInt32(0)
    )
    let result = state.image.finishReadLinearStrided(
        format, associated, stride, UInt16(0)
    )
    pngCImageWriteComponents(buffer, result.components())
}

private func pngCImageFinishColormap(
    state: PngCImageReadState,
    image: PngCImage,
    background: CPointer<Unit>,
    buffer: CPointer<Unit>,
    colormap: CPointer<Unit>,
    stride: Int64
): UInt32 {
    if (colormap.isNull()) {
        throw PngFormatException(
            InvalidArgument, -1,
            "png_image_finish_read[color-map]: no color-map"
        )
    }
    let result = state.image.finishReadColormapStrided(
        pngCImageColormapFormat(image.format),
        pngCImageBackground(background),
        stride,
        UInt8(0)
    )
    pngCImageWriteBytes(buffer, result.indices())
    pngCImageWriteBytes(colormap, result.colormap())
    UInt32(result.entryCount)
}

private func pngCImageBeginBytes(
    image: CPointer<PngCImage>, value: PngCImage, bytes: Array<Byte>
): Int32 {
    var output = value
    let limits = PngReadLimits()
    let facts = pngCImageHeaderFacts(bytes, limits)
    let native = PngImage()
    native.beginReadFromMemory(bytes, limits)
    output.width = native.width()
    output.height = native.height()
    output.format = facts.format
    output.flags = facts.flags
    output.colormapEntries = facts.colormapEntries
    output.opaque = pngCImageRegister(PngCImageReadState(native))
    pngCImageWrite(image, output)
    Int32(1)
}

@C
public func png_image_begin_read_from_memory(
    image: CPointer<PngCImage>,
    memory: CPointer<Unit>,
    size: UIntNative
): Int32 {
    if (image.isNull()) { return Int32(0) }
    var value = unsafe { image.read() }
    if (value.version != PNG_IMAGE_VERSION) {
        return pngCImageFail(
            image, value,
            "png_image_begin_read_from_memory: incorrect PNG_IMAGE_VERSION"
        )
    }
    if (value.opaque.isNotNull()) {
        return pngCImageFail(image, value, "png_image_read: opaque pointer not NULL")
    }
    value = pngCImageClearMessage(value)
    value.warningOrError = UInt32(0)
    value.flags = UInt32(0)
    try {
        let bytes = pngCImageReadInput(memory, size)
        pngCImageBeginBytes(image, value, bytes)
    } catch (error: PngFormatException) {
        pngCImageFail(image, value, error.message)
    } catch (error: Exception) {
        pngCImageFail(image, value, error.message)
    }
}

@C
public func png_image_begin_read_from_stdio(
    image: CPointer<PngCImage>, file: CPointer<Unit>
): Int32 {
    if (image.isNull()) { return Int32(0) }
    var value = unsafe { image.read() }
    if (value.version != PNG_IMAGE_VERSION) {
        return pngCImageFail(
            image, value,
            "png_image_begin_read_from_stdio: incorrect PNG_IMAGE_VERSION"
        )
    }
    if (file.isNull() || value.opaque.isNotNull()) {
        return pngCImageFail(
            image, value, "png_image_begin_read_from_stdio: invalid argument"
        )
    }
    value = pngCImageClearMessage(value)
    value.warningOrError = UInt32(0)
    value.flags = UInt32(0)
    try {
        pngCImageBeginBytes(
            image, value,
            pngCImageReadStdio(file, "png_image_begin_read_from_stdio")
        )
    } catch (error: PngFormatException) {
        pngCImageFail(image, value, error.message)
    } catch (error: Exception) {
        pngCImageFail(image, value, error.message)
    }
}

@C
public func png_image_begin_read_from_file(
    image: CPointer<PngCImage>, fileName: CString
): Int32 {
    if (image.isNull()) { return Int32(0) }
    var value = unsafe { image.read() }
    if (value.version != PNG_IMAGE_VERSION) {
        return pngCImageFail(
            image, value,
            "png_image_begin_read_from_file: incorrect PNG_IMAGE_VERSION"
        )
    }
    if (fileName.isNull() || value.opaque.isNotNull()) {
        return pngCImageFail(
            image, value, "png_image_begin_read_from_file: invalid argument"
        )
    }
    value = pngCImageClearMessage(value)
    value.warningOrError = UInt32(0)
    value.flags = UInt32(0)
    let file = pngCImageOpen(fileName, "rb")
    if (file.isNull()) {
        return pngCImageFail(
            image, value, "png_image_begin_read_from_file: open failed"
        )
    }
    var fileOpen = true
    try {
        let bytes = pngCImageReadStdio(file, "png_image_begin_read_from_file")
        if (unsafe { fclose(file) } != Int32(0)) {
            fileOpen = false
            return pngCImageFail(
                image, value, "png_image_begin_read_from_file: close failed"
            )
        }
        fileOpen = false
        pngCImageBeginBytes(image, value, bytes)
    } catch (error: PngFormatException) {
        if (fileOpen) { pngCImageCloseQuietly(file) }
        pngCImageFail(image, value, error.message)
    } catch (error: Exception) {
        if (fileOpen) { pngCImageCloseQuietly(file) }
        pngCImageFail(image, value, error.message)
    }
}

@C
public func png_image_finish_read(
    image: CPointer<PngCImage>,
    background: CPointer<Unit>,
    buffer: CPointer<Unit>,
    rowStride: Int32,
    colormap: CPointer<Unit>
): Int32 {
    if (image.isNull()) { return Int32(0) }
    var value = unsafe { image.read() }
    if (value.version != PNG_IMAGE_VERSION) {
        return pngCImageFail(
            image, value, "png_image_finish_read: damaged PNG_IMAGE_VERSION"
        )
    }
    if (value.opaque.isNull() || buffer.isNull()) {
        return pngCImageFail(image, value, "png_image_finish_read: invalid argument")
    }
    let handle = value.opaque
    let state = pngCImageReleaseHandle(handle)
    value.opaque = CPointer<Unit>()
    try {
        let stride = pngCImageCheckedStride(value, rowStride, "png_image_finish_read")
        match (state) {
            case Some(readState) =>
                if ((value.format & PNG_C_IMAGE_FORMAT_COLORMAP) != UInt32(0)) {
                    value.colormapEntries = pngCImageFinishColormap(
                        readState, value, background, buffer, colormap, stride
                    )
                } else if ((value.format & PNG_C_IMAGE_FORMAT_LINEAR) != UInt32(0)) {
                    pngCImageFinishLinear(readState, value, buffer, stride)
                } else {
                    pngCImageFinishDirect(readState, value, background, buffer, stride)
                }
            case None => throw PngFormatException(
                InvalidArgument, -1,
                "png_image_finish_read: invalid or released image state"
            )
        }
        pngCImageWrite(image, value)
        Int32(1)
    } catch (error: PngFormatException) {
        match (state) {
            case Some(readState) => readState.image.free()
            case None => ()
        }
        pngCImageFail(image, value, error.message)
    } catch (error: Exception) {
        match (state) {
            case Some(readState) => readState.image.free()
            case None => ()
        }
        pngCImageFail(image, value, error.message)
    }
}

@C
public func png_image_free(image: CPointer<PngCImage>): Unit {
    if (image.isNull()) { return }
    var value = unsafe { image.read() }
    if (value.opaque.isNotNull()) {
        match (pngCImageReleaseHandle(value.opaque)) {
            case Some(state) => state.image.free()
            case None => ()
        }
        value.opaque = CPointer<Unit>()
        pngCImageWrite(image, value)
    }
}

private func pngCImageWriteDirect(
    image: PngCImage,
    buffer: CPointer<Unit>,
    stride: Int64,
    controls: PngWriteControlState,
    operation: String
): Array<Byte> {
    if ((image.format & PNG_C_IMAGE_FORMAT_ASSOCIATED_ALPHA) != UInt32(0)) {
        throw PngFormatException(
            UnsupportedTransform, -1,
            "${operation}: unsupported transformation"
        )
    }
    let components = UInt64(if (stride < Int64(0)) { -stride } else { stride }) *
        UInt64(image.height)
    let bytes = pngCImageReadBytes(buffer, Int64(components))
    writePngImageToMemory(
        PngImageBuffer(
            image.width, image.height, pngCImageDirectFormat(image.format),
            bytes, stride
        ),
        pngCImageWriteMetadata(image), controls, None, PngWriteLimits()
    )
}

private func pngCImageWriteLinear(
    image: PngCImage,
    convertTo8Bit: Bool,
    buffer: CPointer<Unit>,
    stride: Int64,
    controls: PngWriteControlState,
    operation: String
): Array<Byte> {
    if ((image.format & PNG_C_IMAGE_FORMAT_ASSOCIATED_ALPHA) != UInt32(0)) {
        throw PngFormatException(
            UnsupportedTransform, -1,
            "${operation}: unsupported transformation"
        )
    }
    let components = UInt64(if (stride < Int64(0)) { -stride } else { stride }) *
        UInt64(image.height)
    let values = pngCImageReadComponents(buffer, Int64(components))
    writePngLinearImageToMemoryWithColorspace(
        PngLinearImageBuffer(
            image.width, image.height, pngCImageLinearFormat(image.format),
            values, false, stride
        ),
        convertTo8Bit,
        (image.flags & PNG_C_IMAGE_FLAG_COLORSPACE_NOT_SRGB) != UInt32(0),
        PngWriteMetadata(), controls, None, PngWriteLimits()
    )
}

private func pngCImageWriteColormap(
    image: PngCImage,
    buffer: CPointer<Unit>,
    colormap: CPointer<Unit>,
    stride: Int64,
    controls: PngWriteControlState,
    operation: String
): Array<Byte> {
    if (colormap.isNull() || image.colormapEntries == UInt32(0) ||
        image.colormapEntries > UInt32(256)) {
        throw PngFormatException(
            InvalidArgument, -1,
            "${operation}: no color-map for color-mapped image"
        )
    }
    let format = pngCImageColormapFormat(image.format)
    let components = UInt64(if (stride < Int64(0)) { -stride } else { stride }) *
        UInt64(image.height)
    let indices = pngCImageReadBytes(buffer, Int64(components))
    let entries = Int64(image.colormapEntries) * Int64(format.channelCount())
    let table = pngCImageReadBytes(colormap, entries)
    writePngColormapImageToMemory(
        PngColormapImageBuffer(
            image.width, image.height, format, indices, table, stride
        ),
        pngCImageWriteMetadata(image), controls, None, PngWriteLimits()
    )
}

private func pngCImageEncoded(
    image: PngCImage,
    convertTo8Bit: Bool,
    buffer: CPointer<Unit>,
    rowStride: Int32,
    colormap: CPointer<Unit>,
    operation: String
): Array<Byte> {
    if (image.width == UInt32(0) || image.height == UInt32(0) ||
        buffer.isNull() ||
        (image.flags & !(PNG_C_IMAGE_FLAG_MASK)) != UInt32(0)) {
        throw PngFormatException(
            InvalidArgument, -1,
            "${operation}: invalid argument"
        )
    }
    let stride = pngCImageCheckedStride(image, rowStride, operation)
    let controls = pngCImageFastControls(image.flags)
    if ((image.format & PNG_C_IMAGE_FORMAT_COLORMAP) != UInt32(0)) {
        pngCImageWriteColormap(
            image, buffer, colormap, stride, controls, operation
        )
    } else if ((image.format & PNG_C_IMAGE_FORMAT_LINEAR) != UInt32(0)) {
        pngCImageWriteLinear(
            image, convertTo8Bit, buffer, stride, controls, operation
        )
    } else {
        pngCImageWriteDirect(image, buffer, stride, controls, operation)
    }
}

@C
public func png_image_write_to_memory(
    image: CPointer<PngCImage>,
    memory: CPointer<Unit>,
    memoryBytes: CPointer<UIntNative>,
    convertTo8Bit: Int32,
    buffer: CPointer<Unit>,
    rowStride: Int32,
    colormap: CPointer<Unit>
): Int32 {
    if (image.isNull()) { return Int32(0) }
    var value = unsafe { image.read() }
    if (value.version != PNG_IMAGE_VERSION) {
        return pngCImageFail(
            image, value,
            "png_image_write_to_memory: incorrect PNG_IMAGE_VERSION"
        )
    }
    if (memoryBytes.isNull() || buffer.isNull() || value.opaque.isNotNull()) {
        return pngCImageFail(
            image, value, "png_image_write_to_memory: invalid argument"
        )
    }
    value = pngCImageClearMessage(value)
    value.warningOrError = UInt32(0)
    let capacity = if (memory.isNull()) {
        unsafe { memoryBytes.write(UIntNative(0)) }
        UInt64(0)
    } else {
        UInt64(unsafe { memoryBytes.read() })
    }
    try {
        let encoded = pngCImageEncoded(
            value, convertTo8Bit != Int32(0), buffer, rowStride, colormap,
            "png_image_write_to_memory"
        )
        unsafe { memoryBytes.write(UIntNative(encoded.size)) }
        if (memory.isNull()) {
            pngCImageWrite(image, value)
            return Int32(1)
        }
        if (capacity < UInt64(encoded.size)) {
            pngCImageWrite(image, value)
            return Int32(0)
        }
        pngCImageWriteBytes(memory, encoded)
        pngCImageWrite(image, value)
        Int32(1)
    } catch (error: PngFormatException) {
        pngCImageFail(image, value, error.message)
    } catch (error: Exception) {
        pngCImageFail(image, value, error.message)
    }
}

@C
public func png_image_write_to_stdio(
    image: CPointer<PngCImage>,
    file: CPointer<Unit>,
    convertTo8Bit: Int32,
    buffer: CPointer<Unit>,
    rowStride: Int32,
    colormap: CPointer<Unit>
): Int32 {
    if (image.isNull()) { return Int32(0) }
    var value = unsafe { image.read() }
    if (value.version != PNG_IMAGE_VERSION) {
        return pngCImageFail(
            image, value,
            "png_image_write_to_stdio: incorrect PNG_IMAGE_VERSION"
        )
    }
    if (file.isNull() || buffer.isNull() || value.opaque.isNotNull()) {
        return pngCImageFail(
            image, value, "png_image_write_to_stdio: invalid argument"
        )
    }
    value = pngCImageClearMessage(value)
    value.warningOrError = UInt32(0)
    try {
        let encoded = pngCImageEncoded(
            value, convertTo8Bit != Int32(0), buffer, rowStride, colormap,
            "png_image_write_to_stdio"
        )
        pngCImageWriteStdio(file, encoded, "png_image_write_to_stdio")
        pngCImageWrite(image, value)
        Int32(1)
    } catch (error: PngFormatException) {
        pngCImageFail(image, value, error.message)
    } catch (error: Exception) {
        pngCImageFail(image, value, error.message)
    }
}

@C
public func png_image_write_to_file(
    image: CPointer<PngCImage>,
    fileName: CString,
    convertTo8Bit: Int32,
    buffer: CPointer<Unit>,
    rowStride: Int32,
    colormap: CPointer<Unit>
): Int32 {
    if (image.isNull()) { return Int32(0) }
    var value = unsafe { image.read() }
    if (value.version != PNG_IMAGE_VERSION) {
        return pngCImageFail(
            image, value,
            "png_image_write_to_file: incorrect PNG_IMAGE_VERSION"
        )
    }
    if (fileName.isNull() || buffer.isNull() || value.opaque.isNotNull()) {
        return pngCImageFail(
            image, value, "png_image_write_to_file: invalid argument"
        )
    }
    value = pngCImageClearMessage(value)
    value.warningOrError = UInt32(0)
    let file = pngCImageOpen(fileName, "wb")
    if (file.isNull()) {
        return pngCImageFail(
            image, value, "png_image_write_to_file: open failed"
        )
    }
    try {
        let encoded = pngCImageEncoded(
            value, convertTo8Bit != Int32(0), buffer, rowStride, colormap,
            "png_image_write_to_file"
        )
        pngCImageWriteStdio(file, encoded, "png_image_write_to_file")
        if (unsafe { fflush(file) } != Int32(0) ||
            unsafe { ferror(file) } != Int32(0)) {
            pngCImageCloseQuietly(file)
            pngCImageRemoveQuietly(fileName)
            return pngCImageFail(
                image, value, "png_image_write_to_file: flush failed"
            )
        }
        if (unsafe { fclose(file) } != Int32(0)) {
            pngCImageRemoveQuietly(fileName)
            return pngCImageFail(
                image, value, "png_image_write_to_file: close failed"
            )
        }
        pngCImageWrite(image, value)
        Int32(1)
    } catch (error: PngFormatException) {
        pngCImageCloseQuietly(file)
        pngCImageRemoveQuietly(fileName)
        pngCImageFail(image, value, error.message)
    } catch (error: Exception) {
        pngCImageCloseQuietly(file)
        pngCImageRemoveQuietly(fileName)
        pngCImageFail(image, value, error.message)
    }
}
