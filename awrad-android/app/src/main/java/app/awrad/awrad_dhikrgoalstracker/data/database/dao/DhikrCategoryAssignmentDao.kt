package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrCategoryAssignmentEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import kotlinx.coroutines.flow.Flow

@Dao
interface DhikrCategoryAssignmentDao {
    @Query("SELECT * FROM dhikr_category_assignments ORDER BY dhikrId, sortOrder")
    fun observeAll(): Flow<List<DhikrCategoryAssignmentEntity>>

    @Query("SELECT * FROM dhikr_category_assignments WHERE dhikrId = :dhikrId ORDER BY sortOrder")
    suspend fun getForDhikr(dhikrId: AwradId): List<DhikrCategoryAssignmentEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(assignments: List<DhikrCategoryAssignmentEntity>)

    @Query("DELETE FROM dhikr_category_assignments WHERE dhikrId = :dhikrId")
    suspend fun deleteForDhikr(dhikrId: AwradId)

    @Transaction
    suspend fun replaceForDhikr(
        dhikrId: AwradId,
        assignments: List<DhikrCategoryAssignmentEntity>,
    ) {
        deleteForDhikr(dhikrId)
        insertAll(assignments)
    }
}
