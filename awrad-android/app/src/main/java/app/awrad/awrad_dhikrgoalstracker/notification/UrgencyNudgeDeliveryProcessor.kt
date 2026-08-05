package app.awrad.awrad_dhikrgoalstracker.notification

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabaseLockedException
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.net.toUri
import androidx.work.BackoffPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.ListenableWorker
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import app.awrad.awrad_dhikrgoalstracker.MainActivity
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.service.DhikrCountingService
import app.awrad.awrad_dhikrgoalstracker.notification.workers.UrgencyNudgeWorker
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.IOException
import java.time.Instant
import java.time.ZoneId
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CancellationException

fun interface UrgencyNudgeDurationStringLookup {
    fun get(resourceId: Int, vararg formatArgs: Any): String
}

/** Purely local text formatter. It intentionally derives only from the validated duration. */
object UrgencyNudgeDurationFormatter {
    fun format(
        remainingDurationMillis: Long,
        strings: UrgencyNudgeDurationStringLookup,
    ): String {
        val totalMinutes = (remainingDurationMillis.coerceAtLeast(0L) / MINUTE_MILLIS)
        if (totalMinutes == 0L) return strings.get(R.string.notif_urgency_duration_less_than_minute)
        val days = totalMinutes / (24L * 60L)
        val hours = (totalMinutes % (24L * 60L)) / 60L
        val minutes = totalMinutes % 60L
        return when {
            days > 0L && hours > 0L ->
                strings.get(R.string.notif_urgency_duration_days_hours, days, hours)
            days > 0L -> strings.get(R.string.notif_urgency_duration_days, days)
            hours > 0L && minutes > 0L ->
                strings.get(R.string.notif_urgency_duration_hours_minutes, hours, minutes)
            hours > 0L -> strings.get(R.string.notif_urgency_duration_hours, hours)
            else -> strings.get(R.string.notif_urgency_duration_minutes, minutes)
        }
    }

    private const val MINUTE_MILLIS = 60_000L
}

sealed interface UrgencyNudgeDeliveryOutcome {
    data object Posted : UrgencyNudgeDeliveryOutcome
    data object PermissionDenied : UrgencyNudgeDeliveryOutcome
    data class Rejected(val reason: UrgencyNudgeRejectionReason) : UrgencyNudgeDeliveryOutcome
    data object Retry : UrgencyNudgeDeliveryOutcome
    data object Malformed : UrgencyNudgeDeliveryOutcome
}

data class UrgencyNudgeDeliveryRetryRequest(
    val envelope: AdaptiveNudgeEnvelope,
    val uniqueWorkName: String,
    val workTag: String,
    val initialDelayMillis: Long,
)

object UrgencyNudgeDeliveryRetry {
    private const val INITIAL_DELAY_MILLIS = 5_000L

    fun plan(envelope: AdaptiveNudgeEnvelope, nowMillis: Long): UrgencyNudgeDeliveryRetryRequest? {
        if (nowMillis >= envelope.expiresAtMillis) return null
        return UrgencyNudgeDeliveryRetryRequest(
            envelope = envelope,
            uniqueWorkName = AdaptiveNudgeWorkIdentity.retryUniqueWorkName(envelope),
            workTag = AdaptiveNudgeWorkIdentity.workTag(envelope.identity),
            initialDelayMillis = INITIAL_DELAY_MILLIS,
        )
    }
}

/**
 * Classifies storage failures that are safe to retry before envelope expiry.
 *
 * Only explicitly typed retryable failures are accepted: [IOException] and
 * [SQLiteDatabaseLockedException]. Android maps SQLITE_BUSY and database-locked contention
 * through [SQLiteDatabaseLockedException]; there is no separate busy exception type on the
 * compile SDK / AndroidX Room surface used here. Corruption, constraint, schema, plain
 * `SQLiteException`, and other programming failures remain fatal.
 * [CancellationException] anywhere in the causal chain rejects the whole chain as
 * non-transient, even when a retryable cause is also present. Cause traversal is
 * cycle-safe.
 */
internal object UrgencyNudgeKnownTransientClassifier {
    fun isKnownTransient(error: Throwable): Boolean {
        var sawRetryable = false
        for (node in causeChain(error)) {
            if (node is CancellationException) return false
            if (isDirectlyKnownTransient(node)) sawRetryable = true
        }
        return sawRetryable
    }

    private fun isDirectlyKnownTransient(error: Throwable): Boolean =
        when (error) {
            is CancellationException -> false
            is IOException -> true
            is SQLiteDatabaseLockedException -> true
            else -> false
        }

    /** Walks `error` then successive [Throwable.cause] links, stopping on null or a cycle. */
    private fun causeChain(error: Throwable): Sequence<Throwable> = sequence {
        val seen = HashSet<Throwable>()
        var current: Throwable? = error
        while (current != null && seen.add(current)) {
            yield(current)
            current = current.cause
        }
    }
}

