package app.awrad.awrad_dhikrgoalstracker.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Reschedules all alarms after system events that clear pending alarms:
 * device boot, app update, time/timezone change, alarm permission change.
 */
@AndroidEntryPoint
class BootRescheduleReceiver : BroadcastReceiver() {

    @Inject lateinit var reminderScheduler: ReminderScheduler
    @Inject lateinit var wirdReminderScheduler: WirdReminderScheduler

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action?.takeIf(::isTrustedRescheduleAction) ?: run {
            Log.w(TAG, "Ignoring unsupported reschedule broadcast: ${intent.action}")
            return
        }
        Log.d(TAG, "Received system event: $action — rescheduling all alarms")
        reminderScheduler.rescheduleAll()

        // Wird reminders load from the DB, so re-arm them off the main thread.
        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.Default).launch {
            try {
                wirdReminderScheduler.rescheduleAll()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to reschedule wird reminders", e)
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        private const val TAG = "BootRescheduleReceiver"
        internal const val ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED =
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"

        private val RESCHEDULE_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
        )

        internal fun isTrustedRescheduleAction(action: String): Boolean =
            action in RESCHEDULE_ACTIONS
    }
}
