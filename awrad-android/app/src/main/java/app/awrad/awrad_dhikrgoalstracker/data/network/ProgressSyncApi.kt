package app.awrad.awrad_dhikrgoalstracker.data.network

import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.google.gson.annotations.SerializedName

data class SyncHeaderDto(
    @SerializedName("protocol_version") val protocolVersion: Int = 1,
    @SerializedName("progress_model_version") val progressModelVersion: Int = 1,
    val capabilities: List<String> = listOf(
        "count_ledger",
        "entity_occ",
        "materialized_transfers",
        "unchanged_delta",
    ),
)

data class SyncCommandBatchRequest(
    val header: SyncHeaderDto = SyncHeaderDto(),
    @SerializedName("installation_id") val installationId: String,
    val commands: List<JsonObject>,
)

data class SyncCommandBatchResponse(
    val header: SyncHeaderDto,
    val receipts: List<SyncReceiptDto>,
)

data class SyncReceiptDto(
    @SerializedName("command_id") val commandId: String,
    val status: String,
    @SerializedName("result_revision") val resultRevision: String,
    @SerializedName("canonical_effect") val canonicalEffect: JsonObject,
)

data class SyncTransferRequest(
    val header: SyncHeaderDto = SyncHeaderDto(),
    val kind: String,
    val cursor: String?,
)

data class SyncTransferSessionDto(
    val header: SyncHeaderDto,
    val status: String? = null,
    @SerializedName("transfer_id") val transferId: String? = null,
    val kind: String,
    @SerializedName("through_revision") val throughRevision: String,
    val generation: String,
    val cursor: String,
    @SerializedName("page_count") val pageCount: Int? = null,
    @SerializedName("record_count") val recordCount: Int? = null,
    val checksum: String? = null,
    @SerializedName("expires_at") val expiresAt: String? = null,
)

data class SyncTransferPageDto(
    val header: SyncHeaderDto,
    @SerializedName("transfer_id") val transferId: String,
    val page: Int,
    val checksum: String,
    // Keep the records as the raw JSON tree until the page checksum has been
    // verified. Re-encoding typed DTOs can change the JSON representation and
    // must never be part of an integrity decision.
    val records: JsonArray,
)

data class SyncTransferRecordDto(
    val kind: String,
    val id: String,
    @SerializedName("sync_revision") val syncRevision: String,
    val payload: JsonObject,
)

data class SyncActorAckRequest(
    val header: SyncHeaderDto = SyncHeaderDto(),
    @SerializedName("actor_id") val actorId: String,
    @SerializedName("installation_id") val installationId: String,
    @SerializedName("starting_sequence") val startingSequence: String,
    @SerializedName("applied_revision") val appliedRevision: String,
    @SerializedName("safe_compaction_revision") val safeCompactionRevision: String,
)

data class SyncActorAckResponse(
    val header: SyncHeaderDto,
    @SerializedName("actor_id") val actorId: String,
    @SerializedName("applied_revision") val appliedRevision: String,
    @SerializedName("safe_compaction_revision") val safeCompactionRevision: String,
)
