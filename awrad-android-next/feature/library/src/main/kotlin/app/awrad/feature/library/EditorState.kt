package app.awrad.feature.library

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.PlaybackState
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.dhikr.Reference
import app.awrad.core.domain.personal.AudioImportError
import app.awrad.core.domain.personal.CustomAudio
import app.awrad.core.domain.personal.CustomDhikr
import app.awrad.core.domain.personal.CustomTransliteration
import app.awrad.core.domain.personal.OptionalTexts
import app.awrad.core.domain.personal.UserTag
import app.awrad.core.domain.sync.FieldError
import app.awrad.core.domain.sync.FieldErrorCode

/** One text per app language, as typed. */
internal data class LanguageFields(val en: String = "", val ar: String = "", val ml: String = "") {
    operator fun get(language: ContentLanguage): String = when (language) {
        ContentLanguage.EN -> en
        ContentLanguage.AR -> ar
        ContentLanguage.ML -> ml
    }

    fun with(language: ContentLanguage, text: String): LanguageFields = when (language) {
        ContentLanguage.EN -> copy(en = text)
        ContentLanguage.AR -> copy(ar = text)
        ContentLanguage.ML -> copy(ml = text)
    }

    fun toTexts(): OptionalTexts = OptionalTexts(en.trimmedOrNull(), ar.trimmedOrNull(), ml.trimmedOrNull())

    companion object {
        fun of(texts: OptionalTexts) = LanguageFields(texts.en.orEmpty(), texts.ar.orEmpty(), texts.ml.orEmpty())
    }
}

/** The optional Qur'an reference, as typed: all empty means none. */
internal data class QuranFields(val surah: String = "", val ayahStart: String = "", val ayahEnd: String = "") {
    val isEmpty: Boolean get() = surah.isBlank() && ayahStart.isBlank() && ayahEnd.isBlank()
}

/** The recording being edited: [localUri] is null when it was made on another device. */
internal data class AudioField(val localUri: String?, val isNew: Boolean)

/** What the editor checks or was told, mapped to text by the screen. */
internal enum class EditorProblem {
    ARABIC_REQUIRED,
    ARABIC_TOO_LONG,
    TITLE_REQUIRED,
    TEXT_TOO_LONG,
    QURAN_INVALID,
    REFERENCE_INVALID,
    TOO_MANY_REFERENCES,
    LIMIT_REACHED,

    /** The profile changed while saving (signing in as another account). */
    NOT_SAVED,
}

/**
 * The custom dhikr editor. [shownLanguage] picks which language's title, transliteration and translation are
 * shown (the three are compact, one language at a time). [otherReferences] are free-text references; [kept] are
 * references of other types the dhikr already had, kept as they are. [problems] are the last save's.
 */
internal data class EditorUiState(
    val isLoading: Boolean = true,
    val isNew: Boolean = true,
    val kind: DhikrKind = DhikrKind.DHIKR,
    val arabic: String = "",
    val titles: LanguageFields = LanguageFields(),
    val transliterations: LanguageFields = LanguageFields(),
    val translations: LanguageFields = LanguageFields(),
    val shownLanguage: ContentLanguage = ContentLanguage.EN,
    val quran: QuranFields = QuranFields(),
    val otherReferences: List<String> = emptyList(),
    val kept: List<Reference> = emptyList(),
    val audio: AudioField? = null,
    val audioError: AudioImportError? = null,
    val playback: PlaybackState = PlaybackState(),
    val tags: List<UserTag> = emptyList(),
    val selectedTags: List<AwradId> = emptyList(),
    val problems: Set<EditorProblem> = emptySet(),
    val isSaving: Boolean = false,
    val isDeleteConfirmOpen: Boolean = false,
    /** Saved or deleted: the editor closes. */
    val isDone: Boolean = false,
)

internal sealed interface EditorAction {
    data class KindChanged(val kind: DhikrKind) : EditorAction

    data class ArabicChanged(val text: String) : EditorAction

    data class LanguageShown(val language: ContentLanguage) : EditorAction

    data class TitleChanged(val text: String) : EditorAction

    data class TransliterationChanged(val text: String) : EditorAction

    data class TranslationChanged(val text: String) : EditorAction

    data class QuranChanged(val quran: QuranFields) : EditorAction

    data object AddReference : EditorAction

