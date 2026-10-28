@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package app.awrad.feature.sync

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.sync.ConflictChoice
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.LocalProfile
import app.awrad.core.domain.sync.OpenConflict
import app.awrad.core.domain.sync.PendingProfilePrompt
import app.awrad.core.domain.sync.ProfileChoice
import app.awrad.core.domain.sync.RejectionCode
import app.awrad.core.domain.sync.SyncNotice
import app.awrad.core.domain.sync.SyncOp
import app.awrad.core.domain.sync.SyncState
import app.awrad.core.domain.sync.SyncStatus
import app.awrad.core.testing.FakeCustomDhikrRepository
import app.awrad.core.testing.FakeDhikrCatalogSource
import app.awrad.core.testing.FakeProfileService
import app.awrad.core.testing.FakeSyncService
import app.awrad.core.testing.FakeTagRepository
import app.awrad.core.testing.MainDispatcherRule
import app.awrad.core.testing.contractCatalog
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Rule
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SyncViewModelsTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val sync = FakeSyncService(SyncStatus(SyncState.IDLE, Instant.parse("2026-10-28T09:00:00Z"), 3))
    private val profiles = FakeProfileService(listOf(ACTIVE, OTHER))

    private fun dataSync() = DataSyncViewModel(
        sync,
        profiles,
        FakeCustomDhikrRepository(),
        FakeTagRepository(),
        FakeDhikrCatalogSource(),
    )

    @Test
    fun `status, profiles and conflicts with names`() {
        val tahleel = contractCatalog.dhikr("tahleel")!!
        sync.conflictState.value = listOf(OpenConflict(EntityKey(EntityType.DHIKR_PERSONAL, tahleel.id), SyncOp.PUT))
        val state = dataSync().state.value

        assertEquals(3, state.status.pendingCount)
        assertEquals(listOf(ACTIVE, OTHER), state.profiles)
        assertEquals(ConflictName.Tags(tahleel.title.en), state.conflicts.single().name)
    }

    @Test
    fun `an up-to-date sync with open conflicts leads with how many are left, not up to date`() {
        val viewModel = dataSync()
        assertEquals(SyncHeadline.State(SyncState.IDLE), viewModel.state.value.headline)

        sync.conflictState.value = listOf(
            OpenConflict(EntityKey(EntityType.USER_TAG, AwradId("0192f0a0-0000-7000-8000-000000000001")), SyncOp.PUT),
            OpenConflict(EntityKey(EntityType.USER_TAG, AwradId("0192f0a0-0000-7000-8000-000000000002")), SyncOp.PUT),
        )
        assertEquals(SyncHeadline.Conflicts(2), viewModel.state.value.headline)

        // A state that needs the user's attention more still shows.
        sync.status.value = SyncStatus(SyncState.RETRYING)
        assertEquals(SyncHeadline.State(SyncState.RETRYING), viewModel.state.value.headline)
    }

    @Test
    fun `removing a profile with unsent changes warns, then removes`() {
        val viewModel = dataSync()

        viewModel.onAction(DataSyncAction.AskRemove(OTHER.profileId))
        assertEquals(Removing(OTHER, warnsUnsent = true), viewModel.state.value.removing)
        viewModel.onAction(DataSyncAction.ConfirmRemove)

        assertEquals(listOf(OTHER.profileId), profiles.removed)
        assertNull(viewModel.state.value.removing)
    }

    @Test
    fun `removing a profile without unsent changes asks plainly, and cancel keeps it`() {
        val viewModel = dataSync()

        viewModel.onAction(DataSyncAction.AskRemove(ACTIVE.profileId))
        assertEquals(Removing(ACTIVE, warnsUnsent = false), viewModel.state.value.removing)
        viewModel.onAction(DataSyncAction.CancelRemove)

        assertTrue(profiles.removed.isEmpty())
    }

    @Test
    fun `conflicts resolve and Sync now asks for a sync`() {
        val key = EntityKey(EntityType.USER_TAG, AwradId("0192f0a0-0000-7000-8000-000000000001"))
        sync.conflictState.value = listOf(OpenConflict(key, SyncOp.PUT))
        val viewModel = dataSync()

        viewModel.onAction(DataSyncAction.Resolve(key, ConflictChoice.USE_THEIRS))
        viewModel.onAction(DataSyncAction.SyncNow)

        assertEquals(listOf(key to ConflictChoice.USE_THEIRS), sync.resolved)
        assertEquals(1, sync.requests)
    }

    @Test
    fun `the prompts show the profile question first, then refused changes, one at a time`() = runTest {
        val viewModel = SyncPromptsViewModel(profiles, sync)
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.state.collect {} }
        val notice = SyncNotice(RejectionCode.TAG_NAME_TAKEN, EntityKey(EntityType.USER_TAG, OTHER.profileId))
        sync.noticeState.value = listOf(notice)
        profiles.ask(PendingProfilePrompt.AnonymousData("amina@example.com"))
        assertEquals(PendingProfilePrompt.AnonymousData("amina@example.com"), viewModel.state.value.prompt)

        viewModel.onAction(SyncPromptsAction.Answer(ProfileChoice.ADD_TO_ACCOUNT))
        assertEquals(listOf(ProfileChoice.ADD_TO_ACCOUNT), profiles.answers)
        assertEquals(SyncPromptsUiState(prompt = null, notice = notice), viewModel.state.value)

        viewModel.onAction(SyncPromptsAction.Dismiss(notice))
        assertEquals(SyncPromptsUiState(), viewModel.state.value)
    }

    private companion object {
        val ACTIVE =
            LocalProfile(AwradId("0192f0e0-0000-7000-8000-000000000001"), "amina@example.com", true, false, null)
        val OTHER =
            LocalProfile(AwradId("0192f0e0-0000-7000-8000-000000000002"), "bilal@example.com", false, true, null)
    }
}
