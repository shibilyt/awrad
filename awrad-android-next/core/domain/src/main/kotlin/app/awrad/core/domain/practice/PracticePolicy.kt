package app.awrad.core.domain.practice

import java.time.DayOfWeek

/** The account practice policy's day-end rule (CONTEXT.md, "Effective practice day"). */
public enum class DayReset {
    MIDNIGHT,
    MAGHRIB,
}

/** The account practice policy's first day of the week. Every week-based rule takes it as an input. */
public enum class WeekStart(public val firstDay: DayOfWeek) {
    SATURDAY(DayOfWeek.SATURDAY),
    SUNDAY(DayOfWeek.SUNDAY),
    MONDAY(DayOfWeek.MONDAY),
    ;

    public companion object {
        public val DEFAULT: WeekStart = MONDAY
    }
}
