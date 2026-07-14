package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateError
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradStatusBarStyle
import app.awrad.awrad_dhikrgoalstracker.ui.theme.AwradDhikrGoalsTrackerTheme
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import java.time.LocalDate

@Composable
fun EditGoalRemindersScreen(
    goalId: AwradId,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: EditGoalRemindersViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val saveFailedMessage = stringResource(R.string.goal_reminders_edit_save_failed)
    var showDiscardDialog by remember { mutableStateOf(false) }

    LaunchedEffect(goalId) {
        // Route argument is consumed by Hilt/SavedStateHandle; this keeps the parameter intentional.
    }
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

    EditGoalRemindersContent(
        uiState = uiState,
        snackbarHostState = snackbarHostState,
        onNavigateBack = ::requestBack,
        onSave = viewModel::save,
        onAddReminder = viewModel::onAddReminder,
        onDeleteReminder = viewModel::onDeleteReminder,
        onMoveReminder = viewModel::onMoveReminder,
        onToggleReminder = viewModel::onToggleReminder,
        onHourChange = viewModel::onHourChange,
        onMinuteChange = viewModel::onMinuteChange,
        onOffsetChange = viewModel::onOffsetChange,
        onTargetChange = viewModel::onTargetChange,
        modifier = modifier,
    )

    if (showDiscardDialog) {
        AlertDialog(
            onDismissRequest = { showDiscardDialog = false },
            title = { Text(stringResource(R.string.goal_reminders_edit_discard_title)) },
            text = { Text(stringResource(R.string.goal_reminders_edit_discard_body)) },
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
private fun EditGoalRemindersContent(
    uiState: EditGoalRemindersUiState,
    snackbarHostState: SnackbarHostState,
    onNavigateBack: () -> Unit,
    onSave: () -> Unit,
    onAddReminder: (ReminderType) -> Unit,
    onDeleteReminder: (Long) -> Unit,
    onMoveReminder: (Long, Int) -> Unit,
    onToggleReminder: (Long, Boolean) -> Unit,
    onHourChange: (Long, String) -> Unit,
    onMinuteChange: (Long, String) -> Unit,
    onOffsetChange: (Long, String) -> Unit,
    onTargetChange: (Long, AwradId?) -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        containerColor = Color.Transparent,
        contentWindowInsets = WindowInsets(0),
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            EditRemindersTopBar(
                canSave = uiState.canSave,
                isSaving = uiState.isSaving,
                onNavigateBack = onNavigateBack,
                onSave = onSave,
            )
        },
    ) { padding ->
        when {
            uiState.isLoading -> Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }
            uiState.goal == null -> Box(
                modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = stringResource(R.string.goal_details_missing),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(horizontal = 20.dp, vertical = 18.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                item { EditRemindersHeader(uiState.title) }
                if (!uiState.canScheduleExactAlarms) {
                    item { ExactAlarmWarning() }
                }
                if (uiState.validationErrors.isNotEmpty()) {
                    item { RemindersValidationCard(uiState.validationErrors) }
                }
                item {
                    EditRemindersSection(title = stringResource(R.string.goal_reminders_edit_add_title)) {
                        AddReminderButtons(
                            canAddPrayerReminder = uiState.canAddPrayerReminder,
                            canAddTimeWindowReminder = uiState.canAddTimeWindowReminder,
                            onAddReminder = onAddReminder,
                        )
                    }
                }
                if (uiState.draft.reminders.isEmpty()) {
                    item {
                        EmptyRemindersCard()
                    }
                }
                itemsIndexed(uiState.draft.reminders, key = { _, item -> item.draftId }) { index, reminder ->
                    ReminderEditCard(
                        reminder = reminder,
                        index = index,
                        total = uiState.draft.reminders.size,
                        prayerSlots = uiState.prayerSlots,
                        timeWindowSlots = uiState.timeWindowSlots,
                        onDelete = onDeleteReminder,
                        onMove = onMoveReminder,
                        onToggle = onToggleReminder,
                        onHourChange = onHourChange,
                        onMinuteChange = onMinuteChange,
                        onOffsetChange = onOffsetChange,
                        onTargetChange = onTargetChange,
                    )
                }
                item {
                    Button(
                        onClick = onSave,
                        enabled = uiState.canSave,
                        modifier = Modifier.fillMaxWidth().height(54.dp),
                        shape = RoundedCornerShape(8.dp),
                    ) {
                        Text(if (uiState.isSaving) stringResource(R.string.goal_edit_saving) else stringResource(R.string.action_save))
                    }
                }
            }
        }
    }
}

@Composable
private fun EditRemindersTopBar(
    canSave: Boolean,
    isSaving: Boolean,
    onNavigateBack: () -> Unit,
    onSave: () -> Unit,
) {
    val containerColor = if (isAwradDarkTheme()) Color.Transparent else MaterialTheme.colorScheme.surfaceContainerHigh
    AwradStatusBarStyle(color = MaterialTheme.colorScheme.background)
    Surface(color = containerColor, contentColor = MaterialTheme.colorScheme.onSurface) {
        Column {
            Spacer(modifier = Modifier.windowInsetsTopHeight(WindowInsets.statusBars))
            Row(
                modifier = Modifier.fillMaxWidth().height(56.dp).padding(start = 4.dp, end = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onNavigateBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.action_back))
                }
                Text(
                    text = stringResource(R.string.goal_reminders_edit_title),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f).padding(start = 8.dp),
                )
                TextButton(onClick = onSave, enabled = canSave && !isSaving) {
                    Text(stringResource(R.string.action_save))
                }
            }
        }
    }
}

