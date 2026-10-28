package app.awrad.core.domain.sync

import app.awrad.core.domain.AwradId
import app.awrad.core.testing.InMemorySyncStore
import app.awrad.core.testing.fixtures.entityKey
import app.awrad.core.testing.fixtures.jsonArrayOf
import app.awrad.core.testing.fixtures.toChangesPage
import app.awrad.core.testing.fixtures.toConflict
import app.awrad.core.testing.fixtures.toJson
import app.awrad.core.testing.fixtures.toLocalEntity
import app.awrad.core.testing.fixtures.toOutboxCommand
import app.awrad.core.testing.fixtures.toReceipt
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlin.test.Test

class OutboxEnqueueFixtureTest {

    @Test
    fun `every outbox_enqueue fixture case passes`() {
        runSyncFixture("outbox_enqueue") { given ->
            val known = given.getValue("known_versions").jsonArray.associate { element ->
                val entry = element.jsonObject
                entry.entityKey() to entry.getValue("version").jsonPrimitive.long
            }
            val edit = given.getValue("edit").jsonObject.let { json ->
                LocalEdit(
                    commandId = AwradId(json.getValue("command_id").jsonPrimitive.content),
                    key = json.entityKey(),
                    op = checkNotNull(SyncOp.fromWire(json.getValue("op").jsonPrimitive.content)),
                    document = json.getValue("document").let { if (it is JsonNull) null else it.jsonObject },
                )
            }
            val outbox = given.getValue("outbox").jsonArray.map { it.jsonObject.toOutboxCommand() }
            val queued = Outbox.enqueue(outbox, known[edit.key] ?: 0L, edit)
            buildJsonObject { put("outbox", jsonArrayOf(queued) { it.toJson() }) }
        }
    }
}

class ApplyChangesFixtureTest {

    @Test
    fun `every apply_changes fixture case passes`() {
        runSyncFixture("apply_changes") { given ->
            val local = given.getValue("local").jsonObject
            val store = InMemorySyncStore(
                after = local.getValue("after").jsonPrimitive.long,
                entities = local.getValue("entities").jsonArray.map { it.jsonObject.toLocalEntity() },
                outbox = local.getValue("outbox").jsonArray.map { it.jsonObject.toOutboxCommand() },
                conflicts = local.getValue("conflicts").jsonArray.map { it.jsonObject.toConflict() },
            )
            val step = given.getValue("step").jsonObject
            val notices = when (val kind = step.getValue("kind").jsonPrimitive.content) {
                "page" -> {
                    ApplyChanges.applyPage(store, step.getValue("page").jsonObject.toChangesPage())
                    emptyList()
                }
                "receipts" -> ApplyChanges.applyReceipts(
                    store,
                    step.getValue("receipts").jsonArray.map { it.jsonObject.toReceipt() },
                )
                "resolve" -> {
                    resolve(store, step.getValue("resolve").jsonObject)
                    emptyList()
                }
                else -> error("Unknown step $kind")
            }
            buildJsonObject {
                put("local", store.toJson())
                putJsonArray("notices") {
                    notices.forEach { notice ->
                        addJsonObject {
                            put("code", notice.code.wire)
                            put("entity_type", notice.key.type.wire)
                            put("entity_id", notice.key.id.value)
                        }
                    }
                }
            }
        }
    }

    private fun resolve(store: SyncStore, resolve: JsonObject) {
        val choice = ConflictChoice.entries.first { it.wire == resolve.getValue("choice").jsonPrimitive.content }
        val commandId = resolve.getValue(
            "command_id",
        ).let { if (it is JsonNull) null else AwradId(it.jsonPrimitive.content) }
        ApplyChanges.resolve(store, resolve.entityKey(), choice, commandId)
    }

    private fun InMemorySyncStore.toJson(): JsonObject = buildJsonObject {
        put("after", after)
        put("entities", jsonArrayOf(allEntities) { it.toJson() })
        put("outbox", jsonArrayOf(outbox()) { it.toJson() })
        put("conflicts", jsonArrayOf(allConflicts) { it.toJson() })
    }
}
