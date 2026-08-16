package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import java.time.LocalDate
import kotlin.math.roundToInt
import kotlin.math.roundToLong

enum class GoalHistoryRange(val windowDays: Long?) {
    SEVEN_DAYS(7),
    THIRTY_DAYS(30),
    NINETY_DAYS(90),
    ALL_TIME(null),
}

data class GoalDailyCount(
    val date: LocalDate,
    val count: Long,
)

data class GoalTimeEstimate(
    val totalSeconds: Long = 0L,
    val averagePerDaySeconds: Long = 0L,
    val averagePerSessionSeconds: Long = 0L,
    val secondsPerCount: Double = 2.0,
    val isAudioBased: Boolean = false,
)

data class GoalHistoryStats(
    val totalCount: Long = 0L,
    val activeDays: Int = 0,
    val activeDayAverage: Long = 0L,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val scheduledDays: Int = 0,
    val targetMetDays: Int = 0,
    val partialDays: Int = 0,
    val missedDays: Int = 0,
    val presencePercent: Int = 0,
    val adherencePercent: Int = 0,
    val affinityPercent: Int = 0,
    val goalProgressPercent: Int = 0,
    val peakDay: LocalDate? = null,
    val peakDayCount: Long = 0L,
    val dailyCounts: List<GoalDailyCount> = emptyList(),
    val range: GoalHistoryRange = GoalHistoryRange.ALL_TIME,
)

object GoalHistoryStatsCalculator {
    fun calculate(
        dailyCounts: Map<LocalDate, Long>,
        today: LocalDate,
        dailyTarget: Int,
        minimumStreakCount: Int? = null,
        goal: Goal? = null,
        range: GoalHistoryRange = GoalHistoryRange.ALL_TIME,
    ): GoalHistoryStats {
        val allPositiveCounts = dailyCounts.filter { (date, count) ->
            !date.isAfter(today) && count > 0L
        }
        val firstDate = goal?.startDate ?: allPositiveCounts.keys.minOrNull() ?: today
        val requestedStart = range.windowDays
            ?.let { today.minusDays(it - 1) }
            ?: firstDate
        val startDate = maxOf(firstDate, requestedStart)
        val endDate = minOf(today, goal?.endDate ?: today)
        val series = if (startDate.isAfter(endDate)) {
            emptyList()
        } else {
            generateSequence(startDate) { date ->
                date.plusDays(1).takeUnless { it.isAfter(endDate) }
            }.map { date -> GoalDailyCount(date, allPositiveCounts[date] ?: 0L) }
                .toList()
        }
        val positiveCounts = series
            .filter { it.count > 0L }
            .associate { it.date to it.count }
        val activeDays = positiveCounts.size
        val totalCount = positiveCounts.values.sum()
        val threshold = (minimumStreakCount ?: dailyTarget).coerceAtLeast(1).toLong()
        val allQualifyingDates = allPositiveCounts
            .filterValues { it >= threshold }
            .keys
        val (scheduledDays, targetMetDays, partialDays, missedDays) = goal?.let { configuredGoal ->
            if (configuredGoal.isOneTime) {
                GoalDayBreakdown()
            } else {
                val scheduled = series.filter { GoalProgressCalculator.isScheduledOn(configuredGoal, it.date) }
                val target = dailyTarget.coerceAtLeast(0)
                val met = scheduled.count { day ->
                    if (target == 0) day.count > 0L else day.count >= target
                }
                val partial = scheduled.count { day ->
                    target > 0 && day.count in 1L until target.toLong()
                }
                GoalDayBreakdown(
                    scheduledDays = scheduled.size,
                    targetMetDays = met,
                    partialDays = partial,
                    missedDays = (scheduled.size - met - partial).coerceAtLeast(0),
                )
            }
        } ?: GoalDayBreakdown(
            scheduledDays = series.size,
            targetMetDays = positiveCounts.size,
            missedDays = (series.size - positiveCounts.size).coerceAtLeast(0),
        )
        val presencePercent = percentage(
            numerator = if (scheduledDays > 0) {
                series.count { it.count > 0L && (goal == null || GoalProgressCalculator.isScheduledOn(goal, it.date)) }
            } else {
                activeDays
            },
            denominator = scheduledDays.takeIf { it > 0 } ?: series.size,
        )
        val adherencePercent = percentage(targetMetDays, scheduledDays)
        val affinityPercent = when {
            goal?.isOneTime == true -> goalProgressPercent(totalCount, dailyTarget)
            scheduledDays == 0 -> presencePercent
            dailyTarget <= 0 -> presencePercent
            else -> ((presencePercent + adherencePercent) / 2f).roundToInt()
        }
        val peak = positiveCounts.maxByOrNull { it.value }

        return GoalHistoryStats(
            totalCount = totalCount,
            activeDays = activeDays,
            activeDayAverage = if (activeDays == 0) 0L else {
                (totalCount.toDouble() / activeDays).roundToLong()
            },
            currentStreak = currentStreak(
                activeDates = allPositiveCounts.keys,
                qualifyingDates = allQualifyingDates,
                today = today,
                goal = goal,
            ),
            longestStreak = longestStreak(allQualifyingDates, goal),
            scheduledDays = scheduledDays,
            targetMetDays = targetMetDays,
            partialDays = partialDays,
            missedDays = missedDays,
            presencePercent = presencePercent,
            adherencePercent = adherencePercent,
            affinityPercent = affinityPercent,
            goalProgressPercent = goalProgressPercent(totalCount, dailyTarget),
            peakDay = peak?.key,
            peakDayCount = peak?.value ?: 0L,
            dailyCounts = series,
            range = range,
        )
    }

