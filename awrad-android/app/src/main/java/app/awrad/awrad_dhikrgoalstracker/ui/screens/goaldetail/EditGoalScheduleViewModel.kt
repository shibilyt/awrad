package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.BuiltInSeasonTemplates
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalScheduleUpdateFactory
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateError
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.PrayerSlotUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ScheduleSpec
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ScheduleTimingUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.TimeWindowSlotUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalScheduleCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalScheduleResult
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.UpdateGoalScheduleUseCase
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.DayOfWeek
import java.time.LocalDate
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class ScheduleEditMode {
    Daily,
    Weekly,
    Monthly,
    Interval,
    Yearly,
    Season,
    SpecificDates,
}

enum class TimingEditMode {
    Anytime,
    PrayerSlots,
    TimeWindows,
}

data class EditGoalScheduleUiState(
    val isLoading: Boolean = true,
    val goal: Goal? = null,
    val title: String = "",
    val draft: EditGoalScheduleDraft = EditGoalScheduleDraft(),
    val originalDraft: EditGoalScheduleDraft = EditGoalScheduleDraft(),
    val validationErrors: List<GoalUpdateError> = emptyList(),
    val isSaving: Boolean = false,
    val saveCompleted: Boolean = false,
    val saveFailed: Boolean = false,
) {
    val isDirty: Boolean get() = draft != originalDraft
    val canSave: Boolean get() = !isLoading && !isSaving && isDirty && validationErrors.isEmpty()
}

data class EditGoalScheduleDraft(
    val scheduleMode: ScheduleEditMode = ScheduleEditMode.Daily,
    val weekdays: Set<DayOfWeek> = emptySet(),
    val calendar: CalendarSystem = CalendarSystem.GREGORIAN,
    val monthDaysText: String = "1",
    val intervalDaysText: String = "1",
    val yearlyMonthText: String = "9",
    val yearlyDaysText: String = "1",
    val seasonTemplateCode: SeasonTemplateCode = SeasonTemplateCode.RAMADAN,
    val specificDatesText: String = LocalDate.now().toString(),
    val timingMode: TimingEditMode = TimingEditMode.Anytime,
    val sessions: List<EditScheduleSessionDraft> = listOf(EditScheduleSessionDraft.anytime()),
)

data class EditScheduleSessionDraft(
    val draftId: Long,
    val slotId: Long? = null,
    val slotType: GoalSlotType = GoalSlotType.ANYTIME,
    val label: String = "",
    val prayer: Prayer = Prayer.FAJR,
    val relation: PrayerRelation = PrayerRelation.AFTER,
    val beforeLeadMinutes: String = "30",
    val startTime: String = "06:00",
    val endTime: String = "09:00",
) {
    companion object {
        fun anytime(slotId: Long? = null, draftId: Long = slotId ?: -1L) =
            EditScheduleSessionDraft(
                draftId = draftId,
                slotId = slotId,
                slotType = GoalSlotType.ANYTIME,
                label = "Anytime",
            )
    }
}

