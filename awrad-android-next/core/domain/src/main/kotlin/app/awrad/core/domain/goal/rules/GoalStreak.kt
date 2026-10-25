package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CalendarPeriod
import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.DateWindow
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.Requirement
import app.awrad.core.domain.practice.WeekStart
import java.time.LocalDate

/**
 * Rule: the current streak on [date] (fixture `goal_streak`), counting back from [date].
 *
 * - Per-due-date, cumulative and tracker goals count consecutive **due days** meeting the
 *   streak threshold (with sessions, each session's own).
 * - Period-total and days-per-period goals count consecutive **weeks or months** meeting
 *   their requirement.
 * - Units that aren't due (unscheduled, paused, outside the active period) are skipped.
 * - The unit containing [date] is in progress: it adds 1 once met and never breaks the streak.
 */
public fun GoalDefinition.streakOn(date: LocalDate, counts: List<CountEntry>, weekStart: WeekStart): Int {
    val index = CountIndex(counts)
    return when (val requirement = requirement) {
        is Requirement.PeriodTotal -> periodStreak(date, index, requirement.period, weekStart)
        is Requirement.DaysPerPeriod -> periodStreak(date, index, requirement.period, weekStart)
        Requirement.PerDueDate, Requirement.CumulativeTotal, Requirement.Tracker -> dayStreak(date, index)
    }
}

private data class StreakUnit(val isInProgress: Boolean, val isMet: Boolean)

private fun Sequence<StreakUnit>.consecutiveMet(): Int =
    dropWhile { it.isInProgress && !it.isMet }.takeWhile { it.isMet }.count()

private fun GoalDefinition.dayStreak(date: LocalDate, counts: CountIndex): Int {
    val latest = activePeriod.lastDay?.let { minOf(date, it) } ?: date
    return generateSequence(latest) { it.minusDays(1) }
        .takeWhile { !it.isBefore(activePeriod.startDate) }
        .filter { isDueOn(it) }
        .map { StreakUnit(isInProgress = it == date, isMet = dayMeets(it, counts, DayMeasure.STREAK_THRESHOLD)) }
        .consecutiveMet()
}

private fun GoalDefinition.periodStreak(
    date: LocalDate,
    counts: CountIndex,
    period: CalendarPeriod,
    weekStart: WeekStart,
): Int = generateSequence(calendarPeriodOf(date, period, weekStart)) {
    calendarPeriodOf(it.from.minusDays(1), period, weekStart)
}
    .takeWhile { !it.to.isBefore(activePeriod.startDate) }
    .mapNotNull { periodUnit(it, date, counts, weekStart) }
    .consecutiveMet()

/** A calendar period's standing, judged on its last counted day; null when it isn't due. */
private fun GoalDefinition.periodUnit(
    calendarPeriod: DateWindow,
    date: LocalDate,
    counts: CountIndex,
    weekStart: WeekStart,
): StreakUnit? {
    val evaluated = listOfNotNull(calendarPeriod.to, date, activePeriod.lastDay).min()
    if (evaluated !in calendarPeriod) return null
    val status = standingOn(evaluated, counts, weekStart).status
    return if (status == StandingStatus.NOT_DUE) {
        null
    } else {
        StreakUnit(isInProgress = evaluated == date, isMet = status == StandingStatus.MET)
    }
}