internal object UrgencyNudgeDeliveryFailureMapper {
    suspend fun mapKnownTransient(
        error: Throwable,
        envelope: AdaptiveNudgeEnvelope,
        nowMillis: Long,
        onExpiredCleanup: suspend () -> Unit,
    ): UrgencyNudgeDeliveryOutcome {
        if (error is CancellationException || !UrgencyNudgeKnownTransientClassifier.isKnownTransient(error)) {
            throw error
        }
        if (nowMillis < envelope.expiresAtMillis) return UrgencyNudgeDeliveryOutcome.Retry
        onExpiredCleanup()
        return UrgencyNudgeDeliveryOutcome.Rejected(UrgencyNudgeRejectionReason.EXPIRED)
    }
}

/**
 * Settles a processor [UrgencyNudgeDeliveryOutcome.Retry] against a freshly read clock before
 * the exact receiver enqueues retry work or the worker returns [ListenableWorker.Result.retry].
 *
 * When the envelope has expired since the processor observed a pre-expiry retryable failure,
 * runs the same EXPIRED consumed-stage cleanup as
 * [NotificationScheduleCoordinator.handleRejectedDelivery] and maps to a terminal no-retry
 * result. Cleanup failures propagate to the caller so the ledger is not silently left behind.
 * Does not re-enter the delivery processor or schedule coordinator beyond that cleanup path.
 */
sealed interface UrgencyNudgeRetrySettlement {
    data object ProceedWithRetry : UrgencyNudgeRetrySettlement
    data object TerminalExpired : UrgencyNudgeRetrySettlement
}

internal object UrgencyNudgeRetrySettlementApi {
    suspend fun settle(
        envelope: AdaptiveNudgeEnvelope,
        nowMillis: Long,
        onExpiredCleanup: suspend () -> Unit,
    ): UrgencyNudgeRetrySettlement {
        if (nowMillis < envelope.expiresAtMillis) {
            return UrgencyNudgeRetrySettlement.ProceedWithRetry
        }
        onExpiredCleanup()
        return UrgencyNudgeRetrySettlement.TerminalExpired
    }
}

internal object UrgencyNudgeReceiverDeliveryRunner {
    suspend fun run(
        envelope: AdaptiveNudgeEnvelope,
        process: suspend (AdaptiveNudgeEnvelope) -> UrgencyNudgeDeliveryOutcome,
        nowMillis: () -> Long,
        onExpiredCleanup: suspend () -> Unit,
        enqueueRetry: (AdaptiveNudgeEnvelope) -> Unit,
    ) {
        if (process(envelope) != UrgencyNudgeDeliveryOutcome.Retry) return
        when (
            UrgencyNudgeRetrySettlementApi.settle(
                envelope = envelope,
                nowMillis = nowMillis(),
                onExpiredCleanup = onExpiredCleanup,
            )
        ) {
            UrgencyNudgeRetrySettlement.ProceedWithRetry -> enqueueRetry(envelope)
            UrgencyNudgeRetrySettlement.TerminalExpired -> Unit
        }
    }
}

internal object UrgencyNudgeWorkerOutcomeMapper {
    suspend fun toWorkerResult(
        outcome: UrgencyNudgeDeliveryOutcome,
        envelope: AdaptiveNudgeEnvelope,
        nowMillis: Long,
        onExpiredCleanup: suspend () -> Unit,
    ): ListenableWorker.Result =
        when (outcome) {
            UrgencyNudgeDeliveryOutcome.Retry ->
                when (
                    UrgencyNudgeRetrySettlementApi.settle(
                        envelope = envelope,
                        nowMillis = nowMillis,
                        onExpiredCleanup = onExpiredCleanup,
                    )
                ) {
                    UrgencyNudgeRetrySettlement.ProceedWithRetry ->
                        ListenableWorker.Result.retry()
                    UrgencyNudgeRetrySettlement.TerminalExpired ->
                        ListenableWorker.Result.success()
                }
            else -> ListenableWorker.Result.success()
        }
}

@Singleton
class UrgencyNudgeRetryEnqueuer @Inject constructor(
    private val workManager: WorkManager,
) {
    fun enqueue(envelope: AdaptiveNudgeEnvelope, nowMillis: Long = System.currentTimeMillis()) {
        val retry = UrgencyNudgeDeliveryRetry.plan(envelope, nowMillis) ?: return
        workManager.enqueueUniqueWork(
            retry.uniqueWorkName,
            ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<UrgencyNudgeWorker>()
                .setInputData(UrgencyNudgeWorkInput.from(retry.envelope).toData())
                .setInitialDelay(retry.initialDelayMillis, TimeUnit.MILLISECONDS)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, INITIAL_BACKOFF_MILLIS, TimeUnit.MILLISECONDS)
                .addTag(retry.workTag)
                .build(),
        )
    }

    private companion object {
        const val INITIAL_BACKOFF_MILLIS = 10_000L
    }
}

private class NotificationPermissionDeniedException : IllegalStateException()

