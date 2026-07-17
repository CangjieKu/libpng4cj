package libpng4cj.tests

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private func appendAdam7TestBytes(target: ArrayList<Byte>, bytes: Array<Byte>): Unit {
    var index: Int64 = Int64(0)
    while (index < bytes.size) {
        target.add(bytes[index])
        index += Int64(1)
    }
}

private func adam7IdatPayload(encoded: Array<Byte>): Array<Byte> {
    let reader = PngReadSession(encoded)
    let compressed = ArrayList<Byte>()
    var done: Bool = false
    while (!done) {
        let chunk = reader.readNextChunk()
        if (chunk.isType(PNG_CHUNK_IDAT)) {
            appendAdam7TestBytes(compressed, chunk.payload())
        } else if (chunk.isType(PNG_CHUNK_IEND)) {
            done = true
        }
    }
    compressed.toArray()
}

private func adam7IdatCount(encoded: Array<Byte>): Int64 {
    let reader = PngReadSession(encoded)
    var count: Int64 = Int64(0)
    var done: Bool = false
    while (!done) {
        let chunk = reader.readNextChunk()
        if (chunk.isType(PNG_CHUNK_IDAT)) {
            count += Int64(1)
        } else if (chunk.isType(PNG_CHUNK_IEND)) {
            done = true
        }
    }
    count
}

private func makeByteRows(width: UInt32, height: UInt32, pixelBytes: Int64): Array<Array<Byte>> {
    let rows = Array<Array<Byte>>(Int64(height), repeat: Array<Byte>())
    var y: UInt32 = UInt32(0)
    while (y < height) {
        let row = Array<Byte>(Int64(width) * pixelBytes, repeat: UInt8(0))
        var x: UInt32 = UInt32(0)
        while (x < width) {
            var byteIndex: Int64 = Int64(0)
            while (byteIndex < pixelBytes) {
                row[Int64(x) * pixelBytes + byteIndex] = UInt8(
                    (UInt32(y) * UInt32(31) + UInt32(x) * UInt32(7) + UInt32(byteIndex)) % UInt32(251)
                )
                byteIndex += Int64(1)
            }
            x += UInt32(1)
        }
        rows[Int64(y)] = row
        y += UInt32(1)
    }
    rows
}

private func cloneAdam7Rows(rows: Array<Array<Byte>>): Array<Array<Byte>> {
    let cloned = Array<Array<Byte>>(rows.size, repeat: Array<Byte>())
    var index: Int64 = Int64(0)
    while (index < rows.size) {
        cloned[index] = rows[index].clone()
        index += Int64(1)
    }
    cloned
}

private func makePackedRows(width: UInt32, height: UInt32, bitDepth: UInt8): Array<Array<Byte>> {
    let rowBytes = Int64((UInt64(width) * UInt64(bitDepth) + UInt64(7)) / UInt64(8))
    let rows = Array<Array<Byte>>(Int64(height), repeat: Array<Byte>())
    let sampleMask = (UInt32(1) << UInt32(bitDepth)) - UInt32(1)
    var y: UInt32 = UInt32(0)
    while (y < height) {
        let row = Array<Byte>(rowBytes, repeat: UInt8(0))
        var x: UInt32 = UInt32(0)
        while (x < width) {
            let sample = (x * UInt32(3) + y * UInt32(5)) & sampleMask
            let bitOffset = UInt64(x) * UInt64(bitDepth)
            let byteOffset = Int64(bitOffset / UInt64(8))
            let shift = UInt32(8) - UInt32(bitDepth) - UInt32(bitOffset % UInt64(8))
            row[byteOffset] = UInt8(UInt32(row[byteOffset]) | (sample << shift))
            x += UInt32(1)
        }
        rows[Int64(y)] = row
        y += UInt32(1)
    }
    rows
}

private func makePackedPalette(bitDepth: UInt8): Array<Byte> {
    let palette = ArrayList<Byte>()
    let entryCount = UInt32(1) << UInt32(bitDepth)
    var entry: UInt32 = UInt32(0)
    while (entry < entryCount) {
        let value = UInt8((entry * UInt32(255)) / (entryCount - UInt32(1)))
        palette.add(value)
        palette.add(value)
        palette.add(value)
        entry += UInt32(1)
    }
    palette.toArray()
}

@Test
public class PngWriteAdam7TestSuite {
    @TestCase
    public func roundTripsPackedIndexedAndGrayscaleRows(): Unit {
        let depths: Array<UInt8> = [UInt8(1), UInt8(2), UInt8(4)]
        for (bitDepth in depths) {
            let rows = makePackedRows(UInt32(13), UInt32(9), bitDepth)
            let grayscale = encodePngPackedAdam7(
                UInt32(13), UInt32(9), bitDepth, Grayscale, rows
            )
            let grayscaleDecoded = decodePng(grayscale)
            @Assert(grayscaleDecoded.ihdr.interlaceMethod, Adam7)
            @Assert(grayscaleDecoded.rows(), rows)

            let palette = makePackedPalette(bitDepth)
            let indexed = encodeIndexedPngPackedAdam7(
                UInt32(13), UInt32(9), bitDepth, rows, palette
            )
            let indexedDecoded = decodePng(indexed)
            @Assert(indexedDecoded.ihdr.interlaceMethod, Adam7)
            @Assert(indexedDecoded.rows(), rows)
            @Assert(indexedDecoded.metadata.palette(), palette)
        }
    }

