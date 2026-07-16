package app.awrad.awrad_dhikrgoalstracker.data.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncEntityShadowEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncCountShadowEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncConflictEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncInboxPageEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncOpenCountBatchEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncOutboxEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncStateEntity
import com.google.gson.JsonParser

@Dao
abstract class SyncDao {
    @Query("SELECT * FROM sync_state WHERE id = 1")
    abstract suspend fun state(): SyncStateEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    abstract suspend fun putState(state: SyncStateEntity)

    @Query("UPDATE sync_state SET lastError = :error WHERE id = 1")
    abstract suspend fun updateLastError(error: String?): Int

    @Query("UPDATE sync_state SET actorId = :actorId WHERE id = 1")
    abstract suspend fun updateActorId(actorId: String): Int

    @Query("UPDATE sync_state SET initialImportPayloadJson = :payloadJson WHERE id = 1")
    abstract suspend fun updateInitialImportPayload(payloadJson: String?): Int

    @Query("UPDATE sync_state SET initialImportCompleted = 1, initialImportPayloadJson = NULL WHERE id = 1")
    abstract suspend fun completeInitialImport(): Int

    @Query("UPDATE sync_state SET syncRequested = 1 WHERE id = 1 AND syncRequested = 0")
    abstract suspend fun requestSync(): Int

    @Query("UPDATE sync_state SET syncRequested = 0 WHERE id = 1")
    abstract suspend fun clearSyncRequest(): Int

    @Query("UPDATE sync_state SET cursor = NULL, generationResetPending = 1 WHERE id = 1")
    abstract suspend fun requestGenerationReset(): Int

    @Query(
        """
        UPDATE sync_state SET
            pendingTransferId = :transferId,
            pendingTransferKind = :kind,
            pendingTransferCursor = :cursor,
            pendingTransferPage = 1,
            pendingTransferPageCount = :pageCount,
            pendingTransferThroughRevision = :throughRevision,
            pendingTransferChecksum = :checksum,
            pendingTransferRecordCount = :recordCount,
            generation = :generation
        WHERE id = 1 AND pendingTransferId IS NULL
        """,
    )
    abstract suspend fun beginTransfer(
        transferId: String,
        kind: String,
        cursor: String,
        pageCount: Int,
        throughRevision: Long,
        checksum: String,
        recordCount: Int,
        generation: Long,
    ): Int

    @Query("UPDATE sync_state SET nextActorSequence = nextActorSequence + 1 WHERE id = 1")
    protected abstract suspend fun incrementSequence(): Int

    @Transaction
    open suspend fun allocateSequence(): Long {
        val before = requireNotNull(state()) { "Sync state is not initialized" }
        check(incrementSequence() == 1)
        return before.nextActorSequence
    }

