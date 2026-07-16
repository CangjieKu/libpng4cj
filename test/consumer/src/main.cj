package libpng4cj_consumer

import libpng4cj.*

private let CONSUMER_RGBA_ZLIB: Array<Byte> = [
    0x78, 0x9c, 0x63, 0x60, 0x64, 0x62, 0x66, 0x61,
    0x65, 0x63, 0xe7, 0x00, 0x00, 0x00, 0x81, 0x00, 0x25
]

private func joinConsumerBytes(
    left: Array<Byte>,
    right: Array<Byte>
): Array<Byte> {
    let out = Array<Byte>(left.size + right.size, repeat: 0)
    var index: Int64 = 0
    while (index < left.size) {
        out[index] = left[index]
        index += 1
    }
    var rightIndex: Int64 = 0
    while (rightIndex < right.size) {
        out[left.size + rightIndex] = right[rightIndex]
        rightIndex += 1
    }
    out
}

private func makeConsumerChunk(
    chunkType: Array<Byte>,
    data: Array<Byte>
): Array<Byte> {
    joinConsumerBytes(
        joinConsumerBytes(
            joinConsumerBytes(writeUInt32Be(UInt32(data.size)), chunkType),
            data
        ),
        writeUInt32Be(pngChunkCrc32(chunkType, data))
    )
}

private func consumerGammaPng(): Array<Byte> {
    let ihdr = Array<Byte>(13, repeat: 0)
    let width = writeUInt32Be(UInt32(2))
    let height = writeUInt32Be(UInt32(1))
    var index: Int64 = 0
    while (index < 4) {
        ihdr[index] = width[index]
        ihdr[index + 4] = height[index]
        index += 1
    }
    ihdr[8] = UInt8(8)
    ihdr[9] = UInt8(6)

    var png = joinConsumerBytes(PNG_SIGNATURE, makeConsumerChunk(PNG_CHUNK_IHDR, ihdr))
    png = joinConsumerBytes(
        png,
        makeConsumerChunk(PNG_CHUNK_gAMA, writeUInt32Be(UInt32(45455)))
    )
    png = joinConsumerBytes(png, makeConsumerChunk(PNG_CHUNK_IDAT, CONSUMER_RGBA_ZLIB))
    joinConsumerBytes(png, makeConsumerChunk(PNG_CHUNK_IEND, []))
}

main(): Int64 {
    if (!isPngSignature(PNG_SIGNATURE)) {
        println("libpng4cj signature check failed")
        return 1
    }
    let gamma = pngInitGammaValues(PngFileGammaSources(
        Int32(45455),
        Int32(0),
        Int32(0),
        Int32(0)
    ))
    if (gamma.fileGamma != Int32(45455) ||
        gamma.screenGamma != Int32(219998) ||
        gamma.correctionRequired) {
        println("libpng4cj gamma initialization check failed")
        return 1
    }
    let gammaState = PngReadTransformState()
    if (!gammaState.setGammaFixed(PNG_DEFAULT_SRGB, PNG_DEFAULT_SRGB) ||
        gammaState.screenGamma() != PNG_GAMMA_SRGB ||
        gammaState.fileGamma() != PNG_GAMMA_SRGB_INVERSE) {
        println("libpng4cj fixed gamma setter check failed")
        return 1
    }
    let floatingGammaState = PngReadTransformState()
    if (!floatingGammaState.setGamma(2.2, 0.45455) ||
        floatingGammaState.screenGamma() != PNG_GAMMA_SRGB ||
        floatingGammaState.fileGamma() != PNG_GAMMA_SRGB_INVERSE) {
        println("libpng4cj floating gamma setter check failed")
        return 1
    }
    let initializedGammaState = PngReadTransformState()
    if (!initializedGammaState.setGammaFixed(Int32(106000), Int32(100000))) {
        println("libpng4cj initialized gamma state setup failed")
        return 1
    }
    let initializedGamma = initializePngReadTransformations(
        initializedGammaState,
        decodePngNonInterlaced(consumerGammaPng())
    )
    if (!initializedGamma.gammaConfigured() ||
        initializedGamma.chunkGamma() != Int32(45455) ||
        initializedGamma.fileGamma() != Int32(100000) ||
        initializedGamma.screenGamma() != Int32(106000) ||
        !initializedGamma.gammaCorrectionRequired()) {
        println("libpng4cj state-driven gamma initialization check failed")
        return 1
    }
    println("libpng4cj ${LIBPNG4CJ_VERSION} / libpng ${LIBPNG_UPSTREAM_VERSION}")
    0
}
