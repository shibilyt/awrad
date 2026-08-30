package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.outlined.AllInclusive
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetValue
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import kotlinx.coroutines.launch
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.TimingType
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CapBehavior
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualPrimaryButton
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.CountInputField
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.CountRuleDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.CountRuleMode
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.SlotTargetMode
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.toCountRule
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.withCountRule
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.ExtrasDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.FrequencyDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftMapper
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalTimeSlotDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalTimingDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalValidationResult
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.PrayerSlotTargetKey
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.TargetDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.eveningRule
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.morningRule
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.withEveningRule
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.withMorningRule
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import app.awrad.awrad_dhikrgoalstracker.util.DateUtils
import java.time.DayOfWeek

// ─── Accent ──────────────────────────────────────────────────────────────────

@Composable
private fun composerAccent(): Color = MaterialTheme.colorScheme.primary

/** The four first-class goal shapes surfaced as composer cards. */
private enum class ComposerType(
    val defaultPreset: GoalPreset,
    val icon: ImageVector,
    val titleRes: Int,
    val descRes: Int,
) {
    Daily(GoalPreset.DAILY, Icons.Outlined.CalendarMonth, R.string.composer_type_daily_title, R.string.composer_type_daily_desc),
    OneTime(GoalPreset.ONE_TIME, Icons.Outlined.Flag, R.string.composer_type_onetime_title, R.string.composer_type_onetime_desc),
    Tracker(GoalPreset.TRACKER, Icons.Outlined.AllInclusive, R.string.composer_type_tracker_title, R.string.composer_type_tracker_desc),
    Advanced(GoalPreset.CUSTOM, Icons.Outlined.Tune, R.string.composer_type_advanced_title, R.string.composer_type_advanced_desc),
}

private fun composerTypeFor(preset: GoalPreset): ComposerType = when (preset) {
    GoalPreset.DAILY -> ComposerType.Daily
    GoalPreset.ONE_TIME -> ComposerType.OneTime
    GoalPreset.TRACKER, GoalPreset.ADV_TRACKER -> ComposerType.Tracker
    else -> ComposerType.Advanced
}


// ─── Pane ──────────────────────────────────────────────────────────────────

enum class AdvancedComposerStep {
    Schedule,
    ScheduleDetails,
    Timing,
    Target,
    Details,
}

