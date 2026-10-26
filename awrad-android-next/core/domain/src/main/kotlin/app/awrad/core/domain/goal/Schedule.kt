package app.awrad.core.domain.goal

import app.awrad.core.domain.hijri.HijriDate
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.Month

/**
 * Which days a goal is due (CONTEXT.md, "Schedule"). Hijri kinds read the Hijri date of the day, with the
 * account's corrections, and are never due outside the Hijri table.
 * Invalid shapes (an empty set, a zero interval, an impossible day) are rejected on construction.
 */
public sealed interface Schedule {

    public data object EveryDay : Schedule

    public data class Weekdays(val days: Set<DayOfWeek>) : Schedule {
        init {
            require(days.isNotEmpty()) { "A weekday schedule needs at least one weekday" }
        }
    }

    /** Every [every] days from [anchorDate], or from the start date when [anchorDate] is null. */
    public data class EveryNDays(val every: Int, val anchorDate: LocalDate?) : Schedule {
        init {
            require(every in 1..MAX_INTERVAL_DAYS) { "Interval must be 1..$MAX_INTERVAL_DAYS days: $every" }
        }

        public companion object {
            public const val MAX_INTERVAL_DAYS: Int = 366
        }
    }

    /** Days of the month. A day past the month's end falls on its last day (the 31st is 30 April). */
    public data class MonthDays(val days: Set<Int>) : Schedule {
        init {
            require(days.isNotEmpty()) { "A month-day schedule needs at least one day" }
            require(days.all { it in 1..MAX_DAY_OF_MONTH }) { "Month days must be 1..$MAX_DAY_OF_MONTH: $days" }
        }

        public companion object {
            public const val MAX_DAY_OF_MONTH: Int = 31
        }
    }

    public data class SpecificDates(val dates: Set<LocalDate>) : Schedule {
        init {
            require(dates.isNotEmpty()) { "A specific-dates schedule needs at least one date" }
        }
    }

    /** No repeating pattern: due every day of the active period until completed. */
    public data object OneTime : Schedule

    /** Days of every Hijri month. Day 30 falls on the 29th in a 29-day month. */
    public data class HijriMonthDays(val days: Set<Int>) : Schedule {
        init {
            require(days.isNotEmpty()) { "A Hijri month-day schedule needs at least one day" }
            require(days.all { it in 1..HijriDate.MAX_MONTH_LENGTH }) { "Hijri month days must be 1..30: $days" }
        }
    }

    /**
     * Inclusive [ranges] of days every year, in [calendar]. A range whose end comes before its start runs
     * over the year end. Days past a month's end fall on its last day (29 February, Hijri day 30).
     */
    public data class Yearly(val calendar: CalendarSystem, val ranges: List<YearlyRange>) : Schedule {
        init {
            require(ranges.isNotEmpty()) { "A yearly schedule needs at least one range" }
            val days = ranges.flatMap { listOf(it.start, it.end) }
            require(days.all { it.day <= calendar.maxDayOf(it.month) }) { "No such day in the $calendar year: $days" }
        }
    }
}

/** The calendar a yearly schedule's days are in. */
public enum class CalendarSystem {
    GREGORIAN,
    HIJRI,
    ;

    /** The longest a month can be: 29 February is a day, 30 February and Hijri day 31 aren't. */
    internal fun maxDayOf(month: Int): Int = when (this) {
        GREGORIAN -> Month.of(month).maxLength()
        HIJRI -> HijriDate.MAX_MONTH_LENGTH
    }
}

/** A month and day, in a yearly schedule's calendar. */
public data class YearlyDay(val month: Int, val day: Int) {
    init {
        require(month in 1..HijriDate.MONTHS_PER_YEAR) { "Month must be 1..12: $month" }
        require(day >= 1) { "Day must be at least 1: $day" }
    }
}

/** An inclusive range of days in a year; a single day has [start] = [end]. */
public data class YearlyRange(val start: YearlyDay, val end: YearlyDay)