    fun estimateTime(
        totalCount: Long,
        activeDays: Int,
        activeSessions: Int,
        audioDurationMs: Long,
        audioCountPerPlay: Int,
    ): GoalTimeEstimate {
        val isAudioBased = audioDurationMs > 0L && audioCountPerPlay > 0
        val secondsPerCount = if (isAudioBased) {
            (audioDurationMs / 1000.0) / audioCountPerPlay
        } else {
            // Keep this consistent with the existing counting estimate: approximately 30/min.
            2.0
        }
        val totalSeconds = (totalCount * secondsPerCount).roundToLong()
        return GoalTimeEstimate(
            totalSeconds = totalSeconds,
            averagePerDaySeconds = if (activeDays == 0) 0L else {
                (totalSeconds.toDouble() / activeDays).roundToLong()
            },
            averagePerSessionSeconds = if (activeSessions == 0) 0L else {
                (totalSeconds.toDouble() / activeSessions).roundToLong()
            },
            secondsPerCount = secondsPerCount,
            isAudioBased = isAudioBased,
        )
    }

    private fun currentStreak(
        activeDates: Set<LocalDate>,
        qualifyingDates: Set<LocalDate>,
        today: LocalDate,
        goal: Goal?,
    ): Int {
        var cursor = if (today in activeDates) today else today.minusDays(1)
        var streak = 0
        var inspectedDays = 0
        while (inspectedDays <= 366) {
            if (goal != null && !GoalProgressCalculator.isScheduledOn(goal, cursor)) {
                cursor = cursor.minusDays(1)
                inspectedDays += 1
                continue
            }
            if (cursor !in qualifyingDates) break
            streak += 1
            cursor = cursor.minusDays(1)
            inspectedDays += 1
        }
        return streak
    }

    private fun longestStreak(dates: Set<LocalDate>, goal: Goal?): Int {
        if (dates.isEmpty()) return 0
        var longest = 0
        val firstDate = dates.minOrNull() ?: return 0
        val lastDate = dates.maxOrNull() ?: return 0
        var cursor = firstDate
        var length = 0
        while (!cursor.isAfter(lastDate)) {
            if (goal != null && !GoalProgressCalculator.isScheduledOn(goal, cursor)) {
                cursor = cursor.plusDays(1)
                continue
            }
            if (cursor in dates) {
                length += 1
                longest = maxOf(longest, length)
            } else {
                length = 0
            }
            cursor = cursor.plusDays(1)
        }
        return longest
    }

    private fun percentage(numerator: Int, denominator: Int): Int =
        if (denominator <= 0) 0 else {
            (numerator * 100.0 / denominator).roundToInt().coerceIn(0, 100)
        }

    private fun goalProgressPercent(totalCount: Long, target: Int): Int =
        if (target <= 0) 0 else {
            (totalCount * 100.0 / target).roundToInt().coerceIn(0, 100)
        }
}

private data class GoalDayBreakdown(
    val scheduledDays: Int = 0,
    val targetMetDays: Int = 0,
    val partialDays: Int = 0,
    val missedDays: Int = 0,
)
