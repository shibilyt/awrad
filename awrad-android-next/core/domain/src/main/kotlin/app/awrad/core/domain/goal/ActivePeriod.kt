package app.awrad.core.domain.goal

import java.time.LocalDate

/**
 * The span during which a goal can be due (CONTEXT.md, "Active period"): from [startDate] until
 * [endDate] or the last day of [durationDays] (start + N − 1), whichever comes first. Both ends inclusive.
 */
public data class ActivePeriod(
    val startDate: LocalDate,
    val endDate: LocalDate? = null,
    val durationDays: Int? = null,
) {
    init {
        require(durationDays == null || durationDays in 1..MAX_DURATION_DAYS) {
            "Duration must be 1..$MAX_DURATION_DAYS days: $durationDays"
        }
    }

    /** The last active day, or null when the period is open-ended. */
    public val lastDay: LocalDate?
        get() {
            val durationEnd = durationDays?.let { startDate.plusDays(it - 1L) }
            return listOfNotNull(endDate, durationEnd).minOrNull()
        }

    public operator fun contains(date: LocalDate): Boolean {
        val last = lastDay
        return !date.isBefore(startDate) && (last == null || !date.isAfter(last))
    }

    /** [window] limited to this period, or null when they don't overlap. */
    public fun clip(window: DateWindow): DateWindow? {
        val from = maxOf(window.from, startDate)
        val to = lastDay?.let { minOf(window.to, it) } ?: window.to
        return if (to.isBefore(from)) null else DateWindow(from, to)
    }

    public companion object {
        public const val MAX_DURATION_DAYS: Int = 36_600
    }
}

/** Days the user suspended the goal, inclusive. A null [to] means it's still paused. */
public data class PausedRange(val from: LocalDate, val to: LocalDate?) {
    init {
        require(to == null || !to.isBefore(from)) { "A pause can't end before it starts: $from..$to" }
    }

    public operator fun contains(date: LocalDate): Boolean = !date.isBefore(from) && (to == null || !date.isAfter(to))
}

/** An inclusive range of effective practice days. */
public data class DateWindow(val from: LocalDate, val to: LocalDate) {
    init {
        require(!to.isBefore(from)) { "A window can't end before it starts: $from..$to" }
    }

    public operator fun contains(date: LocalDate): Boolean = !date.isBefore(from) && !date.isAfter(to)

    /** Every day in the window, in order. */
    public fun days(): Sequence<LocalDate> = generateSequence(from) { it.plusDays(1) }.takeWhile { !it.isAfter(to) }

    public companion object {
        public fun day(date: LocalDate): DateWindow = DateWindow(date, date)
    }
}
