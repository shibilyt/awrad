package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.BuiltInSeasonTemplates
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters
import java.time.chrono.HijrahDate
import java.time.temporal.ChronoField
import java.time.temporal.ChronoUnit

object GoalProgressCalculator {

    fun getTargetCount(goal: Goal): Int =
        goal.slots.sumOf { it.targetCount ?: 0 }.coerceAtLeast(if (goal.targetPolicy == TargetPolicy.NONE) 0 else 1)

    fun getTotalDailyTarget(goal: Goal): Int = getTargetCount(goal)

    fun getDailyProgress(todayCount: Long, goal: Goal): Float = getProgress(todayCount, goal)

    fun getProgress(progressCount: Long, goal: Goal): Float {
        if (goal.targetPolicy == TargetPolicy.NONE) return if (progressCount > 0) 1f else 0f
        val target = getTargetCount(goal)
        if (target <= 0) return 0f
        return (progressCount.toFloat() / target).coerceIn(0f, 1f)
    }

    fun getRemainingCount(progressCount: Long, goal: Goal): Long {
        if (goal.targetPolicy == TargetPolicy.NONE) return 0
        val target = getTargetCount(goal).toLong()
        return (target - progressCount).coerceAtLeast(0)
    }

    fun isGoalComplete(goal: Goal): Boolean {
        return when (goal.targetPolicy) {
            TargetPolicy.CUMULATIVE_TOTAL -> goal.totalCompletedCount >= getTargetCount(goal)
            TargetPolicy.PER_DUE_DATE, TargetPolicy.PERIOD_TOTAL, TargetPolicy.NONE -> goal.completedAt != null
        }
    }

    fun isDueToday(goal: Goal, date: LocalDate = LocalDate.now()): Boolean {
        if (!goal.isActive || goal.completedAt != null) return false
        if (date.isBefore(goal.startDate)) return false
        goal.endDate?.let { if (date.isAfter(it)) return false }
        goal.durationDays?.let {
            val daysSinceStart = ChronoUnit.DAYS.between(goal.startDate, date)
            if (daysSinceStart >= it) return false
        }
        return isScheduledOnDate(goal.recurrence, date, goal.startDate)
    }

    private fun isScheduledOnDate(recurrence: GoalRecurrence, date: LocalDate, startDate: LocalDate): Boolean {
        return when (recurrence.frequency) {
            RecurrenceFrequency.DAILY -> true
            RecurrenceFrequency.WEEKLY -> {
                recurrence.weekdays.isEmpty() || date.dayOfWeek in recurrence.weekdays
            }
            RecurrenceFrequency.MONTHLY -> {
                if (recurrence.monthDays.isEmpty()) return true
                if (recurrence.calendar == CalendarSystem.HIJRI) {
                    val hijri = HijrahDate.from(date)
                    hijri.get(ChronoField.DAY_OF_MONTH) in recurrence.monthDays
                } else {
                    date.dayOfMonth in recurrence.monthDays
                }
            }
            RecurrenceFrequency.INTERVAL -> {
                val interval = recurrence.intervalDays?.coerceAtLeast(1) ?: 1
                val anchor = recurrence.anchorDate ?: startDate
                val daysSinceStart = ChronoUnit.DAYS.between(anchor, date)
                daysSinceStart >= 0 && daysSinceStart % interval == 0L
            }
            RecurrenceFrequency.YEARLY -> {
                val month = recurrence.month ?: return true
                val days = recurrence.monthDays.ifEmpty {
                    recurrence.specificDates.mapNotNull { it.dayOfMonth }.toSet()
                }
                if (recurrence.calendar == CalendarSystem.HIJRI) {
                    val hijri = HijrahDate.from(date)
                    hijri.get(ChronoField.MONTH_OF_YEAR) == month &&
                        (days.isEmpty() || hijri.get(ChronoField.DAY_OF_MONTH) in days)
                } else {
                    date.monthValue == month && (days.isEmpty() || date.dayOfMonth in days)
                }
            }
            RecurrenceFrequency.SEASON -> isSeasonDate(recurrence, date)
            RecurrenceFrequency.SPECIFIC_DATES -> {
                recurrence.specificDates.any { specific ->
                    when {
                        specific.date != null -> specific.date == date
                        specific.calendar == CalendarSystem.HIJRI -> {
                            val hijri = HijrahDate.from(date)
                            hijri.get(ChronoField.MONTH_OF_YEAR) == specific.month &&
                                hijri.get(ChronoField.DAY_OF_MONTH) == specific.dayOfMonth
                        }
                        else -> date.monthValue == specific.month && date.dayOfMonth == specific.dayOfMonth
                    }
                }
            }
        }
    }

