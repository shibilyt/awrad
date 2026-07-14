package app.awrad.awrad_dhikrgoalstracker.domain.usecase

import java.util.UUID

import app.awrad.awrad_dhikrgoalstracker.testId

import app.awrad.awrad_dhikrgoalstracker.data.model.CountEntry
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class GoalProgressUseCaseTest {

    private val useCase = GoalProgressUseCase()

    @Test
    fun `per due date progress uses only the effective date count`() {
        val goal = goal(id = testId(7), targetPolicy = TargetPolicy.PER_DUE_DATE, target = 100)
        val entries = listOf(
            entry(goalId = testId(7), count = 40, date = "2026-05-24"),
            entry(goalId = testId(7), count = 15, date = "2026-05-23"),
            entry(goalId = testId(8), count = 99, date = "2026-05-24"),
        )

        val summary = useCase.summarize(goal, entries, LocalDate.parse("2026-05-24"))

        assertEquals(40, summary.progressCount)
        assertEquals(100, summary.targetCount)
        assertEquals(0.4f, summary.progress, 0.001f)
        assertEquals(60, summary.remainingCount)
    }

    @Test
    fun `cumulative progress uses all positive entries for the goal`() {
        val goal = goal(id = testId(7), targetPolicy = TargetPolicy.CUMULATIVE_TOTAL, target = 100)
        val entries = listOf(
            entry(goalId = testId(7), count = 40, date = "2026-05-24"),
            entry(goalId = testId(7), count = 15, date = "2026-05-23"),
            entry(goalId = testId(8), count = 99, date = "2026-05-24"),
        )

        val summary = useCase.summarize(goal, entries, LocalDate.parse("2026-05-24"))

        assertEquals(55, summary.progressCount)
        assertEquals(0.55f, summary.progress, 0.001f)
    }

    @Test
    fun `aggregate daily map matches raw entries for cumulative progress`() {
        val goal = goal(id = testId(7), targetPolicy = TargetPolicy.CUMULATIVE_TOTAL, target = 100)
        val entries = listOf(
            entry(goalId = testId(7), count = 40, date = "2026-05-24"),
            entry(goalId = testId(7), count = 15, date = "2026-05-23"),
            entry(goalId = testId(8), count = 99, date = "2026-05-24"),
        )
        val dailyCounts = entries
            .filter { it.goalId == goal.id && it.count > 0 }
            .groupBy { LocalDate.parse(it.date) }
            .mapValues { (_, rows) -> rows.sumOf { it.count } }

        assertEquals(
            useCase.summarize(goal, entries, LocalDate.parse("2026-05-24")),
            useCase.summarize(goal, dailyCounts, LocalDate.parse("2026-05-24")),
        )
    }

    @Test
    fun `period progress includes only entries inside current window`() {
        val goal = goal(
            id = testId(7),
            targetPolicy = TargetPolicy.PERIOD_TOTAL,
            target = 100,
            recurrence = GoalRecurrence(goalId = testId(1), frequency = RecurrenceFrequency.WEEKLY),
        )
        val entries = listOf(
            entry(goalId = testId(7), count = 10, date = "2026-05-24"),
            entry(goalId = testId(7), count = 25, date = "2026-05-25"),
            entry(goalId = testId(7), count = 30, date = "2026-05-31"),
            entry(goalId = testId(7), count = 45, date = "2026-06-01"),
        )

        val summary = useCase.summarize(goal, entries, LocalDate.parse("2026-05-28"))

        assertEquals(55, summary.progressCount)
        assertEquals(0.55f, summary.progress, 0.001f)
    }

    @Test
    fun `aggregate daily map matches raw entries for period progress`() {
        val goal = goal(
            id = testId(7),
            targetPolicy = TargetPolicy.PERIOD_TOTAL,
            target = 100,
            recurrence = GoalRecurrence(goalId = testId(1), frequency = RecurrenceFrequency.WEEKLY),
        )
        val entries = listOf(
            entry(goalId = testId(7), count = 10, date = "2026-05-24"),
            entry(goalId = testId(7), count = 25, date = "2026-05-25"),
            entry(goalId = testId(7), count = 30, date = "2026-05-31"),
            entry(goalId = testId(7), count = 45, date = "2026-06-01"),
        )
        val dailyCounts = entries
            .filter { it.goalId == goal.id && it.count > 0 }
            .groupBy { LocalDate.parse(it.date) }
            .mapValues { (_, rows) -> rows.sumOf { it.count } }
        val date = LocalDate.parse("2026-05-28")

        assertEquals(useCase.summarize(goal, entries, date), useCase.summarize(goal, dailyCounts, date))
    }

    @Test
    fun `period progress ignores malformed legacy history dates`() {
        val goal = goal(
            id = testId(7),
            targetPolicy = TargetPolicy.PERIOD_TOTAL,
            target = 100,
            recurrence = GoalRecurrence(goalId = testId(1), frequency = RecurrenceFrequency.WEEKLY),
        )
        val entries = listOf(
            entry(goalId = testId(7), count = 25, date = "2026-05-25"),
            entry(goalId = testId(7), count = 99, date = "not-a-date"),
        )

        val summary = useCase.summarize(goal, entries, LocalDate.parse("2026-05-28"))

        assertEquals(25, summary.progressCount)
        assertEquals(0.25f, summary.progress, 0.001f)
    }

    @Test
    fun `provider progress uses repository-shaped callbacks for counting screen`() = runBlocking {
        val goal = goal(
            id = testId(7),
            targetPolicy = TargetPolicy.PERIOD_TOTAL,
            target = 100,
            recurrence = GoalRecurrence(goalId = testId(1), frequency = RecurrenceFrequency.WEEKLY),
        )

        val count = useCase.progressCountFor(
            goal = goal,
            date = LocalDate.parse("2026-05-28"),
            countForDate = { 11 },
            totalCount = { 22 },
            countBetween = { window ->
                assertEquals(LocalDate.parse("2026-05-25"), window.start)
                assertEquals(LocalDate.parse("2026-05-31"), window.endInclusive)
                33
            },
        )

        assertEquals(33, count)
    }

    @Test
    fun `tracker summary reports completion after any count`() {
        val goal = goal(id = testId(7), targetPolicy = TargetPolicy.NONE, target = null)
        val entries = listOf(entry(goalId = testId(7), count = 1, date = "2026-05-24"))

        val summary = useCase.summarize(goal, entries, LocalDate.parse("2026-05-24"))

        assertEquals(1, summary.progressCount)
        assertEquals(0, summary.targetCount)
        assertEquals(1f, summary.progress, 0.001f)
        assertEquals("Tracker", summary.targetDisplay)
    }

    private fun goal(
        id: UUID,
        targetPolicy: TargetPolicy,
        target: Int?,
        recurrence: GoalRecurrence = GoalRecurrence(goalId = testId(1), ),
    ): Goal = Goal(
        id = id,
        dhikrId = testId(1),
        targetPolicy = targetPolicy,
        recurrence = recurrence,
        slots = listOf(GoalSlot(goalId = id, slotType = GoalSlotType.ANYTIME, targetCount = target)),
        startDate = LocalDate.parse("2026-05-24"),
    )

    private fun entry(goalId: UUID, count: Long, date: String): CountEntry =
        CountEntry(goalId = goalId, slotId = testId(1), count = count, date = date, lastUpdated = 0)
}
