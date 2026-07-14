package app.awrad.awrad_dhikrgoalstracker.data.model

import java.time.LocalDate

data class Goal(
    val id: AwradId = newAwradId(),
    val dhikrId: AwradId,
    val dhikr: Dhikr? = null,
    val targetPolicy: TargetPolicy = TargetPolicy.PER_DUE_DATE,
    val slotCountingPolicy: SlotCountingPolicy = SlotCountingPolicy.WARN_AND_ALLOW,
    val recurrence: GoalRecurrence = GoalRecurrence(goalId = id),
    val slots: List<GoalSlot> = emptyList(),
    val reminders: List<GoalReminder> = emptyList(),
    val startDate: LocalDate,
    val endDate: LocalDate? = null,
    val durationDays: Int? = null,
    val minimumStreakCount: Int? = null,
    val targetCount: Int? = null,
    val maximumCount: Int? = null,
    val capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
    val streakThreshold: Threshold = Threshold.Target,
    val reminderThreshold: Threshold = Threshold.Target,
    val completionThreshold: Threshold = Threshold.Target,
    val autoCompleteOnTarget: Boolean = false,
    val completionPolicy: CompletionPolicy = if (autoCompleteOnTarget) CompletionPolicy.WhenTargetReached else CompletionPolicy.Never,
    val totalCompletedCount: Long = 0,
    val isActive: Boolean = true,
    val completedAt: Long? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = createdAt,
) {
    val countPolicy: CountPolicy
        get() = CountPolicy(
            minimumCount = minimumStreakCount,
            targetCount = targetCount,
            maximumCount = maximumCount,
            streakThreshold = streakThreshold,
            reminderThreshold = reminderThreshold,
            completionThreshold = completionThreshold,
            capBehavior = capBehavior,
        )
    val activeSlots: List<GoalSlot> get() = slots.filter { it.isActive }
    val archivedSlots: List<GoalSlot> get() = slots.filterNot { it.isActive }
    val isPaused: Boolean get() = !isActive && completedAt == null
    val isCompleted: Boolean get() = completedAt != null
    val isPrayerBased: Boolean get() = activeSlots.any { it.slotType == GoalSlotType.PRAYER }
    val isOneTime: Boolean get() = targetPolicy == TargetPolicy.CUMULATIVE_TOTAL
    val isTracker: Boolean get() = targetPolicy == TargetPolicy.NONE
    val minimumCount: Int? get() = minimumStreakCount
    val notificationEnabled: Boolean get() = reminders.any { it.enabled }
    val notificationHour: Int? get() = reminders.firstOrNull { it.reminderType == ReminderType.FIXED_TIME && it.enabled }?.hour
    val notificationMinute: Int? get() = reminders.firstOrNull { it.reminderType == ReminderType.FIXED_TIME && it.enabled }?.minute

    val frequencyType: FrequencyType
        get() = when (recurrence.frequency) {
            RecurrenceFrequency.DAILY -> FrequencyType.DAILY
            RecurrenceFrequency.WEEKLY -> FrequencyType.WEEKLY
            RecurrenceFrequency.MONTHLY -> FrequencyType.MONTHLY
            RecurrenceFrequency.INTERVAL -> FrequencyType.INTERVAL
            RecurrenceFrequency.YEARLY, RecurrenceFrequency.SEASON -> FrequencyType.YEARLY
            RecurrenceFrequency.SPECIFIC_DATES -> FrequencyType.SPECIFIC_DATES
        }
}
