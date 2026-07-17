package libpng4cj

import std.collection.ArrayList

private func expectedAdam7FilteredWriteSize(ihdr: PngIhdr, limit: UInt64): UInt64 {
    var total: UInt64 = UInt64(0)
    var pass: Int64 = Int64(0)
    while (pass < Int64(7)) {
        let geometry = pngAdam7PassGeometry(ihdr, pass)
        if (geometry.width > UInt32(0) && geometry.height > UInt32(0)) {
            let frameBytes = geometry.rowBytes + UInt64(1)
            let rowCount = UInt64(geometry.height)
            if (total > limit || rowCount > (limit - total) / frameBytes) {
                throw PngFormatException(
                    DecodeLimitExceeded,
                    pass,
                    "filtered Adam7 rows exceed configured input limit"
                )
            }
            total += rowCount * frameBytes
        }
        pass += Int64(1)
    }
    total
}

func buildFilteredAdam7WriteRows(
    ihdr: PngIhdr,
    rows: Array<Array<Byte>>,
    strategy: PngWriteFilterStrategy,
    maxCompressedInput: UInt64
): Array<Byte> {
    let expected = expectedAdam7FilteredWriteSize(ihdr, maxCompressedInput)
    let out = ArrayList<Byte>()
    let bytesPerPixel = pngFilterBytesPerPixel(ihdr)
    var pass: Int64 = Int64(0)
    while (pass < Int64(7)) {
        let geometry = pngAdam7PassGeometry(ihdr, pass)
        if (geometry.width > UInt32(0) && geometry.height > UInt32(0)) {
            var previous = Array<Byte>(Int64(geometry.rowBytes), repeat: UInt8(0))
            var passRowIndex: UInt32 = UInt32(0)
            while (passRowIndex < geometry.height) {
                let sourceY = geometry.startY + passRowIndex * geometry.stepY
                let passRow = pngAdam7GatherRow(rows[Int64(sourceY)], ihdr, geometry)
                let selected = selectWriteFilter(strategy, passRow, previous, bytesPerPixel)
                out.add(selected.filterType)
                appendWriteBytes(out, selected.bytes)
                previous = passRow
                passRowIndex += UInt32(1)
            }
        }
        pass += Int64(1)
    }
    if (UInt64(out.size) != expected) {
        throw PngFormatException(
            InvalidArgument,
            -1,
            "filtered Adam7 output does not match planned pass geometry"
        )
    }
    out.toArray()
}
