package app.awrad.awrad_dhikrgoalstracker.data.model

enum class GoalPreset {
    DAILY, PRAYER_BASED, ONE_TIME, TRACKER,
    WEEKLY, ISLAMIC_SEASON, MORNING_EVENING, CUSTOM,
    ADV_DAILY, ADV_PRAYER_BASED, ADV_WEEKLY,
    ADV_MONTHLY_GREGORIAN, ADV_MONTHLY_HIJRI,
    ADV_INTERVAL, ADV_YEARLY_GREGORIAN, ADV_YEARLY_HIJRI,
    ADV_SPECIFIC_DATES, ADV_TRACKER;

    val isQuickPreset: Boolean
        get() = this in listOf(DAILY, PRAYER_BASED, ONE_TIME, TRACKER, WEEKLY, ISLAMIC_SEASON, MORNING_EVENING)

    val frequencyType: FrequencyType
        get() = when (this) {
            DAILY, PRAYER_BASED, ONE_TIME, TRACKER, MORNING_EVENING, CUSTOM -> FrequencyType.DAILY
            WEEKLY -> FrequencyType.WEEKLY
            ISLAMIC_SEASON -> FrequencyType.YEARLY
            ADV_DAILY, ADV_PRAYER_BASED -> FrequencyType.DAILY
            ADV_WEEKLY -> FrequencyType.WEEKLY
            ADV_MONTHLY_GREGORIAN, ADV_MONTHLY_HIJRI -> FrequencyType.MONTHLY
            ADV_INTERVAL -> FrequencyType.INTERVAL
            ADV_YEARLY_GREGORIAN, ADV_YEARLY_HIJRI -> FrequencyType.YEARLY
            ADV_SPECIFIC_DATES -> FrequencyType.SPECIFIC_DATES
            ADV_TRACKER -> FrequencyType.DAILY
        }

    val defaultTimingType: TimingType
        get() = when (this) {
            PRAYER_BASED, ADV_PRAYER_BASED -> TimingType.PRAYER_BASED
            MORNING_EVENING -> TimingType.TIME_BASED
            else -> TimingType.ANYTIME
        }

    val defaultTargetType: TargetType
        get() = when (this) {
            TRACKER, ADV_TRACKER -> TargetType.NONE
            PRAYER_BASED, ADV_PRAYER_BASED -> TargetType.CUSTOM
            else -> TargetType.FIXED
        }

    val defaultDurationType: DurationType
        get() = when (this) {
            ONE_TIME -> DurationType.FIXED
            else -> DurationType.ONGOING
        }

    val showTimingPicker: Boolean
        get() = !isQuickPreset && this != ADV_TRACKER

    val showTargetField: Boolean
        get() = this != TRACKER && this != ADV_TRACKER
}