@HiltViewModel
class EditGoalScheduleViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val goalRepository: GoalRepository,
    private val dhikrRepository: DhikrRepository,
    private val updateGoalScheduleUseCase: UpdateGoalScheduleUseCase,
    private val reminderScheduler: ReminderScheduler,
) : ViewModel() {

    private val goalId: Long = savedStateHandle["goalId"] ?: -1L
    private var nextDraftId = -1L

    private val _uiState = MutableStateFlow(EditGoalScheduleUiState())
    val uiState: StateFlow<EditGoalScheduleUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun onScheduleModeChange(mode: ScheduleEditMode) {
        updateDraft { it.copy(scheduleMode = mode).withScheduleDefaults(mode) }
    }

    fun onWeekdayToggle(day: DayOfWeek) {
        updateDraft { draft ->
            val weekdays = if (day in draft.weekdays) draft.weekdays - day else draft.weekdays + day
            draft.copy(weekdays = weekdays)
        }
    }

    fun onCalendarChange(calendar: CalendarSystem) {
        updateDraft { it.copy(calendar = calendar) }
    }

    fun onMonthDaysChange(value: String) {
        updateDraft { it.copy(monthDaysText = value.filteredDateListText()) }
    }

    fun onIntervalDaysChange(value: String) {
        updateDraft { it.copy(intervalDaysText = value.onlyDigits()) }
    }

    fun onYearlyMonthChange(value: String) {
        updateDraft { it.copy(yearlyMonthText = value.onlyDigits()) }
    }

    fun onYearlyDaysChange(value: String) {
        updateDraft { it.copy(yearlyDaysText = value.filteredDateListText()) }
    }

    fun onSeasonChange(code: SeasonTemplateCode) {
        updateDraft { it.copy(seasonTemplateCode = code) }
    }

    fun onSpecificDatesChange(value: String) {
        updateDraft { it.copy(specificDatesText = value.filter { char -> char.isDigit() || char == '-' || char == ',' || char == '\n' || char == ' ' }) }
    }

    fun onTimingModeChange(mode: TimingEditMode) {
        updateDraft { draft ->
            val sessions = when (mode) {
                TimingEditMode.Anytime -> listOf(
                    draft.sessions.firstOrNull { it.slotType == GoalSlotType.ANYTIME }
                        ?: EditScheduleSessionDraft.anytime(draftId = nextTempId())
                )
                TimingEditMode.PrayerSlots -> draft.sessions
                    .filter { it.slotType == GoalSlotType.PRAYER }
                    .takeIf { it.isNotEmpty() }
                    ?: listOf(newPrayerSession())
                TimingEditMode.TimeWindows -> draft.sessions
                    .filter { it.slotType == GoalSlotType.TIME_WINDOW }
                    .takeIf { it.isNotEmpty() }
                    ?: listOf(newTimeWindowSession(1))
            }
            draft.copy(timingMode = mode, sessions = sessions)
        }
    }

    fun onAddSession() {
        updateDraft { draft ->
            val nextSession = when (draft.timingMode) {
                TimingEditMode.Anytime -> return@updateDraft draft
                TimingEditMode.PrayerSlots -> newPrayerSession(draft.sessions)
                TimingEditMode.TimeWindows -> newTimeWindowSession(draft.sessions.size + 1)
            }
            draft.copy(sessions = draft.sessions + nextSession)
        }
    }

    fun onRemoveSession(draftId: Long) {
        updateDraft { draft ->
            if (draft.sessions.size <= 1) draft else draft.copy(sessions = draft.sessions.filterNot { it.draftId == draftId })
        }
    }

    fun onMoveSession(draftId: Long, direction: Int) {
        updateDraft { draft ->
            val index = draft.sessions.indexOfFirst { it.draftId == draftId }
            val target = (index + direction).coerceIn(0, draft.sessions.lastIndex)
            if (index < 0 || index == target) return@updateDraft draft
            val mutable = draft.sessions.toMutableList()
            val item = mutable.removeAt(index)
            mutable.add(target, item)
            draft.copy(sessions = mutable)
        }
    }

    fun onSessionLabelChange(draftId: Long, value: String) {
        updateSession(draftId) { it.copy(label = value) }
    }

    fun onSessionPrayerChange(draftId: Long, prayer: Prayer) {
        updateSession(draftId) { it.copy(prayer = prayer) }
    }

    fun onSessionRelationChange(draftId: Long, relation: PrayerRelation) {
        updateSession(draftId) { it.copy(relation = relation) }
    }

    fun onSessionLeadChange(draftId: Long, value: String) {
        updateSession(draftId) { it.copy(beforeLeadMinutes = value.onlyDigits()) }
    }

    fun onSessionStartChange(draftId: Long, value: String) {
        updateSession(draftId) { it.copy(startTime = value.filteredTimeText()) }
    }

    fun onSessionEndChange(draftId: Long, value: String) {
        updateSession(draftId) { it.copy(endTime = value.filteredTimeText()) }
    }

    fun onSaveResultConsumed() {
        _uiState.update { it.copy(saveCompleted = false, saveFailed = false) }
    }

    fun save() {
        val command = _uiState.value.toCommand() ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true, saveFailed = false) }
            when (val result = updateGoalScheduleUseCase(command)) {
                is UpdateGoalScheduleResult.Updated -> {
                    reminderScheduler.rescheduleAll()
                    _uiState.update {
                        it.copy(
                            isSaving = false,
                            saveCompleted = true,
                            goal = result.updatedGoal.goal,
                            originalDraft = it.draft,
                        )
                    }
                }
                is UpdateGoalScheduleResult.Invalid -> {
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
                _uiState.value = EditGoalScheduleUiState(isLoading = false)
                return@launch
            }
            val dhikr = goal.dhikr ?: dhikrRepository.getAllDhikrs().first().firstOrNull { it.id == goal.dhikrId }
            val draft = goal.toScheduleDraft()
            _uiState.value = EditGoalScheduleUiState(
                isLoading = false,
                goal = goal,
                title = dhikr?.transliteration?.ifBlank { dhikr.title }.orEmpty().ifBlank { dhikr?.title.orEmpty() },
                draft = draft,
                originalDraft = draft,
            ).validated()
        }
    }

    private fun updateDraft(transform: (EditGoalScheduleDraft) -> EditGoalScheduleDraft) {
        _uiState.update { state -> state.copy(draft = transform(state.draft)).validated() }
    }

    private fun updateSession(draftId: Long, transform: (EditScheduleSessionDraft) -> EditScheduleSessionDraft) {
        updateDraft { draft ->
            draft.copy(sessions = draft.sessions.map { if (it.draftId == draftId) transform(it) else it })
        }
    }

    private fun EditGoalScheduleUiState.validated(): EditGoalScheduleUiState {
        val goal = goal ?: return this
        val command = toCommand() ?: return copy(validationErrors = listOf(GoalUpdateError.InvalidTiming))
        return when (val result = GoalScheduleUpdateFactory.update(goal, command)) {
            is GoalUpdateResult.Valid -> copy(validationErrors = emptyList())
            is GoalUpdateResult.Invalid -> copy(validationErrors = result.errors)
        }
    }

    private fun EditGoalScheduleUiState.toCommand(): UpdateGoalScheduleCommand? {
        val goal = goal ?: return null
        return UpdateGoalScheduleCommand(
            goalId = goal.id,
            schedule = draft.toScheduleSpec(),
            timing = draft.toTimingUpdate(),
        )
    }

    private fun Goal.toScheduleDraft(): EditGoalScheduleDraft {
        val scheduleMode = recurrence.frequency.toEditMode()
        val timingMode = slots.toTimingMode()
        return EditGoalScheduleDraft(
            scheduleMode = scheduleMode,
            weekdays = recurrence.weekdays,
            calendar = recurrence.calendar,
            monthDaysText = recurrence.monthDays.sorted().joinToString(", ").ifBlank { "1" },
            intervalDaysText = (recurrence.intervalDays ?: 1).toString(),
            yearlyMonthText = (recurrence.month ?: 9).toString(),
            yearlyDaysText = recurrence.monthDays.sorted().joinToString(", ").ifBlank { "1" },
            seasonTemplateCode = recurrence.seasonTemplateCode ?: SeasonTemplateCode.RAMADAN,
            specificDatesText = recurrence.specificDates.mapNotNull { it.date }.sorted().joinToString("\n").ifBlank { LocalDate.now().toString() },
            timingMode = timingMode,
            sessions = slots.sortedBy { it.sortOrder }.map { it.toSessionDraft() }
                .ifEmpty { listOf(EditScheduleSessionDraft.anytime()) },
        ).withScheduleDefaults(scheduleMode)
    }

    private fun RecurrenceFrequency.toEditMode(): ScheduleEditMode =
        when (this) {
            RecurrenceFrequency.DAILY -> ScheduleEditMode.Daily
            RecurrenceFrequency.WEEKLY -> ScheduleEditMode.Weekly
            RecurrenceFrequency.MONTHLY -> ScheduleEditMode.Monthly
            RecurrenceFrequency.INTERVAL -> ScheduleEditMode.Interval
            RecurrenceFrequency.YEARLY -> ScheduleEditMode.Yearly
            RecurrenceFrequency.SEASON -> ScheduleEditMode.Season
            RecurrenceFrequency.SPECIFIC_DATES -> ScheduleEditMode.SpecificDates
        }

    private fun List<GoalSlot>.toTimingMode(): TimingEditMode =
        when {
            isEmpty() -> TimingEditMode.Anytime
            all { it.slotType == GoalSlotType.PRAYER } -> TimingEditMode.PrayerSlots
            all { it.slotType == GoalSlotType.TIME_WINDOW } -> TimingEditMode.TimeWindows
            else -> TimingEditMode.Anytime
        }

    private fun GoalSlot.toSessionDraft(): EditScheduleSessionDraft =
        when (slotType) {
            GoalSlotType.ANYTIME -> EditScheduleSessionDraft.anytime(slotId = id, draftId = id)
            GoalSlotType.PRAYER -> EditScheduleSessionDraft(
                draftId = id,
                slotId = id,
                slotType = GoalSlotType.PRAYER,
                label = label.orEmpty(),
                prayer = prayerName ?: Prayer.FAJR,
                relation = prayerRelation ?: PrayerRelation.AFTER,
                beforeLeadMinutes = (startLeadMinutesOverride ?: 30).toString(),
            )
            GoalSlotType.TIME_WINDOW -> EditScheduleSessionDraft(
                draftId = id,
                slotId = id,
                slotType = GoalSlotType.TIME_WINDOW,
                label = label ?: "Session ${sortOrder + 1}",
                startTime = (startMinute ?: 6 * 60).toTimeText(),
                endTime = (endMinute ?: 9 * 60).toTimeText(),
            )
        }

    private fun EditGoalScheduleDraft.withScheduleDefaults(mode: ScheduleEditMode): EditGoalScheduleDraft =
        when (mode) {
            ScheduleEditMode.Weekly -> if (weekdays.isEmpty()) copy(weekdays = setOf(LocalDate.now().dayOfWeek)) else this
            ScheduleEditMode.Monthly -> if (monthDaysText.isBlank()) copy(monthDaysText = "1") else this
            ScheduleEditMode.Interval -> if (intervalDaysText.isBlank()) copy(intervalDaysText = "1") else this
            ScheduleEditMode.Yearly -> copy(
                yearlyMonthText = yearlyMonthText.ifBlank { "9" },
                yearlyDaysText = yearlyDaysText.ifBlank { "1" },
            )
            ScheduleEditMode.SpecificDates -> if (specificDatesText.isBlank()) copy(specificDatesText = LocalDate.now().toString()) else this
            ScheduleEditMode.Daily,
            ScheduleEditMode.Season -> this
        }

    private fun EditGoalScheduleDraft.toScheduleSpec(): ScheduleSpec =
        when (scheduleMode) {
            ScheduleEditMode.Daily -> ScheduleSpec.Daily
            ScheduleEditMode.Weekly -> ScheduleSpec.Weekly(weekdays)
            ScheduleEditMode.Monthly -> ScheduleSpec.Monthly(calendar = calendar, daysOfMonth = monthDaysText.toDaySet())
            ScheduleEditMode.Interval -> ScheduleSpec.Interval(intervalDays = intervalDaysText.toIntOrNull() ?: 0)
            ScheduleEditMode.Yearly -> ScheduleSpec.Yearly(
                calendar = calendar,
                month = yearlyMonthText.toIntOrNull() ?: 0,
                daysOfMonth = yearlyDaysText.toDaySet(),
            )
            ScheduleEditMode.Season -> ScheduleSpec.Season(seasonTemplateCode)
            ScheduleEditMode.SpecificDates -> ScheduleSpec.SpecificDates(specificDatesText.toDateSet())
        }

    private fun EditGoalScheduleDraft.toTimingUpdate(): ScheduleTimingUpdate =
        when (timingMode) {
            TimingEditMode.Anytime -> {
                val session = sessions.firstOrNull()
                ScheduleTimingUpdate.Anytime(slotId = session?.slotId, label = session?.label)
            }
            TimingEditMode.PrayerSlots -> ScheduleTimingUpdate.PrayerBased(
                sessions.map {
                    PrayerSlotUpdate(
                        slotId = it.slotId,
                        prayer = it.prayer,
                        relation = it.relation,
                        beforeLeadMinutes = it.beforeLeadMinutes.toIntOrNull(),
                        label = it.label,
                    )
                }
            )
            TimingEditMode.TimeWindows -> ScheduleTimingUpdate.TimeWindows(
                sessions.map {
                    TimeWindowSlotUpdate(
                        slotId = it.slotId,
                        label = it.label,
                        startMinute = it.startTime.toMinuteOfDay() ?: -1,
                        endMinute = it.endTime.toMinuteOfDay() ?: -1,
                    )
                }
            )
        }

    private fun newPrayerSession(existingSessions: List<EditScheduleSessionDraft> = emptyList()): EditScheduleSessionDraft {
        val used = existingSessions.map { it.prayer to it.relation }.toSet()
        val nextPair = Prayer.entries.flatMap { prayer ->
            listOf(prayer to PrayerRelation.AFTER, prayer to PrayerRelation.BEFORE)
        }.firstOrNull { it !in used } ?: (Prayer.FAJR to PrayerRelation.AFTER)
        return EditScheduleSessionDraft(
            draftId = nextTempId(),
            slotType = GoalSlotType.PRAYER,
            label = "${nextPair.second.displayName()} ${nextPair.first.displayName()}",
            prayer = nextPair.first,
            relation = nextPair.second,
        )
    }

    private fun newTimeWindowSession(index: Int): EditScheduleSessionDraft {
        val startHour = (6 + (index - 1) * 3).coerceAtMost(22)
        return EditScheduleSessionDraft(
            draftId = nextTempId(),
            slotType = GoalSlotType.TIME_WINDOW,
            label = "Session $index",
            startTime = "%02d:00".format(startHour),
            endTime = "%02d:00".format((startHour + 1).coerceAtMost(23)),
        )
    }

    private fun nextTempId(): Long = nextDraftId--
}

