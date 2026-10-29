package app.awrad.core.data.sync

import app.awrad.core.database.AudioUploadEntity
import app.awrad.core.database.ConflictEntity
import app.awrad.core.database.CustomDhikrEntity
import app.awrad.core.database.DhikrPersonalEntity
import app.awrad.core.database.OutboxEntity
import app.awrad.core.database.SyncDao
import app.awrad.core.database.SyncMetaEntity
import app.awrad.core.database.UserTagEntity
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.uploadedAssetOf
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityState
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.LocalEntity
import app.awrad.core.domain.sync.OutboxCommand
import app.awrad.core.domain.sync.ServerCopy
import app.awrad.core.domain.sync.SyncConflict
import app.awrad.core.domain.sync.SyncOp
import app.awrad.core.domain.sync.SyncStore
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File

/**
 * The queue rules' [SyncStore] over one profile's Room tables. Use it only inside a `runInTransaction`: every call
 * is a blocking query. A custom dhikr whose document drops its recording, or names another uploaded one, loses its
 * local file (and any upload of it); the files to delete afterwards are in [orphanedAudio]. Re-queued uploads take
 * asset IDs from [newAssetId].
 */
internal class RoomSyncStore(
    private val dao: SyncDao,
    private val newAssetId: () -> AwradId = { AwradId.random() },
    private val now: () -> Long,
) : SyncStore {

    /** Recordings no custom dhikr uses any more, to delete once the transaction has committed. */
    val orphanedAudio: MutableList<String> = mutableListOf()

    override var after: Long
        get() = dao.meta()?.after ?: 0L
        set(value) {
            dao.upsertMeta(SyncMetaEntity(after = value, lastSyncedAt = dao.meta()?.lastSyncedAt))
        }

    override fun entity(key: EntityKey): LocalEntity? = when (key.type) {
        EntityType.CUSTOM_DHIKR -> dao.customDhikr(key.id.value)?.toLocal()
        EntityType.USER_TAG -> dao.userTag(key.id.value)?.toLocal()
        EntityType.DHIKR_PERSONAL -> dao.personal(key.id.value)?.toLocal()
    }

    override fun entities(type: EntityType): List<LocalEntity> = when (type) {
        EntityType.CUSTOM_DHIKR -> dao.customDhikrs().map { it.toLocal() }
        EntityType.USER_TAG -> dao.userTags().map { it.toLocal() }
        EntityType.DHIKR_PERSONAL -> dao.personals().map { it.toLocal() }
    }.sortedBy { it.key }

    override fun putEntity(entity: LocalEntity) {
        val id = entity.key.id.value
        when (entity.key.type) {
            EntityType.CUSTOM_DHIKR -> {
                val existing = dao.customDhikr(id)
                val keepsFile = existing != null && keepsRecording(parseDocument(existing.document), entity.document)
                val audioFile = existing?.audioFile?.takeIf { keepsFile }
                if (!keepsFile) {
                    existing?.audioFile?.let(orphanedAudio::add)
                    dao.deleteUploadsFor(id)
                }
                dao.upsertCustomDhikr(
                    CustomDhikrEntity(
                        id = id,
                        knownVersion = entity.knownVersion,
                        document = entity.document.toString(),
                        audioFile = audioFile,
                        createdAt = existing?.createdAt ?: now(),
                    ),
                )
            }
            EntityType.USER_TAG -> dao.upsertUserTag(
                UserTagEntity(
                    id = id,
                    knownVersion = entity.knownVersion,
                    name = entity.document.getValue("name").jsonPrimitive.content,
                    normalizedName = entity.document.getValue("normalized_name").jsonPrimitive.content,
                ),
            )
            EntityType.DHIKR_PERSONAL -> dao.upsertPersonal(
                DhikrPersonalEntity(id, entity.knownVersion, entity.document.getValue("tag_ids").jsonArray.toString()),
            )
        }
    }

    override fun removeEntity(key: EntityKey) {
        val id = key.id.value
        when (key.type) {
            EntityType.CUSTOM_DHIKR -> {
                dao.customDhikr(id)?.audioFile?.let(orphanedAudio::add)
                dao.deleteCustomDhikr(id)
                dao.deleteUploadsFor(id)
            }
            EntityType.USER_TAG -> dao.deleteUserTag(id)
            EntityType.DHIKR_PERSONAL -> dao.deletePersonal(id)
        }
    }

    override fun outbox(): List<OutboxCommand> = dao.outbox().map { it.toCommand() }

    /**
     * Writes only what changed: removed commands go, changed ones are updated where they stand, and new ones are
     * added after the last position, in order. When the queue rules moved a command (a replacement that names a
     * later put), the whole queue is written again in its new order.
     */
    override fun replaceOutbox(commands: List<OutboxCommand>) {
        val stored = dao.outbox()
        val storedById = stored.associateBy { it.commandId }
        val keptIds = commands.map { it.commandId.value }.toSet()
        stored.filterNot { it.commandId in keptIds }.forEach { dao.deleteCommand(it.commandId) }
        var next = (stored.maxOfOrNull { it.position } ?: -1) + 1
        val keptPositions = commands.mapNotNull { storedById[it.commandId.value]?.position }
        val lastKept = commands.indexOfLast { it.commandId.value in storedById }
        val insertsBetween = commands.take(lastKept.coerceAtLeast(0)).any { it.commandId.value !in storedById }
        if (insertsBetween || keptPositions.zipWithNext().any { (before, after) -> before > after }) {
            // A replaced command moved after a put it names, or a new one goes ahead of queued ones (an audio
            // rejection's re-queued put): renumber the queue, past every position in use.
            commands.forEach { dao.upsertCommand(it.toEntity(next++)) }
            return
        }
        commands.forEach { command ->
            val existing = storedById[command.commandId.value]
            if (existing == null) {
                dao.insertCommand(command.toEntity(next++))
            } else if (existing.toCommand() != command) {
                dao.upsertCommand(command.toEntity(existing.position))
            }
        }
    }

    override fun conflict(key: EntityKey): SyncConflict? =
        dao.conflict(key.type.wire, key.id.value)?.toConflict()

    override fun putConflict(conflict: SyncConflict) {
        dao.upsertConflict(
            ConflictEntity(
                entityType = conflict.key.type.wire,
                entityId = conflict.key.id.value,
                localOp = conflict.localOp.wire,
                serverVersion = conflict.server.version,
                serverState = conflict.server.state.wire,
                serverDocument = conflict.server.document?.toString(),
            ),
        )
    }

    override fun removeConflict(key: EntityKey) {
        dao.deleteConflict(key.type.wire, key.id.value)
    }

    override fun hasAudioFile(dhikrId: AwradId): Boolean =
        dao.customDhikr(dhikrId.value)?.audioFile?.let { File(it).isFile } == true

    override fun queueUpload(dhikrId: AwradId) {
        val file = dao.customDhikr(dhikrId.value)?.audioFile ?: return
        dao.insertUpload(
            AudioUploadEntity(
                assetId = newAssetId().value,
                dhikrId = dhikrId.value,
                audioFile = file,
                state = AudioUploadEntity.QUEUED,
                createdAt = now(),
            ),
        )
    }

    private companion object {
        /**
         * Whether a custom dhikr's local file is still its recording after its document goes from [old] to [new]:
         * it has a recording, and not another uploaded one. The upload confirming this phone's own recording
         * writes its row directly (`AudioUploader`), so an asset arriving here in place of a local recording or
         * another asset is another device's recording.
         */
        fun keepsRecording(old: JsonObject, new: JsonObject): Boolean {
            if (new["audio"] !is JsonObject) return false
            val asset = uploadedAssetOf(new)
            return asset == null || asset == uploadedAssetOf(old)
        }
    }
}

