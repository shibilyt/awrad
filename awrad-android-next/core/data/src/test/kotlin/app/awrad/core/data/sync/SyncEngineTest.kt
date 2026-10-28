package app.awrad.core.data.sync

import app.awrad.core.data.sync.FakeSyncServer.Companion.CUSTOM
import app.awrad.core.data.sync.FakeSyncServer.Companion.TAG
import app.awrad.core.data.sync.SyncStack.Companion.ACCOUNT
import app.awrad.core.data.sync.SyncStack.Companion.BUILT_IN
import app.awrad.core.data.sync.SyncStack.Companion.OTHER
import app.awrad.core.data.sync.SyncStack.Companion.dhikr
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.CustomDhikrJson
import app.awrad.core.domain.personal.OptionalTexts
import app.awrad.core.domain.personal.PersonalDocument
import app.awrad.core.domain.personal.TagOutcome
import app.awrad.core.domain.personal.UserTag
import app.awrad.core.domain.sync.ConflictChoice
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.RejectionCode
import app.awrad.core.domain.sync.SyncNotice
import app.awrad.core.domain.sync.SyncOp
import app.awrad.core.network.api.ApiFailure
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

/** The engine against a fake server: every receipt status, the merge rewrite, conflicts, paging and the guards. */
@RunWith(RobolectricTestRunner::class)
class SyncEngineTest {

    private val dhikrId = AwradId("0192f0d0-0000-7000-8000-000000000001")

    @Test
    fun `signed out, edits are queued for the account but nothing is sent or pulled`() = runTest {
        val stack = SyncStack(this, signedIn = null)
        stack.ownActiveProfile()
        stack.dhikrs.save(dhikr(dhikrId))

        assertEquals(SyncOutcome.Skipped, stack.engine.syncOnce())

        assertEquals(1, stack.outbox().size)
        assertTrue(stack.server.batches.isEmpty() && stack.server.pageRequests.isEmpty())
    }

    @Test
    fun `the anonymous profile queues nothing and never syncs, even signed in`() = runTest {
        val stack = SyncStack(this)
        stack.dhikrs.save(dhikr(dhikrId))

        assertEquals(SyncOutcome.Skipped, stack.engine.syncOnce())

        assertTrue(stack.outbox().isEmpty())
        assertTrue(stack.server.batches.isEmpty())
    }

    @Test
    fun `applied receipts record versions and the pull moves after to the head`() = runTest {
        val stack = SyncStack(this)
        stack.ownActiveProfile()
        stack.dhikrs.save(dhikr(dhikrId))
        val tag = (stack.tags.create("Morning") as TagOutcome.Saved).tag
        stack.tags.setTags(dhikrId, listOf(tag.id))

        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

        assertTrue(stack.outbox().isEmpty())
        assertEquals(3, stack.server.head)
        assertEquals(listOf(1L, 1L, 1L), stack.entities().map { it.knownVersion })
        assertEquals(3, stack.after())
        assertEquals(listOf(0L), stack.server.pageRequests)
    }

    @Test
    fun `a lost answer is resent and handled as the duplicate's original`() = runTest {
        val stack = SyncStack(this)
        stack.ownActiveProfile()
        stack.dhikrs.save(dhikr(dhikrId))
        stack.server.loseNextAnswer = true

        assertIs<SyncOutcome.Failed>(stack.engine.syncOnce())
        assertTrue(stack.outbox().single().sent)
        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

        assertEquals(stack.server.batches[0], stack.server.batches[1])
        assertTrue(stack.outbox().isEmpty())
        assertEquals(1L, stack.entities().single().knownVersion)
    }

