package app.awrad.awrad_dhikrgoalstracker.domain.usecase

import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.testId
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AllowCountingPastTargetUseCaseTest {

    @Test
    fun `single session update changes goal and session cap while preserving completion`() {
        val goal = Goal(
            id = testId(1),
            dhikrId = testId(2),
            startDate = LocalDate.of(2026, 7, 14),
            targetCount = 100,
            capBehavior = CountCapBehavior.BlockAtTarget,
            slots = listOf(
                GoalSlot(
                    id = testId(11),
                    goalId = testId(1),
                    targetCount = 100,
                    capBehavior = CountCapBehavior.BlockAtTarget,
                ),
            ),
            autoCompleteOnTarget = true,
            totalCompletedCount = 100,
            isActive = false,
            completedAt = 1234L,
        )

        val updated = requireNotNull(goal.allowCountingPastTarget(testId(11)))

        assertEquals(CountCapBehavior.AllowOverTarget, updated.capBehavior)
        assertEquals(CountCapBehavior.AllowOverTarget, updated.slots.single().capBehavior)
        assertTrue(updated.autoCompleteOnTarget)
        assertFalse(updated.isActive)
        assertEquals(1234L, updated.completedAt)
        assertEquals(100L, updated.totalCompletedCount)
        assertEquals(goal.recurrence, updated.recurrence)
        assertEquals(goal.reminders, updated.reminders)
    }

    @Test
    fun `multi session update changes only selected session`() {
        val first = timedSlot(testId(11), CountCapBehavior.BlockAtTarget)
        val second = timedSlot(testId(12), CountCapBehavior.BlockAtTarget)
        val goal = baseGoal(slots = listOf(first, second))

        val updated = requireNotNull(goal.allowCountingPastTarget(first.id))

        assertEquals(CountCapBehavior.AllowOverTarget, updated.slots[0].capBehavior)
        assertEquals(CountCapBehavior.BlockAtTarget, updated.slots[1].capBehavior)
        assertEquals(goal.capBehavior, updated.capBehavior)
    }

    @Test
    fun `multi session update requires a selected session`() {
        val goal = baseGoal(
            slots = listOf(
                timedSlot(testId(11), CountCapBehavior.BlockAtTarget),
                timedSlot(testId(12), CountCapBehavior.BlockAtTarget),
            ),
        )

        assertNull(goal.allowCountingPastTarget(activeSlotId = null))
    }

    @Test
    fun `non target blocking caps are not changed`() {
        assertNull(
            baseGoal(capBehavior = CountCapBehavior.AllowOverTarget)
                .allowCountingPastTarget(activeSlotId = null),
        )
        assertNull(
            baseGoal(capBehavior = CountCapBehavior.BlockAtMaximum)
                .allowCountingPastTarget(activeSlotId = null),
        )
    }

    private fun baseGoal(
        capBehavior: CountCapBehavior = CountCapBehavior.BlockAtTarget,
        slots: List<GoalSlot> = emptyList(),
    ) = Goal(
        id = testId(1),
        dhikrId = testId(2),
        startDate = LocalDate.of(2026, 7, 14),
        targetCount = 100,
        capBehavior = capBehavior,
        slots = slots,
    )

    private fun timedSlot(id: java.util.UUID, capBehavior: CountCapBehavior) = GoalSlot(
        id = id,
        goalId = testId(1),
        slotType = GoalSlotType.TIME_WINDOW,
        targetCount = 10,
        capBehavior = capBehavior,
        startMinute = 60,
        endMinute = 120,
    )
}
