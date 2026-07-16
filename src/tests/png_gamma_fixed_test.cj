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
}
