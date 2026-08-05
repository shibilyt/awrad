package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.model.CountEntry
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ValidatedGoal
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ValidatedGoalUpdate
import kotlinx.coroutines.flow.Flow
import java.time.LocalDate

interface GoalRepository {
    fun getActiveGoals(): Flow<List<Goal>>
    fun getCompletedGoals(): Flow<List<Goal>>
    fun getAllGoals(): Flow<List<Goal>>
    fun getGoalByIdFlow(id: AwradId): Flow<Goal?>
    suspend fun getGoalById(id: AwradId): Goal?
    suspend fun createGoal(validatedGoal: ValidatedGoal): AwradId
    suspend fun updateGoal(goal: Goal)
    suspend fun updateGoal(validatedGoalUpdate: ValidatedGoalUpdate): Goal
    suspend fun updateGoalSchedule(validatedGoalUpdate: ValidatedGoalUpdate): Goal
    suspend fun updateGoalReminders(validatedGoalUpdate: ValidatedGoalUpdate): Goal
    suspend fun deleteGoal(id: AwradId)
    suspend fun addCount(goalId: AwradId, slotId: AwradId?, count: Long = 1): Long
    fun getTotalCountForDate(goalId: AwradId, date: String): Flow<Long?>
    fun getTotalCount(goalId: AwradId): Flow<Long?>
    suspend fun getCountForSlotAndDate(goalId: AwradId, slotId: AwradId, date: String): Long
    fun getProgressMapForDate(date: String): Flow<Map<AwradId, Long>>
    fun getHistoryForGoal(goalId: AwradId): Flow<List<CountEntry>>
    /** Per-goal per-day totals (goalId -> date -> summed count) over positive rows, for all goals. */
    fun getDailyCountsByGoal(): Flow<Map<AwradId, Map<LocalDate, Long>>>
    /** Per-goal per-day per-slot totals (goalId -> date -> slotId -> summed count) over positive rows. */
    fun getDailySlotCountsByGoal(): Flow<Map<AwradId, Map<LocalDate, Map<AwradId, Long>>>>
    /** A single goal's per-day per-slot totals (date -> slotId -> summed count) over positive rows. */
    fun getDailySlotCountsForGoal(goalId: AwradId): Flow<Map<LocalDate, Map<AwradId, Long>>>
    /** Bounded per-goal daily totals for planning and other one-shot policy reads. */
    suspend fun getDailyCountsForGoalsInRange(
        goalIds: List<AwradId>,
        startDate: LocalDate,
        endDate: LocalDate,
    ): Map<AwradId, Map<LocalDate, Long>> =
        error("Bounded notification count reads are not implemented by this repository")
    /** Bounded per-goal per-slot totals for planning and other one-shot policy reads. */
    suspend fun getDailySlotCountsForGoalsInRange(
        goalIds: List<AwradId>,
        startDate: LocalDate,
        endDate: LocalDate,
    ): Map<AwradId, Map<LocalDate, Map<AwradId, Long>>> =
        error("Bounded notification slot count reads are not implemented by this repository")
    /** Current lifetime totals for a bounded goal set. */
    suspend fun getTotalCountsForGoals(goalIds: List<AwradId>): Map<AwradId, Long> =
        error("Bounded notification lifetime reads are not implemented by this repository")
    /** A single goal's per-slot totals for one date (slotId -> summed count) over positive rows. */
    suspend fun getSlotCountsForGoalAndDate(goalId: AwradId, date: String): Map<AwradId, Long>
    suspend fun getTotalCountBetween(goalId: AwradId, startDate: String, endDate: String): Long
    suspend fun getActiveGoalsWithNotifications(): List<Goal>
    suspend fun deleteAllProgress()
    suspend fun deleteAllGoalsAndProgress()
    fun getActiveGoalsByDhikrId(dhikrId: AwradId): Flow<List<Goal>>
    fun getDailyCountsForGoal(goalId: AwradId): Flow<Map<LocalDate, Long>>
}
