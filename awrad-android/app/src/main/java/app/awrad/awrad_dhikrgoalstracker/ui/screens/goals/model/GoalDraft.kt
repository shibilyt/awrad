package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model

import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSpecificDate
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.Threshold
import app.awrad.awrad_dhikrgoalstracker.data.model.TimingType
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CapBehavior
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CompletionPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CountPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CreateGoalCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalCreationResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalFactory
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.PrayerSlotSpec
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ProgressScope
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ReminderPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ScheduleSpec
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.TimeWindowSpec
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.TimingSpec
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.PrayerTiming
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOrNull
import java.time.DayOfWeek
import java.time.LocalDate
import java.util.UUID

data class GoalTimeSlotDraft(
    val id: String = UUID.randomUUID().toString(),
    val label: String = "Session 1",
    val startHour: Int = 8,
    val startMinute: Int = 0,
    val durationMinutes: Int = 60,
    val mode: CountRuleMode = CountRuleMode.Target,
    val minimumCount: String = "",
    val targetCount: String = "100",
    val maximumCount: String = "",
    val capBehavior: CapBehavior = CapBehavior.AllowOverTarget,
) {
    val startMinuteOfDay: Int
        get() = startHour.coerceIn(0, 23) * 60 + startMinute.coerceIn(0, 59)

    val endMinuteOfDay: Int
        get() = (startMinuteOfDay + durationMinutes.coerceAtLeast(0)).coerceAtMost(24 * 60)

    val timeRangeText: String
        get() = "${startMinuteOfDay.toClockText()}-${endMinuteOfDay.toClockText()}"

    fun displayLabel(fallbackIndex: Int): String =
        label.trim().ifBlank { "Session $fallbackIndex" }.asSessionLabel()
}

private fun String.asSessionLabel(): String =
    replace(Regex("^Slot(\\s+\\d+)$", RegexOption.IGNORE_CASE), "Session$1")

enum class CountRuleMode {
    Tracker,
    Minimum,
    Target,
    Stretch,
    Exact,
    Bounded,
}

data class CountRuleDraft(
    val mode: CountRuleMode = CountRuleMode.Target,
    val minimumCount: String = "",
    val targetCount: String = "100",
    val maximumCount: String = "",
    val capBehavior: CapBehavior = CapBehavior.AllowOverTarget,
) {
    val usesMinimum: Boolean get() = mode == CountRuleMode.Minimum || mode == CountRuleMode.Stretch || mode == CountRuleMode.Bounded
    val usesTarget: Boolean get() = mode == CountRuleMode.Target || mode == CountRuleMode.Stretch || mode == CountRuleMode.Bounded
    val usesMaximum: Boolean get() = mode == CountRuleMode.Exact || mode == CountRuleMode.Bounded

    fun countForPersistence(): String =
        when (mode) {
            CountRuleMode.Tracker -> ""
            CountRuleMode.Minimum -> minimumCount
            CountRuleMode.Target,
            CountRuleMode.Stretch,
            CountRuleMode.Bounded -> targetCount
            CountRuleMode.Exact -> maximumCount
        }

    companion object {
        fun tracker(): CountRuleDraft = CountRuleDraft(mode = CountRuleMode.Tracker, targetCount = "")
        fun target(count: String): CountRuleDraft = CountRuleDraft(mode = CountRuleMode.Target, targetCount = count)
    }
}

fun CountRuleDraft.syncedWithTargetDraft(targetDraft: TargetDraft): CountRuleDraft =
    when (targetDraft) {
        TargetDraft.None -> copy(mode = CountRuleMode.Tracker)
        is TargetDraft.Fixed -> CountRuleDraft.target(targetDraft.count).copy(capBehavior = capBehavior)
        is TargetDraft.PrayerBased -> CountRuleDraft.target(targetDraft.uniformCount).copy(capBehavior = capBehavior)
    }

/** A per-session/per-bucket counting rule (mode + thresholds), expressed as a [CountRuleDraft]. */
fun GoalTimeSlotDraft.toCountRule(): CountRuleDraft =
    CountRuleDraft(mode, minimumCount, targetCount, maximumCount, capBehavior)

fun GoalTimeSlotDraft.withCountRule(rule: CountRuleDraft): GoalTimeSlotDraft =
    copy(
        mode = rule.mode,
        minimumCount = rule.minimumCount,
        targetCount = rule.targetCount,
        maximumCount = rule.maximumCount,
        capBehavior = rule.capBehavior,
    )

fun GoalDraft.morningRule(): CountRuleDraft =
    CountRuleDraft(morningMode, morningMinimumCount, morningTargetCount, morningMaximumCount, morningCapBehavior)

fun GoalDraft.withMorningRule(rule: CountRuleDraft): GoalDraft =
    copy(
        morningMode = rule.mode,
        morningMinimumCount = rule.minimumCount,
        morningTargetCount = rule.targetCount,
        morningMaximumCount = rule.maximumCount,
        morningCapBehavior = rule.capBehavior,
    )

fun GoalDraft.eveningRule(): CountRuleDraft =
    CountRuleDraft(eveningMode, eveningMinimumCount, eveningTargetCount, eveningMaximumCount, eveningCapBehavior)

fun GoalDraft.withEveningRule(rule: CountRuleDraft): GoalDraft =
    copy(
        eveningMode = rule.mode,
        eveningMinimumCount = rule.minimumCount,
        eveningTargetCount = rule.targetCount,
        eveningMaximumCount = rule.maximumCount,
        eveningCapBehavior = rule.capBehavior,
    )

data class GoalDraft(
    val preset: GoalPreset = GoalPreset.DAILY,
    val frequencyDraft: FrequencyDraft = FrequencyDraft.Daily,
    val timingType: TimingType = TimingType.ANYTIME,
    val advancedTiming: GoalTimingDraft = GoalTimingDraft.Anytime,
    val targetDraft: TargetDraft = TargetDraft.Fixed("100"),
    val countRule: CountRuleDraft = CountRuleDraft.target("100"),
    val slotTargetMode: SlotTargetMode = SlotTargetMode.Same,
    val morningMode: CountRuleMode = CountRuleMode.Target,
    val morningMinimumCount: String = "",
    val morningTargetCount: String = "100",
    val morningMaximumCount: String = "",
    val morningCapBehavior: CapBehavior = CapBehavior.AllowOverTarget,
    val eveningMode: CountRuleMode = CountRuleMode.Target,
    val eveningMinimumCount: String = "",
    val eveningTargetCount: String = "100",
    val eveningMaximumCount: String = "",
    val eveningCapBehavior: CapBehavior = CapBehavior.AllowOverTarget,
    val customTargetPolicy: TargetPolicy = TargetPolicy.PER_DUE_DATE,
    val timeSlots: List<GoalTimeSlotDraft> = listOf(GoalTimeSlotDraft()),
    val extras: ExtrasDraft = ExtrasDraft(),
)

