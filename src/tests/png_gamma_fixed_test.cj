package libpng4cj.tests

import libpng4cj.*

@Test
public class PngGammaFixedTestSuite {
    @TestCase
    public func multipliesDividesAndRoundsLikeFrozenDefault(): Unit {
        let identity = pngMulDivFixed(Int32(100000), Int32(45455), Int32(45455))
        @Assert(identity.success, true)
        @Assert(identity.value, Int32(100000))

        let positiveHalf = pngMulDivFixed(Int32(3), Int32(1), Int32(2))
        @Assert(positiveHalf.success, true)
        @Assert(positiveHalf.value, Int32(2))

        let negativeHalf = pngMulDivFixed(Int32(-3), Int32(1), Int32(2))
        @Assert(negativeHalf.success, true)
        @Assert(negativeHalf.value, Int32(-1))
    }

    @TestCase
    public func reportsZeroDivisorAndSignedOverflow(): Unit {
        let dividedByZero = pngMulDivFixed(Int32(1), Int32(1), Int32(0))
        @Assert(dividedByZero.success, false)

        let positiveOverflow = pngMulDivFixed(Int32.Max, Int32.Max, Int32(1))
        @Assert(positiveOverflow.success, false)

        let negativeOverflow = pngMulDivFixed(Int32.Min, Int32(-1), Int32(1))
        @Assert(negativeOverflow.success, false)
    }

    @TestCase
    public func preservesZeroProductSuccess(): Unit {
        let zeroValue = pngMulDivFixed(Int32(0), Int32.Max, Int32(1))
        @Assert(zeroValue.success, true)
        @Assert(zeroValue.value, Int32(0))

        let zeroMultiplier = pngMulDivFixed(Int32.Max, Int32(0), Int32(1))
        @Assert(zeroMultiplier.success, true)
        @Assert(zeroMultiplier.value, Int32(0))
    }

    @TestCase
    public func usesStrictFrozenGammaSignificanceBoundaries(): Unit {
        @Assert(pngGammaSignificant(Int32(94999)), true)
        @Assert(pngGammaSignificant(Int32(95000)), false)
        @Assert(pngGammaSignificant(Int32(100000)), false)
        @Assert(pngGammaSignificant(Int32(105000)), false)
        @Assert(pngGammaSignificant(Int32(105001)), true)
    }

    @TestCase
    public func appliesThresholdAndForcesCorrectionOnOverflow(): Unit {
        @Assert(pngGammaThreshold(Int32(50000), Int32(200000)), false)
        @Assert(pngGammaThreshold(Int32(45455), Int32(220000)), false)
        @Assert(pngGammaThreshold(Int32(100000), Int32(106000)), true)
        @Assert(pngGammaThreshold(Int32(0), Int32(100000)), true)
        @Assert(pngGammaThreshold(Int32.Max, Int32.Max), true)
    }

    @TestCase
    public func calculatesFixedReciprocalAndFailureFallback(): Unit {
        @Assert(pngReciprocalFixed(Int32(200000)), Int32(50000))
        @Assert(pngReciprocalFixed(Int32(45455)), Int32(219998))
        @Assert(pngReciprocalFixed(Int32(0)), Int32(0))
        @Assert(pngReciprocalFixed(Int32(1)), Int32(0))
    }

    @TestCase
    public func resolvesExplicitFileGammaBeforeEveryFallback(): Unit {
        let sources = PngFileGammaSources(
            Int32(70000),
            Int32(80000),
            Int32(90000),
            Int32(200000)
        )
        @Assert(pngResolveFileGamma(sources), Int32(70000))
    }

    @TestCase
    public func resolvesChunkThenDefaultGammaInFrozenOrder(): Unit {
        let chunk = PngFileGammaSources(
            Int32(0),
            Int32(80000),
            Int32(90000),
            Int32(200000)
        )
        @Assert(pngResolveFileGamma(chunk), Int32(80000))

        let fallback = PngFileGammaSources(
            Int32(0),
            Int32(0),
            Int32(90000),
            Int32(200000)
        )
        @Assert(pngResolveFileGamma(fallback), Int32(90000))
    }

