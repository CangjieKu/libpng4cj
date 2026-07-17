package libpng4cj.tests

import std.fs.*
import libpng4cj.*

private func adam7Join(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: UInt8(0))
    var index: Int64 = 0
    while (index < left.size) {
        out[index] = left[index]
        index += 1
    }
    index = 0
    while (index < right.size) {
        out[left.size + index] = right[index]
        index += 1
    }
    out
}

private func adam7Chunk(chunkType: Array<Byte>, data: Array<Byte>): Array<Byte> {
    adam7Join(
        adam7Join(adam7Join(writeUInt32Be(UInt32(data.size)), chunkType), data),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func adam7Ihdr(width: UInt32, height: UInt32, bitDepth: UInt8): PngIhdr {
    let data = Array<Byte>(13, repeat: UInt8(0))
    let widthBytes = writeUInt32Be(width)
    let heightBytes = writeUInt32Be(height)
    var index: Int64 = 0
    while (index < Int64(4)) {
        data[index] = widthBytes[index]
        data[index + 4] = heightBytes[index]
        index += 1
    }
    data[8] = bitDepth
    data[9] = UInt8(0)
    data[12] = UInt8(1)
    readPngIhdr(adam7Join(PNG_SIGNATURE, adam7Chunk(PNG_CHUNK_IHDR, data)))
}

private func adam7Fixture(name: String): Array<Byte> {
    File.readFrom("test/fixtures/pngsuite/${name}")
}

private func assertRgba8RowsEqual(left: PngRgba8Rows, right: PngRgba8Rows): Unit {
    @Assert(left.rowCount(), right.rowCount())
    var index: Int64 = 0
    while (index < left.rowCount()) {
        @Assert(left.row(index), right.row(index))
        index += 1
    }
}

private func assertRgba16RowsEqual(left: PngRgba16Rows, right: PngRgba16Rows): Unit {
    @Assert(left.rowCount(), right.rowCount())
    var index: Int64 = 0
    while (index < left.rowCount()) {
        @Assert(left.row(index), right.row(index))
        index += 1
    }
}

private func expectAdam7Error(bytes: Array<Byte>, expected: PngErrorKind): Unit {
    try {
        decodePng(bytes)
        @Fail("expected Adam7 decode to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind.toString(), expected.toString())
    }
}

@Test
public class PngAdam7TestSuite {
    @TestCase
    public func exposesExactSevenPassGeometryAndEmptyPasses(): Unit {
        let narrow = adam7Ihdr(UInt32(1), UInt32(1), UInt8(1))
        let first = pngAdam7PassGeometry(narrow, Int64(0))
        @Assert(first.width, UInt32(1))
        @Assert(first.height, UInt32(1))
        @Assert(first.rowBytes, UInt64(1))
        @Assert(pngAdam7PassGeometry(narrow, Int64(1)).width, UInt32(0))
        @Assert(pngAdam7PassGeometry(narrow, Int64(2)).height, UInt32(0))
        @Assert(pngAdam7ExpectedInflatedSize(narrow, PngReadLimits()), Int64(2))

        let ordinary = adam7Ihdr(UInt32(13), UInt32(9), UInt8(1))
        let expectedWidths: Array<UInt32> = [2, 2, 4, 3, 7, 6, 13]
        let expectedHeights: Array<UInt32> = [2, 2, 1, 3, 2, 5, 4]
        var pass: Int64 = 0
        while (pass < Int64(7)) {
            let geometry = pngAdam7PassGeometry(ordinary, pass)
            @Assert(geometry.width, expectedWidths[pass])
            @Assert(geometry.height, expectedHeights[pass])
            pass += 1
        }
    }

    @TestCase
    public func reconstructsPackedGrayAndIndexedPngsuiteRows(): Unit {
        assertRgba8RowsEqual(
            decodePngRgba8(adam7Fixture("ibasn0g01.png")),
            decodePngRgba8NonInterlaced(adam7Fixture("basn0g01.png"))
        )
        assertRgba8RowsEqual(
            decodePngRgba8(adam7Fixture("ibasn0g02.png")),
            decodePngRgba8NonInterlaced(adam7Fixture("basn0g02.png"))
        )
        let indexed = decodePngRgba8(adam7Fixture("ibasn3p04.png"))
        let indexedBase = decodePngRgba8NonInterlaced(adam7Fixture("basn3p04.png"))
        assertRgba8RowsEqual(indexed, indexedBase)
        @Assert(indexed.metadata.palette().size > Int64(0), true)
        let mutablePalette = indexed.metadata.palette()
        mutablePalette[0] = UInt8(0)
        @Assert(indexed.metadata.palette()[0] != UInt8(0), true)
    }

    @TestCase
    public func reconstructsEightAndSixteenBitChannelRows(): Unit {
        assertRgba8RowsEqual(
            decodePngRgba8(adam7Fixture("ibasn2c08.png")),
            decodePngRgba8NonInterlaced(adam7Fixture("basn2c08.png"))
        )
        assertRgba8RowsEqual(
            decodePngRgba8(adam7Fixture("ibasn6a08.png")),
            decodePngRgba8NonInterlaced(adam7Fixture("basn6a08.png"))
        )
        assertRgba16RowsEqual(
            decodePngRgba16(adam7Fixture("ibasn4a16.png")),
            decodePngRgba16NonInterlaced(adam7Fixture("basn4a16.png"))
        )
        assertRgba16RowsEqual(
            decodePngRgba16(adam7Fixture("ibasn6a16.png")),
            decodePngRgba16NonInterlaced(adam7Fixture("basn6a16.png"))
        )
    }

    @TestCase
    public func preservesGenericAndLegacyEntryPointBoundaries(): Unit {
        let interlaced = adam7Fixture("ibasn6a08.png")
        let decoded = decodePng(interlaced)
        @Assert(decoded.ihdr.interlaceMethod, Adam7)
        @Assert(decoded.rowCount(), Int64(32))

        try {
            decodePngNonInterlaced(interlaced)
            @Fail("legacy non-interlaced entry should reject Adam7")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), UnsupportedInterlace.toString())
        }

        let plain = adam7Fixture("basn6a08.png")
        @Assert(decodePng(plain).rows(), decodePngNonInterlaced(plain).rows())
    }

    @TestCase
    public func enforcesAdam7InflatedLimitsAndMalformedInputPriority(): Unit {
        let interlaced = adam7Fixture("ibasn6a08.png")
        let limits = PngReadLimits(
            UInt32(8_000_000),
            UInt32(100),
            UInt32(100),
            UInt64(1_000_000),
            UInt64(1)
        )
        try {
            decodePng(interlaced, limits)
            @Fail("Adam7 inflated-byte limit should fail")
        } catch (error: PngFormatException) {
            @Assert(error.kind.toString(), DecodeLimitExceeded.toString())
        }

        expectAdam7Error(
            copyByteRange(interlaced, Int64(0), interlaced.size - Int64(1)),
            TruncatedInput
        )
    }
}
