package app.awrad.feature.library

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import app.awrad.core.domain.audio.PlaybackState
import app.awrad.core.domain.audio.PlaybackStatus
import app.awrad.core.testing.FakeAudioPlayerFactory
import app.awrad.core.testing.FakeDhikrCatalogSource
import app.awrad.core.testing.MainDispatcherRule
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

    private fun viewModel(key: String) = DhikrDetailViewModel(key, FakeDhikrCatalogSource(), players)

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

    /** A page's lifecycle, moved by hand (no main-thread checks). */
    private class TestPage : LifecycleOwner {
        override val lifecycle: LifecycleRegistry = LifecycleRegistry.createUnsafe(this)
    }
}
