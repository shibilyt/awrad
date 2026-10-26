package app.awrad.feature.account

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Counts down the seconds until "send a new code" is offered again, reporting each second to [onTick].
 * The server's `202` says nothing about when to resend, so it's [DEFAULT_SECONDS] (contracts/api
 * `CodeSent`), or a `429`'s `Retry-After`.
 */
internal class ResendCooldown(
    private val scope: CoroutineScope,
    private val onTick: (secondsLeft: Int) -> Unit,
) {
    private var job: Job? = null

    fun start(seconds: Long? = null) {
        job?.cancel()
        val total = (seconds ?: DEFAULT_SECONDS).coerceIn(1, MAX_SECONDS).toInt()
        onTick(total)
        job = scope.launch {
            for (left in total - 1 downTo 0) {
                delay(ONE_SECOND_MS)
                onTick(left)
            }
        }
    }

    companion object {
        const val DEFAULT_SECONDS = 60L
        private const val MAX_SECONDS = 3_600L
        private const val ONE_SECOND_MS = 1_000L
    }
}
