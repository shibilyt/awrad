package app.awrad.awrad_dhikrgoalstracker.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import app.awrad.awrad_dhikrgoalstracker.di.ApplicationCoroutineScope
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Explicit endpoint for engine-generated nudges.
 *
 * Delivery is intentionally deferred to Slice 5C; accepting this envelope here keeps fallback
 * work from entering the configured-reminder receiver and preserves the original trigger.
 */
@AndroidEntryPoint
class UrgencyNudgeReceiver : BroadcastReceiver() {
    @Inject lateinit var processor: UrgencyNudgeDeliveryProcessor
    @Inject lateinit var retryEnqueuer: UrgencyNudgeRetryEnqueuer
    @Inject lateinit var coordinator: NotificationScheduleCoordinator
    @Inject @ApplicationCoroutineScope lateinit var applicationScope: CoroutineScope

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != UrgencyNudgeEnvelopeContract.ACTION_URGENCY_NUDGE) return
        val pendingResult = goAsync()
        applicationScope.launch {
            try {
                val input = UrgencyNudgeWorkInput(
                    canonicalIdentity = intent.getStringExtra(UrgencyNudgeEnvelopeContract.EXTRA_CANONICAL_IDENTITY)
                        ?: return@launch,
                    triggerAtMillis = intent.getLongExtra(
                        UrgencyNudgeEnvelopeContract.EXTRA_TRIGGER_AT_MILLIS,
                        Long.MIN_VALUE,
                    ),
                    expiresAtMillis = intent.getLongExtra(
                        UrgencyNudgeEnvelopeContract.EXTRA_EXPIRES_AT_MILLIS,
                        Long.MIN_VALUE,
                    ),
                    kind = intent.getStringExtra(UrgencyNudgeEnvelopeContract.EXTRA_KIND)
                        ?.let { name -> NudgeKind.entries.firstOrNull { it.name == name } }
                        ?: return@launch,
                )
                val envelope = input.toEnvelope() ?: return@launch
                UrgencyNudgeReceiverDeliveryRunner.run(
                    envelope = envelope,
                    process = processor::process,
                    nowMillis = System::currentTimeMillis,
                    onExpiredCleanup = {
                        coordinator.handleRejectedDelivery(
                            envelope,
                            UrgencyNudgeRejectionReason.EXPIRED,
                        )
                    },
                    enqueueRetry = retryEnqueuer::enqueue,
                )
            } finally {
                pendingResult.finish()
            }
        }
    }
}
