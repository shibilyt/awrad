package app.awrad.awrad_dhikrgoalstracker.data.repository

import app.awrad.awrad_dhikrgoalstracker.data.model.CountEntry
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ValidatedGoal
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ValidatedGoalUpdate
import kotlinx.coroutines.flow.Flow
import java.time.LocalDate

interface GoalRepository {
    fun getActiveGoals(): Flow<List<Goal>>
    fun getCompletedGoals(): Flow<List<Goal>>
    fun getAllGoals(): Flow<List<Goal>>
    fun getGoalByIdFlow(id: Long): Flow<Goal?>
    suspend fun getGoalById(id: Long): Goal?
    suspend fun createGoal(validatedGoal: ValidatedGoal): Long
    suspend fun updateGoal(goal: Goal)
    suspend fun updateGoal(validatedGoalUpdate: ValidatedGoalUpdate): Goal
    suspend fun updateGoalSchedule(validatedGoalUpdate: ValidatedGoalUpdate): Goal
    suspend fun updateGoalReminders(validatedGoalUpdate: ValidatedGoalUpdate): Goal
    suspend fun deleteGoal(id: Long)
    suspend fun addCount(goalId: Long, slotId: Long?, count: Long = 1): Long
    fun getTotalCountForDate(goalId: Long, date: String): Flow<Long?>
    fun getTotalCount(goalId: Long): Flow<Long?>
    suspend fun getCountForSlotAndDate(goalId: Long, slotId: Long, date: String): Long
    fun getProgressMapForDate(date: String): Flow<Map<Long, Long>>
    fun getHistoryForGoal(goalId: Long): Flow<List<CountEntry>>
    /** Per-goal per-day totals (goalId -> date -> summed count) over positive rows, for all goals. */
    fun getDailyCountsByGoal(): Flow<Map<Long, Map<LocalDate, Long>>>
    /** Per-goal per-day per-slot totals (goalId -> date -> slotId -> summed count) over positive rows. */
    fun getDailySlotCountsByGoal(): Flow<Map<Long, Map<LocalDate, Map<Long, Long>>>>
    /** A single goal's per-day per-slot totals (date -> slotId -> summed count) over positive rows. */
    fun getDailySlotCountsForGoal(goalId: Long): Flow<Map<LocalDate, Map<Long, Long>>>
    /** A single goal's per-slot totals for one date (slotId -> summed count) over positive rows. */
    suspend fun getSlotCountsForGoalAndDate(goalId: Long, date: String): Map<Long, Long>
    suspend fun getTotalCountBetween(goalId: Long, startDate: String, endDate: String): Long
    suspend fun getActiveGoalsWithNotifications(): List<Goal>
    suspend fun deleteAllProgress()
    suspend fun deleteAllGoalsAndProgress()
    fun getActiveGoalsByDhikrId(dhikrId: Long): Flow<List<Goal>>
    fun getDailyCountsForGoal(goalId: Long): Flow<Map<LocalDate, Long>>
}
