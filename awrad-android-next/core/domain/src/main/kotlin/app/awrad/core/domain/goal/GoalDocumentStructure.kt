package app.awrad.core.domain.goal

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.isBlank
import app.awrad.core.domain.sync.FieldError
import app.awrad.core.domain.sync.FieldErrorCode
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.longOrNull
import java.time.LocalDate
import java.time.LocalTime
import java.time.Month
import java.time.format.DateTimeParseException

/*
 * The structural layer of goal document validity (`$defs/goal_document`; contracts/sync/v1/README.md, "Goal
 * documents"): every member present and of its shape, reported as `{field, code}` at its JSON Pointer.
 */

/** A member's check: [value] is present (JSON null included) at [path]. */
private typealias Check = StructureErrors.(value: JsonElement, path: String) -> Unit

/** A check, typed so a lambda gets its receiver. */
private fun check(block: Check): Check = block

/** A member whose value another check already read (a schedule's or session's `kind`). */
private val IGNORE: Check = { _, _ -> }

/** Collects structural errors while a document is walked. */
internal class StructureErrors {
    val errors: MutableList<FieldError> = mutableListOf()

    fun add(path: String, code: FieldErrorCode) {
        errors += FieldError(path, code)
    }

    /** An object of exactly [members]: an unknown member is `not_allowed`, a missing one `required`. */
    fun shape(value: JsonElement, path: String, members: Map<String, Check>) {
        if (value !is JsonObject) return add(path, FieldErrorCode.INVALID)
        value.keys.filterNot { it in members }.forEach { add("$path/$it", FieldErrorCode.NOT_ALLOWED) }
        members.forEach { (name, check) ->
            val member = value[name]
            if (member == null) add("$path/$name", FieldErrorCode.REQUIRED) else check(member, "$path/$name")
        }
    }
}

/** Every structural error of a goal document, unsorted. */
internal fun goalDocumentStructureErrors(document: JsonElement): List<FieldError> =
    StructureErrors().apply { shape(document, "", DOCUMENT) }.errors

private val DOCUMENT: Map<String, Check> = mapOf(
    "dhikr_id" to uuid(),
    "dhikr_snapshot" to check { value, path -> shape(value, path, SNAPSHOT) },
    "name" to nullable(text(MAX_LABEL)),
    "counts" to oneOf("shared", "dedicated"),
    "created_on" to date(),
    "versions" to list(GoalTimeline.MAX_VERSIONS, emptyIsRequired = true) { value, path ->
        shape(value, path, VERSION)
    },
    "paused" to list(MAX_PAUSES) { value, path ->
        shape(value, path, mapOf("from" to date(), "to" to nullable(date())))
    },
    "excused" to list(MAX_EXCUSED, unique = true, item = date()),
    "ended" to nullable { value, path ->
        shape(value, path, mapOf("on" to date(), "reason" to oneOf(EndReason.entries.map { it.wire })))
    },
)

private val SNAPSHOT: Map<String, Check> = mapOf(
    "title" to check { value, path ->
        val languages = listOf("en", "ar", "ml")
        shape(value, path, languages.associateWith { nullable(text(MAX_LABEL)) })
        val hasText = value is JsonObject && languages.any { (value[it] as? JsonPrimitive)?.isString == true }
        if (value is JsonObject && !hasText) add(path, FieldErrorCode.REQUIRED)
    },
    "arabic" to text(MAX_ARABIC),
    "kind" to oneOf("quran", "dhikr", "dua", "salawat", "name_of_allah"),
)

private val VERSION: Map<String, Check> = mapOf(
    "from" to date(),
    "schedule" to check { value, path -> schedule(value, path) },
    "active_period" to check { value, path ->
        shape(
            value,
            path,
            mapOf(
                "start_date" to date(),
                "end_date" to nullable(date()),
                "duration_days" to nullable(integer(1..ActivePeriod.MAX_DURATION_DAYS.toLong())),
            ),
        )
    },
    "count_policy" to check { value, path ->
        shape(
            value,
            path,
            mapOf(
                "minimum" to nullable(count()),
                "target" to nullable(count()),
                "maximum" to nullable(count()),
                "streak_threshold" to check { threshold, at -> streakThreshold(threshold, at) },
            ),
        )
    },
    "sessions" to list(Int.MAX_VALUE) { value, path -> session(value, path) },
    "requirement" to check { value, path -> requirement(value, path) },
    "completion" to oneOf(CompletionPolicy.entries.map { it.wire }),
    "make_up" to check { value, path ->
        shape(
            value,
            path,
            mapOf(
                "window" to oneOf(MakeUpWindow.entries.map { it.wire }),
                "fill" to oneOf(MakeUpFill.entries.map { it.wire }),
            ),
        )
    },
)

