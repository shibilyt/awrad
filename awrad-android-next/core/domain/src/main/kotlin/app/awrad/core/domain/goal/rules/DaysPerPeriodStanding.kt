package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.DateWindow
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.Requirement
import app.awrad.core.domain.goal.asTimeline
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
 * - The required days are the period's number less its excused days, capped by the due days the window has
 *   (a partial week, pauses, the schedule).
 * - A window that needs no days (outside the active period or the Hijri table, fully paused, all excused) is not due,
 *   with the day as its window.
 *
 * Hijri schedules and Hijri months read [hijriCorrections].
 */
public fun GoalDefinition.daysPerPeriodOn(
    date: LocalDate,
    counts: List<CountEntry>,
    weekStart: WeekStart,
    hijriCorrections: HijriCorrections,
): DaysPerPeriodStanding {
    val requirement = requirement
    require(requirement is Requirement.DaysPerPeriod) { "Not a days-per-period goal: $requirement" }
    val hijri = HijriCalendar(hijriCorrections)
    val window = PeriodCalendar(weekStart, hijri).periodOf(date, requirement.period)
        ?.let(activePeriod::clip)
        ?.takeIf { date in activePeriod }
    val tally = window?.let { GoalDays(asTimeline(), CountIndex(counts), hijri).tally(it, date) }
    return if (window == null || tally == null || tally.required <= 0) {
        DaysPerPeriodStanding(StandingStatus.NOT_DUE, DateWindow.day(date), 0, 0)
    } else {
        val status = if (tally.qualifying >= tally.required) StandingStatus.MET else StandingStatus.NOT_MET
        DaysPerPeriodStanding(status, window, tally.qualifying, tally.required)
    }
}

/** Qualifying due days up to a day, against the days a window requires. */
internal data class DaysTally(val qualifying: Int, val required: Int)

/**
 * Days per period over [window], judged with the version in force on its last day up to [today]: qualifying due days
 * up to [today], and the required number less the window's excused days, capped by its due days.
 */
internal fun GoalDays.tally(window: DateWindow, today: LocalDate): DaysTally {
    val requirement = goalOn(minOf(window.to, today)).requirement as Requirement.DaysPerPeriod
    val due = window.days().filter(::isDue).toList()
    val qualifying = due.count { !it.isAfter(today) && goalOn(it).dayMeetsTarget(it, counts) }
    val excused = window.days().count { it in timeline.excused }
    return DaysTally(qualifying, required = (requirement.days - excused).coerceIn(0, due.size))
}
