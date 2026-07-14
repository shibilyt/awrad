package app.awrad.awrad_dhikrgoalstracker.notification

import android.app.AlarmManager
import android.app.AlarmManager.AlarmClockInfo
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import app.awrad.awrad_dhikrgoalstracker.MainActivity
import app.awrad.awrad_dhikrgoalstracker.data.model.CalculationMethodPref
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.MadhabPref
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.PrayerTimeRepository
import app.awrad.awrad_dhikrgoalstracker.notification.workers.DailySchedulerWorker
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.util.Calendar
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Schedules/cancels reminders via AlarmManager (primary) with WorkManager as a watchdog.
 *
 * Uses setAlarmClock() for maximum reliability — survives Doze, never batched.
 * Uses setExactAndAllowWhileIdle() for follow-up reminders.
 * Keeps a periodic WorkManager watchdog to catch any missed alarms.
 */
@Singleton
class ReminderScheduler @Inject constructor(
    @ApplicationContext private val context: Context,
    private val goalRepository: GoalRepository,
    private val userPreferences: UserPreferences,
    private val prayerTimeRepository: PrayerTimeRepository,
    private val occurrenceResolver: ReminderOccurrenceResolver,
) : ReminderSchedulingGateway {
    private val alarmManager: AlarmManager =
        context.getSystemService(AlarmManager::class.java)
    private val workManager: WorkManager get() = WorkManager.getInstance(context)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /**
     * Called once at app startup. Enqueues the WorkManager watchdog and
     * schedules all alarms for today.
     */
    fun initialize() {
        initializeWatchdog()
        scope.launch { rescheduleAllAlarms() }
    }

    /**
     * Reschedules all alarms immediately. Call after creating/deleting goals or changing settings.
     */
    override fun rescheduleAll() {
        scope.launch { rescheduleAllAlarms() }
    }

    /**
     * Schedules alarms for a specific newly-created goal.
     * Also triggers a full reschedule to pick up prayer-linked reminders.
     */
    fun scheduleForGoal(goal: Goal) {
        if (!goal.isActive || goal.isCompleted || !goal.notificationEnabled) return
        scope.launch { rescheduleAllAlarms() }
    }

    /**
     * Cancels all alarms for a specific goal.
     */
    fun cancelForGoal(goalId: AwradId) {
        cancelAlarm(AlarmRequestCodes.goalReminder(goalId))
        cancelAlarm(AlarmRequestCodes.goalFollowUp(goalId))
        // Cancel any prayer slot alarms for this goal (up to 10 slots)
        for (slotIndex in 0..9) {
            cancelAlarm(AlarmRequestCodes.prayerSlot(goalId, slotIndex))
        }
        Log.d(TAG, "Cancelled all alarms for goal $goalId")
    }

    /**
     * Schedules a test alarm that fires in the specified delay.
     */
    fun scheduleTest(goalId: AwradId, delaySeconds: Long = 30) {
        val triggerTime = System.currentTimeMillis() + (delaySeconds * 1000)
        val intent = ReminderAlarmReceiver.createIntent(
            context = context,
            goalId = goalId,
            isFollowUp = true, // prevent follow-up chain
        )
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            AlarmRequestCodes.TEST,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        scheduleAlarmClock(triggerTime, pendingIntent)
        Log.d(TAG, "Test alarm scheduled for goal $goalId in ${delaySeconds}s")
    }

    fun scheduleGlobalTest(delaySeconds: Long = 30) {
        val triggerTime = System.currentTimeMillis() + (delaySeconds * 1000)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            AlarmRequestCodes.TEST,
            ReminderAlarmReceiver.createGlobalIntent(context),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        scheduleAlarmClock(triggerTime, pendingIntent)
        Log.d(TAG, "Global test alarm scheduled in ${delaySeconds}s")
    }

    /**
     * Checks whether exact alarms can be scheduled on this device.
     */
    override fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true // Pre-Android 12, no permission needed
        }
    }

    // ── Internal scheduling ─────────────────────────────────────────────

    internal suspend fun rescheduleAllAlarms() {
        if (!canScheduleExactAlarms()) {
            Log.w(TAG, "Cannot schedule exact alarms — permission not granted")
            return
        }

        Log.d(TAG, "Rescheduling all alarms")
        val goals = goalRepository.getActiveGoalsWithNotifications()
            .map { goalRepository.getGoalById(it.id) ?: it }
        cancelAlarms(AlarmRequestCodes.codesToCancelBeforeReschedule(goals))
        scheduleGoalAlarms(goals)
        scheduleGlobalAlarm()
    }

    private suspend fun scheduleGoalAlarms(goals: List<Goal>) {
        val now = System.currentTimeMillis()
        val prayerSettings = loadPrayerSettings()

        for (fullGoal in goals) {
            val occurrences = occurrenceResolver.resolveNextOccurrences(
                goal = fullGoal,
                nowMillis = now,
                prayerTimesForDate = { date ->
                    prayerSettings?.let {
                        prayerTimeRepository.getPrayerTimes(
                            latitude = it.latitude,
                            longitude = it.longitude,
                            method = it.method,
                            madhab = it.madhab,
                            date = date,
                        )
                    }
                },
            )

            for (occurrence in occurrences) {
                scheduleOccurrenceAlarm(occurrence, now)
            }
        }
    }

    private fun scheduleOccurrenceAlarm(occurrence: ReminderOccurrence, now: Long) {
        val requestCode = AlarmRequestCodes.reminder(
            goalId = occurrence.goalId,
            reminderId = occurrence.reminderId,
            slotId = occurrence.slotId,
        )
        val intent = ReminderAlarmReceiver.createIntent(
            context = context,
            goalId = occurrence.goalId,
            isFollowUp = false,
            slotId = occurrence.slotId,
            slotLabel = occurrence.slotLabel,
            occurrenceDate = occurrence.occurrenceDate.toString(),
        )
        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        scheduleAlarmClock(occurrence.triggerAtMillis, pendingIntent)
        Log.d(
            TAG,
            "Alarm set: goal=${occurrence.goalId} slot=${occurrence.slotId} date=${occurrence.occurrenceDate} in ${(occurrence.triggerAtMillis - now) / 60000}min",
        )
    }

    private suspend fun loadPrayerSettings(): PrayerSettings? {
        val lat = userPreferences.latitude.first() ?: return null
        val lng = userPreferences.longitude.first() ?: return null
        val methodStr = userPreferences.calculationMethod.first()
        val madhabStr = userPreferences.madhab.first()

        val method = try {
            CalculationMethodPref.valueOf(methodStr)
        } catch (_: IllegalArgumentException) {
            CalculationMethodPref.KARACHI
        }
        val madhab = try {
            MadhabPref.valueOf(madhabStr)
        } catch (_: IllegalArgumentException) {
            MadhabPref.SHAFI
        }
        return PrayerSettings(lat, lng, method, madhab)
    }

    private suspend fun scheduleGlobalAlarm() {
        val enabled = userPreferences.dailyReminderEnabled.first()
        if (!enabled) return

        val hour = userPreferences.reminderHour.first()
        val minute = userPreferences.reminderMinute.first()
        val now = System.currentTimeMillis()

        var triggerTime = todayAtTime(hour, minute)
        if (triggerTime <= now) {
            triggerTime = Calendar.getInstance().apply {
                timeInMillis = triggerTime
                add(Calendar.DAY_OF_YEAR, 1)
            }.timeInMillis
        }

        val intent = ReminderAlarmReceiver.createGlobalIntent(context)
        val pendingIntent = PendingIntent.getBroadcast(
            context, AlarmRequestCodes.GLOBAL,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        scheduleAlarmClock(triggerTime, pendingIntent)
        Log.d(TAG, "Global alarm set at $hour:$minute (in ${(triggerTime - now) / 60000}min)")
    }

    /**
     * Schedules a follow-up alarm 3 hours from now for a goal reminder.
     */
    internal fun scheduleFollowUp(
        goalId: AwradId,
        slotId: AwradId? = null,
        slotLabel: String? = null,
        occurrenceDate: String? = null,
    ) {
        val cutoffHour = 22
        val cal = Calendar.getInstance().apply { add(Calendar.HOUR_OF_DAY, 3) }
        if (cal.get(Calendar.HOUR_OF_DAY) >= cutoffHour) {
            Log.d(TAG, "Follow-up would be after $cutoffHour:00, skipping")
            return
        }

        val triggerTime = cal.timeInMillis
        val intent = ReminderAlarmReceiver.createIntent(
            context = context,
            goalId = goalId,
            isFollowUp = true,
            slotId = slotId,
            slotLabel = slotLabel,
            occurrenceDate = occurrenceDate,
        )
        val requestCode = AlarmRequestCodes.goalFollowUp(goalId, slotId)
        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        if (canScheduleExactAlarms()) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent,
            )
        } else {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent,
            )
        }
        Log.d(TAG, "Follow-up alarm for goal $goalId slot=$slotId in 3h")
    }

    // ── Alarm helpers ───────────────────────────────────────────────────

    private fun scheduleAlarmClock(triggerTime: Long, pendingIntent: PendingIntent) {
        val showIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.setAlarmClock(
            AlarmClockInfo(triggerTime, showIntent),
            pendingIntent,
        )
    }

    private fun cancelAlarm(requestCode: Int) {
        val intent = Intent(context, ReminderAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
        pendingIntent?.let { alarmManager.cancel(it) }
    }

    private fun cancelAlarms(requestCodes: Set<Int>) {
        requestCodes.forEach(::cancelAlarm)
        Log.d(TAG, "Cancelled ${requestCodes.size} alarm request codes before reschedule")
    }

    // ── WorkManager watchdog ────────────────────────────────────────────

    private fun initializeWatchdog() {
        val dailyDelay = computeDelayToNextOccurrence(hour = 0, minute = 15)
        val dailyWork = PeriodicWorkRequestBuilder<DailySchedulerWorker>(
            repeatInterval = 24,
            repeatIntervalTimeUnit = TimeUnit.HOURS,
        )
            .setInitialDelay(dailyDelay, TimeUnit.MILLISECONDS)
            .build()

        workManager.enqueueUniquePeriodicWork(
            WorkerKeys.DAILY_SCHEDULER,
            ExistingPeriodicWorkPolicy.KEEP,
            dailyWork,
        )
        Log.d(TAG, "Watchdog initialized (next run in ${dailyDelay / 60000}min)")
    }

    // ── Utility ─────────────────────────────────────────────────────────

    private fun todayAtTime(hour: Int, minute: Int): Long {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun computeDelayToNextOccurrence(hour: Int, minute: Int): Long {
        val now = Calendar.getInstance()
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (target.before(now)) target.add(Calendar.DAY_OF_YEAR, 1)
        return target.timeInMillis - now.timeInMillis
    }

    companion object {
        private const val TAG = "ReminderScheduler"
    }

    private data class PrayerSettings(
        val latitude: Double,
        val longitude: Double,
        val method: CalculationMethodPref,
        val madhab: MadhabPref,
    )
}
