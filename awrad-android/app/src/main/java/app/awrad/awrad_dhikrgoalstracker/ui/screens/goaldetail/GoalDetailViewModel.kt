package app.awrad.awrad_dhikrgoalstracker.ui.screens.goaldetail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalLifecycleUpdateFactory
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.GoalProgressSummary
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.GoalProgressUseCase
import app.awrad.awrad_dhikrgoalstracker.notification.GoalReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.util.EffectiveTodayProvider
import app.awrad.awrad_dhikrgoalstracker.util.GoalCountingEligibility
import app.awrad.awrad_dhikrgoalstracker.util.GoalDayActivity
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.StreakInfo
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
import kotlinx.coroutines.launch

data class GoalDetailUiState(
    val isLoading: Boolean = true,
    val goal: Goal? = null,
    val dhikr: Dhikr? = null,
    val progress: GoalProgressSummary? = null,
    val effectiveToday: LocalDate = LocalDate.now(),
    val slotCountsToday: Map<AwradId, Long> = emptyMap(),
    val slotCountsAllTime: Map<AwradId, Long> = emptyMap(),
    val canContinueCounting: Boolean = false,
    val streakInfo: StreakInfo? = null,
    val recentDays: List<GoalDayActivity> = emptyList(),
    val todayCount: Long = 0,
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class GoalDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val goalRepository: GoalRepository,
    private val dhikrRepository: DhikrRepository,
    private val dateProvider: EffectiveTodayProvider,
    private val goalProgressUseCase: GoalProgressUseCase,
    private val scheduler: GoalReminderScheduler,
) : ViewModel() {

    private val goalId: AwradId = java.util.UUID.fromString(checkNotNull(savedStateHandle.get<String>("goalId")))

    val uiState = dateProvider.effectiveToday.flatMapLatest { todayString ->
        goalRepository.getGoalByIdFlow(goalId).withDetailState(todayString)
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
            val progress = goalProgressUseCase.summarize(goal, dailyCounts, effectiveToday)
            val streakInfo = GoalProgressCalculator.calculateStreakWithCounts(
                dailyCounts = dailyCounts,
                today = effectiveToday,
                dailyTarget = GoalProgressCalculator.getTargetCount(goal),
                minimumStreakCount = goal.minimumStreakCount,
                goal = goal,
            )
            val recentDays = GoalProgressCalculator.recentActivity(
                goal = goal,
                dailyCounts = dailyCounts,
                today = effectiveToday,
                dailySlotCounts = dailySlotCounts,
            )
            GoalDetailUiState(
                isLoading = false,
                goal = goal,
                dhikr = goal.dhikr ?: dhikrs.firstOrNull { it.id == goal.dhikrId },
                progress = progress,
                effectiveToday = effectiveToday,
                slotCountsToday = slotCountsToday,
                slotCountsAllTime = slotCountsAllTime,
                canContinueCounting = GoalCountingEligibility.canContinueCounting(
                    goal = goal,
                    progressCount = progress.progressCount,
                    slotCounts = slotCountsToday,
                ),
                streakInfo = streakInfo,
                recentDays = recentDays,
                todayCount = dailyCounts[effectiveToday] ?: 0L,
            )
        }
    }

    fun deleteGoal() {
        viewModelScope.launch {
            scheduler.cancelForGoal(goalId)
            goalRepository.deleteGoal(goalId)
        }
    }

    fun archiveGoal(goal: Goal) {
        val update = GoalLifecycleUpdateFactory.archive(goal) ?: return
        viewModelScope.launch {
            val archived = goalRepository.updateGoalLifecycle(update)
            scheduler.cancelForGoal(archived.id)
        }
    }

    fun restoreGoal(goal: Goal) {
        val update = GoalLifecycleUpdateFactory.restore(goal) ?: return
        viewModelScope.launch {
            val restored = goalRepository.updateGoalLifecycle(update)
            scheduler.scheduleForGoal(restored)
        }
    }
}
