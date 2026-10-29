package app.awrad.feature.library

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.AudioContentType
import app.awrad.core.domain.audio.PlaybackState
import app.awrad.core.domain.audio.PlaybackStatus
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.dhikr.Reference
import app.awrad.core.domain.personal.AudioImport
import app.awrad.core.domain.personal.AudioImportError
import app.awrad.core.domain.personal.CustomAudio
import app.awrad.core.domain.personal.CustomDhikr
import app.awrad.core.domain.personal.OptionalTexts
import app.awrad.core.domain.personal.RecordingDownloadError
import app.awrad.core.domain.personal.RecordingUpload
import app.awrad.core.domain.personal.TagOutcome
import app.awrad.core.domain.personal.UploadedAudio
import app.awrad.core.domain.sync.FieldError
import app.awrad.core.domain.sync.FieldErrorCode
import app.awrad.core.testing.FakeAudioPlayerFactory
import app.awrad.core.testing.FakeCustomAudioService
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
    private val audio = FakeCustomAudioService()

    private fun editor(id: String? = null) = CustomDhikrEditorViewModel(id, dhikrs, tags, players, audio)

    @Test
    fun `a new dhikr needs Arabic and a title in some language`() {
        val editor = editor()

        editor.onAction(EditorAction.Save)

        assertEquals(
            mapOf(
                ProblemSpot.ARABIC to EditorProblem.ARABIC_REQUIRED,
                ProblemSpot.TITLE to EditorProblem.TITLE_REQUIRED,
            ),
            editor.state.value.problems,
        )
        assertTrue(dhikrs.current.isEmpty())
    }

    @Test
    fun `each failed save points at the topmost problem`() {
        val editor = editor()

        editor.onAction(EditorAction.Save)
        assertEquals(1, editor.state.value.failedSaves)
        assertEquals(ProblemSpot.ARABIC, editor.state.value.firstProblemSpot())

        editor.onAction(EditorAction.ArabicChanged("سُبْحَانَ ٱللَّهِ"))
        assertNull(editor.state.value.firstProblemSpot())
        editor.onAction(EditorAction.Save)
        assertEquals(2, editor.state.value.failedSaves)
        assertEquals(ProblemSpot.TITLE, editor.state.value.firstProblemSpot())

        editor.onAction(EditorAction.TitleChanged("Tasbih"))
        editor.onAction(EditorAction.Save)
        assertTrue(editor.state.value.isDone)
        assertEquals(2, editor.state.value.failedSaves)
    }

    @Test
    fun `problems no field shows point at the summary line`() {
        val limit = EditorUiState(problems = mapOf(ProblemSpot.SUMMARY to EditorProblem.LIMIT_REACHED))
        assertEquals(ProblemSpot.SUMMARY, limit.firstProblemSpot())
        val tooMany = EditorUiState().problemsOf(listOf(FieldError("/references", FieldErrorCode.TOO_MANY)))
        assertEquals(mapOf(ProblemSpot.SUMMARY to EditorProblem.TOO_MANY_REFERENCES), tooMany)
    }

    @Test
    fun `an invalid Qur'an reference is marked on the field that's wrong`() {
        val editor = editor()
        editor.onAction(EditorAction.ArabicChanged("قُلْ هُوَ ٱللَّهُ أَحَدٌ"))
        editor.onAction(EditorAction.TitleChanged("Ikhlas"))

        editor.onAction(EditorAction.QuranChanged(QuranFields("115", "1", "")))
        editor.onAction(EditorAction.Save)
        assertEquals(mapOf(ProblemSpot(EditorField.SURAH) to EditorProblem.QURAN_INVALID), editor.state.value.problems)

        editor.onAction(EditorAction.QuranChanged(QuranFields("112", "0", "")))
        editor.onAction(EditorAction.Save)
        assertEquals(ProblemSpot(EditorField.AYAH_START), editor.state.value.firstProblemSpot())

        editor.onAction(EditorAction.QuranChanged(QuranFields("112", "4", "1")))
        editor.onAction(EditorAction.Save)
        assertEquals(
            mapOf(ProblemSpot(EditorField.AYAH_END) to EditorProblem.QURAN_RANGE),
            editor.state.value.problems,
        )
        assertEquals(3, editor.state.value.failedSaves)
        assertTrue(dhikrs.current.isEmpty())
    }

    @Test
    fun `an invalid kept reference is marked on its own row`() {
        val dhikrs = FakeCustomDhikrRepository(listOf(EXISTING.copy(references = MISSING_TITLE)))
        val editor = CustomDhikrEditorViewModel(EXISTING.id.value, dhikrs, tags, players, audio)

        editor.onAction(EditorAction.Save)

        val kept = ProblemSpot.kept(1)
        assertEquals(mapOf(kept to EditorProblem.KEPT_REFERENCE_INVALID), editor.state.value.problems)
        assertEquals(kept, editor.state.value.firstProblemSpot())

        editor.onAction(EditorAction.RemoveKeptReference(1))
        assertTrue(editor.state.value.problems.isEmpty())
        editor.onAction(EditorAction.Save)
        assertTrue(editor.state.value.isDone)
        assertEquals(MISSING_TITLE.take(1), dhikrs.current.single().references)
    }

    @Test
    fun `reference errors, the rules' or a rejected receipt's, land on the row saved at that index`() {
        // Saved as: the Qur'an reference (0), the kept hadith (1), then "Muslim" (2) and "Long" (3); the blank
        // reference isn't saved.
        val form = EditorUiState(
            quran = QuranFields("2", "255", ""),
            kept = listOf(Reference.Hadith("abu-dawud", "Sunan Abi Dawud")),
            otherReferences = listOf("Muslim", " ", "Long"),
        )
        val errors = listOf(
            FieldError("/document/references/0/ayah_end", FieldErrorCode.RANGE),
            FieldError("/document/references/1/number", FieldErrorCode.REQUIRED),
            FieldError("/document/references/3", FieldErrorCode.TOO_LONG),
            FieldError("/references/2", FieldErrorCode.INVALID),
            FieldError("/references/9", FieldErrorCode.INVALID),
            FieldError("/document/title", FieldErrorCode.REQUIRED),
        )

        assertEquals(
            mapOf(
                ProblemSpot(EditorField.AYAH_END) to EditorProblem.QURAN_RANGE,
                ProblemSpot.kept(0) to EditorProblem.KEPT_REFERENCE_INVALID,
                ProblemSpot.other(2) to EditorProblem.TEXT_TOO_LONG,
                ProblemSpot.other(0) to EditorProblem.REFERENCE_INVALID,
                ProblemSpot.SUMMARY to EditorProblem.REFERENCE_INVALID,
                ProblemSpot.TITLE to EditorProblem.TITLE_REQUIRED,
            ),
            form.problemsOf(errors),
        )
        // Without the Qur'an reference, the kept one is saved first.
        assertEquals(
            mapOf(ProblemSpot.kept(0) to EditorProblem.KEPT_REFERENCE_INVALID),
            form.copy(quran = QuranFields()).problemsOf(listOf(FieldError("/references/0", FieldErrorCode.INVALID))),
        )
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
    fun `an uploaded recording survives a text edit and save`() = runTest {
        val recording = CustomAudio("file:///profile/audio/mine.mp3", UPLOADED)
        dhikrs.save(EXISTING.copy(audio = recording))
        val editor = editor(EXISTING.id.value)
        assertEquals(UPLOADED, editor.state.value.audio?.uploaded)

        editor.onAction(EditorAction.TitleChanged("Tasbih"))
        editor.onAction(EditorAction.Save)

        assertEquals(recording, dhikrs.current.single().audio)
    }

    @Test
    fun `replacing an uploaded recording drops the account's copy, so the new one uploads`() = runTest {
        dhikrs.save(EXISTING.copy(audio = CustomAudio("file:///profile/audio/mine.mp3", UPLOADED)))
        val editor = editor(EXISTING.id.value)

        editor.onAction(EditorAction.ImportAudio("content://picked/new.m4a"))
        val replaced = editor.state.value.audio?.localUri
        assertNull(editor.state.value.audio?.uploaded)
        editor.onAction(EditorAction.Save)

        assertEquals(CustomAudio(replaced), dhikrs.current.single().audio)
    }

    @Test
    fun `the recording card says where the recording stands`() = runTest {
        dhikrs.save(EXISTING.copy(audio = CustomAudio("file:///profile/audio/mine.mp3")))
        val editor = editor(EXISTING.id.value)
        assertEquals(RecordingPlace.PHONE, editor.state.value.recordingPlace)

        audio.uploads.value = mapOf(EXISTING.id to RecordingUpload.QUEUED)
        assertEquals(RecordingPlace.WAITING_TO_UPLOAD, editor.state.value.recordingPlace)
        audio.uploads.value = mapOf(EXISTING.id to RecordingUpload.FAILED)
        assertEquals(RecordingPlace.PHONE_ONLY, editor.state.value.recordingPlace)

        // A file imported but not saved isn't the one that failed.
        editor.onAction(EditorAction.ImportAudio("content://picked/new.m4a"))
        assertEquals(RecordingPlace.PHONE, editor.state.value.recordingPlace)

        val uploaded = EditorUiState(audio = AudioField(null, isNew = false, uploaded = UPLOADED))
        assertEquals(RecordingPlace.ACCOUNT, uploaded.recordingPlace)
        assertEquals(RecordingPlace.OTHER_DEVICE, EditorUiState(audio = AudioField(null, false)).recordingPlace)
    }

    @Test
    fun `a recording only in the account downloads before it plays, and a failed download says why`() = runTest {
        dhikrs.save(EXISTING.copy(audio = CustomAudio(localUri = null, uploaded = UPLOADED)))
        val editor = editor(EXISTING.id.value)
        assertTrue(editor.state.value.audio?.isPlayable == true)

        audio.downloadError = RecordingDownloadError.OFFLINE
        editor.onAction(EditorAction.TogglePlayback)
        assertEquals(PlaybackStatus.FAILED, editor.state.value.playback.status)
        assertEquals(RecordingDownloadError.OFFLINE, editor.state.value.downloadError)
        assertTrue(players.players.isEmpty())

        audio.files[EXISTING.id] = DOWNLOADED
        editor.onAction(EditorAction.TogglePlayback)
        assertNull(editor.state.value.downloadError)
        val player = players.players.single()
        assertEquals(listOf(DOWNLOADED), player.played)

        // Played to the end, it plays again from the downloaded file without asking again.
        player.emit(PlaybackState(PlaybackStatus.ENDED))
        editor.onAction(EditorAction.TogglePlayback)
        assertEquals(listOf(DOWNLOADED, DOWNLOADED), player.played)
        assertEquals(listOf(EXISTING.id, EXISTING.id), audio.playableCalls)

        // Saving keeps the dhikr's own recording as it was.
        editor.onAction(EditorAction.Save)
        assertEquals(CustomAudio(localUri = null, uploaded = UPLOADED), dhikrs.current.single().audio)
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
        const val DOWNLOADED = "file:///profile/audio/downloaded.mp3"

        val UPLOADED = UploadedAudio(
            assetId = AwradId("0192f0d0-0000-7000-8000-0000000000a1"),
            byteSize = 4_182_733,
            contentType = AudioContentType.MPEG,
            durationMs = 31_250,
        )

        /** A hadith, then a book reference without a title, which can't be saved. */
        val MISSING_TITLE = listOf(Reference.Hadith("abu-dawud", "Sunan Abi Dawud"), Reference.Book("book", " "))

        val EXISTING = CustomDhikr(
            id = AwradId("0192f0d0-0000-7000-8000-000000000001"),
            kind = DhikrKind.DHIKR,
            arabic = "سُبْحَانَ ٱللَّهِ",
            title = OptionalTexts(en = "Subhanallah"),
        )
    }
}
