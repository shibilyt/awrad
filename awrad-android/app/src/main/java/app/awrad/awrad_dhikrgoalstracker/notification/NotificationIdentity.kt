package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.Base64
import java.util.UUID

/**
 * Stable semantic identity for one notification stage.
 *
 * The key excludes trigger time deliberately: replanning the same obligation stage at a different
 * time updates its manifest record instead of creating a stage that can be delivered twice.
 * [notificationId] is only a deterministic convenience hash. Android callers must always pair it
 * with [notificationTag], because the tag is the collision-resistant notification address.
 */
class NotificationIdentity private constructor(
    val goalId: AwradId,
    val obligationScope: String,
    val slotId: AwradId?,
    val kind: NudgeKind,
    private val payload: String,
) {
    val canonicalKey: String = "$KEY_PREFIX/$FORMAT_VERSION/$payload"
    val pendingIntentDataUri: String = "$URI_PREFIX/$FORMAT_VERSION/$payload"
    val notificationTag: String = "$TAG_PREFIX.$FORMAT_VERSION.$payload"
    val notificationId: Int = ByteBuffer.wrap(
        MessageDigest.getInstance("SHA-256").digest(canonicalKey.toByteArray(StandardCharsets.UTF_8)),
    ).int and Int.MAX_VALUE
    val notificationAddress: NotificationAddress = NotificationAddress(notificationId, notificationTag)

    override fun equals(other: Any?): Boolean =
        other is NotificationIdentity && canonicalKey == other.canonicalKey

    override fun hashCode(): Int = canonicalKey.hashCode()

    companion object {
        const val FORMAT_VERSION = 1
        private const val KEY_PREFIX = "awrad.notification"
        private const val URI_PREFIX = "awrad-notification://candidate"
        private const val TAG_PREFIX = "awrad.notification"

        fun from(key: NudgeCandidateKey): NotificationIdentity = create(
            goalId = key.goalId,
            obligationScope = key.obligationScope,
            slotId = key.slotId,
            kind = key.kind,
        )

        fun create(
            goalId: AwradId,
            obligationScope: String,
            slotId: AwradId?,
            kind: NudgeKind,
        ): NotificationIdentity = NotificationIdentity(
                goalId = goalId,
                obligationScope = obligationScope,
                slotId = slotId,
                kind = kind,
                payload = encode(goalId.toString(), obligationScope, slotId?.toString(), kind),
            )

        /**
         * Parses only this format version and fully validates the opaque payload. Unknown or
         * malformed persisted keys are rejected by returning null rather than treated as scheduled.
         */
        fun parse(canonicalKey: String): NotificationIdentity? {
            val prefix = "$KEY_PREFIX/$FORMAT_VERSION/"
            if (!canonicalKey.startsWith(prefix)) return null
            val payload = canonicalKey.removePrefix(prefix)
            val decoded = decode(payload) ?: return null
            return create(
                goalId = decoded.goalId,
                obligationScope = decoded.obligationScope,
                slotId = decoded.slotId,
                kind = decoded.kind,
            )
        }

        private fun encode(
            goalId: String,
            obligationScope: String,
            slotId: String?,
            kind: NudgeKind,
        ): String {
            val fields = listOf(
                goalId.toByteArray(StandardCharsets.UTF_16BE),
                obligationScope.toByteArray(StandardCharsets.UTF_16BE),
                slotId?.toByteArray(StandardCharsets.UTF_16BE),
                kind.name.toByteArray(StandardCharsets.UTF_8),
            )
            val size = 1 + fields.sumOf { 4 + (it?.size ?: 0) }
            val buffer = ByteBuffer.allocate(size)
            buffer.put(FORMAT_VERSION.toByte())
            fields.forEach { field ->
                buffer.putInt(field?.size ?: -1)
                field?.let(buffer::put)
            }
            return Base64.getUrlEncoder().withoutPadding().encodeToString(buffer.array())
        }

        private fun decode(payload: String): DecodedIdentity? = runCatching {
            val bytes = Base64.getUrlDecoder().decode(payload)
            if (Base64.getUrlEncoder().withoutPadding().encodeToString(bytes) != payload) return null
            val buffer = ByteBuffer.wrap(bytes)
            if (buffer.get().toInt() != FORMAT_VERSION) return null
            val goalId = buffer.readRequiredString(StandardCharsets.UTF_16BE)
                ?.let(::parseUuid)
                ?: return null
            val scope = buffer.readRequiredString(StandardCharsets.UTF_16BE) ?: return null
            val slotValue = buffer.readOptionalString(StandardCharsets.UTF_16BE)
            val slotId = slotValue?.let(::parseUuid)
            if (slotValue != null && slotId == null) return null
            val kindName = buffer.readRequiredString(StandardCharsets.UTF_8) ?: return null
            if (buffer.hasRemaining()) return null
            val kind = NudgeKind.entries.firstOrNull { it.name == kindName } ?: return null
            DecodedIdentity(goalId, scope, slotId, kind)
        }.getOrNull()

        private fun parseUuid(value: String): UUID? {
            if (!CANONICAL_UUID.matches(value)) return null
            return runCatching { UUID.fromString(value) }.getOrNull()
        }

        private fun ByteBuffer.readRequiredString(charset: java.nio.charset.Charset): String? {
            val length = int
            if (length < 0 || length > remaining() || (charset == StandardCharsets.UTF_16BE && length % 2 != 0)) {
                return null
            }
            return ByteArray(length).also(::get).toString(charset)
        }

        private fun ByteBuffer.readOptionalString(charset: java.nio.charset.Charset): String? {
            val length = int
            if (length == -1) return null
            if (length < 0 || length > remaining() || (charset == StandardCharsets.UTF_16BE && length % 2 != 0)) {
                throw IllegalArgumentException("Invalid optional string length")
            }
            return ByteArray(length).also(::get).toString(charset)
        }

        private val CANONICAL_UUID = Regex(
            """[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}""",
        )
    }
}

/** A notification address remains unique when a 32-bit [id] hash collides because [tag] is included. */
data class NotificationAddress(
    val id: Int,
    val tag: String,
)

private data class DecodedIdentity(
    val goalId: AwradId,
    val obligationScope: String,
    val slotId: AwradId?,
    val kind: NudgeKind,
)