    private fun isSeasonDate(recurrence: GoalRecurrence, date: LocalDate): Boolean {
        val template = BuiltInSeasonTemplates.find(recurrence.seasonTemplateCode) ?: return false
        val hijri = HijrahDate.from(date)
        val day = hijri.get(ChronoField.DAY_OF_MONTH)
        val month = hijri.get(ChronoField.MONTH_OF_YEAR)
        return if (template.code.name == "WHITE_DAYS") {
            day in template.days
        } else {
            month == template.month && day in template.days
        }
    }

    fun currentProgressWindow(goal: Goal, today: LocalDate): DateWindow? {
        return when (goal.targetPolicy) {
            TargetPolicy.PER_DUE_DATE -> DateWindow(today, today)
            TargetPolicy.CUMULATIVE_TOTAL -> null
            TargetPolicy.NONE -> DateWindow(today, today)
            TargetPolicy.PERIOD_TOTAL -> currentPeriodWindow(goal.recurrence, today, goal.startDate)
        }
    }

    private fun currentPeriodWindow(recurrence: GoalRecurrence, today: LocalDate, startDate: LocalDate): DateWindow {
        return when (recurrence.frequency) {
            RecurrenceFrequency.WEEKLY -> DateWindow(
                today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)),
                today.with(TemporalAdjusters.nextOrSame(DayOfWeek.SUNDAY)),
            )
            RecurrenceFrequency.MONTHLY -> {
                if (recurrence.calendar == CalendarSystem.HIJRI) {
                    hijriMonthWindow(today)
                } else {
                    DateWindow(today.withDayOfMonth(1), today.withDayOfMonth(today.lengthOfMonth()))
                }
            }
            RecurrenceFrequency.INTERVAL -> {
                val interval = recurrence.intervalDays?.coerceAtLeast(1) ?: 1
                val anchor = recurrence.anchorDate ?: startDate
                val daysSinceStart = ChronoUnit.DAYS.between(anchor, today).coerceAtLeast(0)
                val periodIndex = daysSinceStart / interval
                val start = anchor.plusDays(periodIndex * interval)
                DateWindow(start, start.plusDays(interval.toLong() - 1))
            }
            RecurrenceFrequency.YEARLY, RecurrenceFrequency.SEASON, RecurrenceFrequency.SPECIFIC_DATES ->
                scheduledRunWindow(recurrence, today, startDate)
            RecurrenceFrequency.DAILY -> DateWindow(today, today)
        }
    }

    private fun hijriMonthWindow(today: LocalDate): DateWindow {
        val hijriToday = HijrahDate.from(today)
        val month = hijriToday.get(ChronoField.MONTH_OF_YEAR)
        val year = hijriToday.get(ChronoField.YEAR)

        var start = today
        while (sameHijriMonth(start.minusDays(1), year, month)) {
            start = start.minusDays(1)
        }

        var end = today
        while (sameHijriMonth(end.plusDays(1), year, month)) {
            end = end.plusDays(1)
        }

        return DateWindow(start, end)
    }

    private fun sameHijriMonth(date: LocalDate, year: Int, month: Int): Boolean {
        val hijri = HijrahDate.from(date)
        return hijri.get(ChronoField.YEAR) == year &&
            hijri.get(ChronoField.MONTH_OF_YEAR) == month
    }

    private fun scheduledRunWindow(
        recurrence: GoalRecurrence,
        today: LocalDate,
        startDate: LocalDate,
    ): DateWindow {
        if (!isScheduledOnDate(recurrence, today, startDate)) {
            return DateWindow(today, today)
        }

        var start = today
        while (
            ChronoUnit.DAYS.between(start, today) < 370 &&
            isScheduledOnDate(recurrence, start.minusDays(1), startDate)
        ) {
            start = start.minusDays(1)
        }

        var end = today
        while (
            ChronoUnit.DAYS.between(today, end) < 370 &&
            isScheduledOnDate(recurrence, end.plusDays(1), startDate)
        ) {
            end = end.plusDays(1)
        }

        return DateWindow(start, end)
    }

    fun getFormattedTarget(goal: Goal): String {
        if (goal.targetPolicy == TargetPolicy.NONE) return "Tracker"
        val totalTarget = getTargetCount(goal)
        return when (goal.targetPolicy) {
            TargetPolicy.CUMULATIVE_TOTAL -> "$totalTarget total"
            TargetPolicy.PERIOD_TOTAL -> "$totalTarget${periodSuffix(goal.recurrence)}"
            TargetPolicy.PER_DUE_DATE -> {
                if (goal.isPrayerBased) "${goal.slots.size} slots · $totalTarget total"
                else "$totalTarget${dueDateSuffix(goal.recurrence)}"
            }
            TargetPolicy.NONE -> "Tracker"
        }
    }

    private fun dueDateSuffix(recurrence: GoalRecurrence): String {
        return when (recurrence.frequency) {
            RecurrenceFrequency.DAILY -> "/day"
            RecurrenceFrequency.WEEKLY -> "/due day"
            RecurrenceFrequency.MONTHLY -> "/due day"
            RecurrenceFrequency.INTERVAL -> "/due day"
            RecurrenceFrequency.YEARLY, RecurrenceFrequency.SEASON, RecurrenceFrequency.SPECIFIC_DATES -> "/due day"
        }
    }

    private fun periodSuffix(recurrence: GoalRecurrence): String {
        return when (recurrence.frequency) {
            RecurrenceFrequency.WEEKLY -> "/week"
            RecurrenceFrequency.MONTHLY -> "/month"
            RecurrenceFrequency.INTERVAL -> "/period"
            RecurrenceFrequency.SEASON -> "/season"
            RecurrenceFrequency.YEARLY, RecurrenceFrequency.SPECIFIC_DATES -> "/year"
            RecurrenceFrequency.DAILY -> "/day"
        }
    }

    fun calculateStreakWithCounts(
        dailyCounts: Map<LocalDate, Long>,
        today: LocalDate = LocalDate.now(),
        dailyTarget: Int = 0,
        minimumStreakCount: Int? = null,
        goal: Goal? = null,
    ): StreakInfo {
        val dateSet = dailyCounts.keys.toHashSet()
        val threshold = minimumStreakCount ?: dailyTarget
        // A streak day must have real activity. For tracker goals the threshold is 0,
        // so coerce to at least 1 — otherwise an empty (count == 0) day would satisfy
        // `count < threshold` == `0 < 0` == false and the loop would never terminate.
        val streakThreshold = threshold.coerceAtLeast(1)

        var streak = 0
        var checkDate = if (dateSet.contains(today)) today else today.minusDays(1)
        while (ChronoUnit.DAYS.between(checkDate, today) <= 366) {
            if (goal != null && !isScheduledOnDate(goal.recurrence, checkDate, goal.startDate)) {
                checkDate = checkDate.minusDays(1)
                continue
            }
            val count = dailyCounts[checkDate] ?: 0L
            if (count < streakThreshold) break
            streak++
            checkDate = checkDate.minusDays(1)
        }

        return StreakInfo(
            currentStreak = streak,
            activeDates = dateSet,
            dailyCounts = dailyCounts,
            minimumStreakCount = threshold,
        )
    }

    /** Whether [goal] is scheduled to recur on [date] (ignores active/completed/window gating). */
    fun isScheduledOn(goal: Goal, date: LocalDate): Boolean =
        isScheduledOnDate(goal.recurrence, date, goal.startDate)

    /** History depth for streak strips — enough to fill even a tablet-width row. */
    const val STREAK_STRIP_DAYS = 42

    /**
     * Recent activity for a goal, mirroring the wird week strip: one [GoalDayActivity] per day for
     * the last [days] days (oldest first). A day is COMPLETE when its count meets the goal's daily
     * target (or any activity for tracker goals), PARTIAL when there's some count below target.
     * The strip UI renders only the trailing days that fit its width.
     */
    fun recentActivity(
        goal: Goal,
        dailyCounts: Map<LocalDate, Long>,
        today: LocalDate = LocalDate.now(),
        days: Int = STREAK_STRIP_DAYS,
        dailySlotCounts: Map<LocalDate, Map<Long, Long>> = emptyMap(),
    ): List<GoalDayActivity> {
        val target = getTargetCount(goal)
        // Historical days render against the current slot set — per-day slot history isn't
        // recorded, same approximation as target changes.
        val activeSlots = goal.slots.filter { it.isActive }.sortedBy { it.sortOrder }
        return (days - 1 downTo 0).map { offset ->
            val date = today.minusDays(offset.toLong())
            val count = dailyCounts[date] ?: 0L
            val status = when {
                count <= 0L -> StreakDayStatus.INACTIVE
                target <= 0 || count >= target -> StreakDayStatus.COMPLETE
                else -> StreakDayStatus.PARTIAL
            }
            val progress = when {
                target > 0 -> (count.toFloat() / target).coerceIn(0f, 1f)
                count > 0L -> 1f
                else -> 0f
            }
            val slotCounts = dailySlotCounts[date].orEmpty()
            val slotProgress = activeSlots.map { slot ->
                val slotCount = slotCounts[slot.id] ?: 0L
                val slotTarget = slot.targetCount ?: 0
                when {
                    slotTarget > 0 -> (slotCount.toFloat() / slotTarget).coerceIn(0f, 1f)
                    slotCount > 0L -> 1f
                    else -> 0f
                }
            }
            GoalDayActivity(
                date = date,
                isScheduled = isScheduledOnDate(goal.recurrence, date, goal.startDate),
                status = status,
                isToday = date == today,
                progress = progress,
                slotProgress = slotProgress,
            )
        }
    }
}

