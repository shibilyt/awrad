package app.awrad.awrad_dhikrgoalstracker.notification

import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class BootRescheduleActionRunnerTest {

    @Test
    fun `wird failure still runs urgency success without retry`() = runBlocking {
        val urgencyRan = AtomicBoolean(false)
        val retryEnqueued = AtomicBoolean(false)
        val finishCount = AtomicInteger(0)

        BootRescheduleActionRunner.run(
            rescheduleWird = { throw IllegalStateException("wird boom") },
            reconcileUrgency = {
                urgencyRan.set(true)
                NotificationObligationEngineResult.Reconciled
            },
            enqueueUrgencyRetry = { retryEnqueued.set(true) },
            onWirdFailure = { },
            onUrgencyUnexpectedFailure = { fail("urgency should not throw") },
            finish = { finishCount.incrementAndGet() },
        )

        assertTrue(urgencyRan.get())
        assertFalse(retryEnqueued.get())
        assertEquals(1, finishCount.get())
    }

    @Test
    fun `wird failure still runs urgency transient and enqueues retry`() = runBlocking {
        val urgencyRan = AtomicBoolean(false)
        val retryEnqueued = AtomicBoolean(false)
        val finishCount = AtomicInteger(0)

        BootRescheduleActionRunner.run(
            rescheduleWird = { throw IllegalStateException("wird boom") },
            reconcileUrgency = {
                urgencyRan.set(true)
                NotificationObligationEngineResult.TransientFailure(IOException("transient"))
            },
            enqueueUrgencyRetry = { retryEnqueued.set(true) },
            onWirdFailure = { },
            onUrgencyUnexpectedFailure = { fail("urgency should not throw") },
            finish = { finishCount.incrementAndGet() },
        )

        assertTrue(urgencyRan.get())
        assertTrue(retryEnqueued.get())
        assertEquals(1, finishCount.get())
    }

    @Test
    fun `urgency fatal does not enqueue retry`() = runBlocking {
        val retryEnqueued = AtomicBoolean(false)
        val finishCount = AtomicInteger(0)

        BootRescheduleActionRunner.run(
            rescheduleWird = { },
            reconcileUrgency = {
                NotificationObligationEngineResult.FatalFailure(IllegalStateException("fatal"))
            },
            enqueueUrgencyRetry = { retryEnqueued.set(true) },
            onWirdFailure = { fail("wird should not fail") },
            onUrgencyUnexpectedFailure = { fail("urgency should not throw") },
            finish = { finishCount.incrementAndGet() },
        )

        assertFalse(retryEnqueued.get())
        assertEquals(1, finishCount.get())
    }

    @Test
    fun `finish runs once when urgency throws unexpectedly`() = runBlocking {
        val finishCount = AtomicInteger(0)
        val urgencyFailureLogged = AtomicBoolean(false)

        BootRescheduleActionRunner.run(
            rescheduleWird = { },
            reconcileUrgency = { throw IllegalStateException("urgency boom") },
            enqueueUrgencyRetry = { fail("must not retry on unexpected throw") },
            onWirdFailure = { fail("wird should not fail") },
            onUrgencyUnexpectedFailure = { urgencyFailureLogged.set(true) },
            finish = { finishCount.incrementAndGet() },
        )

        assertTrue(urgencyFailureLogged.get())
        assertEquals(1, finishCount.get())
    }

    @Test
    fun `cancellation propagates but finish still runs once`() = runBlocking {
        val finishCount = AtomicInteger(0)
        val cancelled = CancellationException("cancelled")

        try {
            BootRescheduleActionRunner.run(
                rescheduleWird = { throw cancelled },
                reconcileUrgency = {
                    fail("urgency must not run after cancellation")
                    NotificationObligationEngineResult.Reconciled
                },
                enqueueUrgencyRetry = { fail("must not retry after cancellation") },
                onWirdFailure = { fail("cancellation is not a wird failure") },
                onUrgencyUnexpectedFailure = { fail("urgency must not run") },
                finish = { finishCount.incrementAndGet() },
            )
            fail("expected CancellationException to propagate")
        } catch (thrown: CancellationException) {
            assertEquals(cancelled, thrown)
        }

        assertEquals(1, finishCount.get())
    }
}