@Composable
fun GoalComposerPane(
    dhikr: Dhikr,
    draft: GoalDraft,
    validation: GoalValidationResult,
    isCreating: Boolean,
    canChangeDhikr: Boolean,
    onChangeDhikr: () -> Unit,
    onSelectPreset: (GoalPreset) -> Unit,
    onTargetChange: (TargetDraft) -> Unit,
    onFrequencyChange: (FrequencyDraft) -> Unit,
    onExtrasChange: (ExtrasDraft) -> Unit,
    onDraftChange: (GoalDraft) -> Unit,
    onCreate: () -> Unit,
    modifier: Modifier = Modifier,
    showTypeSelector: Boolean = true,
    showTimingSelector: Boolean = true,
    step: AdvancedComposerStep = AdvancedComposerStep.Details,
    onNext: () -> Unit = {},
) {
    val dhikrName = dhikr.transliteration.ifBlank { dhikr.title }
    val selectedType = composerTypeFor(draft.preset)

    // Pin the goal-preview sentence under the header; collapse it to a slim bar once
    // the user scrolls into the controls so it stays visible without eating the screen.
    val scrollState = rememberScrollState()
    val collapseThresholdPx = with(LocalDensity.current) { 72.dp.toPx() }
    val previewCollapsed by remember(collapseThresholdPx) {
        derivedStateOf { scrollState.value > collapseThresholdPx }
    }

    Box(modifier = modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            GoalSentenceHero(
                sentence = goalSentence(dhikrName, draft),
                collapsed = previewCollapsed,
            )
            if (!previewCollapsed && canChangeDhikr) {
                TextButton(
                    onClick = onChangeDhikr,
                    modifier = Modifier
                        .align(Alignment.End)
                        .padding(end = 20.dp),
                ) {
                    Text(
                        text = stringResourceCompat(R.string.composer_change_dhikr),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }

            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(scrollState)
                    .padding(horizontal = 20.dp)
                    .padding(top = 4.dp, bottom = 116.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                if (step == AdvancedComposerStep.Schedule) {
                    ComposerEntry(0) {
                        AdvancedScheduleStep(
                            draft = draft,
                            onSelect = { onDraftChange(draft.withScheduleStepOption(it)) },
                        )
                    }
                } else if (step == AdvancedComposerStep.ScheduleDetails) {
                    ComposerEntry(0) {
                        ScheduleDetailsStep(
                            draft = draft,
                            onFrequencyChange = onFrequencyChange,
                        )
                    }
                } else if (step == AdvancedComposerStep.Timing) {
                    ComposerEntry(0) {
                        AdvancedTimingStep(
                            draft = draft,
                            onDraftChange = onDraftChange,
                        )
                    }
                } else if (step == AdvancedComposerStep.Target) {
                    ComposerEntry(0) {
                        AdvancedTargetStep(
                            draft = draft,
                            onDraftChange = onDraftChange,
                        )
                    }
                } else {
                    if (showTypeSelector) {
                        ComposerEntry(0) {
                            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                SectionLabel(stringResourceCompat(R.string.composer_type_question))
                                GoalTypeGrid(selected = selectedType, onSelect = { onSelectPreset(it.defaultPreset) })
                            }
                        }
                    }

                    ComposerEntry(1) {
                        AnimatedContent(
                            targetState = selectedType,
                            transitionSpec = {
                                (fadeIn(tween(220)) + slideInVertically(tween(260, easing = FastOutSlowInEasing)) { it / 12 })
                                    .togetherWith(fadeOut(tween(140)))
                            },
                            label = "composerConfig",
                        ) { type ->
                            ComposerConfig(
                                type = type,
                                draft = draft,
                                onTargetChange = onTargetChange,
                                onFrequencyChange = onFrequencyChange,
                                onDraftChange = onDraftChange,
                                includeSchedule = false,
                                showTimingSelector = showTimingSelector,
                            )
                        }
                    }

                    ComposerEntry(2) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            SectionLabel(stringResourceCompat(R.string.composer_finetune))
                            FineTuneSection(
                                draft = draft,
                                onExtrasChange = onExtrasChange,
                            )
                        }
                    }
                }
            }
        }

        if (step == AdvancedComposerStep.Schedule) {
            ComposerNextBar(
                labelRes = scheduleStepCtaLabelRes(draft.frequencyDraft),
                onNext = onNext,
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        } else if (step == AdvancedComposerStep.ScheduleDetails) {
            ComposerNextBar(
                onNext = onNext,
                enabled = draft.scheduleDetailsReady(),
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        } else if (step == AdvancedComposerStep.Timing) {
            ComposerNextBar(
                onNext = onNext,
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        } else if (step == AdvancedComposerStep.Target) {
            ComposerNextBar(
                labelRes = R.string.composer_continue,
                enabled = draft.targetStepReady(),
                onNext = onNext,
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        } else {
            ComposerCreateBar(
                validation = validation,
                isCreating = isCreating,
                onCreate = onCreate,
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }
    }
}

private data class TimingStepOption(
    val timing: GoalTimingDraft,
    val titleRes: Int,
    val descriptionRes: Int,
)

private val ADVANCED_TIMING_OPTIONS = listOf(
    TimingStepOption(
        timing = GoalTimingDraft.Anytime,
        titleRes = R.string.timing_anytime,
        descriptionRes = R.string.timing_anytime_desc,
    ),
    TimingStepOption(
        timing = GoalTimingDraft.PrayerBased,
        titleRes = R.string.timing_prayer_based,
        descriptionRes = R.string.timing_prayer_desc,
    ),
    TimingStepOption(
        timing = GoalTimingDraft.CustomSlots,
        titleRes = R.string.composer_timing_custom,
        descriptionRes = R.string.composer_timing_custom_desc,
    ),
)

@Composable
private fun AdvancedTimingStep(
    draft: GoalDraft,
    onDraftChange: (GoalDraft) -> Unit,
) {
    val selected = GoalDraftMapper.effectiveTiming(draft)
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            text = stringResourceCompat(R.string.composer_timing_question),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ADVANCED_TIMING_OPTIONS.forEach { option ->
                TimingStepOptionCard(
                    option = option,
                    selected = option.timing == selected,
                    onClick = {
                        if (option.timing != selected) {
                            applyTimingSelection(draft, option.timing, onDraftChange)
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun TimingStepOptionCard(
    option: TimingStepOption,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val accent = composerAccent()
    val container = if (selected) {
        MaterialTheme.colorScheme.primaryContainer.copy(alpha = if (isAwradDarkTheme()) 0.5f else 0.7f)
    } else {
        MaterialTheme.colorScheme.surfaceContainerLow
    }
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        color = container,
        border = BorderStroke(
            width = if (selected) 1.5.dp else 1.dp,
            color = if (selected) accent else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f),
        ),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 18.dp, vertical = 17.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = stringResourceCompat(option.titleRes),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = stringResourceCompat(option.descriptionRes),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (selected) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = null,
                    tint = accent,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}

private enum class TargetSessionBucket {
    Anytime,
    Morning,
    Evening,
    Prayer,
    Custom,
}

private data class TargetSessionRef(
    val bucket: TargetSessionBucket,
    val index: Int = -1,
    val prayer: Prayer? = null,
    val relation: PrayerRelation? = null,
    val label: String? = null,
    val labelRes: Int? = null,
)

@Composable
private fun AdvancedTargetStep(
    draft: GoalDraft,
    onDraftChange: (GoalDraft) -> Unit,
) {
    val sessions = targetSessionRefs(draft)
    val hasMultipleSessions = sessions.size > 1
    val perSession = hasMultipleSessions && draft.slotTargetMode == SlotTargetMode.PerSlot

    Column(
        modifier = Modifier.testTag("advanced-target-step"),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = stringResourceCompat(R.string.composer_target_question),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
        )

        if (!perSession) {
            GoalTargetInput(
                value = draft.targetInputValue(),
                labelRes = R.string.composer_target_label,
                quickValues = listOf(33, 100, 1000, 10000),
                integratedStepper = true,
                onValueChange = { onDraftChange(draft.withSharedTargetInputValue(it)) },
                testTag = "advanced-target-shared",
            )
            if (draft.countRule.mode == CountRuleMode.Target) {
                AdvancedMinimumTargetOption(
                    enabled = draft.extras.hasMinStreak,
                    value = draft.extras.minStreakCount,
                    onEnabledChange = { enabled ->
                        onDraftChange(draft.withSharedMinimumTarget(enabled))
                    },
                    onValueChange = { value ->
                        onDraftChange(draft.withSharedMinimumTarget(true, value))
                    },
                    testTag = "advanced-target-shared-minimum",
                )
            }
        }

        if (hasMultipleSessions) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp, vertical = 8.dp)
                    .clickable {
                        onDraftChange(draft.withPerSessionTargets(!perSession, sessions))
                    }
                    .testTag("advanced-target-different-sessions"),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Checkbox(
                    checked = perSession,
                    onCheckedChange = null,
                )
                Text(
                    text = stringResourceCompat(R.string.composer_target_different_sessions),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
        }

        if (perSession) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                sessions.forEachIndexed { index, session ->
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        color = MaterialTheme.colorScheme.surfaceContainerLow,
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f)),
                    ) {
                        Column(
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 14.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Text(
                                text = session.localizedLabel(),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                            GoalTargetInput(
                                value = draft.targetValueFor(session),
                                labelRes = R.string.composer_target_label,
                                quickValues = listOf(33, 100, 1000),
                                integratedStepper = true,
                                onValueChange = { onDraftChange(draft.withSessionTarget(session, it)) },
                                testTag = "advanced-target-session-$index",
                            )
                            if (draft.countRule.mode == CountRuleMode.Target) {
                                AdvancedMinimumTargetOption(
                                    enabled = draft.hasMinimumTargetFor(session),
                                    value = draft.minimumTargetValueFor(session),
                                    onEnabledChange = { enabled ->
                                        onDraftChange(draft.withSessionMinimumTarget(session, enabled))
                                    },
                                    onValueChange = { value ->
                                        onDraftChange(draft.withSessionMinimumTarget(session, value))
                                    },
                                    testTag = "advanced-target-session-$index-minimum",
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AdvancedMinimumTargetOption(
    enabled: Boolean,
    value: String,
    onEnabledChange: (Boolean) -> Unit,
    onValueChange: (String) -> Unit,
    testTag: String,
) {
    Column(
        modifier = Modifier.testTag(testTag),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (enabled) {
            GoalTargetInput(
                value = value,
                labelRes = R.string.create_goal_min_streak,
                quickValues = listOf(1, 10, 33, 100),
                integratedStepper = true,
                onValueChange = onValueChange,
                testTag = "$testTag-input",
            )
            Text(
                text = stringResourceCompat(R.string.create_goal_min_streak_hint),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            TextButton(
                onClick = { onEnabledChange(false) },
                modifier = Modifier
                    .align(Alignment.End)
                    .testTag("$testTag-remove"),
            ) {
                Text(stringResourceCompat(R.string.create_goal_remove_streak))
            }
        } else {
            TextButton(
                onClick = { onEnabledChange(true) },
                modifier = Modifier.testTag("$testTag-add"),
            ) {
                Text(stringResourceCompat(R.string.create_goal_add_streak))
            }
        }
    }
}

private fun targetSessionRefs(draft: GoalDraft): List<TargetSessionRef> = when (GoalDraftMapper.effectiveTiming(draft)) {
    GoalTimingDraft.Anytime -> listOf(
        TargetSessionRef(
            bucket = TargetSessionBucket.Anytime,
            labelRes = R.string.timing_anytime,
        )
    )
    GoalTimingDraft.MorningEvening -> listOf(
        TargetSessionRef(TargetSessionBucket.Morning, labelRes = R.string.composer_morning),
        TargetSessionRef(TargetSessionBucket.Evening, labelRes = R.string.composer_evening),
    )
    GoalTimingDraft.PrayerBased -> {
        val target = draft.targetDraft as? TargetDraft.PrayerBased
        if (target == null) {
            emptyList()
        } else {
            Prayer.entries
                .filter { it in target.selectedPrayers }
                .flatMap { prayer ->
                    PrayerRelation.entries
                        .filter { it in target.relationsFor(prayer) }
                        .map { relation ->
                            TargetSessionRef(
                                bucket = TargetSessionBucket.Prayer,
                                prayer = prayer,
                                relation = relation,
                            )
                        }
                    }
                }
    }
    GoalTimingDraft.CustomSlots -> draft.timeSlots.mapIndexed { index, slot ->
        TargetSessionRef(
            bucket = TargetSessionBucket.Custom,
            index = index,
            label = slot.displayLabel(index + 1),
        )
    }
}

@Composable
private fun TargetSessionRef.localizedLabel(): String = when {
    prayer != null && relation != null -> relation.localizedSlotTitle(prayer)
    labelRes != null -> stringResourceCompat(labelRes)
    else -> label.orEmpty()
}

private fun CountRuleDraft.targetInputValue(): String = when (mode) {
    CountRuleMode.Minimum -> minimumCount
    CountRuleMode.Exact -> maximumCount
    CountRuleMode.Tracker,
    CountRuleMode.Target,
    CountRuleMode.Stretch,
    CountRuleMode.Bounded -> targetCount
}

private fun CountRuleDraft.withTargetInputValue(value: String): CountRuleDraft = when (mode) {
    CountRuleMode.Minimum -> copy(minimumCount = value)
    CountRuleMode.Exact -> copy(maximumCount = value)
    CountRuleMode.Tracker,
    CountRuleMode.Target,
    CountRuleMode.Stretch,
    CountRuleMode.Bounded -> copy(targetCount = value)
}

private fun GoalTimeSlotDraft.targetInputValue(): String = when (mode) {
    CountRuleMode.Minimum -> minimumCount
    CountRuleMode.Exact -> maximumCount
    CountRuleMode.Tracker,
    CountRuleMode.Target,
    CountRuleMode.Stretch,
    CountRuleMode.Bounded -> targetCount
}

private fun GoalTimeSlotDraft.withTargetInputValue(value: String): GoalTimeSlotDraft = when (mode) {
    CountRuleMode.Minimum -> copy(minimumCount = value)
    CountRuleMode.Exact -> copy(maximumCount = value)
    CountRuleMode.Tracker,
    CountRuleMode.Target,
    CountRuleMode.Stretch,
    CountRuleMode.Bounded -> copy(targetCount = value)
}

private fun GoalDraft.targetInputValue(): String {
    val count = countRule.targetInputValue()
    if (count.isNotBlank()) return count
    return when (val target = targetDraft) {
        is TargetDraft.Fixed -> target.count
        is TargetDraft.PrayerBased -> target.uniformCount
        TargetDraft.None -> ""
    }
}

private fun GoalDraft.minimumTargetValueFor(session: TargetSessionRef): String = when (session.bucket) {
    TargetSessionBucket.Anytime -> extras.minStreakCount.takeIf { extras.hasMinStreak }.orEmpty()
    TargetSessionBucket.Morning -> morningRule().minimumCount
    TargetSessionBucket.Evening -> eveningRule().minimumCount
    TargetSessionBucket.Custom -> timeSlots.getOrNull(session.index)?.minimumCount.orEmpty()
    TargetSessionBucket.Prayer -> {
        val target = targetDraft as? TargetDraft.PrayerBased
        val prayer = session.prayer
        val relation = session.relation
        if (target == null || prayer == null || relation == null) {
            ""
        } else {
            target.minimumFor(prayer, relation, "")
        }
    }
}

private fun GoalDraft.hasMinimumTargetFor(session: TargetSessionRef): Boolean =
    minimumTargetValueFor(session).isNotBlank()

private fun GoalDraft.targetValueFor(session: TargetSessionRef): String = when (session.bucket) {
    TargetSessionBucket.Anytime -> targetInputValue()
    TargetSessionBucket.Morning -> morningRule().targetInputValue()
    TargetSessionBucket.Evening -> eveningRule().targetInputValue()
    TargetSessionBucket.Custom -> timeSlots.getOrNull(session.index)?.targetInputValue().orEmpty()
    TargetSessionBucket.Prayer -> {
        val target = targetDraft as? TargetDraft.PrayerBased
        val prayer = session.prayer
        val relation = session.relation
        if (target == null || prayer == null || relation == null) {
            targetInputValue()
        } else {
            when (countRule.mode) {
                CountRuleMode.Minimum -> target.minimumFor(prayer, relation, countRule.minimumCount)
                CountRuleMode.Exact -> target.maximumFor(prayer, relation, countRule.maximumCount)
                CountRuleMode.Tracker,
                CountRuleMode.Target,
                CountRuleMode.Stretch,
                CountRuleMode.Bounded -> target.countFor(prayer, relation)
            }
        }
    }
}

private fun GoalDraft.withSharedTargetInputValue(value: String): GoalDraft {
    val nextTarget = when (val target = targetDraft) {
        is TargetDraft.Fixed -> target.copy(count = value)
        is TargetDraft.PrayerBased -> target.copy(
            uniform = true,
            uniformCount = value,
            perPrayerCounts = emptyMap(),
            perPrayerRelationCounts = emptyMap(),
        )
        TargetDraft.None -> targetDraft
    }
    return copy(
        targetDraft = nextTarget,
        countRule = countRule.withTargetInputValue(value),
        morningTargetCount = value,
        eveningTargetCount = value,
        timeSlots = timeSlots.map { it.withTargetInputValue(value) },
        slotTargetMode = SlotTargetMode.Same,
    )
}

private fun GoalDraft.withSharedMinimumTarget(
    enabled: Boolean,
    value: String = extras.minStreakCount,
): GoalDraft = copy(
    extras = extras.copy(
        hasMinStreak = enabled,
        minStreakCount = if (enabled && value.isBlank()) "1" else value,
    ),
)

private fun GoalDraft.withPerSessionTargets(
    enabled: Boolean,
    sessions: List<TargetSessionRef>,
): GoalDraft {
    if (enabled) {
        val nextTarget = (targetDraft as? TargetDraft.PrayerBased)?.copy(uniform = false) ?: targetDraft
        var next = copy(slotTargetMode = SlotTargetMode.PerSlot, targetDraft = nextTarget)
        if (extras.hasMinStreak && extras.minStreakCount.isNotBlank()) {
            sessions.forEach { session ->
                if (!next.hasMinimumTargetFor(session)) {
                    next = next.withSessionMinimumTarget(session, extras.minStreakCount)
                }
            }
        }
        return next
    }
    val sharedValue = sessions.firstOrNull()?.let { targetValueFor(it) } ?: targetInputValue()
    val sharedMinimum = sessions.firstOrNull()?.let { minimumTargetValueFor(it) }.orEmpty()
    return copy(slotTargetMode = SlotTargetMode.Same)
        .withSharedTargetInputValue(sharedValue)
        .withSharedMinimumTarget(sharedMinimum.isNotBlank(), sharedMinimum)
}

private fun GoalDraft.withSessionTarget(session: TargetSessionRef, value: String): GoalDraft = when (session.bucket) {
    TargetSessionBucket.Anytime -> withSharedTargetInputValue(value)
    TargetSessionBucket.Morning -> copy(
        slotTargetMode = SlotTargetMode.PerSlot,
    ).withMorningRule(morningRule().withTargetInputValue(value))
    TargetSessionBucket.Evening -> copy(
        slotTargetMode = SlotTargetMode.PerSlot,
    ).withEveningRule(eveningRule().withTargetInputValue(value))
    TargetSessionBucket.Custom -> {
        val nextSlots = timeSlots.mapIndexed { index, slot ->
            if (index == session.index) slot.withTargetInputValue(value) else slot
        }
        copy(slotTargetMode = SlotTargetMode.PerSlot, timeSlots = nextSlots)
    }
    TargetSessionBucket.Prayer -> {
        val target = targetDraft as? TargetDraft.PrayerBased
        val prayer = session.prayer
        val relation = session.relation
        if (target == null || prayer == null || relation == null) {
            this
        } else {
            val nextTarget = when (countRule.mode) {
                CountRuleMode.Minimum -> target.withMinimumFor(prayer, relation, value)
                CountRuleMode.Exact -> target.withMaximumFor(prayer, relation, value)
                CountRuleMode.Tracker,
                CountRuleMode.Target,
                CountRuleMode.Stretch,
                CountRuleMode.Bounded -> target.withCountFor(prayer, relation, value)
            }
            copy(slotTargetMode = SlotTargetMode.PerSlot, targetDraft = nextTarget)
        }
    }
}

private fun GoalDraft.withSessionMinimumTarget(
    session: TargetSessionRef,
    enabled: Boolean,
): GoalDraft {
    val value = if (enabled) {
        minimumTargetValueFor(session)
            .ifBlank { extras.minStreakCount.takeIf { extras.hasMinStreak }.orEmpty() }
            .ifBlank { "1" }
    } else {
        ""
    }
    return withSessionMinimumTarget(session, value)
}

private fun GoalDraft.withSessionMinimumTarget(
    session: TargetSessionRef,
    value: String,
): GoalDraft = when (session.bucket) {
    TargetSessionBucket.Anytime -> withSharedMinimumTarget(value.isNotBlank(), value)
    TargetSessionBucket.Morning -> copy(slotTargetMode = SlotTargetMode.PerSlot)
        .withMorningRule(morningRule().copy(minimumCount = value))
    TargetSessionBucket.Evening -> copy(slotTargetMode = SlotTargetMode.PerSlot)
        .withEveningRule(eveningRule().copy(minimumCount = value))
    TargetSessionBucket.Custom -> copy(
        slotTargetMode = SlotTargetMode.PerSlot,
        timeSlots = timeSlots.mapIndexed { index, slot ->
            if (index == session.index) slot.copy(minimumCount = value) else slot
        },
    )
    TargetSessionBucket.Prayer -> {
        val target = targetDraft as? TargetDraft.PrayerBased
        val prayer = session.prayer
        val relation = session.relation
        if (target == null || prayer == null || relation == null) {
            this
        } else {
            val key = PrayerSlotTargetKey(prayer, relation)
            val nextTarget = if (value.isBlank()) {
                target.copy(perPrayerRelationMinimumCounts = target.perPrayerRelationMinimumCounts + (key to ""))
            } else {
                target.withMinimumFor(prayer, relation, value)
            }
            copy(slotTargetMode = SlotTargetMode.PerSlot, targetDraft = nextTarget)
        }
    }
}

private fun GoalDraft.targetStepReady(): Boolean {
    val sessions = targetSessionRefs(this)
    val perSession = sessions.size > 1 && slotTargetMode == SlotTargetMode.PerSlot
    return if (perSession) {
        sessions.all { session ->
            val target = targetValueFor(session).toIntOrNull()
            val minimum = minimumTargetValueFor(session).toIntOrNull()
            target != null && target > 0 && (minimum == null || (minimum > 0 && minimum <= target))
        }
    } else {
        val target = targetInputValue().toIntOrNull()
        val minimum = if (countRule.mode == CountRuleMode.Target && extras.hasMinStreak) {
            extras.minStreakCount.toIntOrNull()
        } else {
            null
        }
        target != null && target > 0 &&
            (!extras.hasMinStreak || (minimum != null && minimum > 0 && minimum <= target))
    }
}

@Composable
private fun AdvancedScheduleStep(
    draft: GoalDraft,
    onSelect: (ScheduleStepOption) -> Unit,
) {
    val selected = draft.scheduleStepOption()
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            text = stringResourceCompat(R.string.composer_schedule_question),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ScheduleStepOption.entries.forEach { option ->
                ScheduleStepOptionCard(
                    option = option,
                    selected = option == selected,
                    onClick = { onSelect(option) },
                )
            }
        }
    }
}

internal fun scheduleStepCtaLabelRes(frequency: FrequencyDraft): Int =
    if (frequency is FrequencyDraft.Daily) {
        R.string.composer_set_timings
    } else {
        R.string.composer_set_days
    }

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ScheduleDetailsStep(
    draft: GoalDraft,
    onFrequencyChange: (FrequencyDraft) -> Unit,
) {
    when (val frequency = draft.frequencyDraft) {
        is FrequencyDraft.Weekly -> ScheduleDetailsSection(
            title = stringResourceCompat(R.string.composer_schedule_details_weekly),
        ) {
            DayOfWeek.entries.chunked(2).forEach { row ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    row.forEach { day ->
                        ScheduleDetailChoice(
                            text = day.localizedFullName(),
                            selected = day in frequency.days,
                            onClick = {
                                val next = if (day in frequency.days) frequency.days - day else frequency.days + day
                                onFrequencyChange(frequency.copy(days = next))
                            },
                            modifier = Modifier.weight(1f),
                        )
                    }
                    if (row.size == 1) Spacer(modifier = Modifier.weight(1f))
                }
            }
        }
        is FrequencyDraft.Monthly -> ScheduleDetailsSection(
            title = stringResourceCompat(R.string.composer_schedule_details_monthly),
        ) {
            CalendarToggle(
                calendar = frequency.calendar,
                onChange = { onFrequencyChange(frequency.copy(calendar = it)) },
            )
            ScheduleDetailDayGrid(
                selected = frequency.daysOfMonth,
                onToggle = { day ->
                    val next = if (day in frequency.daysOfMonth) frequency.daysOfMonth - day else frequency.daysOfMonth + day
                    onFrequencyChange(frequency.copy(daysOfMonth = next))
                },
            )
        }
        is FrequencyDraft.SpecificDates -> ScheduleDetailsSection(
            title = stringResourceCompat(R.string.composer_schedule_details_specific_dates),
        ) {
            OutlinedTextField(
                value = frequency.dateText,
                onValueChange = { onFrequencyChange(FrequencyDraft.SpecificDates(it)) },
                modifier = Modifier.fillMaxWidth(),
                label = { Text(stringResourceCompat(R.string.preset_specific_dates)) },
                placeholder = { Text(stringResourceCompat(R.string.composer_specific_hint)) },
                shape = RoundedCornerShape(16.dp),
                singleLine = false,
                minLines = 3,
            )
        }
        is FrequencyDraft.Interval -> ScheduleDetailsSection(
            title = stringResourceCompat(R.string.composer_schedule_details_interval),
        ) {
            CountInputField(
                value = frequency.intervalDays,
                onValueChange = { onFrequencyChange(FrequencyDraft.Interval(it)) },
                label = stringResourceCompat(R.string.create_goal_days_label),
                quickValues = listOf(2, 3, 7, 10),
            )
        }
        is FrequencyDraft.Yearly -> ScheduleDetailsSection(
            title = stringResourceCompat(R.string.composer_schedule_details_yearly),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SectionLabel(stringResourceCompat(R.string.composer_month))
                Spacer(modifier = Modifier.weight(1f))
                CalendarToggle(
                    calendar = frequency.calendar,
                    onChange = { onFrequencyChange(frequency.copy(calendar = it)) },
                )
            }
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                (1..12).forEach { month ->
                    ScheduleDetailChoice(
                        text = monthLabel(month, frequency.calendar),
                        selected = month == frequency.month,
                        onClick = { onFrequencyChange(frequency.copy(month = month)) },
                    )
                }
            }
            SectionLabel(stringResourceCompat(R.string.create_goal_pick_days_month))
            ScheduleDetailDayGrid(
                selected = frequency.days,
                onToggle = { day ->
                    val next = if (day in frequency.days) frequency.days - day else frequency.days + day
                    onFrequencyChange(frequency.copy(days = next))
                },
            )
        }
        is FrequencyDraft.Season -> ScheduleDetailsSection(
            title = stringResourceCompat(R.string.composer_schedule_details_season),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SeasonTemplateCode.entries.forEach { season ->
                    ScheduleDetailChoice(
                        text = season.localizedName(),
                        selected = season == frequency.seasonTemplateCode,
                        onClick = { onFrequencyChange(FrequencyDraft.Season(season, isConfigured = true)) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
        FrequencyDraft.Daily -> Unit
    }
}

@Composable
private fun ScheduleDetailsSection(
    title: String,
    content: @Composable () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        content()
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ScheduleDetailDayGrid(
    selected: Set<Int>,
    onToggle: (Int) -> Unit,
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        (1..31).forEach { day ->
            ScheduleDetailChoice(
                text = day.toString(),
                selected = day in selected,
                onClick = { onToggle(day) },
                modifier = Modifier.width(48.dp),
            )
        }
    }
}

@Composable
private fun ScheduleDetailChoice(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val accent = composerAccent()
    Surface(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(14.dp),
        color = if (selected) {
            MaterialTheme.colorScheme.primaryContainer.copy(alpha = if (isAwradDarkTheme()) 0.5f else 0.7f)
        } else {
            MaterialTheme.colorScheme.surfaceContainerLow
        },
        border = BorderStroke(
            width = if (selected) 1.5.dp else 1.dp,
            color = if (selected) accent else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f),
        ),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 13.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = text,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun ScheduleStepOptionCard(
    option: ScheduleStepOption,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val accent = composerAccent()
    val container = if (selected) {
        MaterialTheme.colorScheme.primaryContainer.copy(alpha = if (isAwradDarkTheme()) 0.5f else 0.7f)
    } else {
        MaterialTheme.colorScheme.surfaceContainerLow
    }
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        color = container,
        border = BorderStroke(
            width = if (selected) 1.5.dp else 1.dp,
            color = if (selected) accent else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f),
        ),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 18.dp, vertical = 17.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResourceCompat(option.labelRes),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
            if (selected) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = null,
                    tint = accent,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}

// ─── Goal sentence hero ──────────────────────────────────────────────────────

@Composable
private fun GoalSentenceHero(
    sentence: String,
    collapsed: Boolean,
    modifier: Modifier = Modifier,
) {
    val accent = composerAccent()
    // Expanded: an inset rounded card. Collapsed: the accent tint fills the whole top strip
    // edge-to-edge so it reads as a header band, not a floating slab. Animate between the two.
    val sideMargin by animateDpAsState(if (collapsed) 0.dp else 20.dp, label = "heroSideMargin")
    val topMargin by animateDpAsState(if (collapsed) 0.dp else 8.dp, label = "heroTopMargin")
    val bottomMargin by animateDpAsState(if (collapsed) 0.dp else 8.dp, label = "heroBottomMargin")
    val corner by animateDpAsState(if (collapsed) 0.dp else 22.dp, label = "heroCorner")
    val contentVertical by animateDpAsState(if (collapsed) 12.dp else 18.dp, label = "heroContentVertical")
    val accentHeight by animateDpAsState(if (collapsed) 24.dp else 54.dp, label = "heroAccent")
    val sentenceSize by animateFloatAsState(if (collapsed) 16f else 22f, label = "heroFontSize")
    val sentenceLineHeight by animateFloatAsState(if (collapsed) 22f else 30f, label = "heroLineHeight")

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = sideMargin, end = sideMargin, top = topMargin, bottom = bottomMargin),
        shape = RoundedCornerShape(corner),
        color = accent.copy(alpha = if (isAwradDarkTheme()) 0.16f else 0.12f),
    ) {
        Row(modifier = Modifier.padding(horizontal = 20.dp, vertical = contentVertical)) {
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .height(accentHeight)
                    .clip(RoundedCornerShape(2.dp))
                    .background(accent),
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column {
                AnimatedVisibility(visible = !collapsed) {
                    Column {
                        Text(
                            text = stringResourceCompat(R.string.composer_your_goal).uppercase(),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = accent,
                            letterSpacing = 1.5.sp,
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                    }
                }
                Text(
                    text = sentence,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = sentenceSize.sp,
                    lineHeight = sentenceLineHeight.sp,
                    maxLines = if (collapsed) 2 else Int.MAX_VALUE,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

// ─── Goal type grid ──────────────────────────────────────────────────────────

@Composable
private fun GoalTypeGrid(
    selected: ComposerType,
    onSelect: (ComposerType) -> Unit,
) {
    val rows = ComposerType.entries.chunked(2)
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                row.forEach { type ->
                    GoalTypeCard(
                        type = type,
                        selected = type == selected,
                        onClick = { onSelect(type) },
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun GoalTypeCard(
    type: ComposerType,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val accent = composerAccent()
    val container = if (selected) {
        MaterialTheme.colorScheme.primaryContainer.copy(alpha = if (isAwradDarkTheme()) 0.5f else 0.7f)
    } else {
        MaterialTheme.colorScheme.surfaceContainerLow
    }
    val border = if (selected) accent else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.32f)
    val iconTint = if (selected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.primary

    Surface(
        modifier = modifier
            .height(124.dp)
            .clip(RoundedCornerShape(20.dp))
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(20.dp),
        color = container,
        border = BorderStroke(if (selected) 1.5.dp else 1.dp, border),
    ) {
        Box(modifier = Modifier.padding(16.dp)) {
            Column(modifier = Modifier.fillMaxSize()) {
                Icon(
                    imageVector = type.icon,
                    contentDescription = null,
                    tint = iconTint,
                    modifier = Modifier.size(26.dp),
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = stringResourceCompat(type.titleRes),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = stringResourceCompat(type.descRes),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (selected) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .size(22.dp)
                        .clip(RoundedCornerShape(50))
                        .background(accent),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Filled.Check,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(14.dp),
                    )
                }
            }
        }
    }
}

// ─── Per-type configuration ──────────────────────────────────────────────────

@Composable
private fun ComposerConfig(
    type: ComposerType,
    draft: GoalDraft,
    onTargetChange: (TargetDraft) -> Unit,
    onFrequencyChange: (FrequencyDraft) -> Unit,
    onDraftChange: (GoalDraft) -> Unit,
    includeSchedule: Boolean,
    showTimingSelector: Boolean,
) {
    when (type) {
        ComposerType.Daily -> CountTimingConfig(
            draft = draft,
            quickValues = listOf(33, 70, 100, 313),
            onTargetChange = onTargetChange,
            onDraftChange = onDraftChange,
            showTimingSelector = showTimingSelector,
        )
        ComposerType.OneTime -> if (showTimingSelector) {
            ConfigCard {
                AnytimeBucketEditor(
                    draft = draft,
                    quickValues = listOf(1000, 10000, 33000, 70000),
                    onDraftChange = onDraftChange,
                )
            }
        } else {
            CountTimingConfig(
                draft = draft,
                quickValues = listOf(1000, 10000, 33000, 70000),
                onTargetChange = onTargetChange,
                onDraftChange = onDraftChange,
                showTimingSelector = false,
            )
        }
        ComposerType.Tracker -> TrackerNote()
        ComposerType.Advanced -> AdvancedConfig(
            draft = draft,
            onTargetChange = onTargetChange,
            onFrequencyChange = onFrequencyChange,
            onDraftChange = onDraftChange,
            includeSchedule = includeSchedule,
            showTimingSelector = showTimingSelector,
        )
    }
}

/** Advanced = a Daily goal plus a schedule: schedule on top, then timing + per-bucket targets. */
@Composable
private fun AdvancedConfig(
    draft: GoalDraft,
    onTargetChange: (TargetDraft) -> Unit,
    onFrequencyChange: (FrequencyDraft) -> Unit,
    onDraftChange: (GoalDraft) -> Unit,
    includeSchedule: Boolean,
    showTimingSelector: Boolean,
) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        if (includeSchedule) {
            ConfigCard {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    SectionLabel(stringResourceCompat(R.string.review_section_schedule))
                    ScheduleEditor(draft = draft, onFrequencyChange = onFrequencyChange)
                }
            }
        }
        CountTimingConfig(
            draft = draft,
            quickValues = listOf(33, 100, 1000, 10000),
            onTargetChange = onTargetChange,
            onDraftChange = onDraftChange,
            showTimingSelector = showTimingSelector,
        )
    }
}

private val COMPOSER_RULE_MODES = listOf(
    CountRuleMode.Target,
    CountRuleMode.Minimum,
    CountRuleMode.Stretch,
    CountRuleMode.Exact,
    CountRuleMode.Bounded,
)

@Composable
private fun countRuleModeLabel(mode: CountRuleMode): String = stringResourceCompat(
    when (mode) {
        CountRuleMode.Target -> R.string.composer_rule_target
        CountRuleMode.Minimum -> R.string.composer_rule_minimum
        CountRuleMode.Stretch -> R.string.composer_rule_stretch
        CountRuleMode.Exact -> R.string.composer_rule_exact
        CountRuleMode.Bounded -> R.string.composer_rule_range
        CountRuleMode.Tracker -> R.string.composer_type_tracker_title
    },
)

@Composable
private fun countRuleModeDescription(mode: CountRuleMode): String = stringResourceCompat(
    when (mode) {
        CountRuleMode.Target -> R.string.composer_rule_target_desc
        CountRuleMode.Minimum -> R.string.composer_rule_minimum_desc
        CountRuleMode.Stretch -> R.string.composer_rule_stretch_desc
        CountRuleMode.Exact -> R.string.composer_rule_exact_desc
        CountRuleMode.Bounded -> R.string.composer_rule_range_desc
        CountRuleMode.Tracker -> R.string.composer_type_tracker_desc
    },
)

/**
 * Timing defines the buckets; each bucket (Anytime = one, After-prayers = per prayer,
 * Custom = N sessions) gets its own counting rule + target.
 */
@Composable
private fun CountTimingConfig(
    draft: GoalDraft,
    quickValues: List<Int>,
    onTargetChange: (TargetDraft) -> Unit,
    onDraftChange: (GoalDraft) -> Unit,
    showTimingSelector: Boolean,
) {
    val timing = GoalDraftMapper.effectiveTiming(draft)
    ConfigCard {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (showTimingSelector) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    SectionLabel(stringResourceCompat(R.string.create_goal_timing))
                    ComposerSelect(
                        options = listOf(
                            SelectOption(GoalTimingDraft.Anytime, stringResourceCompat(R.string.timing_anytime), stringResourceCompat(R.string.timing_anytime_desc)),
                            SelectOption(GoalTimingDraft.PrayerBased, stringResourceCompat(R.string.timing_prayer_based), stringResourceCompat(R.string.timing_prayer_desc)),
                            SelectOption(GoalTimingDraft.CustomSlots, stringResourceCompat(R.string.composer_timing_custom)),
                        ),
                        selected = timing,
                        sheetTitle = stringResourceCompat(R.string.create_goal_timing),
                        onSelect = { selection -> if (selection != timing) applyTimingSelection(draft, selection, onDraftChange) },
                    )
                }
            }
            when (timing) {
                GoalTimingDraft.Anytime -> AnytimeBucketEditor(draft, quickValues, onDraftChange)
                GoalTimingDraft.PrayerBased -> PrayerBucketEditor(
                    draft = draft,
                    target = draft.targetDraft as? TargetDraft.PrayerBased ?: TargetDraft.PrayerBased(),
                    onTargetChange = onTargetChange,
                    onDraftChange = onDraftChange,
                )
                GoalTimingDraft.CustomSlots -> {
                    SessionsRuleSelector(draft = draft, onDraftChange = onDraftChange)
                    CustomSessionsEditor(draft = draft, mode = draft.countRule.mode, onDraftChange = onDraftChange)
                }
                else -> Unit
            }
        }
    }
}

/** Switches the timing axis, converting the target shape (fixed ↔ per-prayer) to match. */
private fun applyTimingSelection(
    draft: GoalDraft,
    selection: GoalTimingDraft,
    onDraftChange: (GoalDraft) -> Unit,
) {
    when (selection) {
        GoalTimingDraft.Anytime -> onDraftChange(
            draft.copy(
                timingType = TimingType.ANYTIME,
                advancedTiming = GoalTimingDraft.Anytime,
                slotTargetMode = SlotTargetMode.Same,
                targetDraft = fixedTargetFrom(draft),
            )
        )
        GoalTimingDraft.PrayerBased -> onDraftChange(
            draft.copy(
                timingType = TimingType.PRAYER_BASED,
                advancedTiming = GoalTimingDraft.PrayerBased,
                slotTargetMode = SlotTargetMode.Same,
                targetDraft = (draft.targetDraft as? TargetDraft.PrayerBased
                    ?: TargetDraft.PrayerBased(
                        timing = PrayerTiming.AFTER,
                        selectedPrayers = Prayer.entries.toSet(),
                        uniformCount = draft.countRule.targetCount.ifBlank { "33" },
                    )).copy(uniform = true),
            )
        )
        GoalTimingDraft.CustomSlots -> onDraftChange(
            draft.copy(
                timingType = TimingType.TIME_BASED,
                advancedTiming = GoalTimingDraft.CustomSlots,
                slotTargetMode = SlotTargetMode.Same,
                targetDraft = fixedTargetFrom(draft),
            )
        )
        GoalTimingDraft.MorningEvening -> Unit
    }
}

private fun fixedTargetFrom(draft: GoalDraft): TargetDraft = when (val t = draft.targetDraft) {
    is TargetDraft.Fixed -> t
    is TargetDraft.PrayerBased -> TargetDraft.Fixed(t.uniformCount.ifBlank { draft.countRule.targetCount })
    TargetDraft.None -> draft.targetDraft
}

/** The single (Anytime) bucket — keeps the global rule + targetDraft in sync for the goal sentence. */
@Composable
private fun AnytimeBucketEditor(
    draft: GoalDraft,
    quickValues: List<Int>,
    onDraftChange: (GoalDraft) -> Unit,
) {
    BucketRuleEditor(
        rule = draft.countRule,
        quickValues = quickValues,
        onRuleChange = { rule ->
            onDraftChange(
                draft.copy(
                    countRule = rule,
                    targetDraft = if (rule.mode == CountRuleMode.Target) TargetDraft.Fixed(rule.targetCount) else draft.targetDraft,
                )
            )
        },
    )
}

/** Counting-rule select on top, then the target input(s) the rule needs. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BucketRuleEditor(
    rule: CountRuleDraft,
    quickValues: List<Int>,
    onRuleChange: (CountRuleDraft) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionLabel(stringResourceCompat(R.string.composer_counting_rule))
        ComposerSelect(
            options = COMPOSER_RULE_MODES.map { SelectOption(it, countRuleModeLabel(it), countRuleModeDescription(it)) },
            selected = rule.mode,
            sheetTitle = stringResourceCompat(R.string.composer_counting_rule),
            onSelect = { mode -> onRuleChange(seedRuleForMode(rule, mode, rule.countForPersistence())) },
        )
        when (rule.mode) {
            CountRuleMode.Target, CountRuleMode.Tracker -> {
                CountStepperBar(
                    value = rule.targetCount,
                    onValueChange = { onRuleChange(rule.copy(targetCount = it)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                if (quickValues.isNotEmpty()) {
                    QuickValueChips(quickValues, rule.targetCount) { onRuleChange(rule.copy(targetCount = it)) }
                }
            }
            CountRuleMode.Minimum -> LabeledStepperRow(
                label = stringResourceCompat(R.string.composer_rule_minimum_label),
                value = rule.minimumCount,
                onChange = { onRuleChange(rule.copy(minimumCount = it)) },
            )
            CountRuleMode.Exact -> LabeledStepperRow(
                label = stringResourceCompat(R.string.composer_rule_target_label),
                value = rule.maximumCount,
                onChange = { onRuleChange(rule.copy(maximumCount = it)) },
            )
            CountRuleMode.Stretch -> {
                LabeledStepperRow(stringResourceCompat(R.string.composer_rule_minimum_label), rule.minimumCount) { onRuleChange(rule.copy(minimumCount = it)) }
                LabeledStepperRow(stringResourceCompat(R.string.composer_rule_target_label), rule.targetCount) { onRuleChange(rule.copy(targetCount = it)) }
            }
            CountRuleMode.Bounded -> {
                LabeledStepperRow(stringResourceCompat(R.string.composer_rule_minimum_label), rule.minimumCount) { onRuleChange(rule.copy(minimumCount = it)) }
                LabeledStepperRow(stringResourceCompat(R.string.composer_rule_target_label), rule.targetCount) { onRuleChange(rule.copy(targetCount = it)) }
                LabeledStepperRow(stringResourceCompat(R.string.composer_rule_max_label), rule.maximumCount) { onRuleChange(rule.copy(maximumCount = it)) }
            }
        }
        if (rule.mode == CountRuleMode.Bounded) {
            SectionLabel(stringResourceCompat(R.string.composer_cap_behavior))
            ComposerSelect(
                options = capBehaviorOptions().map { (behavior, textRes) -> SelectOption(behavior, stringResourceCompat(textRes)) },
                selected = rule.capBehavior,
                sheetTitle = stringResourceCompat(R.string.composer_cap_behavior),
                onSelect = { behavior -> onRuleChange(rule.copy(capBehavior = behavior)) },
            )
        }
    }
}

// ─── Editable stepper bar:  [ −  |  33  |  + ]  ───────────────────────────────

@Composable
private fun CountStepperBar(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    step: Int = 1,
) {
    val current = value.toIntOrNull()
    val canDecrease = (current ?: 1) > 1
    Surface(
        modifier = modifier.height(54.dp),
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surfaceContainerHighest,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
    ) {
        Row(modifier = Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            StepperEnd(
                icon = Icons.Filled.Remove,
                enabled = canDecrease,
                onClick = { onValueChange(((current ?: 1) - step).coerceAtLeast(1).toString()) },
            )
            StepperDivider()
            BasicTextField(
                value = value,
                onValueChange = { next -> if (next.isEmpty() || next.all(Char::isDigit)) onValueChange(next) },
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 8.dp),
                textStyle = MaterialTheme.typography.titleLarge.copy(
                    textAlign = TextAlign.Center,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                ),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                decorationBox = { inner ->
                    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { inner() }
                },
            )
            StepperDivider()
            StepperEnd(
                icon = Icons.Filled.Add,
                enabled = true,
                onClick = { onValueChange(((current ?: 0) + step).coerceAtLeast(1).toString()) },
            )
        }
    }
}

@Composable
private fun StepperEnd(icon: ImageVector, enabled: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxHeight()
            .width(52.dp)
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (enabled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
            modifier = Modifier.size(20.dp),
        )
    }
}

@Composable
private fun StepperDivider() {
    Box(
        modifier = Modifier
            .width(1.dp)
            .fillMaxHeight()
            .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
    )
}

@Composable
private fun LabeledStepperRow(label: String, value: String, onChange: (String) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        CountStepperBar(value = value, onValueChange = onChange, modifier = Modifier.width(168.dp))
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun QuickValueChips(quickValues: List<Int>, current: String, onPick: (String) -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        quickValues.forEach { qv ->
            ComposerPill(
                text = "%,d".format(qv),
                selected = current == qv.toString(),
                onClick = { onPick(qv.toString()) },
            )
        }
    }
}

/** One counting rule for the whole goal; sessions then set only their amounts. */
@Composable
private fun SessionsRuleSelector(draft: GoalDraft, onDraftChange: (GoalDraft) -> Unit) {
    val rule = draft.countRule
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        SectionLabel(stringResourceCompat(R.string.composer_counting_rule))
        ComposerSelect(
            options = COMPOSER_RULE_MODES.map { SelectOption(it, countRuleModeLabel(it), countRuleModeDescription(it)) },
            selected = rule.mode,
            sheetTitle = stringResourceCompat(R.string.composer_counting_rule),
            onSelect = { mode -> onDraftChange(setSessionsRuleMode(draft, mode)) },
        )
        if (rule.mode == CountRuleMode.Bounded) {
            SectionLabel(stringResourceCompat(R.string.composer_cap_behavior))
            ComposerSelect(
                options = capBehaviorOptions().map { (behavior, textRes) -> SelectOption(behavior, stringResourceCompat(textRes)) },
                selected = rule.capBehavior,
                sheetTitle = stringResourceCompat(R.string.composer_cap_behavior),
                onSelect = { behavior -> onDraftChange(setSessionsCap(draft, behavior)) },
            )
        }
    }
}

/** Applies a shared rule mode to the goal and every session (seeding each session's amounts). */
private fun setSessionsRuleMode(draft: GoalDraft, mode: CountRuleMode): GoalDraft {
    val goalRule = seedRuleForMode(draft.countRule, mode, draft.countRule.countForPersistence())
    val slots = draft.timeSlots.map { slot ->
        val seeded = seedRuleForMode(
            slot.toCountRule().copy(capBehavior = goalRule.capBehavior),
            mode,
            slot.toCountRule().countForPersistence(),
        )
        slot.withCountRule(seeded)
    }
    return draft.copy(countRule = goalRule, timeSlots = slots)
}

private fun setSessionsCap(draft: GoalDraft, cap: CapBehavior): GoalDraft =
    draft.copy(
        countRule = draft.countRule.copy(capBehavior = cap),
        timeSlots = draft.timeSlots.map { it.copy(capBehavior = cap) },
    )

/** Per-session amount input(s) for the goal's shared rule mode — no rule selector. */
@Composable
private fun SlotAmountEditor(
    mode: CountRuleMode,
    slot: GoalTimeSlotDraft,
    onChange: (GoalTimeSlotDraft) -> Unit,
) {
    when (mode) {
        CountRuleMode.Target, CountRuleMode.Tracker -> LabeledStepperRow(
            label = stringResourceCompat(R.string.composer_count),
            value = slot.targetCount,
            onChange = { onChange(slot.copy(targetCount = it)) },
        )
        CountRuleMode.Minimum -> LabeledStepperRow(
            label = stringResourceCompat(R.string.composer_rule_minimum_label),
            value = slot.minimumCount,
            onChange = { onChange(slot.copy(minimumCount = it)) },
        )
        CountRuleMode.Exact -> LabeledStepperRow(
            label = stringResourceCompat(R.string.composer_rule_target_label),
            value = slot.maximumCount,
            onChange = { onChange(slot.copy(maximumCount = it)) },
        )
        CountRuleMode.Stretch -> {
            LabeledStepperRow(stringResourceCompat(R.string.composer_rule_minimum_label), slot.minimumCount) { onChange(slot.copy(minimumCount = it)) }
            LabeledStepperRow(stringResourceCompat(R.string.composer_rule_target_label), slot.targetCount) { onChange(slot.copy(targetCount = it)) }
        }
        CountRuleMode.Bounded -> {
            LabeledStepperRow(stringResourceCompat(R.string.composer_rule_minimum_label), slot.minimumCount) { onChange(slot.copy(minimumCount = it)) }
            LabeledStepperRow(stringResourceCompat(R.string.composer_rule_target_label), slot.targetCount) { onChange(slot.copy(targetCount = it)) }
            LabeledStepperRow(stringResourceCompat(R.string.composer_rule_max_label), slot.maximumCount) { onChange(slot.copy(maximumCount = it)) }
        }
    }
}

private fun seedRuleForMode(rule: CountRuleDraft, mode: CountRuleMode, currentCount: String): CountRuleDraft {
    val base = currentCount.ifBlank { rule.targetCount.ifBlank { "100" } }
    return when (mode) {
        CountRuleMode.Target, CountRuleMode.Tracker -> rule.copy(mode = mode, targetCount = base)
        CountRuleMode.Minimum -> rule.copy(mode = mode, minimumCount = rule.minimumCount.ifBlank { base })
        CountRuleMode.Exact -> rule.copy(mode = mode, maximumCount = rule.maximumCount.ifBlank { base })
        CountRuleMode.Stretch -> rule.copy(
            mode = mode,
            minimumCount = rule.minimumCount.ifBlank { base },
            targetCount = rule.targetCount.ifBlank { base },
        )
        CountRuleMode.Bounded -> rule.copy(
            mode = mode,
            minimumCount = rule.minimumCount.ifBlank { base },
            targetCount = rule.targetCount.ifBlank { base },
            maximumCount = rule.maximumCount.ifBlank { base },
        )
    }
}

private fun capBehaviorOptions(): List<Pair<CapBehavior, Int>> = listOf(
    CapBehavior.AllowOverTarget to R.string.composer_cap_allow,
    CapBehavior.WarnOverTarget to R.string.composer_cap_warn,
    CapBehavior.BlockAtTarget to R.string.composer_cap_block_target,
    CapBehavior.BlockAtMaximum to R.string.composer_cap_block_max,
)


@Composable
private fun PrayerBucketEditor(
    draft: GoalDraft,
    target: TargetDraft.PrayerBased,
    onTargetChange: (TargetDraft) -> Unit,
    onDraftChange: (GoalDraft) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        // Which prayers (multi-select)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SectionLabel(stringResourceCompat(R.string.composer_prayer_which))
            PrayerRelationsSheet(
                target = target,
                onTargetChange = { onTargetChange(it) },
            )
        }
        // Per-prayer toggle
        SwitchRow(
            label = stringResourceCompat(R.string.composer_per_prayer),
            checked = !target.uniform,
            onCheckedChange = { perPrayer ->
                if (perPrayer) {
                    onTargetChange(target.copy(uniform = false))
                } else {
                    onTargetChange(
                        target.copy(
                            uniform = true,
                            perPrayerCounts = emptyMap(),
                            perPrayerRelationCounts = emptyMap(),
                        )
                    )
                }
            },
        )
        // Count(s)
        if (target.uniform) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionLabel(stringResourceCompat(R.string.composer_count_each_prayer))
                CountInputField(
                    value = target.uniformCount,
                    onValueChange = { onTargetChange(target.copy(uniformCount = it)) },
                    label = "",
                    quickValues = listOf(3, 33, 100, 313),
                )
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SectionLabel(stringResourceCompat(R.string.composer_count_each_prayer))
                Prayer.entries.filter { it in target.selectedPrayers }.forEach { prayer ->
                    CompactCountRow(
                        label = prayer.localizedName(),
                        value = target.countFor(prayer),
                        onChange = { onTargetChange(target.withCountFor(prayer, it)) },
                    )
                }
            }
        }
        // Before-prayer lead overrides (only when counting before prayers)
        if (target.selectedPrayers.any { PrayerRelation.BEFORE in target.relationsFor(it) }) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SectionLabel(stringResourceCompat(R.string.composer_lead_before))
                Prayer.entries.filter {
                    it in target.selectedPrayers && PrayerRelation.BEFORE in target.relationsFor(it)
                }.forEach { prayer ->
                    CompactCountRow(
                        label = prayer.localizedName(),
                        value = target.beforePrayerLeadOverrides[prayer] ?: "10",
                        onChange = {
                            onTargetChange(
                                target.copy(beforePrayerLeadOverrides = target.beforePrayerLeadOverrides + (prayer to it)),
                            )
                        },
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PrayerRelationsSheet(
    target: TargetDraft.PrayerBased,
    onTargetChange: (TargetDraft.PrayerBased) -> Unit,
) {
    var open by remember { mutableStateOf(false) }
    var showSelectionError by remember { mutableStateOf(false) }
    val hasActiveSelection = rememberUpdatedState(target.selectedPrayers.isNotEmpty())
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = { value ->
            if (value == SheetValue.Hidden && !hasActiveSelection.value) {
                showSelectionError = true
                false
            } else {
                true
            }
        },
    )
    val dismissSheet = {
        if (!hasActiveSelection.value) {
            showSelectionError = true
        } else {
            showSelectionError = false
            open = false
        }
    }

    LaunchedEffect(target.selectedPrayers.isNotEmpty()) {
        if (target.selectedPrayers.isNotEmpty()) showSelectionError = false
    }

    SelectField(
        text = prayersSummary(target.selectedPrayers),
        onClick = {
            showSelectionError = false
            open = true
        },
    )

    if (open) {
        ModalBottomSheet(
            onDismissRequest = dismissSheet,
            sheetState = sheetState,
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(horizontal = 20.dp)
                    .padding(bottom = 20.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                SheetHeader(title = stringResourceCompat(R.string.composer_prayer_which))
                if (showSelectionError) {
                    Text(
                        text = stringResourceCompat(R.string.composer_prayer_select_relation),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
                PrayerRelationSwitch(
                    label = stringResourceCompat(R.string.composer_prayer_before_all),
                    checked = Prayer.entries.all { PrayerRelation.BEFORE in target.relationsFor(it) },
                    onCheckedChange = { enabled ->
                        val next = target.withRelationForAll(PrayerRelation.BEFORE, enabled)
                        onTargetChange(next)
                    },
                )
                PrayerRelationSwitch(
                    label = stringResourceCompat(R.string.composer_prayer_after_all),
                    checked = Prayer.entries.all { PrayerRelation.AFTER in target.relationsFor(it) },
                    onCheckedChange = { enabled ->
                        val next = target.withRelationForAll(PrayerRelation.AFTER, enabled)
                        onTargetChange(next)
                    },
                )
                Prayer.entries.forEach { prayer ->
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        color = MaterialTheme.colorScheme.surfaceContainerLow,
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f)),
                    ) {
                        Column(
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Text(
                                text = prayer.localizedName(),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                val relations = target.relationsFor(prayer)
                                PrayerRelationSwitch(
                                    label = stringResourceCompat(R.string.prayer_relation_before),
                                    checked = PrayerRelation.BEFORE in relations,
                                    modifier = Modifier.weight(1f),
                                    onCheckedChange = { checked ->
                                        val nextRelations = if (checked) {
                                            relations + PrayerRelation.BEFORE
                                        } else {
                                            relations - PrayerRelation.BEFORE
                                        }
                                        val next = target.withRelationsFor(prayer, nextRelations)
                                        onTargetChange(next)
                                    },
                                )
                                PrayerRelationSwitch(
                                    label = stringResourceCompat(R.string.prayer_relation_after),
                                    checked = PrayerRelation.AFTER in relations,
                                    modifier = Modifier.weight(1f),
                                    onCheckedChange = { checked ->
                                        val nextRelations = if (checked) {
                                            relations + PrayerRelation.AFTER
                                        } else {
                                            relations - PrayerRelation.AFTER
                                        }
                                        val next = target.withRelationsFor(prayer, nextRelations)
                                        onTargetChange(next)
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PrayerRelationSwitch(
    label: String,
    checked: Boolean,
    modifier: Modifier = Modifier,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Checkbox(
            checked = checked,
            onCheckedChange = onCheckedChange,
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun prayersSummary(selected: Set<Prayer>): String {
    if (selected.size == Prayer.entries.size) {
        return stringResourceCompat(R.string.composer_prayers_all)
    }
    val names = Prayer.entries.filter { it in selected }.map { it.localizedName() }
    return names.joinToString(", ")
}

@Composable
private fun CompactCountRow(
    label: String,
    value: String,
    onChange: (String) -> Unit,
) = LabeledStepperRow(label = label, value = value, onChange = onChange)

@Composable
private fun TrackerNote() {
    ConfigCard {
        Row(
            modifier = Modifier.padding(2.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.6f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Outlined.AllInclusive,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                    modifier = Modifier.size(22.dp),
                )
            }
            Text(
                text = stringResourceCompat(R.string.composer_tracker_note),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

// ─── Fine-tune (inline progressive disclosure) ───────────────────────────────

@Composable
private fun FineTuneSection(
    draft: GoalDraft,
    onExtrasChange: (ExtrasDraft) -> Unit,
) {
    // Timing + per-bucket targets now live in the primary config card; fine-tune is
    // just the cross-cutting extras.
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        TuneRow(
            icon = Icons.Outlined.Notifications,
            title = stringResourceCompat(R.string.review_section_reminders),
        ) {
            ReminderEditor(draft = draft, onExtrasChange = onExtrasChange)
        }
        TuneRow(
            icon = Icons.Outlined.Flag,
            title = stringResourceCompat(R.string.review_section_duration),
        ) {
            DurationEditor(draft = draft, onExtrasChange = onExtrasChange)
        }
    }
}

@Composable
private fun CustomSessionsEditor(
    draft: GoalDraft,
    mode: CountRuleMode,
    onDraftChange: (GoalDraft) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        draft.timeSlots.forEachIndexed { index, slot ->
            SessionCard(
                index = index,
                slot = slot,
                mode = mode,
                canRemove = draft.timeSlots.size > 1,
                onChange = { updated ->
                    onDraftChange(draft.copy(timeSlots = draft.timeSlots.map { if (it.id == slot.id) updated else it }))
                },
                onRemove = {
                    onDraftChange(draft.copy(timeSlots = draft.timeSlots.filterNot { it.id == slot.id }))
                },
            )
        }
        TextButton(
            onClick = {
                val next = GoalTimeSlotDraft(
                    label = "Session ${draft.timeSlots.size + 1}",
                    startHour = (8 + draft.timeSlots.size * 4).coerceAtMost(22),
                ).withCountRule(seedRuleForMode(draft.countRule, mode, draft.countRule.countForPersistence()))
                onDraftChange(draft.copy(timeSlots = draft.timeSlots + next))
            },
        ) {
            Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(6.dp))
            Text(stringResourceCompat(R.string.composer_add_session))
        }
    }
}

@Composable
private fun SessionCard(
    index: Int,
    slot: GoalTimeSlotDraft,
    mode: CountRuleMode,
    canRemove: Boolean,
    onChange: (GoalTimeSlotDraft) -> Unit,
    onRemove: () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.5f),
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = stringResourceCompat(R.string.composer_session, index + 1),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )
                if (canRemove) {
                    TextButton(onClick = onRemove) {
                        Text(stringResourceCompat(R.string.composer_remove), color = MaterialTheme.colorScheme.error)
                    }
                }
            }
            // Start time (real time picker)
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = stringResourceCompat(R.string.composer_starts_at),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )
                ComposerTimeField(
                    hour = slot.startHour,
                    minute = slot.startMinute,
                    onTimeChange = { h, m -> onChange(slot.copy(startHour = h, startMinute = m)) },
                )
            }
            // Length (stepped by 15 min)
            StepperRow(
                label = stringResourceCompat(R.string.composer_length),
                valueText = durationText(slot.durationMinutes),
                onDecrease = { onChange(slot.copy(durationMinutes = (slot.durationMinutes - 15).coerceAtLeast(15))) },
                onIncrease = { onChange(slot.copy(durationMinutes = (slot.durationMinutes + 15).coerceAtMost(24 * 60))) },
            )
            androidx.compose.material3.HorizontalDivider(
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f),
            )
            SlotAmountEditor(mode = mode, slot = slot, onChange = onChange)
        }
    }
}

@Composable
private fun StepperRow(
    label: String,
    valueText: String,
    onDecrease: () -> Unit,
    onIncrease: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        FilledTonalIconButton(onClick = onDecrease, modifier = Modifier.size(40.dp)) {
            Icon(Icons.Filled.Remove, contentDescription = null, modifier = Modifier.size(18.dp))
        }
        Text(
            text = valueText,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier.width(76.dp),
        )
        FilledTonalIconButton(onClick = onIncrease, modifier = Modifier.size(40.dp)) {
            Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(18.dp))
        }
    }
}

private fun clockText(minuteOfDay: Int): String {
    val h = (minuteOfDay / 60) % 24
    val m = minuteOfDay % 60
    return "%02d:%02d".format(h, m)
}

private fun durationText(minutes: Int): String {
    val h = minutes / 60
    val m = minutes % 60
    return when {
        h > 0 && m > 0 -> "${h}h ${m}m"
        h > 0 -> "${h}h"
        else -> "${m}m"
    }
}

@Composable
private fun TuneRow(
    icon: ImageVector,
    title: String,
    editor: @Composable () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.28f)),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(RoundedCornerShape(13.dp))
                        .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.55f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.size(20.dp),
                    )
                }
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            editor()
        }
    }
}

@Composable
private fun ScheduleEditor(
    draft: GoalDraft,
    onFrequencyChange: (FrequencyDraft) -> Unit,
) {
    val frequency = draft.frequencyDraft
    val currentMode = frequency.scheduleMode()
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        ComposerSelect(
            options = ScheduleMode.entries.map { SelectOption(it, scheduleModeLabel(it), trailingHint = scheduleModeExample(it)) },
            selected = currentMode,
            sheetTitle = stringResourceCompat(R.string.review_section_schedule),
            onSelect = { mode -> if (mode != currentMode) onFrequencyChange(defaultFrequencyFor(mode)) },
        )
        when (frequency) {
            is FrequencyDraft.Weekly -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionLabel(stringResourceCompat(R.string.composer_days_of_week))
                ComposerChipMultiSelect(
                    options = DayOfWeek.entries.map { it to it.localizedShortName() },
                    selected = frequency.days,
                    sheetTitle = stringResourceCompat(R.string.composer_days_of_week),
                    summary = weekdaysSummary(frequency.days),
                    onToggle = { day ->
                        val next = if (day in frequency.days) frequency.days - day else frequency.days + day
                        onFrequencyChange(frequency.copy(days = next))
                    },
                )
            }
            is FrequencyDraft.Interval -> CountInputField(
                value = frequency.intervalDays,
                onValueChange = { onFrequencyChange(FrequencyDraft.Interval(it)) },
                label = stringResourceCompat(R.string.create_goal_days_label),
                quickValues = listOf(2, 3, 7, 10),
            )
            is FrequencyDraft.Season -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionLabel(stringResourceCompat(R.string.composer_schedule_season))
                ComposerSelect(
                    options = SeasonTemplateCode.entries.map { SelectOption(it, it.localizedName()) },
                    selected = frequency.seasonTemplateCode,
                    sheetTitle = stringResourceCompat(R.string.composer_schedule_season),
                    onSelect = { onFrequencyChange(FrequencyDraft.Season(it, isConfigured = true)) },
                )
            }
            is FrequencyDraft.Monthly -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionLabel(stringResourceCompat(R.string.create_goal_pick_days_month))
                ComposerChipMultiSelect(
                    options = (1..31).map { it to it.toString() },
                    selected = frequency.daysOfMonth,
                    sheetTitle = stringResourceCompat(R.string.create_goal_pick_days_month),
                    summary = daysOfMonthSummary(frequency.daysOfMonth),
                    onToggle = { day ->
                        val next = if (day in frequency.daysOfMonth) frequency.daysOfMonth - day else frequency.daysOfMonth + day
                        onFrequencyChange(frequency.copy(daysOfMonth = next))
                    },
                    header = {
                        CalendarToggle(
                            calendar = frequency.calendar,
                            onChange = { onFrequencyChange(frequency.copy(calendar = it)) },
                        )
                    },
                )
            }
            is FrequencyDraft.Yearly -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionLabel(stringResourceCompat(R.string.composer_month))
                ComposerSelect(
                    options = (1..12).map { SelectOption(it, monthLabel(it, frequency.calendar)) },
                    selected = frequency.month,
                    sheetTitle = stringResourceCompat(R.string.composer_month),
                    onSelect = { onFrequencyChange(frequency.copy(month = it)) },
                    header = {
                        CalendarToggle(
                            calendar = frequency.calendar,
                            onChange = { onFrequencyChange(frequency.copy(calendar = it)) },
                        )
                    },
                )
                SectionLabel(stringResourceCompat(R.string.create_goal_pick_days_month))
                ComposerChipMultiSelect(
                    options = (1..31).map { it to it.toString() },
                    selected = frequency.days,
                    sheetTitle = stringResourceCompat(R.string.create_goal_pick_days_month),
                    summary = daysOfMonthSummary(frequency.days),
                    onToggle = { day ->
                        val next = if (day in frequency.days) frequency.days - day else frequency.days + day
                        onFrequencyChange(frequency.copy(days = next))
                    },
                )
            }
            is FrequencyDraft.SpecificDates -> OutlinedTextField(
                value = frequency.dateText,
                onValueChange = { onFrequencyChange(FrequencyDraft.SpecificDates(it)) },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(stringResourceCompat(R.string.composer_specific_hint)) },
                shape = RoundedCornerShape(16.dp),
                singleLine = false,
            )
            else -> Unit
        }
    }
}

