package app.awrad.awrad_dhikrgoalstracker.data.model

data class GoalReminder(
    val id: AwradId = newAwradId(),
    val goalId: AwradId,
    val slotId: AwradId? = null,
    val reminderType: ReminderType = ReminderType.FIXED_TIME,
    val hour: Int? = null,
    val minute: Int? = null,
    val offsetMinutes: Int? = null,
    val enabled: Boolean = true,
    val sortOrder: Int = 0,
)
