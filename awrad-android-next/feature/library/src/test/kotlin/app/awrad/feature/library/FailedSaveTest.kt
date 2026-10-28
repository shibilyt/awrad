package app.awrad.feature.library

import androidx.compose.runtime.getValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onLast
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.platform.app.InstrumentationRegistry
import app.awrad.core.designsystem.theme.AwradTheme
import app.awrad.core.testing.FakeAudioPlayerFactory
import app.awrad.core.testing.FakeCustomDhikrRepository
import app.awrad.core.testing.FakeTagRepository
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * A save that fails with the problem out of sight: Save at the bottom of the form, the empty Arabic text at the
 * top. The editor scrolls back to the Arabic text and gives it focus, so a screen reader reads its error.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w360dp-h640dp")
class FailedSaveTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `a failed save brings the first problem into view and focuses it`() {
        val editor = CustomDhikrEditorViewModel(
            dhikrId = null,
            customDhikrs = FakeCustomDhikrRepository(),
            tags = FakeTagRepository(),
            playerFactory = FakeAudioPlayerFactory(),
        )
        compose.setContent {
            AwradTheme {
                val state by editor.state
                CustomDhikrEditorScreen(state = state, onAction = editor::onAction, onPickAudio = {}, onBack = {})
            }
        }
        val save = InstrumentationRegistry.getInstrumentation().targetContext.getString(R.string.editor_save)
        val arabic = compose.onAllNodes(hasSetTextAction()).onFirst()
        // The form's own Save, at the end, not the top bar's.
        compose.onAllNodes(hasText(save)).onLast().performScrollTo()
        arabic.assertIsNotDisplayed()
        compose.onAllNodes(hasText(save)).onLast().performClick()
        compose.waitForIdle()

        arabic.assertIsDisplayed()
        arabic.assertIsFocused()
        compose.onAllNodes(hasText(save)).onLast().assertIsNotDisplayed()
    }
}
