package app.awrad.feature.library

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.PlaybackState
import app.awrad.core.domain.audio.PlaybackStatus
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.personal.CustomDhikr
import app.awrad.core.domain.personal.OptionalTexts
import app.awrad.core.domain.personal.TagError
import app.awrad.core.domain.personal.TagOutcome
import app.awrad.core.domain.sync.ConflictChoice
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.OpenConflict
import app.awrad.core.domain.sync.SyncOp
import app.awrad.core.testing.FakeAudioPlayerFactory
import app.awrad.core.testing.FakeCustomDhikrRepository
import app.awrad.core.testing.FakeDhikrCatalogSource
import app.awrad.core.testing.FakeSyncService
import app.awrad.core.testing.FakeTagRepository
import app.awrad.core.testing.MainDispatcherRule
import app.awrad.core.testing.contractCatalog
import kotlinx.coroutines.test.runTest
import org.junit.Rule
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class DhikrDetailViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val players = FakeAudioPlayerFactory()

    private val customDhikrs = FakeCustomDhikrRepository()
    private val tags = FakeTagRepository()
    private val sync = FakeSyncService()

    /** The page for the built-in with catalog [key] (by its ID), or for [key] itself when no dhikr has it. */
    private fun viewModel(key: String) = DhikrDetailViewModel(
        contractCatalog.dhikr(key)?.id?.value ?: key,
        FakeDhikrCatalogSource(),
        customDhikrs,
        tags,
        sync,
        players,
    )

    @Test
    fun `the dhikr loads by key, and an unknown key loads nothing`() {
        assertEquals("swalath-al-nariyya", viewModel("swalath-al-nariyya").state.value.dhikr?.key)
        val missing = viewModel("no-such-dhikr").state.value
        assertFalse(missing.isLoading)
        assertNull(missing.dhikr)
    }

    @Test
    fun `no player is made until the first play`() {
        viewModel("surah-ikhlas")
        assertTrue(players.players.isEmpty())
    }

    @Test
    fun `play streams the recording, and the player's progress reaches the state`() {
        val viewModel = viewModel("swalath-al-nariyya")

        viewModel.onAction(DhikrDetailAction.TogglePlayback)
        val player = players.players.single()
        assertEquals(listOf("https://dhikrs.awrad.app/swalath_nariyya.mp3"), player.played)
        assertEquals(PlaybackStatus.LOADING, viewModel.state.value.playback.status)

        val playing = PlaybackState(PlaybackStatus.PLAYING, positionMs = 1_500, durationMs = 30_000)
        player.emit(playing)
        assertEquals(playing, viewModel.state.value.playback)
    }

    @Test
    fun `toggling while playing pauses, and again resumes on the same player`() {
        val viewModel = viewModel("swalath-al-nariyya")
        viewModel.onAction(DhikrDetailAction.TogglePlayback)
        val player = players.players.single()
        player.emit(PlaybackState(PlaybackStatus.PLAYING, positionMs = 2_000, durationMs = 30_000))

        viewModel.onAction(DhikrDetailAction.TogglePlayback)
        assertEquals(1, player.pauses)
        assertEquals(PlaybackStatus.PAUSED, viewModel.state.value.playback.status)

        viewModel.onAction(DhikrDetailAction.TogglePlayback)
        assertEquals(2, player.played.size)
        assertEquals(1, players.players.size)
    }

    @Test
    fun `leaving the page pauses, and a page that never played has nothing to pause`() {
        viewModel("surah-ikhlas").onAction(DhikrDetailAction.Pause)
        assertTrue(players.players.isEmpty())

        val viewModel = viewModel("surah-ikhlas")
        viewModel.onAction(DhikrDetailAction.TogglePlayback)
        viewModel.onAction(DhikrDetailAction.Pause)
        assertEquals(1, players.players.single().pauses)
    }

    @Test
    fun `the page stopping pauses the recording, and coming back doesn't restart it`() {
        val viewModel = viewModel("swalath-al-nariyya")
        val page = TestPage()
        page.lifecycle.addObserver(pauseOnStop(viewModel::onAction))
        page.lifecycle.currentState = Lifecycle.State.RESUMED
        viewModel.onAction(DhikrDetailAction.TogglePlayback)
        val player = players.players.single()
        player.emit(PlaybackState(PlaybackStatus.PLAYING, positionMs = 2_000, durationMs = 30_000))

        // Home, or another app: the activity, and the page with it, stops.
        page.lifecycle.currentState = Lifecycle.State.CREATED
        assertEquals(1, player.pauses)
        assertEquals(PlaybackStatus.PAUSED, viewModel.state.value.playback.status)

        page.lifecycle.currentState = Lifecycle.State.RESUMED
        assertEquals(1, player.played.size)
        assertEquals(PlaybackStatus.PAUSED, viewModel.state.value.playback.status)
    }

    @Test
    fun `pausing only on stop, not on a passing pause such as a dialog`() {
        val viewModel = viewModel("swalath-al-nariyya")
        val page = TestPage()
        page.lifecycle.addObserver(pauseOnStop(viewModel::onAction))
        page.lifecycle.currentState = Lifecycle.State.RESUMED
        viewModel.onAction(DhikrDetailAction.TogglePlayback)

        page.lifecycle.currentState = Lifecycle.State.STARTED
        assertEquals(0, players.players.single().pauses)
    }

    @Test
    fun `a dhikr without audio never plays`() {
        val viewModel = viewModel("asma-ul-husna-as-sabur")
        viewModel.onAction(DhikrDetailAction.TogglePlayback)
        assertTrue(players.players.isEmpty())
    }

    @Test
    fun `a custom dhikr loads by its ID and can be deleted after confirming`() = runTest {
        customDhikrs.save(CUSTOM)
        val viewModel = viewModel(CUSTOM.id.value)
        assertEquals(CUSTOM, viewModel.state.value.custom)
        assertEquals("Morning remembrance", viewModel.state.value.dhikr?.title?.en)

        viewModel.onAction(DhikrDetailAction.AskDelete)
        assertTrue(viewModel.state.value.isDeleteConfirmOpen)
        viewModel.onAction(DhikrDetailAction.ConfirmDelete)

        assertTrue(customDhikrs.current.isEmpty())
        assertTrue(viewModel.state.value.isDeleted)
    }

    @Test
    fun `a built-in is never deletable`() {
        val viewModel = viewModel("tahleel")
        assertNull(viewModel.state.value.custom)
        viewModel.onAction(DhikrDetailAction.ConfirmDelete)
        assertFalse(viewModel.state.value.isDeleted)
    }

    @Test
    fun `Manage tags toggles a built-in's tags and creates new ones on it`() = runTest {
        val morning = (tags.create("Morning") as TagOutcome.Saved).tag
        val viewModel = viewModel("tahleel")
        val id = contractCatalog.dhikr("tahleel")!!.id

        viewModel.onAction(DhikrDetailAction.Tags(TagSheetAction.Open))
        viewModel.onAction(DhikrDetailAction.Tags(TagSheetAction.Toggle(morning.id)))
        viewModel.onAction(DhikrDetailAction.Tags(TagSheetAction.NameChanged("Evening")))
        viewModel.onAction(DhikrDetailAction.Tags(TagSheetAction.Create))

        assertEquals(listOf("Morning", "Evening"), viewModel.state.value.tags.map { it.name })
        assertEquals(2, tags.currentTagsByDhikr.getValue(id).size)

        viewModel.onAction(DhikrDetailAction.Tags(TagSheetAction.NameChanged("morning")))
        viewModel.onAction(DhikrDetailAction.Tags(TagSheetAction.Create))
        assertEquals(TagError.NameTaken, viewModel.state.value.sheet?.error)

        viewModel.onAction(DhikrDetailAction.Tags(TagSheetAction.Toggle(morning.id)))
        assertEquals(listOf("Evening"), viewModel.state.value.tags.map { it.name })
    }

    @Test
    fun `a conflict on the dhikr shows, and Keep mine resolves it`() = runTest {
        customDhikrs.save(CUSTOM)
        val key = EntityKey(EntityType.CUSTOM_DHIKR, CUSTOM.id)
        sync.conflictState.value = listOf(OpenConflict(key, SyncOp.PUT))
        val viewModel = viewModel(CUSTOM.id.value)
        assertEquals(key, viewModel.state.value.conflict?.key)

        viewModel.onAction(DhikrDetailAction.Resolve(ConflictChoice.KEEP_MINE))

        assertEquals(listOf(key to ConflictChoice.KEEP_MINE), sync.resolved)
        assertNull(viewModel.state.value.conflict)
    }

    /** A page's lifecycle, moved by hand (no main-thread checks). */
    private class TestPage : LifecycleOwner {
        override val lifecycle: LifecycleRegistry = LifecycleRegistry.createUnsafe(this)
    }

    private companion object {
        val CUSTOM = CustomDhikr(
            id = AwradId("0192f0d0-0000-7000-8000-000000000001"),
            kind = DhikrKind.DHIKR,
            arabic = "سُبْحَانَ ٱللَّهِ",
            title = OptionalTexts(en = "Morning remembrance"),
        )
    }
}
