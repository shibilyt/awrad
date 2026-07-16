package app.awrad.awrad_dhikrgoalstracker.data.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ForegroundProgressSyncPolicyTest {
    @Test
    fun `counter polling is ten seconds before jitter`() {
        assertEquals(
            10_000L,
            ForegroundProgressSyncPolicy.intervalMillis(countingActive = true, randomUnit = 0.5),
        )
    }

    @Test
    fun `normal foreground polling is sixty seconds before jitter`() {
        assertEquals(
            60_000L,
            ForegroundProgressSyncPolicy.intervalMillis(countingActive = false, randomUnit = 0.5),
        )
    }

    @Test
    fun `jitter remains within twenty percent`() {
        val counterMinimum = ForegroundProgressSyncPolicy.intervalMillis(true, 0.0)
        val counterMaximum = ForegroundProgressSyncPolicy.intervalMillis(true, 1.0)
        assertEquals(8_000L, counterMinimum)
        assertEquals(12_000L, counterMaximum)
    }

    @Test
    fun `retry backoff grows and caps at five minutes`() {
        assertEquals(0L, ForegroundProgressSyncPolicy.backoffMillis(0))
        assertEquals(5_000L, ForegroundProgressSyncPolicy.backoffMillis(1))
        assertEquals(10_000L, ForegroundProgressSyncPolicy.backoffMillis(2))
        assertTrue(ForegroundProgressSyncPolicy.backoffMillis(20) <= 300_000L)
        assertEquals(300_000L, ForegroundProgressSyncPolicy.backoffMillis(20))
    }
}
