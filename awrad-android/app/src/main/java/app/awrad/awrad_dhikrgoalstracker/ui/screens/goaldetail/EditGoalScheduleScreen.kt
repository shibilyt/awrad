package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import androidx.activity.compose.BackHandler
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.BuiltInSeasonTemplates
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateError
import app.awrad.awrad_dhikrgoalstracker.ui.components.AwradStatusBarStyle
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerCard
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerFieldSection
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerMultiSelectChips
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerSectionLabel
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerSelect
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerSelectChips
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerSelectOption
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerTextField
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.components.ComposerTimePill
import app.awrad.awrad_dhikrgoalstracker.ui.theme.AwradDhikrGoalsTrackerTheme
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import java.time.DayOfWeek

@Composable
fun EditGoalScheduleScreen(
    goalId: AwradId,
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: EditGoalScheduleViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val saveFailedMessage = stringResource(R.string.goal_schedule_edit_save_failed)
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

    EditGoalScheduleContent(
        uiState = uiState,
        snackbarHostState = snackbarHostState,
        onNavigateBack = ::requestBack,
        onSave = viewModel::save,
        onScheduleModeChange = viewModel::onScheduleModeChange,
        onWeekdayToggle = viewModel::onWeekdayToggle,
        onCalendarChange = viewModel::onCalendarChange,
        onMonthDaysChange = viewModel::onMonthDaysChange,
        onIntervalDaysChange = viewModel::onIntervalDaysChange,
        onYearlyMonthChange = viewModel::onYearlyMonthChange,
        onYearlyDaysChange = viewModel::onYearlyDaysChange,
        onSeasonChange = viewModel::onSeasonChange,
        onSpecificDatesChange = viewModel::onSpecificDatesChange,
        onTimingModeChange = viewModel::onTimingModeChange,
        onAddSession = viewModel::onAddSession,
        onRemoveSession = viewModel::onRemoveSession,
        onMoveSession = viewModel::onMoveSession,
        onSessionLabelChange = viewModel::onSessionLabelChange,
        onSessionPrayerChange = viewModel::onSessionPrayerChange,
        onSessionRelationChange = viewModel::onSessionRelationChange,
        onSessionLeadChange = viewModel::onSessionLeadChange,
        onSessionStartChange = viewModel::onSessionStartChange,
        onSessionEndChange = viewModel::onSessionEndChange,
        modifier = modifier,
    )

    if (showDiscardDialog) {
        AlertDialog(
            onDismissRequest = { showDiscardDialog = false },
            title = { Text(stringResource(R.string.goal_schedule_edit_discard_title)) },
            text = { Text(stringResource(R.string.goal_schedule_edit_discard_body)) },
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
private fun EditGoalScheduleContent(
    uiState: EditGoalScheduleUiState,
    snackbarHostState: SnackbarHostState,
    onNavigateBack: () -> Unit,
    onSave: () -> Unit,
    onScheduleModeChange: (ScheduleEditMode) -> Unit,
    onWeekdayToggle: (DayOfWeek) -> Unit,
    onCalendarChange: (CalendarSystem) -> Unit,
    onMonthDaysChange: (String) -> Unit,
    onIntervalDaysChange: (String) -> Unit,
    onYearlyMonthChange: (String) -> Unit,
    onYearlyDaysChange: (String) -> Unit,
    onSeasonChange: (SeasonTemplateCode) -> Unit,
    onSpecificDatesChange: (String) -> Unit,
    onTimingModeChange: (TimingEditMode) -> Unit,
    onAddSession: () -> Unit,
    onRemoveSession: (Long) -> Unit,
    onMoveSession: (Long, Int) -> Unit,
    onSessionLabelChange: (Long, String) -> Unit,
    onSessionPrayerChange: (Long, Prayer) -> Unit,
    onSessionRelationChange: (Long, PrayerRelation) -> Unit,
    onSessionLeadChange: (Long, String) -> Unit,
    onSessionStartChange: (Long, String) -> Unit,
    onSessionEndChange: (Long, String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        containerColor = Color.Transparent,
        contentWindowInsets = WindowInsets(0),
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            EditScheduleTopBar(
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
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                item { EditScheduleHeader(uiState.title) }
                item {
                    ComposerFieldSection(title = stringResource(R.string.goal_schedule_edit_schedule)) {
                        ScheduleModeSelector(uiState.draft.scheduleMode, onScheduleModeChange)
                        ScheduleFields(
                            draft = uiState.draft,
                            onWeekdayToggle = onWeekdayToggle,
                            onCalendarChange = onCalendarChange,
                            onMonthDaysChange = onMonthDaysChange,
                            onIntervalDaysChange = onIntervalDaysChange,
                            onYearlyMonthChange = onYearlyMonthChange,
                            onYearlyDaysChange = onYearlyDaysChange,
                            onSeasonChange = onSeasonChange,
                            onSpecificDatesChange = onSpecificDatesChange,
                        )
                    }
                }
                item {
                    ComposerFieldSection(title = stringResource(R.string.goal_schedule_edit_timing)) {
                        TimingModeSelector(uiState.draft.timingMode, onTimingModeChange)
                    }
                }
                if (uiState.validationErrors.isNotEmpty()) {
                    item { ScheduleValidationCard(uiState.validationErrors) }
                }
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        ComposerSectionLabel(
                            text = stringResource(R.string.goal_schedule_edit_sessions),
                            modifier = Modifier.weight(1f),
                        )
                        if (uiState.draft.timingMode != TimingEditMode.Anytime) {
                            TextButton(onClick = onAddSession) {
                                Icon(Icons.Outlined.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.size(6.dp))
                                Text(stringResource(R.string.goal_schedule_edit_add_session), fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }
                if (uiState.draft.timingMode == TimingEditMode.Anytime) {
                    item {
                        ComposerCard {
                            Text(
                                text = stringResource(R.string.goal_schedule_edit_anytime_hint),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                } else {
                    itemsIndexed(uiState.draft.sessions, key = { _, item -> item.draftId }) { index, session ->
                        SessionScheduleCard(
                            session = session,
                            index = index,
                            total = uiState.draft.sessions.size,
                            timingMode = uiState.draft.timingMode,
                            onRemove = onRemoveSession,
                            onMove = onMoveSession,
                            onLabelChange = onSessionLabelChange,
                            onPrayerChange = onSessionPrayerChange,
                            onRelationChange = onSessionRelationChange,
                            onLeadChange = onSessionLeadChange,
                            onStartChange = onSessionStartChange,
                            onEndChange = onSessionEndChange,
                        )
                    }
                }
                item {
                    Button(
                        onClick = onSave,
                        enabled = uiState.canSave,
                        modifier = Modifier.fillMaxWidth().height(56.dp),
                        shape = RoundedCornerShape(18.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primary,
                            contentColor = MaterialTheme.colorScheme.onPrimary,
                        ),
                    ) {
                        Text(
                            text = if (uiState.isSaving) stringResource(R.string.goal_edit_saving) else stringResource(R.string.action_save),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EditScheduleTopBar(
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
                    Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = stringResource(R.string.action_back))
                }
                Text(
                    text = stringResource(R.string.goal_schedule_edit_title),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f).padding(start = 8.dp),
                )
                TextButton(onClick = onSave, enabled = canSave && !isSaving) {
                    Text(stringResource(R.string.action_save), fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun EditScheduleHeader(title: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = title.ifBlank { stringResource(R.string.goal_details_goal_fallback) },
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = stringResource(R.string.goal_schedule_edit_subtitle),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ScheduleModeSelector(selected: ScheduleEditMode, onSelect: (ScheduleEditMode) -> Unit) {
    ComposerSelect(
        options = ScheduleEditMode.entries.map { ComposerSelectOption(it, it.title()) },
        selected = selected,
        sheetTitle = stringResource(R.string.goal_schedule_edit_schedule),
        onSelect = onSelect,
    )
}

@Composable
private fun TimingModeSelector(selected: TimingEditMode, onSelect: (TimingEditMode) -> Unit) {
    ComposerSelect(
        options = TimingEditMode.entries.map { ComposerSelectOption(it, it.title()) },
        selected = selected,
        sheetTitle = stringResource(R.string.goal_schedule_edit_timing),
        onSelect = onSelect,
    )
}

@Composable
private fun ScheduleFields(
    draft: EditGoalScheduleDraft,
    onWeekdayToggle: (DayOfWeek) -> Unit,
    onCalendarChange: (CalendarSystem) -> Unit,
    onMonthDaysChange: (String) -> Unit,
    onIntervalDaysChange: (String) -> Unit,
    onYearlyMonthChange: (String) -> Unit,
    onYearlyDaysChange: (String) -> Unit,
    onSeasonChange: (SeasonTemplateCode) -> Unit,
    onSpecificDatesChange: (String) -> Unit,
) {
    when (draft.scheduleMode) {
        ScheduleEditMode.Daily -> Text(
            text = stringResource(R.string.goal_summary_schedule_daily),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        ScheduleEditMode.Weekly -> ComposerMultiSelectChips(
            items = DayOfWeek.entries,
            selectedSet = draft.weekdays,
            label = { it.shortTitle() },
            onToggle = onWeekdayToggle,
        )
        ScheduleEditMode.Monthly -> {
            CalendarSelector(draft.calendar, onCalendarChange)
            ComposerTextField(
                value = draft.monthDaysText,
                label = stringResource(R.string.goal_schedule_edit_days_of_month),
                onValueChange = onMonthDaysChange,
                keyboardType = KeyboardType.Number,
            )
        }
        ScheduleEditMode.Interval -> ComposerTextField(
            value = draft.intervalDaysText,
            label = stringResource(R.string.goal_schedule_edit_interval_days),
            onValueChange = onIntervalDaysChange,
            keyboardType = KeyboardType.Number,
        )
        ScheduleEditMode.Yearly -> {
            CalendarSelector(draft.calendar, onCalendarChange)
            ComposerTextField(
                value = draft.yearlyMonthText,
                label = stringResource(R.string.goal_schedule_edit_month),
                onValueChange = onYearlyMonthChange,
                keyboardType = KeyboardType.Number,
            )
            ComposerTextField(
                value = draft.yearlyDaysText,
                label = stringResource(R.string.goal_schedule_edit_days_of_month),
                onValueChange = onYearlyDaysChange,
                keyboardType = KeyboardType.Number,
            )
        }
        ScheduleEditMode.Season -> ComposerSelect(
            options = BuiltInSeasonTemplates.all.map { ComposerSelectOption(it.code, it.code.title()) },
            selected = draft.seasonTemplateCode,
            sheetTitle = stringResource(R.string.schedule_season),
            onSelect = onSeasonChange,
        )
        ScheduleEditMode.SpecificDates -> ComposerTextField(
            value = draft.specificDatesText,
            label = stringResource(R.string.goal_schedule_edit_specific_dates),
            onValueChange = onSpecificDatesChange,
            supportingText = stringResource(R.string.goal_schedule_edit_specific_dates_hint),
            singleLine = false,
            minLines = 3,
        )
    }
}

@Composable
private fun CalendarSelector(selected: CalendarSystem, onSelect: (CalendarSystem) -> Unit) {
    ComposerSelectChips(
        items = listOf(CalendarSystem.GREGORIAN, CalendarSystem.HIJRI),
        selected = selected,
        label = { it.name.lowercase().replaceFirstChar { char -> char.uppercase() } },
        onSelect = onSelect,
    )
}

@Composable
private fun SessionScheduleCard(
    session: EditScheduleSessionDraft,
    index: Int,
    total: Int,
    timingMode: TimingEditMode,
    onRemove: (Long) -> Unit,
    onMove: (Long, Int) -> Unit,
    onLabelChange: (Long, String) -> Unit,
    onPrayerChange: (Long, Prayer) -> Unit,
    onRelationChange: (Long, PrayerRelation) -> Unit,
    onLeadChange: (Long, String) -> Unit,
    onStartChange: (Long, String) -> Unit,
    onEndChange: (Long, String) -> Unit,
) {
    ComposerCard {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = when (timingMode) {
                    TimingEditMode.Anytime -> stringResource(R.string.slot_anytime)
                    else -> stringResource(R.string.goal_schedule_edit_session_number, index + 1)
                },
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f),
            )
            IconButton(onClick = { onMove(session.draftId, -1) }, enabled = index > 0) {
                Icon(Icons.Rounded.KeyboardArrowUp, contentDescription = stringResource(R.string.action_move_up))
            }
            IconButton(onClick = { onMove(session.draftId, 1) }, enabled = index < total - 1) {
                Icon(Icons.Rounded.KeyboardArrowDown, contentDescription = stringResource(R.string.action_move_down))
            }
            IconButton(
                onClick = { onRemove(session.draftId) },
                enabled = total > 1 && timingMode != TimingEditMode.Anytime,
            ) {
                Icon(
                    Icons.Outlined.Delete,
                    contentDescription = stringResource(R.string.action_remove_session),
                    tint = MaterialTheme.colorScheme.error,
                )
            }
        }

        when (timingMode) {
            TimingEditMode.Anytime -> Text(
                text = stringResource(R.string.goal_schedule_edit_anytime_hint),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            TimingEditMode.PrayerSlots -> {
                ComposerTextField(
                    value = session.label,
                    label = stringResource(R.string.goal_schedule_edit_session_label),
                    onValueChange = { onLabelChange(session.draftId, it) },
                )
                ComposerSelect(
                    options = Prayer.entries.map { ComposerSelectOption(it, it.title()) },
                    selected = session.prayer,
                    sheetTitle = stringResource(R.string.goal_schedule_edit_prayer_slots),
                    onSelect = { onPrayerChange(session.draftId, it) },
                )
                ComposerSelectChips(
                    items = PrayerRelation.entries,
                    selected = session.relation,
                    label = { it.title() },
                    onSelect = { onRelationChange(session.draftId, it) },
                )
                if (session.relation == PrayerRelation.BEFORE) {
                    ComposerTextField(
                        value = session.beforeLeadMinutes,
                        label = stringResource(R.string.goal_schedule_edit_before_lead),
                        onValueChange = { onLeadChange(session.draftId, it) },
                        keyboardType = KeyboardType.Number,
                    )
                }
            }
            TimingEditMode.TimeWindows -> {
                ComposerTextField(
                    value = session.label,
                    label = stringResource(R.string.goal_schedule_edit_session_label),
                    onValueChange = { onLabelChange(session.draftId, it) },
                )
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                    TimeField(
                        label = stringResource(R.string.goal_schedule_edit_start_time),
                        time = session.startTime,
                        onTimeChange = { onStartChange(session.draftId, it) },
                        modifier = Modifier.weight(1f),
                    )
                    TimeField(
                        label = stringResource(R.string.goal_schedule_edit_end_time),
                        time = session.endTime,
                        onTimeChange = { onEndChange(session.draftId, it) },
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun TimeField(
    label: String,
    time: String,
    onTimeChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 4.dp),
        )
        ComposerTimePill(time = time, onTimeChange = onTimeChange, modifier = Modifier.fillMaxWidth())
    }
}

@Composable
private fun ScheduleValidationCard(errors: List<GoalUpdateError>) {
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
private fun ScheduleEditMode.title(): String =
    when (this) {
        ScheduleEditMode.Daily -> stringResource(R.string.schedule_daily)
        ScheduleEditMode.Weekly -> stringResource(R.string.schedule_weekly)
        ScheduleEditMode.Monthly -> stringResource(R.string.schedule_monthly_gregorian)
        ScheduleEditMode.Interval -> stringResource(R.string.schedule_interval)
        ScheduleEditMode.Yearly -> stringResource(R.string.schedule_yearly_hijri)
        ScheduleEditMode.Season -> stringResource(R.string.schedule_season)
        ScheduleEditMode.SpecificDates -> stringResource(R.string.schedule_specific_dates)
    }

@Composable
private fun TimingEditMode.title(): String =
    when (this) {
        TimingEditMode.Anytime -> stringResource(R.string.goal_summary_slots_anytime)
        TimingEditMode.PrayerSlots -> stringResource(R.string.goal_schedule_edit_prayer_slots)
        TimingEditMode.TimeWindows -> stringResource(R.string.goal_schedule_edit_time_windows)
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

private fun DayOfWeek.shortTitle(): String = name.take(3).lowercase().replaceFirstChar { it.uppercase() }

private fun Prayer.title(): String = name.lowercase().replaceFirstChar { it.uppercase() }

private fun PrayerRelation.title(): String = name.lowercase().replaceFirstChar { it.uppercase() }

private fun SeasonTemplateCode.title(): String =
    BuiltInSeasonTemplates.find(this)?.label ?: name.lowercase().replace('_', ' ').replaceFirstChar { it.uppercase() }

@Preview(showBackground = true)
@Composable
private fun EditGoalSchedulePreview() {
    AwradDhikrGoalsTrackerTheme {
        EditGoalScheduleContent(
            uiState = EditGoalScheduleUiState(
                isLoading = false,
                title = "Asthaghfirullahil Azeem",
                draft = EditGoalScheduleDraft(
                    scheduleMode = ScheduleEditMode.Weekly,
                    weekdays = setOf(DayOfWeek.MONDAY, DayOfWeek.THURSDAY),
                    timingMode = TimingEditMode.TimeWindows,
                    sessions = listOf(
                        EditScheduleSessionDraft(
                            draftId = 1,
                            slotType = GoalSlotType.TIME_WINDOW,
                            label = "Morning",
                            startTime = "06:00",
                            endTime = "09:00",
                        )
                    ),
                ),
            ),
            snackbarHostState = remember { SnackbarHostState() },
            onNavigateBack = {},
            onSave = {},
            onScheduleModeChange = {},
            onWeekdayToggle = {},
            onCalendarChange = {},
            onMonthDaysChange = {},
            onIntervalDaysChange = {},
            onYearlyMonthChange = {},
            onYearlyDaysChange = {},
            onSeasonChange = {},
            onSpecificDatesChange = {},
            onTimingModeChange = {},
            onAddSession = {},
            onRemoveSession = {},
            onMoveSession = { _, _ -> },
            onSessionLabelChange = { _, _ -> },
            onSessionPrayerChange = { _, _ -> },
            onSessionRelationChange = { _, _ -> },
            onSessionLeadChange = { _, _ -> },
            onSessionStartChange = { _, _ -> },
            onSessionEndChange = { _, _ -> },
        )
    }
}
