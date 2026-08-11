package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalLifecycleUpdateFactory
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.GoalProgressUseCase
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.StreakInfo
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
import java.time.temporal.ChronoUnit
import javax.inject.Inject

data class GoalsUiState(
    val todayGoals: List<GoalDisplayItem> = emptyList(),
    val upcomingGoals: List<GoalDisplayItem> = emptyList(),
    val pastGoals: List<GoalDisplayItem> = emptyList(),
    val completedGoals: List<GoalDisplayItem> = emptyList(),
    val archivedGoals: List<GoalDisplayItem> = emptyList(),
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
    /** Full streak info (active dates + daily counts) powering the history/streak card. */
    val streakInfo: StreakInfo? = null,
    /** Effective "today" (respects Maghrib day-reset), used by the streak card. */
    val effectiveToday: LocalDate = LocalDate.now(),
)

internal data class ActiveGoalSections(
    val today: List<GoalDisplayItem>,
    val upcoming: List<GoalDisplayItem>,
    val past: List<GoalDisplayItem>,
)

internal data class HistoryGoalSections(
    val past: List<GoalDisplayItem>,
    val completed: List<GoalDisplayItem>,
    val archived: List<GoalDisplayItem>,
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
    val (pastGoals, upcomingGoals) = notToday.partition { item ->
        item.goal.endDate?.isBefore(today) == true ||
            item.goal.durationDays
                ?.takeIf { it > 0 }
                ?.let { duration -> ChronoUnit.DAYS.between(item.goal.startDate, today) >= duration } == true
    }
    return ActiveGoalSections(
        today = unfinishedTodayGoals + finishedTodayGoals,
        upcoming = upcomingGoals,
        past = pastGoals,
    )
}

internal fun categorizeHistoryGoals(goals: List<GoalDisplayItem>): HistoryGoalSections =
    HistoryGoalSections(
        past = goals.filter { it.goal.isActive && it.goal.completedAt == null },
        completed = goals.filter { it.goal.completedAt != null },
        archived = goals.filter { !it.goal.isActive && it.goal.completedAt == null },
    )

internal fun completedGoalDisplayItem(
    goal: Goal,
    dhikrName: String,
    effectiveToday: LocalDate = LocalDate.now(),
): GoalDisplayItem = GoalDisplayItem(
    goal = goal,
    dhikrName = dhikrName,
    targetDisplay = GoalProgressCalculator.getFormattedTarget(goal),
    todayCount = goal.totalCompletedCount,
    dailyTarget = GoalProgressCalculator.getTargetCount(goal),
    overallProgress = 1f,
    effectiveToday = effectiveToday,
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
                val streakInfo = GoalProgressCalculator.calculateStreakWithCounts(
                    dailyCounts = dailyCounts,
                    today = effectiveDate,
                    dailyTarget = GoalProgressCalculator.getTargetCount(goal),
                    minimumStreakCount = goal.minimumStreakCount,
                    goal = goal,
                )
                return GoalDisplayItem(
                    goal = goal,
                    dhikrName = dhikr?.title.orEmpty().ifBlank { dhikr?.transliteration.orEmpty() },
                    targetDisplay = progressSummary.targetDisplay,
                    todayCount = progressSummary.progressCount,
                    dailyTarget = progressSummary.targetCount,
                    overallProgress = progressSummary.progress,
                    streakDays = streakInfo.currentStreak,
                    streakInfo = streakInfo,
                    effectiveToday = effectiveDate,
                )
            }

            val activeSections = categorizeActiveGoals(active.map(::displayItem), effectiveDate)
            val historySections = categorizeHistoryGoals(
                activeSections.past + completedOrInactive.map { goal ->
                    if (goal.completedAt != null) {
                        val dhikr = dhikrMap[goal.dhikrId]
                        completedGoalDisplayItem(
                            goal = goal,
                            dhikrName = dhikr?.title.orEmpty().ifBlank { dhikr?.transliteration.orEmpty() },
                            effectiveToday = effectiveDate,
                        )
                    } else {
                        displayItem(goal)
                    }
                },
            )

            GoalsUiState(
                todayGoals = activeSections.today,
                upcomingGoals = activeSections.upcoming,
                pastGoals = historySections.past,
                completedGoals = historySections.completed,
                archivedGoals = historySections.archived,
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
