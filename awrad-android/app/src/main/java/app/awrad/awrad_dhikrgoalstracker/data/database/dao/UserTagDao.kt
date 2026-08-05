package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrAudioAssetEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrTagAssignmentEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.UserTagEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import kotlinx.coroutines.flow.Flow

@Dao
interface UserTagDao {
    @Query("SELECT * FROM user_tags ORDER BY name COLLATE NOCASE")
    fun observeAll(): Flow<List<UserTagEntity>>

    @Query("SELECT * FROM user_tags ORDER BY name COLLATE NOCASE")
    suspend fun getAll(): List<UserTagEntity>

    @Query("SELECT * FROM user_tags WHERE id = :id")
    suspend fun getById(id: AwradId): UserTagEntity?

    @Query("SELECT * FROM user_tags WHERE normalizedName = :normalizedName LIMIT 1")
    suspend fun getByNormalizedName(normalizedName: String): UserTagEntity?

    @Query("SELECT COUNT(*) FROM user_tags")
    suspend fun count(): Int

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(tag: UserTagEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(tag: UserTagEntity)

    @Update
    suspend fun update(tag: UserTagEntity)

    @Query("DELETE FROM user_tags WHERE id = :id")
    suspend fun deleteById(id: AwradId)
}

@Dao
interface DhikrTagAssignmentDao {
    @Query("SELECT * FROM dhikr_tag_assignments")
    fun observeAll(): Flow<List<DhikrTagAssignmentEntity>>

    @Query("SELECT * FROM dhikr_tag_assignments WHERE dhikrId = :dhikrId")
    fun observeForDhikr(dhikrId: AwradId): Flow<List<DhikrTagAssignmentEntity>>

    @Query("SELECT * FROM dhikr_tag_assignments WHERE dhikrId = :dhikrId")
    suspend fun getForDhikr(dhikrId: AwradId): List<DhikrTagAssignmentEntity>

    @Query("SELECT * FROM dhikr_tag_assignments WHERE tagId = :tagId")
    suspend fun getForTag(tagId: AwradId): List<DhikrTagAssignmentEntity>

    @Query("SELECT * FROM dhikr_tag_assignments WHERE id = :id")
    suspend fun getById(id: AwradId): DhikrTagAssignmentEntity?

    @Query("SELECT COUNT(*) FROM dhikr_tag_assignments WHERE dhikrId = :dhikrId")
    suspend fun countForDhikr(dhikrId: AwradId): Int

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(assignment: DhikrTagAssignmentEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(assignment: DhikrTagAssignmentEntity)

    @Query("DELETE FROM dhikr_tag_assignments WHERE id = :id")
    suspend fun deleteById(id: AwradId)

    @Query("DELETE FROM dhikr_tag_assignments WHERE tagId = :tagId")
    suspend fun deleteForTag(tagId: AwradId)

    @Query("DELETE FROM dhikr_tag_assignments WHERE dhikrId = :dhikrId")
    suspend fun deleteForDhikr(dhikrId: AwradId)
}

@Dao
interface DhikrAudioAssetDao {
    @Query("SELECT * FROM dhikr_audio_assets")
    fun observeAll(): Flow<List<DhikrAudioAssetEntity>>

    @Query("SELECT * FROM dhikr_audio_assets WHERE dhikrId = :dhikrId LIMIT 1")
    suspend fun getForDhikr(dhikrId: AwradId): DhikrAudioAssetEntity?

    @Query("SELECT * FROM dhikr_audio_assets WHERE dhikrId = :dhikrId LIMIT 1")
    fun observeForDhikr(dhikrId: AwradId): Flow<DhikrAudioAssetEntity?>

    @Query("SELECT relativeFileName FROM dhikr_audio_assets")
    suspend fun getAllRelativeFileNames(): List<String>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(asset: DhikrAudioAssetEntity)

    @Query("DELETE FROM dhikr_audio_assets WHERE dhikrId = :dhikrId")
    suspend fun deleteForDhikr(dhikrId: AwradId)

    @Query("DELETE FROM dhikr_audio_assets WHERE id = :id")
    suspend fun deleteById(id: AwradId)
}
