package app.awrad.core.database

import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.RoomDatabase
import androidx.room.Transaction
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

/**
 * The phone's profile registry: every local profile, and which one is active. Small and separate from the
 * profiles' own databases, which it names.
 */
@Database(entities = [ProfileEntity::class, RegistryEntity::class], version = 1, exportSchema = true)
public abstract class ProfileRegistryDatabase : RoomDatabase() {
    public abstract fun registryDao(): RegistryDao

    public companion object {
        public const val NAME: String = "awrad-profiles.db"
    }
}

/**
 * One profile: [accountId] and [email] are null for the anonymous profile. [after] mirrors the changes-feed
 * position the profile's own database holds (it's written there with each page, in one transaction).
 * [accountDeleted] marks a kept profile whose account no longer exists: it's never queued or synced again.
 */
@Entity(tableName = "profiles")
public data class ProfileEntity(
    @PrimaryKey @ColumnInfo(name = "profile_id") val profileId: String,
    @ColumnInfo(name = "account_id") val accountId: String?,
    @ColumnInfo(name = "email") val email: String?,
    @ColumnInfo(name = "after") val after: Long,
    @ColumnInfo(name = "created_at") val createdAt: Long,
    @ColumnInfo(name = "last_used_at") val lastUsedAt: Long,
    @ColumnInfo(name = "account_deleted", defaultValue = "0") val accountDeleted: Boolean = false,
)

/** The registry's one row: the active profile. */
@Entity(tableName = "registry")
public data class RegistryEntity(
    @PrimaryKey val id: Int = ONLY_ROW,
    @ColumnInfo(name = "active_profile_id") val activeProfileId: String,
) {
    public companion object {
        public const val ONLY_ROW: Int = 0
    }
}

@Dao
public abstract class RegistryDao {
    @Query("SELECT * FROM profiles ORDER BY created_at, profile_id")
    public abstract suspend fun profiles(): List<ProfileEntity>

    @Query("SELECT * FROM profiles ORDER BY created_at, profile_id")
    public abstract fun observeProfiles(): Flow<List<ProfileEntity>>

    @Query("SELECT * FROM registry WHERE id = 0")
    public abstract suspend fun registry(): RegistryEntity?

    @Query("SELECT * FROM registry WHERE id = 0")
    public abstract fun observeRegistry(): Flow<RegistryEntity?>

    @Upsert
    public abstract suspend fun upsertProfile(profile: ProfileEntity)

    @Query("DELETE FROM profiles WHERE profile_id = :profileId")
    public abstract suspend fun deleteProfile(profileId: String)

    @Upsert
    public abstract suspend fun upsertRegistry(registry: RegistryEntity)

    @Query("UPDATE profiles SET after = :after WHERE profile_id = :profileId")
    public abstract suspend fun setAfter(profileId: String, after: Long)

    /** Replaces every profile and the active one in one go. */
    @Transaction
    public open suspend fun replace(profiles: List<ProfileEntity>, registry: RegistryEntity) {
        val kept = profiles.map { it.profileId }.toSet()
        profiles().filterNot { it.profileId in kept }.forEach { deleteProfile(it.profileId) }
        profiles.forEach { upsertProfile(it) }
        upsertRegistry(registry)
    }
}