    @Insert(onConflict = OnConflictStrategy.ABORT)
    abstract suspend fun insertOutbox(command: SyncOutboxEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    abstract suspend fun putOutbox(command: SyncOutboxEntity)

    @Query("SELECT * FROM sync_outbox WHERE state = 'pending' ORDER BY actorSequence LIMIT :limit")
    abstract suspend fun pendingOutbox(limit: Int = 100): List<SyncOutboxEntity>

    @Query("SELECT * FROM sync_outbox WHERE commandId = :commandId")
    abstract suspend fun outbox(commandId: String): SyncOutboxEntity?

    @Query("SELECT * FROM sync_outbox WHERE state IN ('conflict', 'failed') ORDER BY actorSequence")
    abstract suspend fun unresolvedOutbox(): List<SyncOutboxEntity>

    @Query("SELECT COUNT(*) FROM sync_outbox WHERE state = :state")
    abstract suspend fun outboxCount(state: String): Int

    @Query("SELECT COUNT(*) FROM sync_outbox")
    abstract suspend fun totalOutboxCount(): Int

    @Query("SELECT COUNT(*) FROM sync_open_count_batches")
    abstract suspend fun openBatchCount(): Int

    @Query("SELECT COUNT(*) FROM sync_entity_shadows")
    abstract suspend fun entityShadowCount(): Int

    @Query("SELECT COUNT(*) FROM sync_count_shadows")
    abstract suspend fun countShadowCount(): Int

    @Query("SELECT COUNT(*) FROM sync_inbox_pages")
    abstract suspend fun inboxPageCount(): Int

    @Query("SELECT * FROM sync_outbox WHERE entityType = :entityType AND entityId = :entityId AND state = 'pending' ORDER BY actorSequence DESC LIMIT 1")
    abstract suspend fun pendingEntityCommand(entityType: String, entityId: String): SyncOutboxEntity?

    @Query("DELETE FROM sync_outbox WHERE commandId = :commandId")
    abstract suspend fun deleteOutbox(commandId: String)

    @Query("DELETE FROM sync_outbox WHERE entityType = :entityType AND entityId = :entityId AND type = 'entity_accept_canonical'")
    abstract suspend fun deleteCanonicalAcceptance(entityType: String, entityId: String)

    @Query("DELETE FROM sync_outbox WHERE entityType = :entityType AND entityId = :entityId")
    abstract suspend fun deleteEntityOutbox(entityType: String, entityId: String)

    @Query("DELETE FROM sync_outbox WHERE goalId = :goalId")
    abstract suspend fun deleteCountOutboxForGoal(goalId: String)

    @Query("UPDATE sync_outbox SET state = :state, attemptCount = attemptCount + 1, lastAttemptAt = :now, lastError = :error WHERE commandId = :commandId")
    abstract suspend fun markOutbox(commandId: String, state: String, now: Long, error: String?)

    @Query("UPDATE sync_outbox SET state = 'pending' WHERE state = 'sending'")
    abstract suspend fun releaseInterruptedSends()

    @Query("UPDATE sync_outbox SET state = 'pending' WHERE commandId IN (:commandIds) AND state = 'sending'")
    abstract suspend fun releaseSending(commandIds: List<String>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    abstract suspend fun putInboxPage(page: SyncInboxPageEntity)

    @Query("SELECT * FROM sync_inbox_pages WHERE transferId = :transferId ORDER BY pageNumber")
    abstract suspend fun inboxPages(transferId: String): List<SyncInboxPageEntity>

    @Query("DELETE FROM sync_inbox_pages")
    abstract suspend fun clearInboxPages()

    @Query("SELECT * FROM sync_outbox WHERE goalId = :goalId AND slotId = :slotId AND localDate = :localDate AND state IN ('pending', 'sending') ORDER BY actorSequence")
    protected abstract suspend fun pendingCountCommands(
        goalId: String,
        slotId: String,
        localDate: String,
    ): List<SyncOutboxEntity>

    suspend fun pendingCountDelta(
        goalId: String,
        slotId: String,
        localDate: String,
        incarnation: Long,
    ): Long = pendingCountCommands(goalId, slotId, localDate)
        .filter { it.payloadIncarnation() == incarnation }
        .fold(0L) { total, command -> Math.addExact(total, command.countDelta ?: 0L) }

    suspend fun observedCreditIds(
        goalId: String,
        slotId: String,
        localDate: String,
        incarnation: Long,
    ): List<String> = pendingCountCommands(goalId, slotId, localDate)
        .filter { it.type == "increment" && it.payloadIncarnation() == incarnation }
        .map { it.commandId }

    @Query("SELECT * FROM sync_open_count_batches WHERE goalId = :goalId AND slotId = :slotId AND localDate = :localDate AND entityIncarnation = :incarnation")
    abstract suspend fun openBatch(goalId: String, slotId: String, localDate: String, incarnation: Long): SyncOpenCountBatchEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    abstract suspend fun putOpenBatch(batch: SyncOpenCountBatchEntity)

    @Query("SELECT * FROM sync_open_count_batches ORDER BY createdAt")
    abstract suspend fun openBatches(): List<SyncOpenCountBatchEntity>

    @Query("DELETE FROM sync_open_count_batches WHERE id = :id")
    abstract suspend fun deleteOpenBatch(id: String)

    @Query("DELETE FROM sync_open_count_batches WHERE goalId = :goalId")
    abstract suspend fun deleteOpenBatchesForGoal(goalId: String)

    @Query("SELECT COALESCE(SUM(amount), 0) FROM sync_open_count_batches WHERE goalId = :goalId AND slotId = :slotId AND localDate = :localDate AND entityIncarnation = :incarnation")
    abstract suspend fun openBatchAmount(goalId: String, slotId: String, localDate: String, incarnation: Long): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    abstract suspend fun putShadow(shadow: SyncEntityShadowEntity)

    @Query("SELECT * FROM sync_entity_shadows WHERE entityType = :entityType AND entityId = :entityId")
    abstract suspend fun shadow(entityType: String, entityId: String): SyncEntityShadowEntity?

    @Query("SELECT * FROM sync_entity_shadows")
    abstract suspend fun shadows(): List<SyncEntityShadowEntity>

    @Query("DELETE FROM sync_entity_shadows WHERE `key` = :key")
    abstract suspend fun deleteShadow(key: String)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    abstract suspend fun putCountShadow(shadow: SyncCountShadowEntity)

    @Query("SELECT * FROM sync_count_shadows")
    abstract suspend fun countShadows(): List<SyncCountShadowEntity>

    @Query("SELECT * FROM sync_count_shadows WHERE goalId = :goalId AND slotId = :slotId AND localDate = :localDate AND entityIncarnation = :incarnation LIMIT 1")
    abstract suspend fun countShadow(
        goalId: String,
        slotId: String,
        localDate: String,
        incarnation: Long,
    ): SyncCountShadowEntity?

    @Query("DELETE FROM sync_count_shadows WHERE `key` = :key")
    abstract suspend fun deleteCountShadow(key: String)

    @Query("DELETE FROM sync_count_shadows WHERE goalId = :goalId")
    abstract suspend fun deleteCountShadowsForGoal(goalId: String)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    abstract suspend fun putConflict(conflict: SyncConflictEntity)

    @Query("SELECT * FROM sync_conflicts ORDER BY syncRevision, conflictId")
    abstract suspend fun conflicts(): List<SyncConflictEntity>

    @Query("SELECT * FROM sync_conflicts WHERE commandId = :commandId LIMIT 1")
    abstract suspend fun conflictByCommand(commandId: String): SyncConflictEntity?

    @Query("DELETE FROM sync_conflicts WHERE conflictId = :conflictId OR commandId = :commandId")
    abstract suspend fun deleteConflict(conflictId: String, commandId: String)

    @Query("DELETE FROM sync_conflicts WHERE commandId = :commandId")
    abstract suspend fun deleteConflictByCommand(commandId: String)

    @Query("DELETE FROM sync_conflicts WHERE entityType = :entityType AND entityId = :entityId")
    abstract suspend fun deleteConflictsForEntity(entityType: String, entityId: String)

    @Query("SELECT COUNT(*) FROM sync_conflicts")
    abstract suspend fun conflictCount(): Int

    @Query("SELECT COUNT(*) FROM sync_outbox AS o WHERE o.state = 'conflict' AND NOT EXISTS (SELECT 1 FROM sync_conflicts AS c WHERE c.commandId = o.commandId)")
    abstract suspend fun localOnlyConflictCount(): Int

    @Query("DELETE FROM sync_outbox")
    abstract suspend fun clearOutbox()

    @Query("DELETE FROM sync_open_count_batches")
    abstract suspend fun clearOpenBatches()

    @Query("DELETE FROM sync_entity_shadows")
    abstract suspend fun clearShadows()

    @Query("DELETE FROM sync_count_shadows")
    abstract suspend fun clearCountShadows()

    @Query("DELETE FROM sync_conflicts")
    abstract suspend fun clearConflicts()

    private fun SyncOutboxEntity.payloadIncarnation(): Long? = runCatching {
        JsonParser.parseString(payloadJson).asJsonObject["entity_incarnation"]?.asString?.toLong()
    }.getOrNull()
}
