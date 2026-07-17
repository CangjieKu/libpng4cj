package libpng4cj

private let PNG_ADAM7_START_X: Array<UInt32> = [0, 4, 0, 2, 0, 1, 0]
private let PNG_ADAM7_STEP_X: Array<UInt32> = [8, 8, 4, 4, 2, 2, 1]
private let PNG_ADAM7_START_Y: Array<UInt32> = [0, 0, 4, 0, 2, 0, 1]
private let PNG_ADAM7_STEP_Y: Array<UInt32> = [8, 8, 8, 4, 4, 2, 2]

public class PngAdam7PassGeometry {
    public let pass: Int64
    public let startX: UInt32
    public let startY: UInt32
    public let stepX: UInt32
    public let stepY: UInt32
    public let width: UInt32
    public let height: UInt32
    public let rowBytes: UInt64

    init(
        pass: Int64,
        startX: UInt32,
        startY: UInt32,
        stepX: UInt32,
        stepY: UInt32,
        width: UInt32,
        height: UInt32,
        rowBytes: UInt64
    ) {
        this.pass = pass
        this.startX = startX
        this.startY = startY
        this.stepX = stepX
        this.stepY = stepY
        this.width = width
        this.height = height
        this.rowBytes = rowBytes
    }
}

private func pngAdam7Dimension(total: UInt32, start: UInt32, step: UInt32): UInt32 {
    if (total <= start) {
        return UInt32(0)
    }
    UInt32((UInt64(total - start) + UInt64(step) - UInt64(1)) / UInt64(step))
}

public func pngAdam7PassGeometry(ihdr: PngIhdr, pass: Int64): PngAdam7PassGeometry {
    if (pass < 0 || pass >= Int64(7)) {
        throw PngFormatException(InvalidArgument, pass, "Adam7 pass index must be in 0..6")
    }
    let startX = PNG_ADAM7_START_X[pass]
    let startY = PNG_ADAM7_START_Y[pass]
    let stepX = PNG_ADAM7_STEP_X[pass]
    let stepY = PNG_ADAM7_STEP_Y[pass]
    let width = pngAdam7Dimension(ihdr.width, startX, stepX)
    let height = pngAdam7Dimension(ihdr.height, startY, stepY)
    let rowBytes = (UInt64(width) * UInt64(ihdr.pixelDepth) + UInt64(7)) / UInt64(8)
    PngAdam7PassGeometry(pass, startX, startY, stepX, stepY, width, height, rowBytes)
}

public func pngAdam7ExpectedInflatedSize(ihdr: PngIhdr, limits: PngReadLimits): Int64 {
    var total: UInt64 = UInt64(0)
    var pass: Int64 = 0
    while (pass < Int64(7)) {
        let geometry = pngAdam7PassGeometry(ihdr, pass)
        if (geometry.width > UInt32(0) && geometry.height > UInt32(0)) {
            let rowFrameBytes = geometry.rowBytes + UInt64(1)
            let passHeight = UInt64(geometry.height)
            if (passHeight > (limits.maxInflatedBytes - total) / rowFrameBytes) {
                throw PngFormatException(
                    DecodeLimitExceeded,
                    -1,
                    "Adam7 pass rows exceed configured inflated-byte limit"
                )
            }
            total += rowFrameBytes * passHeight
        }
        pass += 1
    }
    if (total == UInt64(0)) {
        throw PngFormatException(InflatedSizeMismatch, -1, "Adam7 image has no pass rows")
    }
    Int64(total)
}

private func pngAdam7PackedSample(row: Array<Byte>, bitDepth: UInt8, pixel: Int64): UInt8 {
    let bitOffset = UInt64(pixel) * UInt64(bitDepth)
    let byteOffset = Int64(bitOffset / UInt64(8))
    let shift = UInt32(8) - UInt32(bitDepth) - UInt32(bitOffset % UInt64(8))
    let mask = (UInt32(1) << UInt32(bitDepth)) - UInt32(1)
    UInt8((UInt32(row[byteOffset]) >> shift) & mask)
}