private fun monthLabel(month: Int, calendar: String): String =
    DateUtils.monthName(
        month,
        if (calendar.equals("hijri", ignoreCase = true)) CalendarSystem.HIJRI else CalendarSystem.GREGORIAN,
    )

@Composable
private fun weekdaysSummary(days: Set<DayOfWeek>): String {
    val names = DayOfWeek.entries.filter { it in days }.map { it.localizedShortName() }
    return names.joinToString(", ").ifEmpty { "—" }
}

private fun daysOfMonthSummary(days: Set<Int>): String =
    days.sorted().joinToString(", ").ifEmpty { "—" }

/** A compact two-option segmented switch (Gregorian / Hijri). */
@Composable
private fun CalendarToggle(
    calendar: String,
    onChange: (String) -> Unit,
) {
    val isHijri = calendar.equals("hijri", ignoreCase = true)
    Surface(
        shape = RoundedCornerShape(50),
        color = MaterialTheme.colorScheme.surfaceContainerHighest,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
    ) {
        Row(modifier = Modifier.padding(3.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            CalendarSegment(
                text = stringResourceCompat(R.string.composer_calendar_gregorian),
                selected = !isHijri,
                onClick = { onChange("gregorian") },
            )
            CalendarSegment(
                text = stringResourceCompat(R.string.composer_calendar_hijri),
                selected = isHijri,
                onClick = { onChange("hijri") },
            )
        }
    }
}

@Composable
private fun CalendarSegment(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (selected) MaterialTheme.colorScheme.primary else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 7.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Medium,
            color = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ReminderEditor(
    draft: GoalDraft,
    onExtrasChange: (ExtrasDraft) -> Unit,
) {
    val extras = draft.extras
    val timing = GoalDraftMapper.effectiveTiming(draft)
    val isAnytime = timing == GoalTimingDraft.Anytime
    // The toggle and helper note describe what actually gets scheduled: a daily ping for
    // anytime goals, a reminder around each prayer, or one at the start of each session.
    val reminderLabel = when (timing) {
        GoalTimingDraft.Anytime -> R.string.create_goal_daily_reminder
        GoalTimingDraft.PrayerBased -> R.string.create_goal_prayer_reminder
        GoalTimingDraft.MorningEvening,
        GoalTimingDraft.CustomSlots -> R.string.create_goal_session_reminder
    }
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SwitchRow(
            label = stringResourceCompat(reminderLabel),
            checked = extras.notificationEnabled,
            onCheckedChange = { onExtrasChange(extras.copy(notificationEnabled = it)) },
        )
        AnimatedVisibility(visible = extras.notificationEnabled) {
            if (isAnytime) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = stringResourceCompat(R.string.composer_reminder_at),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.weight(1f),
                    )
                    ComposerTimeField(
                        hour = extras.notificationHour,
                        minute = extras.notificationMinute,
                        onTimeChange = { h, m -> onExtrasChange(extras.copy(notificationHour = h, notificationMinute = m)) },
                    )
                }
            } else {
                val noteRes = if (timing == GoalTimingDraft.PrayerBased) {
                    R.string.composer_reminder_prayer_note
                } else {
                    R.string.composer_reminder_session_note
                }
                Text(
                    text = stringResourceCompat(noteRes),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun DurationEditor(
    draft: GoalDraft,
    onExtrasChange: (ExtrasDraft) -> Unit,
) {
    val extras = draft.extras
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SwitchRow(
            label = stringResourceCompat(R.string.create_goal_set_duration),
            checked = extras.hasDuration,
            onCheckedChange = { onExtrasChange(extras.copy(hasDuration = it)) },
        )
        AnimatedVisibility(visible = extras.hasDuration) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                CountInputField(
                    value = extras.durationDays,
                    onValueChange = { onExtrasChange(extras.copy(durationDays = it)) },
                    label = stringResourceCompat(R.string.create_goal_days_label),
                    quickValues = listOf(7, 30, 40, 100),
                )
                Text(
                    text = stringResourceCompat(R.string.composer_duration_days_hint),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        SwitchRow(
            label = stringResourceCompat(R.string.create_goal_min_streak),
            checked = extras.hasMinStreak,
            onCheckedChange = { onExtrasChange(extras.copy(hasMinStreak = it)) },
        )
        AnimatedVisibility(visible = extras.hasMinStreak) {
            CountInputField(
                value = extras.minStreakCount,
                onValueChange = { onExtrasChange(extras.copy(minStreakCount = it)) },
                label = "",
                quickValues = listOf(1, 10, 33, 100),
            )
        }
    }
}

@Composable
private fun SwitchRow(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onCheckedChange(!checked) },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

// ─── Create bar ──────────────────────────────────────────────────────────────

@Composable
private fun ComposerCreateBar(
    validation: GoalValidationResult,
    isCreating: Boolean,
    onCreate: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val error = validation.errors.values.firstOrNull()
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface,
        shadowElevation = 12.dp,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 20.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (error != null) {
                Text(
                    text = error.localizedText(),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            RitualPrimaryButton(
                text = stringResourceCompat(R.string.action_create_goal),
                onClick = onCreate,
                enabled = validation.isValid,
                isLoading = isCreating,
            )
        }
    }
}

@Composable
private fun ComposerNextBar(
    onNext: () -> Unit,
    enabled: Boolean = true,
    labelRes: Int = R.string.composer_set_timings,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface,
        shadowElevation = 12.dp,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 20.dp, vertical = 14.dp),
        ) {
            RitualPrimaryButton(
                text = stringResourceCompat(labelRes),
                onClick = onNext,
                enabled = enabled,
            )
        }
    }
}

