package app.awrad.awrad_dhikrgoalstracker.data.sync

import androidx.room.withTransaction
import app.awrad.awrad_dhikrgoalstracker.data.contract.v1.DhikrTagAssignmentV1
import app.awrad.awrad_dhikrgoalstracker.data.contract.v1.toProgressContractV1
import app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.SyncDao
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncOpenCountBatchEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncOutboxEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncStateEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.UserTag
import com.google.gson.Gson
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.time.Instant
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class SyncAccountMismatchException : IllegalStateException("Local progress is bound to another account")

data class ProgressSyncHealth(
    val lastSyncAt: Long?,
    val lastError: String?,
    val pendingCommands: Int,
    val conflicts: Int,
    val failedCommands: Int,
)

data class ProgressSyncConflict(
    val commandId: String,
    val entityType: String?,
    val entityId: String?,
    val reason: String?,
)

internal data class SyncBindingFootprint(
    val outboxCount: Int,
    val openBatchCount: Int,
    val entityShadowCount: Int,
    val countShadowCount: Int,
    val inboxPageCount: Int,
    val conflictCount: Int,
)

internal object ProgressSyncBindingPolicy {
    fun canRebindTentative(state: SyncStateEntity, footprint: SyncBindingFootprint): Boolean =
        !state.initialImportCompleted &&
            state.cursor == null &&
            state.appliedRevision == 0L &&
            state.safeCompactionRevision == 0L &&
            state.nextActorSequence == 1L &&
            !state.generationResetPending &&
            state.pendingTransferId == null &&
            state.pendingTransferKind == null &&
            state.pendingTransferCursor == null &&
            state.pendingTransferPage == null &&
            state.pendingTransferPageCount == null &&
            state.pendingTransferThroughRevision == null &&
            state.pendingTransferChecksum == null &&
            state.pendingTransferRecordCount == null &&
            footprint == SyncBindingFootprint(0, 0, 0, 0, 0, 0)
}

internal object ProgressSyncConflictMerge {
    fun merge(
        server: List<ProgressSyncConflict>,
        local: List<ProgressSyncConflict>,
    ): List<ProgressSyncConflict> {
        val serverCommandIds = server.mapTo(mutableSetOf()) { it.commandId }
        return server + local.filter { it.commandId !in serverCommandIds }
    }
}

