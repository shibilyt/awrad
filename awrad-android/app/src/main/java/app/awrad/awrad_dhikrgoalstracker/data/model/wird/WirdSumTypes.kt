package app.awrad.awrad_dhikrgoalstracker.data.model.wird

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * When within a day a part should be performed. Each occasion has a stable string [key]
 * persisted in `WirdSession.occasionKey` — these keys are a frozen contract; do not change them.
 */
@Serializable
sealed class WirdOccasion {
    abstract val key: String

    @Serializable
    @SerialName("anytime")
    data object Anytime : WirdOccasion() {
        override val key: String get() = "anytime"
    }

    @Serializable
    @SerialName("after_prayer")
    data class AfterPrayer(val prayer: Prayer) : WirdOccasion() {
        override val key: String get() = "after-${prayer.raw}"
    }

    @Serializable
    @SerialName("morning")
    data object Morning : WirdOccasion() {
        override val key: String get() = "morning"
    }

    @Serializable
    @SerialName("evening")
    data object Evening : WirdOccasion() {
        override val key: String get() = "evening"
    }

    @Serializable
    @SerialName("before_sleep")
    data object BeforeSleep : WirdOccasion() {
        override val key: String get() = "before-sleep"
    }

    @Serializable
    @SerialName("time_window")
    data class TimeWindow(val startMinute: Int, val endMinute: Int) : WirdOccasion() {
        override val key: String get() = "window-$startMinute-$endMinute"
    }
}

/** Which days a wird is active. */
@Serializable
sealed class WirdCadence {
    @Serializable
    @SerialName("every_day")
    data object EveryDay : WirdCadence()

    /** Calendar weekday ints, Sunday = 1 … Saturday = 7. */
    @Serializable
    @SerialName("days_of_week")
    data class DaysOfWeek(val days: Set<Int>) : WirdCadence()

    /** Every [days] days from [anchor] (a `yyyy-MM-dd` dateKey). */
    @Serializable
    @SerialName("interval")
    data class Interval(val days: Int, val anchor: String) : WirdCadence()

    /** Exactly one part per active day, cycling through `parts` in order. */
    @Serializable
    @SerialName("rotation")
    data object Rotation : WirdCadence()

    /** Specific part indexes assigned to calendar weekdays, Sunday = 1 … Saturday = 7. */
    @Serializable
    @SerialName("parts_by_weekday")
    data class PartsByWeekday(val partIndexesByDay: Map<Int, List<Int>>) : WirdCadence()
}

/** Optional Islamic-calendar gating (Umm al-Qura). */
@Serializable
sealed class HijriAnchor {
    @Serializable
    @SerialName("ramadan")
    data object Ramadan : HijriAnchor()

    @Serializable
    @SerialName("last_ten_nights")
    data object LastTenNights : HijriAnchor()

    @Serializable
    @SerialName("hijri_month")
    data class HijriMonth(val month: Int) : HijriAnchor()

    @Serializable
    @SerialName("hijri_date")
    data class HijriDate(val month: Int, val day: Int) : HijriAnchor()
}
