package app.awrad.core.database

import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey

@Entity(tableName = "goals")
public data class GoalEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "dhikr_catalog_key") val dhikrCatalogKey: String,
    @ColumnInfo(name = "daily_target") val dailyTarget: Int,
    @ColumnInfo(name = "start_epoch_day") val startEpochDay: Long,
)

@Dao
public interface GoalDao {
    @Insert(onConflict = OnConflictStrategy.ABORT)
    public suspend fun insert(goal: GoalEntity)
}
