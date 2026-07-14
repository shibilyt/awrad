package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.testId

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate

class GoalProgressCalculatorTest {

    @Test
    fun `per due date daily goal uses current date count`() {
        val goal = goal(targetPolicy = TargetPolicy.PER_DUE_DATE, target = 100)

        assertTrue(GoalProgressCalculator.isDueToday(goal, LocalDate.parse("2026-05-24")))
        assertEquals(0.5f, GoalProgressCalculator.getProgress(50, goal), 0.001f)
        assertEquals(50, GoalProgressCalculator.getRemainingCount(50, goal))
    }

    @Test
    fun `cumulative total goal completes from all time total`() {
        val goal = goal(
            targetPolicy = TargetPolicy.CUMULATIVE_TOTAL,
            target = 70000,
            totalCompletedCount = 70000,
            autoCompleteOnTarget = true,
        )

        assertTrue(GoalProgressCalculator.isGoalComplete(goal))
        assertEquals(1f, GoalProgressCalculator.getProgress(70000, goal), 0.001f)
    }

    @Test
    fun `weekly recurrence is due only on selected weekdays`() {
        val goal = goal(
            recurrence = GoalRecurrence(goalId = testId(1),
                frequency = RecurrenceFrequency.WEEKLY,
                weekdays = setOf(DayOfWeek.MONDAY, DayOfWeek.THURSDAY),
            )
        )

        assertTrue(GoalProgressCalculator.isDueToday(goal, LocalDate.parse("2026-05-25")))
        assertFalse(GoalProgressCalculator.isDueToday(goal, LocalDate.parse("2026-05-26")))
    }

    @Test
    fun `period total weekly window spans monday through sunday`() {
        val goal = goal(
            targetPolicy = TargetPolicy.PERIOD_TOTAL,
            recurrence = GoalRecurrence(goalId = testId(1), frequency = RecurrenceFrequency.WEEKLY),
        )

        val window = GoalProgressCalculator.currentProgressWindow(goal, LocalDate.parse("2026-05-28"))

        assertEquals(LocalDate.parse("2026-05-25"), window?.start)
        assertEquals(LocalDate.parse("2026-05-31"), window?.endInclusive)
    }

    @Test
    fun `tracker has zero target and no remaining count`() {
        val goal = goal(targetPolicy = TargetPolicy.NONE, target = null)

        assertEquals(0, GoalProgressCalculator.getTotalDailyTarget(goal))
        assertEquals(0, GoalProgressCalculator.getRemainingCount(10, goal))
        assertEquals(1f, GoalProgressCalculator.getProgress(10, goal), 0.001f)
    }

    @Test
    fun `season period window uses the active hijri season dates`() {
        val goal = goal(
            targetPolicy = TargetPolicy.PERIOD_TOTAL,
            recurrence = GoalRecurrence(goalId = testId(1),
                frequency = RecurrenceFrequency.SEASON,
                seasonTemplateCode = SeasonTemplateCode.RAMADAN,
            ),
        )

        val window = GoalProgressCalculator.currentProgressWindow(goal, LocalDate.parse("2026-03-01"))

        assertEquals(LocalDate.parse("2026-02-18"), window?.start)
        assertEquals(LocalDate.parse("2026-03-19"), window?.endInclusive)
    }

    private fun goal(
        targetPolicy: TargetPolicy = TargetPolicy.PER_DUE_DATE,
        target: Int? = 100,
        recurrence: GoalRecurrence = GoalRecurrence(goalId = testId(1), ),
        totalCompletedCount: Long = 0,
        autoCompleteOnTarget: Boolean = false,
    ): Goal = Goal(
        dhikrId = testId(1),
        targetPolicy = targetPolicy,
        recurrence = recurrence,
        slots = listOf(GoalSlot(goalId = testId(0), slotType = GoalSlotType.ANYTIME, targetCount = target)),
        startDate = LocalDate.parse("2026-05-24"),
        totalCompletedCount = totalCompletedCount,
        autoCompleteOnTarget = autoCompleteOnTarget,
    )
}
