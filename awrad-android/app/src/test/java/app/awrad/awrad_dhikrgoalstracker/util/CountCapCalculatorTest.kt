package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CountCapCalculatorTest {

    @Test
    fun `allow over target keeps positive delta unchanged`() {
        val result = CountCapCalculator.applyDelta(
            currentCount = 99,
            requestedDelta = 10,
            targetCount = 100,
            maximumCount = null,
            capBehavior = CountCapBehavior.AllowOverTarget,
        )

        assertEquals(10L, result.appliedDelta)
        assertEquals(CountCapReason.Allowed, result.reason)
        assertFalse(result.wouldCrossTarget)
    }

    @Test
    fun `block at target clamps positive delta to target`() {
        val result = CountCapCalculator.applyDelta(
            currentCount = 98,
            requestedDelta = 5,
            targetCount = 100,
            maximumCount = 120,
            capBehavior = CountCapBehavior.BlockAtTarget,
        )

        assertEquals(2L, result.appliedDelta)
        assertEquals(CountCapReason.ClampedAtTarget, result.reason)
    }

    @Test
    fun `block at target blocks when already at target`() {
        val result = CountCapCalculator.applyDelta(
            currentCount = 100,
            requestedDelta = 1,
            targetCount = 100,
            maximumCount = 120,
            capBehavior = CountCapBehavior.BlockAtTarget,
        )

        assertEquals(0L, result.appliedDelta)
        assertEquals(CountCapReason.BlockedAtTarget, result.reason)
        assertTrue(result.isBlocked)
    }

    @Test
    fun `block at maximum clamps positive delta to maximum`() {
        val result = CountCapCalculator.applyDelta(
            currentCount = 38,
            requestedDelta = 5,
            targetCount = 33,
            maximumCount = 40,
            capBehavior = CountCapBehavior.BlockAtMaximum,
        )

        assertEquals(2L, result.appliedDelta)
        assertEquals(CountCapReason.ClampedAtMaximum, result.reason)
    }

    @Test
    fun `block at maximum blocks when already at maximum`() {
        val result = CountCapCalculator.applyDelta(
            currentCount = 40,
            requestedDelta = 1,
            targetCount = 33,
            maximumCount = 40,
            capBehavior = CountCapBehavior.BlockAtMaximum,
        )

        assertEquals(0L, result.appliedDelta)
        assertEquals(CountCapReason.BlockedAtMaximum, result.reason)
        assertTrue(result.isBlocked)
    }

    @Test
    fun `negative adjustment never goes below zero`() {
        val result = CountCapCalculator.applyDelta(
            currentCount = 3,
            requestedDelta = -10,
            targetCount = 5,
            maximumCount = 5,
            capBehavior = CountCapBehavior.BlockAtMaximum,
        )

        assertEquals(-3L, result.appliedDelta)
        assertEquals(CountCapReason.Decremented, result.reason)
    }

    @Test
    fun `warn over target flags target crossing without blocking`() {
        val result = CountCapCalculator.applyDelta(
            currentCount = 98,
            requestedDelta = 5,
            targetCount = 100,
            maximumCount = null,
            capBehavior = CountCapBehavior.WarnOverTarget,
        )

        assertEquals(5L, result.appliedDelta)
        assertEquals(CountCapReason.WarnedOverTarget, result.reason)
        assertTrue(result.wouldCrossTarget)
    }

    @Test
    fun `warn over target flags target crossing from exactly target`() {
        val result = CountCapCalculator.applyDelta(
            currentCount = 100,
            requestedDelta = 1,
            targetCount = 100,
            maximumCount = null,
            capBehavior = CountCapBehavior.WarnOverTarget,
        )

        assertEquals(1L, result.appliedDelta)
        assertEquals(CountCapReason.WarnedOverTarget, result.reason)
        assertTrue(result.wouldCrossTarget)
    }
}
