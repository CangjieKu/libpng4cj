package libpng4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private let PNG_COLORMAP_FORMATS: Array<PngColormapFormat> = [
    ColormapRgb8,
    ColormapBgr8,
    ColormapRgba8,
    ColormapArgb8,
    ColormapBgra8,
    ColormapAbgr8
]

private func indexedColormapSource(): Array<Byte> {
    let metadata = PngWriteMetadata()
    metadata.setTransparency(PngWriteTransparency([UInt8(0), UInt8(255)]))
    encodePngPacked(
        UInt32(2), UInt32(1), UInt8(1), Indexed, [[UInt8(0x40)]],
        [
            UInt8(255), UInt8(0), UInt8(0),
            UInt8(0), UInt8(255), UInt8(0)
        ],
        metadata, WriteFilterAdaptive, Int32(6), PngWriteLimits()
    )
}

private func expectColormapFailure(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected simplified colormap operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

@Test
public class PngSimplifiedColormapTestSuite {
    @TestCase
    public func preservesIndexedIdentityAcrossEveryEntryLayout(): Unit {
        let encoded = indexedColormapSource()
        for (format in PNG_COLORMAP_FORMATS) {
            let image = beginPngImageReadFromMemory(encoded)
            let mapped = image.finishReadColormap(format)
            @Assert(image.state(), PngImageFinished)
            @Assert(mapped.width, UInt32(2))
            @Assert(mapped.height, UInt32(1))
            @Assert(mapped.rowStride, Int64(2))
            @Assert(mapped.entryChannels, format.channelCount())
            @Assert(mapped.entryCount, UInt16(2))
            @Assert(mapped.indices(), [UInt8(0), UInt8(1)])
            @Assert(mapped.entry(0).size, Int64(format.channelCount()))

            let rewritten = writePngColormapImageToMemory(mapped)
            let decoded = decodePng(rewritten)
            @Assert(decoded.ihdr.colorType, Indexed)
            @Assert(decoded.ihdr.bitDepth, UInt8(1))
            let roundTrip = beginPngImageReadFromMemory(rewritten)
                .finishReadColormap(format)
            @Assert(roundTrip.indices(), mapped.indices())
            @Assert(roundTrip.colormap(), mapped.colormap())
        }
    }

    @TestCase
    public func generatesFrozenRgbAndRgbaColormapFamilies(): Unit {
        let rgb = encodePngPacked(
            UInt32(3), UInt32(1), UInt8(8), Truecolor,
            [[
                UInt8(0), UInt8(0), UInt8(0),
                UInt8(51), UInt8(102), UInt8(153),
                UInt8(255), UInt8(255), UInt8(255)
            ]]
        )
        let rgbMap = beginPngImageReadFromMemory(rgb)
            .finishReadColormap(ColormapRgb8)
        @Assert(rgbMap.entryCount, UInt16(216))
        @Assert(rgbMap.indices(), [UInt8(0), UInt8(51), UInt8(215)])
        @Assert(rgbMap.entry(51), [UInt8(51), UInt8(102), UInt8(153)])

        let rgba = encodePngPacked(
            UInt32(3), UInt32(1), UInt8(8), TruecolorAlpha,
            [[
                UInt8(255), UInt8(0), UInt8(0), UInt8(255),
                UInt8(0), UInt8(255), UInt8(0), UInt8(0),
                UInt8(200), UInt8(10), UInt8(130), UInt8(128)
            ]]
        )
        let rgbaMap = beginPngImageReadFromMemory(rgba)
            .finishReadColormap(ColormapRgba8)
        @Assert(rgbaMap.entryCount, UInt16(244))
        @Assert(rgbaMap.indices(), [UInt8(180), UInt8(216), UInt8(236)])
        @Assert(
            rgbaMap.entry(216),
            [UInt8(255), UInt8(255), UInt8(255), UInt8(0)]
        )
        @Assert(
            rgbaMap.entry(236),
            [UInt8(255), UInt8(0), UInt8(127), UInt8(128)]
        )
    }

    @TestCase
    public func generatesGrayAlphaMapAndComposesRemovedAlpha(): Unit {
        let ga = encodePngPacked(
            UInt32(3), UInt32(1), UInt8(8), GrayscaleAlpha,
            [[
                UInt8(255), UInt8(255),
                UInt8(0), UInt8(0),
                UInt8(102), UInt8(128)
            ]]
        )
        let retained = beginPngImageReadFromMemory(ga)
            .finishReadColormap(ColormapRgba8)
        @Assert(retained.entryCount, UInt16(256))
        @Assert(retained.indices(), [UInt8(230), UInt8(231), UInt8(246)])
        @Assert(
            retained.entry(231),
            [UInt8(255), UInt8(255), UInt8(255), UInt8(0)]
        )

        let background = PngSrgbColor8(UInt8(1), UInt8(2), UInt8(3))
        let removed = beginPngImageReadFromMemory(ga)
            .finishReadColormap(ColormapRgb8, background)
        @Assert(removed.entryCount, UInt16(256))
        @Assert(removed.indices(), [UInt8(230), UInt8(231), UInt8(246)])
        @Assert(removed.entry(231), [UInt8(1), UInt8(2), UInt8(3)])
    }

    @TestCase
    public func supportsAdam7GeneratedMapsAndIndexedWriteControls(): Unit {
        let encoded = encodePngPackedAdam7(
            UInt32(2), UInt32(2), UInt8(8), TruecolorAlpha,
            [
                [
                    UInt8(255), UInt8(0), UInt8(0), UInt8(255),
                    UInt8(0), UInt8(255), UInt8(0), UInt8(0)
                ],
                [
                    UInt8(0), UInt8(0), UInt8(255), UInt8(128),
                    UInt8(255), UInt8(255), UInt8(255), UInt8(255)
                ]
            ]
        )
        let mapped = beginPngImageReadFromMemory(encoded)
            .finishReadColormap(ColormapBgra8)
        @Assert(mapped.indices().size, Int64(4))
        @Assert(mapped.entryCount, UInt16(244))

        let controls = PngWriteControlState()
        controls.setFilter(WriteFilterPaeth)
        controls.setCompressionLevel(Int32(1))
        controls.setCompressionBufferBytes(Int64(3))
        let rewritten = writePngColormapImageToMemory(
            mapped,
            PngWriteMetadata(),
            controls,
            Adam7,
            PngWriteLimits(UInt64(8192), UInt64(8192), UInt32(2))
        )
        let decoded = decodePng(rewritten)
        @Assert(decoded.ihdr.colorType, Indexed)
        @Assert(decoded.ihdr.bitDepth, UInt8(8))
        @Assert(decoded.ihdr.interlaceMethod, Adam7)
        let roundTrip = beginPngImageReadFromMemory(rewritten)
            .finishReadColormap(ColormapBgra8)
        @Assert(roundTrip.indices(), mapped.indices())
        @Assert(roundTrip.colormap(), mapped.colormap())
    }

    @TestCase
    public func ownsBuffersAndRejectsInvalidShapesLimitsAndLifecycle(): Unit {
        let mapped = beginPngImageReadFromMemory(indexedColormapSource())
            .finishReadColormap(ColormapRgba8)
        let indices = mapped.indices()
        indices[0] = UInt8(1)
        @Assert(mapped.indices()[0], UInt8(0))
        let colormap = mapped.colormap()
        colormap[0] = UInt8(0)
        @Assert(mapped.colormap()[0], UInt8(255))
        let row = mapped.row(Int64(0))
        row[0] = UInt8(1)
        @Assert(mapped.row(Int64(0))[0], UInt8(0))

        expectColormapFailure(
            { =>
                PngColormapImageBuffer(
                    UInt32(1), UInt32(1), ColormapRgb8,
                    [UInt8(1)], [UInt8(1), UInt8(2), UInt8(3)]
                ); ()
            },
            PaletteIndexOutOfRange
        )

        let limited = beginPngImageReadFromMemory(
            encodePngPacked(
                UInt32(1), UInt32(1), UInt8(8), Truecolor,
                [[UInt8(1), UInt8(2), UInt8(3)]]
            ),
            PngReadLimits(
                UInt32(1024), UInt32(8), UInt32(8),
                UInt64(1024), UInt64(1024), UInt64(4)
            )
        )
        expectColormapFailure(
            { => limited.finishReadColormap(ColormapRgb8); () },
            DecodeLimitExceeded
        )
        @Assert(limited.state(), PngImageFailed)

        let image = PngImage()
        expectColormapFailure(
            { => image.finishReadColormap(ColormapRgb8); () },
            InvalidArgument
        )
    }
}
