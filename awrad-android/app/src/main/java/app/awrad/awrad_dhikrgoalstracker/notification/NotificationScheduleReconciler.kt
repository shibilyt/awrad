package app.awrad.awrad_dhikrgoalstracker.notification

import javax.inject.Inject
import javax.inject.Singleton

/**
 * Android-effect boundary for the desired notification schedule.
 *
 * A failed effect leaves the manifest untouched. Retrying the same desired state is safe because
 * [NotificationSchedulingEffectGateway] operations are required to be idempotent by identity.
 */
interface NotificationSchedulingEffectGateway {
    /** Schedules or updates the pending platform work represented by [record]. */
    suspend fun schedule(record: NotificationScheduleRecord): NotificationSchedulingEffectResult

    /** Cancels only pending platform work. Implementations must be idempotent. */
    suspend fun cancelPending(identity: NotificationIdentity)

    /** Cancels only a visible notification. Implementations must be idempotent. */
    suspend fun cancelVisible(identity: NotificationIdentity)
}

sealed interface NotificationSchedulingEffectResult {
    data object Scheduled : NotificationSchedulingEffectResult
    data object Stale : NotificationSchedulingEffectResult
}

data class NotificationScheduleReconcileResult(
    val unchanged: List<String>,
    val scheduled: List<String>,
    val rescheduled: List<String>,
    val cancelled: List<String>,
    val stale: List<String>,
    val deliveredSuppressed: List<String>,
    val malformedCleanedCount: Int,
)

/** Maps a planner candidate to mutable scheduling data while preserving its semantic identity. */
fun NudgeCandidate.toNotificationScheduleRecord(): NotificationScheduleRecord =
    NotificationScheduleRecord(
        identity = NotificationIdentity.from(key),
        triggerAtMillis = triggerAtMillis,
        expiresAtMillis = expiresAtMillis,
        kind = key.kind,
    )

@Singleton
class NotificationScheduleReconciler @Inject constructor(
    private val store: NotificationScheduleStore,
    private val effects: NotificationSchedulingEffectGateway,
    private val coordinator: NotificationScheduleCoordinator,
) {
    suspend fun reconcile(
        desiredRecords: Collection<NotificationScheduleRecord>,
    ): NotificationScheduleReconcileResult {
        val desiredByIdentity = desiredRecords.indexByCanonicalIdentity()
        return coordinator.withScheduleLock {
            reconcileLocked(desiredByIdentity)
        }
    }

    private suspend fun reconcileLocked(
        desiredByIdentity: Map<String, NotificationScheduleRecord>,
    ): NotificationScheduleReconcileResult {
        val state = store.read()
        val deliveredKeys = state.delivered.mapTo(hashSetOf()) { it.identity.canonicalKey }
        val deliveredSuppressed = desiredByIdentity.keys
            .filter { it in deliveredKeys }
            .sorted()
        val activeDesired = desiredByIdentity
            .filterKeys { it !in deliveredKeys }
            .toSortedMap()
        val currentByIdentity = state.manifest.associateBy { it.identity.canonicalKey }

        val stale = currentByIdentity
            .filterKeys { it !in activeDesired }
            .toSortedMap()
        val replacements = activeDesired
            .filter { (identity, desired) ->
                currentByIdentity[identity]?.let { current -> current != desired } == true
            }
            .toSortedMap()
        val additions = activeDesired
            .filterKeys { it !in currentByIdentity }
            .toSortedMap()
        val unchanged = activeDesired.keys
            .filter { identity -> currentByIdentity[identity] == activeDesired.getValue(identity) }
            .sorted()

        // Cancellation always precedes scheduling; any failure prevents the manifest replacement.
        for (record in stale.values) effects.cancelPending(record.identity)
        for (identity in replacements.keys) effects.cancelPending(currentByIdentity.getValue(identity).identity)
        val scheduledOrUpdated = (additions + replacements).toSortedMap().values
            .mapNotNull { record ->
                when (effects.schedule(record)) {
                    NotificationSchedulingEffectResult.Scheduled -> record
                    NotificationSchedulingEffectResult.Stale -> null
                }
            }
        val staleDesired = (additions + replacements).toSortedMap()
            .filterValues { candidate -> scheduledOrUpdated.none { it.identity == candidate.identity } }
        val scheduledIdentities = scheduledOrUpdated.mapTo(hashSetOf()) { it.identity.canonicalKey }

        if (stale.isNotEmpty() || replacements.isNotEmpty() || additions.isNotEmpty()) {
            // The store atomically excludes stages delivered since the read above.
            store.replaceManifest(
                (activeDesired - staleDesired.keys).values,
            )
        }

        return NotificationScheduleReconcileResult(
            unchanged = unchanged,
            scheduled = additions.keys.filter { it in scheduledIdentities },
            rescheduled = replacements.keys.filter { it in scheduledIdentities },
            cancelled = stale.keys.toList(),
            stale = staleDesired.keys.toList(),
            deliveredSuppressed = deliveredSuppressed,
            malformedCleanedCount = state.discardedEntryCount,
        )
    }

    private fun Collection<NotificationScheduleRecord>.indexByCanonicalIdentity():
        Map<String, NotificationScheduleRecord> {
        val indexed = associateBy { it.identity.canonicalKey }
        require(indexed.size == size) { "Desired notification records must have unique canonical identities" }
        return indexed
    }
}
