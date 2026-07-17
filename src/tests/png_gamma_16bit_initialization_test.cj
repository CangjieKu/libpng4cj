package libpng4cj.tests

import libpng4cj.*

private let GAMMA16_GRAY_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x10, 0x32, 0x01, 0x00, 0x00, 0x5b, 0x00, 0x47
]

private let GAMMA16_RGBA_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private func joinGamma16InitBytes(
    left: Array<Byte>,
    right: Array<Byte>
): Array<Byte> {
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

private func makeGamma16InitChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinGamma16InitBytes(
        joinGamma16InitBytes(
            joinGamma16InitBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func makeGamma16InitIhdr(): Array<Byte> {
    let data = Array<Byte>(13, repeat: 0)
    data[3] = UInt8(1)
    data[7] = UInt8(1)
    data[8] = UInt8(16)
    data[9] = UInt8(0)
    makeGamma16InitChunk(PNG_CHUNK_IHDR, data)
}

private func gamma16InitializedDecoded(
    gamma: UInt32,
    significantGray: UInt8
): PngDecodedRows {
    var png = joinGamma16InitBytes(PNG_SIGNATURE, makeGamma16InitIhdr())
    if (gamma != UInt32(0)) {
        png = joinGamma16InitBytes(
            png,
            makeGamma16InitChunk(PNG_CHUNK_gAMA, writeUInt32Be(gamma))
        )
    }
    if (significantGray != UInt8(0)) {
        png = joinGamma16InitBytes(
            png,
            makeGamma16InitChunk(PNG_CHUNK_sBIT, [significantGray])
        )
    }
    png = joinGamma16InitBytes(
        png,
        makeGamma16InitChunk(PNG_CHUNK_IDAT, GAMMA16_GRAY_ZLIB)
    )
    png = joinGamma16InitBytes(
        png,
        makeGamma16InitChunk(PNG_CHUNK_IEND, [])
    )
    decodePngNonInterlaced(png)
}

private func gamma16RgbaInitializedDecoded(): PngDecodedRows {
    let data = Array<Byte>(13, repeat: 0)
    data[3] = UInt8(1)
    data[7] = UInt8(1)
    data[8] = UInt8(16)
    data[9] = UInt8(6)
    var png = joinGamma16InitBytes(
        PNG_SIGNATURE,
        makeGamma16InitChunk(PNG_CHUNK_IHDR, data)
    )
    png = joinGamma16InitBytes(
        png,
        makeGamma16InitChunk(
            PNG_CHUNK_gAMA,
            writeUInt32Be(UInt32(45455))
        )
    )
    png = joinGamma16InitBytes(
        png,
        makeGamma16InitChunk(PNG_CHUNK_sBIT, [8, 8, 8, 8])
    )
    png = joinGamma16InitBytes(
        png,
        makeGamma16InitChunk(PNG_CHUNK_IDAT, GAMMA16_RGBA_ZLIB)
    )
    png = joinGamma16InitBytes(
        png,
        makeGamma16InitChunk(PNG_CHUNK_IEND, [])
    )
    decodePngNonInterlaced(png)
}

private func gammaAwareGray16Oracle(
    red: UInt16,
    green: UInt16,
    blue: UInt16,
    transform: PngRgbToGrayTransform,
    tables: PngGamma16BitTables
): UInt16 {
    if (red == green && red == blue) {
        return tables.direct().value(red)
    }
    let toLinear = tables.toLinear()
    let linearRed = toLinear.value(red)
    let linearGreen = toLinear.value(green)
    let linearBlue = toLinear.value(blue)
    let weighted = UInt64(transform.redCoefficient) * UInt64(linearRed) +
        UInt64(transform.greenCoefficient) * UInt64(linearGreen) +
        UInt64(transform.blueCoefficient) * UInt64(linearBlue) + UInt64(16384)
    tables.fromLinear().value(UInt16(weighted >> 15))
}

private func gamma16CompressedSample(index: UInt32, shift: UInt8): UInt16 {
    let retainedBits = UInt32(8) - UInt32(shift)
    let segmentMask = (UInt32(1) << retainedBits) - UInt32(1)
    let high = index >> retainedBits
    let segment = index & segmentMask
    UInt16((high << UInt32(8)) | (segment << UInt32(shift)))
}

private func gamma16To8Oracle(
    compressedInput: UInt32,
    shift: UInt8,
    gammaValue: Int32
): UInt16 {
    let compressedMax =
        (UInt32(1) << (UInt32(16) - UInt32(shift))) - UInt32(1)
    var outputIndex = UInt32(0)
    while (outputIndex < UInt32(255)) {
        let output = UInt16(outputIndex * UInt32(257))
        let corrected = pngGamma16BitCorrect(
            UInt16(UInt32(output) + UInt32(128)),
            gammaValue
        )
        let bound = UInt32(
            (UInt64(corrected) * UInt64(compressedMax) + UInt64(32768)) /
            UInt64(65535) + UInt64(1)
        )
        if (compressedInput < bound) {
            return output
        }
        outputIndex += UInt32(1)
    }
    UInt16(65535)
}

@Test
public class PngGamma16BitInitializationTestSuite {
    @TestCase
    public func resolvesSignificantAndReductionShiftBounds(): Unit {
        @Assert(
            pngResolveGamma16BitShift(
                Truecolor,
                PngSignificantBits(0, 12, 10, 11, 16),
                false
            ),
            UInt8(4)
        )
        @Assert(
            pngResolveGamma16BitShift(
                Grayscale,
                PngSignificantBits(7, 0, 0, 0, 16),
                false
            ),
            UInt8(8)
        )
        @Assert(
            pngResolveGamma16BitShift(
                Grayscale,
                PngSignificantBits(0, 0, 0, 0, 0),
                true
            ),
            UInt8(5)
        )
        @Assert(
            pngResolveGamma16BitShift(
                Grayscale,
                PngSignificantBits(14, 0, 0, 0, 16),
                true
            ),
            UInt8(5)
        )
    }

    @TestCase
    public func exhaustivelyMatchesSixteenToEightBoundaryFill(): Unit {
        let shift = UInt8(5)
        let gamma = Int32(220000)
        let table = pngBuildGamma16To8Table(shift, gamma)
        let entryCount = UInt32(1) << (UInt32(16) - UInt32(shift))
        var index = UInt32(0)
        while (index < entryCount) {
            let value = table.value(gamma16CompressedSample(index, shift))
            @Assert(value, gamma16To8Oracle(index, shift, gamma))
            @Assert(UInt32(value) % UInt32(257), UInt32(0))
            index += UInt32(1)
        }
        @Assert(table.value(UInt16(0)), UInt16(0))
        @Assert(table.value(UInt16(65535)), UInt16(65535))
    }

    @TestCase
    public func buildsDirectAndReductionGroupsWithOwnedTables(): Unit {
        let direct = pngBuildGamma16BitTables(
            UInt8(8),
            Int32(100000),
            Int32(106000),
            false,
            false
        )
        @Assert(direct.built(), true)
        @Assert(direct.reductionTableBuilt(), false)
        @Assert(direct.linearTablesBuilt(), false)

        let reduction = pngBuildGamma16BitTables(
            UInt8(5),
            Int32(100000),
            Int32(106000),
            false,
            true
        )
        @Assert(reduction.built(), true)
        @Assert(reduction.reductionTableBuilt(), true)
        @Assert(reduction.shift(), UInt8(5))
        let mutable = reduction.direct().segment(0)
        mutable[0] = UInt16(999)
        @Assert(reduction.direct().value(UInt16(0)), UInt16(0))
    }

    @TestCase
    public func executesDirectAndReductionTablesBeforeScale(): Unit {
        let directState = PngReadTransformState()
        @Assert(
            directState.setGammaFixed(Int32(106000), Int32(100000)),
            true
        )
        let direct = initializePngReadTransformations(
            directState,
            gamma16InitializedDecoded(UInt32(45455), UInt8(12))
        )
        @Assert(direct.gamma8BitTablesBuilt(), false)
        @Assert(direct.gamma16BitTablesBuilt(), true)
        @Assert(direct.gamma16BitReductionTableBuilt(), false)
        @Assert(direct.gamma16BitShift(), UInt8(4))
        @Assert(direct.stageCount(), Int64(1))
        @Assert(direct.stage(0), ReadStageGamma)
        let directSource: Array<Byte> = [0x12, 0x34]
        let directRow = applyInitializedPngGammaStage(
            direct,
            PngReadRowInfo(UInt32(1), UInt8(16), Grayscale),
            directSource
        )
        let directValue = direct.gamma16BitTables().direct().value(
            UInt16(0x1234)
        )
        let directExpected: Array<Byte> = [
            UInt8(directValue >> UInt16(8)),
            UInt8(directValue & UInt16(0xff))
        ]
        @Assert(directRow.row(), directExpected)

        let reductionState = PngReadTransformState()
        @Assert(reductionState.setScale16(), true)
        @Assert(
            reductionState.setGammaFixed(Int32(106000), Int32(100000)),
            true
        )
        let reduction = initializePngReadTransformations(
            reductionState,
            gamma16InitializedDecoded(UInt32(0), UInt8(0))
        )
        @Assert(reduction.gamma16BitTablesBuilt(), true)
        @Assert(reduction.gamma16BitReductionTableBuilt(), true)
        @Assert(reduction.gamma16BitShift(), UInt8(5))
        @Assert(reduction.stageCount(), Int64(2))
        @Assert(reduction.stage(0), ReadStageGamma)
        @Assert(reduction.stage(1), ReadStageScale16To8)
        let reductionSource: Array<Byte> = [0x12, 0x34]
        let reduced = applyInitializedPngReadStages(
            reduction,
            PngReadRowInfo(UInt32(1), UInt8(16), Grayscale),
            reductionSource
        )
        let reducedValue = reduction.gamma16BitTables().direct().value(
            UInt16(0x1234)
        )
        let reducedExpected: Array<Byte> = [UInt8(reducedValue >> UInt16(8))]
        @Assert(reduced.row(), reducedExpected)

        let wholeState = PngReadTransformState()
        @Assert(wholeState.setScale16(), true)
        @Assert(
            wholeState.setGammaFixed(Int32(106000), Int32(100000)),
            true
        )
        let decoded = gamma16InitializedDecoded(UInt32(0), UInt8(0))
        let whole = transformPngRowsInitialized(decoded, wholeState)
        let source = decoded.row(0)
        let sourceValue = UInt16(
            (UInt16(source[0]) << UInt16(8)) | UInt16(source[1])
        )
        let expectedValue = pngBuildGamma16BitTables(
            UInt8(5),
            Int32(100000),
            Int32(106000),
            false,
            true
        ).direct().value(sourceValue)
        let wholeExpected: Array<Byte> = [UInt8(expectedValue >> UInt16(8))]
        @Assert(whole.row(0), wholeExpected)
    }

    @TestCase
    public func snapshotsOwnedLinearTablesForSixteenBitRgbToGray(): Unit {
        let decoded = gamma16InitializedDecoded(UInt32(45455), UInt8(8))
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(
            state.setRgbToGrayFixed(Convert, UInt32(21268), UInt32(71514)),
            true
        )
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.gamma16BitTablesBuilt(), true)
        @Assert(initialized.gamma16BitLinearTablesBuilt(), true)
        @Assert(initialized.gamma16BitReductionTableBuilt(), false)
        @Assert(initialized.gamma16BitShift(), UInt8(8))
        @Assert(initialized.stageCount(), Int64(1))
        @Assert(initialized.stage(0), ReadStageRgbToGray)

        let tables = initialized.gamma16BitTables()
        @Assert(
            tables.toLinear().value(UInt16(0x8080)),
            pngBuildGamma16BitTable(
                UInt8(8),
                pngReciprocalFixed(initialized.fileGamma())
            ).value(UInt16(0x8080))
        )
        let mutable = tables.fromLinear().segment(0)
        mutable[128] = UInt16(0)
        @Assert(
            initialized.gamma16BitTables().fromLinear().value(
                UInt16(0x8080)
            ) == UInt16(0),
            false
        )
    }

    @TestCase
    public func executesGammaAwareSixteenBitRgbToGrayRowsAndImage(): Unit {
        let decoded = gamma16RgbaInitializedDecoded()
        let state = PngReadTransformState()
        state.markIhdrRead(decoded.ihdr)
        @Assert(
            state.setRgbToGrayFixed(Convert, UInt32(21268), UInt32(71514)),
            true
        )
        @Assert(state.setGammaFixed(Int32(106000), Int32(100000)), true)
        let initialized = initializePngReadTransformations(state, decoded)
        @Assert(initialized.gamma16BitShift(), UInt8(8))
        let transform = initialized.rgbToGrayTransform()
        let tables = initialized.gamma16BitTables()
        let source: Array<Byte> = [
            0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
            0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01, 0x02
        ]
        let unequal = gammaAwareGray16Oracle(
            UInt16(0x1234),
            UInt16(0x5678),
            UInt16(0x9abc),
            transform,
            tables
        )
        let equal = tables.direct().value(UInt16(0x8080))
        let expected: Array<Byte> = [
            UInt8(unequal >> UInt16(8)),
            UInt8(unequal & UInt16(0xff)),
            0xde,
            0xf0,
            UInt8(equal >> UInt16(8)),
            UInt8(equal & UInt16(0xff)),
            0x01,
            0x02
        ]
        let transformed = applyInitializedPngRgbToGrayStage(
            initialized,
            PngReadRowInfo(UInt32(2), UInt8(16), TruecolorAlpha),
            source
        )
        @Assert(transformed.row(), expected)
        @Assert(transformed.info.colorType.toString(), "GRAYSCALE_ALPHA")
        @Assert(transformed.info.rowBytes, UInt64(8))
        @Assert(transformed.hadNonGrayPixels, true)

        source[0] = UInt8(0)
        @Assert(transformed.row(), expected)
        let mutable = transformed.row()
        mutable[0] = UInt8(0)
        @Assert(transformed.row(), expected)

        let decodedSource = decoded.row(0)
        let decodedRed = UInt16(
            (UInt16(decodedSource[0]) << UInt16(8)) | UInt16(decodedSource[1])
        )
        let decodedGreen = UInt16(
            (UInt16(decodedSource[2]) << UInt16(8)) | UInt16(decodedSource[3])
        )
        let decodedBlue = UInt16(
            (UInt16(decodedSource[4]) << UInt16(8)) | UInt16(decodedSource[5])
        )
        let wholeGray = gammaAwareGray16Oracle(
            decodedRed, decodedGreen, decodedBlue, transform, tables
        )
        let wholeExpected: Array<Byte> = [
            UInt8(wholeGray >> UInt16(8)),
            UInt8(wholeGray & UInt16(0xff)),
            decodedSource[6],
            decodedSource[7]
        ]
        let wholeState = PngReadTransformState()
        wholeState.markIhdrRead(decoded.ihdr)
        @Assert(
            wholeState.setRgbToGrayFixed(
                Convert, UInt32(21268), UInt32(71514)
            ),
            true
        )
        @Assert(
            wholeState.setGammaFixed(Int32(106000), Int32(100000)),
            true
        )
        let whole = transformPngRowsInitialized(decoded, wholeState)
        @Assert(whole.row(0), wholeExpected)
        @Assert(whole.info.bitDepth, UInt8(16))
        @Assert(whole.info.colorType.toString(), "GRAYSCALE_ALPHA")
        @Assert(whole.hadNonGrayPixels, true)
    }
}
