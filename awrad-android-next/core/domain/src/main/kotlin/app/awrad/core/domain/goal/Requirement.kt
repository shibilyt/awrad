package app.awrad.core.domain.goal

/** A calendar week (starting on the account's week start) or a Gregorian month. */
public enum class CalendarPeriod {
    WEEK,
    MONTH,
}

/**
 * The rule that decides whether a goal is met within a window (CONTEXT.md, "Requirement").
 * Targets come from the goal's count policy, or each session's when the goal has sessions.
 */
public sealed interface Requirement {

    /** The target, on each due day. */
    public data object PerDueDate : Requirement

    /** One target across the whole active period. */
    public data object CumulativeTotal : Requirement

    /** A target per week or month. */
    public data class PeriodTotal(val period: CalendarPeriod) : Requirement

    /** A number of qualifying days (days meeting the daily target) per week or month. */
    public data class DaysPerPeriod(val period: CalendarPeriod, val days: Int) : Requirement {
        init {
            require(days in 1..MAX_DAYS) { "Days per period must be 1..$MAX_DAYS: $days" }
        }

        public companion object {
            public const val MAX_DAYS: Int = 31
        }
    }

    /** No target; any count is progress. */
    public data object Tracker : Requirement
}

/** When a goal counts as completed. Completion is derived by the rules, never set by counting code. */
public enum class CompletionPolicy {
    NEVER,
    WHEN_TARGET_REACHED,
    WHEN_DURATION_ENDED,
}
