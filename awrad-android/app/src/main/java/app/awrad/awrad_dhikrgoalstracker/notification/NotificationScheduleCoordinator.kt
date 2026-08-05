package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Process-wide critical section for notification schedule effects and their local ledger.
 *
 * Effects run before the corresponding ledger mutation. A failure leaves ledger state untouched;
 * callers can retry because effect operations are idempotent by semantic identity.
 */
@Singleton
class NotificationScheduleCoordinator @Inject constructor(
    private val store: NotificationScheduleStore,
    private val effects: NotificationSchedulingEffectGateway,
) {
    private val mutex = Mutex()

    internal suspend fun <T> withScheduleLock(block: suspend () -> T): T {
        val owner = currentCoroutineContext()[Job] ?: this
        return mutex.withLock(owner) { block() }
    }

    /** Must only be called from [withScheduleLock]. */
    internal suspend fun markDeliveredInScheduleLock(
        identity: NotificationIdentity,
        deliveredAtMillis: Long,
        expiresAtMillis: Long? = null,
    ) {
        store.markDelivered(identity, deliveredAtMillis, expiresAtMillis)
    }

    suspend fun recordDelivered(identity: NotificationIdentity, deliveredAtMillis: Long) = withScheduleLock {
        // Delivery must not dismiss the notification that was just shown.
        effects.cancelPending(identity)
        markDeliveredInScheduleLock(identity, deliveredAtMillis)
    }

    /**
     * Dismisses currently visible urgency notifications for committed goal mutations while retaining
     * their delivered tombstones, which are still required for dedupe.
     */
    suspend fun dismissDeliveredVisibleForGoal(goalId: AwradId) =
        dismissDeliveredVisibleForGoals(setOf(goalId))

    suspend fun dismissDeliveredVisibleForGoals(goalIds: Set<AwradId>) = withScheduleLock {
        if (goalIds.isEmpty()) return@withScheduleLock
        store.read()
            .delivered
            .asSequence()
            .map { it.identity }
            .filter { it.goalId in goalIds }
            .distinct()
            .sortedBy { it.canonicalKey }
            .forEach { identity -> effects.cancelVisible(identity) }
    }

    /** Dismisses all visible urgency stages without clearing their delivered tombstones. */
    suspend fun dismissAllDeliveredVisible() = withScheduleLock {
        store.read()
            .delivered
            .asSequence()
            .map { it.identity }
            .distinct()
            .sortedBy { it.canonicalKey }
            .forEach { identity -> effects.cancelVisible(identity) }
    }

    suspend fun clearExact(canonicalKey: String) = withScheduleLock {
        NotificationIdentity.parse(canonicalKey)?.let { identity ->
            effects.cancelPending(identity)
            effects.cancelVisible(identity)
        }
        store.clearExact(canonicalKey)
    }

    suspend fun clearGoal(goalId: AwradId) = withScheduleLock {
        val identities = store.read()
            .let { state -> state.manifest.map { it.identity } + state.delivered.map { it.identity } }
            .filter { it.goalId == goalId }
            .distinct()
            .sortedBy { it.canonicalKey }
        for (identity in identities) {
            effects.cancelPending(identity)
            effects.cancelVisible(identity)
        }
        store.clearGoal(goalId)
    }

    suspend fun retainDelivered(retainedCanonicalKeys: Set<String>) = withScheduleLock {
        store.retainDelivered(retainedCanonicalKeys)
    }

    suspend fun pruneDelivered(nowMillis: Long, retentionMillis: Long) = withScheduleLock {
        store.pruneDelivered(nowMillis, retentionMillis)
    }

    /** Clears only the consumed record; a newer replacement with the same identity is retained. */
    internal suspend fun consumeWithoutDelivery(envelope: AdaptiveNudgeEnvelope) = withScheduleLock {
        consumeWithoutDeliveryInScheduleLock(envelope)
    }

    private suspend fun consumeWithoutDeliveryInScheduleLock(envelope: AdaptiveNudgeEnvelope) {
        val state = store.read()
        val record = state.manifest.singleOrNull { it.identity == envelope.identity }
        if (record?.triggerAtMillis == envelope.triggerAtMillis &&
            record.expiresAtMillis == envelope.expiresAtMillis &&
            record.kind == envelope.kind
        ) {
            effects.cancelPending(envelope.identity)
            store.replaceManifest(state.manifest.filterNot { it == record })
        }
    }

    internal suspend fun handleRejectedDelivery(
        envelope: AdaptiveNudgeEnvelope,
        reason: UrgencyNudgeRejectionReason,
    ) = withScheduleLock {
        when (reason) {
            UrgencyNudgeRejectionReason.ALREADY_DELIVERED,
            UrgencyNudgeRejectionReason.EXPIRED,
            UrgencyNudgeRejectionReason.DISABLED,
            UrgencyNudgeRejectionReason.NO_LONGER_RELEVANT,
            UrgencyNudgeRejectionReason.TRIGGER_UNDERFLOW -> consumeWithoutDeliveryInScheduleLock(envelope)
            UrgencyNudgeRejectionReason.TOO_EARLY -> {
                val state = store.read()
                state.manifest.singleOrNull { it.identity == envelope.identity }?.let { effects.schedule(it) }
            }
            UrgencyNudgeRejectionReason.NOT_SCHEDULED_OR_REPLACED -> Unit
        }
    }
}
