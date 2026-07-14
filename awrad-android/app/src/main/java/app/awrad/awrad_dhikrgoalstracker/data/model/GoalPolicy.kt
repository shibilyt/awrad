package app.awrad.awrad_dhikrgoalstracker.data.model

enum class TargetPolicy {
    PER_DUE_DATE,
    CUMULATIVE_TOTAL,
    PERIOD_TOTAL,
    NONE,
}

enum class RecurrenceFrequency {
    DAILY,
    WEEKLY,
    MONTHLY,
    INTERVAL,
    YEARLY,
    SEASON,
    SPECIFIC_DATES,
}

enum class GoalSlotType {
    ANYTIME,
    PRAYER,
    TIME_WINDOW,
}

enum class SlotCountingPolicy {
    WARN_AND_ALLOW,
    STRICT_ACTIVE_ONLY,
    SILENT_FLEXIBLE,
}

enum class CountCapBehavior {
    AllowOverTarget,
    WarnOverTarget,
    BlockAtTarget,
    BlockAtMaximum,
}

typealias CapBehavior = CountCapBehavior

/** Which configured count is used for a product threshold. */
sealed class Threshold {
    data object AnyPositive : Threshold()
    data object Minimum : Threshold()
    data object Target : Threshold()
    data object Maximum : Threshold()
    data class Custom(val count: Int) : Threshold()
}

data class CountPolicy(
    val minimumCount: Int? = null,
    val targetCount: Int? = null,
    val maximumCount: Int? = null,
    val streakThreshold: Threshold = Threshold.Target,
    val reminderThreshold: Threshold = Threshold.Target,
    val completionThreshold: Threshold = Threshold.Target,
    val capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
) {
    val hasAnyCount: Boolean get() = minimumCount != null || targetCount != null || maximumCount != null
    val effectiveTargetCount: Int? get() = targetCount ?: minimumCount
}

enum class CompletionPolicy {
    Never,
    WhenTargetReached,
    DurationEnded,
}

enum class PrayerRelation {
    BEFORE,
    AFTER,
}

enum class ReminderType {
    FIXED_TIME,
    PRAYER_OFFSET,
    TIME_WINDOW_START,
}

enum class SeasonTemplateCode {
    RAMADAN,
    RAMADAN_LAST_10,
    DHUL_HIJJAH_1_10,
    WHITE_DAYS,
    ASHURA,
    ARAFAH,
}
