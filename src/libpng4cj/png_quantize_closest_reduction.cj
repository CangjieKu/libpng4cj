package libpng4cj

import std.collection.ArrayList

private class PngQuantizeDistancePair {
    let left: Int64
    let right: Int64

    init(left: Int64, right: Int64) {
        this.left = left
        this.right = right
    }
}

private func pngQuantizeDistanceBuckets(): Array<ArrayList<PngQuantizeDistancePair>> {
    let buckets = Array<ArrayList<PngQuantizeDistancePair>>(
        Int64(769),
        repeat: ArrayList<PngQuantizeDistancePair>()
    )
    var index: Int64 = 0
    while (index < buckets.size) {
        buckets[index] = ArrayList<PngQuantizeDistancePair>()
        index += 1
    }
    buckets
}

func pngReduceQuantizePaletteWithoutHistogram(
    palette: Array<Byte>,
    quantizeIndex: Array<Byte>,
    numPalette: Int64,
    maximumColors: Int64,
    fullQuantize: Bool
): Unit {
    let indexToPalette = Array<Byte>(numPalette, repeat: 0)
    let paletteToIndex = Array<Byte>(numPalette, repeat: 0)
    var index: Int64 = 0
    while (index < numPalette) {
        indexToPalette[index] = UInt8(index)
        paletteToIndex[index] = UInt8(index)
        index += 1
    }

    var currentPaletteCount = numPalette
    var maximumDistance: Int64 = 96
    while (currentPaletteCount > maximumColors) {
        let buckets = pngQuantizeDistanceBuckets()
        var hasPairs = false
        var leftPosition: Int64 = 0
        while (leftPosition < currentPaletteCount - 1) {
            var rightPosition = leftPosition + 1
            while (rightPosition < currentPaletteCount) {
                let distance = pngQuantizeColorDistance(
                    palette,
                    leftPosition,
                    rightPosition
                )
                if (distance <= maximumDistance) {
                    buckets[distance].add(
                        PngQuantizeDistancePair(
                            Int64(paletteToIndex[leftPosition]),
                            Int64(paletteToIndex[rightPosition])
                        )
                    )
                    hasPairs = true
                }
                rightPosition += 1
            }
            leftPosition += 1
        }

        if (hasPairs) {
            var distance: Int64 = 0
            while (
                distance <= maximumDistance &&
                currentPaletteCount > maximumColors
            ) {
                let bucket = buckets[distance]
                if (bucket.size > 0) {
                    var pairIndex = bucket.size - 1
                    while (
                        pairIndex >= 0 &&
                        currentPaletteCount > maximumColors
                    ) {
                        let pair = bucket[pairIndex]
                        if (
                            Int64(indexToPalette[pair.left]) < currentPaletteCount &&
                            Int64(indexToPalette[pair.right]) < currentPaletteCount
                        ) {
                            let eliminatedIdentity = if (
                                currentPaletteCount % 2 == 1
                            ) {
                                pair.left
                            } else {
                                pair.right
                            }
                            let survivingIdentity = if (
                                currentPaletteCount % 2 == 1
                            ) {
                                pair.right
                            } else {
                                pair.left
                            }
                            let eliminatedPosition = Int64(
                                indexToPalette[eliminatedIdentity]
                            )
                            let survivingPosition = Int64(
                                indexToPalette[survivingIdentity]
                            )

                            currentPaletteCount -= 1
                            pngCopyQuantizeColor(
                                palette,
                                eliminatedPosition,
                                currentPaletteCount
                            )

                            if (!fullQuantize) {
                                var originalIndex: Int64 = 0
                                while (originalIndex < numPalette) {
                                    if (
                                        Int64(quantizeIndex[originalIndex]) ==
                                        eliminatedPosition
                                    ) {
                                        quantizeIndex[originalIndex] = UInt8(
                                            survivingPosition
                                        )
                                    }
                                    if (
                                        Int64(quantizeIndex[originalIndex]) ==
                                        currentPaletteCount
                                    ) {
                                        quantizeIndex[originalIndex] = UInt8(
                                            eliminatedPosition
                                        )
                                    }
                                    originalIndex += 1
                                }
                            }

                            let movedIdentity = Int64(
                                paletteToIndex[currentPaletteCount]
                            )
                            indexToPalette[movedIdentity] = UInt8(
                                eliminatedPosition
                            )
                            paletteToIndex[eliminatedPosition] = UInt8(
                                movedIdentity
                            )
                            indexToPalette[eliminatedIdentity] = UInt8(
                                currentPaletteCount
                            )
                            paletteToIndex[currentPaletteCount] = UInt8(
                                eliminatedIdentity
                            )
                        }
                        pairIndex -= 1
                    }
                }
                distance += 1
            }
        }
        maximumDistance += 96
    }
}
