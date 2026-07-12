package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetType
import app.awrad.awrad_dhikrgoalstracker.data.model.TimingType
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CreateGoalResult
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.CreateGoalUseCase
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.service.AudioPreviewPlayer
import app.awrad.awrad_dhikrgoalstracker.service.PreviewPlaybackState
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.ExtrasDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.FrequencyDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalCreationMode
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftDefaults
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftMapper
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftSection
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalTimingDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalValidationMessage
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalValidationResult
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.SlotTargetMode
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.TargetDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.syncedWithTargetDraft
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOr
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

enum class PrayerTiming { BEFORE, AFTER, BOTH }

data class CreateGoalUiState(
    val allDhikrs: List<Dhikr> = emptyList(),
    val filteredDhikrs: List<Dhikr> = emptyList(),
    val searchQuery: String = "",
    val selectedDhikr: Dhikr? = null,
    val mode: GoalCreationMode = GoalCreationMode.SelectDhikr,
    val draft: GoalDraft? = null,
    val isDhikrLocked: Boolean = false,
    /**
     * Where the shared dhikr picker advances to once a dhikr is chosen. The entry
     * picker advances to [GoalCreationMode.SelectShape]; a "change dhikr" detour
     * from a later screen returns to that screen.
     */
    val dhikrReturnMode: GoalCreationMode = GoalCreationMode.SelectShape,
    val isCreating: Boolean = false,
    val createdGoalId: Long? = null,
    val validation: GoalValidationResult = GoalValidationResult(
        mapOf(
            GoalDraftSection.Dhikr to GoalValidationMessage.SelectDhikr,
            GoalDraftSection.Template to GoalValidationMessage.ChooseTemplate,
        )
    ),
)

