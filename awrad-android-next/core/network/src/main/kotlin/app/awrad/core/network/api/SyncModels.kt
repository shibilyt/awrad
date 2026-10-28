package app.awrad.core.network.api

import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.JsonContentPolymorphicSerializer
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/*
 * The change queue's wire shapes (contracts/api/paths/sync.yaml; contracts/sync/v1/sync.schema.json), written by
 * hand like the rest of the client (ADR 0005). Documents stay JSON objects: the client sends and stores them whole.
 * ApiContractTest round-trips every example of both operations through these classes.
 */

/** `post_sync_commands`' body: 1 to 100 commands, applied in order. */
@Serializable
public data class SyncCommandBatch(val commands: List<SyncCommandBody>)

/** One command. [document] is the whole new document on a put, and absent on a delete. */
@OptIn(ExperimentalSerializationApi::class)
@Serializable
public data class SyncCommandBody(
    @SerialName("command_id") val commandId: String,
    @SerialName("entity_type") val entityType: String,
    @SerialName("entity_id") val entityId: String,
    val op: String,
    @SerialName("base_version") val baseVersion: Long,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val document: JsonObject? = null,
)

/** `post_sync_commands`' answer: one receipt per command, in order. */
@Serializable
public data class SyncReceiptBatch(
    val receipts: List<SyncReceiptBody>,
    @SerialName("head_revision") val headRevision: Long,
)

/** The server's copy of an entity (`$defs/current`). [document] is null when it's deleted. */
@Serializable
public data class SyncCurrentBody(val version: Long, val state: String, val document: JsonObject?)

/** One problem with a command: a JSON Pointer into it and a code. */
@Serializable
public data class SyncFieldErrorBody(val field: String, val code: String)

/** A receipt, told apart by its `status` ([SyncReceiptSerializer]). */
@Serializable(with = SyncReceiptSerializer::class)
public sealed interface SyncReceiptBody {
    public val commandId: String
    public val status: String
}

/**
 * An entity a `user_tag` or `custom_dhikr` delete changed on the server at the same revision
 * (`$defs/cascaded_change`).
 */
@Serializable
public data class SyncCascadedBody(
    @SerialName("entity_type") val entityType: String,
    @SerialName("entity_id") val entityId: String,
    val state: String,
    val version: Long,
    val revision: Long,
)

/** Done. [cascaded] is a list for a `user_tag` or `custom_dhikr` delete, null for every other command. */
@Serializable
public data class SyncAppliedReceipt(
    @SerialName("command_id") override val commandId: String,
    override val status: String,
    val version: Long,
    val revision: Long,
    val cascaded: List<SyncCascadedBody>? = null,
) : SyncReceiptBody

@Serializable
public data class SyncDuplicateReceipt(
    @SerialName("command_id") override val commandId: String,
    override val status: String,
    val original: SyncReceiptBody,
) : SyncReceiptBody

@Serializable
public data class SyncConflictReceipt(
    @SerialName("command_id") override val commandId: String,
    override val status: String,
    val current: SyncCurrentBody,
) : SyncReceiptBody

@Serializable
public data class SyncMergedReceipt(
    @SerialName("command_id") override val commandId: String,
    override val status: String,
    @SerialName("merged_into") val mergedInto: String,
    val current: SyncCurrentBody,
) : SyncReceiptBody

@Serializable
public data class SyncGoneReceipt(
    @SerialName("command_id") override val commandId: String,
    override val status: String,
) : SyncReceiptBody

@Serializable
public data class SyncRejectedReceipt(
    @SerialName("command_id") override val commandId: String,
    override val status: String,
    val code: String,
    val fields: List<SyncFieldErrorBody>,
    val current: SyncCurrentBody?,
) : SyncReceiptBody

/** Picks a receipt's class by its `status`. An unknown status fails, like any response the app can't read. */
internal object SyncReceiptSerializer : JsonContentPolymorphicSerializer<SyncReceiptBody>(SyncReceiptBody::class) {
    override fun selectDeserializer(element: JsonElement): DeserializationStrategy<SyncReceiptBody> =
        when (val status = element.jsonObject["status"]?.jsonPrimitive?.content) {
            "applied" -> SyncAppliedReceipt.serializer()
            "duplicate" -> SyncDuplicateReceipt.serializer()
            "conflict" -> SyncConflictReceipt.serializer()
            "merged" -> SyncMergedReceipt.serializer()
            "gone" -> SyncGoneReceipt.serializer()
            "rejected" -> SyncRejectedReceipt.serializer()
            else -> throw SerializationException("Unknown receipt status $status")
        }
}

/** `list_sync_changes`' answer: one page of the changes feed. */
@Serializable
public data class SyncChangesPage(
    val changes: List<SyncChangeBody>,
    @SerialName("next_after") val nextAfter: Long,
    @SerialName("has_more") val hasMore: Boolean,
    @SerialName("head_revision") val headRevision: Long,
)

/** An entity's latest state. [document] is null for a delete. */
@Serializable
public data class SyncChangeBody(
    @SerialName("entity_type") val entityType: String,
    @SerialName("entity_id") val entityId: String,
    val state: String,
    val version: Long,
    val revision: Long,
    val document: JsonObject?,
)
