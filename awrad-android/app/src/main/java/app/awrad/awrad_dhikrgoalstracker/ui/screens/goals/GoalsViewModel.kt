package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.GoalProgressUseCase
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOr
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

data class GoalsUiState(
    val activeGoals: List<GoalDisplayItem> = emptyList(),
    val completedGoals: List<GoalDisplayItem> = emptyList(),
    val isLoading: Boolean = true,
)

data class GoalDisplayItem(
    val goal: Goal,
    val dhikrName: String = "",
    val targetDisplay: String = "",
    val todayCount: Long = 0,
    val dailyTarget: Int = 0,
    val overallProgress: Float = 0f,
    /** Consecutive scheduled days meeting the streak threshold, ending today or yesterday. */
    val streakDays: Int = 0,
)

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel
class GoalsViewModel @Inject constructor(
    private val goalRepository: GoalRepository,
    private val dhikrRepository: DhikrRepository,
    private val scheduler: ReminderScheduler,
    private val dateProvider: DateProvider,
    private val goalProgressUseCase: GoalProgressUseCase,
) : ViewModel() {

    val uiState: StateFlow<GoalsUiState> = dateProvider.effectiveToday.flatMapLatest { today ->
        combine(
            goalRepository.getActiveGoals(),
            goalRepository.getCompletedGoals(),
            dhikrRepository.getAllDhikrs(),
            goalRepository.getDailyCountsByGoal(),
        ) { active, completed, dhikrs, dailyCountsByGoal ->
            val dhikrMap = dhikrs.associateBy { it.id }
            val effectiveDate = today.toLocalDateOr(LocalDate.now())

            GoalsUiState(
                activeGoals = active.map { goal ->
                    val dhikr = dhikrMap[goal.dhikrId]
                    val dailyCounts = dailyCountsByGoal[goal.id].orEmpty()
                    val progressSummary = goalProgressUseCase.summarize(goal, dailyCounts, effectiveDate)
                    GoalDisplayItem(
                        goal = goal,
                        dhikrName = dhikr?.title.orEmpty().ifBlank { dhikr?.transliteration.orEmpty() },
                        targetDisplay = progressSummary.targetDisplay,
                        todayCount = progressSummary.progressCount,
                        dailyTarget = progressSummary.targetCount,
                        overallProgress = progressSummary.progress,
                        streakDays = GoalProgressCalculator.calculateStreakWithCounts(
                            dailyCounts = dailyCounts,
                            today = effectiveDate,
                            dailyTarget = GoalProgressCalculator.getTargetCount(goal),
                            minimumStreakCount = goal.minimumStreakCount,
                            goal = goal,
                        ).currentStreak,
                    )
                },
                completedGoals = completed.map { goal ->
                    val dhikr = dhikrMap[goal.dhikrId]
                    GoalDisplayItem(
                        goal = goal,
                        dhikrName = dhikr?.title.orEmpty().ifBlank { dhikr?.transliteration.orEmpty() },
                        targetDisplay = GoalProgressCalculator.getFormattedTarget(goal),
                        overallProgress = 1f,
                    )
                },
                isLoading = false,
            )
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = GoalsUiState(),
    )

    fun deleteGoal(goalId: AwradId) {
        viewModelScope.launch {
            scheduler.cancelForGoal(goalId)
            goalRepository.deleteGoal(goalId)
        }
    }
}
