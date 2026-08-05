package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.util.UUID
import java.util.Base64
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class NotificationIdentityTest {
    @Test
    fun sameSemanticKeyProducesByteIdenticalIdentityUriAndTagAfterRecreation() {
        val candidate = candidate(scope = "2026-07-24")

        val first = NotificationIdentity.from(candidate)
        val recreated = NotificationIdentity.from(candidate.copy())

        assertEquals(first.canonicalKey, recreated.canonicalKey)
        assertEquals(first.pendingIntentDataUri, recreated.pendingIntentDataUri)
        assertEquals(first.notificationTag, recreated.notificationTag)
        assertEquals(first.notificationId, recreated.notificationId)
        assertEquals(first.canonicalKey, NotificationIdentity.parse(first.canonicalKey)?.canonicalKey)
    }

    @Test
    fun independentlyReconstructedSemanticIdentitiesAreEqualAndHashEqual() {
        val first = NotificationIdentity.from(candidate(scope = "reconstructed"))
        val reconstructed = NotificationIdentity.parse(first.canonicalKey)!!

        assertEquals(first, reconstructed)
        assertEquals(first.hashCode(), reconstructed.hashCode())
        assertEquals(setOf(first), setOf(reconstructed))
    }

    @Test
    fun differentGoalScopeSlotAndKindProduceDifferentIdentity() {
        val base = NotificationIdentity.from(candidate())

        assertNotEquals(base.canonicalKey, NotificationIdentity.from(candidate(goalId = UUID.randomUUID())))
        assertNotEquals(base.canonicalKey, NotificationIdentity.from(candidate(scope = "different scope")))
        assertNotEquals(base.canonicalKey, NotificationIdentity.from(candidate(slotId = UUID.randomUUID())))
        assertNotEquals(
            base.canonicalKey,
            NotificationIdentity.from(candidate(kind = NudgeKind.STREAK_GUARDIAN)),
        )
    }

    @Test
    fun delimiterHeavyUnicodeScopesAreUnambiguousAndRoundTrip() {
        val first = NotificationIdentity.from(candidate(scope = "a|b/c:☪️\u0000مرحبا"))
        val second = NotificationIdentity.from(candidate(scope = "a|b/c:☪️\u0000مرحبا|"))

        assertNotEquals(first.canonicalKey, second.canonicalKey)
        assertEquals("a|b/c:☪️\u0000مرحبا", NotificationIdentity.parse(first.canonicalKey)?.obligationScope)
        assertEquals("a|b/c:☪️\u0000مرحبا|", NotificationIdentity.parse(second.canonicalKey)?.obligationScope)
    }

    @Test
    fun recreatingTheSemanticKeyDoesNotChangeStageIdentity() {
        val candidate = candidate()
        val identityAtFirstTrigger = NotificationIdentity.from(candidate)
        val identityAtRescheduledTrigger = NotificationIdentity.from(candidate.copy())

        assertEquals(identityAtFirstTrigger.canonicalKey, identityAtRescheduledTrigger.canonicalKey)
    }

    @Test
    fun notificationAddressDoesNotConflateEqualNumericHashWithDifferentTags() {
        val first = NotificationAddress(id = 17, tag = "awrad.notification.v1.first")
        val second = NotificationAddress(id = 17, tag = "awrad.notification.v1.second")

        assertNotEquals(first, second)
        assertEquals(first.id, second.id)
        assertNotEquals(first.tag, second.tag)
    }

    @Test
    fun malformedOrUnknownVersionKeysAreRejected() {
        assertEquals(null, NotificationIdentity.parse("awrad.notification/2/not-a-v1-payload"))
        assertEquals(null, NotificationIdentity.parse("awrad.notification/1/not base64"))
    }

    @Test
    fun paddedAndAlternateBase64SpellingsAreRejected() {
        val canonical = NotificationIdentity.from(candidate()).canonicalKey
        val prefix = "awrad.notification/1/"
        val payload = canonical.removePrefix(prefix)
        val paddedPayload = payload + "=".repeat((4 - payload.length % 4) % 4)
        val standardBase64Payload = Base64.getEncoder().encodeToString(
            Base64.getUrlDecoder().decode(payload),
        )

        assertNotEquals(payload, paddedPayload)
        assertEquals(null, NotificationIdentity.parse(prefix + paddedPayload))
        assertEquals(null, NotificationIdentity.parse(prefix + standardBase64Payload))
    }

    @Test
    fun uuidSpellingsCanonicalizeToOneStageIdentity() {
        val lower = "a0000000-0000-0000-0000-0000000000ab"
        val upper = lower.uppercase()
        val slotLower = "b0000000-0000-0000-0000-0000000000bc"
        val slotUpper = slotLower.uppercase()
        val lowerIdentity = NotificationIdentity.create(
            UUID.fromString(lower),
            "scope",
            UUID.fromString(slotLower),
            NudgeKind.DEADLINE_WARNING,
        )
        val upperKey = keyWithGoalText(lowerIdentity, upper)

        val parsedUpperIdentity = NotificationIdentity.parse(upperKey)
        assertEquals(lowerIdentity.canonicalKey, parsedUpperIdentity?.canonicalKey)
        assertEquals(UUID.fromString(lower), parsedUpperIdentity?.goalId)
        assertEquals(
            lowerIdentity.canonicalKey,
            NotificationIdentity.parse(keyWithSlotText(lowerIdentity, slotUpper))?.canonicalKey,
        )
    }

    @Test
    fun malformedUuidIsRejected() {
        val identity = NotificationIdentity.create(
            UUID.fromString("a0000000-0000-0000-0000-0000000000ab"),
            "scope",
            null,
            NudgeKind.DEADLINE_WARNING,
        )

        assertEquals(null, NotificationIdentity.parse(keyWithGoalText(identity, "x0000000-0000-0000-0000-0000000000ab")))
    }

    @Test
    fun shortenedGoalAndSlotUuidGroupsAreRejected() {
        val identity = NotificationIdentity.create(
            UUID.fromString("a0000000-0000-0000-0000-0000000000ab"),
            "scope",
            UUID.fromString("b0000000-0000-0000-0000-0000000000bc"),
            NudgeKind.DEADLINE_WARNING,
        )

        assertEquals(
            null,
            NotificationIdentity.parse(
                keyWithUuidTexts(
                    identity,
                    goalText = "a-0-0-0-ab",
                    slotText = identity.slotId.toString(),
                ),
            ),
        )
        assertEquals(
            null,
            NotificationIdentity.parse(
                keyWithUuidTexts(
                    identity,
                    goalText = identity.goalId.toString(),
                    slotText = "b-0-0-0-bc",
                ),
            ),
        )
    }

    private fun candidate(
        goalId: AwradId = UUID.fromString("00000000-0000-0000-0000-000000000001"),
        scope: String = "scope",
        slotId: AwradId? = UUID.fromString("00000000-0000-0000-0000-000000000002"),
        kind: NudgeKind = NudgeKind.DEADLINE_WARNING,
    ) = NudgeCandidateKey(
        goalId = goalId,
        obligationScope = scope,
        slotId = slotId,
        kind = kind,
    )

    private fun keyWithGoalText(identity: NotificationIdentity, goalText: String): String {
        val prefix = "awrad.notification/1/"
        val payload = identity.canonicalKey.removePrefix(prefix)
        val bytes = Base64.getUrlDecoder().decode(payload)
        val goalBytes = goalText.toByteArray(StandardCharsets.UTF_16BE)
        val buffer = ByteBuffer.wrap(bytes)
        buffer.get()
        val goalLength = buffer.int
        require(goalBytes.size == goalLength)
        goalBytes.copyInto(bytes, destinationOffset = buffer.position())
        return prefix + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }

    private fun keyWithSlotText(identity: NotificationIdentity, slotText: String): String {
        val prefix = "awrad.notification/1/"
        val bytes = Base64.getUrlDecoder().decode(identity.canonicalKey.removePrefix(prefix))
        val buffer = ByteBuffer.wrap(bytes)
        buffer.get()
        buffer.position(buffer.position() + 4 + buffer.int)
        buffer.position(buffer.position() + 4 + buffer.int)
        val slotLength = buffer.int
        val slotBytes = slotText.toByteArray(StandardCharsets.UTF_16BE)
        require(slotLength == slotBytes.size)
        slotBytes.copyInto(bytes, destinationOffset = buffer.position())
        return prefix + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }

    private fun keyWithUuidTexts(
        identity: NotificationIdentity,
        goalText: String,
        slotText: String?,
    ): String {
        val prefix = "awrad.notification/1/"
        val source = ByteBuffer.wrap(
            Base64.getUrlDecoder().decode(identity.canonicalKey.removePrefix(prefix)),
        )
        val version = source.get()
        source.readIntString(StandardCharsets.UTF_16BE)
        val scope = source.readIntString(StandardCharsets.UTF_16BE)
        source.readOptionalIntString(StandardCharsets.UTF_16BE)
        val kind = source.readIntString(StandardCharsets.UTF_8)
        val fields = listOf(
            goalText.toByteArray(StandardCharsets.UTF_16BE),
            scope.toByteArray(StandardCharsets.UTF_16BE),
            slotText?.toByteArray(StandardCharsets.UTF_16BE),
            kind.toByteArray(StandardCharsets.UTF_8),
        )
        val rebuilt = ByteBuffer.allocate(1 + fields.sumOf { 4 + (it?.size ?: 0) })
        rebuilt.put(version)
        fields.forEach { field ->
            rebuilt.putInt(field?.size ?: -1)
            field?.let(rebuilt::put)
        }
        return prefix + Base64.getUrlEncoder().withoutPadding().encodeToString(rebuilt.array())
    }

    private fun ByteBuffer.readIntString(charset: java.nio.charset.Charset): String {
        val length = int
        return ByteArray(length).also(::get).toString(charset)
    }

    private fun ByteBuffer.readOptionalIntString(charset: java.nio.charset.Charset): String? {
        val length = int
        return if (length == -1) null else ByteArray(length).also(::get).toString(charset)
    }
}
