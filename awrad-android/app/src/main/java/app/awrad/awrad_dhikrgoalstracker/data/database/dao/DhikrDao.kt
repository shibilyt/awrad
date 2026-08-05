package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import kotlinx.coroutines.flow.Flow

@Dao
interface DhikrDao {

    @Query("SELECT * FROM dhikrs ORDER BY category, sortOrder, transliteration")
    fun getAllDhikrs(): Flow<List<DhikrEntity>>

    @Query("SELECT * FROM dhikrs WHERE id = :id")
    suspend fun getDhikrById(id: AwradId): DhikrEntity?

    @Query("SELECT * FROM dhikrs WHERE catalogKey = :catalogKey")
    suspend fun getDhikrByCatalogKey(catalogKey: String): DhikrEntity?

    @Query("SELECT * FROM dhikrs WHERE category = :category ORDER BY sortOrder, transliteration")
    fun getDhikrsByCategory(category: String): Flow<List<DhikrEntity>>

    @Query("SELECT * FROM dhikrs WHERE title LIKE '%' || :query || '%' OR transliteration LIKE '%' || :query || '%' OR translation LIKE '%' || :query || '%' OR arabic LIKE '%' || :query || '%'")
    fun searchDhikrs(query: String): Flow<List<DhikrEntity>>

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertAll(dhikrs: List<DhikrEntity>)

    @Insert
    suspend fun insert(dhikr: DhikrEntity)

    @Update
    suspend fun update(dhikr: DhikrEntity)

    @Query(
        "UPDATE dhikrs SET title = :title, arabic = :arabic, transliteration = :transliteration, " +
            "translation = :translation, category = :category, audioCountPerPlay = :audioCountPerPlay " +
            "WHERE id = :id AND isCustom = 1",
    )
    suspend fun updateCustomContent(
        id: AwradId,
        title: String,
        arabic: String,
        transliteration: String,
        translation: String,
        category: String,
        audioCountPerPlay: Int,
    ): Int

    @Query("DELETE FROM dhikrs WHERE id = :id AND isCustom = 1")
    suspend fun deleteCustomById(id: AwradId): Int

    @Query("SELECT * FROM dhikrs WHERE isCustom = 1 ORDER BY title COLLATE NOCASE")
    fun getCustomDhikrs(): Flow<List<DhikrEntity>>

    @Query("SELECT COUNT(*) FROM dhikrs WHERE isCustom = 1")
    suspend fun getCustomCount(): Int

    @Query("SELECT COUNT(*) FROM dhikrs")
    suspend fun getCount(): Int

    @Query("SELECT * FROM dhikrs WHERE audioUrl IS NOT NULL")
    suspend fun getDhikrsWithAudioUrl(): List<DhikrEntity>

    @Query("UPDATE dhikrs SET audioUrl = :audioUrl WHERE catalogKey = :catalogKey AND audioUrl IS NULL")
    suspend fun updateAudioUrl(catalogKey: String, audioUrl: String)

    @Query("UPDATE dhikrs SET isDownloaded = :isDownloaded, audioFileName = :audioFileName WHERE id = :dhikrId")
    suspend fun updateAudioDownloadStatus(dhikrId: AwradId, audioFileName: String, isDownloaded: Boolean)

    @Query("SELECT transliteration FROM dhikrs")
    suspend fun getAllTransliterations(): List<String>

    @Query("UPDATE dhikrs SET audioCountPerPlay = :count WHERE catalogKey = :catalogKey")
    suspend fun updateAudioCountPerPlay(catalogKey: String, count: Int)

    @Query(
        "UPDATE dhikrs SET title = :title, arabic = :arabic, transliteration = :transliteration, " +
            "translation = :translation, category = :category, sortOrder = :sortOrder " +
            "WHERE catalogKey = :catalogKey",
    )
    suspend fun updateBuiltInContent(
        catalogKey: String,
        title: String,
        arabic: String,
        transliteration: String,
        translation: String,
        category: String,
        sortOrder: Int,
    )

    @Query("UPDATE dhikrs SET title = :title WHERE catalogKey = :catalogKey")
    suspend fun updateTitle(catalogKey: String, title: String)

    @Query(
        "UPDATE dhikrs SET arabic = :arabic, quranSurah = :surah, " +
            "quranAyahStart = :ayahStart, quranAyahEnd = :ayahEnd " +
            "WHERE catalogKey = :catalogKey"
    )
    suspend fun updateQuranContent(
        catalogKey: String,
        arabic: String,
        surah: Int,
        ayahStart: Int,
        ayahEnd: Int?,
    )
}