enum class GoalTimingDraft {
    Anytime,
    PrayerBased,
    MorningEvening,
    CustomSlots,
}

enum class SlotTargetMode {
    Same,
    PerSlot,
}

enum class GoalDraftSection {
    Dhikr,
    Template,
    Target,
    Schedule,
    Slots,
    Reminders,
    Duration,
}

data class GoalValidationResult(
    val errors: Map<GoalDraftSection, GoalValidationMessage> = emptyMap(),
) {
    val isValid: Boolean get() = errors.isEmpty()
}

enum class GoalValidationMessage {
    SelectDhikr,
    ChooseTemplate,
    PositiveTotalTarget,
    PositiveSlotTarget,
    PositiveMinimumCount,
    PositiveExactCount,
    PositiveMaximumCount,
    TargetMustExceedMinimum,
    BoundedCountsOrdered,
    TrackerCannotHaveTarget,
    SelectWeekday,
    SelectMonthDay,
    SelectYearDay,
    AddDate,
    SelectSeason,
    PositiveInterval,
    AddSlot,
    SelectPrayer,
    AddTimeSlot,
    InvalidTimeWindow,
    InvalidPrayerSlot,
    InvalidReminderTime,
    PositiveDuration,
    PositiveMinimumStreak,
}

object GoalDraftDefaults {
    val curatedPresets: List<GoalPreset> = listOf(
        GoalPreset.DAILY,
        GoalPreset.PRAYER_BASED,
        GoalPreset.ONE_TIME,
        GoalPreset.WEEKLY,
        GoalPreset.ISLAMIC_SEASON,
        GoalPreset.MORNING_EVENING,
        GoalPreset.TRACKER,
        GoalPreset.CUSTOM,
    )

    fun forPreset(preset: GoalPreset): GoalDraft {
        return when (preset) {
            GoalPreset.DAILY -> GoalDraft(
                preset = preset,
                frequencyDraft = FrequencyDraft.Daily,
                timingType = TimingType.ANYTIME,
                advancedTiming = GoalTimingDraft.Anytime,
                targetDraft = TargetDraft.Fixed("100"),
                countRule = CountRuleDraft.target("100").copy(capBehavior = CapBehavior.BlockAtTarget),
                slotTargetMode = SlotTargetMode.PerSlot,
                timeSlots = defaultTimeSlots(targetCount = "100"),
                extras = ExtrasDraft(minStreakCount = "1"),
            )
            GoalPreset.PRAYER_BASED -> GoalDraft(
                preset = preset,
                frequencyDraft = FrequencyDraft.Daily,
                timingType = TimingType.PRAYER_BASED,
                advancedTiming = GoalTimingDraft.PrayerBased,
                targetDraft = TargetDraft.PrayerBased(
                    timing = PrayerTiming.AFTER,
                    selectedPrayers = Prayer.entries.toSet(),
                    uniformCount = "33",
                ),
                countRule = CountRuleDraft.target("33"),
                slotTargetMode = SlotTargetMode.PerSlot,
                timeSlots = defaultTimeSlots(targetCount = "33"),
                extras = ExtrasDraft(notificationEnabled = true),
            )
            GoalPreset.ONE_TIME -> GoalDraft(
                preset = preset,
                frequencyDraft = FrequencyDraft.Daily,
                timingType = TimingType.ANYTIME,
                advancedTiming = GoalTimingDraft.Anytime,
                targetDraft = TargetDraft.Fixed("70000"),
                countRule = CountRuleDraft.target("70000").copy(capBehavior = CapBehavior.BlockAtTarget),
                slotTargetMode = SlotTargetMode.Same,
                customTargetPolicy = TargetPolicy.CUMULATIVE_TOTAL,
                timeSlots = defaultTimeSlots(targetCount = "1000"),
                extras = ExtrasDraft(minStreakCount = "1"),
            )
            GoalPreset.WEEKLY -> GoalDraft(
                preset = preset,
                frequencyDraft = FrequencyDraft.Weekly(days = setOf(DayOfWeek.FRIDAY)),
                timingType = TimingType.ANYTIME,
                advancedTiming = GoalTimingDraft.Anytime,
                targetDraft = TargetDraft.Fixed("1000"),
                countRule = CountRuleDraft.target("1000"),
                slotTargetMode = SlotTargetMode.Same,
                customTargetPolicy = TargetPolicy.PERIOD_TOTAL,
                timeSlots = defaultTimeSlots(targetCount = "1000"),
            )
            GoalPreset.ISLAMIC_SEASON -> GoalDraft(
                preset = preset,
                frequencyDraft = FrequencyDraft.Season(SeasonTemplateCode.RAMADAN),
                timingType = TimingType.ANYTIME,
                advancedTiming = GoalTimingDraft.Anytime,
                targetDraft = TargetDraft.Fixed("10000"),
                countRule = CountRuleDraft.target("10000"),
                slotTargetMode = SlotTargetMode.Same,
                customTargetPolicy = TargetPolicy.PERIOD_TOTAL,
                timeSlots = defaultTimeSlots(targetCount = "10000"),
            )
            GoalPreset.MORNING_EVENING -> GoalDraft(
                preset = preset,
                frequencyDraft = FrequencyDraft.Daily,
                timingType = TimingType.TIME_BASED,
                advancedTiming = GoalTimingDraft.MorningEvening,
                targetDraft = TargetDraft.Fixed("100"),
                countRule = CountRuleDraft.target("100"),
                slotTargetMode = SlotTargetMode.PerSlot,
                morningTargetCount = "50",
                eveningTargetCount = "50",
                timeSlots = defaultTimeSlots(targetCount = "100"),
                extras = ExtrasDraft(notificationEnabled = true),
            )
            GoalPreset.TRACKER -> GoalDraft(
                preset = preset,
                frequencyDraft = FrequencyDraft.Daily,
                timingType = TimingType.ANYTIME,
                advancedTiming = GoalTimingDraft.Anytime,
                targetDraft = TargetDraft.None,
                countRule = CountRuleDraft.tracker(),
                slotTargetMode = SlotTargetMode.Same,
                customTargetPolicy = TargetPolicy.NONE,
                timeSlots = defaultTimeSlots(targetCount = ""),
                extras = ExtrasDraft(minStreakCount = "1"),
            )
            GoalPreset.CUSTOM -> GoalDraft(
                preset = preset,
                frequencyDraft = FrequencyDraft.Daily,
                timingType = TimingType.ANYTIME,
                advancedTiming = GoalTimingDraft.Anytime,
                targetDraft = TargetDraft.Fixed("33"),
                countRule = CountRuleDraft.target("33"),
                slotTargetMode = SlotTargetMode.Same,
                morningTargetCount = "33",
                eveningTargetCount = "33",
                timeSlots = defaultTimeSlots(targetCount = "33"),
            )
            else -> forPreset(GoalPreset.CUSTOM).copy(preset = preset)
        }
    }

