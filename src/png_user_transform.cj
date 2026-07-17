package libpng4cj

public class PngReadUserTransformContext {
    public let rowNumber: UInt32
    public let passNumber: UInt8

    public init(rowNumber: UInt32, passNumber: UInt8) {
        this.rowNumber = rowNumber
        this.passNumber = passNumber
    }
}

public class PngReadUserTransformResult {
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

func pngIdentityReadUserTransform(
    context: PngReadUserTransformContext,
    info: PngReadRowInfo,
    row: Array<Byte>
): PngReadUserTransformResult {
    PngReadUserTransformResult(info, row)
}

class PngReadUserTransformRegistration {
    private var enabledValue: Bool = false
    private var depthValue: UInt8 = UInt8(0)
    private var channelsValue: UInt8 = UInt8(0)
    private var callbackValue: (
        PngReadUserTransformContext,
        PngReadRowInfo,
        Array<Byte>
    ) -> PngReadUserTransformResult = pngIdentityReadUserTransform

    func enableIdentity(): Unit {
        enabledValue = true
        callbackValue = pngIdentityReadUserTransform
    }

    func setCallback(
        callback: (
            PngReadUserTransformContext,
            PngReadRowInfo,
            Array<Byte>
        ) -> PngReadUserTransformResult
    ): Unit {
        enabledValue = true
        callbackValue = callback
    }

    func setInfo(depth: UInt8, channels: UInt8): Unit {
        depthValue = depth
        channelsValue = channels
    }

    func enabled(): Bool {
        enabledValue
    }

    func depth(): UInt8 {
        depthValue
    }

    func channels(): UInt8 {
        channelsValue
    }

    func callback(): (
        PngReadUserTransformContext,
        PngReadRowInfo,
        Array<Byte>
    ) -> PngReadUserTransformResult {
        callbackValue
    }
}

public func applyInitializedPngReadUserTransformStage(
    initialization: PngReadTransformInitialization,
    rowInfo: PngReadRowInfo,
    row: Array<Byte>,
    context: PngReadUserTransformContext
): PngReadTransformRow {
    validatePngTransformRowLength(rowInfo, row)
    if (!initialization.readUserTransformEnabled()) {
        return PngReadTransformRow(rowInfo, row)
    }

    let callback = initialization.readUserTransform()
    let callbackResult = callback(context, rowInfo, row.clone())
    let callbackInfo = callbackResult.info
    let finalBitDepth = if (initialization.userTransformDepth() != UInt8(0)) {
        initialization.userTransformDepth()
    } else {
        callbackInfo.bitDepth
    }
    let finalChannels = if (initialization.userTransformChannels() != UInt8(0)) {
        initialization.userTransformChannels()
    } else {
        callbackInfo.channels
    }
    let finalInfo = PngReadRowInfo(
        callbackInfo.width,
        finalBitDepth,
        callbackInfo.colorType,
        finalChannels
    )
    let output = callbackResult.row()
    validatePngTransformRowLength(finalInfo, output)
    PngReadTransformRow(finalInfo, output)
}
