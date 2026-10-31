package app.awrad.core.testing.fixtures

import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.DateWindow
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.GoalJson
import app.awrad.core.domain.goal.GoalOrder
import app.awrad.core.domain.goal.GoalOrderJson
import app.awrad.core.domain.goal.GoalVersion
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/*
 * Goal domain types the way the goal-model fixtures' `expect` spells them.
 */

/** Encodes a window the way fixtures expect it: `{"from": …, "to": …}`. */
public fun DateWindow.toJson(): JsonObject = buildJsonObject {
    put("from", from.toString())
    put("to", to.toString())
}

/** Encodes an enum the way fixtures spell it: `NOT_MET` → `"not_met"`. */
public fun Enum<*>.toFixtureName(): String = name.lowercase()

/** `$defs/goal`. */
public fun GoalDefinition.toJson(): JsonObject = GoalJson.encodeGoal(this)

/** `$defs/version`. */
public fun GoalVersion.toJson(): JsonObject = GoalJson.encodeVersion(this)

/** `$defs/goal_order_document`. */
public fun GoalOrder.toJson(): JsonObject = GoalOrderJson.encode(this)

/** `$defs/count_entry`. */
public fun CountEntry.toJson(): JsonObject = buildJsonObject {
    put("date", date.toString())
    put("session", sessionId)
    put("count", count)
}