    @TestCase
    public func resolvesScreenReciprocalAndAllZeroState(): Unit {
        let screen = PngFileGammaSources(
            Int32(0),
            Int32(0),
            Int32(0),
            Int32(200000)
        )
        @Assert(pngResolveFileGamma(screen), Int32(50000))

        let zero = PngFileGammaSources(
            Int32(0),
            Int32(0),
            Int32(0),
            Int32(0)
        )
        @Assert(pngResolveFileGamma(zero), Int32(0))

        let overflow = PngFileGammaSources(
            Int32(0),
            Int32(0),
            Int32(0),
            Int32(1)
        )
        @Assert(pngResolveFileGamma(overflow), Int32(0))
    }

    @TestCase
    public func preservesSignedNonzeroValuesAndInputState(): Unit {
        let sources = PngFileGammaSources(
            Int32(-1),
            Int32(80000),
            Int32(90000),
            Int32(200000)
        )
        @Assert(pngResolveFileGamma(sources), Int32(-1))
        @Assert(sources.fileGamma, Int32(-1))
        @Assert(sources.chunkGamma, Int32(80000))
        @Assert(sources.defaultGamma, Int32(90000))
        @Assert(sources.screenGamma, Int32(200000))
    }

    @TestCase
    public func initializesPositiveFileAndScreenWithThresholdDecision(): Unit {
        let insignificant = PngFileGammaSources(
            Int32(50000),
            Int32(0),
            Int32(0),
            Int32(200000)
        )
        let unchanged = pngInitGammaValues(insignificant)
        @Assert(unchanged.fileGamma, Int32(50000))
        @Assert(unchanged.screenGamma, Int32(200000))
        @Assert(unchanged.correctionRequired, false)

        let significant = PngFileGammaSources(
            Int32(100000),
            Int32(0),
            Int32(0),
            Int32(106000)
        )
        @Assert(pngInitGammaValues(significant).correctionRequired, true)
    }

    @TestCase
    public func initializesMissingOrNonpositiveScreenFromFileReciprocal(): Unit {
        let missing = pngInitGammaValues(PngFileGammaSources(
            Int32(45455),
            Int32(0),
            Int32(0),
            Int32(0)
        ))
        @Assert(missing.fileGamma, Int32(45455))
        @Assert(missing.screenGamma, Int32(219998))
        @Assert(missing.correctionRequired, false)

        let nonpositive = pngInitGammaValues(PngFileGammaSources(
            Int32(200000),
            Int32(0),
            Int32(0),
            Int32(-1)
        ))
        @Assert(nonpositive.fileGamma, Int32(200000))
        @Assert(nonpositive.screenGamma, Int32(50000))
        @Assert(nonpositive.correctionRequired, false)
    }

    @TestCase
    public func initializesNonpositiveResolvedFileAsIdentityGamma(): Unit {
        let negative = pngInitGammaValues(PngFileGammaSources(
            Int32(-1),
            Int32(80000),
            Int32(90000),
            Int32(200000)
        ))
        @Assert(negative.fileGamma, PNG_FP_1)
        @Assert(negative.screenGamma, PNG_FP_1)
        @Assert(negative.correctionRequired, false)

        let reciprocalFailure = pngInitGammaValues(PngFileGammaSources(
            Int32(0),
            Int32(0),
            Int32(0),
            Int32(1)
        ))
        @Assert(reciprocalFailure.fileGamma, PNG_FP_1)
        @Assert(reciprocalFailure.screenGamma, PNG_FP_1)
        @Assert(reciprocalFailure.correctionRequired, false)
    }

    @TestCase
    public func initializesThresholdOverflowAsCorrectionRequired(): Unit {
        let result = pngInitGammaValues(PngFileGammaSources(
            Int32.Max,
            Int32(0),
            Int32(0),
            Int32.Max
        ))
        @Assert(result.fileGamma, Int32.Max)
        @Assert(result.screenGamma, Int32.Max)
        @Assert(result.correctionRequired, true)
    }

    @TestCase
    public func initializesWithoutMutatingGammaSources(): Unit {
        let sources = PngFileGammaSources(
            Int32(0),
            Int32(45455),
            Int32(90000),
            Int32(0)
        )
        let result = pngInitGammaValues(sources)
        @Assert(result.fileGamma, Int32(45455))
        @Assert(result.screenGamma, Int32(219998))
        @Assert(sources.fileGamma, Int32(0))
        @Assert(sources.chunkGamma, Int32(45455))
        @Assert(sources.defaultGamma, Int32(90000))
        @Assert(sources.screenGamma, Int32(0))
    }
}
