package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.data.model.SlotCountingPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.CountRuleMode
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.FrequencyDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftMapper
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftSection
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalTimingDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalValidationMessage
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalValidationResult
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.TargetDraft
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOrNull
import java.time.DayOfWeek
import java.time.LocalDate

@Composable
fun GoalValidationResult.localizedErrors(): Map<GoalDraftSection, String> =
    errors.mapValues { (_, message) -> message.localizedText() }

@Composable
fun GoalValidationMessage.localizedText(): String = stringResource(
    when (this) {
        GoalValidationMessage.SelectDhikr -> R.string.goal_validation_select_dhikr
        GoalValidationMessage.ChooseTemplate -> R.string.goal_validation_choose_template
        GoalValidationMessage.PositiveTotalTarget -> R.string.goal_validation_positive_total_target
        GoalValidationMessage.PositiveSlotTarget -> R.string.goal_validation_positive_slot_target
        GoalValidationMessage.PositiveMinimumCount -> R.string.goal_validation_positive_minimum_count
        GoalValidationMessage.PositiveExactCount -> R.string.goal_validation_positive_exact_count
        GoalValidationMessage.PositiveMaximumCount -> R.string.goal_validation_positive_maximum_count
        GoalValidationMessage.TargetMustExceedMinimum -> R.string.goal_validation_target_above_minimum
        GoalValidationMessage.BoundedCountsOrdered -> R.string.goal_validation_bounded_counts_ordered
        GoalValidationMessage.TrackerCannotHaveTarget -> R.string.goal_validation_tracker_no_target
        GoalValidationMessage.SelectWeekday -> R.string.goal_validation_select_weekday
        GoalValidationMessage.SelectMonthDay -> R.string.goal_validation_select_month_day
        GoalValidationMessage.SelectYearDay -> R.string.goal_validation_select_year_day
        GoalValidationMessage.AddDate -> R.string.goal_validation_add_date
        GoalValidationMessage.SelectSeason -> R.string.goal_validation_select_season
        GoalValidationMessage.PositiveInterval -> R.string.goal_validation_positive_interval
        GoalValidationMessage.AddSlot -> R.string.goal_validation_add_slot
        GoalValidationMessage.SelectPrayer -> R.string.goal_validation_select_prayer
        GoalValidationMessage.AddTimeSlot -> R.string.goal_validation_add_time_slot
        GoalValidationMessage.InvalidTimeWindow -> R.string.goal_validation_invalid_time_window
        GoalValidationMessage.InvalidPrayerSlot -> R.string.goal_validation_invalid_prayer_slot
        GoalValidationMessage.InvalidReminderTime -> R.string.goal_validation_invalid_reminder_time
        GoalValidationMessage.PositiveDuration -> R.string.goal_validation_positive_duration
        GoalValidationMessage.PositiveMinimumStreak -> R.string.goal_validation_positive_minimum_streak
    }
)

@Composable
fun goalSentence(dhikrName: String, draft: GoalDraft?): String {
    if (draft == null) return stringResource(R.string.goal_sentence_choose_template, dhikrName)
    val target = targetSummary(draft)
    val schedule = scheduleSummary(draft)
    val slots = slotsSummary(draft)
    return when (draft.preset) {
        GoalPreset.PRAYER_BASED -> stringResource(R.string.goal_sentence_prayer_based, dhikrName, target, slots)
        GoalPreset.ONE_TIME -> stringResource(R.string.goal_sentence_one_time, target, dhikrName)
        GoalPreset.WEEKLY -> stringResource(R.string.goal_sentence_weekly, dhikrName, target, schedule)
        GoalPreset.ISLAMIC_SEASON -> stringResource(R.string.goal_sentence_season, dhikrName, target, schedule)
        GoalPreset.TRACKER -> stringResource(R.string.goal_sentence_tracker, dhikrName)
        GoalPreset.MORNING_EVENING -> stringResource(R.string.goal_sentence_morning_evening, dhikrName, target)
        else -> if (GoalDraftMapper.effectiveTiming(draft) == GoalTimingDraft.Anytime) {
            stringResource(R.string.goal_sentence_default, dhikrName, target, schedule)
        } else {
            // Advanced goals can also pin a timing (prayer windows, custom slots). Surface it so
            // the preview reflects choices like "after Dhuhr" instead of only the schedule day.
            stringResource(R.string.goal_sentence_default_timed, dhikrName, target, slots, schedule)
        }
    }
}

