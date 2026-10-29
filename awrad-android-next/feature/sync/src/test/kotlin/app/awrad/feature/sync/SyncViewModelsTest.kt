@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package app.awrad.feature.sync

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.AudioStorage
import app.awrad.core.domain.personal.AudioUploadNotice
import app.awrad.core.domain.personal.AudioUploadProblem
import app.awrad.core.domain.personal.AudioUsage
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
import app.awrad.core.testing.FakeCustomAudioService
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
import java.util.Locale
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SyncViewModelsTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val sync = FakeSyncService(SyncStatus(SyncState.IDLE, Instant.parse("2026-10-28T09:00:00Z"), 3))
    private val profiles = FakeProfileService(listOf(ACTIVE, OTHER))
    private val audio = FakeCustomAudioService(AudioUsage.Known(STORAGE))

    private fun dataSync() = DataSyncViewModel(
        sync,
        profiles,
        FakeCustomDhikrRepository(),
        FakeTagRepository(),
        FakeDhikrCatalogSource(),
        audio,
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
    fun `audio storage shows while signed in as the profile's account, asked again after each sync run`() {
        val viewModel = dataSync()
        assertEquals(STORAGE, viewModel.state.value.audioStorage)
        assertEquals(1, audio.usageCalls)

        sync.status.value = SyncStatus(SyncState.SYNCING)
        assertEquals(1, audio.usageCalls)
        val after = AudioStorage(usedBytes = 130_000_000, limitBytes = 500_000_000)
        audio.usageAnswer = AudioUsage.Known(after)
        sync.status.value = SyncStatus(SyncState.IDLE)

        assertEquals(2, audio.usageCalls)
        assertEquals(after, viewModel.state.value.audioStorage)
    }

    @Test
    fun `signed out or waiting, usage isn't asked and no storage shows, until signed in`() {
        sync.status.value = SyncStatus(SyncState.SIGNED_OUT)
        val viewModel = dataSync()
        sync.status.value = SyncStatus(SyncState.WAITING)
        assertEquals(0, audio.usageCalls)
        assertNull(viewModel.state.value.audioStorage)

        sync.status.value = SyncStatus(SyncState.SYNCING)
        assertEquals(1, audio.usageCalls)
        assertEquals(STORAGE, viewModel.state.value.audioStorage)

        sync.status.value = SyncStatus(SyncState.SIGNED_OUT)
        assertNull(viewModel.state.value.audioStorage)
        assertEquals(1, audio.usageCalls)
    }

    @Test
    fun `storage that isn't known, or isn't the profile's account's, doesn't show`() {
        audio.usageAnswer = AudioUsage.Unavailable
        val viewModel = dataSync()
        assertNull(viewModel.state.value.audioStorage)

        audio.usageAnswer = AudioUsage.Known(STORAGE)
        sync.status.value = SyncStatus(SyncState.SYNCING)
        sync.status.value = SyncStatus(SyncState.IDLE)
        assertEquals(STORAGE, viewModel.state.value.audioStorage)

        audio.usageAnswer = AudioUsage.NotSignedIn
        sync.status.value = SyncStatus(SyncState.SYNCING)
        sync.status.value = SyncStatus(SyncState.IDLE)
        assertNull(viewModel.state.value.audioStorage)
    }

    @Test
    fun `the prompts show the profile question first, then refused changes, one at a time`() = runTest {
        val viewModel = SyncPromptsViewModel(profiles, sync, audio)
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

    @Test
    fun `upload notices come after profile questions and refused changes, one at a time, until dismissed`() = runTest {
        val viewModel = SyncPromptsViewModel(profiles, sync, audio)
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.state.collect {} }
        val full = AudioUploadNotice(DHIKR, AudioUploadProblem.STORAGE_FULL, STORAGE)
        val mismatch = AudioUploadNotice(OTHER_DHIKR, AudioUploadProblem.UPLOAD_MISMATCH)
        val refused = SyncNotice(RejectionCode.AUDIO_NOT_FOUND, EntityKey(EntityType.CUSTOM_DHIKR, DHIKR))
        audio.noticeState.value = listOf(full, mismatch)
        sync.noticeState.value = listOf(refused)
        profiles.ask(PendingProfilePrompt.AnonymousData("amina@example.com"))
        assertEquals(PendingProfilePrompt.AnonymousData("amina@example.com"), viewModel.state.value.prompt)

        viewModel.onAction(SyncPromptsAction.Answer(ProfileChoice.ADD_TO_ACCOUNT))
        assertEquals(refused, viewModel.state.value.notice)
        viewModel.onAction(SyncPromptsAction.Dismiss(refused))
        assertEquals(SyncPromptsUiState(upload = full), viewModel.state.value)

        viewModel.onAction(SyncPromptsAction.DismissUpload(full))
        assertEquals(SyncPromptsUiState(upload = mismatch), viewModel.state.value)
        viewModel.onAction(SyncPromptsAction.DismissUpload(mismatch))
        assertEquals(SyncPromptsUiState(), viewModel.state.value)
        assertTrue(audio.noticeState.value.isEmpty())
    }

    @Test
    fun `audio storage is decimal megabytes, used with at most one fraction digit, the limit with none`() {
        val limit = 500_000_000L
        assertEquals(
            StorageFigures("120.5", "500", 500),
            storageFigures(AudioStorage(120_456_789, limit), Locale.US),
        )
        assertEquals(StorageFigures("120", "500", 500), storageFigures(AudioStorage(120_000_000, limit), Locale.US))
        assertEquals(StorageFigures("0", "500", 500), storageFigures(AudioStorage(0, limit), Locale.US))
        assertEquals(StorageFigures("0.1", "500", 500), storageFigures(AudioStorage(50_000, limit), Locale.US))
        assertEquals(
            StorageFigures("1,234.6", "2,000", 2_000),
            storageFigures(AudioStorage(1_234_567_890, 2_000_000_000), Locale.US),
        )
        assertEquals(
            StorageFigures("120,5", "500", 500),
            storageFigures(AudioStorage(120_456_789, limit), Locale.GERMANY),
        )
    }

    @Test
    fun `audio rejections and upload problems each have their own message`() {
        val audioReasons = listOf(RejectionCode.AUDIO_NOT_FOUND, RejectionCode.AUDIO_MISMATCH).map(::refusedReason)
        assertEquals(2, audioReasons.toSet().size)
        assertTrue(audioReasons.none { it == refusedReason(RejectionCode.DOCUMENT_INVALID) })
        val problems = AudioUploadProblem.entries.map(::uploadProblemReason)
        assertEquals(AudioUploadProblem.entries.size, problems.toSet().size)
    }

    @Test
    fun `a practice-policy merge that dropped corrections has its own title and reason`() {
        assertEquals(R.string.sync_hijri_replaced_title, noticeTitle(RejectionCode.HIJRI_CORRECTIONS_REPLACED))
        assertEquals(R.string.sync_rejected_title, noticeTitle(RejectionCode.ENTITY_ID_INVALID))
        assertEquals(
            R.string.sync_reason_hijri_corrections_replaced,
            refusedReason(RejectionCode.HIJRI_CORRECTIONS_REPLACED),
        )
    }

    private companion object {
        val STORAGE = AudioStorage(usedBytes = 120_500_000, limitBytes = 500_000_000)
        val DHIKR = AwradId("0192f0d0-0000-7000-8000-000000000001")
        val OTHER_DHIKR = AwradId("0192f0d0-0000-7000-8000-000000000002")
        val ACTIVE =
            LocalProfile(AwradId("0192f0e0-0000-7000-8000-000000000001"), "amina@example.com", true, false, null)
        val OTHER =
            LocalProfile(AwradId("0192f0e0-0000-7000-8000-000000000002"), "bilal@example.com", false, true, null)
    }
}
