package app.awrad.awrad_dhikrgoalstracker.data.model

data class GoalReminder(
    val id: Long = 0,
    val goalId: Long = 0,
    val slotId: Long? = null,
    val reminderType: ReminderType = ReminderType.FIXED_TIME,
    val hour: Int? = null,
    val minute: Int? = null,
    val offsetMinutes: Int? = null,
    val enabled: Boolean = true,
    val sortOrder: Int = 0,
)
