package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.WirdSessionEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface WirdSessionDao {

    @Query(
        "SELECT * FROM wird_sessions WHERE wirdID = :wirdID AND partID = :partID " +
            "AND occasionKey = :occasionKey AND dateKey = :dateKey LIMIT 1",
    )
    suspend fun getByTuple(
        wirdID: String,
        partID: String,
        occasionKey: String,
        dateKey: String,
    ): WirdSessionEntity?

    @Query(
        "SELECT * FROM wird_sessions WHERE wirdID = :wirdID AND partID = :partID " +
            "AND occasionKey = :occasionKey AND dateKey = :dateKey LIMIT 1",
    )
    fun observeByTuple(
        wirdID: String,
        partID: String,
        occasionKey: String,
        dateKey: String,
    ): Flow<WirdSessionEntity?>

    @Query("SELECT * FROM wird_sessions WHERE wirdID = :wirdID AND dateKey = :dateKey")
    fun observeForWirdOnDate(wirdID: String, dateKey: String): Flow<List<WirdSessionEntity>>

    @Query("SELECT * FROM wird_sessions WHERE wirdID = :wirdID")
    suspend fun getAllForWird(wirdID: String): List<WirdSessionEntity>

    @Query("SELECT * FROM wird_sessions WHERE wirdID = :wirdID")
    fun observeAllForWird(wirdID: String): Flow<List<WirdSessionEntity>>

    @Query("SELECT * FROM wird_sessions WHERE dateKey = :dateKey")
    fun observeAllForDate(dateKey: String): Flow<List<WirdSessionEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: WirdSessionEntity)

    @Query(
        "DELETE FROM wird_sessions WHERE wirdID = :wirdID AND partID = :partID " +
            "AND occasionKey = :occasionKey AND dateKey = :dateKey",
    )
    suspend fun deleteByTuple(wirdID: String, partID: String, occasionKey: String, dateKey: String)

    @Query("DELETE FROM wird_sessions WHERE wirdID = :wirdID")
    suspend fun deleteAllForWird(wirdID: String)
}
