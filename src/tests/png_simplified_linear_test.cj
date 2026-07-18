package libpng4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private let PNG_LINEAR_FORMATS: Array<PngLinearImageFormat> = [
    LinearGray,
    LinearGrayAlpha,
    LinearAlphaGray,
    LinearRgb,
    LinearBgr,
    LinearRgba,
    LinearArgb,
    LinearBgra,
    LinearAbgr
]

private func linearSource(): Array<Byte> {
    let metadata = PngWriteMetadata()
    metadata.setGamma(UInt32(45455))
    encodePngPacked(
        UInt32(2),
        UInt32(1),
        UInt8(8),
        TruecolorAlpha,
        [[
            UInt8(255), UInt8(0), UInt8(0), UInt8(128),
            UInt8(0), UInt8(255), UInt8(0), UInt8(255)
        ]],
        Array<Byte>(),
        metadata,
        WriteFilterAdaptive,
        Int32(6),
        PngWriteLimits()
    )
}

private func linearAlphaEndpointSource(): Array<Byte> {
    let metadata = PngWriteMetadata()
    metadata.setGamma(UInt32(100000))
    encodePngPacked(
        UInt32(3),
        UInt32(1),
        UInt8(16),
        TruecolorAlpha,
        [[
            UInt8(0xff), UInt8(0xff), UInt8(0), UInt8(0),
            UInt8(0), UInt8(0), UInt8(0), UInt8(0),
            UInt8(0xff), UInt8(0xff), UInt8(0), UInt8(0),
            UInt8(0), UInt8(0), UInt8(0x80), UInt8(0),
            UInt8(0xff), UInt8(0xff), UInt8(0), UInt8(0),
            UInt8(0), UInt8(0), UInt8(0xff), UInt8(0xff)
        ]],
        Array<Byte>(),
        metadata,
        WriteFilterAdaptive,
        Int32(6),
        PngWriteLimits()
    )
}

