package app.awrad.core.domain.goal

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.personal.OptionalTexts
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalTime

/**
 * The goal model's JSON (`contracts/goal-model/v1/goal-model.schema.json`) to and from the goal types: the `goal`
 * sync entity's document, a timeline, a single goal, a version and its settings. Decoding returns null for JSON that
 * doesn't have the schema's shape, and the validity rules' result for a shape that does.
 */
public object GoalJson {

    /** A valid `$defs/goal_document`, or null when [document] isn't one. */
    public fun decodeDocument(document: JsonObject): GoalDocument? = parse {
        val snapshot = document.obj("dhikr_snapshot")
        val title = snapshot.obj("title")
        val timeline = (timelineOf(document) as? GoalTimelineResult.Valid)?.timeline ?: return@parse null
        GoalDocument(
            dhikrId = AwradId(document.text("dhikr_id")),
            dhikrSnapshot = DhikrSnapshot(
                title = OptionalTexts(title.textOrNull("en"), title.textOrNull("ar"), title.textOrNull("ml")),
                arabic = snapshot.text("arabic"),
                kind = enumOf<DhikrKind>(snapshot.text("kind")),
            ),
            name = document.textOrNull("name"),
            counts = enumOf<GoalCounts>(document.text("counts")),
            timeline = timeline,
        )
    }

    /** The `goal` document of [document]. */
    public fun encodeDocument(document: GoalDocument): JsonObject = encodeGoalDocument(document)

    /** The dhikr a goal document names, read without decoding the rest; null when there's no valid one. */
    public fun dhikrIdOf(document: JsonObject): AwradId? =
        (document["dhikr_id"] as? JsonPrimitive)?.takeIf { it.isString }?.content?.let(AwradId::parse)

    /** A `$defs/goal_timeline` (or a document's timeline part) through the validity rules; null when malformed. */
    public fun decodeTimeline(timeline: JsonObject): GoalTimelineResult? = parse { timelineOf(timeline) }

    /** A `$defs/goal_shape` through the validity rules; null when malformed. */
    public fun decodeGoal(goal: JsonObject): GoalDefinitionResult? =
        parse { GoalDefinition.create(goal.settings(), goal.pausedRanges(), goal.excusedDays()) }

    /** `$defs/goal_settings_shape` (any object holding its members), unvalidated; null when malformed. */
    public fun decodeSettings(settings: JsonObject): GoalSettings? = parse { settings.settings() }

    /** `$defs/version_shape` items, unvalidated; null when malformed. */
    public fun decodeVersions(versions: JsonArray): List<GoalVersion>? =
        parse { versions.map { it.jsonObject.version() } }

    /** `$defs/goal`: one version's settings plus the goal's pauses and excused days. */
    public fun encodeGoal(goal: GoalDefinition): JsonObject = encodeGoalShape(goal)

    /** `$defs/version`. */
    public fun encodeVersion(version: GoalVersion): JsonObject = encodeVersionShape(version)

    private fun timelineOf(json: JsonObject): GoalTimelineResult = GoalTimeline.create(
        createdOn = json.date("created_on"),
        versions = json.getValue("versions").jsonArray.map { it.jsonObject.version() },
        paused = json.pausedRanges(),
        excused = json.excusedDays(),
        ended = json.getValue("ended").takeUnless { it is JsonNull }?.jsonObject?.let {
            GoalEnd(on = it.date("on"), reason = enumOf<EndReason>(it.text("reason")))
        },
    )

    /** Malformed JSON throws while it's read (a missing member, a wrong type, an unknown name): that's null. */
    private inline fun <T> parse(read: () -> T?): T? = runCatching(read).getOrNull()
}

/** `$defs/goal_order_document` to and from [GoalOrder]. */
public object GoalOrderJson {
    public fun encode(order: GoalOrder): JsonObject =
        JsonObject(mapOf("goal_ids" to JsonArray(order.goalIds.map { JsonPrimitive(it.value) })))

    /** The order [document] holds, or null when it isn't a valid one (an ID that isn't a UUID, a repeat). */
    public fun decode(document: JsonObject): GoalOrder? = runCatching {
        val ids = document.getValue("goal_ids").jsonArray.map { AwradId.parse(it.jsonPrimitive.content) }
        if (ids.any { it == null } || ids.toSet().size != ids.size) null else GoalOrder(ids.filterNotNull())
    }.getOrNull()
}

private fun JsonObject.version(): GoalVersion = GoalVersion(from = date("from"), settings = settings())

private fun JsonObject.settings(): GoalSettings = GoalSettings(
    schedule = obj("schedule").schedule(),
    activePeriod = obj("active_period").let {
        ActivePeriod(
            startDate = it.date("start_date"),
            endDate = it.textOrNull("end_date")?.let(LocalDate::parse),
            durationDays = it.longOrNull("duration_days")?.let(Math::toIntExact),
        )
    },
    countPolicy = obj("count_policy").let {
        CountPolicy(
            minimum = it.longOrNull("minimum"),
            target = it.longOrNull("target"),
            maximum = it.longOrNull("maximum"),
            streakThreshold = it.getValue("streak_threshold").streakThreshold(),
        )
    },
    sessions = getValue("sessions").jsonArray.map { it.jsonObject.session() },
    requirement = obj("requirement").requirement(),
    completion = enumOf<CompletionPolicy>(text("completion")),
    makeUp = obj("make_up").let {
        MakeUp(window = enumOf<MakeUpWindow>(it.text("window")), fill = enumOf<MakeUpFill>(it.text("fill")))
    },
)

