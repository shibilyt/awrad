package app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation

import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSpecificDate
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.Threshold
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId

object GoalFactory {

    fun create(command: CreateGoalCommand): GoalCreationResult {
        val errors = validate(command)
        if (errors.isNotEmpty()) return GoalCreationResult.Invalid(errors)
        return GoalCreationResult.Valid(ValidatedGoal(command.toGoal()))
    }

    fun requireValid(command: CreateGoalCommand): ValidatedGoal {
        return when (val result = create(command)) {
            is GoalCreationResult.Valid -> result.validatedGoal
            is GoalCreationResult.Invalid -> error("Invalid goal command: ${result.errors}")
        }
    }

    private fun validate(command: CreateGoalCommand): List<GoalCreationError> {
        val errors = mutableListOf<GoalCreationError>()
        if (command.durationDays != null && command.durationDays <= 0) errors += GoalCreationError.InvalidDuration
        if (command.streakMinimumCount != null && command.streakMinimumCount <= 0) {
            errors += GoalCreationError.InvalidCountPolicy
        }
        if (!isValidSchedule(command.schedule)) errors += GoalCreationError.InvalidSchedule
        if (!isValidTiming(command)) errors += GoalCreationError.InvalidTiming
        if (!isValidCountPolicy(command.countPolicy, allowNoTarget = isTracker(command))) {
            errors += GoalCreationError.InvalidCountPolicy
        }
        if (!isTracker(command) && !command.hasPersistableTarget()) {
            errors += GoalCreationError.MissingTarget
        }
        if (command.reminders.any { !it.isValid() }) errors += GoalCreationError.InvalidReminder
        return errors.distinct()
    }

    private fun CreateGoalCommand.toGoal(): Goal {
        val goalId = newAwradId()
        val hasTarget = hasPersistableTarget()
        val targetPolicy = when {
            !hasTarget -> TargetPolicy.NONE
            progressScope == ProgressScope.Lifetime -> TargetPolicy.CUMULATIVE_TOTAL
            progressScope == ProgressScope.Period -> TargetPolicy.PERIOD_TOTAL
            else -> TargetPolicy.PER_DUE_DATE
        }
        val slots = timing.toSlots(goalId, targetPolicy, countPolicy, streakMinimumCount)
        return Goal(
            id = goalId,
            dhikrId = dhikrId,
            targetPolicy = targetPolicy,
            slotCountingPolicy = slotCountingPolicy,
            recurrence = schedule.toRecurrence(goalId, startDate),
            slots = slots,
            reminders = reminders.mapIndexed { index, policy -> policy.toReminder(goalId, index) },
            startDate = startDate,
            durationDays = durationDays,
            minimumStreakCount = streakMinimumCount ?: countPolicy.minimumCount,
            targetCount = countPolicy.targetCount,
            maximumCount = slots.aggregateMaximumCount(defaultMaximum = countPolicy.maximumCount),
            capBehavior = countPolicy.capBehavior.toDataCapBehavior(),
            streakThreshold = if (streakMinimumCount != null) Threshold.Minimum else countPolicy.streakThreshold,
            reminderThreshold = countPolicy.reminderThreshold,
            completionThreshold = countPolicy.completionThreshold,
            autoCompleteOnTarget = completionPolicy == CompletionPolicy.WhenTargetReached,
            completionPolicy = completionPolicy,
        )
    }

    private fun List<GoalSlot>.aggregateMaximumCount(defaultMaximum: Int?): Int? {
        if (size <= 1) return defaultMaximum
        val slotMaximums = mapNotNull { it.maximumCount }
        return if (slotMaximums.size == size) slotMaximums.sum() else defaultMaximum
    }

