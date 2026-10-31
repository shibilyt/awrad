package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.goal.GoalOrder

/** The result of [GoalOrderMerge.merge]: the merged [order], and whether it differs from theirs and must be sent. */
public data class GoalOrderMergeResult(val order: GoalOrder, val requeue: Boolean)

/**
 * What a phone does when its `goal_order` put conflicts, instead of asking (fixture `goal_order_merge`; README.md,
 * "The goal order").
 */
public object GoalOrderMerge {

    /**
     * Unchanged locally ([mine] equals [base]): take [theirs]. Otherwise mine wins, less the goals the server dropped
     * since [base], plus the goals it added since [base], appended in its order.
     */
    public fun merge(base: GoalOrder, mine: GoalOrder, theirs: GoalOrder): GoalOrderMergeResult {
        if (mine == base) return GoalOrderMergeResult(theirs, requeue = false)
        val dropped = base.goalIds.toSet() - theirs.goalIds.toSet()
        val kept = mine.goalIds.filterNot { it in dropped }
        val added = theirs.goalIds.filterNot { it in kept || it in base.goalIds }
        val merged = GoalOrder(kept + added)
        return GoalOrderMergeResult(merged, requeue = merged != theirs)
    }
}
