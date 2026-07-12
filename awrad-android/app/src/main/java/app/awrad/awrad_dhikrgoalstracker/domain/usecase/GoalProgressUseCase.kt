package app.awrad.awrad_dhikrgoalstracker.domain.usecase

import app.awrad.awrad_dhikrgoalstracker.data.model.CountEntry
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.util.DateWindow
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOrNull
import java.time.LocalDate
import javax.inject.Inject

data class GoalProgressSummary(
    val progressCount: Long,
    val targetCount: Int,
    val progress: Float,
    val remainingCount: Long,
    val targetDisplay: String,
)

class GoalProgressUseCase @Inject constructor() {

    fun isDueOn(goal: Goal, date: LocalDate): Boolean =
        GoalProgressCalculator.isDueToday(goal, date)

    /**
     * Progress summary from raw positive [entries]. Retained as the pure, unit-tested reference form;
     * production reads use the pre-aggregated [Map] overload below (fed by SQL GROUP BY aggregates).
     */
    fun summarize(goal: Goal, entries: List<CountEntry>, date: LocalDate): GoalProgressSummary {
        val progressCount = progressCountFor(goal, entries, date)
        return summarize(goal, progressCount)
    }

    /** Progress summary from pre-aggregated per-day totals ([dailyCounts] = date -> summed count). */
    fun summarize(goal: Goal, dailyCounts: Map<LocalDate, Long>, date: LocalDate): GoalProgressSummary =
        summarize(goal, progressCountFor(goal, dailyCounts, date))

    /**
     * Progress count from pre-aggregated per-day totals. Byte-identical to the [List] overload: the
     * per-date, all-time, and window sums are derived from the already-summed [dailyCounts] map whose
     * keys are the goal's active dates over positive rows.
     */
    fun progressCountFor(goal: Goal, dailyCounts: Map<LocalDate, Long>, date: LocalDate): Long =
        progressCountForPolicy(
            goal = goal,
            date = date,
            countForDate = { targetDate -> dailyCounts[targetDate] ?: 0L },
            totalCount = { dailyCounts.values.sum() },
            countBetween = { window ->
                dailyCounts.entries.sumOf { (entryDate, count) ->
                    if (!entryDate.isBefore(window.start) && !entryDate.isAfter(window.endInclusive)) count else 0L
                }
            },
        )

    fun progressCountFor(goal: Goal, entries: List<CountEntry>, date: LocalDate): Long {
        val goalEntries = entries.filter { it.goalId == goal.id }
        return progressCountForPolicy(
            goal = goal,
            date = date,
            countForDate = { targetDate ->
                goalEntries.filter { it.date == targetDate.toString() }.sumOf { it.count }
            },
            totalCount = {
                goalEntries.sumOf { it.count }
            },
            countBetween = { window ->
                goalEntries.mapNotNull { entry ->
                    val entryDate = entry.date.toLocalDateOrNull() ?: return@mapNotNull null
                    if (
                        !entryDate.isBefore(window.start) && !entryDate.isAfter(window.endInclusive)
                    ) entry.count else null
                }.sum()
            },
        )
    }

    suspend fun progressCountFor(
        goal: Goal,
        date: LocalDate,
        countForDate: suspend (LocalDate) -> Long,
        totalCount: suspend () -> Long,
        countBetween: suspend (DateWindow) -> Long,
    ): Long = when (goal.targetPolicy) {
        TargetPolicy.CUMULATIVE_TOTAL -> totalCount()
        TargetPolicy.PERIOD_TOTAL -> {
            val window = GoalProgressCalculator.currentProgressWindow(goal, date)
            if (window == null) totalCount() else countBetween(window)
        }
        TargetPolicy.PER_DUE_DATE, TargetPolicy.NONE -> countForDate(date)
    }

    private fun summarize(goal: Goal, progressCount: Long): GoalProgressSummary =
        GoalProgressSummary(
            progressCount = progressCount,
            targetCount = GoalProgressCalculator.getTotalDailyTarget(goal),
            progress = GoalProgressCalculator.getProgress(progressCount, goal),
            remainingCount = GoalProgressCalculator.getRemainingCount(progressCount, goal),
            targetDisplay = GoalProgressCalculator.getFormattedTarget(goal),
        )

    private fun progressCountForPolicy(
        goal: Goal,
        date: LocalDate,
        countForDate: (LocalDate) -> Long,
        totalCount: () -> Long,
        countBetween: (DateWindow) -> Long,
    ): Long = when (goal.targetPolicy) {
        TargetPolicy.CUMULATIVE_TOTAL -> totalCount()
        TargetPolicy.PERIOD_TOTAL -> {
            val window = GoalProgressCalculator.currentProgressWindow(goal, date)
            if (window == null) totalCount() else countBetween(window)
        }
        TargetPolicy.PER_DUE_DATE, TargetPolicy.NONE -> countForDate(date)
    }
}
