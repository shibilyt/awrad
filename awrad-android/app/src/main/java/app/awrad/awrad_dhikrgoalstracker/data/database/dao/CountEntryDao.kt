package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.CountEntryEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import kotlinx.coroutines.flow.Flow

data class GoalDateCount(val goalId: AwradId, val total: Long)

@Dao
abstract class CountEntryDao {

    @Query("SELECT * FROM count_entries WHERE count > 0 ORDER BY date, goalId, slotId")
    abstract suspend fun allForInitialSync(): List<CountEntryEntity>

    @Insert
    protected abstract suspend fun insert(entry: CountEntryEntity)

    @Query("""
        UPDATE count_entries SET count = CASE
            WHEN count + :increment < 0 THEN 0
            ELSE count + :increment
        END, lastUpdated = :lastUpdated
        WHERE goalId = :goalId AND date = :date AND slotId = :slotId
    """)
    protected abstract suspend fun updateWithSlot(goalId: AwradId, slotId: AwradId, date: String, increment: Long, lastUpdated: Long): Int

    @Query("SELECT count FROM count_entries WHERE goalId = :goalId AND date = :date AND slotId = :slotId")
    abstract suspend fun getCountValueForSlot(goalId: AwradId, slotId: AwradId, date: String): Long?

    @Query("UPDATE count_entries SET count = :count, lastUpdated = :lastUpdated WHERE goalId = :goalId AND slotId = :slotId AND date = :date")
    protected abstract suspend fun updateCanonicalCount(goalId: AwradId, slotId: AwradId, date: String, count: Long, lastUpdated: Long): Int

    @Transaction
    open suspend fun setCanonicalCount(goalId: AwradId, slotId: AwradId, date: String, count: Long, lastUpdated: Long) {
        val updated = updateCanonicalCount(goalId, slotId, date, count.coerceAtLeast(0), lastUpdated)
        if (updated == 0) {
            insert(
                CountEntryEntity(
                    goalId = goalId,
                    slotId = slotId,
                    count = count.coerceAtLeast(0),
                    date = date,
                    lastUpdated = lastUpdated,
                ),
            )
        }
    }

