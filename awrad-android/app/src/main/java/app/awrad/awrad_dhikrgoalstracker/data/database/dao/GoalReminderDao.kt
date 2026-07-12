package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalReminderEntity

@Dao
interface GoalReminderDao {

    @Query("SELECT * FROM goal_reminders WHERE goalId = :goalId ORDER BY sortOrder, id")
    suspend fun getRemindersForGoal(goalId: Long): List<GoalReminderEntity>

    @Query("SELECT * FROM goal_reminders WHERE goalId IN (:goalIds) ORDER BY goalId, sortOrder, id")
    suspend fun getRemindersForGoals(goalIds: List<Long>): List<GoalReminderEntity>

    @Insert
    suspend fun insertAll(reminders: List<GoalReminderEntity>): List<Long>

    @Insert
    suspend fun insert(reminder: GoalReminderEntity): Long

    @Update
    suspend fun update(reminder: GoalReminderEntity)

    @Query("DELETE FROM goal_reminders WHERE goalId = :goalId")
    suspend fun deleteForGoal(goalId: Long)

    @Query("DELETE FROM goal_reminders WHERE goalId = :goalId AND id NOT IN (:retainedIds)")
    suspend fun deleteForGoalExcept(goalId: Long, retainedIds: List<Long>)
}
