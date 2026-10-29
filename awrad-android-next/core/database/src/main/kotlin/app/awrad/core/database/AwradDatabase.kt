package app.awrad.core.database

import androidx.room.Database
import androidx.room.RoomDatabase

/**
 * One local profile's data (contracts/sync/v1, "Local profiles"): each profile is its own file, [fileName], so two
 * accounts' data never mix. Room stays at version 1 until the first release (ADR 0003): edit it in place and
 * re-export the schema under `schemas/`.
 */
@Database(
    entities = [
        GoalEntity::class,
        CustomDhikrEntity::class,
        UserTagEntity::class,
        DhikrPersonalEntity::class,
        OutboxEntity::class,
        ConflictEntity::class,
        NoticeEntity::class,
        SyncMetaEntity::class,
        AudioUploadEntity::class,
        PracticePolicyEntity::class,
    ],
    version = 1,
    exportSchema = true,
)
public abstract class AwradDatabase : RoomDatabase() {
    public abstract fun goalDao(): GoalDao

    public abstract fun syncDao(): SyncDao

    public companion object {
        /** The database file of the profile with [profileId]. */
        public fun fileName(profileId: String): String = "profile-$profileId.db"
    }
}