@Composable
private fun EditRemindersHeader(title: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = title.ifBlank { stringResource(R.string.goal_details_goal_fallback) },
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = stringResource(R.string.goal_reminders_edit_subtitle),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ExactAlarmWarning() {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Outlined.Notifications,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onTertiaryContainer,
            )
            Text(
                text = stringResource(R.string.goal_reminders_edit_exact_alarm_warning),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onTertiaryContainer,
            )
        }
    }
}

@Composable
private fun EditRemindersSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(8.dp))
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            content = content,
        )
    }
}

@Composable
private fun AddReminderButtons(
    canAddPrayerReminder: Boolean,
    canAddTimeWindowReminder: Boolean,
    onAddReminder: (ReminderType) -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        ReminderAddButton(
            text = stringResource(R.string.goal_reminders_edit_add_fixed),
            onClick = { onAddReminder(ReminderType.FIXED_TIME) },
            modifier = Modifier.weight(1f),
        )
        if (canAddPrayerReminder) {
            ReminderAddButton(
                text = stringResource(R.string.goal_reminders_edit_add_prayer),
                onClick = { onAddReminder(ReminderType.PRAYER_OFFSET) },
                modifier = Modifier.weight(1f),
            )
        }
    }
    if (canAddTimeWindowReminder) {
        ReminderAddButton(
            text = stringResource(R.string.goal_reminders_edit_add_window),
            onClick = { onAddReminder(ReminderType.TIME_WINDOW_START) },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun ReminderAddButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    TextButton(onClick = onClick, modifier = modifier) {
        Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(modifier = Modifier.size(8.dp))
        Text(text, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun EmptyRemindersCard() {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
    ) {
        Text(
            text = stringResource(R.string.goal_reminders_edit_empty),
            modifier = Modifier.padding(16.dp),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ReminderEditCard(
    reminder: EditReminderDraft,
    index: Int,
    total: Int,
    prayerSlots: List<GoalSlot>,
    timeWindowSlots: List<GoalSlot>,
    onDelete: (Long) -> Unit,
    onMove: (Long, Int) -> Unit,
    onToggle: (Long, Boolean) -> Unit,
    onHourChange: (Long, String) -> Unit,
    onMinuteChange: (Long, String) -> Unit,
    onOffsetChange: (Long, String) -> Unit,
    onTargetChange: (Long, AwradId?) -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = reminder.typeTitle(),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = stringResource(R.string.goal_details_reminder_number, index + 1),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(
                    checked = reminder.enabled,
                    onCheckedChange = { onToggle(reminder.draftId, it) },
                )
                IconButton(onClick = { onMove(reminder.draftId, -1) }, enabled = index > 0) {
                    Icon(Icons.Default.KeyboardArrowUp, contentDescription = stringResource(R.string.action_move_up))
                }
                IconButton(onClick = { onMove(reminder.draftId, 1) }, enabled = index < total - 1) {
                    Icon(Icons.Default.KeyboardArrowDown, contentDescription = stringResource(R.string.action_move_down))
                }
                IconButton(onClick = { onDelete(reminder.draftId) }) {
                    Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.create_goal_remove_time_slot))
                }
            }

            when (reminder.reminderType) {
                ReminderType.FIXED_TIME -> FixedTimeFields(
                    reminder = reminder,
                    onHourChange = onHourChange,
                    onMinuteChange = onMinuteChange,
                )
                ReminderType.PRAYER_OFFSET -> PrayerReminderFields(
                    reminder = reminder,
                    prayerSlots = prayerSlots,
                    onTargetChange = onTargetChange,
                    onOffsetChange = onOffsetChange,
                )
                ReminderType.TIME_WINDOW_START -> TimeWindowReminderFields(
                    reminder = reminder,
                    timeWindowSlots = timeWindowSlots,
                    onTargetChange = onTargetChange,
                )
            }
        }
    }
}

@Composable
private fun FixedTimeFields(
    reminder: EditReminderDraft,
    onHourChange: (Long, String) -> Unit,
    onMinuteChange: (Long, String) -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        OutlinedTextField(
            value = reminder.hourText,
            onValueChange = { onHourChange(reminder.draftId, it) },
            label = { Text(stringResource(R.string.goal_reminders_edit_hour)) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.weight(1f),
        )
        OutlinedTextField(
            value = reminder.minuteText,
            onValueChange = { onMinuteChange(reminder.draftId, it) },
            label = { Text(stringResource(R.string.goal_reminders_edit_minute)) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun PrayerReminderFields(
    reminder: EditReminderDraft,
    prayerSlots: List<GoalSlot>,
    onTargetChange: (Long, AwradId?) -> Unit,
    onOffsetChange: (Long, String) -> Unit,
) {
    TargetSelector(
        allLabel = stringResource(R.string.goal_reminders_edit_all_prayer),
        slots = prayerSlots,
        selectedSlotId = reminder.slotId,
        onSelect = { onTargetChange(reminder.draftId, it) },
    )
    OutlinedTextField(
        value = reminder.offsetText,
        onValueChange = { onOffsetChange(reminder.draftId, it) },
        label = { Text(stringResource(R.string.goal_reminders_edit_offset_minutes)) },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun TimeWindowReminderFields(
    reminder: EditReminderDraft,
    timeWindowSlots: List<GoalSlot>,
    onTargetChange: (Long, AwradId?) -> Unit,
) {
    TargetSelector(
        allLabel = stringResource(R.string.goal_reminders_edit_all_windows),
        slots = timeWindowSlots,
        selectedSlotId = reminder.slotId,
        onSelect = { onTargetChange(reminder.draftId, it) },
    )
    Text(
        text = stringResource(R.string.goal_reminders_edit_window_start_hint),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun TargetSelector(
    allLabel: String,
    slots: List<GoalSlot>,
    selectedSlotId: AwradId?,
    onSelect: (AwradId?) -> Unit,
) {
    Text(
        text = stringResource(R.string.goal_reminders_edit_target),
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    val options = listOf<GoalSlot?>(null) + slots.sortedBy { it.sortOrder }
    options.chunked(2).forEach { rowItems ->
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            rowItems.forEach { slot ->
                val id = slot?.id
                FilterChip(
                    selected = selectedSlotId == id,
                    onClick = { onSelect(id) },
                    label = {
                        Text(
                            text = slot?.targetLabel() ?: allLabel,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    },
                    modifier = Modifier.weight(1f),
                )
            }
            if (rowItems.size == 1) {
                Spacer(modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun RemindersValidationCard(errors: List<GoalUpdateError>) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.errorContainer, RoundedCornerShape(8.dp))
            .padding(14.dp),
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

@Composable
private fun EditReminderDraft.typeTitle(): String =
    when (reminderType) {
        ReminderType.FIXED_TIME -> stringResource(R.string.goal_reminders_edit_fixed_time)
        ReminderType.PRAYER_OFFSET -> stringResource(R.string.goal_reminders_edit_prayer_offset)
        ReminderType.TIME_WINDOW_START -> stringResource(R.string.goal_reminders_edit_window_start)
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

private fun GoalSlot.targetLabel(): String =
    label?.takeIf { it.isNotBlank() } ?: when (slotType) {
        GoalSlotType.ANYTIME -> "Anytime"
        GoalSlotType.PRAYER -> {
            val relation = prayerRelation ?: PrayerRelation.AFTER
            val prayer = prayerName ?: Prayer.FAJR
            "${relation.displayName()} ${prayer.displayName()}"
        }
        GoalSlotType.TIME_WINDOW -> {
            val start = startMinute?.toClockText().orEmpty()
            val end = endMinute?.toClockText().orEmpty()
            listOf(start, end).filter { it.isNotBlank() }.joinToString("-").ifBlank { "Session ${sortOrder + 1}" }
        }
    }

private fun Prayer.displayName(): String =
    name.lowercase().replaceFirstChar { it.uppercase() }

private fun PrayerRelation.displayName(): String =
    name.lowercase().replaceFirstChar { it.uppercase() }

private fun Int.toClockText(): String {
    val clamped = coerceIn(0, 24 * 60)
    val hour24 = (clamped / 60) % 24
    val minute = clamped % 60
    return "%02d:%02d".format(hour24, minute)
}

@Preview(showBackground = true)
@Composable
private fun EditGoalRemindersPreview() {
    AwradDhikrGoalsTrackerTheme {
        EditGoalRemindersContent(
            uiState = EditGoalRemindersUiState(
                isLoading = false,
                goal = Goal(
                    id = java.util.UUID.randomUUID(),
                    dhikrId = java.util.UUID.randomUUID(),
                    slots = listOf(
                        GoalSlot(
                            id = java.util.UUID.randomUUID(),
                            goalId = java.util.UUID.randomUUID(),
                            slotType = GoalSlotType.TIME_WINDOW,
                            label = "Morning",
                            startMinute = 6 * 60,
                            endMinute = 9 * 60,
                        )
                    ),
                    startDate = LocalDate.parse("2026-05-27"),
                ),
                title = "Istighfar",
                draft = EditGoalRemindersDraft(
                    reminders = listOf(
                        EditReminderDraft(draftId = 1, reminderType = ReminderType.FIXED_TIME, hourText = "8", minuteText = "00"),
                        EditReminderDraft(draftId = 2, reminderType = ReminderType.TIME_WINDOW_START),
                    )
                ),
            ),
            snackbarHostState = SnackbarHostState(),
            onNavigateBack = {},
            onSave = {},
            onAddReminder = {},
            onDeleteReminder = {},
            onMoveReminder = { _, _ -> },
            onToggleReminder = { _, _ -> },
            onHourChange = { _, _ -> },
            onMinuteChange = { _, _ -> },
            onOffsetChange = { _, _ -> },
            onTargetChange = { _, _ -> },
        )
    }
}