    @Test
    fun `a conflict keeps the local edit until Keep mine or Use theirs`() = runTest {
        val stack = SyncStack(this)
        stack.ownActiveProfile()
        stack.dhikrs.save(dhikr(dhikrId))
        stack.engine.syncOnce()
        stack.server.putFromElsewhere(CUSTOM, dhikrId, CustomDhikrJson.encode(dhikr(dhikrId, "Theirs")))
        stack.dhikrs.save(dhikr(dhikrId, "Mine"))

        stack.engine.syncOnce()

        val conflict = stack.conflicts().single()
        assertEquals(SyncOp.PUT, conflict.localOp)
        assertEquals(2L, conflict.server.version)
        assertEquals(OptionalTexts(en = "Mine"), stack.dhikrs.dhikr(dhikrId).first()?.title)
        assertEquals(EntityKey(EntityType.CUSTOM_DHIKR, dhikrId), stack.sync.conflicts.first().single().key)

        stack.sync.resolve(EntityKey(EntityType.CUSTOM_DHIKR, dhikrId), ConflictChoice.KEEP_MINE)
        stack.engine.syncOnce()

        assertTrue(stack.conflicts().isEmpty())
        val server = stack.server.entities.getValue(CUSTOM to dhikrId.value)
        assertEquals(3L, server.version)
        assertEquals(CustomDhikrJson.encode(dhikr(dhikrId, "Mine")), server.document)
    }

    @Test
    fun `Use theirs takes the server's copy`() = runTest {
        val stack = SyncStack(this)
        stack.ownActiveProfile()
        stack.dhikrs.save(dhikr(dhikrId))
        stack.engine.syncOnce()
        stack.server.putFromElsewhere(CUSTOM, dhikrId, CustomDhikrJson.encode(dhikr(dhikrId, "Theirs")))
        stack.dhikrs.save(dhikr(dhikrId, "Mine"))
        stack.engine.syncOnce()

        stack.sync.resolve(EntityKey(EntityType.CUSTOM_DHIKR, dhikrId), ConflictChoice.USE_THEIRS)

        assertEquals(OptionalTexts(en = "Theirs"), stack.dhikrs.dhikr(dhikrId).first()?.title)
        assertTrue(stack.outbox().isEmpty() && stack.conflicts().isEmpty())
    }

    @Test
    fun `merged rewrites the tag ID in local records, and the server rewrites it in the same batch`() = runTest {
        val stack = SyncStack(this)
        stack.ownActiveProfile()
        val theirs = AwradId("0192f0a0-0000-7000-8000-000000000099")
        stack.server.putFromElsewhere(
            TAG,
            theirs,
            JsonObject(mapOf("name" to JsonPrimitive("Morning"), "normalized_name" to JsonPrimitive("morning"))),
        )
        val mine = (stack.tags.create("MORNING") as TagOutcome.Saved).tag
        stack.tags.setTags(BUILT_IN, listOf(mine.id))

        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

        assertEquals(listOf(UserTag(theirs, "Morning", "morning")), stack.tags.tags.first())
        assertEquals(mapOf(BUILT_IN to listOf(theirs)), stack.tags.tagsByDhikr.first())
        val record = stack.server.entities.getValue(FakeSyncServer.PERSONAL to BUILT_IN.value)
        assertEquals(PersonalDocument.of(listOf(theirs)), record.document)
    }

    @Test
    fun `gone removes an entity deleted elsewhere, with its personal record`() = runTest {
        val stack = SyncStack(this)
        stack.ownActiveProfile()
        stack.dhikrs.save(dhikr(dhikrId))
        stack.engine.syncOnce()
        stack.server.deleteFromElsewhere(CUSTOM, dhikrId)
        stack.dhikrs.save(dhikr(dhikrId, "Edited"))

        stack.engine.syncOnce()

        assertEquals(null, stack.dhikrs.dhikr(dhikrId).first())
        assertTrue(stack.entities().isEmpty() && stack.outbox().isEmpty())
    }

    @Test
    fun `rejected undoes the change and leaves a notice`() = runTest {
        val stack = SyncStack(this)
        stack.ownActiveProfile()
        stack.server.tagLimit = 0
        val tag = (stack.tags.create("Travel") as TagOutcome.Saved).tag

        stack.engine.syncOnce()

        assertTrue(stack.tags.tags.first().isEmpty())
        assertEquals(
            listOf(SyncNotice(RejectionCode.TAG_LIMIT_REACHED, EntityKey(EntityType.USER_TAG, tag.id))),
            stack.sync.notices.first(),
        )
    }

