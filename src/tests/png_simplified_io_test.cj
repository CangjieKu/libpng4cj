package libpng4cj.tests

import std.collection.ArrayList
import std.fs.*
import std.io.*
import libpng4cj.*

private func simplifiedIoFixture(name: String): Array<Byte> {
    File.readFrom("test/fixtures/pngsuite/${name}")
}

private func simplifiedIoCopy(
    source: Array<Byte>,
    start: Int64,
    count: Int64
): Array<Byte> {
    let output = Array<Byte>(count, repeat: UInt8(0))
    var index: Int64 = Int64(0)
    while (index < count) {
        output[index] = source[start + index]
        index += Int64(1)
    }
    output
}

private class SimplifiedIoInputStream <: InputStream {
    private let source: Array<Byte>
    private let chunkBytes: Int64
    private let failOnRead: Int64
    private var offset: Int64 = Int64(0)
    public var readCalls: Int64 = Int64(0)

    public init(source: Array<Byte>, chunkBytes: Int64, failOnRead: Int64) {
        this.source = source.clone()
        this.chunkBytes = chunkBytes
        this.failOnRead = failOnRead
    }

    public init(source: Array<Byte>, chunkBytes: Int64) {
        this(source, chunkBytes, Int64(-1))
    }

    public override func read(buffer: Array<Byte>): Int64 {
        if (readCalls == failOnRead) {
            throw IOException("simplified input failure")
        }
        readCalls += Int64(1)
        if (offset >= source.size || buffer.size == Int64(0)) {
            return Int64(0)
        }
        let remaining = source.size - offset
        var count = if (remaining < buffer.size) { remaining } else { buffer.size }
        if (count > chunkBytes) { count = chunkBytes }
        var index: Int64 = Int64(0)
        while (index < count) {
            buffer[index] = source[offset + index]
            index += Int64(1)
        }
        offset += count
        count
    }
}

private class SimplifiedIoOutputStream <: OutputStream {
    private let output = ArrayList<Byte>()
    private let failWrite: Bool
    private let failFlush: Bool
    public var writeCalls: Int64 = Int64(0)
    public var flushCalls: Int64 = Int64(0)

    public init(failWrite: Bool, failFlush: Bool) {
        this.failWrite = failWrite
        this.failFlush = failFlush
    }

    public init() {
        this(false, false)
    }

    public override func write(bytes: Array<Byte>): Unit {
        writeCalls += Int64(1)
        if (failWrite) { throw IOException("simplified output failure") }
        for (value in bytes) { output.add(value) }
    }

    public override func flush(): Unit {
        flushCalls += Int64(1)
        if (failFlush) { throw IOException("simplified flush failure") }
    }

    public func bytes(): Array<Byte> { output.toArray() }
}

private func expectSimplifiedIoFailure(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected simplified IO operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind.toString(), expected.toString())
    }
}

private func removeSimplifiedIoFile(path: String): Unit {
    if (exists(Path(path))) { remove(Path(path)) }
}

@Test
public class PngSimplifiedIoTestSuite {
    @TestCase
    public func readsEveryFamilyFromCallerManagedStreams(): Unit {
        let directBytes = simplifiedIoFixture("ibasn2c08.png")
        let directStream = SimplifiedIoInputStream(directBytes, Int64(3))
        let expectedDirect = beginPngImageReadFromMemory(
            directBytes
        ).finishRead(ImageBgra8)
        let direct = beginPngImageReadFromStream(
            directStream,
            PngReadLimits(),
            PngSimplifiedIoLimits(UInt64(directBytes.size), UInt32(5))
        ).finishReadStrided(
            ImageBgra8,
            -(expectedDirect.minimumRowStride() + Int64(2)),
            UInt8(0xa5)
        )
        @Assert(direct.row(Int64(0)), expectedDirect.row(Int64(0)))
        @Assert(direct.bottomUp(), true)
        @Assert(directStream.readCalls > Int64(2), true)

        let linearStream = SimplifiedIoInputStream(directBytes, Int64(7))
        let expectedLinear = beginPngImageReadFromMemory(
            directBytes
        ).finishReadLinear(LinearRgba, true)
        let linear = beginPngImageReadFromStream(
            linearStream
        ).finishReadLinearStrided(
            LinearRgba, true,
            -(expectedLinear.minimumRowStride() + Int64(2)),
            UInt16(0xa5a5)
        )
        @Assert(linear.row(Int64(0)), expectedLinear.row(Int64(0)))
        @Assert(linear.bottomUp(), true)

        let indexedBytes = simplifiedIoFixture("ibasn3p04.png")
        let colormapStream = SimplifiedIoInputStream(indexedBytes, Int64(11))
        let expectedColormap = beginPngImageReadFromMemory(
            indexedBytes
        ).finishReadColormap(ColormapBgra8)
        let colormap = beginPngImageReadFromStream(
            colormapStream
        ).finishReadColormapStrided(
            ColormapBgra8,
            -(expectedColormap.minimumRowStride() + Int64(2)),
            UInt8(0xa5)
        )
        @Assert(colormap.row(Int64(0)), expectedColormap.row(Int64(0)))
        @Assert(colormap.colormap(), expectedColormap.colormap())
        @Assert(colormap.bottomUp(), true)
    }

