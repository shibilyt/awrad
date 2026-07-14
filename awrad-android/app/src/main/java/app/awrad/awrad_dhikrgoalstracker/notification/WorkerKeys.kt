package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId

object WorkerKeys {
    // Unique work names
    const val DAILY_SCHEDULER = "daily_scheduler"
    const val DAILY_REMEMBRANCE = "daily_remembrance"
    const val GOAL_REMINDER_PREFIX = "goal_reminder_"
    const val GOAL_FOLLOWUP_PREFIX = "goal_followup_"
    const val PRAYER_REMINDER_PREFIX = "prayer_reminder_"
    const val GLOBAL_REMINDER = "global_reminder"

    // Worker input data keys
    const val KEY_GOAL_ID = "goal_id"
    const val KEY_IS_FOLLOW_UP = "is_follow_up"
    const val KEY_PRAYER_NAME = "prayer_name"

    // Tags for cancellation
    const val TAG_GOAL_REMINDERS = "goal_reminders"
    const val TAG_GOAL_FOLLOWUPS = "goal_followups"
    const val TAG_PRAYER_REMINDERS = "prayer_reminders"
    const val TAG_GLOBAL_REMINDER = "global_reminder"

    // Notification
    const val CHANNEL_GOAL_REMINDERS = "goal_reminders"
    const val CHANNEL_GLOBAL_REMINDER = "global_reminder"
    const val CHANNEL_WIRD_REMINDERS = "wird_reminders"
    const val CHANNEL_DAILY_REMEMBRANCE = "daily_remembrance"
    const val NOTIFICATION_BASE_ID = 3000
    const val GLOBAL_NOTIFICATION_ID = 4000
    const val WIRD_NOTIFICATION_BASE_ID = 5000
    const val DAILY_REMEMBRANCE_NOTIFICATION_ID = 6000

    // Wird reminder extras
    const val EXTRA_WIRD_ID = "extra_wird_id"
    const val EXTRA_WIRD_REMINDER_ID = "extra_wird_reminder_id"

    // Actions
    const val ACTION_DISMISS_NOTIFICATION = "app.awrad.ACTION_DISMISS_NOTIFICATION"
    const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
    const val EXTRA_GOAL_ID = "extra_goal_id"

    fun goalReminderName(goalId: AwradId) = "$GOAL_REMINDER_PREFIX$goalId"
    fun goalFollowUpName(goalId: AwradId) = "$GOAL_FOLLOWUP_PREFIX$goalId"
    fun prayerReminderName(goalId: AwradId, prayer: String) = "$PRAYER_REMINDER_PREFIX${goalId}_$prayer"
    fun goalTag(goalId: AwradId) = "goal_$goalId"
}

/**
 * Deterministic PendingIntent request codes for AlarmManager alarms.
 * Each alarm must have a unique request code so they don't overwrite each other.
 */
object AlarmRequestCodes {
    private const val GOAL_BASE = 10_000
    private const val PRAYER_BASE = 20_000
    private const val FOLLOWUP_BASE = 40_000
    private const val REMINDER_BASE = 100_000
    private const val WIRD_BASE = 200_000
    const val GLOBAL = 30_000
    const val TEST = 50_000

    fun wirdReminder(wirdId: String, reminderId: String): Int =
        stableCode(WIRD_BASE, "$wirdId:$reminderId")

    fun goalReminder(goalId: AwradId): Int = stableCode(GOAL_BASE, goalId.toString())
    fun prayerSlot(goalId: AwradId, slotIndex: Int): Int = stableCode(PRAYER_BASE, "$goalId:$slotIndex")
    fun goalFollowUp(goalId: AwradId, slotId: AwradId? = null): Int =
        stableCode(FOLLOWUP_BASE, "$goalId:${slotId.orEmptyKey()}")

    fun reminder(goalId: AwradId, reminderId: AwradId, slotId: AwradId?): Int =
        stableCode(REMINDER_BASE, "$goalId:$reminderId:${slotId.orEmptyKey()}")

    fun codesToCancelBeforeReschedule(goals: List<Goal>): Set<Int> = buildSet {
        add(GLOBAL)
        goals.forEach { goal ->
            add(goalReminder(goal.id))
            add(goalFollowUp(goal.id))
            for (slotIndex in 0..9) {
                add(prayerSlot(goal.id, slotIndex))
            }
            goal.slots.forEach { slot ->
                add(goalFollowUp(goal.id, slot.id))
            }
            goal.reminders.forEach { reminder ->
                add(reminder(goal.id, reminder.id, reminder.slotId))
                goal.slots.forEach { slot ->
                    add(reminder(goal.id, reminder.id, slot.id))
                }
            }
        }
    }

    private fun stableCode(base: Int, key: String): Int =
        base + (key.hashCode() and Int.MAX_VALUE) % 800_000

    private fun AwradId?.orEmptyKey(): String = this?.toString().orEmpty()
}
