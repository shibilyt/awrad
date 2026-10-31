package app.awrad.core.testing.fixtures

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.CountLogEntry
import app.awrad.core.domain.goal.GoalCounts
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.GoalDefinitionResult
import app.awrad.core.domain.goal.GoalDocument
import app.awrad.core.domain.goal.GoalJson
import app.awrad.core.domain.goal.GoalOrder
import app.awrad.core.domain.goal.GoalOrderJson
import app.awrad.core.domain.goal.GoalSettings
import app.awrad.core.domain.goal.GoalTimeline
import app.awrad.core.domain.goal.GoalTimelineResult
import app.awrad.core.domain.goal.GoalVersion
import app.awrad.core.domain.goal.asTimeline
import app.awrad.core.domain.practice.WeekStart
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import java.time.Instant
import java.time.LocalDate

/*
 * The goal-model fixtures' `given` members (contracts/goal-model/v1/goal-model.schema.json) as domain types. Goals,
 * timelines and documents go through the domain's own codec ([GoalJson]); JSON it can't read fails the case.
 */

public fun JsonObject.string(key: String): String = getValue(key).jsonPrimitive.content

public fun JsonObject.stringOrNull(key: String): String? =
    getValue(key).takeUnless { it is JsonNull }?.jsonPrimitive?.content

public fun JsonObject.date(key: String): LocalDate = LocalDate.parse(string(key))

public fun JsonObject.weekStart(key: String = "week_start"): WeekStart = enumOf(string(key))

public fun JsonObject.counts(key: String = "counts"): List<CountEntry> = getValue(key).jsonArray.map {
    val entry = it.jsonObject
    CountEntry(date = entry.date("date"), sessionId = entry.stringOrNull("session"), count = entry.long("count"))
}

/** A valid goal, as every rule fixture's `goal` is. Fails the case when the domain rejects it. */
public fun JsonObject.goal(key: String = "goal"): GoalDefinition = when (val result = goalResult(key)) {
    is GoalDefinitionResult.Valid -> result.definition
    is GoalDefinitionResult.Invalid -> error("Fixture goal is invalid: ${result.errors}")
}

/** A structural `goal_shape`, which may be invalid, put through the domain's validation (fixture `goal_validity`). */
public fun JsonObject.goalResult(key: String = "goal"): GoalDefinitionResult =
    checkNotNull(GoalJson.decodeGoal(getValue(key).jsonObject)) { "Fixture goal is malformed" }

/** A rule input (`$defs/goal_input`): a timeline, or a single goal standing for one. */
public fun JsonObject.goalInput(key: String = "goal"): GoalTimeline =
    if ("versions" in getValue(key).jsonObject) timeline(key) else goal(key).asTimeline()

/** A valid `goal_timeline` (or the timeline part of a `goal_document`). Fails the case when the domain rejects it. */
public fun JsonObject.timeline(key: String): GoalTimeline = when (val result = timelineResult(key)) {
    is GoalTimelineResult.Valid -> result.timeline
    is GoalTimelineResult.Invalid -> error("Fixture timeline is invalid: ${result.errors}")
}

/** A timeline or document's timeline part, which may be invalid, put through the domain's validation. */
public fun JsonObject.timelineResult(key: String): GoalTimelineResult =
    checkNotNull(GoalJson.decodeTimeline(getValue(key).jsonObject)) { "Fixture timeline is malformed" }

/** A valid `goal_document`. */
public fun JsonObject.goalDocument(key: String = "document"): GoalDocument =
    checkNotNull(GoalJson.decodeDocument(getValue(key).jsonObject)) { "Fixture document isn't a valid one" }

/** `$defs/version_shape` items of [key]. */
public fun JsonObject.versions(key: String = "versions"): List<GoalVersion> =
    checkNotNull(GoalJson.decodeVersions(getValue(key).jsonArray)) { "Fixture versions are malformed" }

/** `$defs/goal_settings_shape`. */
public fun JsonObject.settings(key: String = "settings"): GoalSettings =
    checkNotNull(GoalJson.decodeSettings(getValue(key).jsonObject)) { "Fixture settings are malformed" }

public fun JsonObject.goalCounts(key: String = "counts"): GoalCounts = enumOf(string(key))

public fun JsonObject.goalOrder(key: String): GoalOrder =
    checkNotNull(GoalOrderJson.decode(getValue(key).jsonObject)) { "Fixture goal order is invalid" }

/** `$defs/count_log_entry` items of [key]. */
public fun JsonObject.countLog(key: String = "log"): List<CountLogEntry> = getValue(key).jsonArray.map {
    val entry = it.jsonObject
    CountLogEntry(
        id = AwradId(entry.string("id")),
        dhikrId = AwradId(entry.string("dhikr_id")),
        practiceDay = entry.date("practice_day"),
        sessionId = entry.stringOrNull("session_id"),
        goalId = entry.stringOrNull("goal_id")?.let(::AwradId),
        amount = entry.long("amount"),
        countedAt = Instant.parse(entry.string("counted_at")),
    )
}

internal fun JsonObject.int(key: String): Int = getValue(key).jsonPrimitive.int

private fun JsonObject.long(key: String): Long = getValue(key).jsonPrimitive.long

internal inline fun <reified E : Enum<E>> enumOf(fixtureName: String): E = enumValueOf(fixtureName.uppercase())
