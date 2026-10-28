package app.awrad.feature.library

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.dhikr.Reference
import app.awrad.core.domain.personal.AudioImport
import app.awrad.core.domain.personal.AudioImportError
import app.awrad.core.domain.personal.CustomAudio
import app.awrad.core.domain.personal.CustomDhikr
import app.awrad.core.domain.personal.OptionalTexts
import app.awrad.core.domain.personal.TagOutcome
import app.awrad.core.testing.FakeAudioPlayerFactory
import app.awrad.core.testing.FakeCustomDhikrRepository
import app.awrad.core.testing.FakeTagRepository
import app.awrad.core.testing.MainDispatcherRule
import kotlinx.coroutines.test.runTest
import org.junit.Rule
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class CustomDhikrEditorViewModelTest {

    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val dhikrs = FakeCustomDhikrRepository()
    private val tags = FakeTagRepository()
    private val players = FakeAudioPlayerFactory()

    private fun editor(id: String? = null) = CustomDhikrEditorViewModel(id, dhikrs, tags, players)

    @Test
    fun `a new dhikr needs Arabic and a title in some language`() {
        val editor = editor()

        editor.onAction(EditorAction.Save)

        assertEquals(setOf(EditorProblem.ARABIC_REQUIRED, EditorProblem.TITLE_REQUIRED), editor.state.value.problems)
        assertTrue(dhikrs.current.isEmpty())
    }

    @Test
    fun `fields in each language, a Qur'an reference and others are saved as one dhikr`() {
        val editor = editor()
        editor.onAction(EditorAction.KindChanged(DhikrKind.QURAN))
        editor.onAction(EditorAction.ArabicChanged("  قُلْ هُوَ ٱللَّهُ أَحَدٌ  "))
        editor.onAction(EditorAction.LanguageShown(ContentLanguage.ML))
        editor.onAction(EditorAction.TitleChanged("ഇഖ്‌ലാസ്"))
        editor.onAction(EditorAction.TranslationChanged("പറയുക: അവൻ അല്ലാഹു, ഏകൻ"))
        editor.onAction(EditorAction.LanguageShown(ContentLanguage.EN))
        editor.onAction(EditorAction.TransliterationChanged("Qul huwa Allahu ahad"))
        editor.onAction(EditorAction.QuranChanged(QuranFields("112", "1", "")))
        editor.onAction(EditorAction.AddReference)
        editor.onAction(EditorAction.ReferenceChanged(0, "Taught by my teacher"))

        editor.onAction(EditorAction.Save)

        val saved = dhikrs.current.single()
        assertEquals(DhikrKind.QURAN, saved.kind)
        assertEquals("قُلْ هُوَ ٱللَّهُ أَحَدٌ", saved.arabic)
        assertEquals(OptionalTexts(ml = "ഇഖ്‌ലാസ്"), saved.title)
        assertEquals("Qul huwa Allahu ahad", saved.transliteration.en)
        assertEquals(
            listOf(Reference.Quran("quran", 112, 1, 1), Reference.Other("r1", "Taught by my teacher")),
            saved.references,
        )
        assertTrue(editor.state.value.isDone)
    }

    @Test
    fun `an existing dhikr loads into the form, with its tags, and saves in place`() = runTest {
        val tag = (tags.create("Morning") as TagOutcome.Saved).tag
        dhikrs.save(EXISTING)
        tags.setTags(EXISTING.id, listOf(tag.id))
        val editor = editor(EXISTING.id.value)
        assertEquals("Subhanallah", editor.state.value.titles.en)
        assertEquals(listOf(tag.id), editor.state.value.selectedTags)

        editor.onAction(EditorAction.TitleChanged("Tasbih"))
        editor.onAction(EditorAction.TagToggled(tag.id))
        editor.onAction(EditorAction.Save)

        assertEquals(OptionalTexts(en = "Tasbih"), dhikrs.current.single().title)
        assertNull(tags.currentTagsByDhikr[EXISTING.id])
    }

    @Test
    fun `a recording is imported, replaced or removed, and an unsaved one is discarded`() {
        val editor = editor()
        editor.onAction(EditorAction.ImportAudio("content://picked/one.mp3"))
        val first = editor.state.value.audio?.localUri
        editor.onAction(EditorAction.ImportAudio("content://picked/two.m4a"))
        val second = editor.state.value.audio?.localUri

        editor.onAction(EditorAction.TogglePlayback)
        assertEquals(listOf(second), players.players.single().played)

        dhikrs.nextImport = AudioImport.Failed(AudioImportError.TOO_LARGE)
        editor.onAction(EditorAction.ImportAudio("content://picked/big.mp3"))
        assertEquals(AudioImportError.TOO_LARGE, editor.state.value.audioError)
        assertEquals(second, editor.state.value.audio?.localUri)

        editor.onAction(EditorAction.ArabicChanged("سُبْحَانَ ٱللَّهِ"))
        editor.onAction(EditorAction.TitleChanged("Subhanallah"))
        editor.onAction(EditorAction.Save)
        assertEquals(CustomAudio(second), dhikrs.current.single().audio)
        assertTrue(first != second)
    }

    @Test
    fun `delete asks first, then deletes`() = runTest {
        dhikrs.save(EXISTING)
        val editor = editor(EXISTING.id.value)

        editor.onAction(EditorAction.AskDelete)
        assertTrue(editor.state.value.isDeleteConfirmOpen)
        editor.onAction(EditorAction.ConfirmDelete)

        assertTrue(dhikrs.current.isEmpty())
        assertTrue(editor.state.value.isDone)
    }

    private companion object {
        val EXISTING = CustomDhikr(
            id = AwradId("0192f0d0-0000-7000-8000-000000000001"),
            kind = DhikrKind.DHIKR,
            arabic = "سُبْحَانَ ٱللَّهِ",
            title = OptionalTexts(en = "Subhanallah"),
        )
    }
}
