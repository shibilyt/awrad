package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.testId
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class GoalsCategorizationTest {

    @Test
    fun `goals are grouped into today next seven days and other`() {
        val today = LocalDate.parse("2026-07-14")
        val finishedToday = displayItem(id = 1, startDate = today, overallProgress = 1f)
        val unfinishedToday = displayItem(id = 5, startDate = today, overallProgress = 0.5f)
        val dueOnSeventhDay = displayItem(id = 2, startDate = today.plusDays(7))
        val dueOnEighthDay = displayItem(id = 3, startDate = today.plusDays(8))
        val endedYesterday = displayItem(
            id = 4,
            startDate = today.minusDays(2),
            endDate = today.minusDays(1),
        )

        val sections = categorizeActiveGoals(
            goals = listOf(finishedToday, unfinishedToday, dueOnSeventhDay, dueOnEighthDay, endedYesterday),
            today = today,
        )

        assertEquals(listOf(testId(5), testId(1)), sections.today.map { it.goal.id })
        assertEquals(listOf(testId(2)), sections.upcoming.map { it.goal.id })
        assertEquals(listOf(testId(3), testId(4)), sections.other.map { it.goal.id })
    }

    private fun displayItem(
        id: Int,
        startDate: LocalDate,
        endDate: LocalDate? = null,
        overallProgress: Float = 0f,
    ): GoalDisplayItem = GoalDisplayItem(
        goal = Goal(
            id = testId(id),
            dhikrId = testId(id + 100),
            startDate = startDate,
            endDate = endDate,
        ),
        overallProgress = overallProgress,
    )
}
