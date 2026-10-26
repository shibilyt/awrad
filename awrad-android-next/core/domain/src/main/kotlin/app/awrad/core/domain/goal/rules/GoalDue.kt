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
 * A day is due when it's inside the active period, not paused, and on the schedule. Hijri schedules read
 * the day's Hijri date with [hijriCorrections], and are never due outside the Hijri table.
 * Every other rule asks this function; none re-derives it.
 */
public fun GoalDefinition.isDueOn(date: LocalDate, hijriCorrections: HijriCorrections): Boolean =
    isDueOn(date, HijriCalendar(hijriCorrections))

internal fun GoalDefinition.isDueOn(date: LocalDate, hijri: HijriCalendar): Boolean =
    date in activePeriod && paused.none { date in it } && schedule.includes(date, activePeriod.startDate, hijri)

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
    is Schedule.Yearly -> {
        val day = calendarDayOf(date, calendar, hijri)
        day != null && ranges.any { day in it }
    }
}

/** A day as month, day and the month's length, in [calendar]; null outside the Hijri table. */
private data class CalendarDay(val month: Int, val day: Int, val monthLength: Int)

private fun calendarDayOf(date: LocalDate, calendar: CalendarSystem, hijri: HijriCalendar): CalendarDay? =
    when (calendar) {
        CalendarSystem.GREGORIAN -> CalendarDay(date.monthValue, date.dayOfMonth, date.lengthOfMonth())
        CalendarSystem.HIJRI -> hijri.monthOf(date)?.let { CalendarDay(it.month, it.dateOf(date).day, it.length) }
    }

/**
 * Inclusive, and over the year end when the end comes before the start. Range days past the end of the
 * day's month fall on its last day; whether a range wraps is decided by the days as written.
 */
private operator fun YearlyRange.contains(day: CalendarDay): Boolean {
    val key = day.month * MONTH_KEY + day.day
    val from = start.keyIn(day)
    val to = end.keyIn(day)
    return if (end.rawKey < start.rawKey) key >= from || key <= to else key in from..to
}

private val YearlyDay.rawKey: Int get() = month * MONTH_KEY + day

/** This day's key, clamped to [day]'s month length when it's in the same month. */
private fun YearlyDay.keyIn(day: CalendarDay): Int =
    month * MONTH_KEY + if (month == day.month) minOf(this.day, day.monthLength) else this.day

private const val MONTH_KEY = 100
