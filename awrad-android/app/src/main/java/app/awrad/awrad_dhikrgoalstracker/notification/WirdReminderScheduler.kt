package app.awrad.awrad_dhikrgoalstracker.notification

import android.app.AlarmManager
import android.app.AlarmManager.AlarmClockInfo
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import app.awrad.awrad_dhikrgoalstracker.MainActivity
import app.awrad.awrad_dhikrgoalstracker.data.model.CalculationMethodPref
import app.awrad.awrad_dhikrgoalstracker.data.model.MadhabPref
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdReminder
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import app.awrad.awrad_dhikrgoalstracker.data.repository.PrayerTimeRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.WirdLibraryRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.first
import java.util.Calendar
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Schedules daily-repeating local notifications for wird reminders. Reuses the AlarmManager
 * approach of the goal reminders. Alarms are one-shot ([AlarmClockInfo]); [WirdReminderReceiver]
 * reschedules the next day's occurrence when one fires.
 */
@Singleton
class WirdReminderScheduler @Inject constructor(
    @ApplicationContext private val context: Context,
    private val userPreferences: UserPreferences,
    private val prayerTimeRepository: PrayerTimeRepository,
    private val wirdLibraryRepository: WirdLibraryRepository,
) {
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    /** Re-arm every wird's enabled reminders. Called on boot / app update / time change. */
    suspend fun rescheduleAll() {
        wirdLibraryRepository.observeWirds().first().forEach { wird ->
            if (wird.reminders.any { it.enabled }) schedule(wird)
        }
    }

    suspend fun schedule(wird: Wird) {
        // Cancel current reminders first, then (re)schedule the enabled ones.
        cancel(wird.id, wird.reminders.map { it.id })
        val prayerTimes = loadPrayerTimes()
        wird.reminders.filter { it.enabled }.forEach { reminder ->
            val triggerAt = nextTrigger(reminder, prayerTimes) ?: return@forEach
            scheduleAlarm(wird.id, reminder.id, triggerAt)
        }
    }

    fun cancel(wirdId: String, reminderIds: List<String>) {
        reminderIds.forEach { rid ->
            val code = AlarmRequestCodes.wirdReminder(wirdId, rid)
            val intent = Intent(context, WirdReminderReceiver::class.java)
            PendingIntent.getBroadcast(
                context, code, intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )?.let { alarmManager.cancel(it) }
        }
    }

    /** Reschedule a single reminder one day ahead (called by the receiver after it fires). */
    suspend fun rescheduleNext(wird: Wird, reminderId: String) {
        val reminder = wird.reminders.firstOrNull { it.id == reminderId && it.enabled } ?: return
        val triggerAt = nextTrigger(reminder, loadPrayerTimes(), fromTomorrow = true) ?: return
        scheduleAlarm(wird.id, reminderId, triggerAt)
    }

    private fun scheduleAlarm(wirdId: String, reminderId: String, triggerAt: Long) {
        val intent = Intent(context, WirdReminderReceiver::class.java).apply {
            putExtra(WorkerKeys.EXTRA_WIRD_ID, wirdId)
            putExtra(WorkerKeys.EXTRA_WIRD_REMINDER_ID, reminderId)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, AlarmRequestCodes.wirdReminder(wirdId, reminderId), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val showIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.setAlarmClock(AlarmClockInfo(triggerAt, showIntent), pendingIntent)
    }

    private fun nextTrigger(
        reminder: WirdReminder,
        prayerTimes: PrayerClockTimes?,
        fromTomorrow: Boolean = false,
    ): Long? {
        val (hour, minute) = when (reminder.reminderType) {
            ReminderType.PRAYER_OFFSET -> {
                val base = reminder.prayer?.let { prayerTimes?.timeFor(it) }
                if (base != null) {
                    val cal = Calendar.getInstance().apply { time = base }
                    val total = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE) +
                        (reminder.offsetMinutes ?: 0)
                    (total / 60) % 24 to total % 60
                } else {
                    7 to 0 // fallback when prayer times unavailable
                }
            }
            else -> (reminder.hour ?: 7) to (reminder.minute ?: 0)
        }
        return nextOccurrence(hour, minute, fromTomorrow)
    }

    private fun nextOccurrence(hour: Int, minute: Int, fromTomorrow: Boolean): Long {
        val now = System.currentTimeMillis()
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (fromTomorrow || cal.timeInMillis <= now) cal.add(Calendar.DAY_OF_YEAR, 1)
        return cal.timeInMillis
    }

    private suspend fun loadPrayerTimes(): PrayerClockTimes? {
        val lat = userPreferences.latitude.first() ?: return null
        val lng = userPreferences.longitude.first() ?: return null
        val method = runCatching { CalculationMethodPref.valueOf(userPreferences.calculationMethod.first()) }
            .getOrDefault(CalculationMethodPref.KARACHI)
        val madhab = runCatching { MadhabPref.valueOf(userPreferences.madhab.first()) }
            .getOrDefault(MadhabPref.SHAFI)
        val pt = prayerTimeRepository.getPrayerTimes(lat, lng, method, madhab)
        return PrayerClockTimes(pt.fajr, pt.dhuhr, pt.asr, pt.maghrib, pt.isha)
    }
}

/** Today's prayer instants for offset reminders. */
data class PrayerClockTimes(
    val fajr: Date?,
    val dhuhr: Date?,
    val asr: Date?,
    val maghrib: Date?,
    val isha: Date?,
) {
    fun timeFor(prayer: Prayer): Date? = when (prayer) {
        Prayer.FAJR -> fajr
        Prayer.DHUHR -> dhuhr
        Prayer.ASR -> asr
        Prayer.MAGHRIB -> maghrib
        Prayer.ISHA -> isha
    }
}