// ─── Small shared pieces ─────────────────────────────────────────────────────

@Composable
private fun ConfigCard(content: @Composable () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.28f)),
    ) {
        Box(modifier = Modifier.padding(18.dp)) { content() }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun ComposerPill(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val container = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHighest
    val content = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface
    Surface(
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(14.dp),
        color = container,
        border = if (selected) null else BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Medium,
            color = content,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 9.dp),
        )
    }
}

// ─── Bottom-sheet single-select ──────────────────────────────────────────────

private data class SelectOption<T>(
    val value: T,
    val label: String,
    val description: String? = null,
    /** A short right-aligned example shown on the option row (hidden once selected). */
    val trailingHint: String? = null,
)

/** A tappable dropdown-style field that opens a modal bottom sheet of options. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun <T> ComposerSelect(
    options: List<SelectOption<T>>,
    selected: T,
    sheetTitle: String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    header: (@Composable () -> Unit)? = null,
) {
    var open by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val currentLabel = options.firstOrNull { it.value == selected }?.label.orEmpty()

    SelectField(text = currentLabel, onClick = { open = true }, modifier = modifier)

    if (open) {
        ModalBottomSheet(
            onDismissRequest = { open = false },
            sheetState = sheetState,
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
        ) {
            SelectSheetContent(
                title = sheetTitle,
                options = options,
                selected = selected,
                header = header,
                onPick = { value ->
                    onSelect(value)
                    scope.launch { sheetState.hide() }.invokeOnCompletion {
                        if (!sheetState.isVisible) open = false
                    }
                },
            )
        }
    }
}

@Composable
private fun SelectField(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surfaceContainerHighest,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = text,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
            Icon(
                imageVector = Icons.Filled.KeyboardArrowDown,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(22.dp),
            )
        }
    }
}

/** Sheet title with an optional trailing accessory (e.g. a calendar toggle). */
@Composable
private fun SheetHeader(title: String, header: (@Composable () -> Unit)? = null) {
    if (header == null) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(bottom = 8.dp),
        )
    } else {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
            header()
        }
    }
}

