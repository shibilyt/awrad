package app.awrad.awrad_dhikrgoalstracker.data.sync

import android.util.Log
import androidx.room.withTransaction
import app.awrad.awrad_dhikrgoalstracker.data.contract.v1.DhikrTagAssignmentV1
import app.awrad.awrad_dhikrgoalstracker.data.contract.v1.DhikrV1
import app.awrad.awrad_dhikrgoalstracker.data.contract.v1.GoalV1
import app.awrad.awrad_dhikrgoalstracker.data.contract.v1.UserTagV1
import app.awrad.awrad_dhikrgoalstracker.data.contract.v1.toNativeDhikr
import app.awrad.awrad_dhikrgoalstracker.data.contract.v1.toNativeGoal
import app.awrad.awrad_dhikrgoalstracker.data.contract.v1.toNativeUserTag
import app.awrad.awrad_dhikrgoalstracker.data.contract.v1.toProgressContractV1
import app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.CountEntryDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.SyncDao
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncEntityShadowEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncCountShadowEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncConflictEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncInboxPageEntity
import app.awrad.awrad_dhikrgoalstracker.data.network.AwradApiService
import app.awrad.awrad_dhikrgoalstracker.data.network.SyncCommandBatchRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.SyncActorAckRequest
import app.awrad.awrad_dhikrgoalstracker.data.network.SyncReceiptDto
import app.awrad.awrad_dhikrgoalstracker.data.network.SyncTransferPageDto
import app.awrad.awrad_dhikrgoalstracker.data.network.SyncTransferRecordDto
import app.awrad.awrad_dhikrgoalstracker.data.network.SyncTransferRequest
import app.awrad.awrad_dhikrgoalstracker.data.preferences.AuthTokenManager
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepositoryImpl
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepositoryImpl
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationRequestDispatcher
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationRequestReason
import com.google.gson.Gson
import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.io.IOException
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Singleton
class ProgressSyncEngine @Inject constructor(
    private val api: AwradApiService,
    private val database: AwradDatabase,
    private val syncDao: SyncDao,
    private val countEntryDao: CountEntryDao,
    private val goalDao: GoalDao,
    private val goalRepository: GoalRepositoryImpl,
    private val dhikrRepository: DhikrRepositoryImpl,
    private val syncRepository: ProgressSyncRepository,
    private val tokenManager: AuthTokenManager,
    private val feedbackBus: ProgressSyncFeedbackBus,
    private val notificationRequests: NotificationObligationRequestDispatcher,
    private val practiceSettingsRepository: PracticeSettingsRepository,
) {
    private val gson = Gson()
    private val contractJson = Json {
        ignoreUnknownKeys = false
        encodeDefaults = true
        explicitNulls = true
    }
    private val syncMutex = Mutex()

    suspend fun synchronize() = syncMutex.withLock {
        do {
            syncDao.clearSyncRequest()
            synchronizeOnce()
        } while (syncDao.state()?.syncRequested == true)
    }

    private suspend fun synchronizeOnce() {
        val userId = tokenManager.userId.first() ?: return
        val state = syncRepository.bind(userId, tokenManager.installationId())
        try {
            practiceSettingsRepository.synchronize()
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            Log.w("ProgressSyncEngine", "Practice settings synchronization failed", error)
        }
        // A process may have died after sealing a request but before handling
        // its response. The payload is immutable while `sending`, so releasing
        // it here makes the next attempt an exact idempotent replay.
        syncDao.releaseInterruptedSends()
        val initial = if (!state.initialImportCompleted) loadOrCaptureInitialState() else null
        resumeOrPull()
        initial?.let {
            prepareInitialUpload(it)
            database.withTransaction {
                check(syncDao.completeInitialImport() == 1)
            }
        }
        syncRepository.sealOpenBatches()
        pushPending()
        resumeOrPull()
        acknowledgeActor()
    }

    suspend fun recordFailure(error: Throwable) {
        val detail = "${error::class.java.simpleName}: ${error.message ?: "sync failed"}".take(1_024)
        syncDao.updateLastError(detail)
    }

    private suspend fun loadOrCaptureInitialState(): InitialLocalState = database.withTransaction {
        val state = requireNotNull(syncDao.state())
        state.initialImportPayloadJson?.let {
            return@withTransaction gson.fromJson(it, InitialLocalState::class.java)
        }

        val dhikrs = dhikrRepository.getAllDhikrs().first()
            .filter { it.isCustom }
            .map { dhikr ->
                InitialEntity(
                    commandId = UUID.randomUUID().toString(),
                    entityType = "custom_dhikr",
                    entityId = dhikr.id.toString(),
                    documentJson = contractJson.encodeToString(dhikr.toProgressContractV1()),
                )
            }
        val goals = goalRepository.getAllGoals().first().map { goal ->
            InitialEntity(
                commandId = UUID.randomUUID().toString(),
                entityType = "goal",
                entityId = goal.id.toString(),
                documentJson = contractJson.encodeToString(goal.toProgressContractV1()),
            )
        }
        val counts = countEntryDao.allForInitialSync().mapNotNull { entry ->
            val goalId = entry.goalId.toString()
            val slotId = entry.slotId.toString()
            val incarnation = syncDao.shadow("goal", goalId)?.incarnation ?: 1L
            val alreadyQueued = Math.addExact(
                syncDao.pendingCountDelta(goalId, slotId, entry.date, incarnation),
                syncDao.openBatchAmount(goalId, slotId, entry.date, incarnation),
            )
            val legacyAmount = ProgressSyncImportMath.legacyAmount(entry.count, alreadyQueued)
            legacyAmount.takeIf { it > 0L }?.let {
                InitialCount(
                    commandId = UUID.randomUUID().toString(),
                    goalId = goalId,
                    slotId = slotId,
                    localDate = entry.date,
                    incarnation = incarnation,
                    amount = it,
                )
            }
        }
        val captured = InitialLocalState(dhikrs = dhikrs, goals = goals, counts = counts)
        check(syncDao.updateInitialImportPayload(gson.toJson(captured)) == 1)
        captured
    }

    private suspend fun prepareInitialUpload(initial: InitialLocalState) {
        initial.dhikrs
            .filter { syncDao.shadow("custom_dhikr", it.entityId) == null }
            .forEach { entity ->
                syncRepository.enqueueInitialEntity(
                    entity.commandId,
                    entity.entityType,
                    entity.entityId,
                    JsonParser.parseString(entity.documentJson).asJsonObject,
                )
            }

        val cloudGoalIds = initial.goals
            .filter { syncDao.shadow("goal", it.entityId) != null }
            .mapTo(mutableSetOf()) { it.entityId }
        // UUID overlap means the cloud already owns that entity lineage. Keep
        // the cloud aggregate exactly and never silently add an untraceable
        // legacy local total (which could be the same taps restored twice).
        database.withTransaction {
            cloudGoalIds.forEach { goalId ->
                val id = UUID.fromString(goalId)
                countEntryDao.deleteForGoal(id)
                goalDao.resetGoalCount(id, System.currentTimeMillis())
            }
            syncDao.countShadows()
                .filter { shadow ->
                    shadow.goalId in cloudGoalIds &&
                        syncDao.shadow("goal", shadow.goalId)?.incarnation == shadow.entityIncarnation
                }
                .forEach { shadow ->
                    installCanonicalCount(
                        shadow.goalId,
                        shadow.slotId,
                        shadow.localDate,
                        shadow.canonicalCount,
                        shadow.entityIncarnation,
                        shadow.syncRevision,
                    )
                }
        }
        if (cloudGoalIds.isNotEmpty()) {
            notificationRequests.request(NotificationObligationRequestReason.SYNC_IMPORT)
        }

        val newGoalIds = initial.goals
            .filter { syncDao.shadow("goal", it.entityId) == null }
            .mapTo(mutableSetOf()) { it.entityId }
        initial.goals.filter { it.entityId in newGoalIds }.forEach { entity ->
            syncRepository.enqueueInitialEntity(
                entity.commandId,
                entity.entityType,
                entity.entityId,
                JsonParser.parseString(entity.documentJson).asJsonObject,
            )
        }
        initial.counts.filter { it.goalId in newGoalIds }.forEach { entry ->
            syncRepository.enqueueInitialCount(
                entry.commandId,
                entry.goalId,
                entry.slotId,
                entry.localDate,
                entry.incarnation,
                entry.amount,
            )
        }
    }

    private suspend fun acknowledgeActor() {
        var recoveredFork = false
        while (true) {
            val state = syncDao.state() ?: return
            val response = api.acknowledgeProgressActor(
                SyncActorAckRequest(
                    actorId = state.actorId,
                    installationId = state.installationId,
                    startingSequence = state.nextActorSequence.toString(),
                    appliedRevision = state.appliedRevision.toString(),
                    safeCompactionRevision = state.safeCompactionRevision.toString(),
                ),
            )
            if (!response.isSuccessful) {
                val errorCode = response.errorBody()?.string()?.let(::syncErrorCode)
                if (!recoveredFork && response.code() == 409 && errorCode == "actor_fork") {
                    check(syncDao.updateActorId(UUID.randomUUID().toString()) == 1)
                    recoveredFork = true
                    continue
                }
                throw IOException("Progress actor acknowledgement failed: ${response.code()} ${errorCode.orEmpty()}")
            }
            val body = response.body() ?: throw IOException("Progress actor acknowledgement returned no body")
            validateHeader(body.header)
            val applied = body.appliedRevision.toLongOrNull()
            val safe = body.safeCompactionRevision.toLongOrNull()
            if (body.actorId != state.actorId || applied == null || safe == null ||
                applied != state.appliedRevision || safe != state.safeCompactionRevision || safe > applied
            ) {
                throw IOException("Progress actor acknowledgement frontier mismatch")
            }
            return
        }
    }

    private suspend fun pushPending() {
        while (true) {
            val state = syncDao.state() ?: return
            val pending = database.withTransaction {
                val rows = syncDao.pendingOutbox()
                val now = System.currentTimeMillis()
                rows.forEach { syncDao.markOutbox(it.commandId, "sending", now, null) }
                rows
            }
            if (pending.isEmpty()) return

            val commands = pending.map { command ->
                JsonParser.parseString(command.payloadJson).asJsonObject.deepCopy().apply {
                    addProperty("command_id", command.commandId)
                    addProperty("actor_id", state.actorId)
                    addProperty("actor_sequence", command.actorSequence.toString())
                }
            }

            val commandIds = pending.map { it.commandId }
            try {
                val response = api.pushProgressCommands(
                    SyncCommandBatchRequest(installationId = state.installationId, commands = commands),
                )
                if (!response.isSuccessful) {
                    val errorCode = response.errorBody()?.string()?.let(::syncErrorCode)
                    if (response.code() == 409 && errorCode == "actor_fork") {
                        database.withTransaction {
                            syncDao.releaseSending(commandIds)
                            check(syncDao.updateActorId(UUID.randomUUID().toString()) == 1)
                        }
                        continue
                    }
                    throw IOException("Progress command push failed: ${response.code()} ${errorCode.orEmpty()}")
                }
                val body = response.body() ?: throw IOException("Progress command push returned no body")
                validateHeader(body.header)
                validateReceiptSet(commandIds, body.receipts)
                applyReceipts(body.receipts)
            } catch (error: Throwable) {
                database.withTransaction { syncDao.releaseSending(commandIds) }
                throw error
            }
            if (pending.size < 100) return
        }
    }

    private fun syncErrorCode(body: String): String? = runCatching {
        JsonParser.parseString(body).asJsonObject.get("error")?.asString
    }.getOrNull()

    private fun validateReceiptSet(commandIds: List<String>, receipts: List<SyncReceiptDto>) {
        if (!ProgressSyncReceiptIntegrity.isComplete(commandIds, receipts.map { it.commandId })) {
            throw IOException("Progress command response receipt set mismatch")
        }
    }

    private suspend fun applyReceipts(receipts: List<SyncReceiptDto>) {
        var schedulingRelevantChanged = false
        val countChanges = database.withTransaction {
            val changes = mutableListOf<ProgressSyncCountChange>()
            receipts.forEach { receipt ->
                val outbox = syncDao.outbox(receipt.commandId) ?: return@forEach
                val revision = receipt.resultRevision.toLong()

                if (isDeletionFence(receipt.canonicalEffect)) {
                    applyPurgedEntityReceipt(receipt.canonicalEffect, revision)
                    schedulingRelevantChanged = schedulingRelevantChanged ||
                        receipt.canonicalEffect.get("entity_type")?.asString == "goal"
                    return@forEach
                }

                when (receipt.status) {
                    "accepted", "duplicate" -> {
                        when {
                            outbox.goalId != null && receipt.canonicalEffect.has("count") -> {
                                syncDao.deleteOutbox(outbox.commandId)
                                installCanonicalCount(
                                    outbox.goalId,
                                    requireNotNull(outbox.slotId),
                                    requireNotNull(outbox.localDate),
                                    receipt.canonicalEffect["count"].asString.toLong(),
                                    receipt.canonicalEffect.get("entity_incarnation")
                                        ?.asString?.toLongOrNull() ?: 1L,
                                    revision,
                                )?.let(changes::add)
                            }
                            outbox.entityType != null -> {
                                val effectId = receipt.canonicalEffect.get("entity_id")?.asString
                                val localId = outbox.entityId
                                if (outbox.entityType == "user_tag" &&
                                    effectId != null &&
                                    localId != null &&
                                    effectId != localId
                                ) {
                                    applyUserTagCoalesce(
                                        localTagId = UUID.fromString(localId),
                                        effect = receipt.canonicalEffect,
                                    )
                                } else {
                                    applyCanonicalEntityEffect(receipt.canonicalEffect)
                                }
                                installEntityShadow(receipt.canonicalEffect, revision, null)
                                syncDao.deleteOutbox(outbox.commandId)
                                rebaseNextEntityEdit(receipt.canonicalEffect)
                                schedulingRelevantChanged = schedulingRelevantChanged ||
                                    outbox.entityType == "goal"
                            }
                            else -> syncDao.deleteOutbox(outbox.commandId)
                        }
                    }
                    "conflict" -> {
                        installEntityShadow(receipt.canonicalEffect, revision, outbox.payloadJson)
                        applyCanonicalEntityEffect(receipt.canonicalEffect)
                        schedulingRelevantChanged = schedulingRelevantChanged ||
                            receipt.canonicalEffect.get("entity_type")?.asString == "goal"
                        syncDao.markOutbox(
                            outbox.commandId,
                            "conflict",
                            System.currentTimeMillis(),
                            "conflict",
                        )
                    }
                    "stale_basis" -> {
                        syncDao.markOutbox(
                            outbox.commandId,
                            "conflict",
                            System.currentTimeMillis(),
                            "stale_basis",
                        )
                        installCanonicalCountEffect(receipt.canonicalEffect, revision)
                    }
                    "invalid", "gone", "blocked_dependency" -> {
                        syncDao.markOutbox(
                            outbox.commandId,
                            "failed",
                            System.currentTimeMillis(),
                            receipt.status,
                        )
                        if (receipt.canonicalEffect.has("entity_type")) {
                            installEntityShadow(receipt.canonicalEffect, revision, null)
                            applyCanonicalEntityEffect(receipt.canonicalEffect)
                            schedulingRelevantChanged = schedulingRelevantChanged ||
                                receipt.canonicalEffect.get("entity_type")?.asString == "goal"
                        }
                        if (outbox.goalId != null) {
                            val currentIncarnation = syncDao.shadow("goal", outbox.goalId)?.incarnation
                            val effectIncarnation = receipt.canonicalEffect
                                .get("entity_incarnation")?.asString?.toLongOrNull()
                            if (receipt.canonicalEffect.has("count") && effectIncarnation == currentIncarnation) {
                                installCanonicalCountEffect(receipt.canonicalEffect, revision)
                            } else {
                                reinstallVisibleCount(outbox, revision)
                            }
                        }
                    }
                    else -> throw IOException("Unknown sync receipt status ${receipt.status}")
                }
            }
            changes
        }
        feedbackBus.publish(countChanges)
        if (countChanges.isNotEmpty() || schedulingRelevantChanged) {
            notificationRequests.request(
                NotificationObligationRequestReason.SYNC_IMPORT,
                countChanges.mapTo(linkedSetOf()) { it.goalId },
            )
        }
    }

    private fun isDeletionFence(effect: JsonObject): Boolean = ProgressSyncPurgeEffect.isFence(effect)

    private suspend fun applyPurgedEntityReceipt(effect: JsonObject, revision: Long) {
        val entityType = effect.get("entity_type")?.asString
            ?: throw IOException("Purged receipt is missing entity_type")
        val entityId = effect.get("entity_id")?.asString
            ?: throw IOException("Purged receipt is missing entity_id")
        installEntityShadow(effect, revision, null)
        syncDao.deleteEntityOutbox(entityType, entityId)
        syncDao.deleteConflictsForEntity(entityType, entityId)
        if (entityType == "goal") {
            syncDao.deleteCountOutboxForGoal(entityId)
            syncDao.deleteOpenBatchesForGoal(entityId)
            syncDao.deleteCountShadowsForGoal(entityId)
        }
        applyCanonicalEntityEffect(effect)
    }

    private suspend fun resumeOrPull() {
        var state = requireNotNull(syncDao.state())
        if (state.pendingTransferId != null && state.pendingTransferThroughRevision == null) {
            // A v7 process may have died between starting and finishing a
            // transfer. Restart it because v7 did not persist its frontier.
            resetPendingTransfer()
            state = requireNotNull(syncDao.state())
        }
        while (state.pendingTransferId == null) {
            // One-time capability-aware snapshot when first gaining dhikr_tags_v1.
            val requestedCursor = if (!state.dhikrTagsBootstrapCompleted) null else state.cursor
            val kind = if (requestedCursor == null) "snapshot" else "delta"
            val response = if (kind == "snapshot") {
                api.startProgressSnapshot(SyncTransferRequest(kind = kind, cursor = null))
            } else {
                api.startProgressDelta(SyncTransferRequest(kind = kind, cursor = requestedCursor))
            }
            if (response.code() == 409 && kind == "delta") {
                check(syncDao.requestGenerationReset() == 1)
                state = requireNotNull(syncDao.state())
                continue
            }
            if (!response.isSuccessful) throw IOException("Progress transfer start failed: ${response.code()}")
            val session = response.body() ?: throw IOException("Progress transfer returned no body")
            validateHeader(session.header)
            if (session.status == "unchanged") {
                val throughRevision = session.throughRevision.toLong()
                val generation = session.generation.toLong()
                if (
                    "unchanged_delta" !in session.header.capabilities ||
                    kind != "delta" || session.kind != "delta" ||
                    throughRevision != state.appliedRevision || generation != state.generation
                ) {
                    throw IOException("Invalid unchanged progress delta")
                }
                database.withTransaction {
                    val current = requireNotNull(syncDao.state())
                    syncDao.putState(
                        current.copy(
                            cursor = session.cursor,
                            lastSyncAt = System.currentTimeMillis(),
                            lastError = null,
                        ),
                    )
                }
                return
            }
            val transferId = session.transferId
                ?: throw IOException("Progress transfer is missing its ID")
            val pageCount = session.pageCount
                ?: throw IOException("Progress transfer is missing its page count")
            val recordCount = session.recordCount
                ?: throw IOException("Progress transfer is missing its record count")
            val checksum = session.checksum
                ?: throw IOException("Progress transfer is missing its checksum")
            if (session.status != null || session.kind != kind || pageCount <= 0 || recordCount < 0) {
                throw IOException("Invalid progress transfer session")
            }
            database.withTransaction {
                syncDao.clearInboxPages()
                check(
                    syncDao.beginTransfer(
                        transferId = transferId,
                        kind = session.kind,
                        cursor = session.cursor,
                        pageCount = pageCount,
                        throughRevision = session.throughRevision.toLong(),
                        checksum = checksum,
                        recordCount = recordCount,
                        generation = session.generation.toLong(),
                    ) == 1,
                )
            }
            state = requireNotNull(syncDao.state())
        }

        while (state.pendingTransferPage != null && state.pendingTransferPage <= requireNotNull(state.pendingTransferPageCount)) {
            val kind = when (state.pendingTransferKind) {
                "snapshot" -> "snapshots"
                "delta" -> "deltas"
                else -> throw IOException("Missing progress transfer kind")
            }
            val response = api.progressTransferPage(
                kind,
                requireNotNull(state.pendingTransferId),
                state.pendingTransferPage,
            )
            if (response.code() == 410) {
                resetPendingTransfer()
                return resumeOrPull()
            }
            if (!response.isSuccessful) throw IOException("Progress transfer page failed: ${response.code()}")
            val page = response.body() ?: throw IOException("Progress transfer page returned no body")
            validateHeader(page.header)
            if (page.transferId != state.pendingTransferId || page.page != state.pendingTransferPage) {
                throw IOException("Unexpected progress transfer page")
            }
            verifyPage(page)
            stagePage(page)
            state = requireNotNull(syncDao.state())
        }

        state = requireNotNull(syncDao.state())
        if (state.pendingTransferPage != null && state.pendingTransferPage > requireNotNull(state.pendingTransferPageCount)) {
            installStagedTransfer()
        }
    }

    private suspend fun resetPendingTransfer() = database.withTransaction {
        val state = requireNotNull(syncDao.state())
        syncDao.putState(
            state.copy(
                pendingTransferId = null,
                pendingTransferKind = null,
                pendingTransferCursor = null,
                pendingTransferPage = null,
                pendingTransferPageCount = null,
                pendingTransferThroughRevision = null,
                pendingTransferChecksum = null,
                pendingTransferRecordCount = null,
            ),
        )
        syncDao.clearInboxPages()
    }

    private suspend fun stagePage(page: SyncTransferPageDto) = database.withTransaction {
        val state = requireNotNull(syncDao.state())
        check(state.pendingTransferId == page.transferId)
        syncDao.putInboxPage(
            SyncInboxPageEntity(
                key = "${page.transferId}:${page.page}",
                transferId = page.transferId,
                pageNumber = page.page,
                checksum = page.checksum,
                recordsJson = gson.toJson(page.records),
                itemCount = page.records.size(),
            ),
        )
        syncDao.putState(state.copy(pendingTransferPage = requireNotNull(state.pendingTransferPage) + 1))
    }

    private suspend fun installStagedTransfer() {
        var schedulingRelevantChanged = false
        val countChanges = database.withTransaction {
            val state = requireNotNull(syncDao.state())
            val shouldNotify = state.pendingTransferKind == "delta" && !state.generationResetPending
            val changes = mutableListOf<ProgressSyncCountChange>()
            val transferId = requireNotNull(state.pendingTransferId)
            val pages = syncDao.inboxPages(transferId)
            val expectedPages = requireNotNull(state.pendingTransferPageCount)
            if (pages.size != expectedPages || pages.map { it.pageNumber } != (1..expectedPages).toList()) {
                throw IOException("Progress transfer is missing a staged page")
            }
            val recordCount = pages.sumOf { it.itemCount }
            if (recordCount != requireNotNull(state.pendingTransferRecordCount)) {
                throw IOException("Progress transfer record count mismatch")
            }
            val actualSessionChecksum = ProgressSyncPageIntegrity.sessionChecksum(
                pages.map { it.checksum },
                recordCount,
            )
            if (actualSessionChecksum != state.pendingTransferChecksum) {
                throw IOException("Progress transfer session checksum mismatch")
            }

            val records = pages
                .flatMap { page ->
                    JsonParser.parseString(page.recordsJson).asJsonArray.map {
                        gson.fromJson(it, SyncTransferRecordDto::class.java)
                    }
                }
                .sortedWith(
                    compareBy<SyncTransferRecordDto>(
                        { dependencyOrder(it.kind) },
                        { it.syncRevision.toLong() },
                    ),
                )
            if (state.generationResetPending) reconcileGeneration(records)
            records.forEach { record ->
                applyRecord(record)?.takeIf { shouldNotify }?.let(changes::add)
                schedulingRelevantChanged = schedulingRelevantChanged || record.affectsNotificationScheduling()
            }

            val committedRevision = if (state.generationResetPending) {
                requireNotNull(state.pendingTransferThroughRevision)
            } else {
                maxOf(state.appliedRevision, requireNotNull(state.pendingTransferThroughRevision))
            }
            syncDao.putState(
                state.copy(
                    cursor = state.pendingTransferCursor,
                    appliedRevision = committedRevision,
                    safeCompactionRevision = safeRevision(committedRevision),
                    generationResetPending = false,
                    dhikrTagsBootstrapCompleted = state.dhikrTagsBootstrapCompleted ||
                        state.pendingTransferKind == "snapshot",
                    pendingTransferId = null,
                    pendingTransferKind = null,
                    pendingTransferCursor = null,
                    pendingTransferPage = null,
                    pendingTransferPageCount = null,
                    pendingTransferThroughRevision = null,
                    pendingTransferChecksum = null,
                    pendingTransferRecordCount = null,
                    lastSyncAt = System.currentTimeMillis(),
                    lastError = null,
                ),
            )
            syncDao.clearInboxPages()
            changes
        }
        feedbackBus.publish(countChanges)
        if (countChanges.isNotEmpty() || schedulingRelevantChanged) {
            notificationRequests.request(
                NotificationObligationRequestReason.SYNC_IMPORT,
                countChanges.mapTo(linkedSetOf()) { it.goalId },
            )
        }
    }

    private suspend fun applyRecord(record: SyncTransferRecordDto): ProgressSyncCountChange? =
        when (record.kind) {
            "custom_dhikr", "goal", "user_tag", "dhikr_tag_assignment" -> {
                applyEntity(record)
                null
            }
            "count_projection" -> {
                val payload = record.payload
                val goalShadow = syncDao.shadow("goal", payload["goal_id"].asString)
                val incarnation = payload["entity_incarnation"].asString.toLong()
                if (goalShadow != null && goalShadow.incarnation != incarnation) {
                    null
                } else {
                    installCanonicalCount(
                        payload["goal_id"].asString,
                        payload["slot_id"].asString,
                        payload["local_date"].asString,
                        payload["count"].asString.toLong(),
                        incarnation,
                        record.syncRevision.toLong(),
                    )
                }
            }
            "tombstone", "deletion_fence" -> {
                applyTombstone(record)
                null
            }
            "conflict" -> {
                applyConflict(record)
                null
            }
            else -> throw IOException("Unknown progress transfer record kind ${record.kind}")
        }

    private suspend fun applyEntity(record: SyncTransferRecordDto) {
        val payload = record.payload
        val document = payload["document"].asJsonObject
        val previousShadow = syncDao.shadow(record.kind, record.id)
        val pending = syncDao.pendingEntityCommand(record.kind, record.id)
        val shadow = SyncEntityShadowEntity(
            key = "${record.kind}:${record.id}",
            entityType = record.kind,
            entityId = record.id,
            version = payload["entity_version"].asString.toLong(),
            incarnation = payload["entity_incarnation"].asString.toLong(),
            syncRevision = record.syncRevision.toLong(),
            state = "active",
            documentJson = gson.toJson(document),
        )
        syncDao.putShadow(shadow)
        if (pending != null) return

        if (record.kind == "goal" && previousShadow != null && previousShadow.incarnation != shadow.incarnation) {
            val goalId = UUID.fromString(record.id)
            countEntryDao.deleteForGoal(goalId)
            goalDao.resetGoalCount(goalId, System.currentTimeMillis())
            syncDao.deleteCountShadowsForGoal(record.id)
        }

        when (record.kind) {
            "custom_dhikr" -> dhikrRepository.applyRemoteDhikr(
                contractJson.decodeFromString<DhikrV1>(gson.toJson(document)).toNativeDhikr(),
            )
            "goal" -> goalRepository.applyRemoteGoal(
                contractJson.decodeFromString<GoalV1>(gson.toJson(document)).toNativeGoal(),
            )
            "user_tag" -> dhikrRepository.applyRemoteUserTag(
                contractJson.decodeFromString<UserTagV1>(gson.toJson(document)).toNativeUserTag(),
            )
            "dhikr_tag_assignment" -> {
                val assignment = contractJson.decodeFromString<DhikrTagAssignmentV1>(gson.toJson(document))
                dhikrRepository.applyRemoteTagAssignment(
                    id = UUID.fromString(assignment.id),
                    tagId = UUID.fromString(assignment.tagId),
                    dhikrId = UUID.fromString(assignment.dhikrId),
                    createdAt = java.time.Instant.parse(assignment.createdAt).toEpochMilli(),
                )
            }
        }
    }

    private suspend fun applyTombstone(record: SyncTransferRecordDto) {
        val type = record.payload["entity_type"].asString
        val pending = syncDao.pendingEntityCommand(type, record.id)
        syncDao.putShadow(
            SyncEntityShadowEntity(
                key = "$type:${record.id}",
                entityType = type,
                entityId = record.id,
                version = record.payload["entity_version"].asString.toLong(),
                incarnation = record.payload["entity_incarnation"].asString.toLong(),
                syncRevision = record.syncRevision.toLong(),
                state = if (record.kind == "deletion_fence") "purged" else "deleted",
                documentJson = null,
            ),
        )
        if (pending != null) return
        if (type == "goal") {
            goalRepository.deleteRemoteGoal(UUID.fromString(record.id))
            syncDao.deleteCountShadowsForGoal(record.id)
        }
        if (type == "custom_dhikr") dhikrRepository.deleteRemoteDhikr(UUID.fromString(record.id))
        if (type == "user_tag") dhikrRepository.deleteRemoteUserTag(UUID.fromString(record.id))
        if (type == "dhikr_tag_assignment") {
            dhikrRepository.deleteRemoteTagAssignment(UUID.fromString(record.id))
        }
    }

    private suspend fun applyConflict(record: SyncTransferRecordDto) {
        val commandId = record.payload["command_id"].asString
        val resolved = ProgressSyncConflictDelta.isResolved(record.payload)
        if (resolved) {
            syncDao.deleteConflict(record.id, commandId)
            syncDao.outbox(commandId)?.let { syncDao.deleteOutbox(commandId) }
            val entityType = record.payload.get("entity_type")?.asString
            val entityId = record.payload.get("entity_id")?.asString
            if (entityType != null && entityId != null) {
                syncDao.deleteCanonicalAcceptance(entityType, entityId)
                syncDao.shadow(entityType, entityId)?.let { shadow ->
                    syncDao.putShadow(shadow.copy(conflictDocumentJson = null))
                }
            }
        } else {
            syncDao.putConflict(
                SyncConflictEntity(
                    conflictId = record.id,
                    commandId = commandId,
                    entityType = record.payload["entity_type"].asString,
                    entityId = record.payload["entity_id"].asString,
                    proposedDocumentJson = record.payload.get("proposed_document")
                        ?.takeUnless { it.isJsonNull }
                        ?.let(gson::toJson),
                    syncRevision = record.syncRevision.toLong(),
                ),
            )
            syncDao.outbox(commandId)?.let {
                syncDao.markOutbox(commandId, "conflict", System.currentTimeMillis(), "conflict")
            }
        }
    }

    private suspend fun installCanonicalCount(
        goalId: String,
        slotId: String,
        localDate: String,
        canonical: Long,
        incarnation: Long,
        revision: Long,
    ): ProgressSyncCountChange? {
        syncDao.putCountShadow(
            SyncCountShadowEntity(
                key = "$goalId:$slotId:$localDate:$incarnation",
                goalId = goalId,
                slotId = slotId,
                localDate = localDate,
                entityIncarnation = incarnation,
                canonicalCount = canonical,
                syncRevision = revision,
            ),
        )
        val pending = syncDao.pendingCountDelta(goalId, slotId, localDate, incarnation)
        val open = syncDao.openBatchAmount(goalId, slotId, localDate, incarnation)
        val visible = Math.addExact(canonical, Math.addExact(pending, open)).coerceAtLeast(0)
        val goalUuid = UUID.fromString(goalId)
        val slotUuid = UUID.fromString(slotId)
        val before = countEntryDao.getCountValueForSlot(goalUuid, slotUuid, localDate) ?: 0L
        countEntryDao.setCanonicalCount(goalUuid, slotUuid, localDate, visible, System.currentTimeMillis())
        val delta = visible - before
        goalDao.incrementTotalCount(goalUuid, delta, System.currentTimeMillis())
        return delta.takeIf { it != 0L }?.let {
            ProgressSyncCountChange(goalId = goalUuid, delta = it)
        }
    }

    private suspend fun installEntityShadow(effect: JsonObject, revision: Long, conflict: String?) {
        if (!effect.has("entity_type")) return
        val type = effect["entity_type"].asString
        val id = effect["entity_id"].asString
        syncDao.putShadow(
            SyncEntityShadowEntity(
                key = "$type:$id",
                entityType = type,
                entityId = id,
                version = effect["entity_version"].asString.toLong(),
                incarnation = effect["entity_incarnation"].asString.toLong(),
                syncRevision = revision,
                state = effect["state"].asString,
                documentJson = effect.get("document")?.takeUnless { it.isJsonNull }?.let(gson::toJson),
                conflictDocumentJson = conflict,
            ),
        )
    }

    private suspend fun applyCanonicalEntityEffect(effect: JsonObject) {
        if (!effect.has("entity_type")) return
        val type = effect["entity_type"].asString
        val id = UUID.fromString(effect["entity_id"].asString)
        val state = effect["state"].asString
        val document = effect.get("document")?.takeUnless { it.isJsonNull }?.asJsonObject
        if (state != "active" || document == null) {
            if (type == "goal") goalRepository.deleteRemoteGoal(id)
            if (type == "custom_dhikr") dhikrRepository.deleteRemoteDhikr(id)
            if (type == "user_tag") dhikrRepository.deleteRemoteUserTag(id)
            if (type == "dhikr_tag_assignment") dhikrRepository.deleteRemoteTagAssignment(id)
            return
        }
        when (type) {
            "goal" -> goalRepository.applyRemoteGoal(
                contractJson.decodeFromString<GoalV1>(gson.toJson(document)).toNativeGoal(),
            )
            "custom_dhikr" -> dhikrRepository.applyRemoteDhikr(
                contractJson.decodeFromString<DhikrV1>(gson.toJson(document)).toNativeDhikr(),
            )
            "user_tag" -> dhikrRepository.applyRemoteUserTag(
                contractJson.decodeFromString<UserTagV1>(gson.toJson(document)).toNativeUserTag(),
            )
            "dhikr_tag_assignment" -> {
                val assignment = contractJson.decodeFromString<DhikrTagAssignmentV1>(gson.toJson(document))
                dhikrRepository.applyRemoteTagAssignment(
                    id = UUID.fromString(assignment.id),
                    tagId = UUID.fromString(assignment.tagId),
                    dhikrId = UUID.fromString(assignment.dhikrId),
                    createdAt = java.time.Instant.parse(assignment.createdAt).toEpochMilli(),
                )
            }
        }
    }

    private suspend fun applyUserTagCoalesce(localTagId: UUID, effect: JsonObject) {
        val document = effect.get("document")?.takeUnless { it.isJsonNull }?.asJsonObject
            ?: throw IOException("Coalesced user_tag receipt missing document")
        val canonical = contractJson.decodeFromString<UserTagV1>(gson.toJson(document)).toNativeUserTag()
        dhikrRepository.coalesceUserTag(localTagId, canonical)
        val from = localTagId.toString()
        val to = canonical.id.toString()
        syncDao.pendingOutbox()
            .filter { it.entityType == "dhikr_tag_assignment" && it.payloadJson.contains(from) }
            .forEach { pending ->
                val rewritten = UserTagCoalesceRepoint.rewritePendingAssignmentPayload(
                    payloadJson = pending.payloadJson,
                    fromTagId = from,
                    toTagId = to,
                )
                if (rewritten != pending.payloadJson) {
                    syncDao.putOutbox(pending.copy(payloadJson = rewritten))
                }
            }
        syncDao.deleteEntityOutbox("user_tag", from)
        syncDao.deleteConflictsForEntity("user_tag", from)
    }

    private suspend fun installCanonicalCountEffect(effect: JsonObject, revision: Long) {
        if (!effect.has("count") || !effect.has("goal_id")) return
        installCanonicalCount(
            effect["goal_id"].asString,
            effect["slot_id"].asString,
            effect["local_date"].asString,
            effect["count"].asString.toLong(),
            effect.get("entity_incarnation")?.asString?.toLongOrNull() ?: 1L,
            revision,
        )
    }

    private suspend fun reinstallVisibleCount(outbox: app.awrad.awrad_dhikrgoalstracker.data.database.entity.SyncOutboxEntity, revision: Long) {
        val goalId = outbox.goalId ?: return
        val slotId = outbox.slotId ?: return
        val localDate = outbox.localDate ?: return
        if (goalDao.getGoalById(UUID.fromString(goalId)) == null) return
        val incarnation = syncDao.shadow("goal", goalId)?.incarnation
            ?: JsonParser.parseString(outbox.payloadJson).asJsonObject
                .get("entity_incarnation")?.asString?.toLongOrNull()
            ?: 1L
        val canonical = syncDao.countShadow(goalId, slotId, localDate, incarnation)?.canonicalCount ?: 0L
        installCanonicalCount(goalId, slotId, localDate, canonical, incarnation, revision)
    }

    private suspend fun reconcileGeneration(records: List<SyncTransferRecordDto>) {
        // The incoming snapshot is authoritative for unresolved server
        // conflicts; its conflict records are reinstalled below.
        syncDao.clearConflicts()
        val entityKeys = records.mapNotNull { record ->
            when (record.kind) {
                "custom_dhikr", "goal", "user_tag", "dhikr_tag_assignment" -> "${record.kind}:${record.id}"
                "tombstone", "deletion_fence" -> "${record.payload["entity_type"].asString}:${record.id}"
                else -> null
            }
        }.toSet()
        syncDao.shadows().filter { it.key !in entityKeys }.forEach { shadow ->
            if (syncDao.pendingEntityCommand(shadow.entityType, shadow.entityId) == null) {
                val id = UUID.fromString(shadow.entityId)
                if (shadow.entityType == "goal") goalRepository.deleteRemoteGoal(id)
                if (shadow.entityType == "custom_dhikr") dhikrRepository.deleteRemoteDhikr(id)
                if (shadow.entityType == "user_tag") dhikrRepository.deleteRemoteUserTag(id)
                if (shadow.entityType == "dhikr_tag_assignment") {
                    dhikrRepository.deleteRemoteTagAssignment(id)
                }
                syncDao.deleteShadow(shadow.key)
            }
        }

        val countKeys = records.filter { it.kind == "count_projection" }.map { record ->
            val payload = record.payload
            "${payload["goal_id"].asString}:${payload["slot_id"].asString}:${payload["local_date"].asString}:${payload["entity_incarnation"].asString}"
        }.toSet()
        syncDao.countShadows().filter { it.key !in countKeys }.forEach { shadow ->
            val pending = syncDao.pendingCountDelta(
                shadow.goalId,
                shadow.slotId,
                shadow.localDate,
                shadow.entityIncarnation,
            )
            val open = syncDao.openBatchAmount(
                shadow.goalId,
                shadow.slotId,
                shadow.localDate,
                shadow.entityIncarnation,
            )
            val visible = Math.addExact(pending, open).coerceAtLeast(0)
            val goalId = UUID.fromString(shadow.goalId)
            val slotId = UUID.fromString(shadow.slotId)
            val before = countEntryDao.getCountValueForSlot(goalId, slotId, shadow.localDate) ?: 0L
            countEntryDao.setCanonicalCount(goalId, slotId, shadow.localDate, visible, System.currentTimeMillis())
            goalDao.incrementTotalCount(goalId, visible - before, System.currentTimeMillis())
            syncDao.deleteCountShadow(shadow.key)
        }
    }

    private suspend fun rebaseNextEntityEdit(effect: JsonObject) {
        if (!effect.has("entity_type")) return
        val type = effect["entity_type"].asString
        val id = effect["entity_id"].asString
        val pending = syncDao.pendingEntityCommand(type, id) ?: return
        if (pending.type != "entity_upsert") return
        val payload = JsonParser.parseString(pending.payloadJson).asJsonObject
        payload.addProperty("base_version", effect["entity_version"].asString)
        payload.addProperty("entity_incarnation", effect["entity_incarnation"].asString)
        syncDao.putOutbox(pending.copy(payloadJson = gson.toJson(payload)))
    }

    private suspend fun safeRevision(appliedRevision: Long): Long {
        val pendingCorrections = syncDao.pendingOutbox().filter { it.type != "increment" && it.countDelta != null }
        val oldestBasis = pendingCorrections.mapNotNull { command ->
            JsonParser.parseString(command.payloadJson).asJsonObject.get("basis_revision")?.asString?.toLongOrNull()
        }.minOrNull()
        return minOf(appliedRevision, oldestBasis ?: appliedRevision)
    }

    private fun verifyPage(page: SyncTransferPageDto) {
        val actual = ProgressSyncPageIntegrity.checksum(page.records)
        if (actual != page.checksum) {
            throw IOException("Progress transfer page checksum mismatch: expected=${page.checksum}, actual=$actual")
        }
    }

    private fun validateHeader(header: app.awrad.awrad_dhikrgoalstracker.data.network.SyncHeaderDto) {
        if (header.protocolVersion != 1 || header.progressModelVersion != 1 ||
            "materialized_transfers" !in header.capabilities
        ) {
            throw IOException("Unsupported progress sync response header")
        }
    }

    private fun dependencyOrder(kind: String): Int = ProgressSyncDependencyOrder.order(kind)

    private fun SyncTransferRecordDto.affectsNotificationScheduling(): Boolean =
        kind == "goal" || kind == "count_projection" ||
            (kind in setOf("tombstone", "deletion_fence") &&
                payload.get("entity_type")?.asString == "goal")

    private data class InitialLocalState(
        val dhikrs: List<InitialEntity>,
        val goals: List<InitialEntity>,
        val counts: List<InitialCount>,
    )

    private data class InitialEntity(
        val commandId: String,
        val entityType: String,
        val entityId: String,
        val documentJson: String,
    )

    private data class InitialCount(
        val commandId: String,
        val goalId: String,
        val slotId: String,
        val localDate: String,
        val incarnation: Long,
        val amount: Long,
    )
}

