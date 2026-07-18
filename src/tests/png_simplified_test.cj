package libpng4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private let PNG_SIMPLIFIED_FORMATS: Array<PngImageFormat> = [
    ImageGray8,
    ImageGrayAlpha8,
    ImageAlphaGray8,
    ImageRgb8,
    ImageBgr8,
    ImageRgba8,
    ImageArgb8,
    ImageBgra8,
    ImageAbgr8
]

private func simplifiedSource(): Array<Byte> {
    encodePngPacked(
        UInt32(2),
        UInt32(2),
        UInt8(8),
        TruecolorAlpha,
        [
            [
                UInt8(255), UInt8(0), UInt8(0), UInt8(128),
                UInt8(0), UInt8(255), UInt8(0), UInt8(255)
            ],
            [
                UInt8(0), UInt8(0), UInt8(255), UInt8(64),
                UInt8(255), UInt8(255), UInt8(255), UInt8(0)
            ]
        ]
    )
}

private func expectSimplifiedFailure(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected simplified image operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

@Test
public class PngSimplifiedImageTestSuite {
    @TestCase
    public func readsAndWritesEveryCommonEightBitLayout(): Unit {
        let encoded = simplifiedSource()
        for (format in PNG_SIMPLIFIED_FORMATS) {
            let image = beginPngImageReadFromMemory(encoded)
            @Assert(image.version, PNG_IMAGE_VERSION)
            @Assert(image.state(), PngImageReading)
            @Assert(image.width(), UInt32(2))
            @Assert(image.height(), UInt32(2))
            @Assert(image.sourceBitDepth(), UInt8(8))
            @Assert(image.sourceColorType(), TruecolorAlpha)
            @Assert(image.suggestedFormat(), ImageRgba8)

            let buffer = image.finishRead(format)
            @Assert(image.state(), PngImageFinished)
            @Assert(buffer.width, UInt32(2))
            @Assert(buffer.height, UInt32(2))
            @Assert(buffer.channels, format.channelCount())
            @Assert(
                buffer.rowStride,
                Int64(2) * Int64(format.channelCount())
            )
            @Assert(
                buffer.byteCount(),
                buffer.rowStride * Int64(buffer.height)
            )

            let rewritten = writePngImageToMemory(buffer)
            let reread = beginPngImageReadFromMemory(rewritten)
            @Assert(reread.finishRead(format).bytes(), buffer.bytes())
        }
    }

    @TestCase
    public func compositesRemovedAlphaOntoExplicitSrgbBackground(): Unit {
        let encoded = encodePngPacked(
            UInt32(1),
            UInt32(1),
            UInt8(8),
            TruecolorAlpha,
            [[UInt8(255), UInt8(0), UInt8(0), UInt8(128)]]
        )
        let image = beginPngImageReadFromMemory(encoded)
        let rgb = image.finishRead(
            ImageRgb8,
            PngSrgbColor8(UInt8(0), UInt8(0), UInt8(255))
        )
        @Assert(rgb.bytes(), [UInt8(128), UInt8(0), UInt8(127)])

        let black = beginPngImageReadFromMemory(encoded).finishRead(ImageRgb8)
        @Assert(black.bytes(), [UInt8(128), UInt8(0), UInt8(0)])
    }

    @TestCase
    public func acceptsPackedIndexedTransparencySixteenBitAndAdam7Sources(): Unit {
        let indexedMetadata = PngWriteMetadata()
        indexedMetadata.setTransparency(
            PngWriteTransparency([UInt8(0), UInt8(255)])
        )
        let indexed = encodePngPacked(
            UInt32(2),
            UInt32(1),
            UInt8(1),
            Indexed,
            [[UInt8(0x40)]],
            [
                UInt8(255), UInt8(0), UInt8(0),
                UInt8(0), UInt8(255), UInt8(0)
            ],
            indexedMetadata,
            WriteFilterAdaptive,
            Int32(6),
            PngWriteLimits()
        )
        @Assert(
            beginPngImageReadFromMemory(indexed).finishRead(ImageRgba8).bytes(),
            [
                UInt8(255), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(255), UInt8(0), UInt8(255)
            ]
        )

        let packedGrayCases: Array<(UInt8, UInt32, Array<Byte>)> = [
            (UInt8(2), UInt32(4), [UInt8(0x1b)]),
            (UInt8(4), UInt32(2), [UInt8(0x1f)])
        ]
        for ((bitDepth, width, row) in packedGrayCases) {
            let packed = encodePngPacked(
                width, UInt32(1), bitDepth, Grayscale, [row]
            )
            let packedImage = beginPngImageReadFromMemory(packed)
            @Assert(packedImage.sourceBitDepth(), bitDepth)
            @Assert(
                packedImage.finishRead(ImageGray8).byteCount(),
                Int64(width)
            )
        }

        let sixteen = encodePngPacked(
            UInt32(1),
            UInt32(1),
            UInt8(16),
            TruecolorAlpha,
            [[
                UInt8(0x12), UInt8(0x34),
                UInt8(0x80), UInt8(0x00),
                UInt8(0xff), UInt8(0xff),
                UInt8(0x40), UInt8(0x00)
            ]]
        )
        let sixteenImage = beginPngImageReadFromMemory(sixteen)
        @Assert(sixteenImage.sourceBitDepth(), UInt8(16))
        @Assert(
            sixteenImage.finishRead(ImageRgba8).bytes(),
            [UInt8(18), UInt8(128), UInt8(255), UInt8(64)]
        )

        let adam7 = encodePngPackedAdam7(
            UInt32(2),
            UInt32(2),
            UInt8(8),
            TruecolorAlpha,
            [
                [
                    UInt8(1), UInt8(2), UInt8(3), UInt8(4),
                    UInt8(5), UInt8(6), UInt8(7), UInt8(8)
                ],
                [
                    UInt8(9), UInt8(10), UInt8(11), UInt8(12),
                    UInt8(13), UInt8(14), UInt8(15), UInt8(16)
                ]
            ]
        )
        @Assert(
            beginPngImageReadFromMemory(adam7).finishRead(ImageRgba8).bytes(),
            [
                UInt8(1), UInt8(2), UInt8(3), UInt8(4),
                UInt8(5), UInt8(6), UInt8(7), UInt8(8),
                UInt8(9), UInt8(10), UInt8(11), UInt8(12),
                UInt8(13), UInt8(14), UInt8(15), UInt8(16)
            ]
        )
    }

    @TestCase
    public func ownsInputAndOutputAndKeepsDeterministicLifecycleFailures(): Unit {
        let encoded = simplifiedSource()
        let expected = encoded.clone()
        let image = PngImage()
        image.beginReadFromMemory(encoded)
        encoded[0] = UInt8(0)
        @Assert(image.finishRead(ImageRgba8).byteCount(), Int64(16))
        @Assert(isPngSignature(expected), true)

        let output = beginPngImageReadFromMemory(expected).finishRead(ImageRgba8)
        let copy = output.bytes()
        copy[0] = UInt8(0)
        @Assert(output.bytes()[0], UInt8(255))
        let row = output.row(Int64(0))
        row[0] = UInt8(0)
        @Assert(output.row(Int64(0))[0], UInt8(255))

        let freed = beginPngImageReadFromMemory(expected)
        freed.free()
        @Assert(freed.state(), PngImageFreed)
        expectSimplifiedFailure(
            { => freed.finishRead(ImageRgba8); () },
            InvalidArgument
        )
        freed.free()
        @Assert(freed.state(), PngImageFreed)
        expectSimplifiedFailure(
            { =>
                freed.beginReadFromMemory(
                    Array<Byte>(Int64(8), repeat: UInt8(0))
                ); ()
            },
            InvalidSignature
        )
        @Assert(freed.width(), UInt32(0))
        @Assert(freed.height(), UInt32(0))

        let malformed = PngImage()
        expectSimplifiedFailure(
            { =>
                malformed.beginReadFromMemory(
                    Array<Byte>(Int64(8), repeat: UInt8(0))
                ); ()
            },
            InvalidSignature
        )
        @Assert(malformed.state(), PngImageFailed)
        @Assert(malformed.failed(), true)
        @Assert(malformed.warningOrError(), PNG_IMAGE_ERROR)
        @Assert(
            malformed.errorKindOrdinal(),
            InvalidSignature.ordinalValue()
        )
        @Assert(malformed.message().size > Int64(0), true)
    }

    @TestCase
    public func writesAdam7WithMetadataControlsAndExactRoundTrip(): Unit {
        let buffer = beginPngImageReadFromMemory(
            simplifiedSource()
        ).finishRead(ImageBgra8)
        let metadata = PngWriteMetadata()
        metadata.setGamma(UInt32(45455))
        let controls = PngWriteControlState()
        controls.setFilter(WriteFilterPaeth)
        controls.setCompressionLevel(Int32(1))
        controls.setCompressionBufferBytes(Int64(3))
        let encoded = writePngImageToMemory(
            buffer,
            metadata,
            controls,
            Adam7,
            PngWriteLimits(UInt64(4096), UInt64(4096), UInt32(2))
        )
        let decoded = decodePng(encoded)
        @Assert(decoded.ihdr.interlaceMethod, Adam7)
        @Assert(decoded.metadata.hasGamma, true)
        @Assert(decoded.metadata.gamma, UInt32(45455))
        @Assert(
            beginPngImageReadFromMemory(encoded).finishRead(ImageBgra8).bytes(),
            buffer.bytes()
        )
    }

    @TestCase
    public func rejectsMalformedBufferDimensionsAndRepeatedLifecycleCalls(): Unit {
        expectSimplifiedFailure(
            { =>
                PngImageBuffer(
                    UInt32(2), UInt32(1), ImageRgb8,
                    [UInt8(1), UInt8(2), UInt8(3)]
                ); ()
            },
            InvalidArgument
        )

        let image = PngImage()
        expectSimplifiedFailure(
            { => image.finishRead(ImageRgba8); () },
            InvalidArgument
        )
        image.beginReadFromMemory(simplifiedSource())
        expectSimplifiedFailure(
            { => image.beginReadFromMemory(simplifiedSource()); () },
            InvalidArgument
        )
        image.finishRead(ImageRgba8)
        expectSimplifiedFailure(
            { => image.finishRead(ImageRgba8); () },
            InvalidArgument
        )
    }
}
