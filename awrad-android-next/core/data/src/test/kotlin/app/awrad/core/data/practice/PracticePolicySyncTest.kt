@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package app.awrad.core.data.practice

import app.awrad.core.data.sync.FakeSyncServer
import app.awrad.core.data.sync.SyncOutcome
import app.awrad.core.data.sync.SyncStack
import app.awrad.core.data.sync.SyncStack.Companion.ACCOUNT
import app.awrad.core.domain.practice.CalculationMethod
import app.awrad.core.domain.practice.DayReset
import app.awrad.core.domain.practice.PracticePolicy
import app.awrad.core.domain.practice.PracticePolicyJson
import app.awrad.core.domain.practice.WeekStart
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.ProfileChoice
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The practice policy through Room, the profiles and the engine against [FakeSyncServer]: signed out it stays on the
 * phone; the first sign-in follows `practice_policy_first_sign_in`; signed in, edits sync as the account's entity.
 */
@RunWith(RobolectricTestRunner::class)
class PracticePolicySyncTest {

    private val key = EntityKey(EntityType.PRACTICE_POLICY, ACCOUNT.id)
    private val maghrib = PracticePolicy.DEFAULT.copy(dayReset = DayReset.MAGHRIB)

    private suspend fun TestScope.signedOut(): SyncStack {
        val stack = SyncStack(this, signedIn = null)
        backgroundScope.launch { stack.manager.run() }
        runCurrent()
        return stack
    }

    private fun SyncStack.policies() =
        RoomPracticeSettingsRepository(databases, sync, profiles.clock, profiles.ids::next)

    private fun FakeSyncServer.policy() = entities[EntityType.PRACTICE_POLICY.wire to ACCOUNT.id.value]

    @Test
    fun `signed out, a change stays on the phone and queues nothing`() = runTest {
        val stack = signedOut()
        val policies = stack.policies()
        assertEquals(PracticePolicy.DEFAULT, policies.policy.first())

        policies.update { it.copy(dayReset = DayReset.MAGHRIB) }

        assertEquals(maghrib, policies.policy.first())
        assertTrue(stack.outbox().isEmpty())
        assertTrue(stack.entities().isEmpty())
    }

    @Test
    fun `first sign-in to an account without a policy seeds it with the chosen one`() = runTest {
        val stack = signedOut()
        stack.policies().update { it.copy(dayReset = DayReset.MAGHRIB) }

        // Settings alone aren't data: no Add / Erase question.
        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()
        assertNull(stack.manager.prompt.value)
        assertTrue(stack.outbox().isEmpty(), "nothing is queued before the account's feed is known")

        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())
        assertEquals(PracticePolicyJson.encode(maghrib), stack.server.policy()?.document)
        assertEquals(1L, stack.entities().single { it.key == key }.knownVersion)
        assertTrue(stack.outbox().isEmpty())
    }

    @Test
    fun `first sign-in to an account with a policy takes the account's, whatever was chosen`() = runTest {
        val stack = signedOut()
        stack.policies().update { it.copy(dayReset = DayReset.MAGHRIB) }
        val accounts = PracticePolicy.DEFAULT.copy(weekStart = WeekStart.SUNDAY)
        stack.server.putFromElsewhere(EntityType.PRACTICE_POLICY.wire, ACCOUNT.id, PracticePolicyJson.encode(accounts))

        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()
        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

        assertEquals(accounts, stack.policies().policy.first())
        assertTrue(stack.server.batches.isEmpty(), "the phone's policy isn't sent")
        assertEquals(1L, stack.server.policy()?.version)
    }

    @Test
    fun `untouched defaults are never uploaded`() = runTest {
        val stack = signedOut()
        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()

        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())
        assertNull(stack.server.policy())
        assertTrue(stack.outbox().isEmpty())
    }

    @Test
    fun `Erase still seeds the chosen policy into the fresh profile`() = runTest {
        val stack = signedOut()
        stack.policies().update { it.copy(calculationMethod = CalculationMethod.DUBAI) }
        stack.tags.create("Morning")

        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()
        stack.manager.answer(ProfileChoice.ERASE)
        runCurrent()

        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())
        val dubai = PracticePolicy.DEFAULT.copy(calculationMethod = CalculationMethod.DUBAI)
        assertEquals(PracticePolicyJson.encode(dubai), stack.server.policy()?.document)
        assertEquals(dubai, stack.policies().policy.first())
    }

    @Test
    fun `signed in, an edit syncs, and a conflicting one merges by setting`() = runTest {
        val stack = signedOut()
        stack.accounts.updateAccount(ACCOUNT)
        runCurrent()
        val policies = stack.policies()
        policies.update { it.copy(dayReset = DayReset.MAGHRIB) }
        assertEquals(1, stack.outbox().size)
        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())
        assertEquals(PracticePolicyJson.encode(maghrib), stack.server.policy()?.document)

        // Another device changes the week start while this one changes the method.
        val elsewhere = maghrib.copy(weekStart = WeekStart.SATURDAY)
        stack.server.putFromElsewhere(EntityType.PRACTICE_POLICY.wire, ACCOUNT.id, PracticePolicyJson.encode(elsewhere))
        policies.update { it.copy(calculationMethod = CalculationMethod.QATAR) }
        assertEquals(SyncOutcome.Done, stack.engine.syncOnce())

        val merged = elsewhere.copy(calculationMethod = CalculationMethod.QATAR)
        assertEquals(merged, policies.policy.first())
        assertEquals(PracticePolicyJson.encode(merged), stack.server.policy()?.document)
        assertTrue(stack.conflicts().isEmpty(), "a policy never opens a conflict")
    }
}
