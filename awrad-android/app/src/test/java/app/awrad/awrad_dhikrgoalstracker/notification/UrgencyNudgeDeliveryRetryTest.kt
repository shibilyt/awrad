package app.awrad.awrad_dhikrgoalstracker.notification

import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

class UrgencyNudgeDeliveryRetryTest {
    @Test
    fun `retry preserves envelope and is bounded by expiry`() {
        val envelope = AdaptiveNudgeEnvelope(
            NotificationIdentity.create(UUID.randomUUID(), "retry", null, NudgeKind.DEADLINE_WARNING),
            triggerAtMillis = 10L,
            expiresAtMillis = 100L,
        )

        val retry = UrgencyNudgeDeliveryRetry.plan(envelope, nowMillis = 20L)

        requireNotNull(retry)
        assertEquals(envelope, retry.envelope)
        assertEquals(5_000L, retry.initialDelayMillis)
        assertEquals(
            AdaptiveNudgeWorkIdentity.retryUniqueWorkName(envelope),
            retry.uniqueWorkName,
        )
        assertEquals(AdaptiveNudgeWorkIdentity.workTag(envelope.identity), retry.workTag)
        assertNull(UrgencyNudgeDeliveryRetry.plan(envelope, nowMillis = 100L))
    }

    @Test
    fun `retries for replacement envelopes cannot replace one another`() {
        val identity = NotificationIdentity.create(
            UUID.randomUUID(),
            "retry-replacement",
            null,
            NudgeKind.DEADLINE_WARNING,
        )
        val old = AdaptiveNudgeEnvelope(identity, triggerAtMillis = 10L, expiresAtMillis = 100L)
        val replacement = AdaptiveNudgeEnvelope(identity, triggerAtMillis = 20L, expiresAtMillis = 200L)

        assertNotEquals(
            UrgencyNudgeDeliveryRetry.plan(old, nowMillis = 30L)?.uniqueWorkName,
            UrgencyNudgeDeliveryRetry.plan(replacement, nowMillis = 30L)?.uniqueWorkName,
        )
    }
}
