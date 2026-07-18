package libpng4cj

import std.collection.ArrayList

func expectedAdam7FilteredWriteSize(ihdr: PngIhdr, limit: UInt64): UInt64 {
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

private func newAdam7WritePassRows(): Array<ArrayList<Array<Byte>>> {
    let rows = Array<ArrayList<Array<Byte>>>(
        Int64(7), repeat: ArrayList<Array<Byte>>()
    )
    var pass: Int64 = Int64(0)
    while (pass < rows.size) {
        rows[pass] = ArrayList<Array<Byte>>()
        pass += Int64(1)
    }
    rows
}

class PngAdam7WriteSpool {
    private let ihdr: PngIhdr
    private let controls: PngWriteControlInitialization
    private let passRowsValue: Array<ArrayList<Array<Byte>>>

    init(
        ihdr: PngIhdr,
        controls: PngWriteControlInitialization,
        maxFilteredBytes: UInt64
    ) {
        expectedAdam7FilteredWriteSize(ihdr, maxFilteredBytes)
        this.ihdr = ihdr
        this.controls = controls
        passRowsValue = newAdam7WritePassRows()
    }

    func addTransformedRow(row: Array<Byte>, rowIndex: UInt32): Unit {
        var pass: Int64 = Int64(0)
        while (pass < Int64(7)) {
            let geometry = pngAdam7PassGeometry(ihdr, pass)
            if (geometry.width > UInt32(0) && geometry.height > UInt32(0)) {
                let passRows = passRowsValue[pass]
                let passRowIndex = UInt32(passRows.size)
                if (passRowIndex < geometry.height) {
                    let sourceY = geometry.startY + passRowIndex * geometry.stepY
                    if (rowIndex == sourceY) {
                        passRows.add(pngAdam7GatherRow(row, ihdr, geometry))
                    }
                }
            }
            pass += Int64(1)
        }
    }

    func pushFilteredFrames(output: PngIncrementalWriteOutput): Unit {
        let bytesPerPixel = pngFilterBytesPerPixel(ihdr)
        var pass: Int64 = Int64(0)
        while (pass < Int64(7)) {
            let geometry = pngAdam7PassGeometry(ihdr, pass)
            let passRows = passRowsValue[pass]
            if (geometry.width > UInt32(0) && geometry.height > UInt32(0)) {
                if (passRows.size != Int64(geometry.height)) {
                    throw PngFormatException(
                        InvalidArgument, pass,
                        "Adam7 write spool does not match planned pass geometry"
                    )
                }
                var previous = Array<Byte>(
                    Int64(geometry.rowBytes), repeat: UInt8(0)
                )
                var passRowIndex: Int64 = Int64(0)
                while (passRowIndex < passRows.size) {
                    let row = passRows[passRowIndex]
                    let selected = selectWriteFilter(
                        controls, row, previous, bytesPerPixel
                    )
                    let frame = ArrayList<Byte>()
                    frame.add(selected.filterType)
                    appendWriteBytes(frame, selected.bytes)
                    output.pushFilteredFrame(frame.toArray())
                    previous = row
                    passRowIndex += Int64(1)
                }
            } else if (passRows.size != Int64(0)) {
                throw PngFormatException(
                    InvalidArgument, pass,
                    "empty Adam7 pass contains spooled rows"
                )
            }
            pass += Int64(1)
        }
    }
}

func buildFilteredAdam7WriteRows(
    ihdr: PngIhdr,
    rows: Array<Array<Byte>>,
    controls: PngWriteControlInitialization,
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
                let passRow = pngAdam7GatherRow(
                    rows[Int64(sourceY)], ihdr, geometry
                )
                let selected = selectWriteFilter(
                    controls, passRow, previous, bytesPerPixel
                )
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
