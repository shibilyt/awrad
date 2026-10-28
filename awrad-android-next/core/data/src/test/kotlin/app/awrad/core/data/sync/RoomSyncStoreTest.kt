package app.awrad.core.data.sync

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import app.awrad.core.database.AwradDatabase
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.sync.ApplyChanges
import app.awrad.core.domain.sync.ConflictChoice
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.LocalEntity
import app.awrad.core.domain.sync.Outbox
import app.awrad.core.domain.sync.OutboxCommand
import app.awrad.core.domain.sync.SyncOp
import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner
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
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The Room tables behind the queue rules: every `apply_changes` and `outbox_enqueue` case runs through
 * [RoomSyncStore] in one transaction, unedited, so the DAOs keep documents, versions, queue order and conflicts
 * exactly as the in-memory runners do.
 */
@RunWith(RobolectricTestRunner::class)
class RoomSyncStoreTest {

    private val database = Room.inMemoryDatabaseBuilder(
        ApplicationProvider.getApplicationContext(),
        AwradDatabase::class.java,
    )
        .allowMainThreadQueries()
        .build()
    private val dao = database.syncDao()

    @After
    fun close() {
        database.close()
    }

    @Test
    fun `every apply_changes case passes through Room`() {
        val cases = FixtureRunner.cases(FixtureModel.SYNC, "apply_changes")
        val ran = FixtureRunner.run(cases) { given ->
            database.clearAllTables()
            database.runInTransaction<JsonObject> {
                val store = RoomSyncStore(dao) { 0L }
                load(store, given.getValue("local").jsonObject)
                val step = given.getValue("step").jsonObject
                val notices = when (step.getValue("kind").jsonPrimitive.content) {
                    "page" -> emptyList<app.awrad.core.domain.sync.SyncNotice>().also {
                        ApplyChanges.applyPage(store, step.getValue("page").jsonObject.toChangesPage())
                    }
                    "receipts" -> ApplyChanges.applyReceipts(
                        store,
                        step.getValue("receipts").jsonArray.map { it.jsonObject.toReceipt() },
                    )
                    else -> {
                        resolve(store, step.getValue("resolve").jsonObject)
                        emptyList()
                    }
                }
                buildJsonObject {
                    put("local", dump(store))
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
        assertEquals(cases.size, ran)
    }

    @Test
    fun `every outbox_enqueue case passes through Room`() {
        val cases = FixtureRunner.cases(FixtureModel.SYNC, "outbox_enqueue")
        FixtureRunner.run(cases) { given ->
            database.clearAllTables()
            database.runInTransaction<JsonObject> {
                val store = RoomSyncStore(dao) { 0L }
                store.replaceOutbox(given.getValue("outbox").jsonArray.map { it.jsonObject.toOutboxCommand() })
                val edit = given.getValue("edit").jsonObject
                val key = edit.entityKey()
                val known = given.getValue("known_versions").jsonArray.map { it.jsonObject }
                    .firstOrNull { it.entityKey() == key }?.getValue("version")?.jsonPrimitive?.long ?: 0L
                val document = edit.getValue("document").let { if (it is JsonNull) null else it.jsonObject }
                val localEdit = app.awrad.core.domain.sync.LocalEdit(
                    AwradId(edit.getValue("command_id").jsonPrimitive.content),
                    key,
                    checkNotNull(SyncOp.fromWire(edit.getValue("op").jsonPrimitive.content)),
                    document,
                )
                store.replaceOutbox(Outbox.enqueue(store.outbox(), known, localEdit))
                buildJsonObject { put("outbox", jsonArrayOf(store.outbox()) { it.toJson() }) }
            }
        }
    }

    @Test
    fun `replacing the queue keeps positions and only appends new commands at the end`() {
        database.runInTransaction {
            val store = RoomSyncStore(dao) { 0L }
            val a = command(1, sent = true)
            val b = command(2)
            val c = command(3)
            store.replaceOutbox(listOf(a, b, c))
            val positions = dao.outbox().associate { it.commandId to it.position }

            store.replaceOutbox(listOf(a, c.copy(baseVersion = 9), command(4)))

            val after = dao.outbox()
            assertEquals(listOf(a, c.copy(baseVersion = 9), command(4)), store.outbox())
            assertEquals(
                positions.getValue(c.commandId.value),
                after.first { it.commandId == c.commandId.value }.position,
            )
            assertTrue(after.last().position > positions.values.max())
        }
    }

    @Test
    fun `a custom dhikr that drops its recording frees the file`() {
        database.runInTransaction {
            val store = RoomSyncStore(dao) { 0L }
            val id = AwradId("0192f0d0-0000-7000-8000-000000000001")
            dao.upsertCustomDhikr(
                app.awrad.core.database.CustomDhikrEntity(
                    id.value,
                    1,
                    DOCUMENT_WITH_AUDIO.toString(),
                    "/files/a.mp3",
                    0,
                ),
            )

            store.putEntity(LocalEntity(EntityKey(EntityType.CUSTOM_DHIKR, id), 2, DOCUMENT_WITHOUT_AUDIO))

            assertEquals(null, dao.customDhikr(id.value)?.audioFile)
            assertEquals(listOf("/files/a.mp3"), store.orphanedAudio)
        }
    }

    private fun load(store: RoomSyncStore, local: JsonObject) {
        store.after = local.getValue("after").jsonPrimitive.long
        local.getValue("entities").jsonArray.forEach { store.putEntity(it.jsonObject.toLocalEntity()) }
        store.replaceOutbox(local.getValue("outbox").jsonArray.map { it.jsonObject.toOutboxCommand() })
        local.getValue("conflicts").jsonArray.forEach { store.putConflict(it.jsonObject.toConflict()) }
    }

    private fun dump(store: RoomSyncStore): JsonObject = buildJsonObject {
        put("after", store.after)
        val entities = EntityType.entries.flatMap { store.entities(it) }.sortedBy { it.key }
        put("entities", jsonArrayOf(entities) { it.toJson() })
        put("outbox", jsonArrayOf(store.outbox()) { it.toJson() })
        put("conflicts", jsonArrayOf(dao.conflicts().map { it.toConflict() }) { it.toJson() })
    }

    private fun resolve(store: RoomSyncStore, resolve: JsonObject) {
        val choice = ConflictChoice.entries.first { it.wire == resolve.getValue("choice").jsonPrimitive.content }
        val commandId = resolve.getValue(
            "command_id",
        ).let { if (it is JsonNull) null else AwradId(it.jsonPrimitive.content) }
        ApplyChanges.resolve(store, resolve.entityKey(), choice, commandId)
    }

    private fun command(n: Int, sent: Boolean = false) = OutboxCommand(
        commandId = AwradId("0192f0c0-0000-7000-8000-%012d".format(n)),
        key = EntityKey(EntityType.USER_TAG, AwradId("0192f0a0-0000-7000-8000-%012d".format(n))),
        op = SyncOp.DELETE,
        baseVersion = n.toLong(),
        document = null,
        sent = sent,
    )

    private companion object {
        val DOCUMENT_WITHOUT_AUDIO: JsonObject = kotlinx.serialization.json.Json.parseToJsonElement(
            """{"kind":"dhikr","arabic":"سُبْحَانَ ٱللَّهِ","title":{"en":"Subhanallah","ar":null,"ml":null},""" +
                """"transliteration":{"en":null,"ml":null},"translation":{"en":null,"ar":null,"ml":null},""" +
                """"audio":null,"references":[]}""",
        ).jsonObject
        val DOCUMENT_WITH_AUDIO: JsonObject = JsonObject(
            DOCUMENT_WITHOUT_AUDIO + ("audio" to JsonObject(mapOf("local_only" to JsonPrimitive(true)))),
        )
    }
}
