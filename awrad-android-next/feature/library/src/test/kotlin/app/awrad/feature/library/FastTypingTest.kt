package app.awrad.feature.library

import androidx.compose.runtime.getValue
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.performTextInput
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.testing.FakeAudioPlayerFactory
import app.awrad.core.testing.FakeCustomAudioService
import app.awrad.core.testing.FakeCustomDhikrRepository
import app.awrad.core.testing.FakeTagRepository
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals

/**
 * Fast typing keeps every character: the screen reads the ViewModel's state synchronously, so each keystroke
 * lands on the text the previous one produced. The first character opens the input session; the rest of the
 * phrase then arrives one character per frame through it, with the clock driven by hand. When the state reaches
 * the screen a frame late, as a collected flow can deliver it, a frame recomposes the field with the text from
 * before the last keystroke and most characters are lost.
 */
@RunWith(RobolectricTestRunner::class)
class FastTypingTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `rapid sequential edits are all kept`() {
        val editor = CustomDhikrEditorViewModel(
            dhikrId = null,
            customDhikrs = FakeCustomDhikrRepository(),
            tags = FakeTagRepository(),
            playerFactory = FakeAudioPlayerFactory(),
            audio = FakeCustomAudioService(),
        )
        compose.setContent {
            AwradTheme {
                // As CustomDhikrEditorRoute reads it.
                val state by editor.state
                CustomDhikrEditorScreen(state = state, onAction = editor::onAction, onPickAudio = {}, onBack = {})
            }
        }
        compose.waitForIdle()
        val arabic = compose.onAllNodes(hasSetTextAction()).onFirst()
        arabic.performTextInput(TYPED.take(1))
        compose.waitForIdle()

        compose.mainClock.autoAdvance = false
        TYPED.drop(1).forEach {
            arabic.performTextInput(it.toString())
            compose.mainClock.advanceTimeByFrame()
        }
        compose.mainClock.autoAdvance = true
        compose.waitForIdle()

        assertEquals(TYPED, editor.state.value.arabic)
        assertEquals(TYPED, arabic.fetchSemanticsNode().config[SemanticsProperties.EditableText].text)
    }

    private companion object {
        const val TYPED = "subhanallahi wa bihamdihi"
    }
}
