package app.awrad.awrad_dhikrgoalstracker.notification.workers

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import app.awrad.awrad_dhikrgoalstracker.MainActivity
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.notification.WorkerKeys
import app.awrad.awrad_dhikrgoalstracker.util.RemembranceProvider
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import java.time.LocalDate

/**
 * Periodic (24h) opt-in worker that posts the day's remembrance as a notification.
 *
 * Enqueued/cancelled by [app.awrad.awrad_dhikrgoalstracker.notification.DailyRemembranceScheduler]
 * from the Settings toggle (default OFF).
 */
@HiltWorker
class DailyRemembranceWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted workerParams: WorkerParameters,
    private val remembranceProvider: RemembranceProvider,
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        ensureChannel()

        val remembrance = remembranceProvider.forDate(LocalDate.now())
        val text = remembrance.notificationText
        if (text.isBlank()) return Result.success()

        val body = applicationContext.getString(
            R.string.remembrance_notif_line,
            text,
            remembrance.source,
        )

        val contentIntent = PendingIntent.getActivity(
            applicationContext,
            WorkerKeys.DAILY_REMEMBRANCE_NOTIFICATION_ID,
            Intent(applicationContext, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification = NotificationCompat.Builder(
            applicationContext,
            WorkerKeys.CHANNEL_DAILY_REMEMBRANCE,
        )
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(applicationContext.getString(R.string.remembrance_overline))
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setColor(android.graphics.Color.rgb(75, 124, 90))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        // notify() throws SecurityException if POST_NOTIFICATIONS is not granted (Android 13+);
        // swallow so the periodic work does not fail/retry when the user declined the permission.
        runCatching {
            NotificationManagerCompat.from(applicationContext)
                .notify(WorkerKeys.DAILY_REMEMBRANCE_NOTIFICATION_ID, notification)
        }
        return Result.success()
    }

    private fun ensureChannel() {
        val manager = applicationContext.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(WorkerKeys.CHANNEL_DAILY_REMEMBRANCE) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                WorkerKeys.CHANNEL_DAILY_REMEMBRANCE,
                applicationContext.getString(R.string.notif_channel_daily_remembrance_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description =
                    applicationContext.getString(R.string.notif_channel_daily_remembrance_desc)
            },
        )
    }
}
