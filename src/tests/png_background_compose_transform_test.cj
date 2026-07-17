package libpng4cj.tests

import libpng4cj.*

private let COMPOSE_GRAY8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0xe0, 0x12, 0x91, 0x03, 0x00, 0x00, 0x68, 0x00, 0x3d
]

private let COMPOSE_RGBA8_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0xe0, 0x12, 0x91, 0x63, 0x48, 0xc9, 0xab, 0x68,
    0x38, 0x71, 0xe9, 0xce, 0x7f, 0x00, 0x16, 0x4c, 0x05, 0x7c
]

private func composeJoin(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let output = Array<Byte>(left.size + right.size, repeat: 0)
    var index: Int64 = 0
    while (index < left.size) {
        output[index] = left[index]
        index += 1
    }
    var rightIndex: Int64 = 0
    while (rightIndex < right.size) {
        output[left.size + rightIndex] = right[rightIndex]
        rightIndex += 1
    }
    output
}

private func composeChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    composeJoin(
        composeJoin(
            composeJoin(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func composeDecoded(
    width: UInt8,
    bitDepth: UInt8,
    colorType: UInt8,
    beforeIdat: Array<Array<Byte>>,
    compressed: Array<Byte>
): PngDecodedRows {
    let ihdr = Array<Byte>(13, repeat: 0)
    ihdr[3] = width
    ihdr[7] = UInt8(1)
    ihdr[8] = bitDepth
    ihdr[9] = colorType
    var png = composeJoin(PNG_SIGNATURE, composeChunk(PNG_CHUNK_IHDR, ihdr))
    for (chunk in beforeIdat) {
        png = composeJoin(png, chunk)
    }
    png = composeJoin(png, composeChunk(PNG_CHUNK_IDAT, compressed))
    png = composeJoin(png, composeChunk(PNG_CHUNK_IEND, Array<Byte>()))
    decodePngNonInterlaced(png)
}

private func composeBackground(
    gray: UInt16,
    red: UInt16,
    green: UInt16,
    blue: UInt16
): PngBackground {
    PngBackground(UInt8(0), gray, red, green, blue)
}

private func compose8Oracle(
    foreground: UInt8,
    alpha: UInt8,
    background: UInt8
): UInt8 {
    let temporary = UInt32(foreground) * UInt32(alpha) +
        UInt32(background) * (UInt32(255) - UInt32(alpha)) + UInt32(128)
    UInt8(((temporary + (temporary >> UInt32(8))) >> UInt32(8)) & UInt32(0xff))
}

private func compose16Oracle(
    foreground: UInt16,
    alpha: UInt16,
    background: UInt16
): UInt16 {
    let temporary = UInt64(foreground) * UInt64(alpha) +
        UInt64(background) * (UInt64(65535) - UInt64(alpha)) + UInt64(32768)
    UInt16(
        ((temporary + (temporary >> UInt64(16))) >> UInt64(16)) &
        UInt64(0xffff)
    )
}

private func compose16Bytes(values: Array<UInt16>): Array<Byte> {
    let output = Array<Byte>(values.size * 2, repeat: 0)
    var index: Int64 = 0
    while (index < values.size) {
        output[index * 2] = UInt8(values[index] >> UInt16(8))
        output[index * 2 + 1] = UInt8(values[index] & UInt16(0xff))
        index += 1
    }
    output
}

private func composePackedOracle(
    row: UInt8,
    width: UInt32,
    bitDepth: UInt8,
    key: UInt16,
    background: UInt16,
    table: PngGamma8BitTable
): UInt8 {
    var output = UInt32(row)
    let depth = UInt32(bitDepth)
    let mask = (UInt32(1) << depth) - UInt32(1)
    var pixel = UInt32(0)
    while (pixel < width) {
        let shift = UInt32(8) - depth - pixel * depth
        let sample = (output >> shift) & mask
        let value = if (sample == (UInt32(key) & mask)) {
            UInt32(background) & mask
        } else if (depth == UInt32(2)) {
            UInt32(table.value(UInt8(sample * UInt32(85)))) >> UInt32(6)
        } else {
            UInt32(table.value(UInt8(sample * UInt32(17)))) >> UInt32(4)
        }
        output = (output & !(mask << shift)) | ((value & mask) << shift)
        pixel += UInt32(1)
    }
    UInt8(output)
}

@Test
public class PngBackgroundComposeTransformTestSuite {
    @TestCase
    public func replacesPackedGrayColorKeysAndPreservesPadding(): Unit {
        let one = pngDoCompose(
            PngReadRowInfo(UInt32(5), UInt8(1), Grayscale),
            [0xaf],
            composeBackground(UInt16(0), UInt16(0), UInt16(0), UInt16(0)),
            PngExpandTransparency(UInt16(1))
        )
        let oneExpected: Array<Byte> = [0x07]
        @Assert(one.row(), oneExpected)

        let two = pngDoCompose(
            PngReadRowInfo(UInt32(3), UInt8(2), Grayscale),
            [0x1b],
            composeBackground(UInt16(3), UInt16(0), UInt16(0), UInt16(0)),
            PngExpandTransparency(UInt16(1))
        )
        let twoExpected: Array<Byte> = [0x3b]
        @Assert(two.row(), twoExpected)

        let four = pngDoCompose(
            PngReadRowInfo(UInt32(1), UInt8(4), Grayscale),
            [0xab],
            composeBackground(UInt16(3), UInt16(0), UInt16(0), UInt16(0)),
            PngExpandTransparency(UInt16(10))
        )
        let fourExpected: Array<Byte> = [0x3b]
        @Assert(four.row(), fourExpected)
    }

    @TestCase
    public func gammaCorrectsPackedGrayExceptTransparentSamples(): Unit {
        let tables = pngBuildGamma8BitTables(Int32(45455), Int32(220000), true)
        let table = tables.direct()
        let row = UInt8(0x1b)
        let composed = pngDoCompose(
            PngReadRowInfo(UInt32(4), UInt8(2), Grayscale),
            [row],
            composeBackground(UInt16(3), UInt16(0), UInt16(0), UInt16(0)),
            composeBackground(UInt16(3), UInt16(0), UInt16(0), UInt16(0)),
            PngExpandTransparency(UInt16(1)),
            tables
        )
        let expected: Array<Byte> = [
            composePackedOracle(row, UInt32(4), UInt8(2), UInt16(1), UInt16(3), table)
        ]
        @Assert(composed.row(), expected)
    }

    @TestCase
    public func composesEightBitGrayAndRgbColorKeysWithDirectGamma(): Unit {
        let tables = pngBuildGamma8BitTables(Int32(45455), Int32(220000), true)
        let direct = tables.direct()
        let background = composeBackground(
            UInt16(7), UInt16(9), UInt16(8), UInt16(7)
        )
        let gray = pngDoCompose(
            PngReadRowInfo(UInt32(3), UInt8(8), Grayscale),
            [10, 20, 30],
            background,
            background,
            PngExpandTransparency(UInt16(20)),
            tables
        )
        let grayExpected: Array<Byte> = [
            direct.value(UInt8(10)), UInt8(7), direct.value(UInt8(30))
        ]
        @Assert(gray.row(), grayExpected)

        let rgb = pngDoCompose(
            PngReadRowInfo(UInt32(2), UInt8(8), Truecolor),
            [1, 2, 3, 40, 50, 60],
            background,
            background,
            PngExpandTransparency(UInt16(1), UInt16(2), UInt16(3)),
            tables
        )
        let rgbExpected: Array<Byte> = [
            9, 8, 7,
            direct.value(UInt8(40)),
            direct.value(UInt8(50)),
            direct.value(UInt8(60))
        ]
        @Assert(rgb.row(), rgbExpected)
    }

    @TestCase
    public func composesSixteenBitColorKeysInNetworkOrder(): Unit {
        let tables = pngBuildGamma16BitTables(
            UInt8(0), Int32(45455), Int32(220000), true, false
        )
        let direct = tables.direct()
        let background = composeBackground(
            UInt16(0x1111), UInt16(0x2222), UInt16(0x3333), UInt16(0x4444)
        )
        let gray = pngDoCompose(
            PngReadRowInfo(UInt32(2), UInt8(16), Grayscale),
            compose16Bytes([0x1234, 0x5678]),
            background,
            background,
            PngExpandTransparency(UInt16(0x1234)),
            tables
        )
        @Assert(
            gray.row(),
            compose16Bytes([UInt16(0x1111), direct.value(UInt16(0x5678))])
        )

        let rgb = pngDoCompose(
            PngReadRowInfo(UInt32(2), UInt8(16), Truecolor),
            compose16Bytes([0x0102, 0x0304, 0x0506, 0x1112, 0x1314, 0x1516]),
            background,
            background,
            PngExpandTransparency(UInt16(0x0102), UInt16(0x0304), UInt16(0x0506)),
            tables
        )
        @Assert(
            rgb.row(),
            compose16Bytes([
                0x2222, 0x3333, 0x4444,
                direct.value(UInt16(0x1112)),
                direct.value(UInt16(0x1314)),
                direct.value(UInt16(0x1516))
            ])
        )
    }

    @TestCase
    public func composesEightBitAlphaAndPreservesAlphaBytes(): Unit {
        let background = composeBackground(
            UInt16(30), UInt16(20), UInt16(40), UInt16(60)
        )
        let ga = pngDoCompose(
            PngReadRowInfo(UInt32(3), UInt8(8), GrayscaleAlpha),
            [10, 0, 100, 128, 200, 255],
            background,
            PngExpandTransparency()
        )
        let gaExpected: Array<Byte> = [
            30, 0, compose8Oracle(UInt8(100), UInt8(128), UInt8(30)), 128,
            200, 255
        ]
        @Assert(ga.row(), gaExpected)

        let rgba = pngDoCompose(
            PngReadRowInfo(UInt32(3), UInt8(8), TruecolorAlpha),
            [10, 20, 30, 0, 100, 110, 120, 128, 200, 210, 220, 255],
            background,
            PngExpandTransparency()
        )
        let rgbaExpected: Array<Byte> = [
            20, 40, 60, 0,
            compose8Oracle(UInt8(100), UInt8(128), UInt8(20)),
            compose8Oracle(UInt8(110), UInt8(128), UInt8(40)),
            compose8Oracle(UInt8(120), UInt8(128), UInt8(60)), 128,
            200, 210, 220, 255
        ]
        @Assert(rgba.row(), rgbaExpected)
    }

    @TestCase
    public func composesSixteenBitAlphaAndPreservesNetworkOrder(): Unit {
        let background = composeBackground(
            UInt16(0x3000), UInt16(0x2000), UInt16(0x4000), UInt16(0x6000)
        )
        let ga = pngDoCompose(
            PngReadRowInfo(UInt32(3), UInt8(16), GrayscaleAlpha),
            compose16Bytes([0x1000, 0, 0x7000, 0x8000, 0x9000, 0xffff]),
            background,
            PngExpandTransparency()
        )
        @Assert(
            ga.row(),
            compose16Bytes([
                0x3000, 0,
                compose16Oracle(UInt16(0x7000), UInt16(0x8000), UInt16(0x3000)),
                0x8000,
                0x9000, 0xffff
            ])
        )

        let rgba = pngDoCompose(
            PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha),
            compose16Bytes([0x1000, 0x2000, 0x3000, 0x8000]),
            background,
            PngExpandTransparency()
        )
        @Assert(
            rgba.row(),
            compose16Bytes([
                compose16Oracle(UInt16(0x1000), UInt16(0x8000), UInt16(0x2000)),
                compose16Oracle(UInt16(0x2000), UInt16(0x8000), UInt16(0x4000)),
                compose16Oracle(UInt16(0x3000), UInt16(0x8000), UInt16(0x6000)),
                0x8000
            ])
        )
    }

    @TestCase
    public func composesAlphaThroughLinearGammaTables(): Unit {
        let tables8 = pngBuildGamma8BitTables(Int32(45455), Int32(220000), true)
        let background8 = composeBackground(
            UInt16(25), UInt16(35), UInt16(45), UInt16(55)
        )
        let linear8 = composeBackground(
            UInt16(65), UInt16(75), UInt16(85), UInt16(95)
        )
        let rgba8 = pngDoCompose(
            PngReadRowInfo(UInt32(3), UInt8(8), TruecolorAlpha),
            [10, 20, 30, 0, 100, 110, 120, 128, 200, 210, 220, 255],
            background8,
            linear8,
            PngExpandTransparency(),
            tables8
        )
        let direct8 = tables8.direct()
        let to8 = tables8.toLinear()
        let from8 = tables8.fromLinear()
        let rgba8Expected: Array<Byte> = [
            35, 45, 55, 0,
            from8.value(compose8Oracle(to8.value(UInt8(100)), UInt8(128), UInt8(75))),
            from8.value(compose8Oracle(to8.value(UInt8(110)), UInt8(128), UInt8(85))),
            from8.value(compose8Oracle(to8.value(UInt8(120)), UInt8(128), UInt8(95))),
            128,
            direct8.value(UInt8(200)), direct8.value(UInt8(210)),
            direct8.value(UInt8(220)), 255
        ]
        @Assert(rgba8.row(), rgba8Expected)

        let tables16 = pngBuildGamma16BitTables(
            UInt8(0), Int32(45455), Int32(220000), true, false
        )
        let background16 = composeBackground(
            UInt16(0x1111), UInt16(0x2222), UInt16(0x3333), UInt16(0x4444)
        )
        let linear16 = composeBackground(
            UInt16(0x5555), UInt16(0x6666), UInt16(0x7777), UInt16(0x8888)
        )
        let rgba16 = pngDoCompose(
            PngReadRowInfo(UInt32(1), UInt8(16), TruecolorAlpha),
            compose16Bytes([0x1000, 0x2000, 0x3000, 0x8000]),
            background16,
            linear16,
            PngExpandTransparency(),
            tables16
        )
        let to16 = tables16.toLinear()
        let from16 = tables16.fromLinear()
        @Assert(
            rgba16.row(),
            compose16Bytes([
                from16.value(compose16Oracle(
                    to16.value(UInt16(0x1000)), UInt16(0x8000), UInt16(0x6666)
                )),
                from16.value(compose16Oracle(
                    to16.value(UInt16(0x2000)), UInt16(0x8000), UInt16(0x7777)
                )),
                from16.value(compose16Oracle(
                    to16.value(UInt16(0x3000)), UInt16(0x8000), UInt16(0x8888)
                )),
                0x8000
            ])
        )
    }

    @TestCase
    public func validatesRowsAndReturnsOwnedNoOpResults(): Unit {
        try {
            pngDoCompose(
                PngReadRowInfo(UInt32(2), UInt8(8), Grayscale),
                [1],
                composeBackground(UInt16(0), UInt16(0), UInt16(0), UInt16(0)),
                PngExpandTransparency()
            )
            @Fail("compose should reject malformed row lengths")
        } catch (error: PngFormatException) {
            @Assert(error.kind, InvalidArgument)
        }

        let input: Array<Byte> = [1, 2]
        let noop = pngDoCompose(
            PngReadRowInfo(UInt32(2), UInt8(8), Indexed),
            input,
            composeBackground(UInt16(0), UInt16(0), UInt16(0), UInt16(0)),
            PngExpandTransparency()
        )
        input[0] = UInt8(99)
        let expected: Array<Byte> = [1, 2]
        @Assert(noop.row(), expected)
        let mutable = noop.row()
        mutable[1] = UInt8(88)
        @Assert(noop.row(), expected)
    }

    @TestCase
    public func initializesComposeBeforePostStripAndSuppressesGammaStage(): Unit {
        let transparentGray: Array<Byte> = [0, 20]
        let grayDecoded = composeDecoded(
            UInt8(3),
            UInt8(8),
            UInt8(0),
            [composeChunk(PNG_CHUNK_tRNS, transparentGray)],
            COMPOSE_GRAY8_ZLIB
        )
        let grayState = PngReadTransformState()
        @Assert(grayState.setBackgroundFixed(
            composeBackground(UInt16(7), UInt16(7), UInt16(7), UInt16(7)),
            BackgroundGammaScreen,
            false,
            PNG_FP_1
        ), true)
        let initialized = initializePngReadTransformations(grayState, grayDecoded)
        @Assert(initialized.stageCount(), Int64(2))
        @Assert(initialized.stage(0), ReadStageCompose)
        @Assert(initialized.stage(1), ReadStageStripAlphaAfterCompose)
        @Assert(initialized.hasStage(ReadStageGamma), false)
        @Assert(ReadStageCompose.ordinalValue(), Int64(20))
        @Assert(ReadStageStripAlphaAfterCompose.ordinalValue(), Int64(21))
        let gray = applyInitializedPngReadStages(
            initialized,
            PngReadRowInfo(grayDecoded.ihdr),
            grayDecoded.row(0)
        )
        let grayExpected: Array<Byte> = [10, 7, 30]
        @Assert(gray.row(), grayExpected)
    }

    @TestCase
    public func executesWholeImageRgbaComposeThenStripAlpha(): Unit {
        let decoded = composeDecoded(
            UInt8(3), UInt8(8), UInt8(6), Array<Array<Byte>>(), COMPOSE_RGBA8_ZLIB
        )
        let state = PngReadTransformState()
        @Assert(state.setBackgroundFixed(
            composeBackground(UInt16(0), UInt16(20), UInt16(40), UInt16(60)),
            BackgroundGammaScreen,
            false,
            PNG_FP_1
        ), true)
        let transformed = transformPngRowsInitialized(decoded, state)
        @Assert(transformed.info.colorType.toString(), "TRUECOLOR")
        @Assert(transformed.info.channels, UInt8(3))
        let expected: Array<Byte> = [
            20, 40, 60,
            compose8Oracle(UInt8(100), UInt8(128), UInt8(20)),
            compose8Oracle(UInt8(110), UInt8(128), UInt8(40)),
            compose8Oracle(UInt8(120), UInt8(128), UInt8(60)),
            200, 210, 220
        ]
        @Assert(transformed.row(0), expected)
    }
}
