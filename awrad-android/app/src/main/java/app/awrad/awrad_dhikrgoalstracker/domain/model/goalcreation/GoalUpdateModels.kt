package app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation

import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import java.time.LocalDate

data class UpdateGoalCountSetupCommand(
    val goalId: Long,
    val ruleMode: GoalCountRuleMode,
    val countPolicy: GoalCountPolicyUpdate = GoalCountPolicyUpdate(),
    val slotPolicies: List<GoalSlotCountPolicyUpdate> = emptyList(),
    val autoCompleteOnTarget: Boolean = false,
    val currentProgressCount: Long = 0L,
    val currentSlotCounts: Map<Long, Long> = emptyMap(),
)

enum class GoalCountRuleMode {
    Tracker,
    Minimum,
    Target,
    Stretch,
    Exact,
    Bounded,
}

data class GoalCountPolicyUpdate(
    val minimumCount: Int? = null,
    val targetCount: Int? = null,
    val maximumCount: Int? = null,
    val capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
)

data class GoalSlotCountPolicyUpdate(
    val slotId: Long,
    val countPolicy: GoalCountPolicyUpdate,
)

data class UpdateGoalScheduleCommand(
    val goalId: Long,
    val schedule: ScheduleSpec = ScheduleSpec.Daily,
    val timing: ScheduleTimingUpdate = ScheduleTimingUpdate.Anytime(),
    val archivedAtMillis: Long = System.currentTimeMillis(),
)

sealed class ScheduleTimingUpdate {
    data class Anytime(
        val slotId: Long? = null,
        val label: String? = null,
    ) : ScheduleTimingUpdate()

    data class PrayerBased(
        val slots: List<PrayerSlotUpdate>,
    ) : ScheduleTimingUpdate()

    data class TimeWindows(
        val windows: List<TimeWindowSlotUpdate>,
    ) : ScheduleTimingUpdate()
}

data class PrayerSlotUpdate(
    val slotId: Long? = null,
    val prayer: Prayer,
    val relation: PrayerRelation,
    val beforeLeadMinutes: Int? = null,
    val label: String? = null,
)

data class TimeWindowSlotUpdate(
    val slotId: Long? = null,
    val label: String,
    val startMinute: Int,
    val endMinute: Int,
)

data class UpdateGoalRemindersCommand(
    val goalId: Long,
    val reminders: List<GoalReminderUpdate> = emptyList(),
)

data class GoalReminderUpdate(
    val reminderId: Long? = null,
    val reminderType: ReminderType = ReminderType.FIXED_TIME,
    val slotId: Long? = null,
    val hour: Int? = null,
    val minute: Int? = null,
    val offsetMinutes: Int? = null,
    val enabled: Boolean = true,
)

class ValidatedGoalUpdate internal constructor(
    val goal: Goal,
    val warnings: List<GoalUpdateWarning> = emptyList(),
)

data class UpdatedGoal(
    val goal: Goal,
    val warnings: List<GoalUpdateWarning> = emptyList(),
)

sealed class GoalUpdateResult {
    data class Valid(val validatedGoalUpdate: ValidatedGoalUpdate) : GoalUpdateResult()
    data class Invalid(val errors: List<GoalUpdateError>) : GoalUpdateResult()
}

sealed class UpdateGoalCountSetupResult {
    data class Updated(val updatedGoal: UpdatedGoal) : UpdateGoalCountSetupResult()
    data class Invalid(val errors: List<GoalUpdateError>) : UpdateGoalCountSetupResult()
}

sealed class UpdateGoalScheduleResult {
    data class Updated(val updatedGoal: UpdatedGoal) : UpdateGoalScheduleResult()
    data class Invalid(val errors: List<GoalUpdateError>) : UpdateGoalScheduleResult()
}

sealed class UpdateGoalRemindersResult {
    data class Updated(val updatedGoal: UpdatedGoal) : UpdateGoalRemindersResult()
    data class Invalid(val errors: List<GoalUpdateError>) : UpdateGoalRemindersResult()
}

sealed class GoalUpdateError {
    data object GoalNotFound : GoalUpdateError()
    data object GoalIdMismatch : GoalUpdateError()
    data object InvalidSchedule : GoalUpdateError()
    data object InvalidTiming : GoalUpdateError()
    data object InvalidCountPolicy : GoalUpdateError()
    data object InvalidSlotPolicy : GoalUpdateError()
    data object MissingSlotPolicy : GoalUpdateError()
    data object UnknownSlotPolicy : GoalUpdateError()
    data object DuplicateSlotPolicy : GoalUpdateError()
    data object CannotRemoveLastSlot : GoalUpdateError()
    data object InvalidReminder : GoalUpdateError()
    data object DuplicateReminder : GoalUpdateError()
}

sealed class GoalUpdateWarning {
    data class ProgressAlreadyAboveMaximum(
        val currentCount: Long,
        val maximumCount: Int,
    ) : GoalUpdateWarning()

    data class SlotProgressAlreadyAboveMaximum(
        val slotId: Long,
        val currentCount: Long,
        val maximumCount: Int,
    ) : GoalUpdateWarning()
}
