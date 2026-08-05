package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.testId
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class GoalsCategorizationTest {

    @Test
    fun `completed goal display keeps its final count and target`() {
        val goal = Goal(
            id = testId(1),
            dhikrId = testId(101),
            targetPolicy = TargetPolicy.CUMULATIVE_TOTAL,
            slots = listOf(
                GoalSlot(
                    id = testId(11),
                    goalId = testId(1),
                    targetCount = 313,
                ),
            ),
            startDate = LocalDate.parse("2026-07-14"),
            totalCompletedCount = 313,
            isActive = false,
            completedAt = 1L,
        )

        val item = completedGoalDisplayItem(goal, dhikrName = "Swalath al Nariyya")

        assertEquals(313L, item.todayCount)
        assertEquals(313, item.dailyTarget)
        assertEquals(1f, item.overallProgress)
        assertEquals("313 total", item.targetDisplay)
    }

    @Test
    fun `goals are grouped into today upcoming and past`() {
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
        val durationEndedYesterday = displayItem(
            id = 6,
            startDate = today.minusDays(2),
            durationDays = 2,
        )

        val sections = categorizeActiveGoals(
            goals = listOf(
                finishedToday,
                unfinishedToday,
                dueOnSeventhDay,
                dueOnEighthDay,
                endedYesterday,
                durationEndedYesterday,
            ),
            today = today,
        )

        assertEquals(listOf(testId(5), testId(1)), sections.today.map { it.goal.id })
        assertEquals(listOf(testId(2), testId(3)), sections.upcoming.map { it.goal.id })
        assertEquals(listOf(testId(4), testId(6)), sections.past.map { it.goal.id })
    }

    private fun displayItem(
        id: Int,
        startDate: LocalDate,
        endDate: LocalDate? = null,
        durationDays: Int? = null,
        overallProgress: Float = 0f,
    ): GoalDisplayItem = GoalDisplayItem(
        goal = Goal(
            id = testId(id),
            dhikrId = testId(id + 100),
            startDate = startDate,
            endDate = endDate,
            durationDays = durationDays,
        ),
        overallProgress = overallProgress,
    )
}
