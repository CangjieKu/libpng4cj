package libpng4cj

class PngStrideGeometry {
    let minimum: Int64
    let rowStride: Int64
    let absoluteStride: Int64
    let height: Int64
    let storageCount: Int64

    init(
        minimum: Int64,
        height: UInt32,
        requestedStride: Int64,
        label: String
    ) {
        if (minimum <= Int64(0) || height == UInt32(0)) {
            throw PngFormatException(
                InvalidArgument, -1, "${label} stride geometry must be positive"
            )
        }
        let stride = if (requestedStride == Int64(0)) {
            minimum
        } else {
            requestedStride
        }
        if (stride == Int64.Min) {
            throw PngFormatException(
                InvalidArgument, -1, "${label} row stride cannot be Int64.Min"
            )
        }
        let magnitude = if (stride < Int64(0)) { -stride } else { stride }
        if (magnitude < minimum) {
            throw PngFormatException(
                InvalidArgument, -1, "${label} row stride is smaller than one row"
            )
        }
        let rows = UInt64(height)
        if (rows > UInt64(Int64.Max) / UInt64(magnitude)) {
            throw PngFormatException(
                DecodeLimitExceeded, -1, "${label} strided storage exceeds Int64"
            )
        }
        this.minimum = minimum
        rowStride = stride
        absoluteStride = magnitude
        this.height = Int64(height)
        storageCount = Int64(rows * UInt64(magnitude))
    }

    func logicalRowStart(index: Int64, label: String): Int64 {
        if (index < Int64(0) || index >= height) {
            throw PngFormatException(
                InvalidArgument, index, "${label} row index is out of bounds"
            )
        }
        let physicalRow = if (rowStride < Int64(0)) {
            height - Int64(1) - index
        } else {
            index
        }
        physicalRow * absoluteStride
    }
}

func pngStrideGeometry(
    minimum: Int64,
    height: UInt32,
    rowStride: Int64,
    label: String
): PngStrideGeometry {
    PngStrideGeometry(minimum, height, rowStride, label)
}

func pngStrideChargeRead(
    storageComponents: Int64,
    componentBytes: Int64,
    extraBytes: Int64,
    limits: PngReadLimits,
    label: String
): Unit {
    if (storageComponents < Int64(0) || componentBytes <= Int64(0) ||
        extraBytes < Int64(0)) {
        throw PngFormatException(
            InvalidArgument, -1, "${label} read accounting is invalid"
        )
    }
    let components = UInt64(storageComponents)
    let size = UInt64(componentBytes)
    let extra = UInt64(extraBytes)
    if (components > UInt64.Max / size) {
        throw PngFormatException(
            DecodeLimitExceeded, -1, "${label} strided byte size overflows UInt64"
        )
    }
    let storageBytes = components * size
    if (storageBytes > limits.maxTransformedBytes ||
        extra > limits.maxTransformedBytes - storageBytes) {
        throw PngFormatException(
            DecodeLimitExceeded, -1,
            "${label} strided result exceeds transformed-byte limit"
        )
    }
}

func pngStrideCopyBytePayload(
    source: Array<Byte>,
    sourceGeometry: PngStrideGeometry,
    geometry: PngStrideGeometry,
    padding: UInt8,
    label: String
): Array<Byte> {
    let output = Array<Byte>(geometry.storageCount, repeat: padding)
    var rowIndex: Int64 = Int64(0)
    while (rowIndex < geometry.height) {
        let sourceStart = sourceGeometry.logicalRowStart(rowIndex, label)
        let targetStart = geometry.logicalRowStart(rowIndex, label)
        var offset: Int64 = Int64(0)
        while (offset < geometry.minimum) {
            output[targetStart + offset] = source[sourceStart + offset]
            offset += Int64(1)
        }
        rowIndex += Int64(1)
    }
    output
}

func pngStrideCopyUInt16Payload(
    source: Array<UInt16>,
    sourceGeometry: PngStrideGeometry,
    geometry: PngStrideGeometry,
    padding: UInt16,
    label: String
): Array<UInt16> {
    let output = Array<UInt16>(geometry.storageCount, repeat: padding)
    var rowIndex: Int64 = Int64(0)
    while (rowIndex < geometry.height) {
        let sourceStart = sourceGeometry.logicalRowStart(rowIndex, label)
        let targetStart = geometry.logicalRowStart(rowIndex, label)
        var offset: Int64 = Int64(0)
        while (offset < geometry.minimum) {
            output[targetStart + offset] = source[sourceStart + offset]
            offset += Int64(1)
        }
        rowIndex += Int64(1)
    }
    output
}

func pngStrideByteRow(
    storage: Array<Byte>,
    geometry: PngStrideGeometry,
    index: Int64,
    includePadding: Bool,
    label: String
): Array<Byte> {
    let count = if (includePadding) {
        geometry.absoluteStride
    } else {
        geometry.minimum
    }
    copyByteRange(storage, geometry.logicalRowStart(index, label), count)
}

func pngStrideUInt16Row(
    storage: Array<UInt16>,
    geometry: PngStrideGeometry,
    index: Int64,
    includePadding: Bool,
    label: String
): Array<UInt16> {
    let count = if (includePadding) {
        geometry.absoluteStride
    } else {
        geometry.minimum
    }
    let output = Array<UInt16>(count, repeat: UInt16(0))
    let start = geometry.logicalRowStart(index, label)
    var offset: Int64 = Int64(0)
    while (offset < count) {
        output[offset] = storage[start + offset]
        offset += Int64(1)
    }
    output
}
