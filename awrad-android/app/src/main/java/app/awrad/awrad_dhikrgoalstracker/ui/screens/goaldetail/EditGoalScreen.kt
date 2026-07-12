package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalCountRuleMode
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateError
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateWarning
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradStatusBarStyle
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerCard
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerFieldSection
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerLabeledStepper
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerSectionLabel
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerSelect
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerSelectOption
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerToggleRow
import app.awrad.awrad_dhikrgoalstracker.ui.theme.AwradDhikrGoalsTrackerTheme
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

@Composable
fun EditGoalScreen(
    goalId: Long,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: EditGoalViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val saveFailedMessage = stringResource(R.string.goal_edit_save_failed)
    var showDiscardDialog by remember { mutableStateOf(false) }

    LaunchedEffect(uiState.saveCompleted) {
        if (uiState.saveCompleted) {
            viewModel.onSaveResultConsumed()
            onNavigateBack()
        }
    }
    LaunchedEffect(uiState.saveFailed) {
        if (uiState.saveFailed) {
            snackbarHostState.showSnackbar(saveFailedMessage)
            viewModel.onSaveResultConsumed()
        }
    }

    fun requestBack() {
        if (uiState.isDirty && !uiState.isSaving) {
            showDiscardDialog = true
        } else {
            onNavigateBack()
        }
    }

    BackHandler(enabled = uiState.isDirty && !uiState.isSaving) {
        showDiscardDialog = true
    }

    EditGoalContent(
        uiState = uiState,
        snackbarHostState = snackbarHostState,
        onNavigateBack = ::requestBack,
        onRuleModeChange = viewModel::onRuleModeChange,
        onMinimumChange = viewModel::onMinimumChange,
        onTargetChange = viewModel::onTargetChange,
        onMaximumChange = viewModel::onMaximumChange,
        onCapBehaviorChange = viewModel::onCapBehaviorChange,
        onAutoCompleteChange = viewModel::onAutoCompleteChange,
        onSlotMinimumChange = viewModel::onSlotMinimumChange,
        onSlotTargetChange = viewModel::onSlotTargetChange,
        onSlotMaximumChange = viewModel::onSlotMaximumChange,
        onSlotCapBehaviorChange = viewModel::onSlotCapBehaviorChange,
        onSave = viewModel::save,
        modifier = modifier,
    )

    if (showDiscardDialog) {
        AlertDialog(
            onDismissRequest = { showDiscardDialog = false },
            title = { Text(stringResource(R.string.goal_edit_discard_title)) },
            text = { Text(stringResource(R.string.goal_edit_discard_body)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDiscardDialog = false
                        onNavigateBack()
                    },
                ) {
                    Text(stringResource(R.string.goal_edit_discard_confirm))
                }
            },
            dismissButton = {
                TextButton(onClick = { showDiscardDialog = false }) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        )
    }
}

