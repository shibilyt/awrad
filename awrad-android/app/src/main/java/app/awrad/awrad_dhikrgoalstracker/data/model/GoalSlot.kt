package app.awrad.awrad_dhikrgoalstracker.data.model

data class GoalSlot(
    val id: Long = 0,
    val goalId: Long,
    val slotType: GoalSlotType = GoalSlotType.ANYTIME,
    val minimumCount: Int? = null,
    val targetCount: Int? = null,
    val maximumCount: Int? = null,
    val capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
    val prayerName: Prayer? = null,
    val prayerRelation: PrayerRelation? = null,
    val startMinute: Int? = null,
    val endMinute: Int? = null,
    val startLeadMinutesOverride: Int? = null,
    val label: String? = null,
    val sortOrder: Int = 0,
    val isActive: Boolean = true,
    val archivedAt: Long? = null,
) {
    val timingType: String
        get() = when (slotType) {
            GoalSlotType.ANYTIME -> SlotTimingTypes.ANYTIME
            GoalSlotType.PRAYER -> SlotTimingTypes.PRAYER
            GoalSlotType.TIME_WINDOW -> SlotTimingTypes.TIME_WINDOW
        }

    val timingValue: String?
        get() = when (slotType) {
            GoalSlotType.ANYTIME -> null
            GoalSlotType.PRAYER -> {
                val relation = prayerRelation ?: return null
                val prayer = prayerName ?: return null
                "${relation.name.lowercase()}_${prayer.name.lowercase()}"
            }
            GoalSlotType.TIME_WINDOW -> {
                val start = startMinute ?: return null
                val end = endMinute ?: return null
                "${start.toClockText()}-${end.toClockText()}"
            }
        }

    val targetCountOrZero: Int get() = targetCount ?: 0
}

object SlotTimingTypes {
    const val ANYTIME = "anytime"
    const val PRAYER = "prayer"
    const val TIME_WINDOW = "time_window"
}

object PrayerTimingValues {
    const val BEFORE_FAJR = "before_fajr"
    const val AFTER_FAJR = "after_fajr"
    const val BEFORE_DHUHR = "before_dhuhr"
    const val AFTER_DHUHR = "after_dhuhr"
    const val BEFORE_ASR = "before_asr"
    const val AFTER_ASR = "after_asr"
    const val BEFORE_MAGHRIB = "before_maghrib"
    const val AFTER_MAGHRIB = "after_maghrib"
    const val BEFORE_ISHA = "before_isha"
    const val AFTER_ISHA = "after_isha"
}

private fun Int.toClockText(): String {
    val clamped = coerceIn(0, 24 * 60)
    val hour24 = (clamped / 60) % 24
    val minute = clamped % 60
    val suffix = if (hour24 < 12) "AM" else "PM"
    val hour12 = when (val normalized = hour24 % 12) {
        0 -> 12
        else -> normalized
    }
    return "%d:%02d %s".format(hour12, minute, suffix)
}
