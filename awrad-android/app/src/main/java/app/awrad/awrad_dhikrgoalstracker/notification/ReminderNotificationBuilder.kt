package app.awrad.awrad_dhikrgoalstracker.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import androidx.core.app.NotificationCompat
import app.awrad.awrad_dhikrgoalstracker.MainActivity
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.service.DhikrCountingService
import app.awrad.awrad_dhikrgoalstracker.util.RemembranceProvider
import dagger.hilt.android.qualifiers.ApplicationContext
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

data class GoalNotificationData(
    val goalId: Long,
    val dhikrName: String,
    val todayCount: Long,
    val dailyTarget: Long,
    val isFollowUp: Boolean = false,
    val slotId: Long? = null,
    val slotLabel: String? = null,
    val isTracker: Boolean = false,
)

@Singleton
class ReminderNotificationBuilder @Inject constructor(
    @ApplicationContext private val context: Context,
    private val remembranceProvider: RemembranceProvider,
) {
    private val notificationManager =
        context.getSystemService(NotificationManager::class.java)

    /**
     * The day's remembrance as a "quote — source" line, or null if unavailable.
     * Uses [LocalDate.now] so Home and notifications agree on the same daily pick.
     */
    private fun remembranceLine(): String? {
        val remembrance = remembranceProvider.forDate(LocalDate.now())
        val text = remembrance.notificationText
        if (text.isBlank()) return null
        return context.getString(R.string.remembrance_notif_line, text, remembrance.source)
    }

    /** Appends the day's remembrance to [body] on its own line, if available. */
    private fun withRemembrance(body: String): String {
        val line = remembranceLine() ?: return body
        return "$body\n\n$line"
    }

    fun showGoalReminder(data: GoalNotificationData) {
        ensureGoalChannel()

        val title = buildTitle(data)
        val remaining = (data.dailyTarget - data.todayCount).coerceAtLeast(0)
        val body = buildBody(data, remaining)
        val expandedBody = withRemembrance(buildExpandedBody(data, remaining))

        val notificationId = WorkerKeys.NOTIFICATION_BASE_ID + (data.goalId % 900).toInt()

        val contentIntent = buildContentIntent(data.goalId, data.slotId, notificationId)
        val startAction = buildStartCountingAction(data.goalId, data.slotId, notificationId)
        val dismissAction = buildDismissAction(data.goalId, notificationId)

        val progress = if (!data.isTracker && data.dailyTarget > 0) {
            (data.todayCount * 100 / data.dailyTarget).toInt().coerceIn(0, 100)
        } else 0

        val builder = NotificationCompat.Builder(context, WorkerKeys.CHANNEL_GOAL_REMINDERS)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(expandedBody))
            .setColor(AWRAD_NOTIFICATION_COLOR)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(buildPublicVersion(WorkerKeys.CHANNEL_GOAL_REMINDERS, NotificationCompat.PRIORITY_HIGH))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setShowWhen(true)
            .setContentIntent(contentIntent)
            .addAction(startAction)
            .addAction(dismissAction)
            .setAutoCancel(true)

        if (!data.isTracker && data.dailyTarget > 0) {
            builder.setProgress(100, progress, false)
        }

        val notification = builder.build()

        notificationManager.notify(notificationId, notification)
    }

    fun showGlobalReminder() {
        ensureGlobalChannel()

        val contentIntent = PendingIntent.getActivity(
            context,
            WorkerKeys.GLOBAL_NOTIFICATION_ID,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification = NotificationCompat.Builder(context, WorkerKeys.CHANNEL_GLOBAL_REMINDER)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(context.getString(R.string.notif_global_title))
            .setContentText(context.getString(R.string.notif_global_body))
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(withRemembrance(context.getString(R.string.notif_global_expanded_body))),
            )
            .setColor(AWRAD_NOTIFICATION_COLOR)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(buildPublicVersion(WorkerKeys.CHANNEL_GLOBAL_REMINDER, NotificationCompat.PRIORITY_DEFAULT))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setShowWhen(true)
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(WorkerKeys.GLOBAL_NOTIFICATION_ID, notification)
    }

    private fun buildTitle(data: GoalNotificationData): String {
        val name = data.dhikrName
        return when {
            data.isFollowUp -> context.getString(R.string.notif_title_followup, name)
            data.slotLabel != null -> context.getString(R.string.notif_title_slot, name, data.slotLabel)
            else -> context.getString(R.string.notif_title_reminder, name)
        }
    }

    private fun buildBody(data: GoalNotificationData, remaining: Long): String {
        return when {
            data.isTracker -> context.getString(R.string.notif_body_tracker)
            data.isFollowUp -> context.getString(R.string.notif_body_followup, remaining)
            data.slotLabel != null -> context.getString(R.string.notif_body_slot_remaining, data.slotLabel, remaining)
            else -> context.getString(
                R.string.notif_body_remaining,
                remaining,
                data.todayCount,
                data.dailyTarget,
            )
        }
    }

    private fun buildExpandedBody(data: GoalNotificationData, remaining: Long): String {
        return when {
            data.isTracker -> context.getString(R.string.notif_expanded_tracker)
            data.isFollowUp -> context.getString(
                R.string.notif_expanded_followup,
                remaining,
                data.todayCount,
                data.dailyTarget,
            )
            data.slotLabel != null -> context.getString(
                R.string.notif_expanded_slot,
                data.slotLabel,
                remaining,
                data.todayCount,
                data.dailyTarget,
            )
            else -> context.getString(
                R.string.notif_expanded_goal,
                remaining,
                data.todayCount,
                data.dailyTarget,
            )
        }
    }

    private fun buildContentIntent(goalId: Long, slotId: Long?, notificationId: Int): PendingIntent {
        return PendingIntent.getActivity(
            context,
            notificationId,
            Intent(context, MainActivity::class.java).apply {
                putExtra(DhikrCountingService.EXTRA_GOAL_ID, goalId)
                slotId?.let { putExtra(DhikrCountingService.EXTRA_SLOT_ID, it) }
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun buildStartCountingAction(goalId: Long, slotId: Long?, notificationId: Int): NotificationCompat.Action {
        val intent = PendingIntent.getActivity(
            context,
            notificationId + 50000,
            Intent(context, MainActivity::class.java).apply {
                putExtra(DhikrCountingService.EXTRA_GOAL_ID, goalId)
                slotId?.let { putExtra(DhikrCountingService.EXTRA_SLOT_ID, it) }
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Action.Builder(
            R.drawable.ic_action_count,
            context.getString(R.string.notif_action_start),
            intent,
        ).build()
    }

    private fun buildDismissAction(goalId: Long, notificationId: Int): NotificationCompat.Action {
        val intent = PendingIntent.getBroadcast(
            context,
            notificationId + 60000,
            Intent(context, DismissNotificationReceiver::class.java).apply {
                action = WorkerKeys.ACTION_DISMISS_NOTIFICATION
                putExtra(WorkerKeys.EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(WorkerKeys.EXTRA_GOAL_ID, goalId)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Action.Builder(
            R.drawable.ic_action_dismiss,
            context.getString(R.string.notif_action_dismiss),
            intent,
        ).build()
    }

    private fun buildPublicVersion(channelId: String, priority: Int) =
        NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(context.getString(R.string.notif_public_title))
            .setContentText(context.getString(R.string.notif_public_body))
            .setColor(AWRAD_NOTIFICATION_COLOR)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(priority)
            .build()

    private fun ensureGoalChannel() {
        if (notificationManager.getNotificationChannel(WorkerKeys.CHANNEL_GOAL_REMINDERS) != null) return
        val channel = NotificationChannel(
            WorkerKeys.CHANNEL_GOAL_REMINDERS,
            context.getString(R.string.notif_channel_reminders_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.notif_channel_reminders_desc)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun ensureGlobalChannel() {
        if (notificationManager.getNotificationChannel(WorkerKeys.CHANNEL_GLOBAL_REMINDER) != null) return
        val channel = NotificationChannel(
            WorkerKeys.CHANNEL_GLOBAL_REMINDER,
            context.getString(R.string.notif_channel_global_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.notif_channel_global_desc)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private companion object {
        val AWRAD_NOTIFICATION_COLOR: Int = Color.rgb(75, 124, 90)
    }
}