    @Transaction
    open suspend fun upsertCount(goalId: AwradId, slotId: AwradId, date: String, increment: Long, lastUpdated: Long) {
        if (increment == 0L) return
        val updated = updateWithSlot(goalId, slotId, date, increment, lastUpdated)
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

    @Query("SELECT SUM(count) FROM count_entries WHERE goalId = :goalId AND date = :date")
    abstract fun getCountForDate(goalId: AwradId, date: String): Flow<Long?>

    @Query("SELECT count FROM count_entries WHERE goalId = :goalId AND date = :date AND slotId = :slotId")
    abstract fun getCountForSlotAndDate(goalId: AwradId, slotId: AwradId, date: String): Flow<Long?>

    @Query("SELECT SUM(count) FROM count_entries WHERE goalId = :goalId AND date = :date")
    abstract fun getTotalCountForDate(goalId: AwradId, date: String): Flow<Long?>

    @Query("SELECT SUM(count) FROM count_entries WHERE goalId = :goalId")
    abstract fun getTotalCount(goalId: AwradId): Flow<Long?>

    @Query("SELECT SUM(count) FROM count_entries WHERE goalId = :goalId AND date BETWEEN :startDate AND :endDate")
    abstract suspend fun getTotalCountBetween(goalId: AwradId, startDate: String, endDate: String): Long?

    @Query("SELECT goalId, SUM(count) as total FROM count_entries WHERE date = :date GROUP BY goalId")
    abstract fun getProgressMapForDate(date: String): Flow<List<GoalDateCount>>

    @Query("SELECT * FROM count_entries WHERE goalId = :goalId AND count > 0 ORDER BY date DESC, lastUpdated DESC")
    abstract fun getHistoryForGoal(goalId: AwradId): Flow<List<CountEntryEntity>>

    @Query("SELECT date, SUM(count) as total FROM count_entries WHERE goalId = :goalId AND count > 0 GROUP BY date ORDER BY date DESC")
    abstract fun getDailyCountsForGoal(goalId: AwradId): Flow<List<DateCount>>

    /** Per-goal per-day totals for every goal, positive rows only (feeds Home/Goals progress + streaks). */
    @Query("SELECT goalId, date, SUM(count) as total FROM count_entries WHERE count > 0 GROUP BY goalId, date")
    abstract fun getDailyCountsByGoal(): Flow<List<GoalDailyCount>>

    /** Per-goal per-day per-slot totals for every goal, positive rows with a slot only (feeds Home slot rings). */
    @Query("SELECT goalId, date, slotId, SUM(count) as total FROM count_entries WHERE count > 0 AND slotId IS NOT NULL GROUP BY goalId, date, slotId")
    abstract fun getDailySlotCountsByGoal(): Flow<List<GoalSlotDailyCount>>

    /** Per-day per-slot totals for a single goal, positive rows with a slot only (feeds Goal Detail). */
    @Query("SELECT date, slotId, SUM(count) as total FROM count_entries WHERE goalId = :goalId AND count > 0 AND slotId IS NOT NULL GROUP BY date, slotId")
    abstract fun getDailySlotCountsForGoal(goalId: AwradId): Flow<List<SlotDateCount>>

    /** Bounded grouped read used by notification planning; avoids collecting full history flows. */
    @Query("""
        SELECT goalId, date, SUM(count) as total FROM count_entries
        WHERE goalId IN (:goalIds) AND date BETWEEN :startDate AND :endDate AND count > 0
        GROUP BY goalId, date
    """)
    abstract suspend fun getDailyCountsForGoalsInRange(
        goalIds: List<AwradId>,
        startDate: String,
        endDate: String,
    ): List<GoalDailyCount>

    /** Bounded grouped per-slot read used by notification planning. */
    @Query("""
        SELECT goalId, date, slotId, SUM(count) as total FROM count_entries
        WHERE goalId IN (:goalIds) AND date BETWEEN :startDate AND :endDate
            AND count > 0 AND slotId IS NOT NULL
        GROUP BY goalId, date, slotId
    """)
    abstract suspend fun getDailySlotCountsForGoalsInRange(
        goalIds: List<AwradId>,
        startDate: String,
        endDate: String,
    ): List<GoalSlotDailyCount>

    @Query("""
        SELECT goalId, SUM(count) as total FROM count_entries
        WHERE goalId IN (:goalIds)
        GROUP BY goalId
    """)
    abstract suspend fun getTotalCountsForGoals(goalIds: List<AwradId>): List<GoalTotalCount>

    /** Per-slot totals for a single goal on a single date, positive rows with a slot only (one-shot edit reads). */
    @Query("SELECT slotId, SUM(count) as total FROM count_entries WHERE goalId = :goalId AND date = :date AND count > 0 AND slotId IS NOT NULL GROUP BY slotId")
    abstract suspend fun getSlotCountsForGoalAndDate(goalId: AwradId, date: String): List<SlotCount>

    @Query("DELETE FROM count_entries")
    abstract suspend fun deleteAll()

    @Query("DELETE FROM count_entries WHERE goalId = :goalId")
    abstract suspend fun deleteForGoal(goalId: AwradId)
}

data class DateCount(val date: String, val total: Long)

/** One row of the per-goal per-day aggregate (all goals). */
data class GoalDailyCount(val goalId: AwradId, val date: String, val total: Long)

/** One row of the per-goal per-day per-slot aggregate (all goals; slotId is never null). */
data class GoalSlotDailyCount(val goalId: AwradId, val date: String, val slotId: AwradId, val total: Long)

/** One row of a lifetime goal aggregate. */
data class GoalTotalCount(val goalId: AwradId, val total: Long)

/** One row of a single goal's per-day per-slot aggregate (slotId is never null). */
data class SlotDateCount(val date: String, val slotId: AwradId, val total: Long)

/** One row of a single goal's per-slot aggregate for one date (slotId is never null). */
data class SlotCount(val slotId: AwradId, val total: Long)
