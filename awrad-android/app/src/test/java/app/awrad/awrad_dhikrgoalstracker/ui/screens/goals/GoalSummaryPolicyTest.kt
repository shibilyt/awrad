package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.testId
import java.time.LocalDate
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalSummaryPolicyTest {
    @Test
    fun `cumulative goal with daily streak cadence does not use daily target wording`() {
        val goal = goal(
            targetPolicy = TargetPolicy.CUMULATIVE_TOTAL,
            frequency = RecurrenceFrequency.DAILY,
        )

        assertFalse(usesDailyTargetSummary(goal))
    }

    @Test
    fun `daily due-date goal keeps daily target wording`() {
        val goal = goal(
            targetPolicy = TargetPolicy.PER_DUE_DATE,
            frequency = RecurrenceFrequency.DAILY,
        )

        assertTrue(usesDailyTargetSummary(goal))
    }

    private fun goal(
        targetPolicy: TargetPolicy,
        frequency: RecurrenceFrequency,
    ): Goal = Goal(
        id = testId(1),
        dhikrId = testId(2),
        targetPolicy = targetPolicy,
        recurrence = GoalRecurrence(goalId = testId(1), frequency = frequency),
        startDate = LocalDate.parse("2026-08-17"),
    )
}
