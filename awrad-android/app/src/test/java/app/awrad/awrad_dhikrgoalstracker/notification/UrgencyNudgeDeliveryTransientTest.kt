package app.awrad.awrad_dhikrgoalstracker.notification

import android.database.sqlite.SQLiteConstraintException
import android.database.sqlite.SQLiteDatabaseCorruptException
import android.database.sqlite.SQLiteDatabaseLockedException
import android.database.sqlite.SQLiteException
import androidx.work.ListenableWorker
import java.io.IOException
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class UrgencyNudgeDeliveryTransientTest {
    @Test
    fun `locked sqlite failures are known transient`() {
        assertTrue(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                SQLiteDatabaseLockedException("database is locked"),
            ),
        )
        assertTrue(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                SQLiteDatabaseLockedException("database is busy"),
            ),
        )
        assertTrue(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                RuntimeException("wrapped", SQLiteDatabaseLockedException("locked")),
            ),
        )
    }

    @Test
    fun `io failures are known transient`() {
        assertTrue(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(IOException("disk full")),
        )
        assertTrue(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                RuntimeException("wrapped", IOException("disk full")),
            ),
        )
    }

    @Test
    fun `cancellation anywhere in cause chain is not known transient`() {
        // Cancellation above a retryable cause.
        assertFalse(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                CancellationException("cancelled", IOException("disk full")),
            ),
        )
        assertFalse(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                CancellationException(
                    "cancelled",
                    SQLiteDatabaseLockedException("database is locked"),
                ),
            ),
        )
        // Cancellation below a retryable cause.
        assertFalse(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                IOException("disk full", CancellationException("cancelled")),
            ),
        )
        assertFalse(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                SQLiteDatabaseLockedException("database is locked").also {
                    it.initCause(CancellationException("cancelled"))
                },
            ),
        )
        // Cancellation between wrappers and a deeper retryable cause.
        assertFalse(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                RuntimeException(
                    "outer",
                    CancellationException("cancelled", IOException("disk full")),
                ),
            ),
        )
    }

    @Test
    fun `cyclic cause chains classify without hanging`() {
        val io = IOException("disk full")
        val wrapper = RuntimeException("wrapper")
        wrapper.initCause(io)
        io.initCause(wrapper)
        assertTrue(UrgencyNudgeKnownTransientClassifier.isKnownTransient(wrapper))

        val locked = SQLiteDatabaseLockedException("database is locked")
        val cancelled = CancellationException("cancelled")
        val outer = RuntimeException("outer")
        outer.initCause(locked)
        locked.initCause(cancelled)
        cancelled.initCause(outer)
        assertFalse(UrgencyNudgeKnownTransientClassifier.isKnownTransient(outer))
    }

    @Test
    fun `plain and fatal sqlite failures are not known transient`() {
        assertFalse(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                SQLiteException("no such table: goals"),
            ),
        )
        assertFalse(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                SQLiteConstraintException("UNIQUE constraint failed"),
            ),
        )
        assertFalse(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                SQLiteDatabaseCorruptException("database disk image is malformed"),
            ),
        )
        // Name-alike subclasses must not be treated as transient without an explicit type match.
        assertFalse(
            UrgencyNudgeKnownTransientClassifier.isKnownTransient(
                object : SQLiteException("database is busy") {},
            ),
        )
    }

    @Test
    fun `locked sqlite before expiry maps to retry without cleanup`() = runBlocking {
        val cleaned = AtomicBoolean(false)
        val outcome = UrgencyNudgeDeliveryFailureMapper.mapKnownTransient(
            error = SQLiteDatabaseLockedException("database is locked"),
            envelope = envelope(expiresAtMillis = 100L),
            nowMillis = 50L,
            onExpiredCleanup = { cleaned.set(true) },
        )

        assertEquals(UrgencyNudgeDeliveryOutcome.Retry, outcome)
        assertFalse(cleaned.get())
    }

    @Test
    fun `locked sqlite at and after expiry maps to expired cleanup`() = runBlocking {
        for (nowMillis in listOf(100L, 101L)) {
            val cleaned = AtomicBoolean(false)
            val outcome = UrgencyNudgeDeliveryFailureMapper.mapKnownTransient(
                error = SQLiteDatabaseLockedException("database is locked"),
                envelope = envelope(expiresAtMillis = 100L),
                nowMillis = nowMillis,
                onExpiredCleanup = { cleaned.set(true) },
            )

            assertEquals(
                UrgencyNudgeDeliveryOutcome.Rejected(UrgencyNudgeRejectionReason.EXPIRED),
                outcome,
            )
            assertTrue("cleanup expected at now=$nowMillis", cleaned.get())
        }
    }

    @Test
    fun `fatal sqlite exception propagates without retry or cleanup`() = runBlocking {
        val cleaned = AtomicBoolean(false)
        val fatal = SQLiteConstraintException("UNIQUE constraint failed")
        try {
            UrgencyNudgeDeliveryFailureMapper.mapKnownTransient(
                error = fatal,
                envelope = envelope(expiresAtMillis = 100L),
                nowMillis = 50L,
                onExpiredCleanup = { cleaned.set(true) },
            )
            fail("expected fatal SQLiteConstraintException to propagate")
        } catch (thrown: SQLiteConstraintException) {
            assertSame(fatal, thrown)
        }
        assertFalse(cleaned.get())
    }

    @Test
    fun `plain sqlite exception propagates without retry or cleanup`() = runBlocking {
        val cleaned = AtomicBoolean(false)
        val plain = SQLiteException("no such table: goals")
        try {
            UrgencyNudgeDeliveryFailureMapper.mapKnownTransient(
                error = plain,
                envelope = envelope(expiresAtMillis = 100L),
                nowMillis = 50L,
                onExpiredCleanup = { cleaned.set(true) },
            )
            fail("expected plain SQLiteException to propagate")
        } catch (thrown: SQLiteException) {
            assertSame(plain, thrown)
        }
        assertFalse(cleaned.get())
    }

    @Test
    fun `cancellation exception propagates without retry or cleanup`() = runBlocking {
        val cleaned = AtomicBoolean(false)
        val cancelled = CancellationException("cancelled")
        try {
            UrgencyNudgeDeliveryFailureMapper.mapKnownTransient(
                error = cancelled,
                envelope = envelope(expiresAtMillis = 100L),
                nowMillis = 50L,
                onExpiredCleanup = { cleaned.set(true) },
            )
            fail("expected CancellationException to propagate")
        } catch (thrown: CancellationException) {
            assertSame(cancelled, thrown)
        }
        assertFalse(cleaned.get())
    }

    @Test
    fun `wrapped cancellation with retryable cause propagates without retry or cleanup`() =
        runBlocking {
            val cleaned = AtomicBoolean(false)
            // Cancellation above IO — must not retry.
            val cancelledAbove = CancellationException("cancelled", IOException("disk full"))
            try {
                UrgencyNudgeDeliveryFailureMapper.mapKnownTransient(
                    error = cancelledAbove,
                    envelope = envelope(expiresAtMillis = 100L),
                    nowMillis = 50L,
                    onExpiredCleanup = { cleaned.set(true) },
                )
                fail("expected CancellationException above IO to propagate")
            } catch (thrown: CancellationException) {
                assertSame(cancelledAbove, thrown)
            }
            assertFalse(cleaned.get())

            // Cancellation below locked — must not retry; outer error propagates.
            val cancelledBelow =
                IOException("disk full", CancellationException("cancelled"))
            try {
                UrgencyNudgeDeliveryFailureMapper.mapKnownTransient(
                    error = cancelledBelow,
                    envelope = envelope(expiresAtMillis = 100L),
                    nowMillis = 50L,
                    onExpiredCleanup = { cleaned.set(true) },
                )
                fail("expected IO wrapping CancellationException to propagate")
            } catch (thrown: IOException) {
                assertSame(cancelledBelow, thrown)
            }
            assertFalse(cleaned.get())
        }

    @Test
    fun `io before expiry maps to retry without cleanup`() = runBlocking {
        val cleaned = AtomicBoolean(false)
        val outcome = UrgencyNudgeDeliveryFailureMapper.mapKnownTransient(
            error = IOException("disk full"),
            envelope = envelope(expiresAtMillis = 100L),
            nowMillis = 50L,
            onExpiredCleanup = { cleaned.set(true) },
        )

        assertEquals(UrgencyNudgeDeliveryOutcome.Retry, outcome)
        assertFalse(cleaned.get())
    }

    @Test
    fun `receiver runner enqueues retry only for retry outcome before expiry`() = runBlocking {
        val envelope = envelope(expiresAtMillis = 100L)
        val enqueued = AtomicReference<AdaptiveNudgeEnvelope?>(null)
        val cleaned = AtomicBoolean(false)

        UrgencyNudgeReceiverDeliveryRunner.run(
            envelope = envelope,
            process = { UrgencyNudgeDeliveryOutcome.Retry },
            nowMillis = { 50L },
            onExpiredCleanup = { cleaned.set(true) },
            enqueueRetry = { enqueued.set(it) },
        )
        assertSame(envelope, enqueued.get())
        assertFalse(cleaned.get())

        enqueued.set(null)
        UrgencyNudgeReceiverDeliveryRunner.run(
            envelope = envelope,
            process = { UrgencyNudgeDeliveryOutcome.Posted },
            nowMillis = { 50L },
            onExpiredCleanup = { cleaned.set(true) },
            enqueueRetry = { enqueued.set(it) },
        )
        assertNull(enqueued.get())
        assertFalse(cleaned.get())
    }

    @Test
    fun `receiver settles processor retry when clock reaches expiry`() = runBlocking {
        for (settlementNow in listOf(100L, 101L)) {
            val envelope = envelope(expiresAtMillis = 100L)
            val cleaned = AtomicBoolean(false)
            val enqueued = AtomicReference<AdaptiveNudgeEnvelope?>(null)

            UrgencyNudgeReceiverDeliveryRunner.run(
                envelope = envelope,
                // Processor observed a pre-expiry retryable failure.
                process = { UrgencyNudgeDeliveryOutcome.Retry },
                nowMillis = { settlementNow },
                onExpiredCleanup = { cleaned.set(true) },
                enqueueRetry = { enqueued.set(it) },
            )

            assertTrue("EXPIRED cleanup expected at settlementNow=$settlementNow", cleaned.get())
            assertNull("must not enqueue retry after expiry", enqueued.get())
        }
    }

    @Test
    fun `receiver settlement cleanup failure propagates without enqueue`() = runBlocking {
        val envelope = envelope(expiresAtMillis = 100L)
        val boom = SQLiteDatabaseLockedException("locked during expired cleanup")
        val enqueued = AtomicBoolean(false)
        try {
            UrgencyNudgeReceiverDeliveryRunner.run(
                envelope = envelope,
                process = { UrgencyNudgeDeliveryOutcome.Retry },
                nowMillis = { 100L },
                onExpiredCleanup = { throw boom },
                enqueueRetry = { enqueued.set(true) },
            )
            fail("expected cleanup failure to propagate")
        } catch (thrown: SQLiteDatabaseLockedException) {
            assertSame(boom, thrown)
        }
        assertFalse(enqueued.get())
    }

    @Test
    fun `worker outcome mapper maps retry before expiry to Result retry`() = runBlocking {
        val envelope = envelope(expiresAtMillis = 100L)
        val cleaned = AtomicBoolean(false)

        assertEquals(
            ListenableWorker.Result.retry(),
            UrgencyNudgeWorkerOutcomeMapper.toWorkerResult(
                outcome = UrgencyNudgeDeliveryOutcome.Retry,
                envelope = envelope,
                nowMillis = 50L,
                onExpiredCleanup = { cleaned.set(true) },
            ),
        )
        assertFalse(cleaned.get())
        assertEquals(
            ListenableWorker.Result.success(),
            UrgencyNudgeWorkerOutcomeMapper.toWorkerResult(
                outcome = UrgencyNudgeDeliveryOutcome.Posted,
                envelope = envelope,
                nowMillis = 50L,
                onExpiredCleanup = { cleaned.set(true) },
            ),
        )
        assertFalse(cleaned.get())
    }

    @Test
    fun `worker settles processor retry when clock reaches expiry`() = runBlocking {
        for (settlementNow in listOf(100L, 101L)) {
            val envelope = envelope(expiresAtMillis = 100L)
            val cleaned = AtomicBoolean(false)

            val result = UrgencyNudgeWorkerOutcomeMapper.toWorkerResult(
                outcome = UrgencyNudgeDeliveryOutcome.Retry,
                envelope = envelope,
                nowMillis = settlementNow,
                onExpiredCleanup = { cleaned.set(true) },
            )

            assertTrue("EXPIRED cleanup expected at settlementNow=$settlementNow", cleaned.get())
            assertEquals(ListenableWorker.Result.success(), result)
            assertFalse(result is ListenableWorker.Result.Retry)
        }
    }

    @Test
    fun `worker settlement cleanup failure propagates without Result retry`() = runBlocking {
        val envelope = envelope(expiresAtMillis = 100L)
        val boom = SQLiteException("store write failed during expired cleanup")
        try {
            UrgencyNudgeWorkerOutcomeMapper.toWorkerResult(
                outcome = UrgencyNudgeDeliveryOutcome.Retry,
                envelope = envelope,
                nowMillis = 100L,
                onExpiredCleanup = { throw boom },
            )
            fail("expected cleanup failure to propagate")
        } catch (thrown: SQLiteException) {
            assertSame(boom, thrown)
        }
    }

    private fun envelope(expiresAtMillis: Long): AdaptiveNudgeEnvelope =
        AdaptiveNudgeEnvelope(
            NotificationIdentity.create(
                UUID.randomUUID(),
                "transient",
                null,
                NudgeKind.DEADLINE_WARNING,
            ),
            triggerAtMillis = 10L,
            expiresAtMillis = expiresAtMillis,
        )
}
