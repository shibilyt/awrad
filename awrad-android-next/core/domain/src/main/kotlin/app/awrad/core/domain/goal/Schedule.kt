package app.awrad.core.domain.goal

import java.time.DayOfWeek
import java.time.LocalDate

/**
 * Which days a goal is due, on the Gregorian calendar (CONTEXT.md, "Schedule").
 * Invalid shapes (an empty set, a zero interval) are rejected on construction.
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
}
