package app.awrad.core.domain.goal

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import java.time.LocalTime

/*
 * Goal types to the goal model's JSON ([GoalJson]): every member present, nulls written, sets in their order.
 */

internal fun encodeGoalDocument(document: GoalDocument): JsonObject = buildJsonObject {
    put("dhikr_id", document.dhikrId.value)
    putJsonObject("dhikr_snapshot") {
        putJsonObject("title") {
            put("en", document.dhikrSnapshot.title.en)
            put("ar", document.dhikrSnapshot.title.ar)
            put("ml", document.dhikrSnapshot.title.ml)
        }
        put("arabic", document.dhikrSnapshot.arabic)
        put("kind", document.dhikrSnapshot.kind.wire)
    }
    put("name", document.name)
    put("counts", document.counts.wire)
    val timeline = document.timeline
    put("created_on", timeline.createdOn.toString())
    put("versions", JsonArray(timeline.versions.map(::encodeVersionShape)))
    putPausesAndExcused(timeline.paused, timeline.excused)
    val ended = timeline.ended
    if (ended == null) {
        put("ended", JsonNull)
    } else {
        putJsonObject("ended") {
            put("on", ended.on.toString())
            put("reason", ended.reason.wire)
        }
    }
}

internal fun encodeGoalShape(goal: GoalDefinition): JsonObject = buildJsonObject {
    putSettings(goal.settings)
    putPausesAndExcused(goal.paused, goal.excused)
}

internal fun encodeVersionShape(version: GoalVersion): JsonObject = buildJsonObject {
    put("from", version.from.toString())
    putSettings(version.settings)
}

private fun JsonObjectBuilder.putPausesAndExcused(paused: List<PausedRange>, excused: Set<java.time.LocalDate>) {
    putJsonArray("paused") {
        paused.forEach { range ->
            addJsonObject {
                put("from", range.from.toString())
                put("to", range.to?.toString())
            }
        }
    }
    put("excused", JsonArray(excused.map { JsonPrimitive(it.toString()) }))
}

private fun JsonObjectBuilder.putSettings(settings: GoalSettings) {
    put("schedule", settings.schedule.toJson())
    putJsonObject("active_period") {
        put("start_date", settings.activePeriod.startDate.toString())
        put("end_date", settings.activePeriod.endDate?.toString())
        put("duration_days", settings.activePeriod.durationDays)
    }
    putJsonObject("count_policy") {
        put("minimum", settings.countPolicy.minimum)
        put("target", settings.countPolicy.target)
        put("maximum", settings.countPolicy.maximum)
        put("streak_threshold", settings.countPolicy.streakThreshold.toJson())
    }
    put("sessions", JsonArray(settings.sessions.map { it.toJson() }))
    put("requirement", settings.requirement.toJson())
    put("completion", settings.completion.wire)
    putJsonObject("make_up") {
        put("window", settings.makeUp.window.wire)
        put("fill", settings.makeUp.fill.wire)
    }
}

private fun Schedule.toJson(): JsonObject = buildJsonObject {
    when (val schedule = this@toJson) {
        Schedule.EveryDay -> put("kind", "every_day")
        Schedule.OneTime -> put("kind", "one_time")
        is Schedule.Weekdays -> {
            put("kind", "weekdays")
            put("weekdays", JsonArray(schedule.days.map { JsonPrimitive(it.wire) }))
        }
        is Schedule.EveryNDays -> {
            put("kind", "every_n_days")
            put("every", schedule.every)
            put("anchor_date", schedule.anchorDate?.toString())
        }
        is Schedule.MonthDays -> {
            put("kind", "month_days")
            put("days", JsonArray(schedule.days.map(::JsonPrimitive)))
        }
        is Schedule.SpecificDates -> {
            put("kind", "specific_dates")
            put("dates", JsonArray(schedule.dates.map { JsonPrimitive(it.toString()) }))
        }
        is Schedule.HijriMonthDays -> {
            put("kind", "hijri_month_days")
            put("days", JsonArray(schedule.days.map(::JsonPrimitive)))
        }
        is Schedule.Yearly -> {
            put("kind", "yearly")
            put("calendar", schedule.calendar.wire)
            putJsonArray("ranges") {
                schedule.ranges.forEach { range ->
                    addJsonObject {
                        put("start", range.start.toJson())
                        put("end", range.end.toJson())
                    }
                }
            }
        }
    }
}

private fun YearlyDay.toJson(): JsonObject = buildJsonObject {
    put("month", month)
    put("day", day)
}

private fun StreakThreshold.toJson(): JsonElement = when (this) {
    StreakThreshold.AnyCount -> JsonPrimitive("any_count")
    StreakThreshold.Minimum -> JsonPrimitive("minimum")
    StreakThreshold.Target -> JsonPrimitive("target")
    StreakThreshold.Maximum -> JsonPrimitive("maximum")
    StreakThreshold.DailyPace -> JsonPrimitive("daily_pace")
    is StreakThreshold.Amount -> buildJsonObject { put("amount", amount) }
}

private fun Session.toJson(): JsonObject = buildJsonObject {
    put("id", id)
    when (val kind = kind) {
        SessionKind.Anytime -> put("kind", "anytime")
        is SessionKind.BeforePrayer -> {
            put("kind", "before_prayer")
            put("prayer", kind.prayer.wire)
        }
        is SessionKind.AfterPrayer -> {
            put("kind", "after_prayer")
            put("prayer", kind.prayer.wire)
        }
        is SessionKind.AtTime -> {
            put("kind", "at_time")
            put("time", kind.time.wire)
        }
        is SessionKind.Between -> {
            put("kind", "between")
            put("from", kind.from.wire)
            put("to", kind.to.wire)
        }
    }
    put("target", target)
}

/** `06:30`, with ASCII digits whatever the locale. */
private val LocalTime.wire: String
    get() = hour.toString().padStart(2, '0') + ":" + minute.toString().padStart(2, '0')

private fun Requirement.toJson(): JsonObject = buildJsonObject {
    when (val requirement = this@toJson) {
        Requirement.PerDueDate -> put("type", "per_due_date")
        Requirement.CumulativeTotal -> put("type", "cumulative_total")
        Requirement.Tracker -> put("type", "tracker")
        is Requirement.PeriodTotal -> {
            put("type", "period_total")
            put("period", requirement.period.wire)
        }
        is Requirement.DaysPerPeriod -> {
            put("type", "days_per_period")
            put("period", requirement.period.wire)
            put("days", requirement.days)
        }
    }
}
