package app.awrad.awrad_dhikrgoalstracker.ui.screens.dhikrdetail

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import java.time.LocalDate
import kotlin.math.roundToLong

enum class DhikrStatsRange(val windowDays: Long?) {
    THIRTY_DAYS(30),
    NINETY_DAYS(90),
    ALL_TIME(null),
}

data class DhikrDailyCount(
    val date: LocalDate,
    val count: Long,
)

data class DhikrPracticeStats(
    val range: DhikrStatsRange = DhikrStatsRange.THIRTY_DAYS,
    val totalCount: Long = 0,
    val activeDays: Int = 0,
    val activeDayAverage: Long = 0,
    val presencePercent: Int = 0,
    val currentStreak: Int = 0,
    val peakDayCount: Long = 0,
    val dailyCounts: List<DhikrDailyCount> = emptyList(),
)

object DhikrStatsCalculator {

    fun aggregateGoalCounts(
        goalIds: Set<AwradId>,
        dailyCountsByGoal: Map<AwradId, Map<LocalDate, Long>>,
    ): Map<LocalDate, Long> = buildMap {
        goalIds.forEach { goalId ->
            dailyCountsByGoal[goalId].orEmpty().forEach { (date, count) ->
                if (count > 0) put(date, getOrDefault(date, 0L) + count)
            }
        }
    }

    fun calculate(
        dailyCounts: Map<LocalDate, Long>,
        effectiveToday: LocalDate,
        range: DhikrStatsRange,
    ): DhikrPracticeStats {
        val positiveCounts = dailyCounts.filter { (date, count) ->
            !date.isAfter(effectiveToday) && count > 0
        }
        val startDate = range.windowDays
            ?.let { effectiveToday.minusDays(it - 1) }
            ?: positiveCounts.keys.minOrNull()
            ?: return DhikrPracticeStats(range = range)

        val series = generateSequence(startDate) { date ->
            date.plusDays(1).takeUnless { it.isAfter(effectiveToday) }
        }.map { date -> DhikrDailyCount(date, positiveCounts[date] ?: 0L) }
            .toList()

        val active = series.filter { it.count > 0 }
        val total = active.sumOf { it.count }
        val average = if (active.isEmpty()) 0L else (total.toDouble() / active.size).roundToLong()
        val presence = if (series.isEmpty()) {
            0
        } else {
            (active.size * 100.0 / series.size).roundToLong().toInt()
        }

        return DhikrPracticeStats(
            range = range,
            totalCount = total,
            activeDays = active.size,
            activeDayAverage = average,
            presencePercent = presence,
            currentStreak = currentStreak(positiveCounts, effectiveToday),
            peakDayCount = active.maxOfOrNull { it.count } ?: 0L,
            dailyCounts = series,
        )
    }

    private fun currentStreak(
        positiveCounts: Map<LocalDate, Long>,
        effectiveToday: LocalDate,
    ): Int {
        var cursor = if (positiveCounts[effectiveToday].orZero() > 0) {
            effectiveToday
        } else {
            effectiveToday.minusDays(1)
        }
        var streak = 0
        while (positiveCounts[cursor].orZero() > 0) {
            streak += 1
            cursor = cursor.minusDays(1)
        }
        return streak
    }

    private fun Long?.orZero(): Long = this ?: 0L
}
