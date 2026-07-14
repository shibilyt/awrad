package app.awrad.awrad_dhikrgoalstracker.notification

import android.content.Context
import android.util.Log
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.firstOrNull
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NotificationTestHelper @Inject constructor(
    @ApplicationContext private val context: Context,
    private val goalRepository: GoalRepository,
    private val notificationBuilder: ReminderNotificationBuilder,
    private val reminderScheduler: ReminderScheduler,
    private val dateProvider: DateProvider,
) {
    /**
     * Immediately fires a notification for the first goal with notifications enabled.
     * Tests the notification display pipeline without AlarmManager.
     */
    suspend fun fireTestNotification() {
        val goals = goalRepository.getActiveGoalsWithNotifications()
        if (goals.isEmpty()) {
            Log.w(TAG, "No active goals with notifications enabled")
            notificationBuilder.showGlobalReminder()
            return
        }

        val goal = goals.first()
        val fullGoal = goalRepository.getGoalById(goal.id) ?: return
        val today = dateProvider.getEffectiveToday()
        val todayCount = goalRepository.getTotalCountForDate(fullGoal.id, today).first() ?: 0L
        val dailyTarget = GoalProgressCalculator.getTotalDailyTarget(fullGoal).toLong()

        val dhikrName = fullGoal.dhikr?.transliteration
            ?: context.getString(R.string.notif_dhikr_fallback)

        Log.d(TAG, "Firing test notification: goal=${fullGoal.id}, dhikr=$dhikrName")

        notificationBuilder.showGoalReminder(
            GoalNotificationData(
                goalId = fullGoal.id,
                dhikrName = "[TEST] $dhikrName",
                todayCount = todayCount,
                dailyTarget = dailyTarget,
                isTracker = fullGoal.targetPolicy == TargetPolicy.NONE,
            )
        )
    }

    /**
     * Schedules a real AlarmManager alarm to fire in ~30 seconds.
     * Tests the full AlarmManager → BroadcastReceiver → Notification pipeline.
     */
    suspend fun scheduleTestNotificationIn30Seconds() {
        val goals = goalRepository.getActiveGoalsWithNotifications()
        val goalId = if (goals.isNotEmpty()) {
            goals.first().id
        } else {
            val allGoals = goalRepository.getActiveGoals().firstOrNull().orEmpty()
            if (allGoals.isNotEmpty()) {
                allGoals.first().id
            } else {
                // No goals at all — schedule a global reminder test
                Log.d(TAG, "No goals found, scheduling global reminder test in 30s")
                reminderScheduler.scheduleGlobalTest(delaySeconds = 30)
                return
            }
        }

        reminderScheduler.scheduleTest(goalId, delaySeconds = 30)
        Log.d(TAG, "Test alarm scheduled for goal $goalId in 30s via AlarmManager")
    }

    companion object {
        private const val TAG = "NotifTest"
    }
}