    fun defaultTimeSlots(targetCount: String): List<GoalTimeSlotDraft> = listOf(
        GoalTimeSlotDraft(
            label = "Session 1",
            startHour = 8,
            startMinute = 0,
            durationMinutes = 60,
            targetCount = targetCount,
        )
    )
}

object GoalDraftMapper {

    fun effectiveTiming(draft: GoalDraft): GoalTimingDraft {
        if (draft.preset == GoalPreset.MORNING_EVENING && draft.timingType == TimingType.TIME_BASED) {
            return GoalTimingDraft.MorningEvening
        }
        if (draft.advancedTiming != GoalTimingDraft.Anytime || draft.timingType == TimingType.ANYTIME) {
            return draft.advancedTiming
        }
        return when (draft.timingType) {
            TimingType.ANYTIME -> GoalTimingDraft.Anytime
            TimingType.PRAYER_BASED -> GoalTimingDraft.PrayerBased
            TimingType.TIME_BASED -> GoalTimingDraft.CustomSlots
        }
    }

    fun targetPolicyFor(draft: GoalDraft): TargetPolicy {
        if (draft.countRule.mode == CountRuleMode.Tracker) return TargetPolicy.NONE
        return when (draft.preset) {
            GoalPreset.ONE_TIME -> TargetPolicy.CUMULATIVE_TOTAL
            GoalPreset.TRACKER, GoalPreset.ADV_TRACKER -> TargetPolicy.NONE
            GoalPreset.WEEKLY, GoalPreset.ISLAMIC_SEASON -> TargetPolicy.PERIOD_TOTAL
            GoalPreset.CUSTOM -> draft.customTargetPolicy
            else -> TargetPolicy.PER_DUE_DATE
        }
    }

    fun toGoal(dhikrId: AwradId, draft: GoalDraft, startDate: LocalDate): Goal {
        return when (val result = GoalFactory.create(toCommand(dhikrId, draft, startDate))) {
            is GoalCreationResult.Valid -> result.validatedGoal.goal
            is GoalCreationResult.Invalid -> error("Invalid goal draft: ${result.errors}")
        }
    }

    fun toCommand(dhikrId: AwradId, draft: GoalDraft, startDate: LocalDate): CreateGoalCommand {
        val targetPolicy = targetPolicyFor(draft)
        return CreateGoalCommand(
            dhikrId = dhikrId,
            startDate = startDate,
            schedule = scheduleSpecFor(draft, startDate),
            timing = timingSpecFor(draft),
            slotCountingPolicy = draft.extras.slotCountingPolicy,
            countPolicy = countPolicyFor(draft, targetPolicy),
            streakMinimumCount = streakMinimumCountFor(draft, targetPolicy),
            progressScope = progressScopeFor(targetPolicy),
            completionPolicy = if (targetPolicy == TargetPolicy.CUMULATIVE_TOTAL) {
                CompletionPolicy.WhenTargetReached
            } else {
                CompletionPolicy.Never
            },
            reminders = reminderPoliciesFor(draft),
            durationDays = draft.extras.durationDays.toIntOrNull()?.takeIf { draft.extras.hasDuration },
        )
    }

