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
