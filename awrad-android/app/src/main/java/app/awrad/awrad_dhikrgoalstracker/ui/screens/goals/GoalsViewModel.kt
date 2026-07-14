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
    val todayGoals: List<GoalDisplayItem> = emptyList(),
    val upcomingGoals: List<GoalDisplayItem> = emptyList(),
    val completedGoals: List<GoalDisplayItem> = emptyList(),
    val otherGoals: List<GoalDisplayItem> = emptyList(),
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

internal data class ActiveGoalSections(
    val today: List<GoalDisplayItem>,
    val upcoming: List<GoalDisplayItem>,
    val other: List<GoalDisplayItem>,
)

internal fun categorizeActiveGoals(
    goals: List<GoalDisplayItem>,
    today: LocalDate,
): ActiveGoalSections {
    val (todayGoals, notToday) = goals.partition { item ->
        GoalProgressCalculator.isDueToday(item.goal, today)
    }
    val (unfinishedTodayGoals, finishedTodayGoals) = todayGoals.partition { item ->
        item.overallProgress < 1f
    }
    val (upcomingGoals, otherGoals) = notToday.partition { item ->
        (1L..7L).any { daysAhead ->
            GoalProgressCalculator.isDueToday(item.goal, today.plusDays(daysAhead))
        }
    }
    return ActiveGoalSections(
        today = unfinishedTodayGoals + finishedTodayGoals,
        upcoming = upcomingGoals,
        other = otherGoals,
    )
}

internal fun completedGoalDisplayItem(
    goal: Goal,
    dhikrName: String,
): GoalDisplayItem = GoalDisplayItem(
    goal = goal,
    dhikrName = dhikrName,
    targetDisplay = GoalProgressCalculator.getFormattedTarget(goal),
    todayCount = goal.totalCompletedCount,
    dailyTarget = GoalProgressCalculator.getTargetCount(goal),
    overallProgress = 1f,
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
        ) { active, completedOrInactive, dhikrs, dailyCountsByGoal ->
            val dhikrMap = dhikrs.associateBy { it.id }
            val effectiveDate = today.toLocalDateOr(LocalDate.now())
            fun displayItem(goal: Goal): GoalDisplayItem {
                val dhikr = dhikrMap[goal.dhikrId]
                val dailyCounts = dailyCountsByGoal[goal.id].orEmpty()
                val progressSummary = goalProgressUseCase.summarize(goal, dailyCounts, effectiveDate)
                return GoalDisplayItem(
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
            }

            val activeSections = categorizeActiveGoals(active.map(::displayItem), effectiveDate)
            val (completedGoals, inactiveGoals) = completedOrInactive.partition { it.completedAt != null }

            GoalsUiState(
                todayGoals = activeSections.today,
                upcomingGoals = activeSections.upcoming,
                completedGoals = completedGoals.map { goal ->
                    val dhikr = dhikrMap[goal.dhikrId]
                    completedGoalDisplayItem(
                        goal = goal,
                        dhikrName = dhikr?.title.orEmpty().ifBlank { dhikr?.transliteration.orEmpty() },
                    )
                },
                otherGoals = activeSections.other + inactiveGoals.map(::displayItem),
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
