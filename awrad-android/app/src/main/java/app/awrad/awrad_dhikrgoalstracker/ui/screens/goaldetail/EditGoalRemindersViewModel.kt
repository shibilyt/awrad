package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalReminderUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalReminderUpdateFactory
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateError
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalRemindersCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalRemindersResult
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.UpdateGoalRemindersUseCase
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderSchedulingGateway
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class EditGoalRemindersUiState(
    val isLoading: Boolean = true,
    val goal: Goal? = null,
    val title: String = "",
    val draft: EditGoalRemindersDraft = EditGoalRemindersDraft(),
    val originalDraft: EditGoalRemindersDraft = EditGoalRemindersDraft(),
    val validationErrors: List<GoalUpdateError> = emptyList(),
    val canScheduleExactAlarms: Boolean = true,
    val isSaving: Boolean = false,
    val saveCompleted: Boolean = false,
    val saveFailed: Boolean = false,
) {
    val isDirty: Boolean get() = draft != originalDraft
    val canSave: Boolean get() = !isLoading && !isSaving && isDirty && validationErrors.isEmpty()
    val prayerSlots: List<GoalSlot> get() = goal?.slots.orEmpty().filter { it.slotType == GoalSlotType.PRAYER }
    val timeWindowSlots: List<GoalSlot> get() = goal?.slots.orEmpty().filter { it.slotType == GoalSlotType.TIME_WINDOW }
    val canAddPrayerReminder: Boolean get() = prayerSlots.isNotEmpty()
    val canAddTimeWindowReminder: Boolean get() = timeWindowSlots.isNotEmpty()
}

data class EditGoalRemindersDraft(
    val reminders: List<EditReminderDraft> = emptyList(),
)

data class EditReminderDraft(
    val draftId: Long,
    val reminderId: Long? = null,
    val reminderType: ReminderType = ReminderType.FIXED_TIME,
    val slotId: Long? = null,
    val hourText: String = "8",
    val minuteText: String = "00",
    val offsetText: String = DEFAULT_PRAYER_OFFSET_MINUTES.toString(),
    val enabled: Boolean = true,
)

