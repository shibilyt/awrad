package app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType

object GoalReminderUpdateFactory {

    fun update(existingGoal: Goal, command: UpdateGoalRemindersCommand): GoalUpdateResult {
        val errors = mutableListOf<GoalUpdateError>()
        if (command.goalId != existingGoal.id) errors += GoalUpdateError.GoalIdMismatch

        val activeSlotIds = existingGoal.slots.map { it.id }.toSet()
        val prayerSlotIds = existingGoal.slots
            .filter { it.slotType == GoalSlotType.PRAYER }
            .map { it.id }
            .toSet()
        val timeWindowSlotIds = existingGoal.slots
            .filter { it.slotType == GoalSlotType.TIME_WINDOW }
            .map { it.id }
            .toSet()
        val existingReminderIds = existingGoal.reminders.map { it.id }.filter { it > 0 }.toSet()

        command.reminders.forEach { reminder ->
            if ((reminder.reminderId ?: 0L) > 0L && reminder.reminderId !in existingReminderIds) {
                errors += GoalUpdateError.InvalidReminder
            }
            if (!reminder.isValidFor(activeSlotIds, prayerSlotIds, timeWindowSlotIds)) {
                errors += GoalUpdateError.InvalidReminder
            }
        }

        val duplicateKeys = command.reminders
            .map { it.duplicateKey() }
            .groupingBy { it }
            .eachCount()
            .values
            .any { it > 1 }
        if (duplicateKeys) errors += GoalUpdateError.DuplicateReminder

        if (errors.isNotEmpty()) {
            return GoalUpdateResult.Invalid(errors.distinct())
        }

        val updatedReminders = command.reminders.mapIndexed { index, reminder ->
            GoalReminder(
                id = reminder.reminderId ?: 0L,
                goalId = existingGoal.id,
                slotId = reminder.normalizedSlotId(),
                reminderType = reminder.reminderType,
                hour = reminder.normalizedHour(),
                minute = reminder.normalizedMinute(),
                offsetMinutes = reminder.normalizedOffsetMinutes(),
                enabled = reminder.enabled,
                sortOrder = index,
            )
        }

        return GoalUpdateResult.Valid(
            ValidatedGoalUpdate(
                existingGoal.copy(reminders = updatedReminders)
            )
        )
    }

    private fun GoalReminderUpdate.isValidFor(
        activeSlotIds: Set<Long>,
        prayerSlotIds: Set<Long>,
        timeWindowSlotIds: Set<Long>,
    ): Boolean =
        when (reminderType) {
            ReminderType.FIXED_TIME ->
                slotId == null &&
                    hour != null &&
                    minute != null &&
                    hour in 0..23 &&
                    minute in 0..59
            ReminderType.PRAYER_OFFSET ->
                (offsetMinutes == null || offsetMinutes >= 0) &&
                    ((slotId == null && prayerSlotIds.isNotEmpty()) || slotId in prayerSlotIds) &&
                    (slotId == null || slotId in activeSlotIds)
            ReminderType.TIME_WINDOW_START ->
                ((slotId == null && timeWindowSlotIds.isNotEmpty()) || slotId in timeWindowSlotIds) &&
                    (slotId == null || slotId in activeSlotIds)
        }

    private fun GoalReminderUpdate.normalizedSlotId(): Long? =
        when (reminderType) {
            ReminderType.FIXED_TIME -> null
            ReminderType.PRAYER_OFFSET,
            ReminderType.TIME_WINDOW_START -> slotId
        }

    private fun GoalReminderUpdate.normalizedHour(): Int? =
        if (reminderType == ReminderType.FIXED_TIME) hour else null

    private fun GoalReminderUpdate.normalizedMinute(): Int? =
        if (reminderType == ReminderType.FIXED_TIME) minute else null

    private fun GoalReminderUpdate.normalizedOffsetMinutes(): Int? =
        when (reminderType) {
            ReminderType.FIXED_TIME -> null
            ReminderType.PRAYER_OFFSET -> offsetMinutes ?: DEFAULT_PRAYER_OFFSET_MINUTES
            ReminderType.TIME_WINDOW_START -> 0
        }

    private fun GoalReminderUpdate.duplicateKey(): ReminderDuplicateKey =
        ReminderDuplicateKey(
            type = reminderType,
            slotId = normalizedSlotId(),
            hour = normalizedHour(),
            minute = normalizedMinute(),
            offsetMinutes = normalizedOffsetMinutes(),
        )

    private data class ReminderDuplicateKey(
        val type: ReminderType,
        val slotId: Long?,
        val hour: Int?,
        val minute: Int?,
        val offsetMinutes: Int?,
    )

    private const val DEFAULT_PRAYER_OFFSET_MINUTES = 10
}
