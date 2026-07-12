package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model

import app.awrad.awrad_dhikrgoalstracker.data.model.SlotCountingPolicy

data class ExtrasDraft(
    val hasDuration: Boolean = false,
    val durationDays: String = "",
    val hasMinStreak: Boolean = false,
    val minStreakCount: String = "",
    val notificationEnabled: Boolean = false,
    val notificationHour: Int = 8,
    val notificationMinute: Int = 0,
    val slotCountingPolicy: SlotCountingPolicy = SlotCountingPolicy.WARN_AND_ALLOW,
)
