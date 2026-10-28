package app.awrad.feature.library

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
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
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.dhikr.Reference
import app.awrad.core.domain.personal.CustomDhikr
import app.awrad.core.domain.personal.OptionalTexts
import app.awrad.core.domain.sync.FieldError
import app.awrad.core.domain.sync.FieldErrorCode
import app.awrad.core.testing.FakeAudioPlayerFactory
import app.awrad.core.testing.FakeCustomDhikrRepository
import app.awrad.core.testing.FakeTagRepository
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * A save that fails with the problem out of sight: the editor scrolls to the field or reference row with the first
 * problem and gives it focus, so a screen reader reads its error there.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w360dp-h640dp")
class FailedSaveTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `a failed save brings the first problem into view and focuses it`() {
        show(editor())
        val save = text(R.string.editor_save)
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

    @Test
    fun `a reversed Qur'an range is marked on, and focuses, its last ayah`() {
        val editor = editor()
        editor.onAction(EditorAction.ArabicChanged("قُلْ هُوَ ٱللَّهُ أَحَدٌ"))
        editor.onAction(EditorAction.TitleChanged("Ikhlas"))
        editor.onAction(EditorAction.QuranChanged(QuranFields("112", "4", "1")))
        show(editor)
        val ayahEnd = compose.onNode(hasSetTextAction() and hasText("1"))

        compose.onAllNodes(hasText(text(R.string.editor_save))).onFirst().performClick()
        compose.waitForIdle()

        ayahEnd.assertIsDisplayed().assertIsFocused()
        ayahEnd.assert(hasError(R.string.editor_problem_quran_range))
        compose.onNode(hasSetTextAction() and hasText("4")).assert(hasNoError())
    }

    @Test
    fun `a kept reference that can't be saved is marked on its row, which the failed save focuses`() {
        val dhikrs = FakeCustomDhikrRepository(listOf(BROKEN_BOOK))
        val editor = editor(dhikrs, BROKEN_BOOK.id.value)
        show(editor)
        val kept = compose.onNode(hasError(R.string.editor_problem_kept_reference))
        kept.assertDoesNotExist()

        // The top bar's Save: the references are below what's on screen.
        compose.onAllNodes(hasText(text(R.string.editor_save))).onFirst().performClick()
        compose.waitForIdle()

        kept.assertIsDisplayed().assertIsFocused()
    }

    @Test
    fun `a rejected reference is marked on its own row, which a failed save brings into view and focuses`() {
        val form = EditorUiState(
            isLoading = false,
            arabic = "سُبْحَانَ ٱللَّهِ",
            titles = LanguageFields(en = "Subhanallah"),
            otherReferences = listOf("Muslim", "", "Bukhari"),
        )
        var state by mutableStateOf(form)
        compose.setContent {
            AwradTheme { CustomDhikrEditorScreen(state = state, onAction = {}, onPickAudio = {}, onBack = {}) }
        }
        val bukhari = compose.onNode(hasSetTextAction() and hasText("Bukhari"))
        bukhari.assertIsNotDisplayed()

        // The receipt's second reference is "Bukhari": the blank one wasn't saved.
        val rejected = listOf(FieldError("/document/references/1", FieldErrorCode.INVALID))
        state = form.copy(problems = form.problemsOf(rejected), failedSaves = 1)
        compose.waitForIdle()

        bukhari.assertIsDisplayed().assertIsFocused()
        bukhari.assert(hasError(R.string.editor_problem_reference))
        compose.onNode(hasSetTextAction() and hasText("Muslim")).assert(hasNoError())
    }

    private fun editor(dhikrs: FakeCustomDhikrRepository = FakeCustomDhikrRepository(), id: String? = null) =
        CustomDhikrEditorViewModel(
            dhikrId = id,
            customDhikrs = dhikrs,
            tags = FakeTagRepository(),
            playerFactory = FakeAudioPlayerFactory(),
        )

    private fun show(editor: CustomDhikrEditorViewModel) {
        compose.setContent {
            AwradTheme {
                val state by editor.state
                CustomDhikrEditorScreen(state = state, onAction = editor::onAction, onPickAudio = {}, onBack = {})
            }
        }
    }

    private fun text(id: Int): String = InstrumentationRegistry.getInstrumentation().targetContext.getString(id)

    private fun hasError(id: Int) = SemanticsMatcher.expectValue(SemanticsProperties.Error, text(id))

    private fun hasNoError() = SemanticsMatcher.keyNotDefined(SemanticsProperties.Error)

    private companion object {
        /** An existing dhikr whose book reference (kept as it is) has a blank title. */
        val BROKEN_BOOK = CustomDhikr(
            id = AwradId("0192f0d0-0000-7000-8000-000000000002"),
            kind = DhikrKind.DHIKR,
            arabic = "سُبْحَانَ ٱللَّهِ",
            title = OptionalTexts(en = "Subhanallah"),
            references = listOf(Reference.Hadith("abu-dawud", "Sunan Abi Dawud"), Reference.Book("book", " ")),
        )
    }
}
