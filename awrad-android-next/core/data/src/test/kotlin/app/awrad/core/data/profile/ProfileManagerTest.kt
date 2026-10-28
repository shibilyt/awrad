@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package app.awrad.core.data.profile

import app.awrad.core.data.sync.SyncOutcome
import app.awrad.core.data.sync.SyncStack
import app.awrad.core.data.sync.SyncStack.Companion.ACCOUNT
import app.awrad.core.data.sync.SyncStack.Companion.BUILT_IN
import app.awrad.core.data.sync.SyncStack.Companion.OTHER
import app.awrad.core.data.sync.SyncStack.Companion.dhikr
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.SignOutReason
import app.awrad.core.domain.personal.TagOutcome
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.PendingProfilePrompt
import app.awrad.core.domain.sync.ProfileChoice
import app.awrad.core.domain.sync.ProfilePrompt
import app.awrad.core.domain.sync.SyncOp
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Local profiles end to end over in-memory Room: the `profile_switch` story, with real databases switching. */
@RunWith(RobolectricTestRunner::class)
class ProfileManagerTest {

    private val dhikrId = AwradId("0192f0d0-0000-7000-8000-000000000001")

    private suspend fun TestScope.started(): SyncStack {
        val stack = SyncStack(this, signedIn = null)
        backgroundScope.launch { stack.manager.run() }
        runCurrent()
        return stack
    }

    private suspend fun SyncStack.makeData() {
        dhikrs.save(dhikr(dhikrId))
        val tag = (tags.create("Morning") as TagOutcome.Saved).tag
        tags.setTags(BUILT_IN, listOf(tag.id))
    }

    @Test
    fun `first sign-in with anonymous data asks once, and Add to my account queues everything as puts`() = runTest {
        val stack = started()
        val anonymous = stack.databases.current().profileId
        stack.makeData()
        assertTrue(stack.outbox().isEmpty())

        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()
        assertEquals(PendingProfilePrompt.AnonymousData(ACCOUNT.email), stack.manager.prompt.value)
        stack.manager.answer(ProfileChoice.ADD_TO_ACCOUNT)
        runCurrent()

        assertNull(stack.manager.prompt.value)
        assertEquals(anonymous, stack.databases.current().profileId)
        assertEquals(ACCOUNT.id, stack.databases.current().accountId)
        val queued = stack.outbox()
        assertEquals(
            listOf(EntityType.USER_TAG, EntityType.CUSTOM_DHIKR, EntityType.DHIKR_PERSONAL),
            queued.map { it.key.type },
        )
        assertTrue(queued.all { it.op == SyncOp.PUT && it.baseVersion == 0L })
        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())
        assertEquals(3, stack.server.entities.size)
    }

    @Test
    fun `Erase replaces the anonymous profile with a fresh one for the account`() = runTest {
        val stack = started()
        val anonymous = stack.databases.current().profileId
        stack.makeData()

        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()
        stack.manager.answer(ProfileChoice.ERASE)
        runCurrent()

        val active = stack.databases.current()
        assertNotEquals(anonymous, active.profileId)
        assertEquals(ACCOUNT.id, active.accountId)
        assertTrue(stack.entities().isEmpty())
        assertEquals(listOf(anonymous), stack.profiles.storage.deleted)
    }

    @Test
    fun `an empty anonymous profile is adopted without a question`() = runTest {
        val stack = started()
        val anonymous = stack.databases.current().profileId

        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()

        assertNull(stack.manager.prompt.value)
        assertEquals(anonymous to ACCOUNT.id, stack.databases.current().let { it.profileId to it.accountId })
    }

    @Test
    fun `signing out keeps the profile, edits queue, and signing in again asks nothing`() = runTest {
        val stack = started()
        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()
        val profile = stack.databases.current().profileId

        stack.accounts.signOut()
        runCurrent()
        stack.dhikrs.save(dhikr(dhikrId))
        assertEquals(SyncOutcome.Skipped, stack.engine.syncOnce())
        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()

        assertNull(stack.manager.prompt.value)
        assertEquals(profile, stack.databases.current().profileId)
        assertEquals(1, stack.outbox().size)
        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())
        assertTrue(stack.outbox().isEmpty())
    }

    @Test
    fun `another account gets its own profile, and the first one's unsent edits wait for it`() = runTest {
        val stack = started()
        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()
        val amina = stack.databases.current().profileId
        stack.accounts.signOut()
        runCurrent()
        stack.dhikrs.save(dhikr(dhikrId))

        stack.accounts.updateAccount(OTHER)
        runCurrent()

        val bilal = stack.databases.current()
        assertNotEquals(amina, bilal.profileId)
        assertEquals(OTHER.id, bilal.accountId)
        assertTrue(stack.dhikrs.dhikrs.first().isEmpty())
        assertTrue(stack.outbox().isEmpty())

        stack.accounts.signOut()
        runCurrent()
        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()

        assertEquals(amina, stack.databases.current().profileId)
        assertEquals(listOf(dhikrId), stack.dhikrs.dhikrs.first().map { it.id })
        assertEquals(1, stack.outbox().size)
        val listed = stack.manager.profiles.first()
        assertEquals(listOf(true, false), listed.map { it.isActive })
        assertEquals(listOf(ACCOUNT.email, OTHER.email), listed.map { it.email })
    }

    @Test
    fun `removing a profile with unsent changes warns first`() = runTest {
        val stack = started()
        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()
        val amina = stack.databases.current().profileId
        stack.accounts.signOut()
        runCurrent()
        stack.dhikrs.save(dhikr(dhikrId))
        stack.accounts.updateAccount(OTHER)
        runCurrent()

        assertEquals(ProfilePrompt.UNSENT_CHANGES, stack.manager.removalPrompt(amina))
        stack.manager.remove(amina)
        runCurrent()

        assertEquals(listOf(amina), stack.profiles.storage.deleted)
        assertEquals(listOf(OTHER.email), stack.manager.profiles.first().map { it.email })
    }

    @Test
    fun `removing the active profile signs out and starts a fresh anonymous profile`() = runTest {
        val stack = started()
        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()
        val amina = stack.databases.current().profileId
        stack.dhikrs.save(dhikr(dhikrId))

        stack.manager.remove(amina)
        runCurrent()

        assertTrue(stack.accounts.calls.contains("sign_out"))
        val fresh = stack.databases.current()
        assertNotEquals(amina, fresh.profileId)
        assertNull(fresh.accountId)
        assertTrue(stack.dhikrs.dhikrs.first().isEmpty())
    }

    @Test
    fun `a deleted account offers to remove its profile`() = runTest {
        val stack = started()
        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()
        val amina = stack.databases.current().profileId

        stack.accounts.endSession(SignOutReason.ACCOUNT_DELETED, ACCOUNT.id)
        runCurrent()
        assertEquals(PendingProfilePrompt.AccountDeleted(amina, ACCOUNT.email), stack.manager.prompt.value)
        stack.manager.answer(ProfileChoice.REMOVE)
        runCurrent()

        assertEquals(listOf(amina), stack.profiles.storage.deleted)
        assertNull(stack.databases.current().accountId)
    }
}