private val SCHEDULES: Map<String, Map<String, Check>> = mapOf(
    "every_day" to emptyMap(),
    "one_time" to emptyMap(),
    "weekdays" to mapOf("weekdays" to set(weekday())),
    "every_n_days" to mapOf(
        "every" to integer(1..Schedule.EveryNDays.MAX_INTERVAL_DAYS.toLong()),
        "anchor_date" to nullable(date()),
    ),
    "month_days" to mapOf("days" to set(integer(1L..MAX_MONTH_DAY))),
    "specific_dates" to mapOf("dates" to set(date())),
    "hijri_month_days" to mapOf("days" to set(integer(1L..MAX_HIJRI_DAY))),
)

private fun StructureErrors.schedule(value: JsonElement, path: String) {
    val kind = (value as? JsonObject)?.get("kind")?.let { (it as? JsonPrimitive)?.takeIf { p -> p.isString }?.content }
    when {
        value !is JsonObject -> add(path, FieldErrorCode.INVALID)
        value["kind"] == null -> add("$path/kind", FieldErrorCode.REQUIRED)
        kind == "yearly" -> yearly(value, path)
        kind in SCHEDULES -> shape(value, path, SCHEDULES.getValue(kind!!) + ("kind" to IGNORE))
        else -> add("$path/kind", FieldErrorCode.INVALID)
    }
}

private fun StructureErrors.yearly(value: JsonObject, path: String) {
    val calendar = (value["calendar"] as? JsonPrimitive)?.content
    val day: Check = { range, at ->
        val before = errors.size
        shape(range, at, mapOf("month" to integer(1L..MONTHS), "day" to integer(1L..MAX_MONTH_DAY)))
        if (errors.size == before) {
            // Well formed: the day must exist in that month (29 February yes, 31 April and Hijri 31 no).
            val month = ((range as JsonObject).getValue("month") as JsonPrimitive).longOrNull ?: 1L
            val dayOf = (range.getValue("day") as JsonPrimitive).longOrNull ?: 1L
            val max = if (calendar == "gregorian") Month.of(month.toInt()).maxLength().toLong() else MAX_HIJRI_DAY
            if (dayOf > max) add(at, FieldErrorCode.INVALID)
        }
    }
    shape(
        value,
        path,
        mapOf(
            "kind" to IGNORE,
            "calendar" to oneOf("gregorian", "hijri"),
            "ranges" to list(Int.MAX_VALUE, emptyIsRequired = true) { range, at ->
                shape(range, at, mapOf("start" to day, "end" to day))
            },
        ),
    )
}

private val SESSION_KINDS: Map<String, Map<String, Check>> = mapOf(
    "anytime" to emptyMap(),
    "before_prayer" to mapOf("prayer" to oneOf(Prayer.entries.map { it.wire })),
    "after_prayer" to mapOf("prayer" to oneOf(Prayer.entries.map { it.wire })),
    "at_time" to mapOf("time" to time()),
    "between" to mapOf("from" to time(), "to" to time()),
)

private fun StructureErrors.session(value: JsonElement, path: String) {
    val kind = ((value as? JsonObject)?.get("kind") as? JsonPrimitive)?.takeIf { it.isString }?.content
    val common: Map<String, Check> = mapOf(
        "id" to check { id, at ->
            val text = (id as? JsonPrimitive)?.takeIf { it.isString }?.content
            if (text == null || !SESSION_ID.matches(text)) add(at, FieldErrorCode.INVALID)
        },
        "kind" to IGNORE,
        "target" to nullable(count()),
    )
    when {
        value !is JsonObject -> add(path, FieldErrorCode.INVALID)
        value["kind"] == null -> add("$path/kind", FieldErrorCode.REQUIRED)
        kind in SESSION_KINDS -> shape(value, path, common + SESSION_KINDS.getValue(kind!!))
        else -> add("$path/kind", FieldErrorCode.INVALID)
    }
}

private fun StructureErrors.requirement(value: JsonElement, path: String) {
    val type = ((value as? JsonObject)?.get("type") as? JsonPrimitive)?.takeIf { it.isString }?.content
    val period = oneOf("week", "month", "hijri_month")
    val members: Map<String, Check>? = when (type) {
        "per_due_date", "cumulative_total", "tracker" -> emptyMap()
        "period_total" -> mapOf("period" to period)
        "days_per_period" -> mapOf(
            "period" to period,
            "days" to integer(1..Requirement.DaysPerPeriod.MAX_DAYS.toLong()),
        )
        else -> null
    }
    when {
        value !is JsonObject -> add(path, FieldErrorCode.INVALID)
        value["type"] == null -> add("$path/type", FieldErrorCode.REQUIRED)
        members == null -> add("$path/type", FieldErrorCode.INVALID)
        else -> shape(value, path, members + ("type" to IGNORE))
    }
}

