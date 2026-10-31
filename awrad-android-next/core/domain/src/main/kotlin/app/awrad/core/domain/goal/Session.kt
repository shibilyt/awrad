package app.awrad.core.domain.goal

import java.time.LocalTime

/** The five daily prayers a session can be placed before or after. */
public enum class Prayer {
    FAJR,
    DHUHR,
    ASR,
    MAGHRIB,
    ISHA,
}

/**
 * When a session is meant to happen (decision 10). Kinds only guide: any session can be counted at any time of its
 * day, and windows never block (decision 11).
 */
public sealed interface SessionKind {

    /** The session ID this kind derives (README.md, "Sessions"), so shared counts match sessions across goals. */
    public val derivedId: String

    public data object Anytime : SessionKind {
        override val derivedId: String = "anytime"
    }

    public data class BeforePrayer(val prayer: Prayer) : SessionKind {
        override val derivedId: String get() = "before_${prayer.name.lowercase()}"
    }

    public data class AfterPrayer(val prayer: Prayer) : SessionKind {
        override val derivedId: String get() = "after_${prayer.name.lowercase()}"
    }

    public data class AtTime(val time: LocalTime) : SessionKind {
        override val derivedId: String get() = "at_${time.compact()}"
    }

    /** A local window; it may run past midnight ([from] after [to]). An empty one ([from] = [to]) is invalid. */
    public data class Between(val from: LocalTime, val to: LocalTime) : SessionKind {
        override val derivedId: String get() = "between_${from.compact()}_${to.compact()}"
    }
}

/** `06:30` → `0630`, with ASCII digits whatever the locale. */
private fun LocalTime.compact(): String = hour.toString().padStart(2, '0') + minute.toString().padStart(2, '0')

/**
 * A time-of-day opportunity with its own [target] (CONTEXT.md, "Session"; decision 47): no minimum, cap or streak
 * threshold of its own, and its streak amount is its target. [target] is null only on a tracker's session (any count).
 *
 * [id] should be [SessionKind.derivedId]; [GoalDefinition.create] rejects one that isn't (`session_id_mismatch`).
 */
public data class Session(val id: String, val kind: SessionKind, val target: Long?) {
    init {
        require(id.isNotBlank()) { "A session needs an id" }
        require(target == null || target >= 0) { "Counts can't be negative: $target" }
    }

    public companion object {
        /** A session whose ID is derived from its [kind]. */
        public fun of(kind: SessionKind, target: Long?): Session = Session(kind.derivedId, kind, target)
    }
}
