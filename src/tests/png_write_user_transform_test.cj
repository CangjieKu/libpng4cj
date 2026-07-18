package libpng4cj.tests

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import libpng4cj.*

private class WriteUserTransformRecorder {
    private let contextsValue = ArrayList<PngWriteUserTransformContext>()

    func record(context: PngWriteUserTransformContext): Unit {
        contextsValue.add(context)
    }

    func size(): Int64 {
        contextsValue.size
    }

    func context(index: Int64): PngWriteUserTransformContext {
        contextsValue[index]
    }
}

private func expectWriteUserTransformFailure(
    action: () -> Unit,
    expected: PngErrorKind
): Unit {
    try {
        action()
        @Fail("expected PNG write user transform operation to fail")
    } catch (error: PngFormatException) {
        @Assert(error.kind, expected)
    }
}

@Test
public class PngWriteUserTransformTestSuite {
    @TestCase
    public func runsBeforeDefaultTransformsAndPreservesOwnership(): Unit {
        let recorder = WriteUserTransformRecorder()
        let state = PngWriteTransformState(UInt8(8), Truecolor)
        @Assert(state.setBgr(), true)
        let callback: (
            PngWriteUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngWriteUserTransformResult = {
            context, info, row =>
                recorder.record(context)
                row[0] = UInt8(9)
                let result = PngWriteUserTransformResult(info, row)
                row[0] = UInt8(77)
                result
        }
        @Assert(state.setWriteUserTransform(callback), true)
        let source: Array<Array<Byte>> = [[UInt8(1), UInt8(2), UInt8(3)]]
        let session = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Truecolor, Array<Byte>(),
            PngWriteMetadata(), state, WriteFilterNone, Int32(6), PngWriteLimits()
        )
        let initialized = session.initializedTransforms()
        @Assert(initialized.stageCount(), Int64(2))
        @Assert(initialized.stage(0), WriteStageUserTransform)
        @Assert(initialized.stage(1), WriteStageBgr)
        @Assert(initialized.hasStage(WriteStageUserTransform), true)

        let decoded = decodePngNonInterlaced(session.write(source))
        @Assert(decoded.rows(), [[UInt8(3), UInt8(2), UInt8(9)]])
        @Assert(source, [[UInt8(1), UInt8(2), UInt8(3)]])
        @Assert(recorder.size(), Int64(1))
        @Assert(recorder.context(0).rowNumber, UInt32(0))
        @Assert(recorder.context(0).interlaceMethod.encodedValue(), UInt8(0))
    }

    @TestCase
    public func enablesAndReplacesCallbacksAfterInitialization(): Unit {
        let identityState = PngWriteTransformState(UInt8(8), Grayscale)
        @Assert(identityState.setWriteUserTransform(), true)
        let identitySession = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale, Array<Byte>(),
            PngWriteMetadata(), identityState,
            WriteFilterNone, Int32(6), PngWriteLimits()
        )
        @Assert(identitySession.initializedTransforms().stage(0), WriteStageUserTransform)
        @Assert(
            decodePngNonInterlaced(identitySession.write([[UInt8(7)]])).rows(),
            [[UInt8(7)]]
        )

