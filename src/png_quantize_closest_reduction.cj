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

public class PngQuantizeAllocationFaultPlan {
    private let successfulPairAllocationsBeforeFailureValue: Int64
    private let failureCountValue: Int64
    private let maximumRetriesValue: Int64

    public init(
        successfulPairAllocationsBeforeFailure: Int64,
        failureCount: Int64,
        maximumRetries: Int64
    ) {
        if (successfulPairAllocationsBeforeFailure < 0) {
            throw PngFormatException(
                InvalidArgument,
                successfulPairAllocationsBeforeFailure,
                "PNG quantize allocation fault offset must be nonnegative"
            )
        }
        if (failureCount < 0) {
            throw PngFormatException(
                InvalidArgument,
                failureCount,
                "PNG quantize allocation fault count must be nonnegative"
            )
        }
        if (maximumRetries < 0) {
            throw PngFormatException(
                InvalidArgument,
                maximumRetries,
                "PNG quantize allocation retry limit must be nonnegative"
            )
        }
        successfulPairAllocationsBeforeFailureValue =
            successfulPairAllocationsBeforeFailure
        failureCountValue = failureCount
        maximumRetriesValue = maximumRetries
    }

    public func successfulPairAllocationsBeforeFailure(): Int64 {
        successfulPairAllocationsBeforeFailureValue
    }

    public func failureCount(): Int64 {
        failureCountValue
    }

    public func maximumRetries(): Int64 {
        maximumRetriesValue
    }
}

class PngQuantizeAllocationFacts {
    let warningCount: Int64
    let retryCount: Int64

    init(warningCount: Int64, retryCount: Int64) {
        this.warningCount = warningCount
        this.retryCount = retryCount
    }
}

private class PngQuantizeAllocationRuntime {
    private let failAfterValue: Int64
    private let maximumRetriesValue: Int64
    private var remainingFailuresValue: Int64
    private var attemptAllocationsValue: Int64 = 0
    private var warningCountValue: Int64 = 0
    private var retryCountValue: Int64 = 0

    init(plan: PngQuantizeAllocationFaultPlan) {
        failAfterValue = plan.successfulPairAllocationsBeforeFailure()
        remainingFailuresValue = plan.failureCount()
        maximumRetriesValue = plan.maximumRetries()
    }

    func beginAttempt(): Unit {
        attemptAllocationsValue = 0
    }

    func allowPairAllocation(): Bool {
        if (remainingFailuresValue > 0 &&
            attemptAllocationsValue >= failAfterValue) {
            remainingFailuresValue -= 1
            warningCountValue += 1
            return false
        }
        attemptAllocationsValue += 1
        true
    }

    func retryOrThrow(): Unit {
        if (retryCountValue >= maximumRetriesValue) {
            throw PngFormatException(
                AllocationFailure,
                warningCountValue,
                "PNG quantize pair allocation retry limit was exhausted"
            )
        }
        retryCountValue += 1
    }

    func facts(): PngQuantizeAllocationFacts {
        PngQuantizeAllocationFacts(warningCountValue, retryCountValue)
    }
}

func pngNoQuantizeAllocationFaultPlan(): PngQuantizeAllocationFaultPlan {
    PngQuantizeAllocationFaultPlan(Int64(0), Int64(0), Int64(0))
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
    fullQuantize: Bool,
    allocationFaultPlan: PngQuantizeAllocationFaultPlan
): PngQuantizeAllocationFacts {
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
    let allocation = PngQuantizeAllocationRuntime(allocationFaultPlan)
    while (currentPaletteCount > maximumColors) {
        allocation.beginAttempt()
        let buckets = pngQuantizeDistanceBuckets()
        var hasPairs = false
        var allocationFailed = false
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
                    if (!allocation.allowPairAllocation()) {
                        allocationFailed = true
                        break
                    }
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
            if (allocationFailed) {
                break
            }
            leftPosition += 1
        }

        if (allocationFailed) {
            allocation.retryOrThrow()
            maximumDistance += 96
            continue
        }

        if (hasPairs) {
            let scanMaximumDistance = if (maximumDistance < buckets.size) {
                maximumDistance
            } else {
                buckets.size - 1
            }
            var distance: Int64 = 0
            while (
                distance <= scanMaximumDistance &&
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
    allocation.facts()
}
