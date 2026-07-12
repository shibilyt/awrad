package app.awrad.awrad_dhikrgoalstracker.ui.screens.dhikrdetail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.DhikrBenefitsData
import app.awrad.awrad_dhikrgoalstracker.data.DhikrBenefitsRegistry
import app.awrad.awrad_dhikrgoalstracker.data.SuggestedGoal
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.FrequencyType
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CompletionPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CountPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CreateGoalCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CreateGoalResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ProgressScope
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ScheduleSpec
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.TimingSpec
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.CreateGoalUseCase
import app.awrad.awrad_dhikrgoalstracker.service.AudioDownloadManager
import app.awrad.awrad_dhikrgoalstracker.service.AudioPreviewPlayer
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOr
import app.awrad.awrad_dhikrgoalstracker.service.PreviewPlaybackState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

data class DhikrDetailUiState(
    val dhikr: Dhikr? = null,
    val benefitsData: DhikrBenefitsData? = null,
    val existingGoals: List<Goal> = emptyList(),
    val isLoading: Boolean = true,
    val pendingConfirmation: SuggestedGoal? = null,
)

@HiltViewModel
class DhikrDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val dhikrRepository: DhikrRepository,
    private val goalRepository: GoalRepository,
    private val createGoalUseCase: CreateGoalUseCase,
    private val audioDownloadManager: AudioDownloadManager,
    private val dateProvider: DateProvider,
    val audioPlayer: AudioPreviewPlayer,
) : ViewModel() {

    private val dhikrId: Long = checkNotNull(savedStateHandle["dhikrId"])

    private val _uiState = MutableStateFlow(DhikrDetailUiState())
    val uiState: StateFlow<DhikrDetailUiState> = _uiState.asStateFlow()

    val playerState: StateFlow<PreviewPlaybackState> = audioPlayer.state

    private val _isDownloading = MutableStateFlow(false)
    val isDownloading: StateFlow<Boolean> = _isDownloading.asStateFlow()

    private val _goalCreatedMessage = MutableSharedFlow<String>()
    val goalCreatedMessage: SharedFlow<String> = _goalCreatedMessage.asSharedFlow()

    init {
        loadDhikr()
        observeExistingGoals()
    }

    private fun loadDhikr() {
        viewModelScope.launch {
            val dhikr = dhikrRepository.getDhikrById(dhikrId)
            val benefits = dhikr?.let { DhikrBenefitsRegistry.getBenefits(it.transliteration) }
            _uiState.update {
                it.copy(
                    dhikr = dhikr,
                    benefitsData = benefits,
                    isLoading = false,
                )
            }
        }
    }

    private fun observeExistingGoals() {
        viewModelScope.launch {
            goalRepository.getActiveGoalsByDhikrId(dhikrId).collect { goals ->
                _uiState.update { it.copy(existingGoals = goals) }
            }
        }
    }

    fun isSuggestionAlreadyAdded(suggestion: SuggestedGoal): Boolean {
        return _uiState.value.existingGoals.any { goal ->
            goal.frequencyType == suggestion.frequencyType &&
                goal.isOneTime == suggestion.isOneTime &&
                goal.slots.firstOrNull()?.targetCount == suggestion.targetCount
        }
    }

    fun requestAddGoal(suggestion: SuggestedGoal) {
        if (isSuggestionAlreadyAdded(suggestion)) return
        _uiState.update { it.copy(pendingConfirmation = suggestion) }
    }

    fun dismissConfirmation() {
        _uiState.update { it.copy(pendingConfirmation = null) }
    }

    fun confirmAddGoal() {
        val suggestion = _uiState.value.pendingConfirmation ?: return
        val dhikr = _uiState.value.dhikr ?: return
        _uiState.update { it.copy(pendingConfirmation = null) }
        viewModelScope.launch {
            val command = CreateGoalCommand(
                dhikrId = dhikr.id,
                startDate = dateProvider.getEffectiveToday().toLocalDateOr(LocalDate.now()),
                schedule = suggestion.scheduleSpec(),
                timing = TimingSpec.Anytime,
                countPolicy = CountPolicy(targetCount = suggestion.targetCount),
                progressScope = if (suggestion.isOneTime) ProgressScope.Lifetime else ProgressScope.DueDate,
                completionPolicy = if (suggestion.isOneTime) CompletionPolicy.WhenTargetReached else CompletionPolicy.Never,
            )
            when (createGoalUseCase(command)) {
                is CreateGoalResult.Created -> _goalCreatedMessage.emit("Goal added!")
                is CreateGoalResult.Invalid -> _goalCreatedMessage.emit("Goal could not be added.")
            }
        }
    }

    fun togglePlayback() {
        val dhikr = _uiState.value.dhikr ?: return
        audioPlayer.toggle(dhikr.id, dhikr.audioUrl, dhikr.audioFileName)
    }

    fun downloadAudio() {
        val dhikr = _uiState.value.dhikr ?: return
        if (dhikr.isDownloaded || dhikr.audioUrl == null) return
        _isDownloading.value = true
        viewModelScope.launch {
            dhikrRepository.downloadDhikrAudio(dhikr)
            val updated = dhikrRepository.getDhikrById(dhikrId)
            _uiState.update { it.copy(dhikr = updated) }
            _isDownloading.value = false
        }
    }
}

private fun SuggestedGoal.scheduleSpec(): ScheduleSpec =
    when (frequencyType) {
        FrequencyType.DAILY -> ScheduleSpec.Daily
        FrequencyType.WEEKLY -> ScheduleSpec.Weekly(emptySet())
        FrequencyType.MONTHLY -> ScheduleSpec.Monthly(daysOfMonth = emptySet())
        FrequencyType.INTERVAL -> ScheduleSpec.Interval(intervalDays = 0)
        FrequencyType.YEARLY -> ScheduleSpec.Yearly(month = 0, daysOfMonth = emptySet())
        FrequencyType.SPECIFIC_DATES -> ScheduleSpec.SpecificDates(emptySet())
    }
