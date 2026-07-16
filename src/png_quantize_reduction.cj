package libpng4cj

class PngPreparedQuantizeState {
    let palette: Array<Byte>
    let paletteCount: Int64
    let index: Array<Byte>
    let paletteLookup: Array<Byte>

    init(
        palette: Array<Byte>,
        paletteCount: Int64,
        index: Array<Byte>,
        paletteLookup: Array<Byte>
    ) {
        this.palette = palette
        this.paletteCount = paletteCount
        this.index = index
        this.paletteLookup = paletteLookup
    }
}

private func pngQuantizeIdentityIndex(): Array<Byte> {
    let identity = Array<Byte>(Int64(256), repeat: 0)
    var index: Int64 = 0
    while (index < identity.size) {
        identity[index] = UInt8(index)
        index += 1
    }
    identity
}

func pngQuantizeColorDistance(
    palette: Array<Byte>,
    left: Int64,
    right: Int64
): Int64 {
    let leftOffset = left * 3
    let rightOffset = right * 3
    var distance: Int64 = 0
    var component: Int64 = 0
    while (component < 3) {
        let leftValue = Int64(palette[leftOffset + component])
        let rightValue = Int64(palette[rightOffset + component])
        distance += if (leftValue > rightValue) {
            leftValue - rightValue
        } else {
            rightValue - leftValue
        }
        component += 1
    }
    distance
}

func pngCopyQuantizeColor(
    palette: Array<Byte>,
    destination: Int64,
    source: Int64
): Unit {
    let destinationOffset = destination * 3
    let sourceOffset = source * 3
    palette[destinationOffset] = palette[sourceOffset]
    palette[destinationOffset + 1] = palette[sourceOffset + 1]
    palette[destinationOffset + 2] = palette[sourceOffset + 2]
}

private func pngSwapQuantizeColors(
    palette: Array<Byte>,
    left: Int64,
    right: Int64
): Unit {
    let leftOffset = left * 3
    let rightOffset = right * 3
    var component: Int64 = 0
    while (component < 3) {
        let temporary = palette[rightOffset + component]
        palette[rightOffset + component] = palette[leftOffset + component]
        palette[leftOffset + component] = temporary
        component += 1
    }
}

private func pngQuantizeHistogramSort(
    histogram: Array<UInt16>,
    numPalette: Int64,
    maximumColors: Int64
): Array<Byte> {
    let sorted = Array<Byte>(numPalette, repeat: 0)
    var index: Int64 = 0
    while (index < numPalette) {
        sorted[index] = UInt8(index)
        index += 1
    }

    var end = numPalette - 1
    while (end >= maximumColors) {
        var done = true
        var current: Int64 = 0
        while (current < end) {
            let left = Int64(sorted[current])
            let right = Int64(sorted[current + 1])
            if (histogram[left] < histogram[right]) {
                let temporary = sorted[current]
                sorted[current] = sorted[current + 1]
                sorted[current + 1] = temporary
                done = false
            }
            current += 1
        }
        if (done) {
            break
        }
        end -= 1
    }
    sorted
}

private func pngReduceFullQuantizePalette(
    palette: Array<Byte>,
    sorted: Array<Byte>,
    numPalette: Int64,
    maximumColors: Int64
): Unit {
    var source = numPalette
    var destination: Int64 = 0
    while (destination < maximumColors) {
        if (Int64(sorted[destination]) >= maximumColors) {
            do {
                source -= 1
            } while (Int64(sorted[source]) >= maximumColors)
            pngCopyQuantizeColor(palette, destination, source)
        }
        destination += 1
    }
}

private func pngReduceNonFullQuantizePalette(
    palette: Array<Byte>,
    quantizeIndex: Array<Byte>,
    sorted: Array<Byte>,
    numPalette: Int64,
    maximumColors: Int64
): Unit {
    var source = numPalette
    var destination: Int64 = 0
    while (destination < maximumColors) {
        if (Int64(sorted[destination]) >= maximumColors) {
            do {
                source -= 1
            } while (Int64(sorted[source]) >= maximumColors)
            pngSwapQuantizeColors(palette, source, destination)
            quantizeIndex[source] = UInt8(destination)
            quantizeIndex[destination] = UInt8(source)
        }
        destination += 1
    }

    var originalIndex: Int64 = 0
    while (originalIndex < numPalette) {
        if (Int64(quantizeIndex[originalIndex]) >= maximumColors) {
            let discardedIndex = Int64(quantizeIndex[originalIndex])
            var minimumDistance = pngQuantizeColorDistance(
                palette,
                discardedIndex,
                0
            )
            var minimumIndex: Int64 = 0
            var retainedIndex: Int64 = 1
            while (retainedIndex < maximumColors) {
                let distance = pngQuantizeColorDistance(
                    palette,
                    discardedIndex,
                    retainedIndex
                )
                if (distance < minimumDistance) {
                    minimumDistance = distance
                    minimumIndex = retainedIndex
                }
                retainedIndex += 1
            }
            quantizeIndex[originalIndex] = UInt8(minimumIndex)
        }
        originalIndex += 1
    }
}

private func pngQuantizePalettePrefix(
    palette: Array<Byte>,
    paletteCount: Int64
): Array<Byte> {
    let output = Array<Byte>(paletteCount * 3, repeat: 0)
    var index: Int64 = 0
    while (index < output.size) {
        output[index] = palette[index]
        index += 1
    }
    output
}

func pngPrepareQuantizeState(
    palette: Array<Byte>,
    numPalette: Int64,
    maximumColors: Int64,
    histogram: Array<UInt16>,
    fullQuantize: Bool
): PngPreparedQuantizeState {
    let ownedPalette = palette.clone()
    let quantizeIndex = if (fullQuantize) {
        Array<Byte>()
    } else {
        pngQuantizeIdentityIndex()
    }

    let paletteCount = if (numPalette > maximumColors) {
        if (histogram.size > 0) {
            let sorted = pngQuantizeHistogramSort(
                histogram,
                numPalette,
                maximumColors
            )
            if (fullQuantize) {
                pngReduceFullQuantizePalette(
                    ownedPalette,
                    sorted,
                    numPalette,
                    maximumColors
                )
            } else {
                pngReduceNonFullQuantizePalette(
                    ownedPalette,
                    quantizeIndex,
                    sorted,
                    numPalette,
                    maximumColors
                )
            }
        } else {
            pngReduceQuantizePaletteWithoutHistogram(
                ownedPalette,
                quantizeIndex,
                numPalette,
                maximumColors,
                fullQuantize
            )
        }
        maximumColors
    } else {
        numPalette
    }

    let retainedPalette = pngQuantizePalettePrefix(ownedPalette, paletteCount)
    let paletteLookup = if (fullQuantize) {
        pngBuildQuantizePaletteLookup(retainedPalette, paletteCount)
    } else {
        Array<Byte>()
    }
    PngPreparedQuantizeState(
        retainedPalette,
        paletteCount,
        quantizeIndex,
        paletteLookup
    )
}