@Composable
private fun EditGoalContent(
    uiState: EditGoalUiState,
    snackbarHostState: SnackbarHostState,
    onNavigateBack: () -> Unit,
    onRuleModeChange: (GoalCountRuleMode) -> Unit,
    onMinimumChange: (String) -> Unit,
    onTargetChange: (String) -> Unit,
    onMaximumChange: (String) -> Unit,
    onCapBehaviorChange: (CountCapBehavior) -> Unit,
    onAutoCompleteChange: (Boolean) -> Unit,
    onSlotMinimumChange: (Long, String) -> Unit,
    onSlotTargetChange: (Long, String) -> Unit,
    onSlotMaximumChange: (Long, String) -> Unit,
    onSlotCapBehaviorChange: (Long, CountCapBehavior) -> Unit,
    onSave: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        containerColor = Color.Transparent,
        contentWindowInsets = WindowInsets(0),
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            EditGoalTopBar(
                canSave = uiState.canSave,
                isSaving = uiState.isSaving,
                onNavigateBack = onNavigateBack,
                onSave = onSave,
            )
        },
    ) { padding ->
        when {
            uiState.isLoading -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator()
                }
            }
            uiState.goal == null -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .padding(24.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = stringResource(R.string.goal_details_missing),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            else -> {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                    contentPadding = PaddingValues(horizontal = 20.dp, vertical = 18.dp),
                    verticalArrangement = Arrangement.spacedBy(18.dp),
                ) {
                    item {
                        EditHeader(uiState = uiState)
                    }
                    item {
                        ComposerFieldSection(title = stringResource(R.string.goal_edit_count_rule)) {
                            RuleModeSelector(
                                selected = uiState.draft.ruleMode,
                                onSelect = onRuleModeChange,
                            )
                            CountRuleFields(
                                draft = uiState.draft,
                                hasMultipleSessions = uiState.hasMultipleSessions,
                                onMinimumChange = onMinimumChange,
                                onTargetChange = onTargetChange,
                                onMaximumChange = onMaximumChange,
                                onCapBehaviorChange = onCapBehaviorChange,
                            )
                            if (uiState.isLifetimeGoal && uiState.draft.ruleMode != GoalCountRuleMode.Tracker) {
                                ComposerToggleRow(
                                    title = stringResource(R.string.goal_edit_auto_complete_title),
                                    body = stringResource(R.string.goal_edit_auto_complete_body),
                                    checked = uiState.draft.autoCompleteOnTarget,
                                    onCheckedChange = onAutoCompleteChange,
                                )
                            }
                        }
                    }
                    if (uiState.warnings.isNotEmpty()) {
                        item {
                            WarningCard(warnings = uiState.warnings)
                        }
                    }
                    if (uiState.validationErrors.isNotEmpty()) {
                        item {
                            ValidationCard(errors = uiState.validationErrors)
                        }
                    }
                    if (uiState.hasMultipleSessions) {
                        item {
                            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                ComposerSectionLabel(stringResource(R.string.goal_edit_sessions_title))
                                Text(
                                    text = totalSummary(uiState),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(start = 2.dp),
                                )
                            }
                        }
                        items(uiState.draft.slots, key = { it.slotId }) { slot ->
                            SessionEditCard(
                                slot = slot,
                                ruleMode = uiState.draft.ruleMode,
                                onMinimumChange = { onSlotMinimumChange(slot.slotId, it) },
                                onTargetChange = { onSlotTargetChange(slot.slotId, it) },
                                onMaximumChange = { onSlotMaximumChange(slot.slotId, it) },
                                onCapBehaviorChange = { onSlotCapBehaviorChange(slot.slotId, it) },
                            )
                        }
                    }
                    item {
                        Button(
                            onClick = onSave,
                            enabled = uiState.canSave,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(56.dp),
                            shape = RoundedCornerShape(18.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primary,
                                contentColor = MaterialTheme.colorScheme.onPrimary,
                            ),
                        ) {
                            Text(
                                text = if (uiState.isSaving) {
                                    stringResource(R.string.goal_edit_saving)
                                } else {
                                    stringResource(R.string.action_save)
                                },
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun EditGoalTopBar(
    canSave: Boolean,
    isSaving: Boolean,
    onNavigateBack: () -> Unit,
    onSave: () -> Unit,
) {
    val containerColor = if (isAwradDarkTheme()) Color.Transparent else MaterialTheme.colorScheme.surfaceContainerHigh
    AwradStatusBarStyle(color = MaterialTheme.colorScheme.background)
    Surface(
        color = containerColor,
        contentColor = MaterialTheme.colorScheme.onSurface,
    ) {
        Column {
            Spacer(modifier = Modifier.windowInsetsTopHeight(WindowInsets.statusBars))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .padding(start = 4.dp, end = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Rounded.ArrowBack,
                        contentDescription = stringResource(R.string.action_back),
                    )
                }
                Text(
                    text = stringResource(R.string.goal_edit_title),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 8.dp),
                )
                TextButton(onClick = onSave, enabled = canSave && !isSaving) {
                    Text(stringResource(R.string.action_save), fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun EditHeader(uiState: EditGoalUiState) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = uiState.title.ifBlank { stringResource(R.string.goal_details_goal_fallback) },
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = stringResource(R.string.goal_edit_current_progress, uiState.progressCount),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun RuleModeSelector(
    selected: GoalCountRuleMode,
    onSelect: (GoalCountRuleMode) -> Unit,
) {
    ComposerSelect(
        options = listOf(
            GoalCountRuleMode.Tracker,
            GoalCountRuleMode.Minimum,
            GoalCountRuleMode.Target,
            GoalCountRuleMode.Stretch,
            GoalCountRuleMode.Exact,
            GoalCountRuleMode.Bounded,
        ).map { ComposerSelectOption(it, it.title()) },
        selected = selected,
        sheetTitle = stringResource(R.string.goal_edit_count_rule),
        onSelect = onSelect,
    )
}

@Composable
private fun CountRuleFields(
    draft: EditGoalDraft,
    hasMultipleSessions: Boolean,
    onMinimumChange: (String) -> Unit,
    onTargetChange: (String) -> Unit,
    onMaximumChange: (String) -> Unit,
    onCapBehaviorChange: (CountCapBehavior) -> Unit,
) {
    if (hasMultipleSessions) {
        Text(
            text = stringResource(R.string.goal_edit_multi_session_hint),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    } else {
        CountFields(
            ruleMode = draft.ruleMode,
            minimum = draft.minimumCount,
            target = draft.targetCount,
            maximum = draft.maximumCount,
            onMinimumChange = onMinimumChange,
            onTargetChange = onTargetChange,
            onMaximumChange = onMaximumChange,
        )
        CapBehaviorSelector(
            ruleMode = draft.ruleMode,
            selected = draft.capBehavior,
            onSelect = onCapBehaviorChange,
        )
    }
}

@Composable
private fun CountFields(
    ruleMode: GoalCountRuleMode,
    minimum: String,
    target: String,
    maximum: String,
    onMinimumChange: (String) -> Unit,
    onTargetChange: (String) -> Unit,
    onMaximumChange: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (ruleMode.usesMinimum()) {
            ComposerLabeledStepper(
                label = stringResource(R.string.goal_edit_minimum),
                value = minimum,
                onChange = onMinimumChange,
            )
        }
        if (ruleMode.usesTarget()) {
            ComposerLabeledStepper(
                label = stringResource(R.string.goal_edit_target),
                value = target,
                onChange = onTargetChange,
            )
        }
        if (ruleMode.usesMaximum()) {
            ComposerLabeledStepper(
                label = if (ruleMode == GoalCountRuleMode.Exact) {
                    stringResource(R.string.goal_edit_exact_count)
                } else {
                    stringResource(R.string.goal_edit_maximum)
                },
                value = maximum,
                onChange = onMaximumChange,
            )
        }
        if (ruleMode == GoalCountRuleMode.Tracker) {
            Text(
                text = stringResource(R.string.goal_edit_tracker_hint),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun CapBehaviorSelector(
    ruleMode: GoalCountRuleMode,
    selected: CountCapBehavior,
    onSelect: (CountCapBehavior) -> Unit,
) {
    val options = capOptions(ruleMode)
    if (options.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        ComposerSectionLabel(stringResource(R.string.goal_edit_limit))
        ComposerSelect(
            options = options.map { ComposerSelectOption(it, it.title()) },
            selected = selected,
            sheetTitle = stringResource(R.string.goal_edit_limit),
            onSelect = onSelect,
        )
    }
}

@Composable
private fun WarningCard(warnings: List<GoalUpdateWarning>) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.45f),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            warnings.forEach { warning ->
                Text(
                    text = warning.message(),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onErrorContainer,
                )
            }
        }
    }
}

@Composable
private fun ValidationCard(errors: List<GoalUpdateError>) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.errorContainer,
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            errors.distinct().forEach { error ->
                Text(
                    text = error.message(),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onErrorContainer,
                )
            }
        }
    }
}

@Composable
private fun SessionEditCard(
    slot: EditGoalSlotDraft,
    ruleMode: GoalCountRuleMode,
    onMinimumChange: (String) -> Unit,
    onTargetChange: (String) -> Unit,
    onMaximumChange: (String) -> Unit,
    onCapBehaviorChange: (CountCapBehavior) -> Unit,
) {
    ComposerCard {
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                text = slot.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            val subtitle = listOf(
                slot.subtitle,
                stringResource(R.string.goal_edit_session_current, slot.currentCount),
            ).filter { it.isNotBlank() }.joinToString(" · ")
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        CountFields(
            ruleMode = ruleMode,
            minimum = slot.minimumCount,
            target = slot.targetCount,
            maximum = slot.maximumCount,
            onMinimumChange = onMinimumChange,
            onTargetChange = onTargetChange,
            onMaximumChange = onMaximumChange,
        )
        CapBehaviorSelector(
            ruleMode = ruleMode,
            selected = slot.capBehavior,
            onSelect = onCapBehaviorChange,
        )
    }
}

@Composable
private fun totalSummary(uiState: EditGoalUiState): String {
    if (uiState.draft.ruleMode == GoalCountRuleMode.Tracker) {
        return stringResource(R.string.goal_summary_no_target)
    }
    val target = when (uiState.draft.ruleMode) {
        GoalCountRuleMode.Minimum -> uiState.draft.slots.sumOf { it.minimumCount.toIntOrNull() ?: 0 }
        GoalCountRuleMode.Exact -> uiState.draft.slots.sumOf { it.maximumCount.toIntOrNull() ?: 0 }
        else -> uiState.draft.slots.sumOf { it.targetCount.toIntOrNull() ?: 0 }
    }
    val maximums = uiState.draft.slots.map { it.maximumCount.toIntOrNull() }
    val maximum = maximums.takeIf { values -> values.size == uiState.draft.slots.size && values.all { it != null } }
        ?.sumOf { it ?: 0 }
    return when {
        maximum != null && uiState.draft.ruleMode.usesMaximum() -> {
            stringResource(R.string.goal_edit_total_target_max, target, maximum)
        }
        uiState.draft.ruleMode == GoalCountRuleMode.Minimum -> {
            stringResource(R.string.goal_edit_total_minimum, target)
        }
        else -> {
            stringResource(R.string.goal_edit_total_target, target)
        }
    }
}

private fun GoalCountRuleMode.usesMinimum(): Boolean =
    this == GoalCountRuleMode.Minimum || this == GoalCountRuleMode.Stretch || this == GoalCountRuleMode.Bounded

private fun GoalCountRuleMode.usesTarget(): Boolean =
    this == GoalCountRuleMode.Target || this == GoalCountRuleMode.Stretch || this == GoalCountRuleMode.Bounded

private fun GoalCountRuleMode.usesMaximum(): Boolean =
    this == GoalCountRuleMode.Exact || this == GoalCountRuleMode.Bounded

private fun capOptions(ruleMode: GoalCountRuleMode): List<CountCapBehavior> =
    when (ruleMode) {
        GoalCountRuleMode.Tracker,
        GoalCountRuleMode.Minimum -> emptyList()
        GoalCountRuleMode.Target,
        GoalCountRuleMode.Stretch -> listOf(
            CountCapBehavior.AllowOverTarget,
            CountCapBehavior.WarnOverTarget,
            CountCapBehavior.BlockAtTarget,
        )
        GoalCountRuleMode.Exact -> listOf(CountCapBehavior.BlockAtMaximum)
        GoalCountRuleMode.Bounded -> listOf(
            CountCapBehavior.AllowOverTarget,
            CountCapBehavior.WarnOverTarget,
            CountCapBehavior.BlockAtTarget,
            CountCapBehavior.BlockAtMaximum,
        )
    }

@Composable
private fun GoalCountRuleMode.title(): String =
    when (this) {
        GoalCountRuleMode.Tracker -> stringResource(R.string.goal_edit_rule_tracker)
        GoalCountRuleMode.Minimum -> stringResource(R.string.goal_edit_rule_minimum)
        GoalCountRuleMode.Target -> stringResource(R.string.goal_edit_rule_target)
        GoalCountRuleMode.Stretch -> stringResource(R.string.goal_edit_rule_stretch)
        GoalCountRuleMode.Exact -> stringResource(R.string.goal_edit_rule_exact)
        GoalCountRuleMode.Bounded -> stringResource(R.string.goal_edit_rule_bounded)
    }

@Composable
private fun CountCapBehavior.title(): String =
    when (this) {
        CountCapBehavior.AllowOverTarget -> stringResource(R.string.goal_edit_cap_allow)
        CountCapBehavior.WarnOverTarget -> stringResource(R.string.goal_edit_cap_warn)
        CountCapBehavior.BlockAtTarget -> stringResource(R.string.goal_edit_cap_block_target)
        CountCapBehavior.BlockAtMaximum -> stringResource(R.string.goal_edit_cap_block_maximum)
    }

@Composable
private fun GoalUpdateWarning.message(): String =
    when (this) {
        is GoalUpdateWarning.ProgressAlreadyAboveMaximum -> stringResource(
            R.string.goal_edit_warning_progress_above_max,
            currentCount,
            maximumCount,
        )
        is GoalUpdateWarning.SlotProgressAlreadyAboveMaximum -> stringResource(
            R.string.goal_edit_warning_slot_above_max,
            currentCount,
            maximumCount,
        )
    }

@Composable
private fun GoalUpdateError.message(): String =
    when (this) {
        GoalUpdateError.GoalNotFound -> stringResource(R.string.goal_details_missing)
        GoalUpdateError.GoalIdMismatch -> stringResource(R.string.goal_edit_error_generic)
        GoalUpdateError.InvalidSchedule -> stringResource(R.string.goal_schedule_edit_error_schedule)
        GoalUpdateError.InvalidTiming -> stringResource(R.string.goal_schedule_edit_error_timing)
        GoalUpdateError.InvalidCountPolicy -> stringResource(R.string.goal_edit_error_count_policy)
        GoalUpdateError.InvalidSlotPolicy -> stringResource(R.string.goal_edit_error_slot_policy)
        GoalUpdateError.MissingSlotPolicy -> stringResource(R.string.goal_edit_error_slot_policy)
        GoalUpdateError.UnknownSlotPolicy -> stringResource(R.string.goal_edit_error_slot_policy)
        GoalUpdateError.DuplicateSlotPolicy -> stringResource(R.string.goal_schedule_edit_error_duplicate_slot)
        GoalUpdateError.CannotRemoveLastSlot -> stringResource(R.string.goal_schedule_edit_error_last_slot)
        GoalUpdateError.InvalidReminder -> stringResource(R.string.goal_reminders_edit_error_invalid)
        GoalUpdateError.DuplicateReminder -> stringResource(R.string.goal_reminders_edit_error_duplicate)
    }

@Preview(showBackground = true)
@Composable
private fun EditGoalPreview() {
    AwradDhikrGoalsTrackerTheme {
        EditGoalContent(
            uiState = EditGoalUiState(
                isLoading = false,
                title = "Astaghfirullah",
                progressCount = 22,
                draft = EditGoalDraft(
                    ruleMode = GoalCountRuleMode.Bounded,
                    minimumCount = "50",
                    targetCount = "100",
                    maximumCount = "150",
                    capBehavior = CountCapBehavior.BlockAtMaximum,
                    slots = listOf(
                        EditGoalSlotDraft(1, "Morning", "6:00 AM-8:00 AM", 10, "25", "50", "75", CountCapBehavior.BlockAtMaximum),
                        EditGoalSlotDraft(2, "Evening", "6:00 PM-8:00 PM", 12, "25", "50", "75", CountCapBehavior.BlockAtMaximum),
                    ),
                ),
            ),
            snackbarHostState = remember { SnackbarHostState() },
            onNavigateBack = {},
            onRuleModeChange = {},
            onMinimumChange = {},
            onTargetChange = {},
            onMaximumChange = {},
            onCapBehaviorChange = {},
            onAutoCompleteChange = {},
            onSlotMinimumChange = { _, _ -> },
            onSlotTargetChange = { _, _ -> },
            onSlotMaximumChange = { _, _ -> },
            onSlotCapBehaviorChange = { _, _ -> },
            onSave = {},
        )
    }
}