/** The only code that touches NotificationManager for urgency delivery. */
@Singleton
class AndroidUrgencyNudgePostingAction @Inject constructor(
    @ApplicationContext private val context: Context,
) : UrgencyNudgePostingAction {
    private val manager = context.getSystemService(NotificationManager::class.java)

    override suspend fun post(nudge: PlannedUrgencyNudge) {
        if (!hasNotificationPermission()) throw NotificationPermissionDeniedException()
        try {
            ensureChannel()
        } catch (_: SecurityException) {
            throw NotificationPermissionDeniedException()
        }
        val remaining = nudge.remainingCount?.coerceAtLeast(0L)
        val duration = UrgencyNudgeDurationFormatter.format(nudge.remainingDurationMillis ?: 0L) { id, args ->
            context.getString(id, *args)
        }
        val copy = context.getString(R.string.notif_urgency_time_remaining_about, duration)
        val body = when {
            nudge.record.kind == NudgeKind.STREAK_GUARDIAN && remaining == null ->
                context.getString(R.string.notif_urgency_tracker_guardian, copy, nudge.goalName)
            nudge.record.kind == NudgeKind.STREAK_GUARDIAN ->
                context.getString(R.string.notif_urgency_streak_guardian, nudge.currentStreak.coerceAtLeast(0), copy, remaining)
            nudge.slotId != null && remaining != null && !nudge.goalName.isBlank() ->
                context.getString(R.string.notif_urgency_slot_deadline, copy, remaining, nudge.goalName)
            nudge.slotId != null && remaining != null ->
                context.getString(R.string.notif_urgency_slot_deadline_generic, copy, remaining)
            remaining != null && !nudge.goalName.isBlank() ->
                context.getString(R.string.notif_urgency_anytime_deadline, copy, remaining, nudge.goalName)
            remaining != null -> context.getString(R.string.notif_urgency_deadline_generic, copy, remaining)
            else -> copy
        }
        try {
            manager.notify(
                nudge.record.identity.notificationTag,
                nudge.record.identity.notificationId,
                NotificationCompat.Builder(context, WorkerKeys.CHANNEL_GOAL_REMINDERS)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(context.getString(R.string.notif_public_title))
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(contentIntent(nudge))
                .build(),
            )
        } catch (_: SecurityException) {
            throw NotificationPermissionDeniedException()
        }
    }

    private fun contentIntent(nudge: PlannedUrgencyNudge): PendingIntent =
        PendingIntent.getActivity(
            context,
            nudge.record.identity.notificationId,
            Intent(context, MainActivity::class.java).apply {
                data = nudge.record.identity.pendingIntentDataUri.toUri()
                putExtra(DhikrCountingService.EXTRA_GOAL_ID, nudge.goalId.toString())
                nudge.slotId?.let { putExtra(DhikrCountingService.EXTRA_SLOT_ID, it.toString()) }
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    private fun ensureChannel() {
        if (manager.getNotificationChannel(WorkerKeys.CHANNEL_GOAL_REMINDERS) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    WorkerKeys.CHANNEL_GOAL_REMINDERS,
                    context.getString(R.string.notif_channel_reminders_name),
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply { description = context.getString(R.string.notif_channel_reminders_desc) },
            )
        }
    }

    fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
}

@Singleton
class UrgencyNudgeDeliveryProcessor @Inject constructor(
    private val validator: UrgencyNudgeFireValidator,
    private val postingAction: AndroidUrgencyNudgePostingAction,
    private val planningContextProvider: NotificationObligationPlanningContextProvider,
    private val coordinator: NotificationScheduleCoordinator,
) {
    suspend fun process(envelope: AdaptiveNudgeEnvelope): UrgencyNudgeDeliveryOutcome {
        return try {
            if (!postingAction.hasNotificationPermission()) {
                coordinator.consumeWithoutDelivery(envelope)
                return UrgencyNudgeDeliveryOutcome.PermissionDenied
            }
            val now = System.currentTimeMillis()
            val planInput = planningContextProvider.create(Instant.ofEpochMilli(now), ZoneId.systemDefault())
            val context = UrgencyNudgeValidationContext(
                nowMillis = now,
                zoneId = planInput.zoneId,
                dayReset = planInput.dayReset,
                defaultPrayerLeadMinutes = planInput.defaultPrayerLeadMinutes,
                appLanguage = planInput.appLanguage,
                maghribForCivilDate = planInput.maghribForCivilDate,
                prayerTimesForOccurrenceDate = planInput.prayerTimesForOccurrenceDate,
            )
            when (val result = validator.validateAndPost(envelope, context, postingAction)) {
                is UrgencyNudgeValidationOutcome.Valid -> UrgencyNudgeDeliveryOutcome.Posted
                is UrgencyNudgeValidationOutcome.Rejected -> {
                    coordinator.handleRejectedDelivery(envelope, result.reason)
                    UrgencyNudgeDeliveryOutcome.Rejected(result.reason)
                }
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: NotificationPermissionDeniedException) {
            coordinator.consumeWithoutDelivery(envelope)
            UrgencyNudgeDeliveryOutcome.PermissionDenied
        } catch (error: Exception) {
            UrgencyNudgeDeliveryFailureMapper.mapKnownTransient(
                error = error,
                envelope = envelope,
                nowMillis = System.currentTimeMillis(),
                onExpiredCleanup = {
                    coordinator.handleRejectedDelivery(envelope, UrgencyNudgeRejectionReason.EXPIRED)
                },
            )
        }
    }

}
