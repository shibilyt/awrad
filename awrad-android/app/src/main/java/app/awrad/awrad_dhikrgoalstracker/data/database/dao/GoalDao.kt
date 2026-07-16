package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import kotlinx.coroutines.flow.Flow

@Dao
interface GoalDao {

    @Query("SELECT * FROM goals WHERE isActive = 1 ORDER BY createdAt DESC")
    fun getActiveGoals(): Flow<List<GoalEntity>>

    @Query("SELECT * FROM goals WHERE completedAt IS NOT NULL OR isActive = 0 ORDER BY createdAt DESC")
    fun getCompletedGoals(): Flow<List<GoalEntity>>

    @Query("SELECT * FROM goals ORDER BY createdAt DESC")
    fun getAllGoals(): Flow<List<GoalEntity>>

    @Query("SELECT * FROM goals WHERE id = :id")
    suspend fun getGoalById(id: AwradId): GoalEntity?

    @Query("SELECT * FROM goals WHERE id = :id")
    fun getGoalByIdFlow(id: AwradId): Flow<GoalEntity?>

    @Insert
    suspend fun insert(goal: GoalEntity)

    @Update
    suspend fun update(goal: GoalEntity)

    @Query("DELETE FROM goals WHERE id = :id")
    suspend fun deleteById(id: AwradId)

    @Query("""
        UPDATE goals SET totalCompletedCount = CASE
            WHEN totalCompletedCount + :increment < 0 THEN 0
            ELSE totalCompletedCount + :increment
        END, updatedAt = :updatedAt
        WHERE id = :goalId
    """)
    suspend fun incrementTotalCount(goalId: AwradId, increment: Long, updatedAt: Long)

    @Deprecated("Use incrementTotalCount(goalId, increment, updatedAt) so updatedAt stays accurate.")
    @Query("UPDATE goals SET totalCompletedCount = totalCompletedCount + :increment WHERE id = :goalId")
    suspend fun incrementTotalCount(goalId: AwradId, increment: Long)

    @Query("UPDATE goals SET completedAt = :completedAt, isActive = 0, updatedAt = :completedAt WHERE id = :goalId")
    suspend fun markCompleted(goalId: AwradId, completedAt: Long)

    @Query("UPDATE goals SET completedAt = NULL, isActive = 1, updatedAt = :updatedAt WHERE id = :goalId")
    suspend fun reopenGoal(goalId: AwradId, updatedAt: Long)

    @Query("""
        SELECT DISTINCT goals.* FROM goals
        INNER JOIN goal_reminders ON goal_reminders.goalId = goals.id
        WHERE goals.isActive = 1 AND goals.completedAt IS NULL AND goal_reminders.enabled = 1
    """)
    suspend fun getActiveGoalsWithNotifications(): List<GoalEntity>

    @Query("DELETE FROM goals")
    suspend fun deleteAllGoals()

    @Query("UPDATE goals SET totalCompletedCount = 0, completedAt = NULL, isActive = 1, updatedAt = :updatedAt")
    suspend fun resetAllGoalProgress(updatedAt: Long)

    @Query("UPDATE goals SET totalCompletedCount = 0, updatedAt = :updatedAt WHERE id = :goalId")
    suspend fun resetGoalCount(goalId: AwradId, updatedAt: Long)

    @Query("SELECT * FROM goals WHERE dhikrId = :dhikrId AND isActive = 1 ORDER BY createdAt DESC")
    fun getActiveGoalsByDhikrId(dhikrId: AwradId): Flow<List<GoalEntity>>
}
