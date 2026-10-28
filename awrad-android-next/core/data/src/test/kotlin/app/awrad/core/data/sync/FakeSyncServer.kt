package app.awrad.core.data.sync

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.CustomDhikrValidity
import app.awrad.core.domain.personal.PersonalDocument
import app.awrad.core.domain.personal.TagName
import app.awrad.core.domain.personal.TagNameResult
import app.awrad.core.network.api.ApiFailure
import app.awrad.core.network.api.ApiResult
import app.awrad.core.network.api.Problem
import app.awrad.core.network.api.SyncAppliedReceipt
import app.awrad.core.network.api.SyncCascadedBody
import app.awrad.core.network.api.SyncChangeBody
import app.awrad.core.network.api.SyncChangesPage
import app.awrad.core.network.api.SyncCommandBatch
import app.awrad.core.network.api.SyncCommandBody
import app.awrad.core.network.api.SyncConflictReceipt
import app.awrad.core.network.api.SyncCurrentBody
import app.awrad.core.network.api.SyncDuplicateReceipt
import app.awrad.core.network.api.SyncFieldErrorBody
import app.awrad.core.network.api.SyncGoneReceipt
import app.awrad.core.network.api.SyncMergedReceipt
import app.awrad.core.network.api.SyncReceiptBatch
import app.awrad.core.network.api.SyncReceiptBody
import app.awrad.core.network.api.SyncRejectedReceipt
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * A small in-memory change-queue server for one account, following contracts/sync/v1/README.md's rules in their
 * order (receipt store, document, entity state, entity rules, apply with cascades) and the feed's paging. It's a
 * test double for the engine, not the server's spec: `sync_receipts` and `sync_changes_feed` are the server's.
 */
@Suppress("TooManyFunctions") // One function per rule, as the README lists them.
internal class FakeSyncServer(private val accountId: AwradId, var tagLimit: Int = 100) : SyncRemote {

    data class Entity(
        val type: String,
        val id: String,
        val version: Long,
        val state: String,
        val revision: Long,
        val document: JsonObject?,
    )

    val entities = linkedMapOf<Pair<String, String>, Entity>()
    private val aliases = mutableMapOf<String, String>()
    private val receipts = mutableMapOf<String, Pair<SyncCommandBody, SyncReceiptBody>>()
    var head = 0L
        private set

    /** Batches received, and pages asked for (`after`), in order. */
    val batches = mutableListOf<SyncCommandBatch>()
    val pageRequests = mutableListOf<Long>()

    /** Failures to answer with before handling requests normally. */
    val failures = ArrayDeque<ApiFailure>()

    /** When set, answers are lost after the server applied them (the client sees no connection). */
    var loseNextAnswer = false

    @Suppress("ReturnCount") // A failure, a lost answer, or the receipts.
    override suspend fun postCommands(accountId: AwradId, batch: SyncCommandBatch): ApiResult<SyncReceiptBatch> {
        failureFor(accountId)?.let { return it }
        batches += batch
        val answer = SyncReceiptBatch(batch.commands.map(::apply), head)
        if (loseNextAnswer) {
            loseNextAnswer = false
            return ApiResult.Failure(ApiFailure.NoConnection)
        }
        return ApiResult.Success(answer)
    }

    override suspend fun listChanges(accountId: AwradId, after: Long, limit: Int): ApiResult<SyncChangesPage> {
        failureFor(accountId)?.let { return it }
        pageRequests += after
        val newer = entities.values
            .filter { it.revision > after && (after > 0 || it.state == ACTIVE) }
            .sortedWith(compareBy({ it.revision }, { it.type }, { it.id }))
        val page = mutableListOf<Entity>()
        for (revision in newer.map { it.revision }.distinct()) {
            if (page.size >= limit) break
            page += newer.filter { it.revision == revision }
        }
        val hasMore = page.size < newer.size
        return ApiResult.Success(
            SyncChangesPage(
                changes = page.map { SyncChangeBody(it.type, it.id, it.state, it.version, it.revision, it.document) },
                nextAfter = if (hasMore) page.last().revision else head,
                hasMore = hasMore,
                headRevision = head,
            ),
        )
    }

    /** Another device's change, applied as the server would. */
    fun putFromElsewhere(type: String, id: AwradId, document: JsonObject) {
        val current = entities[type to id.value]
        write(type, id.value, (current?.version ?: 0) + 1, ACTIVE, ++head, document)
    }

    fun deleteFromElsewhere(type: String, id: AwradId) {
        val current = checkNotNull(entities[type to id.value])
        val revision = ++head
        write(type, id.value, current.version + 1, DELETED, revision, null)
        cascade(type, id.value, revision)
    }

    private fun failureFor(accountId: AwradId): ApiResult.Failure? {
        if (accountId != this.accountId) return ApiResult.Failure(problem(CONFLICT, "account_mismatch"))
        return failures.removeFirstOrNull()?.let { ApiResult.Failure(it) }
    }

    private fun apply(command: SyncCommandBody): SyncReceiptBody {
        receipts[command.commandId]?.let { (payload, outcome) ->
            return if (payload == command) {
                SyncDuplicateReceipt(command.commandId, "duplicate", outcome)
            } else {
                rejected(command, "command_id_reused", null)
            }
        }
        val outcome = decide(command)
        receipts[command.commandId] = command to outcome
        return outcome
    }

