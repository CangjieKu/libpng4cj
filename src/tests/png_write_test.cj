package libpng4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private func expectWriteFailure(action: () -> Unit, expected: PngErrorKind): Unit {
    try {
        action()
        @Fail("expected PNG write operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

@Test
public class PngWriteTestSuite {
    @TestCase
    public func roundTripsAllNonIndexedColorDepthShapes(): Unit {
        let cases = [
            (UInt8(1), Grayscale),
            (UInt8(2), Grayscale),
            (UInt8(4), Grayscale),
            (UInt8(8), Grayscale),
            (UInt8(16), Grayscale),
            (UInt8(8), Truecolor),
            (UInt8(16), Truecolor),
            (UInt8(8), GrayscaleAlpha),
            (UInt8(16), GrayscaleAlpha),
            (UInt8(8), TruecolorAlpha),
            (UInt8(16), TruecolorAlpha)
        ]
        for ((bitDepth, colorType) in cases) {
            let pixelDepth = UInt64(bitDepth) * UInt64(colorType.channels())
            let rowBytes = Int64((UInt64(3) * pixelDepth + UInt64(7)) / UInt64(8))
            let rows = [
                Array<Byte>(rowBytes, repeat: UInt8(0x15)),
                Array<Byte>(rowBytes, repeat: UInt8(0xa6))
            ]
            let encoded = encodePngPacked(UInt32(3), UInt32(2), bitDepth, colorType, rows)
            let decoded = decodePngNonInterlaced(encoded)
            @Assert(decoded.ihdr.bitDepth, bitDepth)
            @Assert(decoded.ihdr.colorType, colorType)
            @Assert(decoded.rows(), rows)
        }
    }

    @TestCase
    public func roundTripsEveryIndexedBitDepth(): Unit {
        let palette: Array<Byte> = [
            UInt8(0), UInt8(0), UInt8(0),
            UInt8(255), UInt8(255), UInt8(255)
        ]
        let cases: Array<(UInt8, Array<Array<Byte>>)> = [
            (UInt8(1), [[UInt8(0x40)], [UInt8(0xa0)]]),
            (UInt8(2), [[UInt8(0x10)], [UInt8(0x41)]]),
            (UInt8(4), [[UInt8(0x01), UInt8(0x00)], [UInt8(0x10), UInt8(0x10)]]),
            (UInt8(8), [[UInt8(0), UInt8(1), UInt8(0)], [UInt8(1), UInt8(0), UInt8(1)]])
        ]
        for ((bitDepth, rows) in cases) {
            let encoded = encodeIndexedPngPacked(
                UInt32(3), UInt32(2), bitDepth, rows, palette
            )
            let decoded = decodePngNonInterlaced(encoded)
            @Assert(decoded.ihdr.bitDepth, bitDepth)
            @Assert(decoded.rows(), rows)
            @Assert(decoded.metadata.palette(), palette)
        }
    }

    @TestCase
    public func writesIndexedPaletteAndSplitIdatChunks(): Unit {
        let rows: Array<Array<Byte>> = [[UInt8(0x1b)], [UInt8(0xe4)]]
        let palette: Array<Byte> = [
            UInt8(0), UInt8(0), UInt8(0),
            UInt8(255), UInt8(0), UInt8(0),
            UInt8(0), UInt8(255), UInt8(0),
            UInt8(0), UInt8(0), UInt8(255)
        ]
        let encoded = encodePngPacked(
            UInt32(4), UInt32(2), UInt8(2), Indexed, rows, palette,
            WriteFilterAdaptive, Int32(6),
            PngWriteLimits(UInt64(4096), UInt64(4096), UInt32(2))
        )
        let decoded = decodePngNonInterlaced(encoded)
        @Assert(decoded.rows(), rows)
        @Assert(decoded.metadata.palette(), palette)
    }

    @TestCase
    public func writesSuggestedPaletteForTruecolorAndRejectsGrayPalette(): Unit {
        let palette: Array<Byte> = [
            UInt8(255), UInt8(0), UInt8(0),
            UInt8(0), UInt8(255), UInt8(0)
        ]
        let encoded = encodePngPacked(
            UInt32(1), UInt32(1), UInt8(8), Truecolor,
            [[UInt8(9), UInt8(8), UInt8(7)]], palette,
            WriteFilterNone, Int32(6), PngWriteLimits()
        )
        let decoded = decodePngNonInterlaced(encoded)
        @Assert(decoded.rows(), [[UInt8(9), UInt8(8), UInt8(7)]])
        @Assert(decoded.metadata.palette(), palette)

        expectWriteFailure({ =>
            encodePngPacked(
                UInt32(1), UInt32(1), UInt8(8), Grayscale, [[UInt8(0)]],
                palette, WriteFilterNone, Int32(6), PngWriteLimits()
            ); ()
        }, InvalidPalette)
    }

    @TestCase
    public func emitsExactCoreChunkOrderLengthsAndCrcs(): Unit {
        let rows: Array<Array<Byte>> = [[UInt8(0x1b)], [UInt8(0xe4)]]
        let palette: Array<Byte> = [
            UInt8(0), UInt8(0), UInt8(0),
            UInt8(255), UInt8(0), UInt8(0),
            UInt8(0), UInt8(255), UInt8(0),
            UInt8(0), UInt8(0), UInt8(255)
        ]
        let encoded = encodePngPacked(
            UInt32(4), UInt32(2), UInt8(2), Indexed, rows, palette,
            WriteFilterAdaptive, Int32(6),
            PngWriteLimits(UInt64(4096), UInt64(4096), UInt32(2))
        )
        let reader = PngReadSession(encoded)
        let ihdr = reader.readNextChunk()
        @Assert(ihdr.isType(PNG_CHUNK_IHDR), true)
        @Assert(ihdr.length, UInt32(13))
        @Assert(ihdr.crcValid, true)

        let plte = reader.readNextChunk()
        @Assert(plte.isType(PNG_CHUNK_PLTE), true)
        @Assert(plte.length, UInt32(palette.size))
        @Assert(plte.crcValid, true)

        var idatCount: Int64 = Int64(0)
        var reachedEnd: Bool = false
        while (!reachedEnd) {
            let chunk = reader.readNextChunk()
            @Assert(chunk.crcValid, true)
            if (chunk.isType(PNG_CHUNK_IDAT)) {
                @Assert(chunk.length > UInt32(0), true)
                @Assert(chunk.length <= UInt32(2), true)
                idatCount += Int64(1)
            } else {
                @Assert(chunk.isType(PNG_CHUNK_IEND), true)
                @Assert(chunk.length, UInt32(0))
                reachedEnd = true
            }
        }
        @Assert(idatCount > Int64(1), true)
        @Assert(reader.remaining(), Int64(0))
    }

    @TestCase
    public func fixedFiltersRoundTripAndAdaptiveIsDeterministic(): Unit {
        let rows: Array<Array<Byte>> = [
            [UInt8(1), UInt8(2), UInt8(3), UInt8(4), UInt8(5), UInt8(6)],
            [UInt8(1), UInt8(2), UInt8(4), UInt8(4), UInt8(7), UInt8(6)]
        ]
        let strategies = [
            WriteFilterNone, WriteFilterSub, WriteFilterUp,
            WriteFilterAverage, WriteFilterPaeth, WriteFilterAdaptive
        ]
        for (strategy in strategies) {
            let encoded = encodePngPacked(
                UInt32(2), UInt32(2), UInt8(8), Truecolor, rows,
                Array<Byte>(), strategy, Int32(6), PngWriteLimits()
            )
            @Assert(decodePngNonInterlaced(encoded).rows(), rows)
            if (strategy == WriteFilterAdaptive) {
                @Assert(
                    encoded,
                    encodePngPacked(
                        UInt32(2), UInt32(2), UInt8(8), Truecolor, rows,
                        Array<Byte>(), strategy, Int32(6), PngWriteLimits()
                    )
                )
            }
        }
    }

    @TestCase
    public func enforcesRowsPaletteLimitsAndLifecycle(): Unit {
        let writer = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale,
            Array<Byte>(), WriteFilterNone, Int32(6), PngWriteLimits()
        )
        let encoded = writer.write([[UInt8(9)]])
        @Assert(writer.state(), WriteCompleted)
        @Assert(decodePngNonInterlaced(encoded).rows(), [[UInt8(9)]])
        expectWriteFailure({ => writer.write([[UInt8(9)]]); () }, InvalidArgument)
        writer.close()
        @Assert(writer.state(), WriteClosed)
        expectWriteFailure({ => writer.write([[UInt8(9)]]); () }, SessionClosed)

        expectWriteFailure({ =>
            encodePngPacked(UInt32(1), UInt32(2), UInt8(8), Grayscale, [[UInt8(0)]]); ()
        }, InvalidArgument)
        expectWriteFailure({ =>
            encodeIndexedPngPacked(UInt32(1), UInt32(1), UInt8(1), [[UInt8(0)]], [UInt8(0)]); ()
        }, InvalidPalette)
        expectWriteFailure({ =>
            encodeIndexedPngPacked(
                UInt32(1), UInt32(1), UInt8(1), [[UInt8(0x80)]],
                [UInt8(0), UInt8(0), UInt8(0)]
            ); ()
        }, PaletteIndexOutOfRange)
        expectWriteFailure({ =>
            encodePngPacked(
                UInt32(1), UInt32(1), UInt8(8), Grayscale, [[UInt8(0)]],
                Array<Byte>(), WriteFilterNone, Int32(6),
                PngWriteLimits(UInt64(16), UInt64(16), UInt32(4))
            ); ()
        }, DecodeLimitExceeded)
    }

    @TestCase
    public func recordsFailedStateForMalformedRowsCompressionAndLimits(): Unit {
        let malformed = PngWriteSession(
            UInt32(2), UInt32(1), UInt8(8), Grayscale,
            Array<Byte>(), WriteFilterNone, Int32(6), PngWriteLimits()
        )
        expectWriteFailure({ => malformed.write([[UInt8(1)]]); () }, InvalidArgument)
        @Assert(malformed.state(), WriteFailed)
        expectWriteFailure({ => malformed.write([[UInt8(1), UInt8(2)]]); () }, InvalidArgument)

        let invalidLevel = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale,
            Array<Byte>(), WriteFilterNone, Int32(10), PngWriteLimits()
        )
        expectWriteFailure({ => invalidLevel.write([[UInt8(1)]]); () }, InvalidArgument)
        @Assert(invalidLevel.state(), WriteFailed)

        let filteredLimit = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale,
            Array<Byte>(), WriteFilterNone, Int32(6),
            PngWriteLimits(UInt64(1), UInt64(4096), UInt64(4096), UInt32(4))
        )
        expectWriteFailure({ => filteredLimit.write([[UInt8(1)]]); () }, DecodeLimitExceeded)
        @Assert(filteredLimit.state(), WriteFailed)

        let compressedLimit = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale,
            Array<Byte>(), WriteFilterNone, Int32(6),
            PngWriteLimits(UInt64(4096), UInt64(1), UInt64(4096), UInt32(4))
        )
        expectWriteFailure({ => compressedLimit.write([[UInt8(1)]]); () }, DecodeLimitExceeded)
        @Assert(compressedLimit.state(), WriteFailed)

        let outputLimit = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale,
            Array<Byte>(), WriteFilterNone, Int32(6),
            PngWriteLimits(UInt64(4096), UInt64(4096), UInt64(45), UInt32(4))
        )
        expectWriteFailure({ => outputLimit.write([[UInt8(1)]]); () }, DecodeLimitExceeded)
        @Assert(outputLimit.state(), WriteFailed)
    }

    @TestCase
    public func preservesCallerRowsPaletteAndEncodedOutputOwnership(): Unit {
        let rows: Array<Array<Byte>> = [[UInt8(0x40)]]
        let expectedRows: Array<Array<Byte>> = [[UInt8(0x40)]]
        let palette: Array<Byte> = [
            UInt8(1), UInt8(2), UInt8(3),
            UInt8(4), UInt8(5), UInt8(6)
        ]
        let expectedPalette = palette.clone()
        let writer = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(1), Indexed, palette,
            WriteFilterSub, Int32(6), PngWriteLimits()
        )
        palette[0] = UInt8(99)
        let encoded = writer.write(rows)
        @Assert(rows, expectedRows)
        rows[0][0] = UInt8(0)
        palette[1] = UInt8(88)

        let decoded = decodePngNonInterlaced(encoded)
        @Assert(decoded.rows(), expectedRows)
        @Assert(decoded.metadata.palette(), expectedPalette)
    }
}
