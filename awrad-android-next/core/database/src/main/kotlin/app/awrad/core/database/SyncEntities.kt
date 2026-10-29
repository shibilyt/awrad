package app.awrad.core.database

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/*
 * One profile's synced data (contracts/sync/v1): each entity keeps its whole document as JSON text plus the last
 * server version this phone has seen of it (`known_version`, 0 until the server confirms it). Deleted entities
 * aren't kept.
 */

/**
 * A custom dhikr. [audioFile] is its recording in the profile's private files: imported here, or the uploaded
 * recording downloaded on its first play. The file itself never goes through the change queue.
 */
@Entity(tableName = "custom_dhikrs")
public data class CustomDhikrEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "known_version") val knownVersion: Long,
    @ColumnInfo(name = "document") val document: String,
    @ColumnInfo(name = "audio_file") val audioFile: String?,
    /** When this phone first stored it, for "newest first". */
    @ColumnInfo(name = "created_at") val createdAt: Long,
)

/** A user tag: its document is `{name, normalized_name}`. */
@Entity(tableName = "user_tags", indices = [Index("normalized_name")])
public data class UserTagEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "known_version") val knownVersion: Long,
    @ColumnInfo(name = "name") val name: String,
    @ColumnInfo(name = "normalized_name") val normalizedName: String,
)

/** A dhikr's personal record, keyed by the dhikr's ID: [tagIds] is a JSON array of tag IDs, in order. */
@Entity(tableName = "dhikr_personal")
public data class DhikrPersonalEntity(
    @PrimaryKey @ColumnInfo(name = "dhikr_id") val dhikrId: String,
    @ColumnInfo(name = "known_version") val knownVersion: Long,
    @ColumnInfo(name = "tag_ids") val tagIds: String,
)

/** One queued command. [position] orders the queue; [document] is null for a delete. */
@Entity(tableName = "outbox", indices = [Index(value = ["position"], unique = true)])
public data class OutboxEntity(
    @PrimaryKey @ColumnInfo(name = "command_id") val commandId: String,
    @ColumnInfo(name = "position") val position: Long,
    @ColumnInfo(name = "entity_type") val entityType: String,
    @ColumnInfo(name = "entity_id") val entityId: String,
    @ColumnInfo(name = "op") val op: String,
    @ColumnInfo(name = "base_version") val baseVersion: Long,
    @ColumnInfo(name = "document") val document: String?,
    @ColumnInfo(name = "sent") val sent: Boolean,
)

/** An open conflict: the server's copy the user can take instead of the local edit. */
@Entity(tableName = "sync_conflicts", primaryKeys = ["entity_type", "entity_id"])
public data class ConflictEntity(
    @ColumnInfo(name = "entity_type") val entityType: String,
    @ColumnInfo(name = "entity_id") val entityId: String,
    @ColumnInfo(name = "local_op") val localOp: String,
    @ColumnInfo(name = "server_version") val serverVersion: Long,
    @ColumnInfo(name = "server_state") val serverState: String,
    @ColumnInfo(name = "server_document") val serverDocument: String?,
)

/** A change the server refused and the phone undid, until the user dismisses it. */
@Entity(tableName = "sync_notices")
public data class NoticeEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    @ColumnInfo(name = "code") val code: String,
    @ColumnInfo(name = "entity_type") val entityType: String,
    @ColumnInfo(name = "entity_id") val entityId: String,
)

/** The profile's one row of sync state: the changes-feed position and the last successful sync. */
@Entity(tableName = "sync_meta")
public data class SyncMetaEntity(
    @PrimaryKey val id: Int = ONLY_ROW,
    @ColumnInfo(name = "after") val after: Long,
    @ColumnInfo(name = "last_synced_at") val lastSyncedAt: Long?,
) {
    public companion object {
        public const val ONLY_ROW: Int = 0
    }
}

/**
 * A recording waiting to upload to the account (slice 3c), one per custom dhikr. [assetId] is a new UUIDv7 for
 * this file; [sha256], [byteSize], [contentType] and [durationMs] are measured on the first attempt and kept, so a
 * retry reserves the same body. [state] is `queued` or `failed`; a failed one keeps the recording on the phone and
 * is a notice ([problem], with the account's [usedBytes] and [limitBytes] when it's full) until dismissed.
 * [mismatches] counts `upload_mismatch` answers in a row.
 */
@Entity(tableName = "audio_uploads", indices = [Index(value = ["dhikr_id"], unique = true)])
public data class AudioUploadEntity(
    @PrimaryKey @ColumnInfo(name = "asset_id") val assetId: String,
    @ColumnInfo(name = "dhikr_id") val dhikrId: String,
    @ColumnInfo(name = "audio_file") val audioFile: String,
    @ColumnInfo(name = "state") val state: String,
    @ColumnInfo(name = "created_at") val createdAt: Long,
    @ColumnInfo(name = "sha256") val sha256: String? = null,
    @ColumnInfo(name = "byte_size") val byteSize: Long? = null,
    @ColumnInfo(name = "content_type") val contentType: String? = null,
    @ColumnInfo(name = "duration_ms") val durationMs: Long? = null,
    @ColumnInfo(name = "problem") val problem: String? = null,
    @ColumnInfo(name = "used_bytes") val usedBytes: Long? = null,
    @ColumnInfo(name = "limit_bytes") val limitBytes: Long? = null,
    @ColumnInfo(name = "mismatches") val mismatches: Int = 0,
) {
    public companion object {
        public const val QUEUED: String = "queued"
        public const val FAILED: String = "failed"
    }
}
