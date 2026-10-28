package app.awrad.core.testing.fixtures

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.sync.Change
import app.awrad.core.domain.sync.ChangesPage
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityState
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.FieldError
import app.awrad.core.domain.sync.FieldErrorCode
import app.awrad.core.domain.sync.LocalEntity
import app.awrad.core.domain.sync.OutboxCommand
import app.awrad.core.domain.sync.Receipt
import app.awrad.core.domain.sync.RejectionCode
import app.awrad.core.domain.sync.ServerCopy
import app.awrad.core.domain.sync.SyncConflict
import app.awrad.core.domain.sync.SyncOp
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put

/*
 * The sync fixtures' shapes (contracts/sync/v1/fixtures) to and from the domain's sync types. Decoding is strict:
 * an unknown entity type, op or state fails the case rather than being skipped.
 */

private fun JsonObject.number(member: String): Long = getValue(member).jsonPrimitive.long

internal fun JsonObject.id(member: String): AwradId = AwradId(string(member))

/** The document member: an object, or null for JSON null. */
internal fun JsonObject.document(member: String = "document"): JsonObject? =
    getValue(member).let { if (it is JsonNull) null else it.jsonObject }

public fun JsonObject.entityKey(): EntityKey =
    EntityKey(checkNotNull(EntityType.fromWire(string("entity_type"))) { "entity_type" }, id("entity_id"))

public fun JsonObject.toLocalEntity(): LocalEntity =
    LocalEntity(entityKey(), number("known_version"), checkNotNull(document()) { "entity document" })

public fun JsonObject.toOutboxCommand(): OutboxCommand = OutboxCommand(
    commandId = id("command_id"),
    key = entityKey(),
    op = checkNotNull(SyncOp.fromWire(string("op"))) { "op" },
    baseVersion = number("base_version"),
    document = document(),
    sent = getValue("sent").jsonPrimitive.content.toBooleanStrict(),
)

public fun JsonObject.toServerCopy(): ServerCopy = ServerCopy(
    version = number("version"),
    state = checkNotNull(EntityState.fromWire(string("state"))) { "state" },
    document = document(),
)

public fun JsonObject.toConflict(): SyncConflict = SyncConflict(
    key = entityKey(),
    localOp = checkNotNull(SyncOp.fromWire(string("local_op"))) { "local_op" },
    server = getValue("server").jsonObject.toServerCopy(),
)

public fun JsonObject.toChangesPage(): ChangesPage = ChangesPage(
    changes = getValue("changes").jsonArray.map { element ->
        val change = element.jsonObject
        Change(
            key = change.entityKey(),
            state = checkNotNull(EntityState.fromWire(change.string("state"))) { "state" },
            version = change.number("version"),
            revision = change.number("revision"),
            document = change.document(),
        )
    },
    nextAfter = number("next_after"),
    hasMore = getValue("has_more").jsonPrimitive.content.toBooleanStrict(),
    headRevision = number("head_revision"),
)

public fun JsonObject.toReceipt(): Receipt {
    val commandId = id("command_id")
    return when (val status = string("status")) {
        "applied" -> Receipt.Applied(commandId, number("version"), number("revision"))
        "duplicate" -> Receipt.Duplicate(commandId, getValue("original").jsonObject.toReceipt())
        "conflict" -> Receipt.Conflict(commandId, getValue("current").jsonObject.toServerCopy())
        "merged" -> Receipt.Merged(commandId, id("merged_into"), getValue("current").jsonObject.toServerCopy())
        "gone" -> Receipt.Gone(commandId)
        "rejected" -> Receipt.Rejected(
            commandId = commandId,
            code = RejectionCode.fromWire(string("code")),
            fields = getValue("fields").jsonArray.map {
                FieldError(it.jsonObject.string("field"), FieldErrorCode.fromWire(it.jsonObject.string("code")))
            },
            current = getValue("current").let { if (it is JsonNull) null else it.jsonObject.toServerCopy() },
        )
        else -> error("Unknown receipt status $status")
    }
}

internal fun EntityKey.encodeInto(builder: kotlinx.serialization.json.JsonObjectBuilder) {
    builder.put("entity_type", type.wire)
    builder.put("entity_id", id.value)
}

public fun LocalEntity.toJson(): JsonObject = buildJsonObject {
    key.encodeInto(this)
    put("known_version", knownVersion)
    put("document", document)
}

public fun OutboxCommand.toJson(): JsonObject = buildJsonObject {
    put("command_id", commandId.value)
    key.encodeInto(this)
    put("op", op.wire)
    put("base_version", baseVersion)
    put("document", document ?: JsonNull)
    put("sent", sent)
}

public fun ServerCopy.toJson(): JsonObject = buildJsonObject {
    put("version", version)
    put("state", state.wire)
    put("document", document ?: JsonNull)
}

public fun SyncConflict.toJson(): JsonObject = buildJsonObject {
    key.encodeInto(this)
    put("local_op", localOp.wire)
    put("server", server.toJson())
}

/** A JSON array of [items], each encoded by [encode]. */
public fun <T> jsonArrayOf(items: List<T>, encode: (T) -> JsonElement): JsonArray =
    buildJsonArray { items.forEach { add(encode(it)) } }