    @Test
    fun `a full download pages through whole revisions`() = runTest {
        val stack = SyncStack(this)
        stack.ownActiveProfile()
        repeat(450) { n ->
            stack.server.putFromElsewhere(
                CUSTOM,
                AwradId("0192f0d0-0000-7000-8000-%012d".format(n + 1)),
                CustomDhikrJson.encode(dhikr(dhikrId)),
            )
        }

        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

        assertEquals(listOf(0L, 200L, 400L), stack.server.pageRequests)
        assertEquals(450, stack.dhikrs.dhikrs.first().size)
        assertEquals(450, stack.after())
    }

    @Test
    fun `commands go in order in batches of up to 100`() = runTest {
        val stack = SyncStack(this)
        stack.ownActiveProfile()
        val ids = (1..150).map { AwradId("0192f0d0-0000-7000-8000-%012d".format(it)) }
        ids.forEach { stack.dhikrs.save(dhikr(it)) }

        stack.engine.syncOnce()

        assertEquals(listOf(100, 50), stack.server.batches.map { it.commands.size })
        assertEquals(ids.map { it.value }, stack.server.entities.values.map { it.id })
    }

    @Test
    fun `account_mismatch stops syncing that profile until the account or profile changes`() = runTest {
        val stack = SyncStack(this, signedIn = OTHER)
        stack.ownActiveProfile(OTHER)
        stack.tags.create("Morning")

        assertEquals(SyncOutcome.AccountMismatch, stack.engine.syncOnce())
        assertEquals(SyncOutcome.AccountMismatch, stack.engine.syncOnce())

        assertTrue(stack.server.batches.isEmpty())
        assertEquals(1, stack.outbox().size)
        assertEquals(EngineState.ACCOUNT_MISMATCH, stack.engine.state.value)
    }

    @Test
    fun `a signed-in account that doesn't own the active profile never sends its queue`() = runTest {
        val stack = SyncStack(this, signedIn = OTHER)
        stack.ownActiveProfile(ACCOUNT)
        stack.tags.create("Morning")

        assertEquals(SyncOutcome.Skipped, stack.engine.syncOnce())

        assertTrue(stack.server.batches.isEmpty())
    }

    @Test
    fun `server faults and rate limits fail the run for a retry`() = runTest {
        val stack = SyncStack(this)
        stack.ownActiveProfile()
        stack.tags.create("Morning")
        stack.server.failures += FakeSyncServer.problem(429, "rate_limited", retryAfter = 30)
        stack.server.failures += ApiFailure.NoConnection

        assertEquals(SyncOutcome.Failed(java.time.Duration.ofSeconds(30)), stack.engine.syncOnce())
        assertEquals(SyncOutcome.Failed(null), stack.engine.syncOnce())
        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())
        assertTrue(stack.outbox().isEmpty())
    }

    @Test
    fun `a record edited to name a later-created tag is sent after that tag`() = runTest {
        val stack = SyncStack(this)
        stack.ownActiveProfile()
        val morning = (stack.tags.create("Morning") as TagOutcome.Saved).tag
        stack.tags.setTags(BUILT_IN, listOf(morning.id))
        val travel = (stack.tags.create("Travel") as TagOutcome.Saved).tag
        // The record's never-sent put is replaced; it now names a tag whose create is queued after it.
        stack.tags.setTags(BUILT_IN, listOf(morning.id, travel.id))

        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

        val sent = stack.server.batches.flatMap { it.commands }.map { it.entityType to it.entityId }
        assertEquals(
            listOf(TAG to morning.id.value, TAG to travel.id.value, "dhikr_personal" to BUILT_IN.value),
            sent,
        )
        assertTrue(stack.sync.notices.first().isEmpty())
        assertTrue(stack.outbox().isEmpty())
        val record = stack.server.entities.getValue("dhikr_personal" to BUILT_IN.value)
        assertEquals(listOf(morning.id, travel.id), PersonalDocument.tagIds(checkNotNull(record.document)))
    }
}