internal fun parseDocument(text: String): JsonObject = Json.parseToJsonElement(text).jsonObject

internal fun CustomDhikrEntity.toLocal() =
    LocalEntity(EntityKey(EntityType.CUSTOM_DHIKR, AwradId(id)), knownVersion, parseDocument(document))

internal fun UserTagEntity.toLocal() = LocalEntity(
    EntityKey(EntityType.USER_TAG, AwradId(id)),
    knownVersion,
    JsonObject(mapOf("name" to JsonPrimitive(name), "normalized_name" to JsonPrimitive(normalizedName))),
)

internal fun DhikrPersonalEntity.toLocal() = LocalEntity(
    EntityKey(EntityType.DHIKR_PERSONAL, AwradId(dhikrId)),
    knownVersion,
    JsonObject(mapOf("tag_ids" to Json.parseToJsonElement(tagIds) as JsonArray)),
)

internal fun OutboxEntity.toCommand() = OutboxCommand(
    commandId = AwradId(commandId),
    key = EntityKey(checkNotNull(EntityType.fromWire(entityType)), AwradId(entityId)),
    op = checkNotNull(SyncOp.fromWire(op)),
    baseVersion = baseVersion,
    document = document?.let(::parseDocument),
    sent = sent,
)

internal fun OutboxCommand.toEntity(position: Long) = OutboxEntity(
    commandId = commandId.value,
    position = position,
    entityType = key.type.wire,
    entityId = key.id.value,
    op = op.wire,
    baseVersion = baseVersion,
    document = document?.toString(),
    sent = sent,
)

internal fun ConflictEntity.toConflict() = SyncConflict(
    key = EntityKey(checkNotNull(EntityType.fromWire(entityType)), AwradId(entityId)),
    localOp = checkNotNull(SyncOp.fromWire(localOp)),
    server = ServerCopy(
        version = serverVersion,
        state = checkNotNull(EntityState.fromWire(serverState)),
        document = serverDocument?.let { Json.parseToJsonElement(it) }?.takeUnless { it is JsonNull }?.jsonObject,
    ),
)
