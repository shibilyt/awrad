package app.awrad.core.domain.goal

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.personal.OptionalTexts

/** Which count-log entries fill a goal (decision 2). Set at creation and never changed. */
public enum class GoalCounts {
    /** Every count of its dhikr made outside a dedicated goal, wherever it was made. */
    SHARED,

    /** Only counts made inside this goal; they fill no other goal. */
    DEDICATED,
}

/**
 * The dhikr's label when the goal was last saved (decision 37), so History and stats read correctly after a custom
 * dhikr is gone. Apps show the live dhikr while it exists.
 */
public data class DhikrSnapshot(val title: OptionalTexts, val arabic: String, val kind: DhikrKind) {
    init {
        require(title.all.isNotEmpty()) { "A dhikr snapshot needs a title in at least one language" }
    }
}

/**
 * The `goal` sync entity's document (`$defs/goal_document`): the dhikr it's for (a catalog ID or a custom dhikr's
 * entity ID, never changed), its [dhikrSnapshot], the user's own [name] (null shows the dhikr's title), whether its
 * [counts] are shared or dedicated, and its [timeline]. Valid because the timeline is.
 */
public data class GoalDocument(
    val dhikrId: AwradId,
    val dhikrSnapshot: DhikrSnapshot,
    val name: String?,
    val counts: GoalCounts,
    val timeline: GoalTimeline,
)

/**
 * The `goal_order` sync entity's document (`$defs/goal_order_document`): the user's order of My Goals (decision 25),
 * one per account. Goals it doesn't name follow, by `created_on` then ID.
 */
public data class GoalOrder(val goalIds: List<AwradId>) {
    init {
        require(goalIds.toSet().size == goalIds.size) { "A goal order names each goal once" }
    }

    public companion object {
        public val EMPTY: GoalOrder = GoalOrder(emptyList())
    }
}
