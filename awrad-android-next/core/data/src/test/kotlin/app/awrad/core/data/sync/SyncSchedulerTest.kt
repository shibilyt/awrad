@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package app.awrad.core.data.sync

import app.awrad.core.domain.sync.SyncCadence
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import java.time.Duration
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** The cadence in virtual time: start, debounce, period, and backoff with jitter. */
class SyncSchedulerTest {

    private val runs = mutableListOf<Long>()
    private val outcomes = ArrayDeque<SyncOutcome>()

    private fun TestScope.scheduler(random: Random = Random(1)): SyncScheduler {
        val scheduler = SyncScheduler(
            sync = {
                runs += currentTime
                outcomes.removeFirstOrNull() ?: SyncOutcome.Done
            },
            random = random,
        )
        backgroundScope.launch { scheduler.runWhileOpen() }
        runCurrent()
        return scheduler
    }

    @Test
    fun `syncs on start, then every 5 minutes`() = runTest {
        scheduler()

        advanceTimeBy(SyncCadence.PERIOD.toMillis() * 2 + 1)

        assertEquals(listOf(0L, PERIOD, PERIOD * 2), runs)
    }

    @Test
    fun `edits sync 2 seconds after the last one`() = runTest {
        val scheduler = scheduler()

        advanceTimeBy(10_000)
        scheduler.request(debounced = true)
        advanceTimeBy(1_500)
        scheduler.request(debounced = true)
        advanceTimeBy(1_999)
        assertEquals(listOf(0L), runs)
        advanceTimeBy(2)

        assertEquals(listOf(0L, 13_500L), runs)
    }

    @Test
    fun `an immediate request syncs at once`() = runTest {
        val scheduler = scheduler()

        advanceTimeBy(10_000)
        scheduler.request(debounced = false)
        runCurrent()

        assertEquals(listOf(0L, 10_000L), runs)
    }

    @Test
    fun `failures back off from 5 seconds, doubling to 5 minutes, with up to 20 percent jitter`() = runTest {
        repeat(9) { outcomes += SyncOutcome.Failed(null) }
        scheduler()

        advanceTimeBy(Duration.ofMinutes(30).toMillis())

        val waits = runs.zipWithNext { a, b -> b - a }
        val expected = listOf(5L, 10, 20, 40, 80, 160, 300, 300, 300).map { it * 1_000 }
        waits.take(expected.size).zip(expected).forEach { (wait, base) ->
            assertTrue(wait in (base * 0.8).toLong()..(base * 1.2).toLong(), "waited $wait for $base")
        }
        // After the last failure, the regular period again.
        assertEquals(PERIOD, waits[expected.size])
    }

    @Test
    fun `Retry-After decides the wait`() = runTest {
        outcomes += SyncOutcome.Failed(Duration.ofSeconds(42))
        scheduler()

        advanceTimeBy(42_001)

        assertEquals(listOf(0L, 42_000L), runs)
    }

    private companion object {
        val PERIOD = SyncCadence.PERIOD.toMillis()
    }
}
