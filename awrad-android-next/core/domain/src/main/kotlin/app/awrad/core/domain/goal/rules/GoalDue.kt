package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.CalendarSystem
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.Schedule
import app.awrad.core.domain.goal.YearlyDay
import app.awrad.core.domain.goal.YearlyRange
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.hijri.HijriCorrections
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Rule: whether the goal is due on [date] (fixture `goal_is_due`).
 *
 * A day is due when it's inside the active period, on the schedule, not paused and not excused. Hijri schedules read
 * the day's Hijri date with [hijriCorrections], and are never due outside the Hijri table.
 * Every other rule asks this function; none re-derives it.
 */
public fun GoalDefinition.isDueOn(date: LocalDate, hijriCorrections: HijriCorrections): Boolean =
    isDueOn(date, HijriCalendar(hijriCorrections))

internal fun GoalDefinition.isDueOn(date: LocalDate, hijri: HijriCalendar): Boolean =
    isScheduledOn(date, hijri) && !isPausedOn(date) && date !in excused

/** Inside the active period and on the schedule, ignoring pauses and excused days. */
internal fun GoalDefinition.isScheduledOn(date: LocalDate, hijri: HijriCalendar): Boolean =
    date in activePeriod && schedule.includes(date, activePeriod.startDate, hijri)

internal fun GoalDefinition.isPausedOn(date: LocalDate): Boolean = paused.any { date in it }

private fun Schedule.includes(date: LocalDate, startDate: LocalDate, hijri: HijriCalendar): Boolean = when (this) {
    Schedule.EveryDay, Schedule.OneTime -> true
    is Schedule.Weekdays -> date.dayOfWeek in days
    is Schedule.EveryNDays -> {
        val sinceAnchor = ChronoUnit.DAYS.between(anchorDate ?: startDate, date)
        sinceAnchor >= 0 && sinceAnchor % every == 0L
    }
    is Schedule.MonthDays -> days.any { minOf(it, date.lengthOfMonth()) == date.dayOfMonth }
    is Schedule.SpecificDates -> date in dates
    is Schedule.HijriMonthDays -> {
        val month = hijri.monthOf(date)
        month != null && days.any { minOf(it, month.length) == month.dateOf(date).day }
    }
    is Schedule.Yearly -> matchOn(date, hijri) != null
}

/** A day as year, month, day and the month's length, in a yearly schedule's calendar. */
internal data class CalendarDay(val year: Int, val month: Int, val day: Int, val monthLength: Int)

/** The first of a yearly schedule's ranges that holds a day, and the day in the schedule's calendar. */
internal data class YearlyMatch(val range: YearlyRange, val day: CalendarDay) {

    /**
     * The occasion (README.md, "Streaks"): the year in the schedule's calendar. A range that runs over the year end
     * belongs to the year it starts in.
     */
    val occasionYear: Int
        get() = if (range.wraps && day.key <= range.end.keyIn(day)) day.year - 1 else day.year
}

/** The range holding [date] and the day in this schedule's calendar; null when none does or outside the Hijri table. */
internal fun Schedule.Yearly.matchOn(date: LocalDate, hijri: HijriCalendar): YearlyMatch? {
    val day = when (calendar) {
        CalendarSystem.GREGORIAN -> CalendarDay(date.year, date.monthValue, date.dayOfMonth, date.lengthOfMonth())
        CalendarSystem.HIJRI -> hijri.monthOf(date)?.let { month ->
            CalendarDay(month.year, month.month, month.dateOf(date).day, month.length)
        }
    } ?: return null
    return ranges.firstOrNull { day in it }?.let { YearlyMatch(it, day) }
}

/**
 * Inclusive, and over the year end when the end comes before the start. Range days past the end of the
 * day's month fall on its last day; whether a range wraps is decided by the days as written.
 */
private operator fun YearlyRange.contains(day: CalendarDay): Boolean {
    val from = start.keyIn(day)
    val to = end.keyIn(day)
    return if (wraps) day.key >= from || day.key <= to else day.key in from..to
}

private val YearlyRange.wraps: Boolean get() = end.rawKey < start.rawKey

private val CalendarDay.key: Int get() = month * MONTH_KEY + day

private val YearlyDay.rawKey: Int get() = month * MONTH_KEY + day

/** This day's key, clamped to [day]'s month length when it's in the same month. */
private fun YearlyDay.keyIn(day: CalendarDay): Int =
    month * MONTH_KEY + if (month == day.month) minOf(this.day, day.monthLength) else this.day

private const val MONTH_KEY = 100
