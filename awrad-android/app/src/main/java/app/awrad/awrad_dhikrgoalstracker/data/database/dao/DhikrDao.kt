package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface DhikrDao {

    @Query("SELECT * FROM dhikrs ORDER BY category, transliteration")
    fun getAllDhikrs(): Flow<List<DhikrEntity>>

    @Query("SELECT * FROM dhikrs WHERE id = :id")
    suspend fun getDhikrById(id: Long): DhikrEntity?

    @Query("SELECT * FROM dhikrs WHERE category = :category ORDER BY transliteration")
    fun getDhikrsByCategory(category: String): Flow<List<DhikrEntity>>

    @Query("SELECT * FROM dhikrs WHERE title LIKE '%' || :query || '%' OR transliteration LIKE '%' || :query || '%' OR translation LIKE '%' || :query || '%' OR arabic LIKE '%' || :query || '%'")
    fun searchDhikrs(query: String): Flow<List<DhikrEntity>>

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertAll(dhikrs: List<DhikrEntity>)

    @Insert
    suspend fun insert(dhikr: DhikrEntity): Long

    @Update
    suspend fun update(dhikr: DhikrEntity)

    @Query("SELECT COUNT(*) FROM dhikrs")
    suspend fun getCount(): Int

    @Query("SELECT * FROM dhikrs WHERE audioUrl IS NOT NULL")
    suspend fun getDhikrsWithAudioUrl(): List<DhikrEntity>

    @Query("UPDATE dhikrs SET audioUrl = :audioUrl WHERE transliteration = :transliteration AND audioUrl IS NULL")
    suspend fun updateAudioUrl(transliteration: String, audioUrl: String)

    @Query("UPDATE dhikrs SET isDownloaded = :isDownloaded, audioFileName = :audioFileName WHERE id = :dhikrId")
    suspend fun updateAudioDownloadStatus(dhikrId: Long, audioFileName: String, isDownloaded: Boolean)

    @Query("SELECT transliteration FROM dhikrs")
    suspend fun getAllTransliterations(): List<String>

    @Query("UPDATE dhikrs SET audioCountPerPlay = :count WHERE transliteration = :transliteration")
    suspend fun updateAudioCountPerPlay(transliteration: String, count: Int)

    @Query("UPDATE dhikrs SET title = :title WHERE transliteration = :transliteration")
    suspend fun updateTitle(transliteration: String, title: String)

    @Query(
        "UPDATE dhikrs SET arabic = :arabic, quranSurah = :surah, " +
            "quranAyahStart = :ayahStart, quranAyahEnd = :ayahEnd " +
            "WHERE transliteration = :transliteration"
    )
    suspend fun updateQuranContent(
        transliteration: String,
        arabic: String,
        surah: Int,
        ayahStart: Int,
        ayahEnd: Int?,
    )
}
