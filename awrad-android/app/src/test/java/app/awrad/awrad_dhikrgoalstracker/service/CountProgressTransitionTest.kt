package app.awrad.awrad_dhikrgoalstracker.service

import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CountProgressTransitionTest {

    @Test
    fun `allow and warn target crossings do not produce a hard stop`() {
        listOf(
            CountCapBehavior.AllowOverTarget,
            CountCapBehavior.WarnOverTarget,
        ).forEach { capBehavior ->
            val transition = transition(99, 100, capBehavior)

            assertTrue(transition.targetReached)
            assertTrue(transition.targetReachedNow)
            assertFalse(transition.hardCapReached)
        }
    }

    @Test
    fun `block at target crossing produces a hard stop`() {
        val transition = transition(99, 100, CountCapBehavior.BlockAtTarget)

        assertTrue(transition.targetReachedNow)
        assertTrue(transition.hardCapReached)
    }

    @Test
    fun `block at maximum stays open at target and stops at maximum`() {
        val targetTransition = transition(99, 100, CountCapBehavior.BlockAtMaximum)
        val maximumTransition = transition(119, 120, CountCapBehavior.BlockAtMaximum)

        assertTrue(targetTransition.targetReachedNow)
        assertFalse(targetTransition.hardCapReached)
        assertFalse(maximumTransition.targetReachedNow)
        assertTrue(maximumTransition.hardCapReached)
    }

    @Test
    fun `completion feedback is only requested on the first target crossing`() {
        val first = transition(99, 100, CountCapBehavior.AllowOverTarget)
        val later = transition(100, 101, CountCapBehavior.AllowOverTarget)

        assertTrue(first.targetReachedNow)
        assertFalse(later.targetReachedNow)
    }

    private fun transition(
        previousCount: Long,
        newCount: Long,
        capBehavior: CountCapBehavior,
    ) = evaluateCountProgressTransition(
        previousCount = previousCount,
        newCount = newCount,
        targetCount = 100,
        maximumCount = 120,
        capBehavior = capBehavior,
    )
}
