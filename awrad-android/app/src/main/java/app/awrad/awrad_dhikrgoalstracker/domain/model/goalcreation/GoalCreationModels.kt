package app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation

import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.data.model.SlotCountingPolicy
import java.time.DayOfWeek
import java.time.LocalDate

data class CreateGoalCommand(
    val dhikrId: AwradId,
    val startDate: LocalDate,
    val schedule: ScheduleSpec = ScheduleSpec.Daily,
    val timing: TimingSpec = TimingSpec.Anytime,
    val slotCountingPolicy: SlotCountingPolicy = SlotCountingPolicy.WARN_AND_ALLOW,
    val countPolicy: CountPolicy = CountPolicy(targetCount = 100),
    val progressScope: ProgressScope = ProgressScope.DueDate,
    val completionPolicy: CompletionPolicy = CompletionPolicy.Never,
    val reminders: List<ReminderPolicy> = emptyList(),
    val durationDays: Int? = null,
)

sealed class ScheduleSpec {
    data object Daily : ScheduleSpec()
    data class Weekly(val weekdays: Set<DayOfWeek>) : ScheduleSpec()
    data class Monthly(
        val calendar: CalendarSystem = CalendarSystem.GREGORIAN,
        val daysOfMonth: Set<Int>,
    ) : ScheduleSpec()
    data class Interval(val intervalDays: Int, val anchorDate: LocalDate? = null) : ScheduleSpec()
    data class Yearly(
        val calendar: CalendarSystem = CalendarSystem.GREGORIAN,
        val month: Int,
        val daysOfMonth: Set<Int>,
    ) : ScheduleSpec()
    data class Season(val templateCode: SeasonTemplateCode) : ScheduleSpec()
    data class SpecificDates(val dates: Set<LocalDate>) : ScheduleSpec()
}

sealed class TimingSpec {
    data object Anytime : TimingSpec()
    data class PrayerBased(val slots: List<PrayerSlotSpec>) : TimingSpec()
    data class TimeWindows(val windows: List<TimeWindowSpec>) : TimingSpec()
}

data class PrayerSlotSpec(
    val prayer: Prayer,
    val relation: PrayerRelation,
    val countPolicy: CountPolicy = CountPolicy(),
    val beforeLeadMinutes: Int? = null,
    val label: String? = null,
)

data class TimeWindowSpec(
    val label: String,
    val startMinute: Int,
    val endMinute: Int,
    val countPolicy: CountPolicy = CountPolicy(),
)

enum class ProgressScope {
    DueDate,
    Period,
    Lifetime,
}

sealed class ReminderPolicy {
    data class FixedTime(val hour: Int, val minute: Int, val enabled: Boolean = true) : ReminderPolicy()
    data class PrayerOffset(val offsetMinutes: Int = 10, val enabled: Boolean = true) : ReminderPolicy()
    data class TimeWindowStart(val offsetMinutes: Int = 0, val enabled: Boolean = true) : ReminderPolicy()
}

@JvmInline
value class ValidatedGoal internal constructor(val goal: Goal)

data class CreatedGoal(
    val id: AwradId,
    val goal: Goal,
)

sealed class GoalCreationResult {
    data class Valid(val validatedGoal: ValidatedGoal) : GoalCreationResult()
    data class Invalid(val errors: List<GoalCreationError>) : GoalCreationResult()
}

sealed class CreateGoalResult {
    data class Created(val createdGoal: CreatedGoal) : CreateGoalResult()
    data class Invalid(val errors: List<GoalCreationError>) : CreateGoalResult()
}

sealed class GoalCreationError {
    data object InvalidDhikr : GoalCreationError()
    data object InvalidDuration : GoalCreationError()
    data object InvalidSchedule : GoalCreationError()
    data object InvalidTiming : GoalCreationError()
    data object MissingTarget : GoalCreationError()
    data object InvalidCountPolicy : GoalCreationError()
    data object InvalidReminder : GoalCreationError()
}
