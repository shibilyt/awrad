package app.awrad.awrad_dhikrgoalstracker.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import app.awrad.awrad_dhikrgoalstracker.notification.workers.DailySchedulerWorker
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.concurrent.TimeUnit
import javax.inject.Inject

/**
 * Reschedules all alarms after system events that clear pending alarms:
 * device boot, app update, time/timezone change, alarm permission change.
 */
@AndroidEntryPoint
class BootRescheduleReceiver : BroadcastReceiver() {

    @Inject lateinit var reminderScheduler: ReminderScheduler
    @Inject lateinit var wirdReminderScheduler: WirdReminderScheduler
    @Inject lateinit var notificationObligationEngine: NotificationObligationEngine
    @Inject lateinit var workManager: WorkManager

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
            BootRescheduleActionRunner.run(
                rescheduleWird = { wirdReminderScheduler.rescheduleAll() },
                reconcileUrgency = {
                    notificationObligationEngine.reconcileNow(
                        NotificationObligationRequestReason.BOOT_OR_TIME,
                    )
                },
                enqueueUrgencyRetry = ::enqueueUrgencyRetry,
                onWirdFailure = { error ->
                    Log.e(TAG, "Failed to reschedule wird reminders", error)
                },
                onUrgencyUnexpectedFailure = { error ->
                    Log.e(TAG, "Failed to reconcile urgency obligations after boot", error)
                },
                finish = pending::finish,
            )
        }
    }

    private fun enqueueUrgencyRetry() {
        workManager.enqueueUniqueWork(
            URGENCY_RETRY_WORK,
            ExistingWorkPolicy.KEEP,
            OneTimeWorkRequestBuilder<DailySchedulerWorker>()
                .setInitialDelay(1, TimeUnit.MINUTES)
                .build(),
        )
    }

    companion object {
        private const val TAG = "BootRescheduleReceiver"
        private const val URGENCY_RETRY_WORK = "notification_obligation_boot_retry"
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

/**
 * Isolates configured Wird reschedule failures from urgency engine reconciliation on the boot
 * path, and guarantees [finish] runs exactly once even when urgency work fails or cancels.
 */
internal object BootRescheduleActionRunner {
    suspend fun run(
        rescheduleWird: suspend () -> Unit,
        reconcileUrgency: suspend () -> NotificationObligationEngineResult,
        enqueueUrgencyRetry: () -> Unit,
        onWirdFailure: (Exception) -> Unit,
        onUrgencyUnexpectedFailure: (Exception) -> Unit,
        finish: () -> Unit,
    ) {
        try {
            try {
                rescheduleWird()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                onWirdFailure(error)
            }

            try {
                when (reconcileUrgency()) {
                    NotificationObligationEngineResult.Reconciled -> Unit
                    is NotificationObligationEngineResult.TransientFailure -> enqueueUrgencyRetry()
                    is NotificationObligationEngineResult.FatalFailure -> Unit
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                onUrgencyUnexpectedFailure(error)
            }
        } finally {
            finish()
        }
    }
}
