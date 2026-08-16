package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.CountEntry
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.testId
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Test

class GoalSessionStatsCalculatorTest {

    @Test
    fun `groups positive count history by configured session`() {
        val goalId = testId(1)
        val fajrId = testId(2)
        val maghribId = testId(3)
        val slots = listOf(
            GoalSlot(
                id = fajrId,
                goalId = goalId,
                slotType = GoalSlotType.PRAYER,
                label = "After Fajr",
            ),
            GoalSlot(
                id = maghribId,
                goalId = goalId,
                slotType = GoalSlotType.PRAYER,
                label = "After Maghrib",
            ),
        )
        val entries = listOf(
            entry(goalId, fajrId, "2026-08-12", 60L),
            entry(goalId, fajrId, "2026-08-13", 40L),
            entry(goalId, maghribId, "2026-08-13", 25L),
            entry(goalId, maghribId, "2026-08-11", 0L),
        )

        val stats = GoalSessionStatsCalculator.calculate(entries, slots)

        assertEquals(2, stats.size)
        assertEquals(100L, stats[0].totalCount)
        assertEquals(2, stats[0].activeDays)
        assertEquals(50L, stats[0].averageActiveDayCount)
        assertEquals(80, stats[0].sharePercent)
        assertEquals(25L, stats[1].totalCount)
        assertEquals(1, stats[1].activeDays)
        assertEquals(25L, stats[1].averageActiveDayCount)
        assertEquals(20, stats[1].sharePercent)
    }

    private fun entry(goalId: java.util.UUID, slotId: java.util.UUID, date: String, count: Long): CountEntry =
        CountEntry(
            goalId = goalId,
            slotId = slotId,
            count = count,
            date = date,
            lastUpdated = 0L,
        )
}
