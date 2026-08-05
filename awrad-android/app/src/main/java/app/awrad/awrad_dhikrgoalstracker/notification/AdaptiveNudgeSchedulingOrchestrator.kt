package app.awrad.awrad_dhikrgoalstracker.notification

import java.nio.charset.StandardCharsets
import java.security.MessageDigest

/** Immutable envelope shared by exact-alarm and WorkManager urgency backends. */
data class AdaptiveNudgeEnvelope(
    val identity: NotificationIdentity,
    val triggerAtMillis: Long,
    val expiresAtMillis: Long,
    val kind: NudgeKind = identity.kind,
) {
    init {
        require(kind == identity.kind) { "Urgency kind must match canonical identity" }
        require(triggerAtMillis < expiresAtMillis) { "Urgency trigger must precede expiry" }
    }
}

enum class AdaptiveBackend {
    EXACT,
    WORK,
}

sealed interface AdaptiveScheduleResult {
    data class Scheduled(val backend: AdaptiveBackend) : AdaptiveScheduleResult
    data object Stale : AdaptiveScheduleResult
}

interface AdaptiveExactAlarmBackend {
    fun isExactSchedulingAvailable(): Boolean
    fun schedule(envelope: AdaptiveNudgeEnvelope)
    fun cancel(identity: NotificationIdentity)
}

data class AdaptiveWorkRequest(
    val envelope: AdaptiveNudgeEnvelope,
    val uniqueWorkName: String,
    val delayMillis: Long,
)

interface AdaptiveWorkBackend {
    fun enqueue(request: AdaptiveWorkRequest)
    fun cancel(identity: NotificationIdentity)
}

/**
 * Pure scheduling policy. A stale candidate never reaches either platform backend; permission
 * unavailability alone selects WorkManager while unexpected platform failures remain observable.
 */
class AdaptiveNudgeSchedulingOrchestrator(
    private val nowMillis: () -> Long,
    private val exactBackend: AdaptiveExactAlarmBackend,
    private val workBackend: AdaptiveWorkBackend,
) {
    fun schedule(envelope: AdaptiveNudgeEnvelope): AdaptiveScheduleResult {
        val now = nowMillis()
        if (envelope.triggerAtMillis <= now || now >= envelope.expiresAtMillis) return AdaptiveScheduleResult.Stale

        val exactAvailable = try {
            exactBackend.isExactSchedulingAvailable()
        } catch (_: SecurityException) {
            false
        }
        if (exactAvailable) {
            try {
                exactBackend.schedule(envelope)
                return AdaptiveScheduleResult.Scheduled(AdaptiveBackend.EXACT)
            } catch (_: SecurityException) {
                // Permission may be revoked between the availability check and scheduling.
            }
        }

        workBackend.enqueue(
            AdaptiveWorkRequest(
                envelope = envelope,
                uniqueWorkName = AdaptiveNudgeWorkIdentity.uniqueWorkName(envelope.identity),
                delayMillis = positiveDelayMillis(envelope.triggerAtMillis, now),
            ),
        )
        return AdaptiveScheduleResult.Scheduled(AdaptiveBackend.WORK)
    }

    fun cancel(identity: NotificationIdentity) {
        try {
            exactBackend.cancel(identity)
        } finally {
            // An exact alarm can exist even if the latest schedule chose WorkManager, and vice versa.
            workBackend.cancel(identity)
        }
    }

    private fun positiveDelayMillis(triggerAtMillis: Long, now: Long): Long =
        when {
            triggerAtMillis <= now -> 0L
            now < 0L && triggerAtMillis > Long.MAX_VALUE + now -> Long.MAX_VALUE
            else -> triggerAtMillis - now
        }
}

object AdaptiveNudgeWorkIdentity {
    fun uniqueWorkName(identity: NotificationIdentity): String =
        "awrad-urgency-" + MessageDigest.getInstance("SHA-256")
            .digest(identity.canonicalKey.toByteArray(StandardCharsets.UTF_8))
            .joinToString(separator = "") { byte -> "%02x".format(byte) }

    /** Stable tag shared by the current schedule and any immutable-envelope retries. */
    fun workTag(identity: NotificationIdentity): String = "awrad-urgency-tag-" +
        digest(identity.canonicalKey)

    /**
     * Retries cannot use the normal identity-only name: an old retry must never replace a
     * newer schedule for the same semantic stage.
     */
    fun retryUniqueWorkName(envelope: AdaptiveNudgeEnvelope): String =
        "awrad-urgency-retry-" + digest(
            "${envelope.identity.canonicalKey}\u0000${envelope.triggerAtMillis}\u0000${envelope.expiresAtMillis}",
        )

    private fun digest(value: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(StandardCharsets.UTF_8))
            .joinToString(separator = "") { byte -> "%02x".format(byte) }
}
