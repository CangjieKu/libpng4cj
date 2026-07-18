package libpng4cj

public class PngWriteUserTransformContext {
    public let rowNumber: UInt32
    public let interlaceMethod: PngInterlaceMethod

    public init(rowNumber: UInt32, interlaceMethod: PngInterlaceMethod) {
        this.rowNumber = rowNumber
        this.interlaceMethod = interlaceMethod
    }
}

public class PngWriteUserTransformResult {
    public let info: PngReadRowInfo
    private let ownedRow: Array<Byte>

    public init(info: PngReadRowInfo, row: Array<Byte>) {
        this.info = info
        ownedRow = row.clone()
    }

    public func row(): Array<Byte> {
        ownedRow.clone()
    }
}

private func pngIdentityWriteUserTransform(
    context: PngWriteUserTransformContext,
    info: PngReadRowInfo,
    row: Array<Byte>
): PngWriteUserTransformResult {
    PngWriteUserTransformResult(info, row)
}

class PngWriteUserTransformRegistration {
    private var enabledValue: Bool = false
    private var callbackValue: (
        PngWriteUserTransformContext,
        PngReadRowInfo,
        Array<Byte>
    ) -> PngWriteUserTransformResult = pngIdentityWriteUserTransform

    func enableIdentity(): Unit {
        enabledValue = true
        callbackValue = pngIdentityWriteUserTransform
    }

    func setCallback(
        callback: (
            PngWriteUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngWriteUserTransformResult
    ): Unit {
        enabledValue = true
        callbackValue = callback
    }

    func enabled(): Bool {
        enabledValue
    }

    func callback(): (
        PngWriteUserTransformContext,
        PngReadRowInfo,
        Array<Byte>
    ) -> PngWriteUserTransformResult {
        callbackValue
    }
}

func applyPngWriteUserTransform(
    initialization: PngWriteTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    context: PngWriteUserTransformContext
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.writeUserTransformEnabled()) {
        return PngReadTransformRow(rowInfo, row)
    }

    let callback = initialization.writeUserTransform()
    let result = callback(context, rowInfo, row.clone())
    let outputInfo = result.info
    let output = result.row()
    if (outputInfo.width != rowInfo.width ||
        outputInfo.bitDepth != rowInfo.bitDepth ||
        outputInfo.colorType != rowInfo.colorType ||
        outputInfo.channels != rowInfo.channels ||
        outputInfo.rowBytes != rowInfo.rowBytes) {
        throw PngFormatException(
            InvalidArgument,
            Int64(context.rowNumber),
            "PNG write user transform changed the configured source row shape"
        )
    }
    validatePngTransformRowLength(outputInfo, output)
    PngReadTransformRow(outputInfo, output)
}