@Composable
fun targetSummary(draft: GoalDraft): String {
    val policy = GoalDraftMapper.targetPolicyFor(draft)
    if (policy == TargetPolicy.NONE) return stringResource(R.string.goal_summary_no_target)
    val isDaily = draft.frequencyDraft is FrequencyDraft.Daily
    when (draft.countRule.mode) {
        CountRuleMode.Minimum -> {
            val minimum = draft.countRule.minimumCount.ifBlank { "0" }
            return stringResource(
                if (isDaily) R.string.goal_summary_minimum_count_daily else R.string.goal_summary_minimum_count,
                minimum,
            )
        }
        CountRuleMode.Stretch -> {
            val minimum = draft.countRule.minimumCount.ifBlank { "0" }
            val target = draft.countRule.targetCount.ifBlank { "0" }
            return stringResource(
                if (isDaily) R.string.goal_summary_stretch_count_daily else R.string.goal_summary_stretch_count,
                minimum,
                target,
            )
        }
        CountRuleMode.Exact -> {
            val count = draft.countRule.maximumCount.ifBlank { "0" }
            return stringResource(
                if (isDaily) R.string.goal_summary_exact_count_daily else R.string.goal_summary_exact_count,
                count,
            )
        }
        CountRuleMode.Bounded -> {
            val minimum = draft.countRule.minimumCount.ifBlank { "0" }
            val target = draft.countRule.targetCount.ifBlank { "0" }
            val maximum = draft.countRule.maximumCount.ifBlank { "0" }
            return stringResource(
                if (isDaily) R.string.goal_summary_bounded_count_daily else R.string.goal_summary_bounded_count,
                minimum,
                target,
                maximum,
            )
        }
        CountRuleMode.Tracker,
        CountRuleMode.Target -> Unit
    }
    return when (val target = draft.targetDraft) {
        TargetDraft.None -> stringResource(R.string.goal_summary_no_target)
        is TargetDraft.Fixed -> {
            val count = target.count.ifBlank { "0" }
            when (policy) {
                TargetPolicy.CUMULATIVE_TOTAL -> stringResource(R.string.goal_summary_target_total, count)
                TargetPolicy.PERIOD_TOTAL -> stringResource(R.string.goal_summary_target_period, count)
                TargetPolicy.PER_DUE_DATE -> stringResource(
                    if (isDaily) R.string.goal_summary_target_times_daily else R.string.goal_summary_target_times,
                    count,
                )
                TargetPolicy.NONE -> stringResource(R.string.goal_summary_no_target)
            }
        }
        is TargetDraft.PrayerBased -> {
            val singlePrayer = target.selectedPrayers.singleOrNull()
            if (singlePrayer != null) {
                // Only one prayer — "per prayer" is meaningless, so read it as a plain count.
                stringResource(
                    if (isDaily) R.string.goal_summary_target_times_daily else R.string.goal_summary_target_times,
                    target.countFor(singlePrayer).ifBlank { "0" },
                )
            } else {
                val counts = target.selectedPrayers.map { target.countFor(it) }.filter { it.isNotBlank() }.distinct()
                if (counts.size == 1) {
                    stringResource(R.string.goal_summary_target_per_prayer_count, counts.single())
                } else {
                    stringResource(R.string.goal_summary_target_per_prayer)
                }
            }
        }
    }
}

@Composable
fun scheduleSummary(draft: GoalDraft): String {
    return when (val frequency = draft.frequencyDraft) {
        FrequencyDraft.Daily -> stringResource(R.string.goal_summary_schedule_daily)
        is FrequencyDraft.Weekly -> {
            if (frequency.days.isEmpty()) {
                stringResource(R.string.goal_summary_schedule_no_weekdays)
            } else {
                val days = frequency.days.sortedBy { it.value }
                    .map { it.localizedFullName() }
                    .joinToString(", ")
                stringResource(R.string.goal_summary_schedule_weekly_every, days)
            }
        }
        is FrequencyDraft.Monthly -> {
            val calendar = localizedCalendar(frequency.calendar)
            if (frequency.daysOfMonth.isEmpty()) {
                stringResource(R.string.goal_summary_schedule_monthly, calendar)
            } else {
                stringResource(R.string.goal_summary_schedule_monthly_on, calendar, frequency.daysOfMonth.sorted().joinToString(", "))
            }
        }
        is FrequencyDraft.Interval -> stringResource(R.string.goal_summary_schedule_interval, frequency.intervalDays.ifBlank { "?" })
        is FrequencyDraft.Yearly -> {
            val calendar = localizedCalendar(frequency.calendar)
            stringResource(
                R.string.goal_summary_schedule_yearly,
                calendar,
                frequency.month,
                frequency.days.sorted().joinToString(", ").ifBlank { stringResource(R.string.goal_summary_not_set) },
            )
        }
        is FrequencyDraft.Season -> frequency.seasonTemplateCode.localizedName()
        is FrequencyDraft.SpecificDates -> parseSpecificDates(frequency.dateText).joinToString(", ").ifBlank {
            stringResource(R.string.goal_summary_schedule_no_dates)
        }
    }
}

