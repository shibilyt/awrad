package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceDateEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceMonthDayEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceWeekdayEntity

@Dao
interface GoalRecurrenceDao {

    @Query("SELECT * FROM goal_recurrences WHERE goalId = :goalId")
    suspend fun getForGoal(goalId: Long): GoalRecurrenceEntity?

    @Query("SELECT * FROM goal_recurrences WHERE goalId IN (:goalIds)")
    suspend fun getForGoals(goalIds: List<Long>): List<GoalRecurrenceEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(recurrence: GoalRecurrenceEntity)

    @Query("DELETE FROM goal_recurrences WHERE goalId = :goalId")
    suspend fun deleteForGoal(goalId: Long)

    @Query("SELECT * FROM goal_recurrence_weekdays WHERE goalId = :goalId ORDER BY dayOfWeek")
    suspend fun getWeekdaysForGoal(goalId: Long): List<GoalRecurrenceWeekdayEntity>

    @Query("SELECT * FROM goal_recurrence_weekdays WHERE goalId IN (:goalIds) ORDER BY goalId, dayOfWeek")
    suspend fun getWeekdaysForGoals(goalIds: List<Long>): List<GoalRecurrenceWeekdayEntity>

    @Insert
    suspend fun insertWeekdays(days: List<GoalRecurrenceWeekdayEntity>)

    @Query("DELETE FROM goal_recurrence_weekdays WHERE goalId = :goalId")
    suspend fun deleteWeekdaysForGoal(goalId: Long)

    @Query("SELECT * FROM goal_recurrence_month_days WHERE goalId = :goalId ORDER BY dayOfMonth")
    suspend fun getMonthDaysForGoal(goalId: Long): List<GoalRecurrenceMonthDayEntity>

    @Query("SELECT * FROM goal_recurrence_month_days WHERE goalId IN (:goalIds) ORDER BY goalId, dayOfMonth")
    suspend fun getMonthDaysForGoals(goalIds: List<Long>): List<GoalRecurrenceMonthDayEntity>

    @Insert
    suspend fun insertMonthDays(days: List<GoalRecurrenceMonthDayEntity>)

    @Query("DELETE FROM goal_recurrence_month_days WHERE goalId = :goalId")
    suspend fun deleteMonthDaysForGoal(goalId: Long)

    @Query("SELECT * FROM goal_recurrence_dates WHERE goalId = :goalId ORDER BY date, month, dayOfMonth")
    suspend fun getDatesForGoal(goalId: Long): List<GoalRecurrenceDateEntity>

    @Query("SELECT * FROM goal_recurrence_dates WHERE goalId IN (:goalIds) ORDER BY goalId, date, month, dayOfMonth")
    suspend fun getDatesForGoals(goalIds: List<Long>): List<GoalRecurrenceDateEntity>

    @Insert
    suspend fun insertDates(dates: List<GoalRecurrenceDateEntity>)

    @Query("DELETE FROM goal_recurrence_dates WHERE goalId = :goalId")
    suspend fun deleteDatesForGoal(goalId: Long)
}