@Singleton
class ProgressSyncRepository @Inject constructor(
    private val database: AwradDatabase,
    private val syncDao: SyncDao,
    private val scheduler: ProgressSyncScheduler,
) {
    private val gson = Gson()
    private val contractJson = Json { encodeDefaults = true; explicitNulls = true }

    suspend fun bind(userId: String, installationId: String): SyncStateEntity = database.withTransaction {
        val existing = syncDao.state()
        when {
            existing == null -> {
                val state = SyncStateEntity(
                    boundUserId = userId,
                    actorId = UUID.randomUUID().toString(),
                    installationId = installationId,
                )
                syncDao.putState(state)
                state
            }
            existing.boundUserId == userId -> existing
            ProgressSyncBindingPolicy.canRebindTentative(
                existing,
                SyncBindingFootprint(
                    outboxCount = syncDao.totalOutboxCount(),
                    openBatchCount = syncDao.openBatchCount(),
                    entityShadowCount = syncDao.entityShadowCount(),
                    countShadowCount = syncDao.countShadowCount(),
                    inboxPageCount = syncDao.inboxPageCount(),
                    conflictCount = syncDao.conflictCount(),
                ),
            ) -> {
                val state = SyncStateEntity(
                    boundUserId = userId,
                    actorId = UUID.randomUUID().toString(),
                    installationId = installationId,
                )
                syncDao.putState(state)
                state
            }
            else -> throw SyncAccountMismatchException()
        }
    }

    suspend fun health(): ProgressSyncHealth = database.withTransaction {
        val state = syncDao.state()
        ProgressSyncHealth(
            lastSyncAt = state?.lastSyncAt,
            lastError = state?.lastError,
            pendingCommands = syncDao.outboxCount("pending") + syncDao.outboxCount("sending"),
            conflicts = syncDao.conflictCount() + syncDao.localOnlyConflictCount(),
            failedCommands = syncDao.outboxCount("failed"),
        )
    }

    suspend fun conflicts(): List<ProgressSyncConflict> = database.withTransaction {
        val server = syncDao.conflicts().map {
            ProgressSyncConflict(it.commandId, it.entityType, it.entityId, "conflict")
        }
        ProgressSyncConflictMerge.merge(
            server,
            syncDao.unresolvedOutbox()
            .map { ProgressSyncConflict(it.commandId, it.entityType, it.entityId, it.lastError) }
        )
    }

    suspend fun acceptCloud(commandId: String) {
        database.withTransaction {
            val row = syncDao.outbox(commandId)
            val conflict = syncDao.conflictByCommand(commandId)
            val entityType = row?.entityType ?: conflict?.entityType ?: return@withTransaction
            val entityId = row?.entityId ?: conflict?.entityId ?: return@withTransaction
            val shadow = syncDao.shadow(entityType, entityId) ?: return@withTransaction
            row?.let { syncDao.deleteOutbox(commandId) }
            syncDao.deleteConflictByCommand(commandId)
            syncDao.putShadow(shadow.copy(conflictDocumentJson = null))
            val sequence = syncDao.allocateSequence()
            val payload = JsonObject().apply {
                addProperty("type", "entity_accept_canonical")
                addProperty("entity_type", entityType)
                addProperty("entity_id", entityId)
                addProperty("base_version", shadow.version.toString())
                addProperty("entity_incarnation", shadow.incarnation.toString())
            }
            syncDao.insertOutbox(
                SyncOutboxEntity(
                    commandId = UUID.randomUUID().toString(),
                    actorSequence = sequence,
                    type = "entity_accept_canonical",
                    payloadJson = gson.toJson(payload),
                    entityType = entityType,
                    entityId = entityId,
                    createdAt = System.currentTimeMillis(),
                ),
            )
        }
        requestSync()
    }

    suspend fun keepDeviceVersion(commandId: String) {
        database.withTransaction {
            val row = syncDao.outbox(commandId)
            val conflict = syncDao.conflictByCommand(commandId)
            val entityType = row?.entityType ?: conflict?.entityType ?: return@withTransaction
            val entityId = row?.entityId ?: conflict?.entityId ?: return@withTransaction
            val proposed = row?.let {
                JsonParser.parseString(it.payloadJson).asJsonObject["proposed_document"]
            } ?: conflict?.proposedDocumentJson?.let(JsonParser::parseString)
            ?: return@withTransaction
            val shadow = syncDao.shadow(entityType, entityId) ?: return@withTransaction
            row?.let { syncDao.deleteOutbox(commandId) }
            syncDao.deleteConflictByCommand(commandId)
            syncDao.putShadow(shadow.copy(conflictDocumentJson = null))
            val sequence = syncDao.allocateSequence()
            val payload = JsonObject().apply {
                addProperty("type", "entity_upsert")
                addProperty("entity_type", entityType)
                addProperty("entity_id", entityId)
                addProperty("base_version", shadow.version.toString())
                addProperty("entity_incarnation", shadow.incarnation.toString())
                add("proposed_document", proposed)
            }
            syncDao.insertOutbox(
                SyncOutboxEntity(
                    commandId = UUID.randomUUID().toString(),
                    actorSequence = sequence,
                    type = "entity_upsert",
                    payloadJson = gson.toJson(payload),
                    entityType = entityType,
                    entityId = entityId,
                    createdAt = System.currentTimeMillis(),
                ),
            )
        }
        requestSync()
    }

    suspend fun discardCountConflict(commandId: String) = database.withTransaction {
        val row = syncDao.outbox(commandId) ?: return@withTransaction
        if (row.entityType == null && row.state in setOf("conflict", "failed")) {
            syncDao.deleteOutbox(commandId)
        }
    }

    suspend fun enqueueDhikr(dhikr: Dhikr) {
        if (!dhikr.isCustom) return
        val document = contractJson.encodeToString(dhikr.toProgressContractV1())
        enqueueEntity("custom_dhikr", dhikr.id.toString(), JsonParser.parseString(document).asJsonObject)
    }

    suspend fun enqueueUserTag(tag: UserTag) {
        val document = contractJson.encodeToString(tag.toProgressContractV1())
        enqueueEntity("user_tag", tag.id.toString(), JsonParser.parseString(document).asJsonObject)
    }

    suspend fun enqueueTagAssignment(
        id: AwradId,
        tagId: AwradId,
        dhikrId: AwradId,
        createdAt: Long,
    ) {
        val document = contractJson.encodeToString(
            DhikrTagAssignmentV1(
                id = id.toString(),
                tagId = tagId.toString(),
                dhikrId = dhikrId.toString(),
                createdAt = Instant.ofEpochMilli(createdAt).toString(),
            ),
        )
        enqueueEntity("dhikr_tag_assignment", id.toString(), JsonParser.parseString(document).asJsonObject)
    }

    suspend fun enqueueGoal(goal: Goal) {
        val document = contractJson.encodeToString(goal.toProgressContractV1())
        enqueueEntity("goal", goal.id.toString(), JsonParser.parseString(document).asJsonObject)
    }

    suspend fun enqueueEntity(entityType: String, entityId: String, document: JsonObject) {
        database.withTransaction {
            val state = syncDao.state() ?: return@withTransaction
            val shadow = syncDao.shadow(entityType, entityId)
            val existing = syncDao.pendingEntityCommand(entityType, entityId)
            val payload = JsonObject().apply {
                addProperty("type", "entity_upsert")
                addProperty("entity_type", entityType)
                addProperty("entity_id", entityId)
                addProperty("base_version", (shadow?.version ?: 0).toString())
                addProperty("entity_incarnation", (shadow?.incarnation ?: 1).toString())
                add("proposed_document", document)
            }

            if (existing != null && existing.type == "entity_upsert") {
                syncDao.putOutbox(existing.copy(payloadJson = gson.toJson(payload), lastError = null))
            } else {
                val sequence = syncDao.allocateSequence()
                syncDao.insertOutbox(
                    SyncOutboxEntity(
                        commandId = UUID.randomUUID().toString(),
                        actorSequence = sequence,
                        type = "entity_upsert",
                        payloadJson = gson.toJson(payload),
                        entityType = entityType,
                        entityId = entityId,
                        createdAt = System.currentTimeMillis(),
                    ),
                )
            }
            check(syncDao.state()?.actorId == state.actorId)
        }
        requestSync()
    }

    /**
     * Installs a captured pre-cloud entity exactly once. A foreground edit or delete always wins:
     * if one already exists in the outbox, the captured document must never overwrite it.
     */
    suspend fun enqueueInitialEntity(
        commandId: String,
        entityType: String,
        entityId: String,
        document: JsonObject,
    ) {
        database.withTransaction {
            syncDao.state() ?: return@withTransaction
            if (syncDao.pendingEntityCommand(entityType, entityId) != null || syncDao.outbox(commandId) != null) {
                return@withTransaction
            }
            val shadow = syncDao.shadow(entityType, entityId)
            val sequence = syncDao.allocateSequence()
            val payload = JsonObject().apply {
                addProperty("type", "entity_upsert")
                addProperty("entity_type", entityType)
                addProperty("entity_id", entityId)
                addProperty("base_version", (shadow?.version ?: 0).toString())
                addProperty("entity_incarnation", (shadow?.incarnation ?: 1).toString())
                add("proposed_document", document)
            }
            syncDao.insertOutbox(
                SyncOutboxEntity(
                    commandId = commandId,
                    actorSequence = sequence,
                    type = "entity_upsert",
                    payloadJson = gson.toJson(payload),
                    entityType = entityType,
                    entityId = entityId,
                    createdAt = System.currentTimeMillis(),
                ),
            )
        }
    }

    suspend fun enqueueDelete(entityType: String, entityId: String) {
        database.withTransaction {
            syncDao.state() ?: return@withTransaction
            if (entityType == "goal") {
                // These taps have not received actor sequences yet. Once the
                // goal tombstone is allocated they must not be sealed after it
                // and replayed against a deleted incarnation.
                syncDao.deleteOpenBatchesForGoal(entityId)
            }
            val shadow = syncDao.shadow(entityType, entityId)
            val pending = syncDao.pendingEntityCommand(entityType, entityId)
            val baseVersion = (shadow?.version ?: 0L) + if (pending?.type == "entity_upsert") 1L else 0L
            val sequence = syncDao.allocateSequence()
            val payload = JsonObject().apply {
                addProperty("type", "entity_delete")
                addProperty("entity_type", entityType)
                addProperty("entity_id", entityId)
                addProperty("base_version", baseVersion.toString())
                addProperty("entity_incarnation", (shadow?.incarnation ?: 1).toString())
            }
            syncDao.insertOutbox(
                SyncOutboxEntity(
                    commandId = UUID.randomUUID().toString(),
                    actorSequence = sequence,
                    type = "entity_delete",
                    payloadJson = gson.toJson(payload),
                    entityType = entityType,
                    entityId = entityId,
                    createdAt = System.currentTimeMillis(),
                ),
            )
        }
        requestSync()
    }

    suspend fun recordCountDelta(goalId: UUID, slotId: UUID, localDate: String, appliedDelta: Long) {
        if (appliedDelta == 0L) return
        database.withTransaction {
            syncDao.state() ?: return@withTransaction
            val incarnation = syncDao.shadow("goal", goalId.toString())?.incarnation ?: 1L
            if (appliedDelta > 0) {
                val existing = syncDao.openBatch(goalId.toString(), slotId.toString(), localDate, incarnation)
                val now = System.currentTimeMillis()
                val amount = Math.addExact(existing?.amount ?: 0L, appliedDelta)
                syncDao.putOpenBatch(
                    existing?.copy(amount = amount, updatedAt = now)
                        ?: SyncOpenCountBatchEntity(
                            id = UUID.randomUUID().toString(),
                            goalId = goalId.toString(),
                            slotId = slotId.toString(),
                            localDate = localDate,
                            entityIncarnation = incarnation,
                            amount = amount,
                            createdAt = now,
                            updatedAt = now,
                        ),
                )
            } else {
                sealOpenBatchesLocked()
                val state = requireNotNull(syncDao.state())
                val sequence = syncDao.allocateSequence()
                val commandId = UUID.randomUUID().toString()
                val payload = JsonObject().apply {
                    addProperty("type", "decrement_bucket")
                    addProperty("goal_id", goalId.toString())
                    addProperty("slot_id", slotId.toString())
                    addProperty("local_date", localDate)
                    addProperty("amount", Math.negateExact(appliedDelta).toString())
                    addProperty("basis_revision", state.appliedRevision.toString())
                    addProperty("local_frontier_sequence", (sequence - 1).coerceAtLeast(0).toString())
                    // Credits in this actor (including durably adopted actor
                    // lineage) are observed through local_frontier_sequence;
                    // transferred foreign credits are covered by basis_revision.
                    add("observed_local_credit_ids", JsonArray())
                    addProperty("entity_incarnation", incarnation.toString())
                }
                syncDao.insertOutbox(
                    SyncOutboxEntity(
                        commandId = commandId,
                        actorSequence = sequence,
                        type = "decrement_bucket",
                        payloadJson = gson.toJson(payload),
                        goalId = goalId.toString(),
                        slotId = slotId.toString(),
                        localDate = localDate,
                        countDelta = appliedDelta,
                        createdAt = System.currentTimeMillis(),
                    ),
                )
            }
        }
        requestSync()
    }

    /** Adds the legacy portion of a captured bucket exactly once during first import. */
    suspend fun enqueueInitialCount(
        commandId: String,
        goalId: String,
        slotId: String,
        localDate: String,
        incarnation: Long,
        amount: Long,
    ) {
        if (amount <= 0L) return
        database.withTransaction {
            syncDao.state() ?: return@withTransaction
            if (syncDao.outbox(commandId) != null) return@withTransaction
            val sequence = syncDao.allocateSequence()
            val payload = JsonObject().apply {
                addProperty("type", "increment")
                addProperty("goal_id", goalId)
                addProperty("slot_id", slotId)
                addProperty("local_date", localDate)
                addProperty("amount", amount.toString())
                addProperty("entity_incarnation", incarnation.toString())
            }
            syncDao.insertOutbox(
                SyncOutboxEntity(
                    commandId = commandId,
                    actorSequence = sequence,
                    type = "increment",
                    payloadJson = gson.toJson(payload),
                    goalId = goalId,
                    slotId = slotId,
                    localDate = localDate,
                    countDelta = amount,
                    createdAt = System.currentTimeMillis(),
                ),
            )
        }
    }

    suspend fun resetObservedBucket(
        goalId: UUID,
        slotId: UUID,
        localDate: String,
        visibleCount: Long,
    ) {
        if (visibleCount <= 0L) return
        database.withTransaction {
            syncDao.state() ?: return@withTransaction
            sealOpenBatchesLocked()
            val state = requireNotNull(syncDao.state())
            val sequence = syncDao.allocateSequence()
            val incarnation = syncDao.shadow("goal", goalId.toString())?.incarnation ?: 1L
            val payload = JsonObject().apply {
                addProperty("type", "reset_bucket_observed")
                addProperty("goal_id", goalId.toString())
                addProperty("slot_id", slotId.toString())
                addProperty("local_date", localDate)
                addProperty("basis_revision", state.appliedRevision.toString())
                addProperty("local_frontier_sequence", (sequence - 1).coerceAtLeast(0).toString())
                add("observed_local_credit_ids", JsonArray())
                addProperty("entity_incarnation", incarnation.toString())
            }
            syncDao.insertOutbox(
                SyncOutboxEntity(
                    commandId = UUID.randomUUID().toString(),
                    actorSequence = sequence,
                    type = "reset_bucket_observed",
                    payloadJson = gson.toJson(payload),
                    goalId = goalId.toString(),
                    slotId = slotId.toString(),
                    localDate = localDate,
                    countDelta = Math.negateExact(visibleCount),
                    createdAt = System.currentTimeMillis(),
                ),
            )
        }
        requestSync()
    }

    suspend fun sealOpenBatches() = database.withTransaction { sealOpenBatchesLocked() }

    private suspend fun sealOpenBatchesLocked() {
        syncDao.openBatches().forEach { batch ->
            val sequence = syncDao.allocateSequence()
            val payload = JsonObject().apply {
                addProperty("type", "increment")
                addProperty("goal_id", batch.goalId)
                addProperty("slot_id", batch.slotId)
                addProperty("local_date", batch.localDate)
                addProperty("amount", batch.amount.toString())
                addProperty("entity_incarnation", batch.entityIncarnation.toString())
            }
            syncDao.insertOutbox(
                SyncOutboxEntity(
                    commandId = batch.id,
                    actorSequence = sequence,
                    type = "increment",
                    payloadJson = gson.toJson(payload),
                    goalId = batch.goalId,
                    slotId = batch.slotId,
                    localDate = batch.localDate,
                    countDelta = batch.amount,
                    createdAt = batch.createdAt,
                ),
            )
            syncDao.deleteOpenBatch(batch.id)
        }
    }

    private suspend fun requestSync() {
        val shouldSchedule = database.withTransaction { syncDao.requestSync() == 1 }
        if (shouldSchedule) scheduler.enqueue()
    }
}
