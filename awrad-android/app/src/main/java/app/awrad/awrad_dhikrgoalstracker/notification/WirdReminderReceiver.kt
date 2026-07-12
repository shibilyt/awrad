package app.awrad.awrad_dhikrgoalstracker.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import app.awrad.awrad_dhikrgoalstracker.MainActivity
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.resolve
import app.awrad.awrad_dhikrgoalstracker.data.repository.WirdLibraryRepository
import app.awrad.awrad_dhikrgoalstracker.util.RemembranceProvider
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.Locale
import javax.inject.Inject

@AndroidEntryPoint
class WirdReminderReceiver : BroadcastReceiver() {

    @Inject lateinit var repository: WirdLibraryRepository
    @Inject lateinit var scheduler: WirdReminderScheduler
    @Inject lateinit var remembranceProvider: RemembranceProvider

    override fun onReceive(context: Context, intent: Intent) {
        val wirdId = intent.getStringExtra(WorkerKeys.EXTRA_WIRD_ID) ?: return
        val reminderId = intent.getStringExtra(WorkerKeys.EXTRA_WIRD_REMINDER_ID) ?: return
        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                val wird = repository.getWird(wirdId) ?: return@launch
                val lang = Locale.getDefault().language
                val name = wird.displayName(lang).ifBlank { wird.slug }
                postNotification(context, wirdId, reminderId, name)
                // Daily repeat: schedule the next day's occurrence.
                scheduler.rescheduleNext(wird, reminderId)
            } finally {
                pending.finish()
            }
        }
    }

    private fun postNotification(context: Context, wirdId: String, reminderId: String, name: String) {
        ensureChannel(context)
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            putExtra(WorkerKeys.EXTRA_WIRD_ID, wirdId)
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val notificationId = WorkerKeys.WIRD_NOTIFICATION_BASE_ID +
            ((wirdId + reminderId).hashCode() and 0x7FFF)
        val tapPending = PendingIntent.getActivity(
            context, notificationId, tapIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val body = context.getString(R.string.wird_reminder_body, name)
        val remembrance = remembranceProvider.forDate(java.time.LocalDate.now())
        val expandedBody = remembrance.notificationText.takeIf { it.isNotBlank() }?.let { text ->
            "$body\n\n" + context.getString(R.string.remembrance_notif_line, text, remembrance.source)
        } ?: body
        val notification = NotificationCompat.Builder(context, WorkerKeys.CHANNEL_WIRD_REMINDERS)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(name)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(expandedBody))
            .setAutoCancel(true)
            .setContentIntent(tapPending)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        runCatching {
            NotificationManagerCompat.from(context).notify(notificationId, notification)
        }
    }

    private fun ensureChannel(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(WorkerKeys.CHANNEL_WIRD_REMINDERS) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    WorkerKeys.CHANNEL_WIRD_REMINDERS,
                    context.getString(R.string.wird_reminders),
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
    }
}
