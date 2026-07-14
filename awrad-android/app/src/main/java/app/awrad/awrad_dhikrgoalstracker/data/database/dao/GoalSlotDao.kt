package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalSlotEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import kotlinx.coroutines.flow.Flow

@Dao
interface GoalSlotDao {

    @Query("SELECT * FROM goal_slots WHERE goalId = :goalId ORDER BY sortOrder")
    suspend fun getSlotsForGoal(goalId: AwradId): List<GoalSlotEntity>

    @Query("SELECT * FROM goal_slots WHERE goalId = :goalId ORDER BY sortOrder")
    fun getSlotsForGoalFlow(goalId: AwradId): Flow<List<GoalSlotEntity>>

    @Query("SELECT * FROM goal_slots WHERE goalId IN (:goalIds) ORDER BY goalId, sortOrder")
    suspend fun getSlotsForGoals(goalIds: List<AwradId>): List<GoalSlotEntity>

    @Insert
    suspend fun insertAll(slots: List<GoalSlotEntity>)

    @Insert
    suspend fun insert(slot: GoalSlotEntity)

    @Update
    suspend fun update(slot: GoalSlotEntity)

    @Query("DELETE FROM goal_slots WHERE goalId = :goalId")
    suspend fun deleteForGoal(goalId: AwradId)

    @Query("DELETE FROM goal_slots WHERE goalId = :goalId AND id NOT IN (:retainedIds)")
    suspend fun deleteForGoalExcept(goalId: AwradId, retainedIds: List<AwradId>)
}
