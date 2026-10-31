package app.awrad.core.domain.goal

import java.time.LocalDate

/** Settings in force from [from] (an effective practice day) until the next version's [from] (decision 23). */
public data class GoalVersion(val from: LocalDate, val settings: GoalSettings)

/** Why a goal finished (README.md, "The goal document"). */
public enum class EndReason {
    /** End goal. */
    USER,

    /** A total was reached. */
    COMPLETED,

    /** Its active period ran out, or no scheduled day is left. */
    DATE,

    /** A different schedule or requirement type started a new goal. */
    STRUCTURAL_EDIT,

    /** Its custom dhikr was deleted (decision 37). */
    DHIKR_DELETED,
}

/** When and why a goal finished: [on] is its last day, inclusive. A finished goal is never reactivated. */
public data class GoalEnd(val on: LocalDate, val reason: EndReason)

/**
 * Everything about a goal's days (`$defs/goal_timeline`): its dated [versions], oldest first and the first from
 * [createdOn], plus [paused], [excused] and [ended], which aren't versioned. Rules that look across days judge each day
 * by the version in force that day (README.md, "Dated versions").
 *
 * Only valid timelines exist: build one with [create], or from a single goal with [GoalDefinition.asTimeline].
 */
@ConsistentCopyVisibility
public data class GoalTimeline internal constructor(
    val createdOn: LocalDate,
    val versions: List<GoalVersion>,
    val paused: List<PausedRange>,
    val excused: Set<LocalDate>,
    val ended: GoalEnd?,
) {

    /** The index of the version in force on [date]: the latest starting on or before it, or the first. */
    public fun versionIndexOn(date: LocalDate): Int = versions.indexOfLast { !it.from.isAfter(date) }.coerceAtLeast(0)

    /**
     * The goal a rule evaluates on [date]: that version's settings plus the pauses and excused days. An ended goal's
     * active period ends on [GoalEnd.on] when the version's own last day is later or missing.
     */
    public fun goalOn(date: LocalDate): GoalDefinition = goalOn(date, capEnded = true)

    /** [capEnded] false keeps the version's own end (daily pace and count attribution). */
    internal fun goalOn(date: LocalDate, capEnded: Boolean): GoalDefinition {
        val settings = versions[versionIndexOn(date)].settings
        val end = ended?.on?.takeIf { capEnded }
        val endsLater = end != null && settings.activePeriod.lastDay?.isAfter(end) != false
        val capped = if (endsLater) {
            settings.copy(activePeriod = ActivePeriod(settings.activePeriod.startDate, endDate = end))
        } else {
            settings
        }
        return GoalDefinition(capped, paused, excused)
    }

    public companion object {
        /** The most versions a goal keeps; a 101st folds the oldest into the next ([withEdit]). */
        public const val MAX_VERSIONS: Int = 100

        /**
         * Validates every version (with the goal's pauses and excused days) and the document rules, and builds the
         * timeline, or returns every reason it's invalid (fixture `goal_validity`).
         */
        public fun create(
            createdOn: LocalDate,
            versions: List<GoalVersion>,
            paused: List<PausedRange> = emptyList(),
            excused: Set<LocalDate> = emptySet(),
            ended: GoalEnd? = null,
        ): GoalTimelineResult {
            require(versions.size in 1..MAX_VERSIONS) { "A goal has 1..$MAX_VERSIONS versions: ${versions.size}" }
            val errors = timelineErrors(createdOn, versions)
            return if (errors.isEmpty()) {
                GoalTimelineResult.Valid(GoalTimeline(createdOn, versions, paused, excused, ended))
            } else {
                GoalTimelineResult.Invalid(errors)
            }
        }
    }
}

/** The outcome of [GoalTimeline.create]: the timeline, or every reason it's invalid. */
public sealed interface GoalTimelineResult {
    public data class Valid(val timeline: GoalTimeline) : GoalTimelineResult

    public data class Invalid(val errors: Set<GoalDefinitionError>) : GoalTimelineResult {
        init {
            require(errors.isNotEmpty()) { "An invalid timeline has at least one error" }
        }
    }
}

/** A single goal as a timeline: one version from its start date, never ended. */
public fun GoalDefinition.asTimeline(): GoalTimeline =
    GoalTimeline(activePeriod.startDate, listOf(GoalVersion(activePeriod.startDate, settings)), paused, excused, null)

/**
 * A detail edit saved from [today] (fixture `goal_version_add`; decision 23):
 * - unchanged settings add nothing;
 * - a last version starting on or after [today] is replaced, and removed when the edit returns to the one before;
 * - otherwise a version from [today] is added;
 * - past [GoalTimeline.MAX_VERSIONS], the oldest folds into the next, which takes its `from`.
 */
public fun List<GoalVersion>.withEdit(settings: GoalSettings, today: LocalDate): List<GoalVersion> {
    val last = last()
    if (last.settings == settings) return this
    val edited = toMutableList()
    if (!last.from.isBefore(today)) {
        edited[edited.lastIndex] = GoalVersion(last.from, settings)
        if (edited.size >= 2 && edited[edited.lastIndex - 1].settings == settings) edited.removeAt(edited.lastIndex)
    } else {
        edited += GoalVersion(today, settings)
    }
    if (edited.size > GoalTimeline.MAX_VERSIONS) {
        val oldest = edited.removeAt(0)
        edited[0] = edited[0].copy(from = oldest.from)
    }
    return edited
}

/** [withEdit] on a whole timeline: the edited goal, or why the new settings are invalid. */
public fun GoalTimeline.withEdit(settings: GoalSettings, today: LocalDate): GoalTimelineResult =
    GoalTimeline.create(createdOn, versions.withEdit(settings, today), paused, excused, ended)
