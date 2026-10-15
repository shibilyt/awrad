package app.awrad.core.database

import androidx.room.Database
import androidx.room.RoomDatabase

/**
 * The Room seam. Schema changes bump [version], add a forward migration, and
 * commit the exported schema under `schemas/`.
 */
@Database(
    entities = [GoalEntity::class],
    version = 1,
    exportSchema = true,
)
public abstract class AwradDatabase : RoomDatabase() {
    public abstract fun goalDao(): GoalDao

    public companion object {
        public const val NAME: String = "awrad-next.db"
    }
}
