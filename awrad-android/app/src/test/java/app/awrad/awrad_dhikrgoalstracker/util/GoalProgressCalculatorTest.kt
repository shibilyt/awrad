package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.testId

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSpecificDate
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

    @Test
    fun `hijri monthly period window spans the civil days of that hijri month`() {
        val goal = goal(
            targetPolicy = TargetPolicy.PERIOD_TOTAL,
            recurrence = GoalRecurrence(
                goalId = testId(1),
                frequency = RecurrenceFrequency.MONTHLY,
                calendar = app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem.HIJRI,
            ),
        )

        val window = GoalProgressCalculator.currentProgressWindow(goal, LocalDate.parse("2026-03-01"))

        assertEquals(LocalDate.parse("2026-02-18"), window?.start)
        assertEquals(LocalDate.parse("2026-03-19"), window?.endInclusive)
    }

    @Test
    fun `interval period window is anchored to recurrence anchor`() {
        val goal = goal(
            targetPolicy = TargetPolicy.PERIOD_TOTAL,
            recurrence = GoalRecurrence(
                goalId = testId(1),
                frequency = RecurrenceFrequency.INTERVAL,
                intervalDays = 7,
                anchorDate = LocalDate.parse("2026-05-01"),
            ),
        )

        val window = GoalProgressCalculator.currentProgressWindow(goal, LocalDate.parse("2026-05-12"))

        assertEquals(LocalDate.parse("2026-05-08"), window?.start)
        assertEquals(LocalDate.parse("2026-05-14"), window?.endInclusive)
    }

    @Test
    fun `yearly contiguous scheduled days form one period total window`() {
        val goal = goal(
            targetPolicy = TargetPolicy.PERIOD_TOTAL,
            recurrence = GoalRecurrence(
                goalId = testId(1),
                frequency = RecurrenceFrequency.YEARLY,
                month = 7,
                monthDays = setOf(1, 2, 3),
            ),
        )

        val window = GoalProgressCalculator.currentProgressWindow(goal, LocalDate.parse("2026-07-02"))

        assertEquals(LocalDate.parse("2026-07-01"), window?.start)
        assertEquals(LocalDate.parse("2026-07-03"), window?.endInclusive)
    }

    @Test
    fun `season contiguous run forms one period total window`() {
        val goal = goal(
            targetPolicy = TargetPolicy.PERIOD_TOTAL,
            recurrence = GoalRecurrence(
                goalId = testId(1),
                frequency = RecurrenceFrequency.SEASON,
                seasonTemplateCode = SeasonTemplateCode.WHITE_DAYS,
            ),
        )

        val window = GoalProgressCalculator.currentProgressWindow(goal, LocalDate.parse("2026-03-03"))

        assertEquals(LocalDate.parse("2026-03-02"), window?.start)
        assertEquals(LocalDate.parse("2026-03-04"), window?.endInclusive)
    }

    @Test
    fun `non contiguous specific dates remain separate period total windows`() {
        val goal = goal(
            targetPolicy = TargetPolicy.PERIOD_TOTAL,
            recurrence = GoalRecurrence(
                goalId = testId(1),
                frequency = RecurrenceFrequency.SPECIFIC_DATES,
                specificDates = setOf(
                    GoalSpecificDate(date = LocalDate.parse("2026-07-01")),
                    GoalSpecificDate(date = LocalDate.parse("2026-07-15")),
                ),
            ),
        )

        val window = GoalProgressCalculator.currentProgressWindow(goal, LocalDate.parse("2026-07-15"))

        assertEquals(LocalDate.parse("2026-07-15"), window?.start)
        assertEquals(LocalDate.parse("2026-07-15"), window?.endInclusive)
    }

    @Test
    fun `streak counts consecutive days that meet the daily target`() {
        val today = LocalDate.parse("2026-05-27")
        val dailyCounts = mapOf(
            today to 100L,
            today.minusDays(1) to 100L,
            today.minusDays(2) to 120L,
            today.minusDays(3) to 50L,
        )

        val streak = GoalProgressCalculator.calculateStreakWithCounts(
            dailyCounts = dailyCounts,
            today = today,
            dailyTarget = 100,
            goal = goal(),
        )

        assertEquals(3, streak.currentStreak)
    }

    @Test
    fun `streak skips unscheduled days but breaks on a scheduled miss`() {
        val today = LocalDate.parse("2026-05-27") // Wednesday
        val dailyCounts = mapOf(
            today to 100L, // Wed
            today.minusDays(1) to 0L, // Tue, unscheduled
            today.minusDays(2) to 100L, // Mon
        )
        val weekly = goal(
            recurrence = GoalRecurrence(
                goalId = testId(1),
                frequency = RecurrenceFrequency.WEEKLY,
                weekdays = setOf(DayOfWeek.MONDAY, DayOfWeek.WEDNESDAY, DayOfWeek.FRIDAY),
            ),
        )

        val streak = GoalProgressCalculator.calculateStreakWithCounts(
            dailyCounts = dailyCounts,
            today = today,
            dailyTarget = 100,
            goal = weekly,
        )

        // Wed + Mon count; the Friday before had no entry, so the streak stops there.
        assertEquals(2, streak.currentStreak)
    }

    @Test
    fun `streak uses minimum streak count when set below the daily target`() {
        val today = LocalDate.parse("2026-05-27")
        val dailyCounts = mapOf(
            today to 15L,
            today.minusDays(1) to 20L,
            today.minusDays(2) to 5L,
        )

        val streak = GoalProgressCalculator.calculateStreakWithCounts(
            dailyCounts = dailyCounts,
            today = today,
            dailyTarget = 100,
            minimumStreakCount = 10,
            goal = goal(),
        )

        assertEquals(2, streak.currentStreak)
    }

    @Test
    fun `recent activity spans the strip with today last and only today flagged`() {
        val today = LocalDate.parse("2026-05-27")

        val days = GoalProgressCalculator.recentActivity(
            goal = goal(),
            dailyCounts = emptyMap(),
            today = today,
        )

        assertEquals(GoalProgressCalculator.STREAK_STRIP_DAYS, days.size)
        assertEquals(today.minusDays(GoalProgressCalculator.STREAK_STRIP_DAYS - 1L), days.first().date)
        assertEquals(today, days.last().date)
        assertTrue(days.last().isToday)
        assertEquals(1, days.count { it.isToday })
        assertEquals(StreakDayStatus.INACTIVE, days.last().status)
    }

    @Test
    fun `recent activity marks complete partial and inactive days by the daily target`() {
        val today = LocalDate.parse("2026-05-27")
        val dailyCounts = mapOf(
            today to 100L,
            today.minusDays(1) to 30L,
        )

        val days = GoalProgressCalculator.recentActivity(
            goal = goal(),
            dailyCounts = dailyCounts,
            today = today,
            days = 3,
        )

        assertEquals(StreakDayStatus.INACTIVE, days[0].status)
        assertEquals(0f, days[0].progress, 0.0001f)
        assertEquals(StreakDayStatus.PARTIAL, days[1].status)
        assertEquals(0.3f, days[1].progress, 0.0001f)
        assertEquals(StreakDayStatus.COMPLETE, days[2].status)
        assertEquals(1f, days[2].progress, 0.0001f)
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
