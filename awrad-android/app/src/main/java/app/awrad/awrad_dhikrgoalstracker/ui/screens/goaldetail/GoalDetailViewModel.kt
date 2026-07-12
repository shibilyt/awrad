package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.GoalProgressSummary
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.GoalProgressUseCase
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOr
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.LocalDate
import javax.inject.Inject
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn

data class GoalDetailUiState(
    val isLoading: Boolean = true,
    val goal: Goal? = null,
    val dhikr: Dhikr? = null,
    val progress: GoalProgressSummary? = null,
    val effectiveToday: LocalDate = LocalDate.now(),
    val slotCountsToday: Map<Long, Long> = emptyMap(),
    val slotCountsAllTime: Map<Long, Long> = emptyMap(),
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class GoalDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val goalRepository: GoalRepository,
    private val dhikrRepository: DhikrRepository,
    private val dateProvider: DateProvider,
    private val goalProgressUseCase: GoalProgressUseCase,
) : ViewModel() {

    private val goalId: Long = savedStateHandle["goalId"] ?: -1L

    val uiState = dateProvider.effectiveToday.flatMapLatest { todayString ->
        if (goalId <= 0) {
            flowOf(GoalDetailUiState(isLoading = false))
        } else {
            goalRepository.getGoalByIdFlow(goalId).withDetailState(todayString)
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = GoalDetailUiState(),
    )

    private fun Flow<Goal?>.withDetailState(todayString: String) = combine(
        this,
        dhikrRepository.getAllDhikrs(),
        goalRepository.getDailyCountsByGoal(),
        goalRepository.getDailySlotCountsForGoal(goalId),
    ) { goal, dhikrs, dailyCountsByGoal, dailySlotCounts ->
        val effectiveToday = todayString.toLocalDateOr(LocalDate.now())
        if (goal == null) {
            GoalDetailUiState(isLoading = false, effectiveToday = effectiveToday)
        } else {
            val dailyCounts = dailyCountsByGoal[goal.id].orEmpty()
            val slotCountsToday = dailySlotCounts[effectiveToday].orEmpty()
            val slotCountsAllTime = dailySlotCounts.values
                .flatMap { it.entries }
                .groupingBy { it.key }
                .fold(0L) { total, entry -> total + entry.value }
            GoalDetailUiState(
                isLoading = false,
                goal = goal,
                dhikr = goal.dhikr ?: dhikrs.firstOrNull { it.id == goal.dhikrId },
                progress = goalProgressUseCase.summarize(goal, dailyCounts, effectiveToday),
                effectiveToday = effectiveToday,
                slotCountsToday = slotCountsToday,
                slotCountsAllTime = slotCountsAllTime,
            )
        }
    }
}
