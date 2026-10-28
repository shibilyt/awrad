package app.awrad.core.data.sync

import app.awrad.core.domain.sync.SyncCadence
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.random.Random

/**
 * When the engine runs (contracts/sync/v1/README.md, "Cadence"): [runWhileOpen] syncs at once, then every
 * 5 minutes, and soon after each [request] (2 seconds after the last edit, or straight away). After a failure it
 * backs off from 5 seconds to 5 minutes with ±20% jitter, or waits for the server's `Retry-After`.
 */
internal class SyncScheduler(
    private val sync: suspend () -> SyncOutcome,
    private val random: Random = Random.Default,
) {
    private val requests = Channel<Boolean>(Channel.CONFLATED)

    /** Asks for a sync: after the debounce when [debounced] (an edit), else at once (sign-in, a resolution). */
    fun request(debounced: Boolean) {
        requests.trySend(debounced)
    }

    /** Runs until cancelled: call it while the app is open (started), and cancel it when the app goes away. */
    suspend fun runWhileOpen() {
        var failures = 0
        while (true) {
            val outcome = sync()
            failures = if (outcome is SyncOutcome.Failed) failures + 1 else 0
            val wait = when (outcome) {
                is SyncOutcome.Failed -> outcome.retryAfter ?: SyncCadence.backoff(failures, random)
                else -> SyncCadence.PERIOD
            }
            val debounced = withTimeoutOrNull(wait.toMillis()) { requests.receive() } ?: continue
            if (debounced) debounce()
        }
    }

    /** Waits until no request has come for [SyncCadence.DEBOUNCE]; an immediate request ends the wait. */
    private suspend fun debounce() {
        while (true) {
            val debounced = withTimeoutOrNull(SyncCadence.DEBOUNCE.toMillis()) { requests.receive() } ?: return
            if (!debounced) return
        }
    }
}