data class DateWindow(val start: LocalDate, val endInclusive: LocalDate)

enum class StreakDayStatus { COMPLETE, PARTIAL, INACTIVE }

/** One day in a goal's recent-activity strip (the per-goal equivalent of the wird week strip). */
data class GoalDayActivity(
    val date: LocalDate,
    val isScheduled: Boolean,
    val status: StreakDayStatus,
    val isToday: Boolean,
    /** That day's count as a fraction of the daily target (0..1). */
    val progress: Float = 0f,
    /** That day's per-slot fractions (0..1), one per active slot in sort order. */
    val slotProgress: List<Float> = emptyList(),
)

data class StreakInfo(
    val currentStreak: Int = 0,
    val activeDates: Set<LocalDate> = emptySet(),
    val dailyCounts: Map<LocalDate, Long> = emptyMap(),
    val minimumStreakCount: Int = 0,
) {
    fun statusForDate(date: LocalDate): StreakDayStatus {
        val count = dailyCounts[date] ?: 0L
        return when {
            count <= 0L -> StreakDayStatus.INACTIVE
            minimumStreakCount > 0 && count >= minimumStreakCount -> StreakDayStatus.COMPLETE
            count > 0L -> StreakDayStatus.PARTIAL
            else -> StreakDayStatus.INACTIVE
        }
    }
}