    @TestCase
    public func writesEveryFamilyToCallerManagedStreamsAndFlushes(): Unit {
        let source = simplifiedIoFixture("ibasn2c08.png")
        let direct = beginPngImageReadFromMemory(source).finishRead(ImageBgra8)
        let directOutput = SimplifiedIoOutputStream()
        let metadata = PngWriteMetadata()
        metadata.setGamma(UInt32(45455))
        let controls = PngWriteControlState()
        controls.setFilter(WriteFilterPaeth)
        controls.setCompressionLevel(Int32(1))
        controls.setCompressionBufferBytes(Int64(3))
        let writeLimits = PngWriteLimits(
            UInt64(4096), UInt64(4096), UInt32(2)
        )
        let expectedDirectBytes = writePngImageToMemory(
            direct, metadata, controls, Adam7, writeLimits
        )
        writePngImageToStream(
            direct, directOutput, metadata, controls, Adam7, writeLimits
        )
        @Assert(directOutput.writeCalls, Int64(1))
        @Assert(directOutput.flushCalls, Int64(1))
        @Assert(directOutput.bytes(), expectedDirectBytes)
        @Assert(decodePng(directOutput.bytes()).metadata.gamma, UInt32(45455))
        @Assert(
            beginPngImageReadFromMemory(
                directOutput.bytes()
            ).finishRead(ImageBgra8).bytes(),
            direct.bytes()
        )
        @Assert(decodePng(directOutput.bytes()).ihdr.interlaceMethod, Adam7)

        let linear = beginPngImageReadFromMemory(
            source
        ).finishReadLinear(LinearRgba, true)
        let linearOutput = SimplifiedIoOutputStream()
        writePngLinearImageToStream(linear, linearOutput, false, Adam7)
        @Assert(linearOutput.flushCalls, Int64(1))
        @Assert(
            beginPngImageReadFromMemory(
                linearOutput.bytes()
            ).finishReadLinear(LinearRgba, true).components(),
            linear.components()
        )

        let indexed = simplifiedIoFixture("ibasn3p04.png")
        let colormap = beginPngImageReadFromMemory(
            indexed
        ).finishReadColormap(ColormapBgra8)
        let colormapOutput = SimplifiedIoOutputStream()
        writePngColormapImageToStream(colormap, colormapOutput, Adam7)
        @Assert(colormapOutput.flushCalls, Int64(1))
        let colormapRoundTrip = beginPngImageReadFromMemory(
            colormapOutput.bytes()
        ).finishReadColormap(ColormapBgra8)
        @Assert(colormapRoundTrip.indices(), colormap.indices())
        @Assert(colormapRoundTrip.colormap(), colormap.colormap())
    }

    @TestCase
    public func roundTripsEveryFamilyThroughOwnedFilePaths(): Unit {
        let directPath = "/tmp/libpng4cj-s007e-direct.png"
        let linearPath = "/tmp/libpng4cj-s007e-linear.png"
        let colormapPath = "/tmp/libpng4cj-s007e-colormap.png"
        removeSimplifiedIoFile(directPath)
        removeSimplifiedIoFile(linearPath)
        removeSimplifiedIoFile(colormapPath)
        try {
            let source = simplifiedIoFixture("ibasn2c08.png")
            let direct = beginPngImageReadFromMemory(
                source
            ).finishRead(ImageBgra8)
            writePngImageToFile(direct, directPath, Adam7)
            @Assert(
                beginPngImageReadFromFile(
                    directPath
                ).finishRead(ImageBgra8).bytes(),
                direct.bytes()
            )

            let linear = beginPngImageReadFromMemory(
                source
            ).finishReadLinear(LinearRgba, true)
            writePngLinearImageToFile(linear, linearPath, false, Adam7)
            @Assert(
                beginPngImageReadFromFile(
                    linearPath
                ).finishReadLinear(LinearRgba, true).components(),
                linear.components()
            )

            let colormap = beginPngImageReadFromMemory(
                simplifiedIoFixture("ibasn3p04.png")
            ).finishReadColormap(ColormapBgra8)
            writePngColormapImageToFile(colormap, colormapPath, Adam7)
            let colormapRoundTrip = beginPngImageReadFromFile(
                colormapPath
            ).finishReadColormap(ColormapBgra8)
            @Assert(colormapRoundTrip.indices(), colormap.indices())
            @Assert(colormapRoundTrip.colormap(), colormap.colormap())
        } finally {
            removeSimplifiedIoFile(directPath)
            removeSimplifiedIoFile(linearPath)
            removeSimplifiedIoFile(colormapPath)
        }
    }