    data class ReferenceChanged(val index: Int, val text: String) : EditorAction

    data class RemoveReference(val index: Int) : EditorAction

    data class RemoveKeptReference(val index: Int) : EditorAction

    /** A file the user picked (a content URI), to import as the recording. */
    data class ImportAudio(val sourceUri: String) : EditorAction

    data object RemoveAudio : EditorAction

    data object TogglePlayback : EditorAction

    data class TagToggled(val tagId: AwradId) : EditorAction

    data object Save : EditorAction

    data object AskDelete : EditorAction

    data object CancelDelete : EditorAction

    data object ConfirmDelete : EditorAction
}

/** The dhikr these fields describe, with [id]; references in order: the Qur'an, kept ones, then the others. */
internal fun EditorUiState.toDhikr(id: AwradId): CustomDhikr {
    val quran = quran.takeUnless { it.isEmpty }?.let {
        Reference.Quran(
            id = QURAN_REFERENCE_ID,
            surah = it.surah.trim().toIntOrNull() ?: 0,
            ayahStart = it.ayahStart.trim().toIntOrNull() ?: 0,
            ayahEnd = (it.ayahEnd.trim().ifEmpty { it.ayahStart.trim() }).toIntOrNull() ?: 0,
        )
    }
    val usedIds = (listOfNotNull(quran) + kept).map { it.id }.toMutableSet()
    val others = otherReferences.mapNotNull { it.trimmedOrNull() }.map { text ->
        val id = generateSequence(1) { it + 1 }.map { "$OTHER_REFERENCE_PREFIX$it" }.first { it !in usedIds }
        usedIds += id
        Reference.Other(id = id, text = text)
    }
    return CustomDhikr(
        id = id,
        kind = kind,
        arabic = arabic.trim(),
        title = titles.toTexts(),
        transliteration = transliterations.toTexts().let { CustomTransliteration(it.en, it.ml) },
        translation = translations.toTexts(),
        references = listOfNotNull(quran) + kept + others,
        audio = audio?.let { CustomAudio(it.localUri) },
    )
}

/** The editor's fields for [dhikr]. */
internal fun EditorUiState.loaded(dhikr: CustomDhikr): EditorUiState {
    val quran = dhikr.references.filterIsInstance<Reference.Quran>().firstOrNull()
    return copy(
        isLoading = false,
        isNew = false,
        kind = dhikr.kind,
        arabic = dhikr.arabic,
        titles = LanguageFields.of(dhikr.title),
        transliterations = LanguageFields(
            en = dhikr.transliteration.en.orEmpty(),
            ml = dhikr.transliteration.ml.orEmpty(),
        ),
        translations = LanguageFields.of(dhikr.translation),
        quran = quran?.let { QuranFields(it.surah.toString(), it.ayahStart.toString(), it.ayahEnd.toString()) }
            ?: QuranFields(),
        otherReferences = dhikr.references
            .filterIsInstance<Reference.Other>()
            .filter { it.url == null }
            .map { it.text },
        kept = dhikr.references.filterNot { it == quran || (it is Reference.Other && it.url == null) },
        audio = dhikr.audio?.let { AudioField(it.localUri, isNew = false) },
    )
}

/** The problems [errors] (from the shared validity rules) point at; [hasQuran] puts the Qur'an reference first. */
internal fun problemsOf(errors: List<FieldError>, hasQuran: Boolean): Set<EditorProblem> = errors.map { error ->
    when {
        error.field == "/arabic" && error.code == FieldErrorCode.TOO_LONG -> EditorProblem.ARABIC_TOO_LONG
        error.field == "/arabic" -> EditorProblem.ARABIC_REQUIRED
        error.field == "/title" -> EditorProblem.TITLE_REQUIRED
        error.field == "/references" -> EditorProblem.TOO_MANY_REFERENCES
        error.field == "/references/0" && hasQuran -> EditorProblem.QURAN_INVALID
        error.field.startsWith("/references/") -> EditorProblem.REFERENCE_INVALID
        else -> EditorProblem.TEXT_TOO_LONG
    }
}.toSet()

private fun String.trimmedOrNull(): String? = trim().takeIf { it.isNotEmpty() }

private const val QURAN_REFERENCE_ID = "quran"
private const val OTHER_REFERENCE_PREFIX = "r"
