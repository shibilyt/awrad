package app.awrad.awrad_dhikrgoalstracker.notification

import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Test

class UrgencyNudgePlatformRequestBuilderTest {
    @Test
    fun `broadcast intent preserves explicit envelope identity`() {
        val envelope = envelope("intent")

        val request = UrgencyNudgePlatformRequestBuilder.broadcastRequest(
            packageName = "app.awrad.test",
            identity = envelope.identity,
            triggerAtMillis = envelope.triggerAtMillis,
            expiresAtMillis = envelope.expiresAtMillis,
            kind = envelope.kind,
        )

        assertEquals(UrgencyNudgeEnvelopeContract.ACTION_URGENCY_NUDGE, request.action)
        assertEquals("app.awrad.test", request.packageName)
        assertEquals(UrgencyNudgeReceiver::class.java.name, request.receiverClassName)
        assertEquals(envelope.identity.pendingIntentDataUri, request.dataUri)
        assertEquals(
            envelope.identity.canonicalKey,
            request.canonicalIdentity,
        )
        assertEquals(envelope.triggerAtMillis, request.triggerAtMillis)
        assertEquals(envelope.expiresAtMillis, request.expiresAtMillis)
        assertEquals(envelope.kind, request.kind)
    }

    @Test
    fun `work request builder retains canonical input and unique identity`() {
        val envelope = envelope("work")
        val request = AdaptiveWorkRequest(
            envelope = envelope,
            uniqueWorkName = AdaptiveNudgeWorkIdentity.uniqueWorkName(envelope.identity),
            delayMillis = 321L,
        )

        val built = UrgencyNudgePlatformRequestBuilder.workRequest(request)

        assertEquals(request.uniqueWorkName, built.uniqueWorkName)
        assertEquals(request.delayMillis, built.delayMillis)
        assertEquals(AdaptiveNudgeWorkIdentity.workTag(envelope.identity), built.workTag)
        assertEquals(envelope.identity.canonicalKey, built.inputData.getString(
            UrgencyNudgeEnvelopeContract.EXTRA_CANONICAL_IDENTITY,
        ))
        assertEquals(envelope.triggerAtMillis, built.inputData.getLong(
            UrgencyNudgeEnvelopeContract.EXTRA_TRIGGER_AT_MILLIS,
            -1L,
        ))
        assertEquals(envelope.expiresAtMillis, built.inputData.getLong(
            UrgencyNudgeEnvelopeContract.EXTRA_EXPIRES_AT_MILLIS,
            -1L,
        ))
        assertEquals(envelope.kind.name, built.inputData.getString(UrgencyNudgeEnvelopeContract.EXTRA_KIND))
    }

    private fun envelope(scope: String): AdaptiveNudgeEnvelope = AdaptiveNudgeEnvelope(
        identity = NotificationIdentity.create(
            goalId = UUID.fromString("00000000-0000-0000-0000-000000000001"),
            obligationScope = scope,
            slotId = null,
            kind = NudgeKind.DEADLINE_WARNING,
        ),
        triggerAtMillis = 1234L,
        expiresAtMillis = 5678L,
    )
}