@Composable
fun slotsSummary(draft: GoalDraft): String {
    return when (GoalDraftMapper.effectiveTiming(draft)) {
        GoalTimingDraft.Anytime -> stringResource(R.string.goal_summary_slots_anytime)
        GoalTimingDraft.MorningEvening -> stringResource(R.string.goal_summary_slots_morning_evening)
        GoalTimingDraft.CustomSlots -> pluralStringResource(
            R.plurals.goal_summary_slots_time_count,
            draft.timeSlots.size,
            draft.timeSlots.size,
        )
        GoalTimingDraft.PrayerBased -> {
            val target = draft.targetDraft as? TargetDraft.PrayerBased
                ?: return stringResource(R.string.goal_summary_slots_prayer_not_configured)
            val relation = target.timing.localizedSummary()
            // On a Friday-only schedule the Dhuhr prayer is the Jumuʿah (Friday) prayer.
            val fridayOnly = (draft.frequencyDraft as? FrequencyDraft.Weekly)
                ?.let { it.days.size == 1 && it.days.first() == DayOfWeek.FRIDAY } == true
            val prayers = if (target.selectedPrayers.size == Prayer.entries.size) {
                stringResource(R.string.goal_summary_slots_each_prayer)
            } else {
                target.selectedPrayers.sortedBy { it.ordinal }
                    .map { prayer ->
                        if (fridayOnly && prayer == Prayer.DHUHR) {
                            stringResource(R.string.prayer_jumuah)
                        } else {
                            prayer.localizedName()
                        }
                    }
                    .joinToString(", ")
            }
            stringResource(R.string.goal_summary_slots_prayer, relation, prayers)
        }
    }
}

@Composable
fun remindersSummary(draft: GoalDraft): String {
    val reminders = if (!draft.extras.notificationEnabled) {
        stringResource(R.string.goal_summary_off)
    } else when (GoalDraftMapper.effectiveTiming(draft)) {
        GoalTimingDraft.PrayerBased -> stringResource(R.string.goal_summary_reminders_prayer)
        GoalTimingDraft.MorningEvening,
        GoalTimingDraft.CustomSlots -> stringResource(R.string.goal_summary_reminders_window_start)
        GoalTimingDraft.Anytime -> stringResource(
            R.string.goal_summary_reminders_time,
            "%02d:%02d".format(draft.extras.notificationHour, draft.extras.notificationMinute),
        )
    }
    return reminders
}

@Composable
fun durationSummary(draft: GoalDraft): String {
    val duration = if (draft.extras.hasDuration) {
        stringResource(R.string.goal_summary_duration_days, draft.extras.durationDays.ifBlank { "?" })
    } else {
        stringResource(R.string.goal_summary_duration_ongoing)
    }
    return if (draft.extras.hasMinStreak) {
        stringResource(R.string.goal_summary_duration_with_streak, duration, draft.extras.minStreakCount.ifBlank { "?" })
    } else {
        duration
    }
}

@Composable
fun GoalSlot.previewTitle(): String {
    return when (slotType) {
        GoalSlotType.ANYTIME -> stringResource(R.string.goal_summary_slots_anytime)
        GoalSlotType.PRAYER -> label ?: stringResource(
            R.string.goal_slot_prayer_title,
            prayerRelation?.localizedTitle().orEmpty(),
            prayerName?.localizedName().orEmpty(),
        ).trim()
        GoalSlotType.TIME_WINDOW -> label?.asSessionDisplayLabel() ?: stringResource(R.string.goal_slot_time_slot)
    }
}

private fun String.asSessionDisplayLabel(): String =
    trim().replace(Regex("^Slot(\\s+\\d+)$", RegexOption.IGNORE_CASE), "Session$1")

@Composable
fun GoalSlot.previewValue(): String {
    val targetText = targetCount?.let { stringResource(R.string.goal_slot_target_suffix, it) }.orEmpty()
    return when (slotType) {
        GoalSlotType.ANYTIME -> stringResource(R.string.goal_slot_flexible, targetText)
        GoalSlotType.PRAYER -> stringResource(R.string.goal_slot_prayer_value, prayerRelation?.localizedTitle().orEmpty(), targetText)
        GoalSlotType.TIME_WINDOW -> stringResource(
            R.string.goal_slot_time_window_value,
            (startMinute ?: 0).toClockText(),
            (endMinute ?: 0).toClockText(),
            targetText,
        )
    }
}

@Composable
fun Prayer.localizedName(): String = stringResource(
    when (this) {
        Prayer.FAJR -> R.string.prayer_fajr
        Prayer.DHUHR -> R.string.prayer_dhuhr
        Prayer.ASR -> R.string.prayer_asr
        Prayer.MAGHRIB -> R.string.prayer_maghrib
        Prayer.ISHA -> R.string.prayer_isha
    }
)