private fun StructureErrors.streakThreshold(value: JsonElement, path: String) {
    val names = setOf("any_count", "minimum", "target", "maximum", "daily_pace")
    when {
        value is JsonObject -> shape(value, path, mapOf("amount" to integer(1..MAX_COUNT)))
        (value as? JsonPrimitive)?.takeIf { it.isString }?.content !in names -> add(path, FieldErrorCode.INVALID)
    }
}

private fun nullable(check: Check): Check = { value, path -> if (value !is JsonNull) check(value, path) }

private fun text(maxLength: Int): Check = { value, path ->
    val text = (value as? JsonPrimitive)?.takeIf { it.isString }?.content
    when {
        text == null -> add(path, FieldErrorCode.INVALID)
        isBlank(text) -> add(path, FieldErrorCode.BLANK)
        text.codePointCount(0, text.length) > maxLength -> add(path, FieldErrorCode.TOO_LONG)
    }
}

private fun oneOf(vararg names: String): Check = oneOf(names.toList())

private fun oneOf(names: Collection<String>): Check = { value, path ->
    if ((value as? JsonPrimitive)?.takeIf { it.isString }?.content !in names) add(path, FieldErrorCode.INVALID)
}

private fun uuid(): Check = { value, path ->
    val text = (value as? JsonPrimitive)?.takeIf { it.isString }?.content
    if (text == null || AwradId.parse(text) == null) add(path, FieldErrorCode.INVALID)
}

private fun date(): Check = { value, path ->
    val text = (value as? JsonPrimitive)?.takeIf { it.isString }?.content
    val valid = text != null && DATE.matches(text) &&
        try {
            LocalDate.parse(text)
            true
        } catch (_: DateTimeParseException) {
            false
        }
    if (!valid) add(path, FieldErrorCode.INVALID)
}

private fun time(): Check = { value, path ->
    val text = (value as? JsonPrimitive)?.takeIf { it.isString }?.content
    val valid = text != null && TIME.matches(text) && runCatching { LocalTime.parse(text) }.isSuccess
    if (!valid) add(path, FieldErrorCode.INVALID)
}

private fun weekday(): Check = oneOf(java.time.DayOfWeek.entries.map { it.wire })

private fun integer(range: LongRange): Check = { value, path ->
    val number = (value as? JsonPrimitive)?.takeUnless { it.isString }?.longOrNull
    if (number == null || number !in range) add(path, FieldErrorCode.INVALID)
}

private fun count(): Check = integer(0..MAX_COUNT)

/**
 * An array of at most [max] items, each checked by [item]: over the limit is `too_many`, an empty one `required` when
 * [emptyIsRequired], and with [unique] a repeated item is `duplicate` on the array.
 */
private fun list(
    max: Int,
    emptyIsRequired: Boolean = false,
    unique: Boolean = false,
    item: Check,
): Check = { value, path ->
    when {
        value !is JsonArray -> add(path, FieldErrorCode.INVALID)
        value.isEmpty() && emptyIsRequired -> add(path, FieldErrorCode.REQUIRED)
        value.size > max -> add(path, FieldErrorCode.TOO_MANY)
        else -> {
            value.forEachIndexed { index, element -> item(element, "$path/$index") }
            if (unique && value.toSet().size != value.size) add(path, FieldErrorCode.DUPLICATE)
        }
    }
}

/** A non-empty array without repeats (weekdays, month days, dates). */
private fun set(item: Check): Check = list(Int.MAX_VALUE, emptyIsRequired = true, unique = true, item = item)

private const val MONTHS = 12L
private const val MAX_MONTH_DAY = 31L
private const val MAX_HIJRI_DAY = 30L
private const val MAX_LABEL = 120
private const val MAX_ARABIC = 5000
private const val MAX_PAUSES = 500
private const val MAX_EXCUSED = 1000
private const val MAX_COUNT = 9_007_199_254_740_991L
private val SESSION_ID = Regex("^[a-z][a-z0-9_]*$")
private val DATE = Regex("^\\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\\d|3[01])$")
private val TIME = Regex("^([01]\\d|2[0-3]):[0-5]\\d$")
