package app.awrad.awrad_dhikrgoalstracker.notification.workers

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationEngine
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationEngineResult
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationRequestReason
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject

/**
 * Periodic WorkManager watchdog (runs every 24h at ~12:15 AM).
 *
 * Its sole job is to verify and reschedule any AlarmManager alarms
 * that may have been lost (e.g., OEM battery killers silently dropping them).
 * This is a safety net — AlarmManager is the primary scheduler.
 */
@HiltWorker
class DailySchedulerWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted workerParams: WorkerParameters,
    private val reminderScheduler: ReminderScheduler,
    private val notificationObligationEngine: NotificationObligationEngine,
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        Log.d(TAG, "Watchdog running — rescheduling all alarms")
        reminderScheduler.rescheduleAllAlarms()
        return when (notificationObligationEngine.reconcileNow(NotificationObligationRequestReason.WATCHDOG)) {
            NotificationObligationEngineResult.Reconciled -> {
                Log.d(TAG, "Watchdog finished")
                Result.success()
            }
            is NotificationObligationEngineResult.TransientFailure -> Result.retry()
            is NotificationObligationEngineResult.FatalFailure -> Result.failure()
        }
    }

    companion object {
        private const val TAG = "DailySchedulerWorker"
    }
}
