package app.awrad.core.domain.sync

import java.time.Duration
import kotlin.random.Random

/**
 * When a phone syncs (contracts/sync/v1/README.md, "Cadence"): on app start, 2 seconds after the last change, and
 * every 5 minutes while the app is open. After a failure it waits 5 seconds, doubling up to 5 minutes, each wait
 * moved by up to 20% either way so phones don't retry in step.
 */
public object SyncCadence {
    public val DEBOUNCE: Duration = Duration.ofSeconds(2)
    public val PERIOD: Duration = Duration.ofMinutes(5)
    public val FIRST_BACKOFF: Duration = Duration.ofSeconds(5)
    public val MAX_BACKOFF: Duration = Duration.ofMinutes(5)
    public const val JITTER: Double = 0.2

    /** Commands per request (the endpoint takes 1 to 100). */
    public const val BATCH_SIZE: Int = 100

    /** Changes per page asked for (the feed's default). */
    public const val PAGE_SIZE: Int = 200

    /**
     * The wait after the [failures]th failure in a row (1 for the first): 5 s × 2^(failures − 1), at most 5 min,
     * times a factor in [1 − 20%, 1 + 20%] from [random].
     */
    public fun backoff(failures: Int, random: Random = Random.Default): Duration {
        require(failures >= 1) { "No failure, no backoff" }
        val doublings = (failures - 1).coerceAtMost(MAX_DOUBLINGS)
        val base = FIRST_BACKOFF.toMillis().toDouble() * Math.pow(2.0, doublings.toDouble())
        val capped = base.coerceAtMost(MAX_BACKOFF.toMillis().toDouble())
        val factor = 1 + JITTER * (random.nextDouble() * 2 - 1)
        return Duration.ofMillis((capped * factor).toLong())
    }

    /** Enough doublings to pass the cap, without overflowing. */
    private const val MAX_DOUBLINGS = 16
}
