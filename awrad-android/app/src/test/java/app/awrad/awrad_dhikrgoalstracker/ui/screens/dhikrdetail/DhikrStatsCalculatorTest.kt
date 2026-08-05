package app.awrad.awrad_dhikrgoalstracker.ui.screens.dhikrdetail

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import java.time.LocalDate
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DhikrStatsCalculatorTest {

    @Test
    fun `aggregates every goal for the dhikr without counting other goals`() {
        val firstGoal = id("00000000-0000-0000-0000-000000000001")
        val secondGoal = id("00000000-0000-0000-0000-000000000002")
        val unrelatedGoal = id("00000000-0000-0000-0000-000000000003")
        val day = LocalDate.of(2026, 8, 5)

        val result = DhikrStatsCalculator.aggregateGoalCounts(
            goalIds = setOf(firstGoal, secondGoal),
            dailyCountsByGoal = mapOf(
                firstGoal to mapOf(day to 33L),
                secondGoal to mapOf(day to 67L),
                unrelatedGoal to mapOf(day to 999L),
            ),
        )

        assertEquals(mapOf(day to 100L), result)
    }

    @Test
    fun `thirty day stats use active days for average and calendar days for presence`() {
        val today = LocalDate.of(2026, 8, 30)
        val result = DhikrStatsCalculator.calculate(
            dailyCounts = mapOf(
                today.minusDays(29) to 100L,
                today.minusDays(2) to 32L,
                today.minusDays(1) to 33L,
                today to 0L,
                today.minusDays(30) to 500L,
            ),
            effectiveToday = today,
            range = DhikrStatsRange.THIRTY_DAYS,
        )

        assertEquals(165L, result.totalCount)
        assertEquals(3, result.activeDays)
        assertEquals(55L, result.activeDayAverage)
        assertEquals(10, result.presencePercent)
        assertEquals(100L, result.peakDayCount)
        assertEquals(30, result.dailyCounts.size)
        assertEquals(today.minusDays(29), result.dailyCounts.first().date)
        assertEquals(0L, result.dailyCounts.last().count)
    }

    @Test
    fun `current streak keeps yesterday while the current effective day is still open`() {
        val today = LocalDate.of(2026, 8, 5)
        val result = DhikrStatsCalculator.calculate(
            dailyCounts = mapOf(
                today.minusDays(3) to 20L,
                today.minusDays(2) to 20L,
                today.minusDays(1) to 20L,
            ),
            effectiveToday = today,
            range = DhikrStatsRange.THIRTY_DAYS,
        )

        assertEquals(3, result.currentStreak)
    }

    @Test
    fun `empty history produces a safe empty profile`() {
        val result = DhikrStatsCalculator.calculate(
            dailyCounts = emptyMap(),
            effectiveToday = LocalDate.of(2026, 8, 5),
            range = DhikrStatsRange.ALL_TIME,
        )

        assertEquals(0L, result.totalCount)
        assertEquals(0, result.activeDays)
        assertEquals(0L, result.activeDayAverage)
        assertEquals(0, result.presencePercent)
        assertEquals(0, result.currentStreak)
        assertTrue(result.dailyCounts.isEmpty())
    }

    private fun id(value: String): AwradId = UUID.fromString(value)
}
