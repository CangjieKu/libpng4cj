package libpng4cj

private let PNG_QUANTIZE_RED_BITS_STATE: Int64 = 5
private let PNG_QUANTIZE_GREEN_BITS_STATE: Int64 = 5
private let PNG_QUANTIZE_BLUE_BITS_STATE: Int64 = 5
private let PNG_QUANTIZE_LOOKUP_SIZE_STATE: Int64 = Int64(1) << 15

func pngBuildQuantizePaletteLookup(
    palette: Array<Byte>,
    numPalette: Int64
): Array<Byte> {
    let lookup = Array<Byte>(PNG_QUANTIZE_LOOKUP_SIZE_STATE, repeat: 0)
    let distance = Array<Byte>(PNG_QUANTIZE_LOOKUP_SIZE_STATE, repeat: 0xff)
    let numRed = Int64(1) << PNG_QUANTIZE_RED_BITS_STATE
    let numGreen = Int64(1) << PNG_QUANTIZE_GREEN_BITS_STATE
    let numBlue = Int64(1) << PNG_QUANTIZE_BLUE_BITS_STATE

    var paletteIndex: Int64 = 0
    while (paletteIndex < numPalette) {
        let paletteOffset = paletteIndex * 3
        let red = Int64(palette[paletteOffset]) >>
            (8 - PNG_QUANTIZE_RED_BITS_STATE)
        let green = Int64(palette[paletteOffset + 1]) >>
            (8 - PNG_QUANTIZE_GREEN_BITS_STATE)
        let blue = Int64(palette[paletteOffset + 2]) >>
            (8 - PNG_QUANTIZE_BLUE_BITS_STATE)

        var redCell: Int64 = 0
        while (redCell < numRed) {
            let redDistance = if (redCell > red) {
                redCell - red
            } else {
                red - redCell
            }
            let redIndex = redCell <<
                (PNG_QUANTIZE_BLUE_BITS_STATE + PNG_QUANTIZE_GREEN_BITS_STATE)

            var greenCell: Int64 = 0
            while (greenCell < numGreen) {
                let greenDistance = if (greenCell > green) {
                    greenCell - green
                } else {
                    green - greenCell
                }
                let distanceTotal = redDistance + greenDistance
                let distanceMaximum = if (redDistance > greenDistance) {
                    redDistance
                } else {
                    greenDistance
                }
                let greenIndex = redIndex |
                    (greenCell << PNG_QUANTIZE_BLUE_BITS_STATE)

                var blueCell: Int64 = 0
                while (blueCell < numBlue) {
                    let distanceIndex = greenIndex | blueCell
                    let blueDistance = if (blueCell > blue) {
                        blueCell - blue
                    } else {
                        blue - blueCell
                    }
                    let distanceMax = if (distanceMaximum > blueDistance) {
                        distanceMaximum
                    } else {
                        blueDistance
                    }
                    let cellDistance = distanceMax + distanceTotal + blueDistance

                    if (cellDistance < Int64(distance[distanceIndex])) {
                        distance[distanceIndex] = UInt8(cellDistance)
                        lookup[distanceIndex] = UInt8(paletteIndex)
                    }
                    blueCell += 1
                }
                greenCell += 1
            }
            redCell += 1
        }
        paletteIndex += 1
    }
    lookup
}
