package app.awrad.awrad_dhikrgoalstracker.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOrNull
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

/**
 * Receives AlarmManager alarms and posts reminder notifications.
 *
 * Uses goAsync() to keep the receiver alive while doing async work (DB lookups).
 * After posting the notification, schedules a follow-up alarm if applicable.
 */
@AndroidEntryPoint
class ReminderAlarmReceiver : BroadcastReceiver() {

    @Inject lateinit var goalRepository: GoalRepository
    @Inject lateinit var notificationBuilder: ReminderNotificationBuilder
    @Inject lateinit var reminderScheduler: ReminderScheduler
    @Inject lateinit var dateProvider: DateProvider

    override fun onReceive(context: Context, intent: Intent) {
        val goalId = intent.getLongExtra(EXTRA_GOAL_ID, -1L)
        val isFollowUp = intent.getBooleanExtra(EXTRA_IS_FOLLOW_UP, false)
        val slotId = intent.getLongExtra(EXTRA_SLOT_ID, -1L).takeIf { it > 0 }
        val slotLabel = intent.getStringExtra(EXTRA_SLOT_LABEL)
        val occurrenceDate = intent.getStringExtra(EXTRA_OCCURRENCE_DATE)

        Log.d(TAG, "Alarm received: goalId=$goalId, followUp=$isFollowUp, slot=$slotId, date=$occurrenceDate")

        if (goalId == GLOBAL_REMINDER_ID) {
            notificationBuilder.showGlobalReminder()
            reminderScheduler.rescheduleAll()
            Log.d(TAG, "Global reminder fired")
            return
        }

        if (goalId == -1L) return

        val pendingResult = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                handleGoalReminder(
                    goalId = goalId,
                    isFollowUp = isFollowUp,
                    slotId = slotId,
                    slotLabel = slotLabel,
                    occurrenceDate = occurrenceDate,
                    dhikrFallback = context.getString(R.string.notif_dhikr_fallback),
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error handling alarm for goal $goalId", e)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private suspend fun handleGoalReminder(
        goalId: Long,
        isFollowUp: Boolean,
        slotId: Long?,
        slotLabel: String?,
        occurrenceDate: String?,
        dhikrFallback: String,
    ) {
        val goal = goalRepository.getGoalById(goalId)
        if (goal == null) {
            Log.w(TAG, "Goal $goalId not found")
            return
        }

        if (!goal.isActive || goal.isCompleted) {
            Log.d(TAG, "Goal $goalId inactive or completed, skipping")
            return
        }

        val reminderDate = resolveReminderDate(
            occurrenceDate = occurrenceDate,
            fallbackDateText = dateProvider.getEffectiveToday(),
        )
        val dateText = reminderDate.dateText
        val effectiveDate = reminderDate.date

        if (!GoalProgressCalculator.isDueToday(goal, effectiveDate)) {
            Log.d(TAG, "Goal $goalId not due on $effectiveDate, skipping")
            return
        }

        val slot = slotId?.let { id -> goal.slots.firstOrNull { it.id == id } }
        if (slotId != null && slot == null) {
            Log.d(TAG, "Goal $goalId slot $slotId not found, skipping")
            return
        }

        val progressCount = if (slot != null) {
            goalRepository.getCountForSlotAndDate(goalId, slot.id, dateText)
        } else {
            when (goal.targetPolicy) {
                TargetPolicy.CUMULATIVE_TOTAL -> goalRepository.getTotalCount(goalId).first() ?: 0L
                TargetPolicy.PERIOD_TOTAL -> {
                    val window = GoalProgressCalculator.currentProgressWindow(goal, effectiveDate)
                    if (window != null) goalRepository.getTotalCountBetween(goalId, window.start.toString(), window.endInclusive.toString()) else 0L
                }
                TargetPolicy.PER_DUE_DATE, TargetPolicy.NONE -> goalRepository.getTotalCountForDate(goalId, dateText).first() ?: 0L
            }
        }
        val isTracker = goal.targetPolicy == TargetPolicy.NONE
        val target = (slot?.targetCount ?: GoalProgressCalculator.getTotalDailyTarget(goal)).toLong()
        val isDoneForReminder = ReminderDeliveryEvaluator.isCompleteForReminder(goal, slot, progressCount)

        if (isDoneForReminder) {
            Log.d(TAG, "Goal $goalId slot=$slotId completed for $dateText, skipping notification")
            return
        }

        val dhikrName = goal.dhikr?.transliteration?.ifBlank { null }
            ?: goal.dhikr?.title?.ifBlank { null }
            ?: dhikrFallback

        notificationBuilder.showGoalReminder(
            GoalNotificationData(
                goalId = goalId,
                dhikrName = dhikrName,
                todayCount = progressCount,
                dailyTarget = target,
                isFollowUp = isFollowUp,
                slotId = slotId,
                slotLabel = slotLabel ?: slot?.label,
                isTracker = isTracker,
            )
        )

        if (!isFollowUp) {
            reminderScheduler.scheduleFollowUp(
                goalId = goalId,
                slotId = slotId,
                slotLabel = slotLabel ?: slot?.label,
                occurrenceDate = dateText,
            )
            reminderScheduler.rescheduleAll()
        }
    }

    companion object {
        private const val TAG = "ReminderAlarmReceiver"
        const val EXTRA_GOAL_ID = "alarm_goal_id"
        const val EXTRA_IS_FOLLOW_UP = "alarm_is_follow_up"
        const val EXTRA_SLOT_ID = "alarm_slot_id"
        const val EXTRA_SLOT_LABEL = "alarm_slot_label"
        const val EXTRA_OCCURRENCE_DATE = "alarm_occurrence_date"
        const val GLOBAL_REMINDER_ID = -99L

        fun createIntent(
            context: Context,
            goalId: Long,
            isFollowUp: Boolean,
            slotId: Long? = null,
            slotLabel: String? = null,
            occurrenceDate: String? = null,
        ): Intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            putExtra(EXTRA_GOAL_ID, goalId)
            putExtra(EXTRA_IS_FOLLOW_UP, isFollowUp)
            slotId?.let { putExtra(EXTRA_SLOT_ID, it) }
            slotLabel?.let { putExtra(EXTRA_SLOT_LABEL, it) }
            occurrenceDate?.let { putExtra(EXTRA_OCCURRENCE_DATE, it) }
        }
    }
}

internal data class ReminderDateResolution(
    val dateText: String,
    val date: LocalDate,
)

internal fun resolveReminderDate(
    occurrenceDate: String?,
    fallbackDateText: String,
    fallbackDate: LocalDate = LocalDate.now(),
): ReminderDateResolution {
    occurrenceDate.toLocalDateOrNull()?.let { date ->
        return ReminderDateResolution(dateText = date.toString(), date = date)
    }

    val repairedDate = fallbackDateText.toLocalDateOrNull() ?: fallbackDate
    return ReminderDateResolution(dateText = repairedDate.toString(), date = repairedDate)
}