private fun JsonObject.pausedRanges(): List<PausedRange> = getValue("paused").jsonArray.map {
    PausedRange(from = it.jsonObject.date("from"), to = it.jsonObject.textOrNull("to")?.let(LocalDate::parse))
}

private fun JsonObject.excusedDays(): Set<LocalDate> =
    getValue("excused").jsonArray.map { LocalDate.parse(it.jsonPrimitive.content) }.toSet()

private fun JsonObject.schedule(): Schedule = when (val kind = text("kind")) {
    "every_day" -> Schedule.EveryDay
    "weekdays" -> Schedule.Weekdays(strings("weekdays").map { enumOf<DayOfWeek>(it) }.toSet())
    "every_n_days" -> Schedule.EveryNDays(
        every = int("every"),
        anchorDate = textOrNull("anchor_date")?.let(LocalDate::parse),
    )
    "month_days" -> Schedule.MonthDays(ints("days"))
    "specific_dates" -> Schedule.SpecificDates(strings("dates").map(LocalDate::parse).toSet())
    "one_time" -> Schedule.OneTime
    "hijri_month_days" -> Schedule.HijriMonthDays(ints("days"))
    "yearly" -> Schedule.Yearly(
        calendar = enumOf<CalendarSystem>(text("calendar")),
        ranges = getValue("ranges").jsonArray.map {
            YearlyRange(start = it.jsonObject.obj("start").yearlyDay(), end = it.jsonObject.obj("end").yearlyDay())
        },
    )
    else -> error("Unknown schedule kind: $kind")
}

private fun JsonObject.yearlyDay(): YearlyDay = YearlyDay(month = int("month"), day = int("day"))

private fun JsonElement.streakThreshold(): StreakThreshold = when {
    this is JsonObject -> StreakThreshold.Amount(long("amount"))
    else -> when (val name = jsonPrimitive.content) {
        "any_count" -> StreakThreshold.AnyCount
        "minimum" -> StreakThreshold.Minimum
        "target" -> StreakThreshold.Target
        "maximum" -> StreakThreshold.Maximum
        "daily_pace" -> StreakThreshold.DailyPace
        else -> error("Unknown streak threshold: $name")
    }
}

private fun JsonObject.session(): Session = Session(
    id = text("id"),
    kind = when (val kind = text("kind")) {
        "anytime" -> SessionKind.Anytime
        "before_prayer" -> SessionKind.BeforePrayer(enumOf<Prayer>(text("prayer")))
        "after_prayer" -> SessionKind.AfterPrayer(enumOf<Prayer>(text("prayer")))
        "at_time" -> SessionKind.AtTime(LocalTime.parse(text("time")))
        "between" -> SessionKind.Between(LocalTime.parse(text("from")), LocalTime.parse(text("to")))
        else -> error("Unknown session kind: $kind")
    },
    target = longOrNull("target"),
)

private fun JsonObject.requirement(): Requirement = when (val type = text("type")) {
    "per_due_date" -> Requirement.PerDueDate
    "cumulative_total" -> Requirement.CumulativeTotal
    "tracker" -> Requirement.Tracker
    "period_total" -> Requirement.PeriodTotal(enumOf<CalendarPeriod>(text("period")))
    "days_per_period" -> Requirement.DaysPerPeriod(enumOf<CalendarPeriod>(text("period")), int("days"))
    else -> error("Unknown requirement type: $type")
}

private fun JsonObject.obj(member: String): JsonObject = getValue(member).jsonObject

private fun JsonObject.text(member: String): String {
    val value = getValue(member).jsonPrimitive
    require(value.isString) { "$member isn't a string" }
    return value.content
}

private fun JsonObject.textOrNull(member: String): String? = if (getValue(member) is JsonNull) null else text(member)

private fun JsonObject.date(member: String): LocalDate = LocalDate.parse(text(member))

private fun JsonObject.int(member: String): Int = getValue(member).jsonPrimitive.int

private fun JsonObject.long(member: String): Long = getValue(member).jsonPrimitive.long

private fun JsonObject.longOrNull(member: String): Long? = if (getValue(member) is JsonNull) null else long(member)

private fun JsonObject.strings(member: String): List<String> =
    getValue(member).jsonArray.map { it.jsonPrimitive.content }

private fun JsonObject.ints(member: String): Set<Int> = getValue(member).jsonArray.map { it.jsonPrimitive.int }.toSet()

/** A wire name (`after_prayer`, `name_of_allah`) as its enum constant; unknown names throw. */
private inline fun <reified E : Enum<E>> enumOf(wire: String): E =
    enumValues<E>().first { it.name.lowercase() == wire }

/** An enum constant as its wire name: `NAME_OF_ALLAH` → `name_of_allah`. */
internal val Enum<*>.wire: String get() = name.lowercase()
