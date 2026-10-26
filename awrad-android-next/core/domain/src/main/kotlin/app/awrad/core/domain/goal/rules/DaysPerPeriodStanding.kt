package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.DateWindow
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.Requirement
import app.awrad.core.domain.practice.WeekStart
import java.time.LocalDate

/** Qualifying days against required days in one week or month. */
public data class DaysPerPeriodStanding(
    val status: StandingStatus,
    val window: DateWindow,
    val qualifyingDays: Int,
    val requiredDays: Int,
)

/**
 * Rule: days per period on [date] (fixture `days_per_period`). Only for [Requirement.DaysPerPeriod] goals.
 *
 * - The window is the week or month containing [date], clipped to the active period.
 * - A day qualifies when it's due, on or before [date], and meets the daily target
 *   (with sessions, every session meets its own).
 * - The required days are capped by the due days the window has (a partial week, pauses, the schedule).
 * - A window with no due days (outside the active period, fully paused) is not due, with the day as its window.
 */
public fun GoalDefinition.daysPerPeriodOn(
    date: LocalDate,
    counts: List<CountEntry>,
    weekStart: WeekStart,
): DaysPerPeriodStanding = daysPerPeriodOn(date, CountIndex(counts), weekStart)

internal fun GoalDefinition.daysPerPeriodOn(
    date: LocalDate,
    counts: CountIndex,
    weekStart: WeekStart,
): DaysPerPeriodStanding {
    val requirement = requirement
    require(requirement is Requirement.DaysPerPeriod) { "Not a days-per-period goal: $requirement" }
    val window = activePeriod.clip(calendarPeriodOf(date, requirement.period, weekStart))
        ?.takeIf { date in activePeriod }
    val dueDays = window?.days()?.filter { isDueOn(it) }?.toList().orEmpty()
    if (window == null || dueDays.isEmpty()) {
        return DaysPerPeriodStanding(StandingStatus.NOT_DUE, DateWindow.day(date), 0, 0)
    }
    val requiredDays = minOf(requirement.days, dueDays.size)
    val qualifyingDays = dueDays.count { !it.isAfter(date) && dayMeets(it, counts, DayMeasure.TARGET) }
    val status = if (qualifyingDays >= requiredDays) StandingStatus.MET else StandingStatus.NOT_MET
    return DaysPerPeriodStanding(status, window, qualifyingDays, requiredDays)
}