@Composable
private fun <T> SelectSheetContent(
    title: String,
    options: List<SelectOption<T>>,
    selected: T,
    onPick: (T) -> Unit,
    header: (@Composable () -> Unit)? = null,
) {
    val accent = composerAccent()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
            .padding(bottom = 20.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        SheetHeader(title = title, header = header)
        options.forEach { option ->
            val isSelected = option.value == selected
            val container = if (isSelected) {
                MaterialTheme.colorScheme.primaryContainer.copy(alpha = if (isAwradDarkTheme()) 0.5f else 0.7f)
            } else {
                Color.Transparent
            }
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .clickable { onPick(option.value) },
                shape = RoundedCornerShape(16.dp),
                color = container,
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = option.label,
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        option.description?.let { desc ->
                            Text(
                                text = desc,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                    if (!isSelected) {
                        option.trailingHint?.let { hint ->
                            Text(
                                text = hint,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                            )
                        }
                    }
                    if (isSelected) {
                        Box(
                            modifier = Modifier
                                .size(24.dp)
                                .clip(RoundedCornerShape(50))
                                .background(accent),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                imageVector = Icons.Filled.Check,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(15.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}

/** Multi-select whose sheet shows a wrap of selectable chips (good for day grids). */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun <T> ComposerChipMultiSelect(
    options: List<Pair<T, String>>,
    selected: Set<T>,
    sheetTitle: String,
    summary: String,
    onToggle: (T) -> Unit,
    modifier: Modifier = Modifier,
    header: (@Composable () -> Unit)? = null,
) {
    var open by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    SelectField(text = summary, onClick = { open = true }, modifier = modifier)

    if (open) {
        ModalBottomSheet(
            onDismissRequest = { open = false },
            sheetState = sheetState,
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(horizontal = 20.dp)
                    .padding(bottom = 20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                SheetHeader(title = sheetTitle, header = header)
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    options.forEach { (value, label) ->
                        ComposerPill(
                            text = label,
                            selected = value in selected,
                            onClick = { onToggle(value) },
                        )
                    }
                }
            }
        }
    }
}

// ─── Time picker ─────────────────────────────────────────────────────────────

/** A compact pill showing a time that opens a clock-dial picker on tap. */
@Composable
private fun ComposerTimeField(
    hour: Int,
    minute: Int,
    onTimeChange: (Int, Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    var open by remember { mutableStateOf(false) }
    Surface(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .clickable { open = true },
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surfaceContainerHighest,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                imageVector = Icons.Outlined.Schedule,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(18.dp),
            )
            Text(
                text = clockText(hour * 60 + minute),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
    if (open) {
        ComposerTimePickerDialog(
            initialHour = hour,
            initialMinute = minute,
            onDismiss = { open = false },
            onConfirm = { h, m ->
                onTimeChange(h, m)
                open = false
            },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ComposerTimePickerDialog(
    initialHour: Int,
    initialMinute: Int,
    onDismiss: () -> Unit,
    onConfirm: (Int, Int) -> Unit,
) {
    val is24Hour = android.text.format.DateFormat.is24HourFormat(LocalContext.current)
    val state = rememberTimePickerState(
        initialHour = initialHour,
        initialMinute = initialMinute,
        is24Hour = is24Hour,
    )
    Dialog(onDismissRequest = onDismiss) {
        Surface(
            shape = RoundedCornerShape(28.dp),
            color = MaterialTheme.colorScheme.surfaceContainerHigh,
            tonalElevation = 6.dp,
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = stringResourceCompat(R.string.composer_pick_time),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 20.dp),
                )
                TimePicker(state = state)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextButton(onClick = onDismiss) {
                        Text(stringResourceCompat(R.string.action_cancel))
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    TextButton(onClick = { onConfirm(state.hour, state.minute) }) {
                        Text(stringResourceCompat(R.string.action_ok))
                    }
                }
            }
        }
    }
}

// ─── Schedule mode mapping ───────────────────────────────────────────────────

private enum class ScheduleStepOption(val labelRes: Int) {
    OneTime(R.string.composer_type_onetime_title),
    Daily(R.string.composer_type_daily_title),
    Weekly(R.string.preset_weekly),
    Monthly(R.string.preset_monthly_gregorian),
    SpecificDates(R.string.preset_specific_dates),
    Interval(R.string.preset_interval),
    Yearly(R.string.composer_schedule_yearly),
    Season(R.string.composer_schedule_season),
}

private fun GoalDraft.scheduleDetailsReady(): Boolean = when (val frequency = frequencyDraft) {
    FrequencyDraft.Daily -> true
    is FrequencyDraft.Weekly -> frequency.days.isNotEmpty()
    is FrequencyDraft.Monthly -> frequency.daysOfMonth.isNotEmpty()
    is FrequencyDraft.SpecificDates -> frequency.dateText.isNotBlank()
    is FrequencyDraft.Interval -> frequency.intervalDays.toIntOrNull()?.let { it > 0 } == true
    is FrequencyDraft.Yearly -> frequency.days.isNotEmpty()
    is FrequencyDraft.Season -> frequency.isConfigured
}

private fun GoalDraft.scheduleStepOption(): ScheduleStepOption =
    if (preset == GoalPreset.ONE_TIME) {
        ScheduleStepOption.OneTime
    } else {
        when (frequencyDraft) {
            is FrequencyDraft.Daily -> ScheduleStepOption.Daily
            is FrequencyDraft.Weekly -> ScheduleStepOption.Weekly
            is FrequencyDraft.Interval -> ScheduleStepOption.Interval
            is FrequencyDraft.Monthly -> ScheduleStepOption.Monthly
            is FrequencyDraft.Yearly -> ScheduleStepOption.Yearly
            is FrequencyDraft.Season -> ScheduleStepOption.Season
            is FrequencyDraft.SpecificDates -> ScheduleStepOption.SpecificDates
        }
    }

private fun GoalDraft.withScheduleStepOption(option: ScheduleStepOption): GoalDraft = when (option) {
    ScheduleStepOption.OneTime -> copy(
        preset = GoalPreset.ONE_TIME,
        frequencyDraft = FrequencyDraft.Daily,
        customTargetPolicy = TargetPolicy.CUMULATIVE_TOTAL,
    )
    ScheduleStepOption.Daily -> copy(
        preset = GoalPreset.CUSTOM,
        frequencyDraft = FrequencyDraft.Daily,
        customTargetPolicy = TargetPolicy.PER_DUE_DATE,
    )
    ScheduleStepOption.Weekly -> copy(
        preset = GoalPreset.CUSTOM,
        frequencyDraft = defaultFrequencyFor(ScheduleMode.Weekly),
        customTargetPolicy = TargetPolicy.PER_DUE_DATE,
    )
    ScheduleStepOption.Monthly -> copy(
        preset = GoalPreset.CUSTOM,
        frequencyDraft = defaultFrequencyFor(ScheduleMode.Monthly),
        customTargetPolicy = TargetPolicy.PER_DUE_DATE,
    )
    ScheduleStepOption.SpecificDates -> copy(
        preset = GoalPreset.CUSTOM,
        frequencyDraft = defaultFrequencyFor(ScheduleMode.SpecificDates),
        customTargetPolicy = TargetPolicy.PER_DUE_DATE,
    )
    ScheduleStepOption.Interval -> copy(
        preset = GoalPreset.CUSTOM,
        frequencyDraft = defaultFrequencyFor(ScheduleMode.Interval),
        customTargetPolicy = TargetPolicy.PER_DUE_DATE,
    )
    ScheduleStepOption.Yearly -> copy(
        preset = GoalPreset.CUSTOM,
        frequencyDraft = defaultFrequencyFor(ScheduleMode.Yearly),
        customTargetPolicy = TargetPolicy.PER_DUE_DATE,
    )
    ScheduleStepOption.Season -> copy(
        preset = GoalPreset.CUSTOM,
        frequencyDraft = defaultFrequencyFor(ScheduleMode.Season),
        customTargetPolicy = TargetPolicy.PER_DUE_DATE,
    )
}

private enum class ScheduleMode { Daily, Weekly, Interval, Monthly, Yearly, Season, SpecificDates }

private fun FrequencyDraft.scheduleMode(): ScheduleMode = when (this) {
    is FrequencyDraft.Daily -> ScheduleMode.Daily
    is FrequencyDraft.Weekly -> ScheduleMode.Weekly
    is FrequencyDraft.Interval -> ScheduleMode.Interval
    is FrequencyDraft.Monthly -> ScheduleMode.Monthly
    is FrequencyDraft.Yearly -> ScheduleMode.Yearly
    is FrequencyDraft.Season -> ScheduleMode.Season
    is FrequencyDraft.SpecificDates -> ScheduleMode.SpecificDates
}

private fun defaultFrequencyFor(mode: ScheduleMode): FrequencyDraft = when (mode) {
    ScheduleMode.Daily -> FrequencyDraft.Daily
    ScheduleMode.Weekly -> FrequencyDraft.Weekly(emptySet())
    ScheduleMode.Interval -> FrequencyDraft.Interval("")
    ScheduleMode.Monthly -> FrequencyDraft.Monthly(daysOfMonth = emptySet())
    ScheduleMode.Yearly -> FrequencyDraft.Yearly(month = 1, days = emptySet())
    ScheduleMode.Season -> FrequencyDraft.Season(SeasonTemplateCode.RAMADAN)
    ScheduleMode.SpecificDates -> FrequencyDraft.SpecificDates("")
}

@Composable
private fun scheduleModeLabel(mode: ScheduleMode): String = stringResourceCompat(
    when (mode) {
        ScheduleMode.Daily -> R.string.create_goal_every_day
        ScheduleMode.Weekly -> R.string.preset_weekly
        ScheduleMode.Interval -> R.string.preset_interval
        ScheduleMode.Monthly -> R.string.preset_monthly_gregorian
        ScheduleMode.Yearly -> R.string.composer_schedule_yearly
        ScheduleMode.Season -> R.string.composer_schedule_season
        ScheduleMode.SpecificDates -> R.string.preset_specific_dates
    },
)

/** A short example of each schedule, shown as a trailing hint in the picker. Daily needs none. */
@Composable
private fun scheduleModeExample(mode: ScheduleMode): String? = when (mode) {
    ScheduleMode.Daily -> null
    ScheduleMode.Weekly -> stringResourceCompat(R.string.schedule_example_weekly)
    ScheduleMode.Interval -> stringResourceCompat(R.string.schedule_example_interval)
    ScheduleMode.Monthly -> stringResourceCompat(R.string.schedule_example_monthly)
    ScheduleMode.Yearly -> stringResourceCompat(R.string.schedule_example_yearly)
    ScheduleMode.Season -> stringResourceCompat(R.string.schedule_example_season)
    ScheduleMode.SpecificDates -> stringResourceCompat(R.string.schedule_example_dates)
}

/** Lightweight staggered entrance, matching the onboarding choreography. */
@Composable
private fun ComposerEntry(index: Int, content: @Composable () -> Unit) {
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(tween(380, delayMillis = index * 70)) +
            slideInVertically(tween(380, delayMillis = index * 70)) { it / 10 },
    ) {
        content()
    }
}

@Composable
private fun stringResourceCompat(resId: Int): String =
    androidx.compose.ui.res.stringResource(resId)

@Composable
private fun stringResourceCompat(resId: Int, vararg formatArgs: Any): String =
    androidx.compose.ui.res.stringResource(resId, *formatArgs)