@Composable
fun PrayerRelation.localizedTitle(): String = when (this) {
    PrayerRelation.BEFORE -> stringResource(R.string.prayer_relation_before)
    PrayerRelation.AFTER -> stringResource(R.string.prayer_relation_after)
}

@Composable
fun SlotCountingPolicy.localizedTitle(): String = when (this) {
    SlotCountingPolicy.WARN_AND_ALLOW -> stringResource(R.string.slot_policy_warn_title)
    SlotCountingPolicy.STRICT_ACTIVE_ONLY -> stringResource(R.string.slot_policy_strict_title)
    SlotCountingPolicy.SILENT_FLEXIBLE -> stringResource(R.string.slot_policy_silent_title)
}

@Composable
fun SlotCountingPolicy.localizedDescription(): String = when (this) {
    SlotCountingPolicy.WARN_AND_ALLOW -> stringResource(R.string.slot_policy_warn_description)
    SlotCountingPolicy.STRICT_ACTIVE_ONLY -> stringResource(R.string.slot_policy_strict_description)
    SlotCountingPolicy.SILENT_FLEXIBLE -> stringResource(R.string.slot_policy_silent_description)
}

@Composable
fun SlotCountingPolicy.localizedSummary(): String = when (this) {
    SlotCountingPolicy.WARN_AND_ALLOW -> stringResource(R.string.slot_policy_warn_summary)
    SlotCountingPolicy.STRICT_ACTIVE_ONLY -> stringResource(R.string.slot_policy_strict_summary)
    SlotCountingPolicy.SILENT_FLEXIBLE -> stringResource(R.string.slot_policy_silent_summary)
}

@Composable
fun PrayerRelation.localizedSlotTitle(prayer: Prayer): String =
    stringResource(R.string.goal_slot_prayer_title, localizedTitle(), prayer.localizedName())

@Composable
fun PrayerTiming.localizedTitle(): String = when (this) {
    PrayerTiming.BEFORE -> stringResource(R.string.prayer_timing_before_prayer)
    PrayerTiming.AFTER -> stringResource(R.string.prayer_timing_after_prayer)
    PrayerTiming.BOTH -> stringResource(R.string.prayer_timing_before_and_after)
}

@Composable
fun PrayerTiming.localizedSummary(): String = when (this) {
    PrayerTiming.BEFORE -> stringResource(R.string.prayer_relation_before)
    PrayerTiming.AFTER -> stringResource(R.string.prayer_relation_after)
    PrayerTiming.BOTH -> stringResource(R.string.prayer_timing_before_and_after)
}

@Composable
fun DayOfWeek.localizedShortName(): String = stringResource(
    when (this) {
        DayOfWeek.MONDAY -> R.string.weekday_mon_short
        DayOfWeek.TUESDAY -> R.string.weekday_tue_short
        DayOfWeek.WEDNESDAY -> R.string.weekday_wed_short
        DayOfWeek.THURSDAY -> R.string.weekday_thu_short
        DayOfWeek.FRIDAY -> R.string.weekday_fri_short
        DayOfWeek.SATURDAY -> R.string.weekday_sat_short
        DayOfWeek.SUNDAY -> R.string.weekday_sun_short
    }
)

@Composable
fun DayOfWeek.localizedFullName(): String = stringResource(
    when (this) {
        DayOfWeek.MONDAY -> R.string.weekday_mon_full
        DayOfWeek.TUESDAY -> R.string.weekday_tue_full
        DayOfWeek.WEDNESDAY -> R.string.weekday_wed_full
        DayOfWeek.THURSDAY -> R.string.weekday_thu_full
        DayOfWeek.FRIDAY -> R.string.weekday_fri_full
        DayOfWeek.SATURDAY -> R.string.weekday_sat_full
        DayOfWeek.SUNDAY -> R.string.weekday_sun_full
    }
)

@Composable
fun SeasonTemplateCode.localizedName(): String = stringResource(
    when (this) {
        SeasonTemplateCode.RAMADAN -> R.string.season_ramadan
        SeasonTemplateCode.RAMADAN_LAST_10 -> R.string.season_ramadan_last_10
        SeasonTemplateCode.DHUL_HIJJAH_1_10 -> R.string.season_dhul_hijjah_1_10
        SeasonTemplateCode.WHITE_DAYS -> R.string.season_white_days
        SeasonTemplateCode.ASHURA -> R.string.season_ashura
        SeasonTemplateCode.ARAFAH -> R.string.season_arafah
    }
)

@Composable
fun localizedCalendar(calendar: String): String =
    if (calendar.equals("hijri", ignoreCase = true)) {
        stringResource(R.string.settings_calendar_hijri)
    } else {
        stringResource(R.string.settings_calendar_gregorian)
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