private fun String.onlyDigits(): String = filter { it.isDigit() }

private fun String.filteredDateListText(): String =
    filter { it.isDigit() || it == ',' || it == ' ' || it == '\n' }

private fun String.filteredTimeText(): String =
    filter { it.isDigit() || it == ':' }.take(5)

private fun String.toDaySet(): Set<Int> =
    split(',', ' ', '\n')
        .mapNotNull { it.trim().takeIf { value -> value.isNotEmpty() } }
        .takeIf { it.isNotEmpty() }
        ?.map { it.toIntOrNull() }
        ?.takeIf { values -> values.all { it != null && it in 1..31 } }
        ?.mapNotNull { it }
        ?.toSet()
        ?: emptySet()

private fun String.toDateSet(): Set<LocalDate> =
    split(',', '\n')
        .mapNotNull { raw -> raw.trim().takeIf { it.isNotEmpty() } }
        .takeIf { it.isNotEmpty() }
        ?.map { runCatching { LocalDate.parse(it) }.getOrNull() }
        ?.takeIf { dates -> dates.all { it != null } }
        ?.mapNotNull { it }
        ?.toSet()
        ?: emptySet()

private fun String.toMinuteOfDay(): Int? {
    if (':' !in this && length in 3..4) {
        val padded = padStart(4, '0')
        val hour = padded.take(2).toIntOrNull() ?: return null
        val minute = padded.takeLast(2).toIntOrNull() ?: return null
        if (hour !in 0..23 || minute !in 0..59) return null
        return hour * 60 + minute
    }
    val parts = split(':')
    val hour = parts.getOrNull(0)?.toIntOrNull() ?: return null
    val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0
    if (hour !in 0..23 || minute !in 0..59) return null
    return hour * 60 + minute
}

private fun Int.toTimeText(): String {
    val hour = (this / 60).coerceIn(0, 23)
    val minute = (this % 60).coerceIn(0, 59)
    return "%02d:%02d".format(hour, minute)
}

private fun Prayer.displayName(): String =
    name.lowercase().replaceFirstChar { it.uppercase() }

private fun PrayerRelation.displayName(): String =
    name.lowercase().replaceFirstChar { it.uppercase() }
