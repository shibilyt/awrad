package app.awrad.core.data.sync

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.sync.Change
import app.awrad.core.domain.sync.ChangesPage
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityState
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.FieldError
import app.awrad.core.domain.sync.FieldErrorCode
import app.awrad.core.domain.sync.OutboxCommand
import app.awrad.core.domain.sync.Receipt
import app.awrad.core.domain.sync.RejectionCode
import app.awrad.core.domain.sync.ServerCopy
import app.awrad.core.network.api.ApiResult
import app.awrad.core.network.api.SyncApi
import app.awrad.core.network.api.SyncAppliedReceipt
import app.awrad.core.network.api.SyncChangesPage
import app.awrad.core.network.api.SyncCommandBatch
import app.awrad.core.network.api.SyncCommandBody
import app.awrad.core.network.api.SyncConflictReceipt
import app.awrad.core.network.api.SyncCurrentBody
import app.awrad.core.network.api.SyncDuplicateReceipt
import app.awrad.core.network.api.SyncGoneReceipt
import app.awrad.core.network.api.SyncMergedReceipt
import app.awrad.core.network.api.SyncReceiptBatch
import app.awrad.core.network.api.SyncReceiptBody
import app.awrad.core.network.api.SyncRejectedReceipt
import app.awrad.core.network.session.DeviceSessionManager
import javax.inject.Inject

/**
 * The server side of the change queue, for one account. The app's is [NetworkSyncRemote]; the engine's tests use
 * a fake server.
 */
internal interface SyncRemote {
    suspend fun postCommands(accountId: AwradId, batch: SyncCommandBatch): ApiResult<SyncReceiptBatch>

    suspend fun listChanges(accountId: AwradId, after: Long, limit: Int): ApiResult<SyncChangesPage>
}

/** [SyncRemote] over the API with this device's session (refreshing the access token as needed). */
internal class NetworkSyncRemote @Inject constructor(
    private val api: SyncApi,
    private val sessions: DeviceSessionManager,
) : SyncRemote {
    override suspend fun postCommands(accountId: AwradId, batch: SyncCommandBatch): ApiResult<SyncReceiptBatch> =
        sessions.authorized { token -> api.postCommands(token, accountId.value, batch) }

    override suspend fun listChanges(accountId: AwradId, after: Long, limit: Int): ApiResult<SyncChangesPage> =
        sessions.authorized { token -> api.listChanges(token, accountId.value, after, limit) }
}

/** The wire command for [command]: a put carries its document, a delete none. */
internal fun OutboxCommand.toWire() = SyncCommandBody(
    commandId = commandId.value,
    entityType = key.type.wire,
    entityId = key.id.value,
    op = op.wire,
    baseVersion = baseVersion,
    document = document,
)

/** The domain receipt for [this], or null when it names something this app can't read. */
internal fun SyncReceiptBody.toDomain(): Receipt? {
    val commandId = AwradId.parse(commandId) ?: return null
    return when (this) {
        is SyncAppliedReceipt -> Receipt.Applied(commandId, version, revision)
        is SyncDuplicateReceipt -> original.toDomain()?.let { Receipt.Duplicate(commandId, it) }
        is SyncConflictReceipt -> current.toDomain()?.let { Receipt.Conflict(commandId, it) }
        is SyncMergedReceipt -> AwradId.parse(mergedInto)?.let { survivor ->
            current.toDomain()?.let { Receipt.Merged(commandId, survivor, it) }
        }
        is SyncGoneReceipt -> Receipt.Gone(commandId)
        is SyncRejectedReceipt -> Receipt.Rejected(
            commandId = commandId,
            code = RejectionCode.fromWire(code),
            fields = fields.map { FieldError(it.field, FieldErrorCode.fromWire(it.code)) },
            current = current?.toDomain(),
        )
    }
}

private fun SyncCurrentBody.toDomain(): ServerCopy? =
    EntityState.fromWire(state)?.let { ServerCopy(version, it, document) }

/** The domain page; changes of an entity type this app doesn't know are skipped. */
internal fun SyncChangesPage.toDomain() = ChangesPage(
    changes = changes.mapNotNull { change ->
        val type = EntityType.fromWire(change.entityType) ?: return@mapNotNull null
        val id = AwradId.parse(change.entityId) ?: return@mapNotNull null
        val state = EntityState.fromWire(change.state) ?: return@mapNotNull null
        Change(EntityKey(type, id), state, change.version, change.revision, change.document)
    },
    nextAfter = nextAfter,
    hasMore = hasMore,
    headRevision = headRevision,
)
