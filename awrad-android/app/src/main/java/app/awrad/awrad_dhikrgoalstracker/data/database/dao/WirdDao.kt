package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.WirdEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface WirdDao {

    @Query("SELECT * FROM wirds ORDER BY sortOrder ASC, nameEn ASC")
    fun observeAll(): Flow<List<WirdEntity>>

    @Query("SELECT * FROM wirds ORDER BY sortOrder ASC, nameEn ASC")
    suspend fun getAll(): List<WirdEntity>

    @Query("SELECT * FROM wirds WHERE id = :id")
    suspend fun getById(id: String): WirdEntity?

    @Query("SELECT * FROM wirds WHERE id = :id")
    fun observeById(id: String): Flow<WirdEntity?>

    @Query("SELECT * FROM wirds WHERE slug = :slug")
    suspend fun getBySlug(slug: String): WirdEntity?

    @Query("SELECT COALESCE(MAX(sortOrder), -1) FROM wirds")
    suspend fun maxSortOrder(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: WirdEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<WirdEntity>)

    @Query("DELETE FROM wirds WHERE id = :id AND isCustom = 1")
    suspend fun deleteCustom(id: String)
}
