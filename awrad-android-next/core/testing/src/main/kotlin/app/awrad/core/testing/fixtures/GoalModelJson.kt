package app.awrad.core.testing.fixtures

import app.awrad.core.domain.goal.ActivePeriod
import app.awrad.core.domain.goal.CalendarPeriod
import app.awrad.core.domain.goal.CalendarSystem
import app.awrad.core.domain.goal.CompletionPolicy
import app.awrad.core.domain.goal.CountEntry
import app.awrad.core.domain.goal.CountPolicy
import app.awrad.core.domain.goal.DateWindow
import app.awrad.core.domain.goal.GoalDefinition
import app.awrad.core.domain.goal.GoalDefinitionResult
import app.awrad.core.domain.goal.PausedRange
import app.awrad.core.domain.goal.Requirement
import app.awrad.core.domain.goal.Schedule
import app.awrad.core.domain.goal.Session
import app.awrad.core.domain.goal.StreakThreshold
import app.awrad.core.domain.goal.YearlyDay
import app.awrad.core.domain.goal.YearlyRange
import app.awrad.core.domain.practice.WeekStart
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import java.time.DayOfWeek
import java.time.LocalDate

/*
 * Decoders from the goal-model fixture JSON (contracts/goal-model/v1/goal-model.schema.json)
 * to domain types. Unknown kinds fail loudly so a new schema shape can't be skipped silently.
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
public fun JsonObject.goalResult(key: String = "goal"): GoalDefinitionResult {
    val goal = getValue(key).jsonObject
    return GoalDefinition.create(
        schedule = goal.getValue("schedule").jsonObject.toSchedule(),
        activePeriod = goal.getValue("active_period").jsonObject.toActivePeriod(),
        paused = goal.getValue("paused").jsonArray.map { it.jsonObject.toPausedRange() },
        countPolicy = goal.getValue("count_policy").jsonObject.toCountPolicy(),
        sessions = goal.getValue("sessions").jsonArray.map { it.jsonObject.toSession() },
        requirement = goal.getValue("requirement").jsonObject.toRequirement(),
        completion = enumOf<CompletionPolicy>(goal.string("completion")),
    )
}

/** Encodes a window the way fixtures expect it: `{"from": …, "to": …}`. */
public fun DateWindow.toJson(): JsonObject = buildJsonObject {
    put("from", from.toString())
    put("to", to.toString())
}

/** Encodes an enum the way fixtures spell it: `NOT_MET` → `"not_met"`. */
public fun Enum<*>.toFixtureName(): String = name.lowercase()

private fun JsonObject.toSchedule(): Schedule = when (val kind = string("kind")) {
    "every_day" -> Schedule.EveryDay
    "weekdays" -> Schedule.Weekdays(getValue("weekdays").jsonArray.map { enumOf<DayOfWeek>(it.content) }.toSet())
    "every_n_days" -> Schedule.EveryNDays(
        every = int("every"),
        anchorDate = stringOrNull("anchor_date")?.let(LocalDate::parse),
    )
    "month_days" -> Schedule.MonthDays(getValue("days").jsonArray.map { it.jsonPrimitive.int }.toSet())
    "specific_dates" -> Schedule.SpecificDates(getValue("dates").jsonArray.map { LocalDate.parse(it.content) }.toSet())
    "one_time" -> Schedule.OneTime
    "hijri_month_days" -> Schedule.HijriMonthDays(getValue("days").jsonArray.map { it.jsonPrimitive.int }.toSet())
    "yearly" -> Schedule.Yearly(
        calendar = enumOf<CalendarSystem>(string("calendar")),
        ranges = getValue("ranges").jsonArray.map {
            YearlyRange(start = it.jsonObject.yearlyDay("start"), end = it.jsonObject.yearlyDay("end"))
        },
    )
    else -> error("Unknown schedule kind: $kind")
}

private fun JsonObject.yearlyDay(key: String): YearlyDay =
    getValue(key).jsonObject.let { YearlyDay(month = it.int("month"), day = it.int("day")) }

private fun JsonObject.toActivePeriod(): ActivePeriod = ActivePeriod(
    startDate = date("start_date"),
    endDate = stringOrNull("end_date")?.let(LocalDate::parse),
    durationDays = longOrNull("duration_days")?.toInt(),
)

private fun JsonObject.toPausedRange(): PausedRange =
    PausedRange(from = date("from"), to = stringOrNull("to")?.let(LocalDate::parse))

private fun JsonObject.toCountPolicy(): CountPolicy = CountPolicy(
    minimum = longOrNull("minimum"),
    target = longOrNull("target"),
    maximum = longOrNull("maximum"),
    streakThreshold = enumOf<StreakThreshold>(string("streak_threshold")),
)

private fun JsonObject.toSession(): Session =
    Session(id = string("id"), countPolicy = getValue("count_policy").jsonObject.toCountPolicy())

private fun JsonObject.toRequirement(): Requirement = when (val type = string("type")) {
    "per_due_date" -> Requirement.PerDueDate
    "cumulative_total" -> Requirement.CumulativeTotal
    "tracker" -> Requirement.Tracker
    "period_total" -> Requirement.PeriodTotal(enumOf<CalendarPeriod>(string("period")))
    "days_per_period" -> Requirement.DaysPerPeriod(enumOf<CalendarPeriod>(string("period")), int("days"))
    else -> error("Unknown requirement type: $type")
}

internal fun JsonObject.int(key: String): Int = getValue(key).jsonPrimitive.int

private fun JsonObject.long(key: String): Long = getValue(key).jsonPrimitive.long

private fun JsonObject.longOrNull(key: String): Long? = getValue(key).takeUnless { it is JsonNull }?.jsonPrimitive?.long

private val JsonElement.content: String get() = jsonPrimitive.content

private inline fun <reified E : Enum<E>> enumOf(fixtureName: String): E = enumValueOf(fixtureName.uppercase())
