package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalSlotEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface GoalSlotDao {

    @Query("SELECT * FROM goal_slots WHERE goalId = :goalId ORDER BY sortOrder")
    suspend fun getSlotsForGoal(goalId: Long): List<GoalSlotEntity>

    @Query("SELECT * FROM goal_slots WHERE goalId = :goalId ORDER BY sortOrder")
    fun getSlotsForGoalFlow(goalId: Long): Flow<List<GoalSlotEntity>>

    @Query("SELECT * FROM goal_slots WHERE goalId IN (:goalIds) ORDER BY goalId, sortOrder")
    suspend fun getSlotsForGoals(goalIds: List<Long>): List<GoalSlotEntity>

    @Insert
    suspend fun insertAll(slots: List<GoalSlotEntity>): List<Long>

    @Insert
    suspend fun insert(slot: GoalSlotEntity): Long

    @Update
    suspend fun update(slot: GoalSlotEntity)

    @Query("DELETE FROM goal_slots WHERE goalId = :goalId")
    suspend fun deleteForGoal(goalId: Long)

    @Query("DELETE FROM goal_slots WHERE goalId = :goalId AND id NOT IN (:retainedIds)")
    suspend fun deleteForGoalExcept(goalId: Long, retainedIds: List<Long>)
}