internal object ProgressSyncReceiptIntegrity {
    fun isComplete(commandIds: List<String>, receiptIds: List<String>): Boolean {
        val expected = commandIds.toSet()
        val actual = receiptIds.toSet()
        return expected.size == commandIds.size && actual.size == receiptIds.size &&
            receiptIds.size == commandIds.size && actual == expected
    }
}

internal object ProgressSyncPurgeEffect {
    fun isFence(effect: JsonObject): Boolean =
        effect.get("kind")?.takeUnless { it.isJsonNull }?.asString == "deletion_fence" ||
            effect.get("state")?.takeUnless { it.isJsonNull }?.asString == "purged" ||
            effect.get("purged")?.takeUnless { it.isJsonNull }?.asBoolean == true
}

internal object ProgressSyncPageIntegrity {
    private val gson = Gson()

    fun checksum(records: JsonArray): String {
        return MessageDigest.getInstance("SHA-256")
            .digest(canonicalPayload(records).toByteArray(StandardCharsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }

    fun sessionChecksum(pageChecksums: List<String>, recordCount: Int): String =
        MessageDigest.getInstance("SHA-256")
            .digest((pageChecksums.joinToString("") + ":$recordCount").toByteArray(StandardCharsets.UTF_8))
            .joinToString("") { "%02x".format(it) }

    internal fun canonicalPayload(records: JsonArray): String =
        canonicalJson(JsonObject().apply { add("records", records.deepCopy()) })

    private fun canonicalJson(element: JsonElement): String = when {
        element is JsonNull -> "null"
        element.isJsonPrimitive -> gson.toJson(element)
        element.isJsonArray -> element.asJsonArray.joinToString(separator = ",", prefix = "[", postfix = "]") { canonicalJson(it) }
        element.isJsonObject -> element.asJsonObject.entrySet().sortedBy { it.key }
            .joinToString(separator = ",", prefix = "{", postfix = "}") { (key, value) -> "${gson.toJson(key)}:${canonicalJson(value)}" }
        else -> error("Unsupported JSON value")
    }
}

internal object ProgressSyncImportMath {
    fun legacyAmount(visibleLocalCount: Long, alreadyQueuedDelta: Long): Long =
        Math.subtractExact(visibleLocalCount, alreadyQueuedDelta).coerceAtLeast(0L)
}

internal object ProgressSyncConflictDelta {
    fun isResolved(payload: JsonObject): Boolean = payload.get("resolved")?.asBoolean ?: false
}