        let state = PngWriteTransformState(UInt8(8), Grayscale)
        let session = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale, Array<Byte>(),
            PngWriteMetadata(), state, WriteFilterNone, Int32(6), PngWriteLimits()
        )
        @Assert(session.initializedTransforms().stageCount(), Int64(0))
        let callback: (
            PngWriteUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngWriteUserTransformResult = {
            _, info, row =>
                row[0] = UInt8(44)
                PngWriteUserTransformResult(info, row)
        }
        @Assert(state.setBgr(), false)
        @Assert(state.lastApplicationError(), InvalidAfterWriteInitialization)
        @Assert(state.setWriteUserTransform(callback), true)
        @Assert(state.lastApplicationError(), NoWriteTransformApplicationError)
        @Assert(session.initializedTransforms().stage(0), WriteStageUserTransform)
        @Assert(decodePngNonInterlaced(session.write([[UInt8(1)]])).rows(), [[UInt8(44)]])

        let replacingState = PngWriteTransformState(UInt8(8), Grayscale)
        let second: (
            PngWriteUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngWriteUserTransformResult = {
            _, info, row =>
                row[0] = UInt8(20)
                PngWriteUserTransformResult(info, row)
        }
        let first: (
            PngWriteUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngWriteUserTransformResult = {
            _, info, row =>
                replacingState.setWriteUserTransform(second)
                row[0] = UInt8(10)
                PngWriteUserTransformResult(info, row)
        }
        @Assert(replacingState.setWriteUserTransform(first), true)
        let replaced = encodePngPacked(
            UInt32(1), UInt32(2), UInt8(8), Grayscale,
            [[UInt8(1)], [UInt8(2)]], Array<Byte>(), PngWriteMetadata(),
            replacingState, WriteFilterNone, Int32(6), PngWriteLimits()
        )
        @Assert(decodePngNonInterlaced(replaced).rows(), [[UInt8(10)], [UInt8(20)]])
    }

    @TestCase
    public func callsAdam7OncePerCompleteImageRow(): Unit {
        let recorder = WriteUserTransformRecorder()
        let state = PngWriteTransformState(UInt8(8), Grayscale)
        let callback: (
            PngWriteUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngWriteUserTransformResult = {
            context, info, row =>
                recorder.record(context)
                var index: Int64 = Int64(0)
                while (index < row.size) {
                    row[index] = UInt8(UInt16(row[index]) + UInt16(context.rowNumber))
                    index += Int64(1)
                }
                PngWriteUserTransformResult(info, row)
        }
        @Assert(state.setWriteUserTransform(callback), true)
        let source = ArrayList<Array<Byte>>()
        let expected = ArrayList<Array<Byte>>()
        var rowNumber: UInt32 = UInt32(0)
        while (rowNumber < UInt32(8)) {
            source.add(Array<Byte>(Int64(8), repeat: UInt8(1)))
            expected.add(Array<Byte>(Int64(8), repeat: UInt8(UInt16(1) + UInt16(rowNumber))))
            rowNumber += UInt32(1)
        }
        let encoded = encodePngPackedAdam7(
            UInt32(8), UInt32(8), UInt8(8), Grayscale, source.toArray(),
            Array<Byte>(), PngWriteMetadata(), state,
            WriteFilterAdaptive, Int32(6), PngWriteLimits()
        )
        @Assert(decodePng(encoded).rows(), expected.toArray())
        @Assert(recorder.size(), Int64(8))
        var index: Int64 = Int64(0)
        while (index < recorder.size()) {
            @Assert(recorder.context(index).rowNumber, UInt32(index))
            @Assert(recorder.context(index).interlaceMethod, Adam7)
            index += Int64(1)
        }
    }

    @TestCase
    public func streamsAdam7UserTransformOnceDuringRowIntake(): Unit {
        let recorder = WriteUserTransformRecorder()
        let state = PngWriteTransformState(UInt8(8), Grayscale)
        let callback: (
            PngWriteUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngWriteUserTransformResult = {
            context, info, row =>
                recorder.record(context)
                row[0] = UInt8(UInt16(row[0]) + UInt16(context.rowNumber))
                PngWriteUserTransformResult(info, row)
        }
        @Assert(state.setWriteUserTransform(callback), true)
        let session = PngRowWriteSession(
            UInt32(1), UInt32(8), UInt8(8), Grayscale, Adam7,
            Array<Byte>(), PngWriteMetadata(), state, WriteFilterNone,
            Int32(6), PngWriteLimits()
        )
        let bytes = ArrayList<Byte>()
        let sink = PngWriteSink()
        sink.setWriteCallback({ _, emitted =>
            for (value in emitted) {
                bytes.add(value)
            }
        })
        session.startTo(sink)
        var rowNumber: UInt32 = UInt32(0)
        while (rowNumber < UInt32(8)) {
            session.writeRow([UInt8(1)])
            @Assert(recorder.size(), Int64(rowNumber) + Int64(1))
            rowNumber += UInt32(1)
        }
        session.finishTo()
        let decoded = decodePng(bytes.toArray()).rows()
        var index: Int64 = Int64(0)
        while (index < Int64(8)) {
            @Assert(decoded[index], [UInt8(UInt16(1) + UInt16(index))])
            @Assert(recorder.context(index).rowNumber, UInt32(index))
            @Assert(recorder.context(index).interlaceMethod, Adam7)
            index += Int64(1)
        }
    }

    @TestCase
    public func rejectsMalformedCallbackResultsAndMarksFailure(): Unit {
        let state = PngWriteTransformState(UInt8(8), Grayscale)
        let callback: (
            PngWriteUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngWriteUserTransformResult = {
            _, info, _ =>
                PngWriteUserTransformResult(
                    PngReadRowInfo(info.width, info.bitDepth, info.colorType, UInt8(2)),
                    [UInt8(1), UInt8(2)]
                )
        }
        @Assert(state.setWriteUserTransform(callback), true)
        let session = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale, Array<Byte>(),
            PngWriteMetadata(), state, WriteFilterNone, Int32(6), PngWriteLimits()
        )
        expectWriteUserTransformFailure({ => session.write([[UInt8(1)]]); () }, InvalidArgument)
        @Assert(session.state(), WriteFailed)
    }

    @TestCase
    public func marksFailureWhenCallbackThrows(): Unit {
        let state = PngWriteTransformState(UInt8(8), Grayscale)
        let callback: (
            PngWriteUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngWriteUserTransformResult = {
            _, _, _ => throw PngFormatException(InvalidData, -1, "callback failure")
        }
        @Assert(state.setWriteUserTransform(callback), true)
        let session = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale, Array<Byte>(),
            PngWriteMetadata(), state, WriteFilterNone, Int32(6), PngWriteLimits()
        )
        expectWriteUserTransformFailure({ => session.write([[UInt8(1)]]); () }, InvalidData)
        @Assert(session.state(), WriteFailed)
    }

    @TestCase
    public func rejectsReentrantCloseAndMarksFailure(): Unit {
        let state = PngWriteTransformState(UInt8(8), Grayscale)
        let session = PngWriteSession(
            UInt32(1), UInt32(1), UInt8(8), Grayscale, Array<Byte>(),
            PngWriteMetadata(), state, WriteFilterNone, Int32(6), PngWriteLimits()
        )
        let callback: (
            PngWriteUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngWriteUserTransformResult = {
            _, info, row =>
                session.close()
                PngWriteUserTransformResult(info, row)
        }
        @Assert(state.setWriteUserTransform(callback), true)
        expectWriteUserTransformFailure({ => session.write([[UInt8(1)]]); () }, InvalidArgument)
        @Assert(session.state(), WriteFailed)
    }
}