    @TestCase
    public func mapsLimitsMalformedInputAndReadFailures(): Unit {
        let bytes = simplifiedIoFixture("basn2c08.png")
        let limited = PngImage()
        expectSimplifiedIoFailure(
            {
                =>
                    limited.beginReadFromStream(
                        SimplifiedIoInputStream(bytes, Int64(9)),
                        PngReadLimits(),
                        PngSimplifiedIoLimits(
                            UInt64(bytes.size - Int64(1)), UInt32(9)
                        )
                    )
            },
            DecodeLimitExceeded
        )
        @Assert(limited.state(), PngImageFailed)
        @Assert(
            limited.errorKindOrdinal(), DecodeLimitExceeded.ordinalValue()
        )
        let rejectedStream = SimplifiedIoInputStream(bytes, Int64(9))
        expectSimplifiedIoFailure(
            { => limited.beginReadFromStream(rejectedStream) },
            InvalidArgument
        )
        @Assert(rejectedStream.readCalls, Int64(0))

        let truncated = PngImage()
        expectSimplifiedIoFailure(
            {
                =>
                    truncated.beginReadFromStream(
                        SimplifiedIoInputStream(
                            simplifiedIoCopy(bytes, Int64(0), Int64(12)),
                            Int64(4)
                        )
                    )
            },
            TruncatedInput
        )
        @Assert(truncated.state(), PngImageFailed)

        let failedRead = PngImage()
        expectSimplifiedIoFailure(
            {
                =>
                    failedRead.beginReadFromStream(
                        SimplifiedIoInputStream(bytes, Int64(5), Int64(2))
                    )
            },
            IoFailure
        )
        @Assert(failedRead.state(), PngImageFailed)
        @Assert(failedRead.errorKindOrdinal(), IoFailure.ordinalValue())

        let missing = PngImage()
        expectSimplifiedIoFailure(
            {
                =>
                    missing.beginReadFromFile(
                        "/tmp/libpng4cj-s007e-does-not-exist/input.png"
                    )
            },
            IoFailure
        )
        @Assert(missing.state(), PngImageFailed)
    }

    @TestCase
    public func mapsWriteFlushAndPathOpenFailuresWithoutMaskingEncoding(): Unit {
        let image = beginPngImageReadFromMemory(
            simplifiedIoFixture("basn2c08.png")
        ).finishRead(ImageBgra8)

        let failedWrite = SimplifiedIoOutputStream(true, false)
        expectSimplifiedIoFailure(
            { => writePngImageToStream(image, failedWrite) },
            IoFailure
        )
        @Assert(failedWrite.writeCalls, Int64(1))
        @Assert(failedWrite.flushCalls, Int64(0))

        let failedFlush = SimplifiedIoOutputStream(false, true)
        expectSimplifiedIoFailure(
            { => writePngImageToStream(image, failedFlush) },
            IoFailure
        )
        @Assert(failedFlush.writeCalls, Int64(1))
        @Assert(failedFlush.flushCalls, Int64(1))

        expectSimplifiedIoFailure(
            {
                =>
                    writePngImageToFile(
                        image,
                        "/tmp/libpng4cj-s007e-missing-directory/output.png"
                    )
            },
            IoFailure
        )

        let malformed = PngImageBuffer(
            UInt32(1), UInt32(1), ImageRgb8,
            [UInt8(1), UInt8(2), UInt8(3)]
        )
        let encodingFailureOutput = SimplifiedIoOutputStream()
        expectSimplifiedIoFailure(
            {
                =>
                    writePngImageToStream(
                        malformed,
                        encodingFailureOutput,
                        PngWriteMetadata(),
                        PngWriteControlState(),
                        PngInterlaceMethod.None,
                        PngWriteLimits(
                            UInt64(1), UInt64(1), UInt32(1)
                        )
                    )
            },
            DecodeLimitExceeded
        )
        @Assert(encodingFailureOutput.writeCalls, Int64(0))
        @Assert(encodingFailureOutput.flushCalls, Int64(0))
    }
}