    private fun ScheduleSpec.toRecurrence(goalId: AwradId, startDate: java.time.LocalDate): GoalRecurrence =
        when (this) {
            ScheduleSpec.Daily -> GoalRecurrence(goalId = goalId, frequency = RecurrenceFrequency.DAILY)
            is ScheduleSpec.Weekly -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.WEEKLY,
                weekdays = weekdays,
            )
            is ScheduleSpec.Monthly -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.MONTHLY,
                calendar = calendar,
                monthDays = daysOfMonth,
            )
            is ScheduleSpec.Interval -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.INTERVAL,
                intervalDays = intervalDays,
                anchorDate = anchorDate ?: startDate,
            )
            is ScheduleSpec.Yearly -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.YEARLY,
                calendar = calendar,
                month = month,
                monthDays = daysOfMonth,
            )
            is ScheduleSpec.Season -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.SEASON,
                calendar = CalendarSystem.HIJRI,
                seasonTemplateCode = templateCode,
            )
            is ScheduleSpec.SpecificDates -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.SPECIFIC_DATES,
                specificDates = dates.map { GoalSpecificDate(date = it) }.toSet(),
            )
        }

    private fun TimingSpec.toSlots(
        goalId: AwradId,
        targetPolicy: TargetPolicy,
        defaultPolicy: CountPolicy,
        streakMinimumCount: Int?,
    ): List<GoalSlot> =
        when (this) {
            TimingSpec.Anytime -> listOf(
                GoalSlot(
                    // A tracker may still have a streak floor, but never a target.
                    // Keep that floor on the slot so counting reads the same local policy.
                    minimumCount = defaultPolicy.withStreakMinimum(streakMinimumCount).minimumCount,
                    goalId = goalId,
                    slotType = GoalSlotType.ANYTIME,
                    targetCount = defaultPolicy.targetForPersistence(targetPolicy),
                    maximumCount = defaultPolicy.maximumCount,
                    capBehavior = defaultPolicy.capBehavior.toDataCapBehavior(),
                    streakThreshold = defaultPolicy.withStreakMinimum(streakMinimumCount).streakThreshold,
                    reminderThreshold = defaultPolicy.reminderThreshold,
                    completionThreshold = defaultPolicy.completionThreshold,
                )
            )
            is TimingSpec.PrayerBased -> slots.mapIndexed { index, slot ->
                val policy = slot.countPolicy.withFallback(defaultPolicy).withStreakMinimum(streakMinimumCount)
                GoalSlot(
                    goalId = goalId,
                    slotType = GoalSlotType.PRAYER,
                    prayerName = slot.prayer,
                    prayerRelation = slot.relation,
                    startLeadMinutesOverride = slot.beforeLeadMinutes?.takeIf { slot.relation == PrayerRelation.BEFORE },
                    label = slot.label ?: slot.defaultLabel(),
                    minimumCount = policy.minimumCount,
                    targetCount = policy.targetForPersistence(targetPolicy),
                    maximumCount = policy.maximumCount,
                    capBehavior = policy.capBehavior.toDataCapBehavior(),
                    streakThreshold = policy.streakThreshold,
                    reminderThreshold = policy.reminderThreshold,
                    completionThreshold = policy.completionThreshold,
                    sortOrder = index,
                )
            }
            is TimingSpec.TimeWindows -> windows.mapIndexed { index, window ->
                val policy = window.countPolicy.withFallback(defaultPolicy).withStreakMinimum(streakMinimumCount)
                GoalSlot(
                    goalId = goalId,
                    slotType = GoalSlotType.TIME_WINDOW,
                    startMinute = window.startMinute,
                    endMinute = window.endMinute,
                    label = window.label,
                    minimumCount = policy.minimumCount,
                    targetCount = policy.targetForPersistence(targetPolicy),
                    maximumCount = policy.maximumCount,
                    capBehavior = policy.capBehavior.toDataCapBehavior(),
                    streakThreshold = policy.streakThreshold,
                    reminderThreshold = policy.reminderThreshold,
                    completionThreshold = policy.completionThreshold,
                    sortOrder = index,
                )
            }
        }

    private fun ReminderPolicy.toReminder(goalId: AwradId, sortOrder: Int): GoalReminder =
        when (this) {
            is ReminderPolicy.FixedTime -> GoalReminder(
                goalId = goalId,
                reminderType = ReminderType.FIXED_TIME,
                hour = hour,
                minute = minute,
                enabled = enabled,
                sortOrder = sortOrder,
            )
            is ReminderPolicy.PrayerOffset -> GoalReminder(
                goalId = goalId,
                reminderType = ReminderType.PRAYER_OFFSET,
                offsetMinutes = offsetMinutes,
                enabled = enabled,
                sortOrder = sortOrder,
            )
            is ReminderPolicy.TimeWindowStart -> GoalReminder(
                goalId = goalId,
                reminderType = ReminderType.TIME_WINDOW_START,
                offsetMinutes = offsetMinutes,
                enabled = enabled,
                sortOrder = sortOrder,
            )
        }

    private fun isValidSchedule(schedule: ScheduleSpec): Boolean =
        when (schedule) {
            ScheduleSpec.Daily -> true
            is ScheduleSpec.Weekly -> schedule.weekdays.isNotEmpty()
            is ScheduleSpec.Monthly -> schedule.daysOfMonth.isNotEmpty() && schedule.daysOfMonth.all { it in 1..31 }
            is ScheduleSpec.Interval -> schedule.intervalDays > 0
            is ScheduleSpec.Yearly -> schedule.month in 1..12 &&
                schedule.daysOfMonth.isNotEmpty() &&
                schedule.daysOfMonth.all { it in 1..31 }
            is ScheduleSpec.Season -> true
            is ScheduleSpec.SpecificDates -> schedule.dates.isNotEmpty()
        }

    private fun isValidTiming(command: CreateGoalCommand): Boolean =
        when (val timing = command.timing) {
            TimingSpec.Anytime -> true
            is TimingSpec.PrayerBased -> {
                timing.slots.isNotEmpty() &&
                    timing.slots.distinctBy { it.prayer to it.relation }.size == timing.slots.size &&
                    timing.slots.all { slot ->
                        (slot.beforeLeadMinutes == null || slot.beforeLeadMinutes >= 0) &&
                            isValidCountPolicy(slot.countPolicy.withFallback(command.countPolicy), allowNoTarget = isTracker(command))
                    }
            }
            is TimingSpec.TimeWindows -> {
                timing.windows.isNotEmpty() &&
                    timing.windows.all { window ->
                        window.label.isNotBlank() &&
                            window.startMinute in 0 until MINUTES_PER_DAY &&
                            window.endMinute in 1..MINUTES_PER_DAY &&
                            window.startMinute < window.endMinute &&
                            isValidCountPolicy(window.countPolicy.withFallback(command.countPolicy), allowNoTarget = isTracker(command))
                    }
            }
        }

    private fun CountPolicy.withFallback(defaultPolicy: CountPolicy): CountPolicy {
        if (hasAnyCount) return this
        return copy(
            minimumCount = defaultPolicy.minimumCount,
            targetCount = defaultPolicy.targetCount,
            maximumCount = defaultPolicy.maximumCount,
            streakThreshold = defaultPolicy.streakThreshold,
            reminderThreshold = defaultPolicy.reminderThreshold,
            completionThreshold = defaultPolicy.completionThreshold,
            capBehavior = defaultPolicy.capBehavior,
        )
    }

    private fun CountPolicy.withStreakMinimum(streakMinimumCount: Int?): CountPolicy {
        if (streakMinimumCount == null || minimumCount != null) return this
        return copy(
            minimumCount = streakMinimumCount,
            streakThreshold = Threshold.Minimum,
        )
    }

    private fun CountPolicy.targetForPersistence(targetPolicy: TargetPolicy): Int? =
        if (targetPolicy == TargetPolicy.NONE) null else effectiveTargetCount

    private fun CapBehavior.toDataCapBehavior(): CountCapBehavior =
        when (this) {
            CapBehavior.AllowOverTarget -> CountCapBehavior.AllowOverTarget
            CapBehavior.WarnOverTarget -> CountCapBehavior.WarnOverTarget
            CapBehavior.BlockAtTarget -> CountCapBehavior.BlockAtTarget
            CapBehavior.BlockAtMaximum -> CountCapBehavior.BlockAtMaximum
        }

    private fun isValidCountPolicy(policy: CountPolicy, allowNoTarget: Boolean): Boolean {
        val counts = listOfNotNull(policy.minimumCount, policy.targetCount, policy.maximumCount)
        if (counts.any { it <= 0 }) return false
        if (policy.minimumCount != null && policy.targetCount != null && policy.minimumCount > policy.targetCount) return false
        if (policy.targetCount != null && policy.maximumCount != null && policy.targetCount > policy.maximumCount) return false
        if (policy.minimumCount != null && policy.maximumCount != null && policy.minimumCount > policy.maximumCount) return false
        if (!allowNoTarget && policy.effectiveTargetCount == null) return false
        if (policy.capBehavior == CapBehavior.BlockAtTarget && policy.targetCount == null) return false
        if (policy.capBehavior == CapBehavior.BlockAtMaximum && policy.maximumCount == null) return false
        return listOf(policy.streakThreshold, policy.reminderThreshold, policy.completionThreshold)
            .all { threshold -> threshold.isValidFor(policy, allowNoTarget) }
    }

    private fun Threshold.isValidFor(policy: CountPolicy, allowNoTarget: Boolean): Boolean =
        when (this) {
            Threshold.AnyPositive -> true
            Threshold.Minimum -> policy.minimumCount != null
            Threshold.Target -> policy.targetCount != null || (allowNoTarget && !policy.hasAnyCount)
            Threshold.Maximum -> policy.maximumCount != null
            is Threshold.Custom -> count > 0
        }

    private fun CreateGoalCommand.hasPersistableTarget(): Boolean =
        countPolicy.effectiveTargetCount != null ||
            when (val timing = timing) {
                TimingSpec.Anytime -> false
                is TimingSpec.PrayerBased -> timing.slots.any { it.countPolicy.withFallback(countPolicy).effectiveTargetCount != null }
                is TimingSpec.TimeWindows -> timing.windows.any { it.countPolicy.withFallback(countPolicy).effectiveTargetCount != null }
            }

    private fun isTracker(command: CreateGoalCommand): Boolean =
        command.progressScope == ProgressScope.DueDate &&
            command.completionPolicy == CompletionPolicy.Never &&
            !command.hasPersistableTarget()

    private fun ReminderPolicy.isValid(): Boolean =
        when (this) {
            is ReminderPolicy.FixedTime -> hour in 0..23 && minute in 0..59
            is ReminderPolicy.PrayerOffset -> offsetMinutes >= 0
            is ReminderPolicy.TimeWindowStart -> offsetMinutes >= 0
        }

    private fun PrayerSlotSpec.defaultLabel(): String =
        "${relation.displayName()} ${prayer.displayName()}"

    private fun PrayerRelation.displayName(): String = when (this) {
        PrayerRelation.BEFORE -> "Before"
        PrayerRelation.AFTER -> "After"
    }

    private fun Prayer.displayName(): String = name.lowercase().replaceFirstChar { it.uppercase() }

    private const val MINUTES_PER_DAY = 24 * 60
}
