package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CountPolicy
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.GoalTimeline
import app.awrad.core.domain.goal.Requirement
import app.awrad.core.domain.goal.StreakThreshold
import app.awrad.core.domain.hijri.HijriCalendar
import java.time.LocalDate

/**
 * A timeline with its counts, evaluated day by day with the version in force each day (README.md, "Dated versions").
 * Rules that look across days share one, so each day's goal, pace and statuses are worked out once.
 */
internal class GoalDays(val timeline: GoalTimeline, val counts: CountIndex, val hijri: HijriCalendar) {
    private val goals = HashMap<LocalDate, GoalDefinition>()
    private val ownEndGoals = HashMap<LocalDate, GoalDefinition>()
    private val paces = HashMap<LocalDate, DailyPace>()
    private val statuses = HashMap<LocalDate, Map<LocalDate, DueDay>>()

    /** The goal on [date], an ended goal's end capping its active period. */
    fun goalOn(date: LocalDate): GoalDefinition = goals.getOrPut(date) { timeline.goalOn(date) }

    /** The goal on [date] with its version's own end, even after it ended early (pace, attribution). */
    fun ownEndGoalOn(date: LocalDate): GoalDefinition =
        ownEndGoals.getOrPut(date) { timeline.goalOn(date, capEnded = false) }

    fun isDue(date: LocalDate): Boolean = goalOn(date).isDueOn(date, hijri)

    fun isScheduled(date: LocalDate): Boolean = goalOn(date).isScheduledOn(date, hijri)

    /** The goal's last day as of [today] (its version's end, or its ended day); null while open-ended. */
    fun lastDay(today: LocalDate): LocalDate? = goalOn(today).activePeriod.lastDay

    /** Up to and including its last day, the goal is still running: its last day or period is in progress. */
    fun isRunning(today: LocalDate): Boolean = lastDay(today)?.let { !today.isAfter(it) } ?: true

    /** The first day of the active period (structural, so every version agrees). */
    val startDate: LocalDate get() = timeline.versions.first().settings.activePeriod.startDate

    fun paceOn(date: LocalDate): DailyPace = paces.getOrPut(date) { dailyPace(date) }

    /** The number a day needs to keep the streak (README.md, "Streaks"). */
    fun streakAmount(policy: CountPolicy, date: LocalDate): Long = when (val threshold = policy.streakThreshold) {
        is StreakThreshold.Amount -> threshold.amount
        StreakThreshold.AnyCount -> 1
        StreakThreshold.DailyPace -> maxOf(1, paceOn(date).pace ?: 1)
        StreakThreshold.Minimum, StreakThreshold.Target, StreakThreshold.Maximum ->
            checkNotNull(policy.streakThresholdValue) { "A valid goal's streak threshold has its value" }
    }

    /** Every due day's status from the start date up to [today] (or the goal's last day), oldest first. */
    fun statusesOn(today: LocalDate): Map<LocalDate, DueDay> = statuses.getOrPut(today) { dayStatuses(today) }

    /** Every day of the active period up to [today] (or the goal's last day), oldest first. */
    fun daysUpTo(today: LocalDate): Sequence<LocalDate> =
        daysBetween(startDate, lastDay(today)?.let { minOf(today, it) } ?: today)

    private fun dailyPace(date: LocalDate): DailyPace {
        val goal = ownEndGoalOn(date)
        if (goal.requirement != Requirement.CumulativeTotal || goal.sessions.isNotEmpty()) return DailyPace.NONE
        val start = goal.activePeriod.startDate
        val before = daysBetween(start, date.minusDays(1))
            .filter { it in goal.activePeriod }
            .sumOf { goal.countOn(it, counts) }
        val remaining = maxOf(0, checkNotNull(goal.countPolicy.target) - before)
        val left = goal.activePeriod.lastDay?.let { last ->
            daysBetween(maxOf(date, start), last).count { ownEndGoalOn(it).isDueOn(it, hijri) }
        }
        val pace = left?.takeIf { it > 0 && goal.isDueOn(date, hijri) }?.let { ceilDiv(remaining, it.toLong()) }
        return DailyPace(pace = pace, remaining = remaining, dueDaysLeft = left)
    }
}

private fun ceilDiv(a: Long, b: Long): Long = (a + b - 1) / b