private func pngAdam7WritePackedSample(
    row: Array<Byte>,
    bitDepth: UInt8,
    pixel: UInt32,
    sample: UInt8
): Unit {
    let bitOffset = UInt64(pixel) * UInt64(bitDepth)
    let byteOffset = Int64(bitOffset / UInt64(8))
    let shift = UInt32(8) - UInt32(bitDepth) - UInt32(bitOffset % UInt64(8))
    let mask = (UInt32(1) << UInt32(bitDepth)) - UInt32(1)
    let cleared = UInt32(row[byteOffset]) & !(mask << shift)
    row[byteOffset] = UInt8(cleared | ((UInt32(sample) & mask) << shift))
}

private func pngAdam7ScatterRow(
    target: Array<Byte>,
    passRow: Array<Byte>,
    ihdr: PngIhdr,
    geometry: PngAdam7PassGeometry
): Unit {
    if (ihdr.pixelDepth < UInt16(8)) {
        var pixel: Int64 = 0
        while (pixel < Int64(geometry.width)) {
            let targetX = geometry.startX + UInt32(pixel) * geometry.stepX
            pngAdam7WritePackedSample(
                target,
                ihdr.bitDepth,
                targetX,
                pngAdam7PackedSample(passRow, ihdr.bitDepth, pixel)
            )
            pixel += 1
        }
        return
    }

    let pixelBytes = Int64(ihdr.pixelDepth / UInt16(8))
    var pixel: Int64 = 0
    while (pixel < Int64(geometry.width)) {
        let sourceOffset = pixel * pixelBytes
        let targetX = geometry.startX + UInt32(pixel) * geometry.stepX
        let targetOffset = Int64(targetX) * pixelBytes
        var byteIndex: Int64 = 0
        while (byteIndex < pixelBytes) {
            target[targetOffset + byteIndex] = passRow[sourceOffset + byteIndex]
            byteIndex += 1
        }
        pixel += 1
    }
}

func decodeAdam7InflatedRows(inflated: Array<Byte>, ihdr: PngIhdr): Array<Array<Byte>> {
    let fullRowBytes = Int64(ihdr.rowBytes)
    let rows = Array<Array<Byte>>(Int64(ihdr.height), repeat: Array<Byte>())
    var rowIndex: Int64 = 0
    while (rowIndex < rows.size) {
        rows[rowIndex] = Array<Byte>(fullRowBytes, repeat: UInt8(0))
        rowIndex += 1
    }
    let filterBytesPerPixel = pngFilterBytesPerPixel(ihdr)
    var sourceOffset: Int64 = 0
    var pass: Int64 = 0
    while (pass < Int64(7)) {
        let geometry = pngAdam7PassGeometry(ihdr, pass)
        if (geometry.width > UInt32(0) && geometry.height > UInt32(0)) {
            let passRowBytes = Int64(geometry.rowBytes)
            var previous = Array<Byte>(passRowBytes, repeat: UInt8(0))
            var passRowIndex: UInt32 = UInt32(0)
            while (passRowIndex < geometry.height) {
                let filterType = inflated[sourceOffset]
                let filtered = copyByteRange(inflated, sourceOffset + 1, passRowBytes)
                let decoded = unfilterPngRow(
                    filterType,
                    filtered,
                    previous,
                    filterBytesPerPixel
                )
                let targetY = geometry.startY + passRowIndex * geometry.stepY
                pngAdam7ScatterRow(rows[Int64(targetY)], decoded, ihdr, geometry)
                previous = decoded
                sourceOffset += passRowBytes + 1
                passRowIndex += 1
            }
        }
        pass += 1
    }
    if (sourceOffset != inflated.size) {
        throw PngFormatException(
            InflatedSizeMismatch,
            sourceOffset,
            "Adam7 pass rows do not consume the exact inflated stream"
        )
    }
    rows
}