@HiltViewModel
class CreateGoalViewModel @Inject constructor(
    private val dhikrRepository: DhikrRepository,
    private val createGoalUseCase: CreateGoalUseCase,
    private val scheduler: ReminderScheduler,
    private val dateProvider: DateProvider,
    val audioPlayer: AudioPreviewPlayer,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val _state = MutableStateFlow(CreateGoalUiState())
    private val _searchQuery = MutableStateFlow("")

    val audioState: StateFlow<PreviewPlaybackState> = audioPlayer.state

    init {
        val dhikrId = savedStateHandle.get<Long>("dhikrId")?.takeIf { it != -1L }
        if (dhikrId != null) {
            viewModelScope.launch {
                val dhikr = dhikrRepository.getDhikrById(dhikrId)
                if (dhikr != null) {
                    setState(
                        _state.value.copy(
                            selectedDhikr = dhikr,
                            mode = GoalCreationMode.SelectShape,
                            isDhikrLocked = true,
                        )
                    )
                }
            }
        }
    }

    val uiState: StateFlow<CreateGoalUiState> = combine(
        _state,
        dhikrRepository.getAllDhikrs(),
        _searchQuery,
    ) { state, allDhikrs, query ->
        val filtered = if (query.isBlank()) {
            allDhikrs
        } else {
            allDhikrs.filter {
                it.title.contains(query, ignoreCase = true) ||
                    it.transliteration.contains(query, ignoreCase = true) ||
                    it.translation.contains(query, ignoreCase = true) ||
                    it.arabic.contains(query)
            }
        }
        state.copy(
            allDhikrs = allDhikrs,
            filteredDhikrs = filtered,
            searchQuery = query,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = CreateGoalUiState(),
    )

    fun onSearchQueryChange(query: String) {
        _searchQuery.value = query
    }

    /** Simple path: choose a goal shape, then collect the target on [GoalCreationMode.SimpleTarget]. */
    fun selectShape(preset: GoalPreset) {
        setState(
            _state.value.copy(
                draft = GoalDraftDefaults.forPreset(preset),
                mode = GoalCreationMode.SimpleTarget,
            )
        )
    }

    /** Advanced path: open the full composer. Requires a dhikr — route through the picker first if none. */
    fun enterAdvanced() {
        val state = _state.value
        val next = if (state.selectedDhikr == null) {
            GoalCreationMode.SelectDhikr
        } else {
            GoalCreationMode.Advanced
        }
        setState(
            state.copy(
                draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM),
                mode = next,
                dhikrReturnMode = GoalCreationMode.Advanced,
            )
        )
    }

    /** Open the shared dhikr picker, returning to whichever screen requested it. */
    fun openDhikrPicker() {
        val state = _state.value
        setState(state.copy(mode = GoalCreationMode.SelectDhikr, dhikrReturnMode = state.mode))
    }

    fun selectDhikr(dhikr: Dhikr) {
        val state = _state.value
        setState(state.copy(selectedDhikr = dhikr, mode = state.dhikrReturnMode))
    }

    fun updateDraft(draft: GoalDraft) {
        setState(_state.value.copy(draft = draft))
    }

    fun updateFrequencyDraft(frequencyDraft: FrequencyDraft) {
        val draft = _state.value.draft ?: return
        setState(_state.value.copy(draft = draft.copy(frequencyDraft = frequencyDraft)))
    }

    fun updateTimingType(timing: TimingType) {
        val draft = _state.value.draft ?: return
        val nextTarget = when (timing) {
            TimingType.PRAYER_BASED -> draft.targetDraft as? TargetDraft.PrayerBased ?: TargetDraft.PrayerBased(
                uniformCount = when (val current = draft.targetDraft) {
                    is TargetDraft.Fixed -> current.count
                    is TargetDraft.PrayerBased -> current.uniformCount
                    TargetDraft.None -> "33"
                }
            )
            TimingType.ANYTIME, TimingType.TIME_BASED -> {
                if (draft.targetDraft is TargetDraft.None || draft.preset.defaultTargetType == TargetType.NONE) {
                    TargetDraft.None
                } else {
                    val count = when (val current = draft.targetDraft) {
                        is TargetDraft.Fixed -> current.count
                        is TargetDraft.PrayerBased -> current.uniformCount
                        TargetDraft.None -> "33"
                    }
                    TargetDraft.Fixed(count)
                }
            }
        }
        val advancedTiming = when (timing) {
            TimingType.ANYTIME -> GoalTimingDraft.Anytime
            TimingType.PRAYER_BASED -> GoalTimingDraft.PrayerBased
            TimingType.TIME_BASED -> if (draft.preset == GoalPreset.MORNING_EVENING) {
                GoalTimingDraft.MorningEvening
            } else {
                GoalTimingDraft.CustomSlots
            }
        }
        setState(_state.value.copy(draft = draft.copy(timingType = timing, advancedTiming = advancedTiming, targetDraft = nextTarget)))
    }

    fun updateTargetDraft(targetDraft: TargetDraft) {
        val draft = _state.value.draft ?: return
        setState(
            _state.value.copy(
                draft = draft.copy(
                    targetDraft = targetDraft,
                    countRule = draft.countRule.syncedWithTargetDraft(targetDraft),
                )
            )
        )
    }

    fun updateExtras(extras: ExtrasDraft) {
        val draft = _state.value.draft ?: return
        setState(_state.value.copy(draft = draft.copy(extras = extras)))
    }

    fun navigateBack(): Boolean {
        val state = _state.value
        return when (state.mode) {
            GoalCreationMode.SelectDhikr -> {
                // The entry picker (returns forward to SelectShape) exits on back. A "change
                // dhikr" detour returns to the screen that opened it.
                when (state.dhikrReturnMode) {
                    GoalCreationMode.SimpleTarget, GoalCreationMode.Advanced -> {
                        setState(state.copy(mode = state.dhikrReturnMode))
                        false
                    }
                    else -> true
                }
            }
            GoalCreationMode.SelectShape -> {
                // First screen when a dhikr was pre-supplied (locked) → exit; otherwise step
                // back to the entry dhikr picker.
                if (state.isDhikrLocked) {
                    true
                } else {
                    setState(state.copy(mode = GoalCreationMode.SelectDhikr, dhikrReturnMode = GoalCreationMode.SelectShape))
                    false
                }
            }
            GoalCreationMode.SimpleTarget,
            GoalCreationMode.Advanced -> {
                setState(state.copy(mode = GoalCreationMode.SelectShape))
                false
            }
        }
    }

    fun createGoal() {
        val state = _state.value
        val dhikr = state.selectedDhikr ?: return
        val draft = state.draft ?: return
        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        if (!validation.isValid) {
            setState(state.copy(validation = validation))
            return
        }

        setState(state.copy(isCreating = true, validation = validation))

        viewModelScope.launch {
            val startDate = dateProvider.getEffectiveToday().toLocalDateOr(LocalDate.now())
            val command = GoalDraftMapper.toCommand(
                dhikrId = dhikr.id,
                draft = draft,
                startDate = startDate,
            )
            when (val result = createGoalUseCase(command)) {
                is CreateGoalResult.Created -> {
                    val created = result.createdGoal
                    if (created.goal.reminders.any { it.enabled }) {
                        scheduler.scheduleForGoal(
                            created.goal.copy(
                                reminders = created.goal.reminders.map { it.copy(goalId = created.id) },
                            )
                        )
                    }
                    setState(_state.value.copy(isCreating = false, createdGoalId = created.id))
                }
                is CreateGoalResult.Invalid -> {
                    setState(_state.value.copy(isCreating = false))
                }
            }
        }
    }

    fun togglePlayback() {
        val dhikr = _state.value.selectedDhikr ?: return
        audioPlayer.toggle(dhikr.id, dhikr.audioUrl, dhikr.audioFileName)
    }

    private fun setState(state: CreateGoalUiState) {
        _state.value = state.copy(
            validation = GoalDraftMapper.validate(
                draft = state.draft,
                hasDhikr = state.selectedDhikr != null,
            )
        )
    }
}
