package app.awrad.awrad_dhikrgoalstracker.util

import java.util.UUID

import app.awrad.awrad_dhikrgoalstracker.testId

import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import java.time.LocalDate
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalCountingEligibilityTest {

    @Test
    fun `goal without slots follows its goal cap behavior`() {
        val blockedGoal = Goal(
            id = testId(1),
            dhikrId = testId(1),
            startDate = LocalDate.of(2026, 7, 12),
            maximumCount = 120,
            capBehavior = CountCapBehavior.BlockAtMaximum,
        )

        assertTrue(
            GoalCountingEligibility.canContinueCounting(
                goal = blockedGoal,
                progressCount = 119,
                slotCounts = emptyMap(),
            ),
        )
        assertFalse(
            GoalCountingEligibility.canContinueCounting(
                goal = blockedGoal,
                progressCount = 120,
                slotCounts = emptyMap(),
            ),
        )
        assertTrue(
            GoalCountingEligibility.canContinueCounting(
                goal = blockedGoal.copy(capBehavior = CountCapBehavior.WarnOverTarget),
                progressCount = 120,
                slotCounts = emptyMap(),
            ),
        )
    }

    @Test
    fun `single anytime slot uses goal progress and blocks at target`() {
        val goal = goalWithSlots(
            GoalSlot(
                id = testId(11),
                goalId = testId(1),
                targetCount = 100,
                capBehavior = CountCapBehavior.BlockAtTarget,
            ),
        )

        assertFalse(
            GoalCountingEligibility.canContinueCounting(
                goal = goal,
                progressCount = 100,
                slotCounts = mapOf(testId(11) to 0L),
            ),
        )
    }

    @Test
    fun `single anytime slot remains countable when over target is allowed`() {
        val goal = goalWithSlots(
            GoalSlot(
                id = testId(11),
                goalId = testId(1),
                targetCount = 100,
                capBehavior = CountCapBehavior.AllowOverTarget,
            ),
        )

        assertTrue(
            GoalCountingEligibility.canContinueCounting(
                goal = goal,
                progressCount = 100,
                slotCounts = mapOf(testId(11) to 100L),
            ),
        )
    }

    @Test
    fun `multi slot goal is blocked when every slot has reached its cap`() {
        val goal = goalWithSlots(
            timedSlot(id = testId(11), capBehavior = CountCapBehavior.BlockAtTarget),
            timedSlot(id = testId(12), capBehavior = CountCapBehavior.BlockAtMaximum),
        )

        assertFalse(
            GoalCountingEligibility.canContinueCounting(
                goal = goal,
                progressCount = 20,
                slotCounts = mapOf(testId(11) to 10L, testId(12) to 12L),
            ),
        )
    }

    @Test
    fun `multi slot goal remains countable when one slot permits over target`() {
        val goal = goalWithSlots(
            timedSlot(id = testId(11), capBehavior = CountCapBehavior.BlockAtTarget),
            timedSlot(id = testId(12), capBehavior = CountCapBehavior.WarnOverTarget),
        )

        assertTrue(
            GoalCountingEligibility.canContinueCounting(
                goal = goal,
                progressCount = 20,
                slotCounts = mapOf(testId(11) to 10L, testId(12) to 12L),
            ),
        )
    }

    private fun goalWithSlots(vararg slots: GoalSlot) = Goal(
        id = testId(1),
        dhikrId = testId(1),
        startDate = LocalDate.of(2026, 7, 12),
        slots = slots.toList(),
    )

    private fun timedSlot(id: UUID, capBehavior: CountCapBehavior) = GoalSlot(
        id = id,
        goalId = testId(1),
        slotType = GoalSlotType.TIME_WINDOW,
        targetCount = 10,
        maximumCount = 12,
        capBehavior = capBehavior,
        startMinute = 60,
        endMinute = 120,
    )
}
