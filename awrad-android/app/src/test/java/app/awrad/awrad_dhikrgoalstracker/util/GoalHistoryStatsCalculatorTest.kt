package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.testId
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Test

class GoalHistoryStatsCalculatorTest {

    @Test
    fun `calculates all time totals average active days and both streak lengths`() {
        val today = LocalDate.of(2026, 8, 13)
        val stats = GoalHistoryStatsCalculator.calculate(
            dailyCounts = mapOf(
                today to 100L,
                today.minusDays(1) to 100L,
                today.minusDays(3) to 150L,
                today.minusDays(4) to 100L,
                today.minusDays(5) to 100L,
                today.minusDays(6) to 100L,
            ),
            today = today,
            dailyTarget = 100,
        )

        assertEquals(650L, stats.totalCount)
        assertEquals(6, stats.activeDays)
        assertEquals(108L, stats.activeDayAverage)
        assertEquals(2, stats.currentStreak)
        assertEquals(4, stats.longestStreak)
    }

    @Test
    fun `empty history returns zeroed stats`() {
        val stats = GoalHistoryStatsCalculator.calculate(
            dailyCounts = emptyMap(),
            today = LocalDate.of(2026, 8, 13),
            dailyTarget = 100,
        )

        assertEquals(0L, stats.totalCount)
        assertEquals(0, stats.activeDays)
        assertEquals(0L, stats.activeDayAverage)
        assertEquals(0, stats.currentStreak)
        assertEquals(0, stats.longestStreak)
    }

    @Test
    fun `future dated rows do not inflate all time stats`() {
        val today = LocalDate.of(2026, 8, 13)
        val stats = GoalHistoryStatsCalculator.calculate(
            dailyCounts = mapOf(
                today to 50L,
                today.plusDays(1) to 999L,
            ),
            today = today,
            dailyTarget = 1,
        )

        assertEquals(50L, stats.totalCount)
        assertEquals(1, stats.activeDays)
    }

    @Test
    fun `range stats classify scheduled days and expose affinity and peak day`() {
        val today = LocalDate.of(2026, 8, 13)
        val goal = dailyGoal(startDate = today.minusDays(6))
        val stats = GoalHistoryStatsCalculator.calculate(
            dailyCounts = mapOf(
                today to 100L,
                today.minusDays(1) to 50L,
                today.minusDays(3) to 120L,
                today.minusDays(6) to 40L,
            ),
            today = today,
            dailyTarget = 100,
            goal = goal,
            range = GoalHistoryRange.SEVEN_DAYS,
        )

        assertEquals(7, stats.scheduledDays)
        assertEquals(4, stats.activeDays)
        assertEquals(2, stats.targetMetDays)
        assertEquals(2, stats.partialDays)
        assertEquals(3, stats.missedDays)
        assertEquals(57, stats.presencePercent)
        assertEquals(29, stats.adherencePercent)
        assertEquals(43, stats.affinityPercent)
        assertEquals(120L, stats.peakDayCount)
        assertEquals(today.minusDays(3), stats.peakDay)
        assertEquals(7, stats.dailyCounts.size)
    }

    @Test
    fun `time estimate uses audio pace and falls back to manual pace`() {
        val audioEstimate = GoalHistoryStatsCalculator.estimateTime(
            totalCount = 125L,
            activeDays = 5,
            activeSessions = 8,
            audioDurationMs = 2_000L,
            audioCountPerPlay = 1,
        )
        val manualEstimate = GoalHistoryStatsCalculator.estimateTime(
            totalCount = 125L,
            activeDays = 5,
            activeSessions = 8,
            audioDurationMs = 0L,
            audioCountPerPlay = 1,
        )

        assertEquals(250L, audioEstimate.totalSeconds)
        assertEquals(50L, audioEstimate.averagePerDaySeconds)
        assertEquals(31L, audioEstimate.averagePerSessionSeconds)
        assertEquals(250L, manualEstimate.totalSeconds)
        assertEquals(2.0, manualEstimate.secondsPerCount, 0.001)
        assertEquals(false, manualEstimate.isAudioBased)
    }

    private fun dailyGoal(startDate: LocalDate): Goal = Goal(
        dhikrId = testId(1),
        targetPolicy = TargetPolicy.PER_DUE_DATE,
        recurrence = GoalRecurrence(goalId = testId(2)),
        slots = listOf(
            GoalSlot(
                id = testId(3),
                goalId = testId(2),
                slotType = GoalSlotType.ANYTIME,
                targetCount = 100,
            ),
        ),
        startDate = startDate,
    )
}