    /** The README's rules 2 to 4, in order; each can decide the receipt. */
    @Suppress("ReturnCount", "CyclomaticComplexMethod")
    private fun decide(command: SyncCommandBody): SyncReceiptBody {
        val key = command.entityType to command.entityId
        if (command.entityType == PERSONAL && command.op == "delete") {
            return rejected(command, "delete_not_allowed", null)
        }
        if (command.op == "put" && !isValid(command)) return rejected(command, "document_invalid", current(key))
        val existing = entities[key]
        if ((command.entityType == TAG && command.entityId in aliases) || existing?.state == DELETED) {
            return SyncGoneReceipt(command.commandId, "gone")
        }
        if (existing == null && (command.op != "put" || command.baseVersion != 0L)) {
            return rejected(command, "entity_not_found", null)
        }
        if (existing != null && command.baseVersion != existing.version) {
            return SyncConflictReceipt(command.commandId, "conflict", current(key)!!)
        }
        return entityRules(command, existing)
    }

    /** The README's rules 5 and 6: tag merges and names, limits, personal records, then apply with cascades. */
    @Suppress("ReturnCount", "CyclomaticComplexMethod")
    private fun entityRules(command: SyncCommandBody, existing: Entity?): SyncReceiptBody {
        var document = command.document
        if (command.entityType == TAG && command.op == "put") {
            val normalized = document!!.getValue("normalized_name").jsonPrimitive.content
            val same = activeTags().firstOrNull {
                it.document!!["normalized_name"]?.jsonPrimitive?.content == normalized && it.id != command.entityId
            }
            if (same != null && existing == null) {
                aliases[command.entityId] = same.id
                return SyncMergedReceipt(command.commandId, "merged", same.id, current(TAG to same.id)!!)
            }
            if (same != null) return rejected(command, "tag_name_taken", current(TAG to command.entityId))
            if (existing == null && activeTags().size >= tagLimit) return rejected(command, "tag_limit_reached", null)
        }
        if (command.entityType == PERSONAL && command.op == "put") {
            val tags = PersonalDocument.tagIds(document!!).map { aliases[it.value] ?: it.value }
            if (tags.any { (TAG to it) !in entities }) {
                return rejected(command, "tag_not_found", current(PERSONAL to command.entityId))
            }
            val kept = tags.filter { entities[TAG to it]?.state == ACTIVE }.distinct()
            document = PersonalDocument.of(kept.map(::AwradId))
        }
        val revision = ++head
        val version = (existing?.version ?: 0) + 1
        if (command.op == "delete") {
            write(command.entityType, command.entityId, version, DELETED, revision, null)
            cascade(command.entityType, command.entityId, revision)
        } else {
            write(command.entityType, command.entityId, version, ACTIVE, revision, document)
        }
        val cascades = command.op == "delete" && command.entityType in setOf(TAG, CUSTOM)
        val cascaded = entities.values
            .filter { it.revision == revision && !(it.type == command.entityType && it.id == command.entityId) }
            .sortedWith(compareBy({ it.type }, { it.id }))
            .map { SyncCascadedBody(it.type, it.id, it.state, it.version, it.revision) }
        return SyncAppliedReceipt(command.commandId, "applied", version, revision, cascaded.takeIf { cascades })
    }

    private fun cascade(type: String, id: String, revision: Long) {
        when (type) {
            CUSTOM -> entities[PERSONAL to id]?.takeIf { it.state == ACTIVE }?.let {
                write(PERSONAL, id, it.version + 1, DELETED, revision, null)
            }
            TAG -> entities.values.filter { it.type == PERSONAL && it.state == ACTIVE }.forEach { record ->
                val tags = PersonalDocument.tagIds(record.document!!)
                if (tags.any { it.value == id }) {
                    write(
                        PERSONAL,
                        record.id,
                        record.version + 1,
                        ACTIVE,
                        revision,
                        PersonalDocument.of(tags.filterNot { it.value == id }),
                    )
                }
            }
        }
    }

    private fun isValid(command: SyncCommandBody): Boolean {
        val document = command.document ?: return false
        return when (command.entityType) {
            CUSTOM -> CustomDhikrValidity.isValid(document)
            TAG -> (TagName.of(document["name"]?.jsonPrimitive?.content.orEmpty()) as? TagNameResult.Accepted)
                ?.name?.normalized == document["normalized_name"]?.jsonPrimitive?.content
            else -> true
        }
    }

    private fun activeTags() = entities.values.filter { it.type == TAG && it.state == ACTIVE }

    private fun current(key: Pair<String, String>): SyncCurrentBody? =
        entities[key]?.let { SyncCurrentBody(it.version, it.state, it.document) }

    private fun rejected(command: SyncCommandBody, code: String, current: SyncCurrentBody?) =
        SyncRejectedReceipt(command.commandId, "rejected", code, listOf<SyncFieldErrorBody>(), current)

    @Suppress("LongParameterList")
    private fun write(type: String, id: String, version: Long, state: String, revision: Long, document: JsonObject?) {
        entities[type to id] = Entity(type, id, version, state, revision, document)
    }

    companion object {
        const val CUSTOM = "custom_dhikr"
        const val TAG = "user_tag"
        const val PERSONAL = "dhikr_personal"
        const val ACTIVE = "active"
        const val DELETED = "deleted"
        const val CONFLICT = 409

        fun problem(status: Int, code: String, retryAfter: Long? = null) =
            ApiFailure.ProblemResponse(Problem(status = status, code = code), retryAfter)
    }
}