    fun validate(draft: GoalDraft?, hasDhikr: Boolean): GoalValidationResult {
        val errors = linkedMapOf<GoalDraftSection, GoalValidationMessage>()
        if (!hasDhikr) errors[GoalDraftSection.Dhikr] = GoalValidationMessage.SelectDhikr
        if (draft == null) {
            errors[GoalDraftSection.Template] = GoalValidationMessage.ChooseTemplate
            return GoalValidationResult(errors)
        }

        val recurrence = buildRecurrence(draft)
        val slots = buildSlots(draft)
        val slotRuleModes = slotModes(draft)
        val policy = targetPolicyFor(draft)

        // The global rule governs the single (Anytime) bucket; multi-bucket timings are
        // validated per-slot below using each slot's own mode.
        if (effectiveTiming(draft) == GoalTimingDraft.Anytime) {
            countRuleError(draft, policy)?.let { errors[GoalDraftSection.Target] = it }
        }
        if (!errors.containsKey(GoalDraftSection.Target) && policy != TargetPolicy.NONE && slots.any { (it.targetCount ?: 0) <= 0 }) {
            errors[GoalDraftSection.Target] = if (policy == TargetPolicy.CUMULATIVE_TOTAL) {
                GoalValidationMessage.PositiveTotalTarget
            } else {
                GoalValidationMessage.PositiveSlotTarget
            }
        }
        if (
            !errors.containsKey(GoalDraftSection.Target) &&
            policy != TargetPolicy.NONE &&
            draft.slotTargetMode == SlotTargetMode.PerSlot &&
            supportsPerSlotRules(draft)
        ) {
            val invalid = slots.filterIndexed { index, slot ->
                !slot.hasValidCountRule(slotRuleModes.getOrElse(index) { draft.countRule.mode })
            }
            if (invalid.isNotEmpty()) {
                val anyBounded = slots.filterIndexed { index, _ ->
                    slotRuleModes.getOrElse(index) { draft.countRule.mode } == CountRuleMode.Bounded
                }.any { it in invalid }
                errors[GoalDraftSection.Target] = if (anyBounded) {
                    GoalValidationMessage.BoundedCountsOrdered
                } else {
                    GoalValidationMessage.PositiveSlotTarget
                }
            }
        }
        if (
            (draft.preset == GoalPreset.TRACKER || draft.preset == GoalPreset.ADV_TRACKER) &&
            draft.countRule.mode != CountRuleMode.Tracker &&
            draft.targetDraft !is TargetDraft.None
        ) {
            errors[GoalDraftSection.Target] = GoalValidationMessage.TrackerCannotHaveTarget
        }

        when (recurrence.frequency) {
            RecurrenceFrequency.WEEKLY -> if (recurrence.weekdays.isEmpty()) errors[GoalDraftSection.Schedule] = GoalValidationMessage.SelectWeekday
            RecurrenceFrequency.MONTHLY -> if (recurrence.monthDays.isEmpty()) errors[GoalDraftSection.Schedule] = GoalValidationMessage.SelectMonthDay
            RecurrenceFrequency.YEARLY -> if (recurrence.monthDays.isEmpty()) errors[GoalDraftSection.Schedule] = GoalValidationMessage.SelectYearDay
            RecurrenceFrequency.SPECIFIC_DATES -> if (recurrence.specificDates.isEmpty()) errors[GoalDraftSection.Schedule] = GoalValidationMessage.AddDate
            RecurrenceFrequency.SEASON -> if (recurrence.seasonTemplateCode == null) errors[GoalDraftSection.Schedule] = GoalValidationMessage.SelectSeason
            RecurrenceFrequency.INTERVAL -> {
                val interval = (draft.frequencyDraft as? FrequencyDraft.Interval)?.intervalDays?.toIntOrNull() ?: 0
                if (interval <= 0) errors[GoalDraftSection.Schedule] = GoalValidationMessage.PositiveInterval
            }
            RecurrenceFrequency.DAILY -> Unit
        }

        if (slots.isEmpty()) errors[GoalDraftSection.Slots] = GoalValidationMessage.AddSlot
        val timing = effectiveTiming(draft)
        if (timing == GoalTimingDraft.PrayerBased) {
            val prayerDraft = draft.targetDraft as? TargetDraft.PrayerBased
            if (prayerDraft == null || prayerDraft.selectedPrayers.isEmpty()) {
                errors[GoalDraftSection.Slots] = GoalValidationMessage.SelectPrayer
            }
        }
        if (timing == GoalTimingDraft.CustomSlots && draft.timeSlots.isEmpty()) {
            errors[GoalDraftSection.Slots] = GoalValidationMessage.AddTimeSlot
        }
        if (slots.any { it.slotType == GoalSlotType.TIME_WINDOW && ((it.startMinute ?: 0) >= (it.endMinute ?: 0)) }) {
            errors[GoalDraftSection.Slots] = GoalValidationMessage.InvalidTimeWindow
        }
        if (slots.any { it.slotType == GoalSlotType.PRAYER && (it.prayerName == null || it.prayerRelation == null) }) {
            errors[GoalDraftSection.Slots] = GoalValidationMessage.InvalidPrayerSlot
        }
        if (draft.extras.notificationEnabled && timing == GoalTimingDraft.Anytime) {
            if (draft.extras.notificationHour !in 0..23 || draft.extras.notificationMinute !in 0..59) {
                errors[GoalDraftSection.Reminders] = GoalValidationMessage.InvalidReminderTime
            }
        }
        if (draft.extras.hasDuration && (draft.extras.durationDays.toIntOrNull() ?: 0) <= 0) {
            errors[GoalDraftSection.Duration] = GoalValidationMessage.PositiveDuration
        }
        if (draft.extras.hasMinStreak && (draft.extras.minStreakCount.toIntOrNull() ?: 0) <= 0) {
            errors[GoalDraftSection.Duration] = GoalValidationMessage.PositiveMinimumStreak
        }

        return GoalValidationResult(errors)
    }

