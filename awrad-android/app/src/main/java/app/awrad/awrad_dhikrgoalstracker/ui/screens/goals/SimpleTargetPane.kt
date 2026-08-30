package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AllInclusive
import androidx.compose.material3.Icon
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.foundation.BorderStroke
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.service.PreviewPlaybackState
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualIconTile
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualMetricChip
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualPrimaryButton
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.CountInputField
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.DhikrHeaderCard
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalValidationResult
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.TargetDraft
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

/**
 * Post-dhikr screen for the simple create-goal flow. It keeps the established
 * goal hero, dhikr card, scrollable form, and bottom create bar while exposing
 * quick goal types plus their target and streak-requirement controls.
 */
@Composable
fun SimpleTargetPane(
    dhikr: Dhikr?,
    audioState: PreviewPlaybackState,
    draft: GoalDraft,
    validation: GoalValidationResult,
    isCreating: Boolean,
    canChangeDhikr: Boolean,
    onTogglePlayback: () -> Unit,
    onShowFullQuran: (AwradId) -> Unit,
    onChangeDhikr: () -> Unit,
    onTargetChange: (TargetDraft) -> Unit,
    onCreate: () -> Unit,
    onSelectQuickPreset: (GoalPreset) -> Unit = {},
    onDraftChange: (GoalDraft) -> Unit = {},
    onAdvanced: () -> Unit = {},
    onChangeGoalType: () -> Unit = {},
    showTypeSelector: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val dhikrName = dhikr?.let { it.transliteration.ifBlank { it.title } }
        ?: stringResource(R.string.simple_target_dhikr_placeholder)

    Box(modifier = modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            SimpleGoalHero(sentence = goalSentence(dhikrName, draft))

            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .padding(top = 8.dp, bottom = if (showTypeSelector) 28.dp else 108.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                if (dhikr != null) {
                    Column {
                        DhikrHeaderCard(
                            dhikr = dhikr,
                            audioState = audioState,
                            onTogglePlayback = onTogglePlayback,
                            onShowFullQuran = { onShowFullQuran(dhikr.id) },
                            collapsed = true,
                        )
                        if (canChangeDhikr) {
                            TextButton(
                                onClick = onChangeDhikr,
                                modifier = Modifier.align(Alignment.End),
                            ) {
                                Text(
                                    text = stringResource(R.string.composer_change_dhikr),
                                    style = MaterialTheme.typography.labelLarge,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                        }
                    }
                } else {
                    ChooseDhikrCard(onClick = onChangeDhikr)
                }

                if (showTypeSelector) {
                    SimpleGoalTypeSection(
                        selectedPreset = null,
                        onSelectPreset = onSelectQuickPreset,
                        onAdvanced = onAdvanced,
                    )
                } else {
                    SimpleGoalTypeSummary(
                        preset = draft.preset,
                        onChange = onChangeGoalType,
                    )

                    when (draft.preset) {
                        GoalPreset.TRACKER -> {
                            SimpleTrackerNote()
                            SimpleOptionalStreakRequirement(
                                enabled = draft.extras.hasMinStreak,
                                value = draft.extras.minStreakCount,
                                integratedStepper = true,
                                onEnabledChange = { enabled ->
                                    onDraftChange(draft.withStreakEnabled(enabled))
                                },
                                onValueChange = { value ->
                                    onDraftChange(draft.withStreakCount(value))
                                },
                            )
                        }
                        GoalPreset.ONE_TIME -> {
                            GoalTargetInput(
                                draft = draft,
                                labelRes = R.string.simple_target_onetime_label,
                                quickValues = listOf(1000, 10000, 70000),
                                integratedStepper = true,
                                onTargetChange = onTargetChange,
                            )
                            SimpleOptionalStreakRequirement(
                                enabled = draft.extras.hasMinStreak,
                                value = draft.extras.minStreakCount,
                                integratedStepper = true,
                                onEnabledChange = { enabled ->
                                    onDraftChange(draft.withStreakEnabled(enabled))
                                },
                                onValueChange = { value ->
                                    onDraftChange(draft.withStreakCount(value))
                                },
                            )
                        }
                        GoalPreset.DAILY -> {
                            GoalTargetInput(
                                draft = draft,
                                labelRes = R.string.simple_target_daily_label,
                                quickValues = listOf(33, 100, 313),
                                integratedStepper = true,
                                onTargetChange = onTargetChange,
                            )
                            SimpleOptionalStreakRequirement(
                                enabled = draft.extras.hasMinStreak,
                                value = draft.extras.minStreakCount,
                                integratedStepper = true,
                                onEnabledChange = { enabled ->
                                    onDraftChange(draft.withStreakEnabled(enabled))
                                },
                                onValueChange = { value ->
                                    onDraftChange(draft.withStreakCount(value))
                                },
                            )
                        }
                        else -> Unit
                    }
                }
            }
        }

        if (!showTypeSelector) {
            SimpleCreateBar(
                validation = validation,
                isCreating = isCreating,
                onCreate = onCreate,
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }
    }
}

@Composable
internal fun GoalTargetInput(
    draft: GoalDraft,
    labelRes: Int,
    quickValues: List<Int>,
    integratedStepper: Boolean = false,
    onTargetChange: (TargetDraft) -> Unit,
    testTag: String = "simple-goal-target",
) {
    val count = (draft.targetDraft as? TargetDraft.Fixed)?.count ?: ""
    CountInputField(
        value = count,
        onValueChange = { onTargetChange(TargetDraft.Fixed(it)) },
        label = stringResource(labelRes),
        quickValues = quickValues,
        integratedStepper = integratedStepper,
        modifier = Modifier.testTag(testTag),
    )
}

/** The shared target field styling used by both quick goals and advanced steps. */
@Composable
internal fun GoalTargetInput(
    value: String,
    labelRes: Int,
    quickValues: List<Int>,
    integratedStepper: Boolean = false,
    onValueChange: (String) -> Unit,
    testTag: String = "simple-goal-target",
) {
    CountInputField(
        value = value,
        onValueChange = onValueChange,
        label = stringResource(labelRes),
        quickValues = quickValues,
        integratedStepper = integratedStepper,
        modifier = Modifier.testTag(testTag),
    )
}

@Composable
private fun SimpleGoalTypeSection(
    selectedPreset: GoalPreset?,
    onSelectPreset: (GoalPreset) -> Unit,
    onAdvanced: () -> Unit,
) {
    val selected = selectedPreset
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = stringResource(R.string.create_goal_goal_type),
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        SimpleGoalTypeCard(
            titleRes = R.string.goal_shape_daily_title,
            descRes = R.string.goal_shape_daily_desc,
            selected = selected == GoalPreset.DAILY,
            testTag = "simple-goal-option-daily",
            onClick = { onSelectPreset(GoalPreset.DAILY) },
        )
        SimpleGoalTypeCard(
            titleRes = R.string.goal_shape_onetime_title,
            descRes = R.string.goal_shape_onetime_desc,
            selected = selected == GoalPreset.ONE_TIME,
            testTag = "simple-goal-option-total",
            onClick = { onSelectPreset(GoalPreset.ONE_TIME) },
        )
        SimpleGoalTypeCard(
            titleRes = R.string.goal_shape_notarget_title,
            descRes = R.string.goal_shape_notarget_desc,
            selected = selected == GoalPreset.TRACKER,
            testTag = "simple-goal-option-tracker",
            onClick = { onSelectPreset(GoalPreset.TRACKER) },
        )
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            HorizontalDivider(modifier = Modifier.weight(1f))
            Text(
                text = stringResource(R.string.goal_shape_or).uppercase(),
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                letterSpacing = 1.2.sp,
            )
            HorizontalDivider(modifier = Modifier.weight(1f))
        }
        SimpleGoalTypeCard(
            titleRes = R.string.goal_shape_advanced_title,
            descRes = R.string.goal_shape_advanced_desc,
            selected = false,
            testTag = "simple-goal-advanced",
            onClick = onAdvanced,
        )
    }
}

