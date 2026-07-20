package app.awrad.awrad_dhikrgoalstracker.data.sync

import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

internal data class ProgressSyncCountChange(
    val goalId: UUID,
    val delta: Long,
)

data class RemoteCountSyncEvent(
    val id: UUID = UUID.randomUUID(),
    val goalId: UUID,
    val delta: Long,
)

internal fun aggregateRemoteCountChanges(
    changes: List<ProgressSyncCountChange>,
): Map<UUID, Long> = buildMap {
    changes.forEach { change ->
        val current = get(change.goalId) ?: 0L
        val combined = runCatching { Math.addExact(current, change.delta) }
            .getOrElse { if (change.delta > 0L) Long.MAX_VALUE else Long.MIN_VALUE }
        if (combined == 0L) remove(change.goalId) else put(change.goalId, combined)
    }
}

@Singleton
class ProgressSyncFeedbackBus @Inject constructor() {
    private val _remoteCountEvents = MutableSharedFlow<RemoteCountSyncEvent>(
        extraBufferCapacity = 32,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val remoteCountEvents: SharedFlow<RemoteCountSyncEvent> = _remoteCountEvents.asSharedFlow()

    internal fun publish(changes: List<ProgressSyncCountChange>) {
        aggregateRemoteCountChanges(changes).forEach { (goalId, delta) ->
            _remoteCountEvents.tryEmit(RemoteCountSyncEvent(goalId = goalId, delta = delta))
        }
    }
}
