package app.awrad.awrad_dhikrgoalstracker.notification

import android.content.Context
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import app.awrad.awrad_dhikrgoalstracker.notification.workers.DailyRemembranceWorker
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.Calendar
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Enqueues/cancels the opt-in [DailyRemembranceWorker] periodic notification.
 *
 * The work runs every 24h, first firing at the next 09:00 local time.
 */
@Singleton
class DailyRemembranceScheduler @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val workManager: WorkManager get() = WorkManager.getInstance(context)

    /** Schedules the daily remembrance notification (first run at the next 09:00 local). */
    fun schedule() {
        val initialDelay = computeDelayToNextOccurrence(hour = NOTIFY_HOUR, minute = 0)
        val work = PeriodicWorkRequestBuilder<DailyRemembranceWorker>(
            repeatInterval = 24,
            repeatIntervalTimeUnit = TimeUnit.HOURS,
        )
            .setInitialDelay(initialDelay, TimeUnit.MILLISECONDS)
            .build()

        workManager.enqueueUniquePeriodicWork(
            WorkerKeys.DAILY_REMEMBRANCE,
            ExistingPeriodicWorkPolicy.UPDATE,
            work,
        )
        Log.d(TAG, "Daily remembrance scheduled (first run in ${initialDelay / 60000}min)")
    }

    /** Cancels the daily remembrance notification. */
    fun cancel() {
        workManager.cancelUniqueWork(WorkerKeys.DAILY_REMEMBRANCE)
        Log.d(TAG, "Daily remembrance cancelled")
    }

    private fun computeDelayToNextOccurrence(hour: Int, minute: Int): Long {
        val now = Calendar.getInstance()
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!target.after(now)) target.add(Calendar.DAY_OF_YEAR, 1)
        return target.timeInMillis - now.timeInMillis
    }

    companion object {
        private const val TAG = "DailyRemembranceScheduler"
        private const val NOTIFY_HOUR = 9
    }
}