@Composable
private fun SimpleGoalTypeSummary(
    preset: GoalPreset,
    onChange: () -> Unit,
) {
    val titleRes = when (preset) {
        GoalPreset.DAILY -> R.string.quick_goal_daily_title
        GoalPreset.ONE_TIME -> R.string.quick_goal_total_title
        GoalPreset.TRACKER -> R.string.quick_goal_tracker_title
        else -> R.string.goal_shape_advanced_title
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("simple-goal-type-summary"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = stringResource(titleRes),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        TextButton(
            onClick = onChange,
            modifier = Modifier.testTag("simple-goal-change-type"),
        ) {
            Text(stringResource(R.string.create_goal_change_type))
        }
    }
}

@Composable
private fun SimpleGoalTypeCard(
    titleRes: Int,
    descRes: Int,
    selected: Boolean,
    testTag: String,
    onClick: () -> Unit,
) {
    val containerColor = if (selected) {
        MaterialTheme.colorScheme.primaryContainer.copy(alpha = if (isAwradDarkTheme()) 0.5f else 0.7f)
    } else {
        null
    }
    val cardTag = if (selected) "$testTag-selected" else testTag
    RitualCard(
        modifier = Modifier.fillMaxWidth().testTag(cardTag),
        onClick = onClick,
        containerColor = containerColor,
        showBorder = selected,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 16.dp),
        ) {
            Text(
                text = stringResource(titleRes),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = stringResource(descRes),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 3.dp),
            )
        }
    }
}

