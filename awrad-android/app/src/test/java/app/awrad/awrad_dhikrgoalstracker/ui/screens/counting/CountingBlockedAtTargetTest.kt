package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.service.CountingState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CountingBlockedAtTargetTest {

    @Test
    fun `block at target is detected exactly at and above target`() {
        val state = CountingState(
            currentCount = 100,
            targetCount = 100,
            capBehavior = CountCapBehavior.BlockAtTarget,
        )

        assertTrue(state.isBlockedAtTargetCap())
        assertTrue(state.copy(currentCount = 101).isBlockedAtTargetCap())
    }

    @Test
    fun `block at target is hidden below target and for other policies`() {
        val state = CountingState(
            currentCount = 99,
            targetCount = 100,
            capBehavior = CountCapBehavior.BlockAtTarget,
        )

        assertFalse(state.isBlockedAtTargetCap())
        assertFalse(
            state.copy(
                currentCount = 100,
                capBehavior = CountCapBehavior.AllowOverTarget,
            ).isBlockedAtTargetCap(),
        )
        assertFalse(
            state.copy(
                currentCount = 120,
                maximumCount = 120,
                capBehavior = CountCapBehavior.BlockAtMaximum,
            ).isBlockedAtTargetCap(),
        )
    }

    @Test
    fun `zero target never shows target blocked state`() {
        assertFalse(
            CountingState(
                currentCount = 10,
                targetCount = 0,
                capBehavior = CountCapBehavior.BlockAtTarget,
            ).isBlockedAtTargetCap(),
        )
    }

    @Test
    fun `goal reached dialog is only shown for a new blocked transition`() {
        assertFalse(shouldShowGoalReachedDialog(null, isCompletionBlocked = true))
        assertFalse(shouldShowGoalReachedDialog(false, isCompletionBlocked = false))
        assertTrue(shouldShowGoalReachedDialog(false, isCompletionBlocked = true))
        assertFalse(shouldShowGoalReachedDialog(true, isCompletionBlocked = true))
    }

    @Test
    fun `ordinary goal target becomes a milestone at and above target`() {
        val reached = countingTargetMilestone(
            currentCount = 33,
            targetCount = 33,
            hasSessionTarget = false,
            usesRangeProgress = false,
        )
        val exceeded = countingTargetMilestone(
            currentCount = 43,
            targetCount = 33,
            hasSessionTarget = false,
            usesRangeProgress = false,
        )

        assertEquals(CountingTargetMilestone(targetCount = 33, additionalCount = 0), reached)
        assertEquals(CountingTargetMilestone(targetCount = 33, additionalCount = 10), exceeded)
    }

    @Test
    fun `progress denominator remains for incomplete session and range targets`() {
        assertNull(
            countingTargetMilestone(
                currentCount = 32,
                targetCount = 33,
                hasSessionTarget = false,
                usesRangeProgress = false,
            ),
        )
        assertNull(
            countingTargetMilestone(
                currentCount = 43,
                targetCount = 33,
                hasSessionTarget = true,
                usesRangeProgress = false,
            ),
        )
        assertNull(
            countingTargetMilestone(
                currentCount = 43,
                targetCount = 33,
                hasSessionTarget = false,
                usesRangeProgress = true,
            ),
        )
    }
}
