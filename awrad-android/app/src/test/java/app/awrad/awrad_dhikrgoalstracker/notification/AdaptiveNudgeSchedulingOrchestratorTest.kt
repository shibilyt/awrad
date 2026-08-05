package app.awrad.awrad_dhikrgoalstracker.notification

import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AdaptiveNudgeSchedulingOrchestratorTest {
    @Test
    fun `exact available schedules exact only`() {
        val exact = FakeExactBackend(available = true)
        val work = FakeWorkBackend()

        val result = AdaptiveNudgeSchedulingOrchestrator(
            nowMillis = { 100L },
            exactBackend = exact,
            workBackend = work,
        ).schedule(envelope(triggerAtMillis = 200L))

        assertEquals(AdaptiveScheduleResult.Scheduled(AdaptiveBackend.EXACT), result)
        assertEquals(1, exact.scheduled.size)
        assertTrue(work.scheduled.isEmpty())
    }

    @Test
    fun `exact unavailable uses fallback only`() {
        val exact = FakeExactBackend(available = false)
        val work = FakeWorkBackend()

        val result = AdaptiveNudgeSchedulingOrchestrator(
            nowMillis = { 100L },
            exactBackend = exact,
            workBackend = work,
        ).schedule(envelope(triggerAtMillis = 250L))

        assertEquals(AdaptiveScheduleResult.Scheduled(AdaptiveBackend.WORK), result)
        assertTrue(exact.scheduled.isEmpty())
        assertEquals(listOf(150L), work.scheduled.map { it.delayMillis })
    }

    @Test
    fun `security exception from exact falls back but other exceptions propagate`() {
        val fallback = FakeWorkBackend()
        val securityExact = FakeExactBackend(available = true, failure = SecurityException("denied"))

        val fallbackResult = AdaptiveNudgeSchedulingOrchestrator(
            nowMillis = { 100L },
            exactBackend = securityExact,
            workBackend = fallback,
        ).schedule(envelope(triggerAtMillis = 200L))

        assertEquals(AdaptiveScheduleResult.Scheduled(AdaptiveBackend.WORK), fallbackResult)
        assertEquals(1, fallback.scheduled.size)

        val unexpected = IllegalStateException("platform failure")
        try {
            AdaptiveNudgeSchedulingOrchestrator(
                nowMillis = { 100L },
                exactBackend = FakeExactBackend(available = true, failure = unexpected),
                workBackend = FakeWorkBackend(),
            ).schedule(envelope(triggerAtMillis = 200L))
            throw AssertionError("Expected unexpected error to propagate")
        } catch (error: IllegalStateException) {
            assertEquals(unexpected, error)
        }
    }

    @Test
    fun `security exception from exact availability probe falls back to work`() {
        val work = FakeWorkBackend()

        val result = AdaptiveNudgeSchedulingOrchestrator(
            nowMillis = { 100L },
            exactBackend = FakeExactBackend(
                available = true,
                availabilityFailure = SecurityException("probe denied"),
            ),
            workBackend = work,
        ).schedule(envelope(triggerAtMillis = 200L))

        assertEquals(AdaptiveScheduleResult.Scheduled(AdaptiveBackend.WORK), result)
        assertEquals(listOf(100L), work.scheduled.map { it.delayMillis })
    }

    @Test
    fun `non security exception from exact availability probe propagates`() {
        val expected = IllegalStateException("probe failed")

        try {
            AdaptiveNudgeSchedulingOrchestrator(
                nowMillis = { 100L },
                exactBackend = FakeExactBackend(available = true, availabilityFailure = expected),
                workBackend = FakeWorkBackend(),
            ).schedule(envelope(triggerAtMillis = 200L))
            throw AssertionError("Expected probe failure to propagate")
        } catch (actual: IllegalStateException) {
            assertEquals(expected, actual)
        }
    }

    @Test
    fun `fallback delay saturates instead of overflowing`() {
        val work = FakeWorkBackend()

        AdaptiveNudgeSchedulingOrchestrator(
            nowMillis = { Long.MIN_VALUE },
            exactBackend = FakeExactBackend(available = false),
            workBackend = work,
        ).schedule(envelope(triggerAtMillis = Long.MAX_VALUE - 1))

        assertEquals(listOf(Long.MAX_VALUE), work.scheduled.map { it.delayMillis })
    }

    @Test
    fun `past and current triggers are stale without effects`() {
        val exact = FakeExactBackend(available = true)
        val work = FakeWorkBackend()
        val subject = AdaptiveNudgeSchedulingOrchestrator({ 100L }, exact, work)

        assertEquals(AdaptiveScheduleResult.Stale, subject.schedule(envelope(triggerAtMillis = 100L)))
        assertEquals(AdaptiveScheduleResult.Stale, subject.schedule(envelope(triggerAtMillis = 99L)))
        assertTrue(exact.scheduled.isEmpty())
        assertTrue(work.scheduled.isEmpty())
    }

    @Test
    fun `work names are stable and identities are collision resistant`() {
        val first = envelope(scope = "first")
        val second = envelope(scope = "second")

        assertTrue(first.identity.pendingIntentDataUri != second.identity.pendingIntentDataUri)
        assertTrue(AdaptiveNudgeWorkIdentity.uniqueWorkName(first.identity) !=
            AdaptiveNudgeWorkIdentity.uniqueWorkName(second.identity))
        assertTrue(first.identity.notificationAddress != second.identity.notificationAddress)
    }

    @Test
    fun `cancellation invokes both exact and work backends`() {
        val exact = FakeExactBackend(available = true)
        val work = FakeWorkBackend()
        val identity = envelope().identity

        AdaptiveNudgeSchedulingOrchestrator({ 100L }, exact, work).cancel(identity)

        assertEquals(listOf(identity), exact.cancelled)
        assertEquals(listOf(identity), work.cancelled)
    }

    @Test
    fun `cancellation still cancels work when exact cancellation fails`() {
        val exact = FakeExactBackend(
            available = true,
            cancelFailure = IllegalStateException("exact cancel failed"),
        )
        val work = FakeWorkBackend()
        val identity = envelope().identity

        try {
            AdaptiveNudgeSchedulingOrchestrator({ 100L }, exact, work).cancel(identity)
            throw AssertionError("Expected exact cancellation failure")
        } catch (_: IllegalStateException) {
            assertEquals(listOf(identity), work.cancelled)
        }
    }

    @Test
    fun `same identity keeps platform addresses when trigger changes`() {
        val first = envelope(triggerAtMillis = 200L)
        val changed = first.copy(triggerAtMillis = 300L)

        assertEquals(first.identity.pendingIntentDataUri, changed.identity.pendingIntentDataUri)
        assertEquals(
            AdaptiveNudgeWorkIdentity.uniqueWorkName(first.identity),
            AdaptiveNudgeWorkIdentity.uniqueWorkName(changed.identity),
        )
    }

    private fun envelope(
        scope: String = "scope",
        triggerAtMillis: Long = 200L,
    ): AdaptiveNudgeEnvelope = AdaptiveNudgeEnvelope(
        identity = NotificationIdentity.create(
            goalId = UUID.fromString("00000000-0000-0000-0000-000000000001"),
            obligationScope = scope,
            slotId = null,
            kind = NudgeKind.DEADLINE_WARNING,
        ),
        triggerAtMillis = triggerAtMillis,
        expiresAtMillis = if (triggerAtMillis <= Long.MAX_VALUE - 1_000L) {
            triggerAtMillis + 1_000L
        } else {
            Long.MAX_VALUE
        },
        kind = NudgeKind.DEADLINE_WARNING,
    )

    private class FakeExactBackend(
        private val available: Boolean,
        private val failure: Throwable? = null,
        private val availabilityFailure: Throwable? = null,
        private val cancelFailure: Throwable? = null,
    ) : AdaptiveExactAlarmBackend {
        val scheduled = mutableListOf<AdaptiveNudgeEnvelope>()
        val cancelled = mutableListOf<NotificationIdentity>()

        override fun isExactSchedulingAvailable(): Boolean {
            availabilityFailure?.let { throw it }
            return available
        }

        override fun schedule(envelope: AdaptiveNudgeEnvelope) {
            failure?.let { throw it }
            scheduled += envelope
        }

        override fun cancel(identity: NotificationIdentity) {
            cancelled += identity
            cancelFailure?.let { throw it }
        }
    }

    private class FakeWorkBackend : AdaptiveWorkBackend {
        val scheduled = mutableListOf<AdaptiveWorkRequest>()
        val cancelled = mutableListOf<NotificationIdentity>()

        override fun enqueue(request: AdaptiveWorkRequest) {
            scheduled += request
        }

        override fun cancel(identity: NotificationIdentity) {
            cancelled += identity
        }
    }
}
