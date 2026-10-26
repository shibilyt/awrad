package app.awrad.core.domain.hijri

import java.time.LocalDate

/** A date in the Hijri calendar (CONTEXT.md, "Hijri date"): `hijri_date` in the hijri-calendar schema. */
public data class HijriDate(val year: Int, val month: Int, val day: Int) {
    init {
        require(month in 1..MONTHS_PER_YEAR) { "Hijri month must be 1..$MONTHS_PER_YEAR: $month" }
        require(day in 1..MAX_MONTH_LENGTH) { "Hijri day must be 1..$MAX_MONTH_LENGTH: $day" }
    }

    public companion object {
        public const val MONTHS_PER_YEAR: Int = 12
        public const val MIN_MONTH_LENGTH: Int = 29
        public const val MAX_MONTH_LENGTH: Int = 30
    }
}

/** One (corrected) Hijri month: its Gregorian [firstDay] and its [length], 29 or 30 days. */
public data class HijriMonth(val year: Int, val month: Int, val firstDay: LocalDate, val length: Int) {
    init {
        require(month in 1..HijriDate.MONTHS_PER_YEAR) { "Hijri month must be 1..12: $month" }
        require(length in HijriDate.MIN_MONTH_LENGTH..HijriDate.MAX_MONTH_LENGTH) {
            "A Hijri month has 29 or 30 days: $length"
        }
    }

    public val lastDay: LocalDate get() = firstDay.plusDays(length - 1L)

    public operator fun contains(date: LocalDate): Boolean = !date.isBefore(firstDay) && !date.isAfter(lastDay)

    /** The Hijri date of [date], which must be in this month. */
    public fun dateOf(date: LocalDate): HijriDate {
        require(date in this) { "$date isn't in $year-$month" }
        return HijriDate(year, month, (date.toEpochDay() - firstDay.toEpochDay()).toInt() + 1)
    }
}
