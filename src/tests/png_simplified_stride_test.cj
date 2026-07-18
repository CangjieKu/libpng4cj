package libpng4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private func strideRgbaRows(): Array<Array<Byte>> {
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
}

private func strideRgbaSource(interlaceMethod: PngInterlaceMethod): Array<Byte> {
    if (interlaceMethod == Adam7) {
        encodePngPackedAdam7(
            UInt32(2), UInt32(2), UInt8(8), TruecolorAlpha,
            strideRgbaRows()
        )
    } else {
        encodePngPacked(
            UInt32(2), UInt32(2), UInt8(8), TruecolorAlpha,
            strideRgbaRows()
        )
    }
}

private func expectStrideFailure(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected strided simplified image operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

@Test
public class PngSimplifiedStrideTestSuite {
    @TestCase
    public func directBuffersPreservePositiveAndNegativePadding(): Unit {
        let top = [
            UInt8(1), UInt8(2), UInt8(3),
            UInt8(4), UInt8(5), UInt8(6)
        ]
        let bottom = [
            UInt8(7), UInt8(8), UInt8(9),
            UInt8(10), UInt8(11), UInt8(12)
        ]
        let positive = PngImageBuffer(
            UInt32(2), UInt32(2), ImageRgb8,
            [
                UInt8(1), UInt8(2), UInt8(3), UInt8(4), UInt8(5), UInt8(6),
                UInt8(0xaa), UInt8(0xaa),
                UInt8(7), UInt8(8), UInt8(9), UInt8(10), UInt8(11), UInt8(12),
                UInt8(0xbb), UInt8(0xbb)
            ],
            Int64(8)
        )
        @Assert(positive.minimumRowStride(), Int64(6))
        @Assert(positive.bottomUp(), false)
        @Assert(positive.row(Int64(0)), top)
        @Assert(positive.row(Int64(1)), bottom)
        @Assert(
            positive.storageRow(Int64(0)),
            [
                UInt8(1), UInt8(2), UInt8(3), UInt8(4), UInt8(5), UInt8(6),
                UInt8(0xaa), UInt8(0xaa)
            ]
        )

        let negative = positive.withRowStride(Int64(-9), UInt8(0xee))
        @Assert(negative.rowStride, Int64(-9))
        @Assert(negative.bottomUp(), true)
        @Assert(negative.row(Int64(0)), top)
        @Assert(negative.row(Int64(1)), bottom)
        @Assert(
            negative.bytes(),
            [
                UInt8(7), UInt8(8), UInt8(9), UInt8(10), UInt8(11), UInt8(12),
                UInt8(0xee), UInt8(0xee), UInt8(0xee),
                UInt8(1), UInt8(2), UInt8(3), UInt8(4), UInt8(5), UInt8(6),
                UInt8(0xee), UInt8(0xee), UInt8(0xee)
            ]
        )
        let storageCopy = negative.bytes()
        storageCopy[0] = UInt8(0)
        @Assert(negative.bytes()[0], UInt8(7))
        let positiveAgain = negative.withRowStride(Int64(7), UInt8(0xdd))
        @Assert(positiveAgain.row(Int64(0)), top)
        @Assert(positiveAgain.row(Int64(1)), bottom)
        @Assert(positiveAgain.storageRow(Int64(0))[6], UInt8(0xdd))

        for (interlace in [PngInterlaceMethod.None, PngInterlaceMethod.Adam7]) {
            let reread = beginPngImageReadFromMemory(
                writePngImageToMemory(negative, interlace)
            ).finishRead(ImageRgb8)
            @Assert(reread.row(Int64(0)), top)
            @Assert(reread.row(Int64(1)), bottom)
        }
    }

    @TestCase
    public func directFinishReadsIntoBottomUpStorage(): Unit {
        for (sourceInterlace in [
            PngInterlaceMethod.None, PngInterlaceMethod.Adam7
        ]) {
            let image = beginPngImageReadFromMemory(
                strideRgbaSource(sourceInterlace)
            )
            let output = image.finishReadStrided(
                ImageRgba8, Int64(-10), UInt8(0xcc)
            )
            @Assert(image.state(), PngImageFinished)
            @Assert(output.row(Int64(0)), strideRgbaRows()[0])
            @Assert(output.row(Int64(1)), strideRgbaRows()[1])
            @Assert(
                output.storageRow(Int64(0)),
                [
                    UInt8(1), UInt8(2), UInt8(3), UInt8(4),
                    UInt8(5), UInt8(6), UInt8(7), UInt8(8),
                    UInt8(0xcc), UInt8(0xcc)
                ]
            )
            @Assert(output.bytes()[0], UInt8(9))
            let rewritten = writePngImageToMemory(output, Adam7)
            let reread = beginPngImageReadFromMemory(rewritten)
                .finishRead(ImageRgba8)
            @Assert(reread.row(Int64(0)), strideRgbaRows()[0])
            @Assert(reread.row(Int64(1)), strideRgbaRows()[1])
        }
    }

    @TestCase
    public func linearBuffersUseComponentStrideAndRoundTrip(): Unit {
        let logicalTop = [
            UInt16(65535), UInt16(0), UInt16(0), UInt16(65535)
        ]
        let logicalBottom = [
            UInt16(0), UInt16(65535), UInt16(0), UInt16(32768)
        ]
        let input = PngLinearImageBuffer(
            UInt32(1), UInt32(2), LinearRgba,
            [
                UInt16(0), UInt16(65535), UInt16(0), UInt16(32768),
                UInt16(0xaaaa), UInt16(0xbbbb),
                UInt16(65535), UInt16(0), UInt16(0), UInt16(65535),
                UInt16(0xcccc), UInt16(0xdddd)
            ],
            false,
            Int64(-6)
        )
        @Assert(input.minimumRowStride(), Int64(4))
        @Assert(input.byteCount(), Int64(24))
        @Assert(input.row(Int64(0)), logicalTop)
        @Assert(input.row(Int64(1)), logicalBottom)
        @Assert(
            input.storageRow(Int64(1)),
            [
                UInt16(0), UInt16(65535), UInt16(0), UInt16(32768),
                UInt16(0xaaaa), UInt16(0xbbbb)
            ]
        )

        let encoded = writePngLinearImageToMemory(input, false, Adam7)
        let output = beginPngImageReadFromMemory(encoded)
            .finishReadLinearStrided(
                LinearRgba, Int64(7), UInt16(0xeeee)
            )
        @Assert(output.associatedAlpha, false)
        @Assert(output.row(Int64(0)), logicalTop)
        @Assert(output.row(Int64(1)), logicalBottom)
        @Assert(output.storageRow(Int64(0))[6], UInt16(0xeeee))
        @Assert(output.storageRow(Int64(1))[6], UInt16(0xeeee))
        let reread = beginPngImageReadFromMemory(
            writePngLinearImageToMemory(output)
        ).finishReadLinear(LinearRgba)
        @Assert(reread.row(Int64(0)), logicalTop)
        @Assert(reread.row(Int64(1)), logicalBottom)
    }

    @TestCase
    public func colormapPaddingIsNotTreatedAsPixelIndices(): Unit {
        let colormap = [
            UInt8(255), UInt8(0), UInt8(0), UInt8(255),
            UInt8(0), UInt8(255), UInt8(0), UInt8(128),
            UInt8(0), UInt8(0), UInt8(255), UInt8(0)
        ]
        let input = PngColormapImageBuffer(
            UInt32(2), UInt32(2), ColormapRgba8,
            [
                UInt8(2), UInt8(1), UInt8(0xfe), UInt8(0xfd),
                UInt8(0), UInt8(2), UInt8(0xfc), UInt8(0xfb)
            ],
            colormap,
            Int64(-4)
        )
        @Assert(input.row(Int64(0)), [UInt8(0), UInt8(2)])
        @Assert(input.row(Int64(1)), [UInt8(2), UInt8(1)])
        @Assert(input.storageRow(Int64(0))[2], UInt8(0xfc))
        @Assert(input.entry(Int64(1)), [
            UInt8(0), UInt8(255), UInt8(0), UInt8(128)
        ])

        let encoded = writePngColormapImageToMemory(input, Adam7)
        let output = beginPngImageReadFromMemory(encoded)
            .finishReadColormapStrided(
                ColormapRgba8, Int64(-5), UInt8(0xfa)
            )
        @Assert(output.row(Int64(0)), [UInt8(0), UInt8(2)])
        @Assert(output.row(Int64(1)), [UInt8(2), UInt8(1)])
        @Assert(output.colormap(), colormap)
        @Assert(output.storageRow(Int64(0))[4], UInt8(0xfa))
        @Assert(output.indices()[0], UInt8(2))
        let nonInterlaced = writePngColormapImageToMemory(output)
        let reread = beginPngImageReadFromMemory(nonInterlaced)
            .finishReadColormap(ColormapRgba8)
        @Assert(reread.row(Int64(0)), [UInt8(0), UInt8(2)])
        @Assert(reread.row(Int64(1)), [UInt8(2), UInt8(1)])
    }

    @TestCase
    public func zeroMinimumAndOneRowStridesStayDeterministic(): Unit {
        let contiguous = PngImageBuffer(
            UInt32(1), UInt32(1), ImageRgba8,
            [UInt8(1), UInt8(2), UInt8(3), UInt8(4)],
            Int64(0)
        )
        @Assert(contiguous.rowStride, Int64(4))
        let bottomUp = contiguous.withRowStride(Int64(-6), UInt8(0xa5))
        @Assert(bottomUp.bottomUp(), true)
        @Assert(
            bottomUp.bytes(),
            [
                UInt8(1), UInt8(2), UInt8(3), UInt8(4),
                UInt8(0xa5), UInt8(0xa5)
            ]
        )
        @Assert(bottomUp.row(Int64(0)), contiguous.row(Int64(0)))
    }

    @TestCase
    public func rejectsSmallOverflowingAndLimitBreakingStrides(): Unit {
        expectStrideFailure(
            { =>
                PngImageBuffer(
                    UInt32(2), UInt32(1), ImageRgba8,
                    Array<Byte>(Int64(7), repeat: UInt8(0)), Int64(7)
                ); ()
            },
            InvalidArgument
        )
        expectStrideFailure(
            { =>
                PngLinearImageBuffer(
                    UInt32(1), UInt32(1), LinearRgba,
                    Array<UInt16>(Int64(4), repeat: UInt16(0)), false,
                    Int64.Min
                ); ()
            },
            InvalidArgument
        )
        expectStrideFailure(
            { =>
                PngColormapImageBuffer(
                    UInt32(1), UInt32(2), ColormapRgb8,
                    Array<Byte>(),
                    [UInt8(0), UInt8(0), UInt8(0)],
                    Int64.Max
                ); ()
            },
            DecodeLimitExceeded
        )

        let limits = PngReadLimits(
            UInt32(1024), UInt32(2), UInt32(2),
            PNG_DEFAULT_MAX_COMPRESSED_BYTES,
            PNG_DEFAULT_MAX_INFLATED_BYTES,
            UInt64(16)
        )
        let image = beginPngImageReadFromMemory(
            strideRgbaSource(PngInterlaceMethod.None), limits
        )
        expectStrideFailure(
            { =>
                image.finishReadStrided(
                    ImageRgba8, Int64(10), UInt8(0)
                ); ()
            },
            DecodeLimitExceeded
        )
        @Assert(image.state(), PngImageFailed)
    }
}
