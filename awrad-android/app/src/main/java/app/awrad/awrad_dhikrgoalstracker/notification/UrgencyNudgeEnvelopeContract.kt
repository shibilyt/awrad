package app.awrad.awrad_dhikrgoalstracker.notification

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.work.Data
import java.nio.charset.StandardCharsets

/**
 * Single serializer for platform handoff fields. The receiver is deliberately separate from
 * configured reminders so this slice cannot enter their AlarmClock/follow-up delivery path.
 */
object UrgencyNudgeEnvelopeContract {
    const val ACTION_URGENCY_NUDGE = "app.awrad.awrad_dhikrgoalstracker.action.URGENCY_NUDGE"
    const val EXTRA_CANONICAL_IDENTITY = "urgency_canonical_identity"
    const val EXTRA_TRIGGER_AT_MILLIS = "urgency_trigger_at_millis"
    const val EXTRA_EXPIRES_AT_MILLIS = "urgency_expires_at_millis"
    const val EXTRA_KIND = "urgency_kind"

    fun intent(
        context: Context,
        identity: NotificationIdentity,
        triggerAtMillis: Long?,
        expiresAtMillis: Long?,
        kind: NudgeKind?,
    ): Intent = Intent(ACTION_URGENCY_NUDGE).apply {
        component = ComponentName(context, UrgencyNudgeReceiver::class.java)
        data = Uri.parse(identity.pendingIntentDataUri)
        putExtra(EXTRA_CANONICAL_IDENTITY, identity.canonicalKey)
        triggerAtMillis?.let { putExtra(EXTRA_TRIGGER_AT_MILLIS, it) }
        expiresAtMillis?.let { putExtra(EXTRA_EXPIRES_AT_MILLIS, it) }
        kind?.let { putExtra(EXTRA_KIND, it.name) }
    }
}

data class UrgencyNudgeWorkInput(
    val canonicalIdentity: String,
    val triggerAtMillis: Long,
    val expiresAtMillis: Long,
    val kind: NudgeKind,
) {
    fun toData(): Data {
        // These are the only four fields; reserve framing space so the bounded Data payload cannot
        // approach WorkManager's 10 KB serialized limit even with the longest valid identity.
        val payloadBytes = canonicalIdentity.toByteArray(StandardCharsets.UTF_8).size +
            kind.name.toByteArray(StandardCharsets.UTF_8).size + 128
        require(payloadBytes <= Data.MAX_DATA_BYTES) { "Urgency work input exceeds Data limit" }
        return Data.Builder()
            .putString(UrgencyNudgeEnvelopeContract.EXTRA_CANONICAL_IDENTITY, canonicalIdentity)
            .putLong(UrgencyNudgeEnvelopeContract.EXTRA_TRIGGER_AT_MILLIS, triggerAtMillis)
            .putLong(UrgencyNudgeEnvelopeContract.EXTRA_EXPIRES_AT_MILLIS, expiresAtMillis)
            .putString(UrgencyNudgeEnvelopeContract.EXTRA_KIND, kind.name)
            .build()
    }

    fun toEnvelope(): AdaptiveNudgeEnvelope? {
        val identity = NotificationIdentity.parse(canonicalIdentity) ?: return null
        if (identity.kind != kind || triggerAtMillis >= expiresAtMillis) return null
        return AdaptiveNudgeEnvelope(identity, triggerAtMillis, expiresAtMillis, kind)
    }

    companion object {
        fun from(envelope: AdaptiveNudgeEnvelope): UrgencyNudgeWorkInput = UrgencyNudgeWorkInput(
            canonicalIdentity = envelope.identity.canonicalKey,
            triggerAtMillis = envelope.triggerAtMillis,
            expiresAtMillis = envelope.expiresAtMillis,
            kind = envelope.kind,
        )

        fun from(data: Data): UrgencyNudgeWorkInput? {
            val canonicalIdentity = data.getString(UrgencyNudgeEnvelopeContract.EXTRA_CANONICAL_IDENTITY)
                ?: return null
            val triggerAtMillis = data.getLong(UrgencyNudgeEnvelopeContract.EXTRA_TRIGGER_AT_MILLIS, Long.MIN_VALUE)
            val expiresAtMillis = data.getLong(UrgencyNudgeEnvelopeContract.EXTRA_EXPIRES_AT_MILLIS, Long.MIN_VALUE)
            val kind = data.getString(UrgencyNudgeEnvelopeContract.EXTRA_KIND)
                ?.let { value -> NudgeKind.entries.firstOrNull { it.name == value } }
                ?: return null
            return UrgencyNudgeWorkInput(canonicalIdentity, triggerAtMillis, expiresAtMillis, kind)
                .takeIf { it.toEnvelope() != null }
        }
    }
}

