package libpng4cj_consumer

import libpng4cj.*

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
    println("libpng4cj ${LIBPNG4CJ_VERSION} / libpng ${LIBPNG_UPSTREAM_VERSION}")
    0
}
