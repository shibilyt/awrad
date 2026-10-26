package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.DateWindow
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.Requirement
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.hijri.HijriCorrections
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
 * - The window is the week, month or Hijri month containing [date], clipped to the active period.
 * - A day qualifies when it's due, on or before [date], and meets the daily target
 *   (with sessions, every session meets its own).
 * - The required days are capped by the due days the window has (a partial week, pauses, the schedule).
 * - A window with no due days (outside the active period or the Hijri table, fully paused) is not due,
 *   with the day as its window.
 *
 * Hijri schedules and Hijri months read [hijriCorrections].
 */
public fun GoalDefinition.daysPerPeriodOn(
    date: LocalDate,
    counts: List<CountEntry>,
    weekStart: WeekStart,
    hijriCorrections: HijriCorrections,
): DaysPerPeriodStanding =
    daysPerPeriodOn(date, CountIndex(counts), PeriodCalendar(weekStart, HijriCalendar(hijriCorrections)))

internal fun GoalDefinition.daysPerPeriodOn(
    date: LocalDate,
    counts: CountIndex,
    calendar: PeriodCalendar,
): DaysPerPeriodStanding {
    val requirement = requirement
    require(requirement is Requirement.DaysPerPeriod) { "Not a days-per-period goal: $requirement" }
    val window = calendar.periodOf(date, requirement.period)
        ?.let(activePeriod::clip)
        ?.takeIf { date in activePeriod }
    val dueDays = window?.days()?.filter { isDueOn(it, calendar.hijri) }?.toList().orEmpty()
    if (window == null || dueDays.isEmpty()) {
        return DaysPerPeriodStanding(StandingStatus.NOT_DUE, DateWindow.day(date), 0, 0)
    }
    val requiredDays = minOf(requirement.days, dueDays.size)
    val qualifyingDays = dueDays.count { !it.isAfter(date) && dayMeets(it, counts, DayMeasure.TARGET) }
    val status = if (qualifyingDays >= requiredDays) StandingStatus.MET else StandingStatus.NOT_MET
    return DaysPerPeriodStanding(status, window, qualifyingDays, requiredDays)
}
