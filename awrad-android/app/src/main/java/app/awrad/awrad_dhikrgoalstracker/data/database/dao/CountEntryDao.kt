package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.CountEntryEntity
import kotlinx.coroutines.flow.Flow

data class GoalDateCount(val goalId: Long, val total: Long)

@Dao
abstract class CountEntryDao {

    @Insert
    protected abstract suspend fun insert(entry: CountEntryEntity): Long

    @Query("""
        UPDATE count_entries SET count = CASE
            WHEN count + :increment < 0 THEN 0
            ELSE count + :increment
        END, lastUpdated = :lastUpdated
        WHERE goalId = :goalId AND date = :date AND slotId = :slotId
    """)
    protected abstract suspend fun updateWithSlot(goalId: Long, slotId: Long, date: String, increment: Long, lastUpdated: Long): Int

    @Query("""
        UPDATE count_entries SET count = CASE
            WHEN count + :increment < 0 THEN 0
            ELSE count + :increment
        END, lastUpdated = :lastUpdated
        WHERE goalId = :goalId AND date = :date AND slotId IS NULL
    """)
    protected abstract suspend fun updateNoSlot(goalId: Long, date: String, increment: Long, lastUpdated: Long): Int

    @Query("SELECT count FROM count_entries WHERE goalId = :goalId AND date = :date AND slotId = :slotId")
    abstract suspend fun getCountValueForSlot(goalId: Long, slotId: Long, date: String): Long?

    @Query("SELECT count FROM count_entries WHERE goalId = :goalId AND date = :date AND slotId IS NULL")
    abstract suspend fun getCountValueNoSlot(goalId: Long, date: String): Long?

    @Transaction
    open suspend fun upsertCount(goalId: Long, slotId: Long?, date: String, increment: Long, lastUpdated: Long) {
        if (increment == 0L) return
        val updated = if (slotId != null) {
            updateWithSlot(goalId, slotId, date, increment, lastUpdated)
        } else {
            updateNoSlot(goalId, date, increment, lastUpdated)
        }
        if (updated == 0 && increment > 0) {
            insert(CountEntryEntity(
                goalId = goalId,
                slotId = slotId,
                count = increment,
                date = date,
                lastUpdated = lastUpdated,
            ))
        }
    }

    @Query("SELECT count FROM count_entries WHERE goalId = :goalId AND date = :date AND slotId IS NULL")
    abstract fun getCountForDate(goalId: Long, date: String): Flow<Long?>

    @Query("SELECT count FROM count_entries WHERE goalId = :goalId AND date = :date AND slotId = :slotId")
    abstract fun getCountForSlotAndDate(goalId: Long, slotId: Long, date: String): Flow<Long?>

    @Query("SELECT SUM(count) FROM count_entries WHERE goalId = :goalId AND date = :date")
    abstract fun getTotalCountForDate(goalId: Long, date: String): Flow<Long?>

    @Query("SELECT SUM(count) FROM count_entries WHERE goalId = :goalId")
    abstract fun getTotalCount(goalId: Long): Flow<Long?>

    @Query("SELECT SUM(count) FROM count_entries WHERE goalId = :goalId AND date BETWEEN :startDate AND :endDate")
    abstract suspend fun getTotalCountBetween(goalId: Long, startDate: String, endDate: String): Long?

    @Query("SELECT goalId, SUM(count) as total FROM count_entries WHERE date = :date GROUP BY goalId")
    abstract fun getProgressMapForDate(date: String): Flow<List<GoalDateCount>>

    @Query("SELECT * FROM count_entries WHERE goalId = :goalId AND count > 0 ORDER BY date DESC, lastUpdated DESC")
    abstract fun getHistoryForGoal(goalId: Long): Flow<List<CountEntryEntity>>

    @Query("SELECT date, SUM(count) as total FROM count_entries WHERE goalId = :goalId AND count > 0 GROUP BY date ORDER BY date DESC")
    abstract fun getDailyCountsForGoal(goalId: Long): Flow<List<DateCount>>

    /** Per-goal per-day totals for every goal, positive rows only (feeds Home/Goals progress + streaks). */
    @Query("SELECT goalId, date, SUM(count) as total FROM count_entries WHERE count > 0 GROUP BY goalId, date")
    abstract fun getDailyCountsByGoal(): Flow<List<GoalDailyCount>>

    /** Per-goal per-day per-slot totals for every goal, positive rows with a slot only (feeds Home slot rings). */
    @Query("SELECT goalId, date, slotId, SUM(count) as total FROM count_entries WHERE count > 0 AND slotId IS NOT NULL GROUP BY goalId, date, slotId")
    abstract fun getDailySlotCountsByGoal(): Flow<List<GoalSlotDailyCount>>

    /** Per-day per-slot totals for a single goal, positive rows with a slot only (feeds Goal Detail). */
    @Query("SELECT date, slotId, SUM(count) as total FROM count_entries WHERE goalId = :goalId AND count > 0 AND slotId IS NOT NULL GROUP BY date, slotId")
    abstract fun getDailySlotCountsForGoal(goalId: Long): Flow<List<SlotDateCount>>

    /** Per-slot totals for a single goal on a single date, positive rows with a slot only (one-shot edit reads). */
    @Query("SELECT slotId, SUM(count) as total FROM count_entries WHERE goalId = :goalId AND date = :date AND count > 0 AND slotId IS NOT NULL GROUP BY slotId")
    abstract suspend fun getSlotCountsForGoalAndDate(goalId: Long, date: String): List<SlotCount>

    @Query("DELETE FROM count_entries")
    abstract suspend fun deleteAll()
}

data class DateCount(val date: String, val total: Long)

/** One row of the per-goal per-day aggregate (all goals). */
data class GoalDailyCount(val goalId: Long, val date: String, val total: Long)

/** One row of the per-goal per-day per-slot aggregate (all goals; slotId is never null). */
data class GoalSlotDailyCount(val goalId: Long, val date: String, val slotId: Long, val total: Long)

/** One row of a single goal's per-day per-slot aggregate (slotId is never null). */
data class SlotDateCount(val date: String, val slotId: Long, val total: Long)

/** One row of a single goal's per-slot aggregate for one date (slotId is never null). */
data class SlotCount(val slotId: Long, val total: Long)
