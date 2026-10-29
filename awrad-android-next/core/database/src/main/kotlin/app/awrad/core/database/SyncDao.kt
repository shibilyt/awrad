package app.awrad.core.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

/**
 * The profile's synced tables. The blocking calls run inside one `runInTransaction` (the queue rules' store);
 * the flows are what the screens observe.
 */
@Dao
@Suppress("TooManyFunctions") // One small query per table and operation, as Room wants them.
public interface SyncDao {

    // Custom dhikrs

    @Query("SELECT * FROM custom_dhikrs WHERE id = :id")
    public fun customDhikr(id: String): CustomDhikrEntity?

    @Query("SELECT * FROM custom_dhikrs")
    public fun customDhikrs(): List<CustomDhikrEntity>

    @Upsert
    public fun upsertCustomDhikr(entity: CustomDhikrEntity)

    @Query("DELETE FROM custom_dhikrs WHERE id = :id")
    public fun deleteCustomDhikr(id: String)

    @Query("SELECT * FROM custom_dhikrs ORDER BY created_at DESC, id DESC")
    public fun observeCustomDhikrs(): Flow<List<CustomDhikrEntity>>

    @Query("SELECT COUNT(*) FROM custom_dhikrs")
    public fun customDhikrCount(): Int

    /** Whether the profile holds any custom dhikr, tag or personal record. */
    @Query(
        "SELECT EXISTS(SELECT 1 FROM custom_dhikrs) OR EXISTS(SELECT 1 FROM user_tags) " +
            "OR EXISTS(SELECT 1 FROM dhikr_personal)",
    )
    public fun hasData(): Boolean

    // Tags

    @Query("SELECT * FROM user_tags WHERE id = :id")
    public fun userTag(id: String): UserTagEntity?

    @Query("SELECT * FROM user_tags")
    public fun userTags(): List<UserTagEntity>

    @Upsert
    public fun upsertUserTag(entity: UserTagEntity)

    @Query("DELETE FROM user_tags WHERE id = :id")
    public fun deleteUserTag(id: String)

    @Query("SELECT * FROM user_tags ORDER BY name COLLATE NOCASE, id")
    public fun observeUserTags(): Flow<List<UserTagEntity>>

    // Personal records

    @Query("SELECT * FROM dhikr_personal WHERE dhikr_id = :dhikrId")
    public fun personal(dhikrId: String): DhikrPersonalEntity?

    @Query("SELECT * FROM dhikr_personal")
    public fun personals(): List<DhikrPersonalEntity>

    @Upsert
    public fun upsertPersonal(entity: DhikrPersonalEntity)

    @Query("DELETE FROM dhikr_personal WHERE dhikr_id = :dhikrId")
    public fun deletePersonal(dhikrId: String)

    @Query("SELECT * FROM dhikr_personal")
    public fun observePersonals(): Flow<List<DhikrPersonalEntity>>

    // Outbox

    @Query("SELECT * FROM outbox ORDER BY position")
    public fun outbox(): List<OutboxEntity>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    public fun insertCommand(entity: OutboxEntity)

    @Upsert
    public fun upsertCommand(entity: OutboxEntity)

    @Query("DELETE FROM outbox WHERE command_id = :commandId")
    public fun deleteCommand(commandId: String)

    @Query("UPDATE outbox SET sent = 1 WHERE command_id IN (:commandIds)")
    public fun markSent(commandIds: List<String>)

    @Query("SELECT COUNT(*) FROM outbox")
    public fun outboxCount(): Int

    @Query("SELECT COUNT(*) FROM outbox")
    public fun observeOutboxCount(): Flow<Int>

    // Conflicts

    @Query("SELECT * FROM sync_conflicts WHERE entity_type = :entityType AND entity_id = :entityId")
    public fun conflict(entityType: String, entityId: String): ConflictEntity?

    @Upsert
    public fun upsertConflict(entity: ConflictEntity)

    @Query("DELETE FROM sync_conflicts WHERE entity_type = :entityType AND entity_id = :entityId")
    public fun deleteConflict(entityType: String, entityId: String)

    @Query("SELECT * FROM sync_conflicts ORDER BY entity_type, entity_id")
    public fun conflicts(): List<ConflictEntity>

    @Query("SELECT * FROM sync_conflicts ORDER BY entity_type, entity_id")
    public fun observeConflicts(): Flow<List<ConflictEntity>>

    // Notices

    @Insert
    public fun insertNotice(entity: NoticeEntity)

    @Query("DELETE FROM sync_notices WHERE code = :code AND entity_type = :entityType AND entity_id = :entityId")
    public fun deleteNotice(code: String, entityType: String, entityId: String)

    @Query("SELECT * FROM sync_notices ORDER BY id")
    public fun observeNotices(): Flow<List<NoticeEntity>>

    // Sync state

    @Query("SELECT * FROM sync_meta WHERE id = 0")
    public fun meta(): SyncMetaEntity?

    @Upsert
    public fun upsertMeta(entity: SyncMetaEntity)

    @Query("SELECT * FROM sync_meta WHERE id = 0")
    public fun observeMeta(): Flow<SyncMetaEntity?>

    // Recordings waiting to upload

    /** Queues an upload; one already queued or failed for the same dhikr is replaced. */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    public fun insertUpload(entity: AudioUploadEntity)

    @Upsert
    public fun upsertUpload(entity: AudioUploadEntity)

    @Query("SELECT * FROM audio_uploads WHERE asset_id = :assetId")
    public fun upload(assetId: String): AudioUploadEntity?

    @Query("SELECT * FROM audio_uploads WHERE state = 'queued' ORDER BY created_at, asset_id")
    public fun queuedUploads(): List<AudioUploadEntity>

    @Query("DELETE FROM audio_uploads WHERE asset_id = :assetId")
    public fun deleteUpload(assetId: String)

    @Query("DELETE FROM audio_uploads WHERE dhikr_id = :dhikrId")
    public fun deleteUploadsFor(dhikrId: String)

    @Query("DELETE FROM audio_uploads WHERE dhikr_id = :dhikrId AND state = 'failed'")
    public fun deleteFailedUploadFor(dhikrId: String)

    @Query("SELECT * FROM audio_uploads ORDER BY created_at, asset_id")
    public fun observeUploads(): Flow<List<AudioUploadEntity>>
}
