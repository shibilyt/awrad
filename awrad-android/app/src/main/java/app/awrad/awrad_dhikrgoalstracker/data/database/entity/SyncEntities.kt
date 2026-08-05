package app.awrad.awrad_dhikrgoalstracker.data.database.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "sync_state")
data class SyncStateEntity(
    @PrimaryKey val id: Int = 1,
    val boundUserId: String,
    val actorId: String,
    val installationId: String,
    val nextActorSequence: Long = 1,
    val cursor: String? = null,
    val appliedRevision: Long = 0,
    val safeCompactionRevision: Long = 0,
    val generation: Long = 1,
    val initialImportCompleted: Boolean = false,
    val initialImportPayloadJson: String? = null,
    val syncRequested: Boolean = false,
    /** One-time capability-aware snapshot completed after upgrading into dhikr_tags_v1. */
    val dhikrTagsBootstrapCompleted: Boolean = false,
    val generationResetPending: Boolean = false,
    val pendingTransferId: String? = null,
    val pendingTransferKind: String? = null,
    val pendingTransferCursor: String? = null,
    val pendingTransferPage: Int? = null,
    val pendingTransferPageCount: Int? = null,
    val pendingTransferThroughRevision: Long? = null,
    val pendingTransferChecksum: String? = null,
    val pendingTransferRecordCount: Int? = null,
    val lastSyncAt: Long? = null,
    val lastError: String? = null,
)

@Entity(
    tableName = "sync_inbox_pages",
    indices = [Index(value = ["transferId", "pageNumber"], unique = true)],
)
data class SyncInboxPageEntity(
    @PrimaryKey val key: String,
    val transferId: String,
    val pageNumber: Int,
    val checksum: String,
    val recordsJson: String,
    val itemCount: Int,
)

@Entity(
    tableName = "sync_outbox",
    indices = [
        Index(value = ["actorSequence"], unique = true),
        Index(value = ["state", "actorSequence"]),
        Index(value = ["entityType", "entityId"]),
        Index(value = ["goalId", "slotId", "localDate"]),
    ],
)
data class SyncOutboxEntity(
    @PrimaryKey val commandId: String,
    val actorSequence: Long,
    val type: String,
    val payloadJson: String,
    val state: String = "pending",
    val entityType: String? = null,
    val entityId: String? = null,
    val goalId: String? = null,
    val slotId: String? = null,
    val localDate: String? = null,
    val countDelta: Long? = null,
    val createdAt: Long,
    val attemptCount: Int = 0,
    val lastAttemptAt: Long? = null,
    val lastError: String? = null,
)

@Entity(
    tableName = "sync_open_count_batches",
    indices = [Index(value = ["goalId", "slotId", "localDate", "entityIncarnation"], unique = true)],
)
data class SyncOpenCountBatchEntity(
    @PrimaryKey val id: String,
    val goalId: String,
    val slotId: String,
    val localDate: String,
    val entityIncarnation: Long = 1,
    val amount: Long,
    val createdAt: Long,
    val updatedAt: Long,
)

@Entity(
    tableName = "sync_entity_shadows",
    indices = [Index(value = ["entityType", "entityId"], unique = true)],
)
data class SyncEntityShadowEntity(
    @PrimaryKey val key: String,
    val entityType: String,
    val entityId: String,
    val version: Long,
    val incarnation: Long,
    val syncRevision: Long,
    val state: String,
    val documentJson: String?,
    val conflictDocumentJson: String? = null,
)

@Entity(
    tableName = "sync_count_shadows",
    indices = [Index(value = ["goalId", "slotId", "localDate", "entityIncarnation"], unique = true)],
)
data class SyncCountShadowEntity(
    @PrimaryKey val key: String,
    val goalId: String,
    val slotId: String,
    val localDate: String,
    val entityIncarnation: Long,
    val canonicalCount: Long,
    val syncRevision: Long,
)

@Entity(
    tableName = "sync_conflicts",
    indices = [
        Index(value = ["commandId"], unique = true),
        Index(value = ["entityType", "entityId"]),
    ],
)
data class SyncConflictEntity(
    @PrimaryKey val conflictId: String,
    val commandId: String,
    val entityType: String,
    val entityId: String,
    val proposedDocumentJson: String?,
    val syncRevision: Long,
)
