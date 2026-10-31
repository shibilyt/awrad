package app.awrad.core.domain.goal

import java.time.LocalDate

/** Why a goal or goal document can't be built: `contracts/goal-model/v1/fixtures/goal_validity.json`'s codes. */
public enum class GoalDefinitionError {
    /** Both an end date and a number of days. */
    END_DATE_AND_DURATION,

    /** A document's first version doesn't start on its `created_on`. */
    FIRST_VERSION_NOT_CREATED_ON,

    /** A make-up window on a goal that isn't per due date, or a total counting at an amount with `fill: streak`. */
    MAKE_UP_NOT_ALLOWED,

    /** Two sessions with one ID. */
    SESSION_DUPLICATE,

    /** A session ID that isn't derived from its kind. */
    SESSION_ID_MISMATCH,

    /** A goal with sessions, other than a tracker, has a session without a target. */
    SESSION_TARGET_REQUIRED,

    /** A `between` window from a time to the same time. */
    SESSION_WINDOW_EMPTY,

    /** Sessions together with a minimum or cap on the goal. */
    SESSIONS_WITH_MINIMUM_OR_CAP,

    /** `daily_pace` on anything but a total with an end. */
    STREAK_PACE_NOT_ALLOWED,

    /** A streak threshold of minimum, target or maximum points at a value that isn't set. */
    STREAK_THRESHOLD_VALUE_REQUIRED,

    /** A document's versions disagree on a structural field. */
    STRUCTURAL_CHANGE,

    /** A goal without sessions, other than a tracker, has no target. */
    TARGET_REQUIRED,

    /** A document's version `from` days aren't strictly increasing. */
    VERSIONS_OUT_OF_ORDER,
}

/** The outcome of [GoalDefinition.create]: the goal, or every reason it's invalid. */
public sealed interface GoalDefinitionResult {
    public data class Valid(val definition: GoalDefinition) : GoalDefinitionResult

    public data class Invalid(val errors: Set<GoalDefinitionError>) : GoalDefinitionResult {
        init {
            require(errors.isNotEmpty()) { "An invalid goal has at least one error" }
        }
    }
}

/** The validity rules of the schema's `goal_rules`, plus session IDs and windows (README.md, "Validity"). */
internal fun GoalSettings.validityErrors(): Set<GoalDefinitionError> = buildSet {
    val isTracker = requirement == Requirement.Tracker
    if (sessions.isEmpty()) {
        if (!countPolicy.hasStreakThresholdValue) add(GoalDefinitionError.STREAK_THRESHOLD_VALUE_REQUIRED)
        if (!isTracker && countPolicy.target == null) add(GoalDefinitionError.TARGET_REQUIRED)
    } else {
        addAll(sessionErrors(isTracker))
    }
    addAll(endAndStreakErrors())
}

private fun GoalSettings.endAndStreakErrors(): Set<GoalDefinitionError> = buildSet {
    val endDate = activePeriod.endDate
    val durationDays = activePeriod.durationDays
    if (endDate != null && durationDays != null) add(GoalDefinitionError.END_DATE_AND_DURATION)
    if (makeUp.window != MakeUpWindow.OFF && !allowsMakeUp) add(GoalDefinitionError.MAKE_UP_NOT_ALLOWED)
    val paceAllowed = requirement == Requirement.CumulativeTotal && (endDate != null || durationDays != null)
    if (countPolicy.streakThreshold == StreakThreshold.DailyPace && !paceAllowed) {
        add(GoalDefinitionError.STREAK_PACE_NOT_ALLOWED)
    }
}

private fun GoalSettings.sessionErrors(isTracker: Boolean): Set<GoalDefinitionError> = buildSet {
    sessions.forEach { session ->
        if (!isTracker && session.target == null) add(GoalDefinitionError.SESSION_TARGET_REQUIRED)
        if (session.id != session.kind.derivedId) add(GoalDefinitionError.SESSION_ID_MISMATCH)
        val kind = session.kind
        if (kind is SessionKind.Between && kind.from == kind.to) add(GoalDefinitionError.SESSION_WINDOW_EMPTY)
    }
    if (countPolicy.minimum != null || countPolicy.maximum != null) {
        add(GoalDefinitionError.SESSIONS_WITH_MINIMUM_OR_CAP)
    }
    if (sessions.map { it.id }.toSet().size != sessions.size) add(GoalDefinitionError.SESSION_DUPLICATE)
}

/** Make-up is for daily goals, and for totals whose streak counts at a daily amount, filled to it (decision 48). */
private val GoalSettings.allowsMakeUp: Boolean
    get() = requirement == Requirement.PerDueDate ||
        requirement == Requirement.CumulativeTotal &&
        countPolicy.streakThreshold is StreakThreshold.Amount &&
        makeUp.fill == MakeUpFill.STREAK

/** Every version's errors plus the document's own: versions in order from [createdOn], structural fields equal. */
internal fun timelineErrors(createdOn: LocalDate, versions: List<GoalVersion>): Set<GoalDefinitionError> = buildSet {
    versions.forEach { addAll(it.settings.validityErrors()) }
    if (versions.zipWithNext().any { (earlier, later) -> !later.from.isAfter(earlier.from) }) {
        add(GoalDefinitionError.VERSIONS_OUT_OF_ORDER)
    }
    if (versions.first().from != createdOn) add(GoalDefinitionError.FIRST_VERSION_NOT_CREATED_ON)
    val structure = versions.first().settings.structure
    if (versions.any { it.settings.structure != structure }) add(GoalDefinitionError.STRUCTURAL_CHANGE)
}

/** What can't change between versions (decision 23): changing it ends the goal and starts a new one. */
private data class Structure(
    val schedule: Class<out Schedule>,
    val calendar: CalendarSystem?,
    val requirement: Class<out Requirement>,
    val period: CalendarPeriod?,
    val startDate: LocalDate,
)

private val GoalSettings.structure: Structure
    get() = Structure(
        schedule = schedule.javaClass,
        calendar = (schedule as? Schedule.Yearly)?.calendar,
        requirement = requirement.javaClass,
        period = when (val requirement = requirement) {
            is Requirement.PeriodTotal -> requirement.period
            is Requirement.DaysPerPeriod -> requirement.period
            else -> null
        },
        startDate = activePeriod.startDate,
    )