@HiltViewModel
class EditGoalRemindersViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val goalRepository: GoalRepository,
    private val dhikrRepository: DhikrRepository,
    private val updateGoalRemindersUseCase: UpdateGoalRemindersUseCase,
    private val reminderScheduler: ReminderSchedulingGateway,
) : ViewModel() {

    private val goalId: Long = savedStateHandle["goalId"] ?: -1L
    private var nextDraftId = -1L

    private val _uiState = MutableStateFlow(EditGoalRemindersUiState())
    val uiState: StateFlow<EditGoalRemindersUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun onAddReminder(reminderType: ReminderType) {
        updateDraft { draft ->
            draft.copy(reminders = draft.reminders + newReminder(reminderType))
        }
    }

    fun onDeleteReminder(draftId: Long) {
        updateDraft { draft ->
            draft.copy(reminders = draft.reminders.filterNot { it.draftId == draftId })
        }
    }

    fun onMoveReminder(draftId: Long, direction: Int) {
        updateDraft { draft ->
            val index = draft.reminders.indexOfFirst { it.draftId == draftId }
            val target = (index + direction).coerceIn(0, draft.reminders.lastIndex)
            if (index < 0 || index == target) return@updateDraft draft
            val mutable = draft.reminders.toMutableList()
            val item = mutable.removeAt(index)
            mutable.add(target, item)
            draft.copy(reminders = mutable)
        }
    }

    fun onToggleReminder(draftId: Long, enabled: Boolean) {
        updateReminder(draftId) { it.copy(enabled = enabled) }
    }

    fun onHourChange(draftId: Long, value: String) {
        updateReminder(draftId) { it.copy(hourText = value.onlyDigits().take(2)) }
    }

    fun onMinuteChange(draftId: Long, value: String) {
        updateReminder(draftId) { it.copy(minuteText = value.onlyDigits().take(2)) }
    }

    fun onOffsetChange(draftId: Long, value: String) {
        updateReminder(draftId) { it.copy(offsetText = value.onlyDigits().take(3)) }
    }

    fun onTargetChange(draftId: Long, slotId: Long?) {
        updateReminder(draftId) { it.copy(slotId = slotId) }
    }

    fun onSaveResultConsumed() {
        _uiState.update { it.copy(saveCompleted = false, saveFailed = false) }
    }

    fun save() {
        val command = _uiState.value.toCommand() ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true, saveFailed = false) }
            when (val result = updateGoalRemindersUseCase(command)) {
                is UpdateGoalRemindersResult.Updated -> {
                    reminderScheduler.rescheduleAll()
                    val draft = result.updatedGoal.goal.toRemindersDraft()
                    _uiState.update {
                        it.copy(
                            isSaving = false,
                            saveCompleted = true,
                            goal = result.updatedGoal.goal,
                            draft = draft,
                            originalDraft = draft,
                            validationErrors = emptyList(),
                        )
                    }
                }
                is UpdateGoalRemindersResult.Invalid -> {
                    _uiState.update {
                        it.copy(
                            isSaving = false,
                            saveFailed = true,
                            validationErrors = result.errors,
                        )
                    }
                }
            }
        }
    }

    private fun load() {
        viewModelScope.launch {
            val goal = goalRepository.getGoalById(goalId)
            if (goal == null) {
                _uiState.value = EditGoalRemindersUiState(
                    isLoading = false,
                    canScheduleExactAlarms = reminderScheduler.canScheduleExactAlarms(),
                )
                return@launch
            }
            val dhikr = goal.dhikr ?: dhikrRepository.getAllDhikrs().first().firstOrNull { it.id == goal.dhikrId }
            val draft = goal.toRemindersDraft()
            _uiState.value = EditGoalRemindersUiState(
                isLoading = false,
                goal = goal,
                title = dhikr?.transliteration?.ifBlank { dhikr.title }.orEmpty().ifBlank { dhikr?.title.orEmpty() },
                draft = draft,
                originalDraft = draft,
                canScheduleExactAlarms = reminderScheduler.canScheduleExactAlarms(),
            ).validated()
        }
    }

    private fun updateDraft(transform: (EditGoalRemindersDraft) -> EditGoalRemindersDraft) {
        _uiState.update { state -> state.copy(draft = transform(state.draft)).validated() }
    }

    private fun updateReminder(draftId: Long, transform: (EditReminderDraft) -> EditReminderDraft) {
        updateDraft { draft ->
            draft.copy(reminders = draft.reminders.map { if (it.draftId == draftId) transform(it) else it })
        }
    }

    private fun EditGoalRemindersUiState.validated(): EditGoalRemindersUiState {
        val goal = goal ?: return this
        val command = toCommand() ?: return copy(validationErrors = listOf(GoalUpdateError.InvalidReminder))
        return when (val result = GoalReminderUpdateFactory.update(goal, command)) {
            is GoalUpdateResult.Valid -> copy(validationErrors = emptyList())
            is GoalUpdateResult.Invalid -> copy(validationErrors = result.errors)
        }
    }

    private fun EditGoalRemindersUiState.toCommand(): UpdateGoalRemindersCommand? {
        val goal = goal ?: return null
        return UpdateGoalRemindersCommand(
            goalId = goal.id,
            reminders = draft.reminders.map { it.toUpdate() },
        )
    }

    private fun EditReminderDraft.toUpdate(): GoalReminderUpdate =
        GoalReminderUpdate(
            reminderId = reminderId,
            reminderType = reminderType,
            slotId = when (reminderType) {
                ReminderType.FIXED_TIME -> null
                ReminderType.PRAYER_OFFSET,
                ReminderType.TIME_WINDOW_START -> slotId
            },
            hour = if (reminderType == ReminderType.FIXED_TIME) hourText.toIntOrNull() else null,
            minute = if (reminderType == ReminderType.FIXED_TIME) minuteText.toIntOrNull() else null,
            offsetMinutes = when (reminderType) {
                ReminderType.FIXED_TIME -> null
                ReminderType.PRAYER_OFFSET -> offsetText.toIntOrNull()
                ReminderType.TIME_WINDOW_START -> 0
            },
            enabled = enabled,
        )

    private fun Goal.toRemindersDraft(): EditGoalRemindersDraft =
        EditGoalRemindersDraft(
            reminders = reminders
                .sortedWith(compareBy<GoalReminder> { it.sortOrder }.thenBy { it.id })
                .map { it.toDraft() },
        )

    private fun GoalReminder.toDraft(): EditReminderDraft =
        EditReminderDraft(
            draftId = id.takeIf { it > 0 } ?: nextTempId(),
            reminderId = id.takeIf { it > 0 },
            reminderType = reminderType,
            slotId = slotId,
            hourText = (hour ?: 8).toString(),
            minuteText = "%02d".format(minute ?: 0),
            offsetText = (offsetMinutes ?: DEFAULT_PRAYER_OFFSET_MINUTES).toString(),
            enabled = enabled,
        )

    private fun newReminder(reminderType: ReminderType): EditReminderDraft =
        EditReminderDraft(
            draftId = nextTempId(),
            reminderType = reminderType,
            hourText = "8",
            minuteText = "00",
            offsetText = DEFAULT_PRAYER_OFFSET_MINUTES.toString(),
        )

    private fun nextTempId(): Long = nextDraftId--
}

private const val DEFAULT_PRAYER_OFFSET_MINUTES = 10

private fun String.onlyDigits(): String = filter { it.isDigit() }
