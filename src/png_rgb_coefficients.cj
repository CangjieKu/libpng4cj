package libpng4cj

import std.math.floor

private class PngResolvedRgbCoefficients {
    let success: Bool
    let red: UInt16
    let green: UInt16
    let blue: UInt16

    init(success: Bool, red: UInt16, green: UInt16, blue: UInt16) {
        this.success = success
        this.red = red
        this.green = green
        this.blue = blue
    }
}

private func pngDefaultRgbCoefficients(): PngResolvedRgbCoefficients {
    PngResolvedRgbCoefficients(
        false,
        UInt16(6968),
        UInt16(23434),
        UInt16(2366)
    )
}

private func pngChromaticitiesInRange(value: PngChromaticities): Bool {
    let limit = Int32(110000)
    value.redX >= Int32(0) && value.redX <= limit &&
        value.redY >= Int32(0) && value.redY <= limit - value.redX &&
        value.greenX >= Int32(0) && value.greenX <= limit &&
        value.greenY >= Int32(0) && value.greenY <= limit - value.greenX &&
        value.blueX >= Int32(0) && value.blueX <= limit &&
        value.blueY >= Int32(0) && value.blueY <= limit - value.blueX &&
        value.whiteX >= Int32(0) && value.whiteX <= limit &&
        value.whiteY >= Int32(5) && value.whiteY <= limit - value.whiteX
}

private func pngRoundRgbCoefficient(value: Float64): Int64 {
    Int64(floor(value * 32768.0 + 0.5))
}

// Floating-arithmetic translation of the frozen cHRM-to-XYZ coefficient path.
private func pngRgbCoefficientsFromChromaticities(
    value: PngChromaticities
): PngResolvedRgbCoefficients {
    if (!pngChromaticitiesInRange(value)) {
        return pngDefaultRgbCoefficients()
    }

    let scale = 100000.0
    let whiteX = Float64(value.whiteX) / scale
    let whiteY = Float64(value.whiteY) / scale
    let redX = Float64(value.redX) / scale
    let redY = Float64(value.redY) / scale
    let greenX = Float64(value.greenX) / scale
    let greenY = Float64(value.greenY) / scale
    let blueX = Float64(value.blueX) / scale
    let blueY = Float64(value.blueY) / scale
    let redZ = 1.0 - redX - redY
    let greenZ = 1.0 - greenX - greenY
    let blueZ = 1.0 - blueX - blueY
    let referenceX = whiteX / whiteY
    let referenceZ = (1.0 - whiteX - whiteY) / whiteY

    let determinant = redX * (greenY * blueZ - blueY * greenZ) -
        greenX * (redY * blueZ - blueY * redZ) +
        blueX * (redY * greenZ - greenY * redZ)
    if (determinant == 0.0) {
        return pngDefaultRgbCoefficients()
    }

    let redScale = (
        referenceX * (greenY * blueZ - blueY * greenZ) -
        greenX * (blueZ - blueY * referenceZ) +
        blueX * (greenZ - greenY * referenceZ)
    ) / determinant
    let greenScale = (
        redX * (blueZ - blueY * referenceZ) -
        referenceX * (redY * blueZ - blueY * redZ) +
        blueX * (redY * referenceZ - redZ)
    ) / determinant
    let blueScale = (
        redX * (greenY * referenceZ - greenZ) -
        greenX * (redY * referenceZ - redZ) +
        referenceX * (redY * greenZ - greenY * redZ)
    ) / determinant
    let redContribution = redY * redScale
    let greenContribution = greenY * greenScale
    let blueContribution = blueY * blueScale
    let total = redContribution + greenContribution + blueContribution
    if (redScale.isNaN() || redScale.isInf() ||
        greenScale.isNaN() || greenScale.isInf() ||
        blueScale.isNaN() || blueScale.isInf() ||
        redScale < 0.0 || greenScale < 0.0 || blueScale <= 0.0 ||
        redContribution < 0.0 || greenContribution < 0.0 ||
        blueContribution < 0.0 || total <= 0.0) {
        return pngDefaultRgbCoefficients()
    }

    var red = pngRoundRgbCoefficient(redContribution / total)
    var green = pngRoundRgbCoefficient(greenContribution / total)
    var blue = pngRoundRgbCoefficient(blueContribution / total)
    let sum = red + green + blue
    if (sum > Int64(32768)) {
        if (green >= red && green >= blue) {
            green -= 1
        } else if (red >= green && red >= blue) {
            red -= 1
        } else {
            blue -= 1
        }
    } else if (sum < Int64(32768)) {
        if (green >= red && green >= blue) {
            green += 1
        } else if (red >= green && red >= blue) {
            red += 1
        } else {
            blue += 1
        }
    }

    if (red < 0 || red > Int64(32768) ||
        green < 0 || green > Int64(32768) ||
        blue < 0 || blue > Int64(32768) ||
        red + green + blue != Int64(32768)) {
        return pngDefaultRgbCoefficients()
    }
    PngResolvedRgbCoefficients(
        true,
        UInt16(red),
        UInt16(green),
        UInt16(blue)
    )
}

func pngResolveRgbToGrayTransform(
    configured: PngRgbToGrayTransform,
    metadata: PngReadMetadata
): PngRgbToGrayTransform {
    if (configured.customCoefficientsAccepted || metadata.hasSrgb ||
        !metadata.hasChromaticities) {
        return PngRgbToGrayTransform(configured)
    }
    let resolved = pngRgbCoefficientsFromChromaticities(
        metadata.chromaticities
    )
    if (!resolved.success) {
        return PngRgbToGrayTransform(configured)
    }
    PngRgbToGrayTransform(
        configured.policy,
        resolved.red,
        resolved.green,
        resolved.blue
    )
}