    fun buildRecurrence(draft: GoalDraft, goalId: AwradId = newAwradId()): GoalRecurrence {
        return when (val frequency = draft.frequencyDraft) {
            FrequencyDraft.Daily -> GoalRecurrence(goalId = goalId, frequency = RecurrenceFrequency.DAILY)
            is FrequencyDraft.Weekly -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.WEEKLY,
                weekdays = frequency.days,
            )
            is FrequencyDraft.Monthly -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.MONTHLY,
                calendar = frequency.calendar.toCalendarSystem(),
                monthDays = frequency.daysOfMonth,
            )
            is FrequencyDraft.Interval -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.INTERVAL,
                intervalDays = frequency.intervalDays.toIntOrNull()?.coerceAtLeast(1),
            )
            is FrequencyDraft.Yearly -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.YEARLY,
                calendar = frequency.calendar.toCalendarSystem(),
                month = frequency.month,
                monthDays = frequency.days,
            )
            is FrequencyDraft.Season -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.SEASON,
                calendar = CalendarSystem.HIJRI,
                seasonTemplateCode = frequency.seasonTemplateCode,
            )
            is FrequencyDraft.SpecificDates -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.SPECIFIC_DATES,
                specificDates = parseSpecificDates(frequency.dateText)
                    .map { GoalSpecificDate(date = it) }
                    .toSet(),
            )
        }
    }

    fun buildSlots(draft: GoalDraft, goalId: AwradId = newAwradId()): List<GoalSlot> {
        val policy = targetPolicyFor(draft)
        return when (effectiveTiming(draft)) {
            GoalTimingDraft.Anytime -> {
                val countPolicy = countPolicyFor(draft, policy)
                listOf(GoalSlot(
                    goalId = goalId,
                    slotType = GoalSlotType.ANYTIME,
                    minimumCount = countPolicy.minimumCount,
                    targetCount = countPolicy.targetForSlotPersistence(policy),
                    maximumCount = countPolicy.maximumCount,
                    capBehavior = countPolicy.capBehavior.toDataCapBehavior(),
                ))
            }
            GoalTimingDraft.PrayerBased -> {
                val target = draft.targetDraft as? TargetDraft.PrayerBased ?: return emptyList()
                buildPrayerSlots(draft, target, policy, goalId)
            }
            GoalTimingDraft.MorningEvening -> buildMorningEveningSlots(draft, policy, goalId)
            GoalTimingDraft.CustomSlots -> buildCustomTimeSlots(draft, policy, goalId)
        }
    }

    /** The counting-rule mode for each slot, aligned 1:1 (and in order) with [buildSlots]. */
    private fun slotModes(draft: GoalDraft): List<CountRuleMode> =
        when (effectiveTiming(draft)) {
            GoalTimingDraft.Anytime -> listOf(draft.countRule.mode)
            GoalTimingDraft.PrayerBased -> {
                val target = draft.targetDraft as? TargetDraft.PrayerBased ?: return emptyList()
                val relationCount = if (target.timing == PrayerTiming.BOTH) 2 else 1
                List(target.selectedPrayers.size * relationCount) { draft.countRule.mode }
            }
            GoalTimingDraft.MorningEvening -> listOf(draft.morningMode, draft.eveningMode)
            GoalTimingDraft.CustomSlots -> draft.timeSlots.map { it.mode }
        }

    fun buildReminders(draft: GoalDraft, goalId: AwradId = newAwradId()): List<GoalReminder> {
        if (!draft.extras.notificationEnabled) return emptyList()
        return when (effectiveTiming(draft)) {
            GoalTimingDraft.PrayerBased -> listOf(
                GoalReminder(
                    goalId = goalId,
                    reminderType = ReminderType.PRAYER_OFFSET,
                    offsetMinutes = 10,
                    enabled = true,
                )
            )
            GoalTimingDraft.MorningEvening,
            GoalTimingDraft.CustomSlots -> listOf(
                GoalReminder(
                    goalId = goalId,
                    reminderType = ReminderType.TIME_WINDOW_START,
                    offsetMinutes = 0,
                    enabled = true,
                )
            )
            GoalTimingDraft.Anytime -> listOf(
                GoalReminder(
                    goalId = goalId,
                    reminderType = ReminderType.FIXED_TIME,
                    hour = draft.extras.notificationHour,
                    minute = draft.extras.notificationMinute,
                    enabled = true,
                )
            )
        }
    }

    private fun buildMorningEveningSlots(draft: GoalDraft, policy: TargetPolicy, goalId: AwradId): List<GoalSlot> {
        val sharedPolicy = countPolicyFor(draft, policy)
        val count = sharedPolicy.targetCount
        val morningPolicy = when {
            policy == TargetPolicy.NONE -> CountPolicy()
            draft.slotTargetMode == SlotTargetMode.PerSlot && supportsPerSlotRules(draft) -> slotCountPolicyFor(
                mode = draft.morningMode,
                minimum = draft.morningMinimumCount.ifBlank { draft.countRule.minimumCount },
                target = draft.morningTargetCount.ifBlank { draft.countRule.targetCount },
                maximum = draft.morningMaximumCount.ifBlank { draft.countRule.maximumCount },
                capBehavior = draft.morningCapBehavior,
            )
            draft.preset == GoalPreset.MORNING_EVENING && draft.countRule.mode == CountRuleMode.Target -> {
                CountPolicy(targetCount = count?.let { (it / 2).coerceAtLeast(1) })
            }
            else -> sharedPolicy
        }
        val eveningPolicy = when {
            policy == TargetPolicy.NONE -> CountPolicy()
            draft.slotTargetMode == SlotTargetMode.PerSlot && supportsPerSlotRules(draft) -> slotCountPolicyFor(
                mode = draft.eveningMode,
                minimum = draft.eveningMinimumCount.ifBlank { draft.countRule.minimumCount },
                target = draft.eveningTargetCount.ifBlank { draft.countRule.targetCount },
                maximum = draft.eveningMaximumCount.ifBlank { draft.countRule.maximumCount },
                capBehavior = draft.eveningCapBehavior,
            )
            draft.preset == GoalPreset.MORNING_EVENING && draft.countRule.mode == CountRuleMode.Target -> {
                CountPolicy(targetCount = count?.let { (it - (it / 2).coerceAtLeast(1)).coerceAtLeast(1) })
            }
            else -> sharedPolicy
        }
        return listOf(
            GoalSlot(
                goalId = goalId,
                slotType = GoalSlotType.TIME_WINDOW,
                startMinute = 5 * 60,
                endMinute = 11 * 60,
                label = "Morning",
                minimumCount = morningPolicy.minimumCount,
                targetCount = morningPolicy.targetForSlotPersistence(policy),
                maximumCount = morningPolicy.maximumCount,
                capBehavior = morningPolicy.capBehavior.toDataCapBehavior(),
                sortOrder = 0,
            ),
            GoalSlot(
                goalId = goalId,
                slotType = GoalSlotType.TIME_WINDOW,
                startMinute = 17 * 60,
                endMinute = 22 * 60,
                label = "Evening",
                minimumCount = eveningPolicy.minimumCount,
                targetCount = eveningPolicy.targetForSlotPersistence(policy),
                maximumCount = eveningPolicy.maximumCount,
                capBehavior = eveningPolicy.capBehavior.toDataCapBehavior(),
                sortOrder = 1,
            ),
        )
    }

    private fun buildCustomTimeSlots(draft: GoalDraft, policy: TargetPolicy, goalId: AwradId): List<GoalSlot> {
        val sharedPolicy = if (draft.slotTargetMode == SlotTargetMode.Same || !supportsPerSlotRules(draft)) {
            countPolicyFor(draft, policy)
        } else {
            null
        }
        return draft.timeSlots.mapIndexed { index, slot ->
            val slotPolicy = when {
                policy == TargetPolicy.NONE -> CountPolicy()
                sharedPolicy != null -> sharedPolicy
                else -> slotCountPolicyFor(
                    mode = slot.mode,
                    minimum = slot.minimumCount.ifBlank { draft.countRule.minimumCount },
                    target = slot.targetCount.ifBlank { draft.countRule.targetCount },
                    maximum = slot.maximumCount.ifBlank { draft.countRule.maximumCount },
                    capBehavior = slot.capBehavior,
                )
            }
            GoalSlot(
                goalId = goalId,
                slotType = GoalSlotType.TIME_WINDOW,
                startMinute = slot.startMinuteOfDay,
                endMinute = slot.endMinuteOfDay,
                label = slot.displayLabel(index + 1),
                minimumCount = slotPolicy.minimumCount,
                targetCount = slotPolicy.targetForSlotPersistence(policy),
                maximumCount = slotPolicy.maximumCount,
                capBehavior = slotPolicy.capBehavior.toDataCapBehavior(),
                sortOrder = index,
            )
        }
    }

    private fun buildPrayerSlots(
        draft: GoalDraft,
        target: TargetDraft.PrayerBased,
        policy: TargetPolicy,
        goalId: AwradId,
    ): List<GoalSlot> {
        val relations = when (target.timing) {
            PrayerTiming.BEFORE -> listOf(PrayerRelation.BEFORE)
            PrayerTiming.AFTER -> listOf(PrayerRelation.AFTER)
            PrayerTiming.BOTH -> listOf(PrayerRelation.BEFORE, PrayerRelation.AFTER)
        }
        var sortOrder = 0
        val sharedPolicy = countPolicyFor(draft, policy)
        return Prayer.entries
            .filter { it in target.selectedPrayers }
            .flatMap { prayer ->
                relations.map { relation ->
                    val fallbackMinimum = draft.countRule.minimumCount
                    val fallbackTarget = target.countFor(prayer, relation).ifBlank { draft.countRule.targetCount }
                    val fallbackMaximum = draft.countRule.maximumCount.ifBlank { fallbackTarget }
                    val slotPolicy = when {
                        policy == TargetPolicy.NONE -> CountPolicy()
                        draft.slotTargetMode == SlotTargetMode.PerSlot && supportsPerSlotRules(draft) -> slotCountPolicyFor(
                            mode = draft.countRule.mode,
                            minimum = target.minimumFor(prayer, relation, fallbackMinimum),
                            target = fallbackTarget,
                            maximum = target.maximumFor(prayer, relation, fallbackMaximum),
                            capBehavior = target.capBehaviorFor(prayer, relation, draft.countRule.capBehavior),
                        )
                        else -> sharedPolicy
                    }
                    GoalSlot(
                        goalId = goalId,
                        slotType = GoalSlotType.PRAYER,
                        prayerName = prayer,
                        prayerRelation = relation,
                        label = "${relation.name.lowercase().replaceFirstChar { it.uppercase() }} ${prayer.displayName()}",
                        minimumCount = slotPolicy.minimumCount,
                        targetCount = slotPolicy.targetForSlotPersistence(policy),
                        maximumCount = slotPolicy.maximumCount,
                        capBehavior = slotPolicy.capBehavior.toDataCapBehavior(),
                        startLeadMinutesOverride = if (relation == PrayerRelation.BEFORE) {
                            target.beforePrayerLeadOverrides[prayer]
                                ?.toIntOrNull()
                                ?.coerceAtLeast(0)
                        } else {
                            null
                        },
                        sortOrder = sortOrder++,
                    )
                }
            }
    }

    private fun fixedTargetFor(draft: GoalDraft, policy: TargetPolicy): Int? {
        if (policy == TargetPolicy.NONE) return null
        return when (draft.countRule.mode) {
            CountRuleMode.Tracker -> null
            CountRuleMode.Minimum -> positiveInt(draft.countRule.minimumCount)
            CountRuleMode.Stretch -> positiveInt(draft.countRule.targetCount)
            CountRuleMode.Exact -> positiveInt(draft.countRule.maximumCount)
            CountRuleMode.Bounded -> positiveInt(draft.countRule.targetCount)
            CountRuleMode.Target -> when (val target = draft.targetDraft) {
                is TargetDraft.Fixed -> positiveInt(target.count)
                is TargetDraft.PrayerBased -> positiveInt(target.uniformCount)
                TargetDraft.None -> positiveInt(draft.countRule.targetCount)
            }
        }
    }

    private fun scheduleSpecFor(draft: GoalDraft, startDate: LocalDate): ScheduleSpec {
        // A quick one-time goal is a single anchored occurrence. If the user opts into
        // a daily streak, the existing daily draft frequency becomes intentional.
        if (draft.preset == GoalPreset.ONE_TIME && !draft.extras.hasMinStreak) {
            return ScheduleSpec.SpecificDates(setOf(startDate))
        }
        return when (val frequency = draft.frequencyDraft) {
            FrequencyDraft.Daily -> ScheduleSpec.Daily
            is FrequencyDraft.Weekly -> ScheduleSpec.Weekly(frequency.days)
            is FrequencyDraft.Monthly -> ScheduleSpec.Monthly(
                calendar = frequency.calendar.toCalendarSystem(),
                daysOfMonth = frequency.daysOfMonth,
            )
            is FrequencyDraft.Interval -> ScheduleSpec.Interval(
                intervalDays = frequency.intervalDays.toIntOrNull() ?: 0,
            )
            is FrequencyDraft.Yearly -> ScheduleSpec.Yearly(
                calendar = frequency.calendar.toCalendarSystem(),
                month = frequency.month,
                daysOfMonth = frequency.days,
            )
            is FrequencyDraft.Season -> ScheduleSpec.Season(frequency.seasonTemplateCode)
            is FrequencyDraft.SpecificDates -> ScheduleSpec.SpecificDates(
                dates = parseSpecificDates(frequency.dateText).toSet(),
            )
        }
    }

    private fun timingSpecFor(draft: GoalDraft): TimingSpec {
        val slots = buildSlots(draft)
        val modes = slotModes(draft)
        fun modeFor(index: Int): CountRuleMode = modes.getOrElse(index) { draft.countRule.mode }
        return when (effectiveTiming(draft)) {
            GoalTimingDraft.Anytime -> TimingSpec.Anytime
            GoalTimingDraft.PrayerBased -> TimingSpec.PrayerBased(
                slots = slots.mapIndexedNotNull { index, slot ->
                    val prayer = slot.prayerName ?: return@mapIndexedNotNull null
                    val relation = slot.prayerRelation ?: return@mapIndexedNotNull null
                    PrayerSlotSpec(
                        prayer = prayer,
                        relation = relation,
                        countPolicy = slot.countPolicy(modeFor(index)),
                        beforeLeadMinutes = slot.startLeadMinutesOverride,
                        label = slot.label,
                    )
                }
            )
            GoalTimingDraft.MorningEvening,
            GoalTimingDraft.CustomSlots -> TimingSpec.TimeWindows(
                windows = slots.mapIndexedNotNull { index, slot ->
                    val start = slot.startMinute ?: return@mapIndexedNotNull null
                    val end = slot.endMinute ?: return@mapIndexedNotNull null
                    TimeWindowSpec(
                        label = slot.label.orEmpty().ifBlank { "Session ${slot.sortOrder + 1}" }.asSessionLabel(),
                        startMinute = start,
                        endMinute = end,
                        countPolicy = slot.countPolicy(modeFor(index)),
                    )
                }
            )
        }
    }

    private fun countPolicyFor(draft: GoalDraft, targetPolicy: TargetPolicy): CountPolicy {
        if (targetPolicy == TargetPolicy.NONE || draft.countRule.mode == CountRuleMode.Tracker) {
            return CountPolicy(
                streakThreshold = Threshold.AnyPositive,
                reminderThreshold = Threshold.AnyPositive,
                completionThreshold = Threshold.AnyPositive,
            )
        }
        val minimum = if (draft.extras.hasMinStreak) {
            positiveInt(draft.extras.minStreakCount)
        } else {
            null
        }
        return when (draft.countRule.mode) {
            CountRuleMode.Minimum -> CountPolicy(
                minimumCount = positiveInt(draft.countRule.minimumCount),
                streakThreshold = Threshold.Minimum,
                reminderThreshold = Threshold.Minimum,
                completionThreshold = Threshold.Minimum,
            )
            CountRuleMode.Stretch -> CountPolicy(
                minimumCount = positiveInt(draft.countRule.minimumCount),
                targetCount = positiveInt(draft.countRule.targetCount),
                streakThreshold = Threshold.Minimum,
                reminderThreshold = Threshold.Target,
                completionThreshold = Threshold.Target,
            )
            CountRuleMode.Exact -> {
                val count = positiveInt(draft.countRule.maximumCount)
                CountPolicy(
                    targetCount = count,
                    maximumCount = count,
                    streakThreshold = Threshold.Target,
                    reminderThreshold = Threshold.Target,
                    completionThreshold = Threshold.Target,
                    capBehavior = CapBehavior.BlockAtMaximum,
                )
            }
            CountRuleMode.Bounded -> CountPolicy(
                minimumCount = positiveInt(draft.countRule.minimumCount),
                targetCount = positiveInt(draft.countRule.targetCount),
                maximumCount = positiveInt(draft.countRule.maximumCount),
                streakThreshold = Threshold.Minimum,
                reminderThreshold = Threshold.Target,
                completionThreshold = Threshold.Target,
                capBehavior = draft.countRule.capBehavior,
            )
            CountRuleMode.Target -> CountPolicy(
                minimumCount = minimum,
                targetCount = fixedTargetFor(draft, targetPolicy),
                streakThreshold = if (minimum != null) Threshold.Minimum else Threshold.Target,
                reminderThreshold = Threshold.Target,
                completionThreshold = Threshold.Target,
                capBehavior = draft.countRule.capBehavior,
            )
            CountRuleMode.Tracker -> CountPolicy(
                streakThreshold = Threshold.AnyPositive,
                reminderThreshold = Threshold.AnyPositive,
                completionThreshold = Threshold.AnyPositive,
            )
        }
    }

    /** Keeps a tracker targetless while allowing its daily activity to protect a streak. */
    private fun streakMinimumCountFor(draft: GoalDraft, targetPolicy: TargetPolicy): Int? =
        if (targetPolicy == TargetPolicy.NONE && draft.extras.hasMinStreak) {
            positiveInt(draft.extras.minStreakCount)
        } else {
            null
        }

    private fun GoalSlot.countPolicy(mode: CountRuleMode): CountPolicy =
        if (minimumCount != null || targetCount != null || maximumCount != null) {
            when (mode) {
                CountRuleMode.Tracker -> CountPolicy(
                    streakThreshold = Threshold.AnyPositive,
                    reminderThreshold = Threshold.AnyPositive,
                    completionThreshold = Threshold.AnyPositive,
                )
                CountRuleMode.Minimum -> CountPolicy(
                    minimumCount = minimumCount,
                    maximumCount = maximumCount,
                    streakThreshold = Threshold.Minimum,
                    reminderThreshold = Threshold.Minimum,
                    completionThreshold = Threshold.Minimum,
                    capBehavior = capBehavior.toDomainCapBehavior(),
                )
                CountRuleMode.Target -> CountPolicy(
                    minimumCount = minimumCount,
                    targetCount = targetCount,
                    maximumCount = maximumCount,
                    streakThreshold = if (minimumCount != null) Threshold.Minimum else Threshold.Target,
                    reminderThreshold = Threshold.Target,
                    completionThreshold = Threshold.Target,
                    capBehavior = capBehavior.toDomainCapBehavior(),
                )
                CountRuleMode.Stretch -> CountPolicy(
                    minimumCount = minimumCount,
                    targetCount = targetCount,
                    maximumCount = maximumCount,
                    streakThreshold = Threshold.Minimum,
                    reminderThreshold = Threshold.Target,
                    completionThreshold = Threshold.Target,
                    capBehavior = capBehavior.toDomainCapBehavior(),
                )
                CountRuleMode.Exact -> CountPolicy(
                    targetCount = targetCount,
                    maximumCount = maximumCount,
                    streakThreshold = Threshold.Target,
                    reminderThreshold = Threshold.Target,
                    completionThreshold = Threshold.Target,
                    capBehavior = CapBehavior.BlockAtMaximum,
                )
                CountRuleMode.Bounded -> CountPolicy(
                    minimumCount = minimumCount,
                    targetCount = targetCount,
                    maximumCount = maximumCount,
                    streakThreshold = Threshold.Minimum,
                    reminderThreshold = Threshold.Target,
                    completionThreshold = Threshold.Target,
                    capBehavior = capBehavior.toDomainCapBehavior(),
                )
            }
        } else {
            CountPolicy()
        }

    private fun CountPolicy.targetForSlotPersistence(policy: TargetPolicy): Int? =
        if (policy == TargetPolicy.NONE) null else targetCount ?: minimumCount

    private fun progressScopeFor(policy: TargetPolicy): ProgressScope =
        when (policy) {
            TargetPolicy.CUMULATIVE_TOTAL -> ProgressScope.Lifetime
            TargetPolicy.PERIOD_TOTAL -> ProgressScope.Period
            TargetPolicy.PER_DUE_DATE, TargetPolicy.NONE -> ProgressScope.DueDate
        }

    private fun reminderPoliciesFor(draft: GoalDraft): List<ReminderPolicy> =
        buildReminders(draft).map { reminder ->
            when (reminder.reminderType) {
                ReminderType.FIXED_TIME -> ReminderPolicy.FixedTime(
                    hour = reminder.hour ?: 0,
                    minute = reminder.minute ?: 0,
                    enabled = reminder.enabled,
                )
                ReminderType.PRAYER_OFFSET -> ReminderPolicy.PrayerOffset(
                    offsetMinutes = reminder.offsetMinutes ?: 10,
                    enabled = reminder.enabled,
                )
                ReminderType.TIME_WINDOW_START -> ReminderPolicy.TimeWindowStart(
                    offsetMinutes = reminder.offsetMinutes ?: 0,
                    enabled = reminder.enabled,
                )
            }
        }

    private fun positiveInt(value: String): Int? =
        value.toIntOrNull()?.takeIf { it > 0 }

    private fun supportsPerSlotTargets(draft: GoalDraft): Boolean =
        draft.countRule.mode == CountRuleMode.Target

    private fun supportsPerSlotRules(draft: GoalDraft): Boolean =
        draft.countRule.mode != CountRuleMode.Tracker

    private fun slotCountPolicyFor(
        mode: CountRuleMode,
        minimum: String,
        target: String,
        maximum: String,
        capBehavior: CapBehavior,
    ): CountPolicy =
        when (mode) {
            CountRuleMode.Tracker -> CountPolicy(
                streakThreshold = Threshold.AnyPositive,
                reminderThreshold = Threshold.AnyPositive,
                completionThreshold = Threshold.AnyPositive,
            )
            CountRuleMode.Minimum -> CountPolicy(
                minimumCount = positiveInt(minimum),
                streakThreshold = Threshold.Minimum,
                reminderThreshold = Threshold.Minimum,
                completionThreshold = Threshold.Minimum,
            )
            CountRuleMode.Target -> CountPolicy(
                targetCount = positiveInt(target),
                streakThreshold = Threshold.Target,
                reminderThreshold = Threshold.Target,
                completionThreshold = Threshold.Target,
            )
            CountRuleMode.Stretch -> CountPolicy(
                minimumCount = positiveInt(minimum),
                targetCount = positiveInt(target),
                streakThreshold = Threshold.Minimum,
                reminderThreshold = Threshold.Target,
                completionThreshold = Threshold.Target,
            )
            CountRuleMode.Exact -> {
                val count = positiveInt(maximum.ifBlank { target })
                CountPolicy(
                    targetCount = count,
                    maximumCount = count,
                    streakThreshold = Threshold.Target,
                    reminderThreshold = Threshold.Target,
                    completionThreshold = Threshold.Target,
                    capBehavior = CapBehavior.BlockAtMaximum,
                )
            }
            CountRuleMode.Bounded -> CountPolicy(
                minimumCount = positiveInt(minimum),
                targetCount = positiveInt(target),
                maximumCount = positiveInt(maximum),
                streakThreshold = Threshold.Minimum,
                reminderThreshold = Threshold.Target,
                completionThreshold = Threshold.Target,
                capBehavior = capBehavior,
            )
        }

    private fun GoalSlot.hasValidCountRule(mode: CountRuleMode): Boolean =
        when (mode) {
            CountRuleMode.Tracker -> true
            CountRuleMode.Minimum -> minimumCount != null && minimumCount > 0
            CountRuleMode.Target -> targetCount != null && targetCount > 0
            CountRuleMode.Stretch -> minimumCount != null && targetCount != null && minimumCount > 0 && minimumCount < targetCount
            CountRuleMode.Exact -> targetCount != null && maximumCount != null && targetCount > 0 && targetCount == maximumCount
            CountRuleMode.Bounded -> minimumCount != null &&
                targetCount != null &&
                maximumCount != null &&
                minimumCount > 0 &&
                minimumCount <= targetCount &&
                targetCount <= maximumCount
        }

    private fun CapBehavior.toDataCapBehavior(): CountCapBehavior =
        when (this) {
            CapBehavior.AllowOverTarget -> CountCapBehavior.AllowOverTarget
            CapBehavior.WarnOverTarget -> CountCapBehavior.WarnOverTarget
            CapBehavior.BlockAtTarget -> CountCapBehavior.BlockAtTarget
            CapBehavior.BlockAtMaximum -> CountCapBehavior.BlockAtMaximum
        }

    private fun CountCapBehavior.toDomainCapBehavior(): CapBehavior =
        when (this) {
            CountCapBehavior.AllowOverTarget -> CapBehavior.AllowOverTarget
            CountCapBehavior.WarnOverTarget -> CapBehavior.WarnOverTarget
            CountCapBehavior.BlockAtTarget -> CapBehavior.BlockAtTarget
            CountCapBehavior.BlockAtMaximum -> CapBehavior.BlockAtMaximum
        }

    private fun countRuleError(draft: GoalDraft, policy: TargetPolicy): GoalValidationMessage? {
        if (policy == TargetPolicy.NONE) return null
        return when (draft.countRule.mode) {
            CountRuleMode.Tracker -> null
            CountRuleMode.Minimum -> {
                if ((positiveInt(draft.countRule.minimumCount) ?: 0) <= 0) {
                    GoalValidationMessage.PositiveMinimumCount
                } else {
                    null
                }
            }
            CountRuleMode.Target -> null
            CountRuleMode.Stretch -> {
                val minimum = positiveInt(draft.countRule.minimumCount)
                val target = positiveInt(draft.countRule.targetCount)
                when {
                    minimum == null -> GoalValidationMessage.PositiveMinimumCount
                    target == null -> if (policy == TargetPolicy.CUMULATIVE_TOTAL) {
                        GoalValidationMessage.PositiveTotalTarget
                    } else {
                        GoalValidationMessage.PositiveSlotTarget
                    }
                    minimum >= target -> GoalValidationMessage.TargetMustExceedMinimum
                    else -> null
                }
            }
            CountRuleMode.Exact -> {
                if ((positiveInt(draft.countRule.maximumCount) ?: 0) <= 0) {
                    GoalValidationMessage.PositiveExactCount
                } else {
                    null
                }
            }
            CountRuleMode.Bounded -> {
                val minimum = positiveInt(draft.countRule.minimumCount)
                val target = positiveInt(draft.countRule.targetCount)
                val maximum = positiveInt(draft.countRule.maximumCount)
                when {
                    minimum == null -> GoalValidationMessage.PositiveMinimumCount
                    target == null -> if (policy == TargetPolicy.CUMULATIVE_TOTAL) {
                        GoalValidationMessage.PositiveTotalTarget
                    } else {
                        GoalValidationMessage.PositiveSlotTarget
                    }
                    maximum == null -> GoalValidationMessage.PositiveMaximumCount
                    minimum > target || target > maximum -> GoalValidationMessage.BoundedCountsOrdered
                    else -> null
                }
            }
        }
    }

    private fun parseSpecificDates(text: String): List<LocalDate> {
        return text.split(',', '\n', ' ')
            .mapNotNull { raw ->
                raw.trim()
                    .takeIf { it.isNotBlank() }
                    ?.toLocalDateOrNull()
            }
            .distinct()
    }

    private fun String.toCalendarSystem(): CalendarSystem =
        if (equals("hijri", ignoreCase = true)) CalendarSystem.HIJRI else CalendarSystem.GREGORIAN

    private fun Prayer.displayName(): String = name.lowercase().replaceFirstChar { it.uppercase() }
}

private fun GoalDraft.usesMorningEveningSlots(): Boolean =
    preset == GoalPreset.MORNING_EVENING && timingType == TimingType.TIME_BASED

private fun Int.toClockText(): String {
    val clamped = coerceIn(0, 24 * 60)
    val hour24 = (clamped / 60) % 24
    val minute = clamped % 60
    val suffix = if (hour24 < 12) "AM" else "PM"
    val hour12 = when (val normalized = hour24 % 12) {
        0 -> 12
        else -> normalized
    }
    return "%d:%02d %s".format(hour12, minute, suffix)
}