    @TestCase
    public func roundTripsEightAndSixteenBitMultiChannelRows(): Unit {
        let rgba8 = makeByteRows(UInt32(9), UInt32(9), Int64(4))
        let encoded8 = encodePngPackedAdam7(
            UInt32(9), UInt32(9), UInt8(8), TruecolorAlpha, rgba8
        )
        @Assert(decodePng(encoded8).rows(), rgba8)

        let rgb16 = makeByteRows(UInt32(9), UInt32(9), Int64(6))
        let encoded16 = encodePngPackedAdam7(
            UInt32(9), UInt32(9), UInt8(16), Truecolor, rgb16
        )
        @Assert(decodePng(encoded16).rows(), rgb16)
    }

    @TestCase
    public func handlesNarrowGeometryAndResetsUpFilterPerPass(): Unit {
        let rows: Array<Array<Byte>> = [
            [UInt8(10), UInt8(20)], [UInt8(30), UInt8(40)],
            [UInt8(50), UInt8(60)]
        ]
        let encoded = encodePngPackedAdam7(
            UInt32(2), UInt32(3), UInt8(8), Grayscale, rows, Array<Byte>(),
            PngWriteMetadata(), WriteFilterUp, Int32(6),
            PngWriteLimits(UInt64(4096), UInt64(4096), UInt32(2))
        )
        let decoded = decodePng(encoded)
        @Assert(decoded.ihdr.interlaceMethod, Adam7)
        @Assert(decoded.rows(), rows)

        let ihdr = decoded.ihdr
        var expectedInflated: UInt64 = UInt64(0)
        var nonEmptyPasses: Int64 = Int64(0)
        var pass: Int64 = Int64(0)
        while (pass < Int64(7)) {
            let geometry = pngAdam7PassGeometry(ihdr, pass)
            if (geometry.width > UInt32(0) && geometry.height > UInt32(0)) {
                expectedInflated += (geometry.rowBytes + UInt64(1)) * UInt64(geometry.height)
                nonEmptyPasses += Int64(1)
            }
            pass += Int64(1)
        }
        let inflated = inflatePngZlibExact(adam7IdatPayload(encoded), Int64(expectedInflated))
        var offset: Int64 = Int64(0)
        pass = Int64(0)
        var observedPasses: Int64 = Int64(0)
        while (pass < Int64(7)) {
            let geometry = pngAdam7PassGeometry(ihdr, pass)
            if (geometry.width > UInt32(0) && geometry.height > UInt32(0)) {
                @Assert(inflated[offset], PNG_FILTER_UP)
                var pixel: UInt32 = UInt32(0)
                while (pixel < geometry.width) {
                    let sourceX = geometry.startX + pixel * geometry.stepX
                    @Assert(
                        inflated[offset + Int64(1) + Int64(pixel)],
                        rows[Int64(geometry.startY)][Int64(sourceX)]
                    )
                    pixel += UInt32(1)
                }
                offset += Int64(geometry.rowBytes + UInt64(1)) * Int64(geometry.height)
                observedPasses += Int64(1)
            }
            pass += Int64(1)
        }
        @Assert(observedPasses, nonEmptyPasses)
        @Assert(offset, inflated.size)
    }

    @TestCase
    public func preservesMetadataSplitIdatOwnershipAndLimits(): Unit {
        let rows = makeByteRows(UInt32(9), UInt32(9), Int64(3))
        let expectedRows = cloneAdam7Rows(rows)
        let metadata = PngWriteMetadata()
        metadata.setGamma(UInt32(45455))
        let encoded = encodePngPackedAdam7(
            UInt32(9), UInt32(9), UInt8(8), Truecolor, rows, Array<Byte>(),
            metadata, WriteFilterAdaptive, Int32(6),
            PngWriteLimits(UInt64(4096), UInt64(4096), UInt32(2))
        )
        rows[0][0] = UInt8(255)
        let decoded = decodePng(encoded)
        @Assert(decoded.rows(), expectedRows)
        @Assert(decoded.metadata.gamma, UInt32(45455))
        @Assert(adam7IdatCount(encoded) > Int64(1), true)

        try {
            encodePngPackedAdam7(
                UInt32(9), UInt32(9), UInt8(8), Truecolor, expectedRows,
                Array<Byte>(), PngWriteMetadata(), WriteFilterNone, Int32(6),
                PngWriteLimits(UInt64(8), UInt64(4096), UInt64(4096), UInt32(4))
            )
            @Fail("Adam7 filtered limit should fail")
        } catch (error: PngFormatException) {
            @Assert(error.kind, DecodeLimitExceeded)
        }
    }
}