private func expectLinearFailure(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected simplified linear image operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

@Test
public class PngSimplifiedLinearImageTestSuite {
    @TestCase
    public func readsAndWritesEveryLinearLayout(): Unit {
        let encoded = linearSource()
        for (format in PNG_LINEAR_FORMATS) {
            let image = beginPngImageReadFromMemory(encoded)
            let buffer = image.finishReadLinear(format)
            @Assert(image.state(), PngImageFinished)
            @Assert(buffer.width, UInt32(2))
            @Assert(buffer.height, UInt32(1))
            @Assert(buffer.channels, format.channelCount())
            @Assert(buffer.rowStride, Int64(2) * Int64(format.channelCount()))
            @Assert(buffer.byteCount(), buffer.componentCount() * Int64(2))
            @Assert(buffer.associatedAlpha, false)

            let rewritten = writePngLinearImageToMemory(buffer)
            let decoded = decodePng(rewritten)
            @Assert(decoded.ihdr.bitDepth, UInt8(16))
            @Assert(decoded.metadata.hasGamma, true)
            @Assert(decoded.metadata.gamma, UInt32(100000))
            @Assert(
                beginPngImageReadFromMemory(rewritten)
                    .finishReadLinear(format).components(),
                buffer.components()
            )
        }
    }

    @TestCase
    public func preservesAbsoluteChannelOrderAcrossEveryLayout(): Unit {
        let encoded = linearSource()
        @Assert(
            beginPngImageReadFromMemory(encoded)
                .finishReadLinear(LinearGray).components(),
            [UInt16(6995), UInt16(46867)]
        )
        @Assert(
            beginPngImageReadFromMemory(encoded)
                .finishReadLinear(LinearGrayAlpha).components(),
            [UInt16(13936), UInt16(32896), UInt16(46867), UInt16(65535)]
        )
        @Assert(
            beginPngImageReadFromMemory(encoded)
                .finishReadLinear(LinearAlphaGray).components(),
            [UInt16(32896), UInt16(13936), UInt16(65535), UInt16(46867)]
        )
        @Assert(
            beginPngImageReadFromMemory(encoded)
                .finishReadLinear(LinearRgb).components(),
            [
                UInt16(32896), UInt16(0), UInt16(0),
                UInt16(0), UInt16(65535), UInt16(0)
            ]
        )
        @Assert(
            beginPngImageReadFromMemory(encoded)
                .finishReadLinear(LinearBgr).components(),
            [
                UInt16(0), UInt16(0), UInt16(32896),
                UInt16(0), UInt16(65535), UInt16(0)
            ]
        )
        @Assert(
            beginPngImageReadFromMemory(encoded)
                .finishReadLinear(LinearRgba).components(),
            [
                UInt16(65535), UInt16(0), UInt16(0), UInt16(32896),
                UInt16(0), UInt16(65535), UInt16(0), UInt16(65535)
            ]
        )
        @Assert(
            beginPngImageReadFromMemory(encoded)
                .finishReadLinear(LinearArgb).components(),
            [
                UInt16(32896), UInt16(65535), UInt16(0), UInt16(0),
                UInt16(65535), UInt16(0), UInt16(65535), UInt16(0)
            ]
        )
        @Assert(
            beginPngImageReadFromMemory(encoded)
                .finishReadLinear(LinearBgra).components(),
            [
                UInt16(0), UInt16(0), UInt16(65535), UInt16(32896),
                UInt16(0), UInt16(65535), UInt16(0), UInt16(65535)
            ]
        )
        @Assert(
            beginPngImageReadFromMemory(encoded)
                .finishReadLinear(LinearAbgr).components(),
            [
                UInt16(32896), UInt16(0), UInt16(0), UInt16(65535),
                UInt16(65535), UInt16(0), UInt16(65535), UInt16(0)
            ]
        )
    }

    @TestCase
    public func convertsSrgbToLinearAndAssociatesAlpha(): Unit {
        let straight = beginPngImageReadFromMemory(
            linearSource()
        ).finishReadLinear(LinearRgba)
        let associated = beginPngImageReadFromMemory(
            linearSource()
        ).finishReadLinear(LinearRgba, true)
        let straightValues = straight.components()
        let associatedValues = associated.components()
        @Assert(straightValues[0], UInt16(65535))
        @Assert(straightValues[1], UInt16(0))
        @Assert(straightValues[3], UInt16(32896))
        @Assert(associated.associatedAlpha, true)
        @Assert(associatedValues[0], UInt16(32896))
        @Assert(associatedValues[1], UInt16(0))
        @Assert(associatedValues[3], UInt16(32896))

        let black = beginPngImageReadFromMemory(
            linearSource()
        ).finishReadLinear(LinearRgb)
        @Assert(black.components()[0], UInt16(32896))
    }

    @TestCase
    public func usesExactSrgbTransferAtRepresentativeSamples(): Unit {
        let metadata = PngWriteMetadata()
        metadata.setSrgb(Perceptual)
        let encoded = encodePngPacked(
            UInt32(8), UInt32(1), UInt8(8), Grayscale,
            [[
                UInt8(0), UInt8(1), UInt8(12), UInt8(13),
                UInt8(128), UInt8(188), UInt8(254), UInt8(255)
            ]],
            Array<Byte>(), metadata, WriteFilterAdaptive, Int32(6),
            PngWriteLimits()
        )
        @Assert(
            beginPngImageReadFromMemory(encoded)
                .finishReadLinear(LinearGray).components(),
            [
                UInt16(0), UInt16(20), UInt16(241), UInt16(264),
                UInt16(14146), UInt16(32957), UInt16(64952), UInt16(65535)
            ]
        )

        let rgbaMetadata = PngWriteMetadata()
        rgbaMetadata.setSrgb(Perceptual)
        let rgba = encodePngPacked(
            UInt32(1), UInt32(1), UInt8(8), TruecolorAlpha,
            [[UInt8(188), UInt8(0), UInt8(0), UInt8(128)]],
            Array<Byte>(), rgbaMetadata, WriteFilterAdaptive, Int32(6),
            PngWriteLimits()
        )
        @Assert(
            beginPngImageReadFromMemory(rgba)
                .finishReadLinear(LinearRgba).components(),
            [UInt16(32957), UInt16(0), UInt16(0), UInt16(32896)]
        )
        @Assert(
            beginPngImageReadFromMemory(rgba)
                .finishReadLinear(LinearRgba, true).components(),
            [UInt16(16543), UInt16(0), UInt16(0), UInt16(32896)]
        )

        let linear = PngLinearImageBuffer(
            UInt32(8), UInt32(1), LinearGray,
            [
                UInt16(0), UInt16(20), UInt16(241), UInt16(264),
                UInt16(14146), UInt16(32768), UInt16(64952), UInt16(65535)
            ],
            false
        )
        @Assert(
            beginPngImageReadFromMemory(
                writePngLinearImageToMemory(linear, true)
            ).finishRead(ImageGray8).bytes(),
            [
                UInt8(0), UInt8(1), UInt8(12), UInt8(13),
                UInt8(128), UInt8(188), UInt8(254), UInt8(255)
            ]
        )
    }

    @TestCase
    public func preservesStraightAndAssociatedAlphaEndpoints(): Unit {
        let encoded = linearAlphaEndpointSource()
        let straight = beginPngImageReadFromMemory(
            encoded
        ).finishReadLinear(LinearRgba)
        @Assert(
            straight.components(),
            [
                UInt16(65535), UInt16(0), UInt16(0), UInt16(0),
                UInt16(65535), UInt16(0), UInt16(0), UInt16(32768),
                UInt16(65535), UInt16(0), UInt16(0), UInt16(65535)
            ]
        )

        let associated = beginPngImageReadFromMemory(
            encoded
        ).finishReadLinear(LinearRgba, true)
        @Assert(
            associated.components(),
            [
                UInt16(0), UInt16(0), UInt16(0), UInt16(0),
                UInt16(32768), UInt16(0), UInt16(0), UInt16(32768),
                UInt16(65535), UInt16(0), UInt16(0), UInt16(65535)
            ]
        )
        let roundTrip = beginPngImageReadFromMemory(
            writePngLinearImageToMemory(associated)
        ).finishReadLinear(LinearRgba, true)
        @Assert(roundTrip.components(), associated.components())
    }

    @TestCase
    public func acceptsPackedTransparencySixteenBitAndAdam7(): Unit {
        let metadata = PngWriteMetadata()
        metadata.setTransparency(PngWriteTransparency(UInt16(1)))
        let packed = encodePngPacked(
            UInt32(2), UInt32(1), UInt8(1), Grayscale,
            [[UInt8(0x40)]], Array<Byte>(), metadata,
            WriteFilterAdaptive, Int32(6), PngWriteLimits()
        )
        let packedLinear = beginPngImageReadFromMemory(
            packed
        ).finishReadLinear(LinearGrayAlpha)
        @Assert(packedLinear.components()[1], UInt16(65535))
        @Assert(packedLinear.components()[3], UInt16(0))

        let sixteenMetadata = PngWriteMetadata()
        sixteenMetadata.setGamma(UInt32(100000))
        let sixteen = encodePngPackedAdam7(
            UInt32(1), UInt32(1), UInt8(16), TruecolorAlpha,
            [[
                UInt8(0x12), UInt8(0x34),
                UInt8(0x56), UInt8(0x78),
                UInt8(0x9a), UInt8(0xbc),
                UInt8(0xff), UInt8(0xff)
            ]],
            Array<Byte>(),
            sixteenMetadata,
            WriteFilterAdaptive,
            Int32(6),
            PngWriteLimits()
        )
        @Assert(
            beginPngImageReadFromMemory(sixteen)
                .finishReadLinear(LinearRgba).components(),
            [UInt16(0x1234), UInt16(0x5678), UInt16(0x9abc), UInt16(0xffff)]
        )
    }

    @TestCase
    public func writesAssociatedAlphaAndConvertedSrgbEightBit(): Unit {
        let associated = PngLinearImageBuffer(
            UInt32(1), UInt32(1), LinearRgba,
            [UInt16(32768), UInt16(0), UInt16(0), UInt16(32768)],
            true
        )
        let linearPng = writePngLinearImageToMemory(associated, false, Adam7)
        let linearRoundTrip = beginPngImageReadFromMemory(
            linearPng
        ).finishReadLinear(LinearRgba, true)
        @Assert(linearRoundTrip.components(), associated.components())
        @Assert(decodePng(linearPng).ihdr.interlaceMethod, Adam7)

        let srgbPng = writePngLinearImageToMemory(associated, true)
        let srgbDecoded = decodePng(srgbPng)
        @Assert(srgbDecoded.ihdr.bitDepth, UInt8(8))
        @Assert(srgbDecoded.metadata.hasSrgb, true)
        let srgb = beginPngImageReadFromMemory(srgbPng).finishRead(ImageRgba8)
        @Assert(srgb.bytes(), [UInt8(255), UInt8(0), UInt8(0), UInt8(128)])

        let midpoint = PngLinearImageBuffer(
            UInt32(1), UInt32(1), LinearRgb,
            [UInt16(32768), UInt16(0), UInt16(0)], false
        )
        let midpointSrgb = beginPngImageReadFromMemory(
            writePngLinearImageToMemory(midpoint, true)
        ).finishRead(ImageRgb8)
        @Assert(midpointSrgb.bytes(), [UInt8(188), UInt8(0), UInt8(0)])
    }

    @TestCase
    public func ownsComponentsAndRejectsInvalidAssociatedShapes(): Unit {
        let source: Array<UInt16> = [UInt16(1), UInt16(2), UInt16(3)]
        let buffer = PngLinearImageBuffer(
            UInt32(1), UInt32(1), LinearRgb, source, false
        )
        source[0] = UInt16(9)
        @Assert(buffer.components()[0], UInt16(1))
        let row = buffer.row(Int64(0))
        row[0] = UInt16(8)
        @Assert(buffer.row(Int64(0))[0], UInt16(1))

        expectLinearFailure(
            { =>
                PngLinearImageBuffer(
                    UInt32(1), UInt32(1), LinearRgb,
                    [UInt16(1), UInt16(2), UInt16(3)], true
                ); ()
            },
            InvalidArgument
        )
        expectLinearFailure(
            { =>
                beginPngImageReadFromMemory(linearSource())
                    .finishReadLinear(LinearRgb, true); ()
            },
            InvalidArgument
        )
    }

    @TestCase
    public func preservesWritePolicyLimitsAndLifecycleFailures(): Unit {
        let image = beginPngImageReadFromMemory(linearSource())
        let buffer = image.finishReadLinear(LinearRgba, true)
        expectLinearFailure(
            { => image.finishReadLinear(LinearRgba); () },
            InvalidArgument
        )

        let metadata = PngWriteMetadata()
        metadata.addText(PngTextEntry(
            Latin1Uncompressed,
            [UInt8(0x41), UInt8(0x50), UInt8(0x49)],
            [UInt8(0x6c), UInt8(0x69), UInt8(0x6e), UInt8(0x65), UInt8(0x61), UInt8(0x72)],
            Array<Byte>(),
            Array<Byte>()
        ), WriteBeforeIdat)
        let controls = PngWriteControlState()
        controls.setFilter(WriteFilterPaeth)
        controls.setCompressionLevel(Int32(1))
        controls.setCompressionBufferBytes(Int64(3))
        let encoded = writePngLinearImageToMemory(
            buffer,
            false,
            metadata,
            controls,
            Adam7,
            PngWriteLimits(
                UInt64(4096), UInt64(4096), UInt64(4096), UInt64(4096),
                UInt64(4096), UInt64(16384), UInt32(2)
            )
        )
        let decoded = decodePng(encoded)
        @Assert(decoded.ihdr.interlaceMethod, Adam7)
        @Assert(decoded.metadata.textEntryCount(), Int64(1))
        @Assert(decoded.metadata.gamma, UInt32(100000))

        expectLinearFailure(
            { =>
                writePngLinearImageToMemory(
                    buffer,
                    false,
                    PngWriteMetadata(),
                    PngWriteControlState(),
                    PngInterlaceMethod.None,
                    PngWriteLimits(
                        UInt64(1), UInt64(4096), UInt64(4096), UInt64(4096),
                        UInt64(4096), UInt64(16384), UInt32(4)
                    )
                ); ()
            },
            DecodeLimitExceeded
        )

        let limited = beginPngImageReadFromMemory(
            linearSource(),
            PngReadLimits(
                UInt32(4096), UInt32(16), UInt32(16),
                UInt64(4096), UInt64(4096), UInt64(1)
            )
        )
        expectLinearFailure(
            { => limited.finishReadLinear(LinearRgba); () },
            DecodeLimitExceeded
        )
        @Assert(limited.state(), PngImageFailed)
    }
}