@Composable
private fun SimpleStreakRequirement(
    value: String,
    integratedStepper: Boolean = false,
    onValueChange: (String) -> Unit,
    onRemove: () -> Unit,
) {
    Column(
        modifier = Modifier.testTag("simple-goal-streak-input"),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        CountInputField(
            value = value,
            onValueChange = onValueChange,
            label = stringResource(R.string.create_goal_min_streak),
            quickValues = listOf(1, 10, 33, 100),
            integratedStepper = integratedStepper,
        )
        Text(
            text = stringResource(R.string.create_goal_min_streak_hint),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        TextButton(
            onClick = onRemove,
            modifier = Modifier
                .align(Alignment.End)
                .testTag("simple-goal-remove-streak"),
        ) {
            Text(stringResource(R.string.create_goal_remove_streak))
        }
    }
}

@Composable
private fun SimpleOptionalStreakRequirement(
    enabled: Boolean,
    value: String,
    integratedStepper: Boolean = false,
    onEnabledChange: (Boolean) -> Unit,
    onValueChange: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (enabled) {
            SimpleStreakRequirement(
                value = value,
                integratedStepper = integratedStepper,
                onValueChange = onValueChange,
                onRemove = { onEnabledChange(false) },
            )
        } else {
            TextButton(
                onClick = { onEnabledChange(true) },
                modifier = Modifier.testTag("simple-goal-add-streak"),
            ) {
                Text(stringResource(R.string.create_goal_add_streak))
            }
        }
    }
}

private fun GoalDraft.withStreakEnabled(enabled: Boolean): GoalDraft = copy(
    extras = extras.copy(
        hasMinStreak = enabled,
        minStreakCount = if (enabled && extras.minStreakCount.isBlank()) "1" else extras.minStreakCount,
    ),
)

private fun GoalDraft.withStreakCount(value: String): GoalDraft = copy(
    extras = extras.copy(minStreakCount = value),
)

@Composable
private fun SimpleGoalHero(sentence: String) {
    val accent = MaterialTheme.colorScheme.primary
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 8.dp),
        shape = RoundedCornerShape(22.dp),
        color = accent.copy(alpha = if (isAwradDarkTheme()) 0.16f else 0.12f),
    ) {
        Row(modifier = Modifier.padding(horizontal = 20.dp, vertical = 18.dp)) {
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .height(54.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(accent),
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column {
                Text(
                    text = stringResource(R.string.composer_your_goal).uppercase(),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = accent,
                    letterSpacing = 1.5.sp,
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = sentence,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
        }
    }
}

@Composable
private fun ChooseDhikrCard(onClick: () -> Unit) {
    RitualCard(modifier = Modifier.fillMaxWidth(), onClick = onClick) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            RitualIconTile(icon = Icons.Outlined.AllInclusive)
            Text(
                text = stringResource(R.string.create_goal_choose_dhikr_title),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
            RitualMetricChip(text = stringResource(R.string.action_choose))
        }
    }
}

@Composable
private fun SimpleTrackerNote() {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.28f)),
    ) {
        Row(
            modifier = Modifier.padding(18.dp),
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
                text = stringResource(R.string.composer_tracker_note),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun SimpleCreateBar(
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
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            RitualPrimaryButton(
                text = stringResource(R.string.action_create_goal),
                onClick = onCreate,
                enabled = validation.isValid,
                isLoading = isCreating,
            )
        }
    }
}
