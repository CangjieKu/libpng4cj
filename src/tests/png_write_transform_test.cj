package libpng4cj.tests

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private func writeTransformPalette(entries: Int64): Array<Byte> {
    let palette = ArrayList<Byte>()
    var index: Int64 = Int64(0)
    while (index < entries) {
        palette.add(UInt8(index * Int64(17)))
        palette.add(UInt8(index * Int64(11)))
        palette.add(UInt8(index * Int64(7)))
        index += Int64(1)
    }
    palette.toArray()
}

private func expectWriteTransformFailure(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected PNG write transform operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

@Test
public class PngWriteTransformTestSuite {
    @TestCase
    public func freezesCopyOwnedStateAndCanonicalStageOrder(): Unit {
        let state = PngWriteTransformState(UInt8(16), TruecolorAlpha)
        @Assert(state.setInvertMono(), true)
        @Assert(state.setBgr(), true)
        @Assert(state.setInvertAlpha(), true)
        @Assert(state.setSwapAlpha(), true)
        @Assert(state.setShift(PngSignificantBits(
            UInt8(0), UInt8(8), UInt8(8), UInt8(8), UInt8(8)
        )), true)
        @Assert(state.setByteSwap(), true)
        let writer = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(16), TruecolorAlpha, Array<Byte>(),
            PngWriteMetadata(), state, WriteFilterNone, Int32(6), PngWriteLimits()
        )
        let initialized = writer.initializedTransforms()
        @Assert(initialized.stageCount(), Int64(6))
        @Assert(initialized.stage(0), WriteStageByteSwap)
        @Assert(initialized.stage(1), WriteStageShift)
        @Assert(initialized.stage(2), WriteStageSwapAlpha)
        @Assert(initialized.stage(3), WriteStageInvertAlpha)
        @Assert(initialized.stage(4), WriteStageBgr)
        @Assert(initialized.stage(5), WriteStageInvertMono)
        @Assert(state.initialized(), true)
        @Assert(state.setBgr(), false)
        @Assert(
            state.lastApplicationError(),
            InvalidAfterWriteInitialization
        )
        @Assert(initialized.shiftSignificantBits().red, UInt8(8))

        let invalid = PngWriteTransformState(UInt8(8), Grayscale)
        @Assert(invalid.setByteSwap(), false)
        @Assert(invalid.lastApplicationError(), InvalidWriteTransformTarget)
        let unchanged = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale, Array<Byte>(),
            PngWriteMetadata(), invalid, WriteFilterNone, Int32(6), PngWriteLimits()
        )
        @Assert(unchanged.initializedTransforms().stageCount(), Int64(0))
    }

    @TestCase
    public func packsOneTwoAndFourBitRowsBeforeBothWriteModes(): Unit {
        let depths: Array<UInt8> = [UInt8(1), UInt8(2), UInt8(4)]
        let sources: Array<Array<Array<Byte>>> = [
            [[UInt8(0), UInt8(1), UInt8(0), UInt8(1)],
             [UInt8(1), UInt8(0), UInt8(1), UInt8(0)]],
            [[UInt8(0), UInt8(1), UInt8(2), UInt8(3)],
             [UInt8(3), UInt8(2), UInt8(1), UInt8(0)]],
            [[UInt8(0), UInt8(1), UInt8(2), UInt8(3)],
             [UInt8(3), UInt8(2), UInt8(1), UInt8(0)]]
        ]
        let expected: Array<Array<Array<Byte>>> = [
            [[UInt8(0x50)], [UInt8(0xa0)]],
            [[UInt8(0x1b)], [UInt8(0xe4)]],
            [[UInt8(0x01), UInt8(0x23)], [UInt8(0x32), UInt8(0x10)]]
        ]
        var index: Int64 = Int64(0)
        while (index < depths.size) {
            let depth = depths[index]
            let palette = writeTransformPalette(Int64(UInt32(1) << UInt32(depth)))
            let state = PngWriteTransformState(depth, Indexed)
            @Assert(state.setPackSwap(), true)
            @Assert(state.setPacking(), true)
            let encoded = encodePngPacked(
                UInt32(4), UInt32(2), depth, Indexed, sources[index], palette,
                PngWriteMetadata(), state, WriteFilterNone, Int32(6), PngWriteLimits()
            )
            @Assert(decodePngNonInterlaced(encoded).rows(), expected[index])

            let adam7State = PngWriteTransformState(depth, Indexed)
            @Assert(adam7State.setPacking(), true)
            let adam7 = encodePngPackedAdam7(
                UInt32(4), UInt32(2), depth, Indexed, sources[index], palette,
                PngWriteMetadata(), adam7State, WriteFilterUp, Int32(6), PngWriteLimits()
            )
            @Assert(decodePng(adam7).rows(), expected[index])
            index += Int64(1)
        }
    }

    @TestCase
    public func appliesPackSwapShiftAndInvertMonoInFrozenOrder(): Unit {
        let packSwap = PngWriteTransformState(UInt8(2), Grayscale)
        @Assert(packSwap.setPackSwap(), true)
        let swapped = encodePngPacked(
            UInt32(4), UInt32(1), UInt8(2), Grayscale,
            [[UInt8(0x1b)]], Array<Byte>(), PngWriteMetadata(), packSwap,
            WriteFilterNone, Int32(6), PngWriteLimits()
        )
        @Assert(decodePngNonInterlaced(swapped).rows(), [[UInt8(0xe4)]])

        let adam7PackSwap = PngWriteTransformState(UInt8(2), Grayscale)
        @Assert(adam7PackSwap.setPackSwap(), true)
        let adam7Source: Array<Array<Byte>> = [
            [UInt8(0xe4), UInt8(0x1b)], [UInt8(0x1b), UInt8(0xe4)],
            [UInt8(0xe4), UInt8(0x1b)], [UInt8(0x1b), UInt8(0xe4)],
            [UInt8(0xe4), UInt8(0x1b)], [UInt8(0x1b), UInt8(0xe4)],
            [UInt8(0xe4), UInt8(0x1b)], [UInt8(0x1b), UInt8(0xe4)]
        ]
        let adam7Expected: Array<Array<Byte>> = [
            [UInt8(0x1b), UInt8(0xe4)], [UInt8(0xe4), UInt8(0x1b)],
            [UInt8(0x1b), UInt8(0xe4)], [UInt8(0xe4), UInt8(0x1b)],
            [UInt8(0x1b), UInt8(0xe4)], [UInt8(0xe4), UInt8(0x1b)],
            [UInt8(0x1b), UInt8(0xe4)], [UInt8(0xe4), UInt8(0x1b)]
        ]
        let adam7Swapped = encodePngPackedAdam7(
            UInt32(8), UInt32(8), UInt8(2), Grayscale, adam7Source,
            Array<Byte>(), PngWriteMetadata(), adam7PackSwap,
            WriteFilterNone, Int32(6), PngWriteLimits()
        )
        @Assert(decodePng(adam7Swapped).rows(), adam7Expected)

        let shifted = PngWriteTransformState(UInt8(4), Grayscale)
        @Assert(shifted.setInvertMono(), true)
        @Assert(shifted.setShift(PngSignificantBits(
            UInt8(3), UInt8(0), UInt8(0), UInt8(0), UInt8(0)
        )), true)
        let encoded = encodePngPacked(
            UInt32(2), UInt32(1), UInt8(4), Grayscale,
            [[UInt8(0x71)]], Array<Byte>(), PngWriteMetadata(), shifted,
            WriteFilterNone, Int32(6), PngWriteLimits()
        )
        @Assert(decodePngNonInterlaced(encoded).rows(), [[UInt8(0x0d)]])
    }

    @TestCase
    public func composesByteShiftAlphaAndBgrWithNetworkOutput(): Unit {
        let state = PngWriteTransformState(UInt8(16), TruecolorAlpha)
        @Assert(state.setBgr(), true)
        @Assert(state.setInvertAlpha(), true)
        @Assert(state.setSwapAlpha(), true)
        @Assert(state.setShift(PngSignificantBits(
            UInt8(0), UInt8(8), UInt8(8), UInt8(8), UInt8(8)
        )), true)
        @Assert(state.setByteSwap(), true)
        let source: Array<Array<Byte>> = [[
            UInt8(0x10), UInt8(0x00),
            UInt8(0x20), UInt8(0x00),
            UInt8(0x30), UInt8(0x00),
            UInt8(0x40), UInt8(0x00)
        ]]
        let encoded = encodePngPacked(
            UInt32(1), UInt32(1), UInt8(16), TruecolorAlpha, source,
            Array<Byte>(), PngWriteMetadata(), state,
            WriteFilterNone, Int32(6), PngWriteLimits()
        )
        let expected: Array<Array<Byte>> = [[
            UInt8(0x40), UInt8(0x40),
            UInt8(0x30), UInt8(0x30),
            UInt8(0x20), UInt8(0x20),
            UInt8(0xef), UInt8(0xef)
        ]]
        @Assert(decodePngNonInterlaced(encoded).rows(), expected)
        @Assert(source[0][0], UInt8(0x10))
    }

    @TestCase
    public func swapsAndInvertsEightBitGrayAlphaInWriteOrder(): Unit {
        let state = PngWriteTransformState(UInt8(8), GrayscaleAlpha)
        @Assert(state.setInvertMono(), true)
        @Assert(state.setInvertAlpha(), true)
        @Assert(state.setSwapAlpha(), true)
        let encoded = encodePngPacked(
            UInt32(1), UInt32(1), UInt8(8), GrayscaleAlpha,
            [[UInt8(0x20), UInt8(0x10)]],
            Array<Byte>(), PngWriteMetadata(), state,
            WriteFilterNone, Int32(6), PngWriteLimits()
        )
        @Assert(
            decodePngNonInterlaced(encoded).rows(),
            [[UInt8(0xef), UInt8(0xdf)]]
        )
    }

    @TestCase
    public func stripsFillerBeforeColorTransformsAndPreservesSource(): Unit {
        let state = PngWriteTransformState(UInt8(8), Truecolor)
        @Assert(state.setBgr(), true)
        @Assert(state.setStripFiller(WriteFillerBefore), true)
        let source: Array<Array<Byte>> = [[
            UInt8(9), UInt8(3), UInt8(2), UInt8(1),
            UInt8(8), UInt8(6), UInt8(5), UInt8(4)
        ]]
        let encoded = encodePngPacked(
            UInt32(2), UInt32(1), UInt8(8), Truecolor, source,
            Array<Byte>(), PngWriteMetadata(), state,
            WriteFilterNone, Int32(6), PngWriteLimits()
        )
        let expected: Array<Array<Byte>> = [[
            UInt8(1), UInt8(2), UInt8(3),
            UInt8(4), UInt8(5), UInt8(6)
        ]]
        @Assert(decodePngNonInterlaced(encoded).rows(), expected)
        @Assert(source[0][0], UInt8(9))
        @Assert(source[0].size, Int64(8))
    }

    @TestCase
    public func enforcesSourceShapeTransformedLimitAndFailedState(): Unit {
        let state = PngWriteTransformState(UInt8(8), Truecolor)
        @Assert(state.setStripFiller(WriteFillerAfter), true)
        let malformed = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Truecolor, Array<Byte>(),
            PngWriteMetadata(), state, WriteFilterNone, Int32(6), PngWriteLimits()
        )
        expectWriteTransformFailure({ => malformed.write([[UInt8(1), UInt8(2), UInt8(3)]]); () }, InvalidArgument)
        @Assert(malformed.state(), WriteFailed)
        @Assert(malformed.initializedTransforms().stage(0), WriteStageStripFiller)

        let limitedState = PngWriteTransformState(UInt8(8), Truecolor)
        @Assert(limitedState.setStripFiller(WriteFillerAfter), true)
        expectWriteTransformFailure({ =>
            encodePngPacked(
                UInt32(1), UInt32(1), UInt8(8), Truecolor,
                [[UInt8(1), UInt8(2), UInt8(3), UInt8(4)]],
                Array<Byte>(), PngWriteMetadata(), limitedState,
                WriteFilterNone, Int32(6),
                PngWriteLimits(
                    UInt64(2), UInt64(4096), UInt64(4096),
                    UInt64(4096), UInt64(4096), UInt64(4096), UInt32(64)
                )
            ); ()
        }, DecodeLimitExceeded)
    }
}
