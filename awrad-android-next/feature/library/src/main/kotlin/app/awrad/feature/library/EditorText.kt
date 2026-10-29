package app.awrad.feature.library

import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.res.stringResource
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.personal.AudioImportError
import app.awrad.core.domain.personal.RecordingDownloadError

/*
 * The editor's words that come from resources: kinds, languages and problems, typed in, text out.
 */

@Composable
@ReadOnlyComposable
internal fun kindName(kind: DhikrKind): String = stringResource(
    when (kind) {
        DhikrKind.QURAN -> R.string.editor_kind_quran
        DhikrKind.DHIKR -> R.string.editor_kind_dhikr
        DhikrKind.DUA -> R.string.editor_kind_dua
        DhikrKind.SALAWAT -> R.string.editor_kind_salawat
        DhikrKind.NAME_OF_ALLAH -> R.string.editor_kind_name_of_allah
    },
)

/** Each language in its own script, as language pickers show them. */
@Composable
@ReadOnlyComposable
internal fun languageName(language: ContentLanguage): String = stringResource(
    when (language) {
        ContentLanguage.EN -> R.string.editor_language_en
        ContentLanguage.AR -> R.string.editor_language_ar
        ContentLanguage.ML -> R.string.editor_language_ml
    },
)

@Composable
@ReadOnlyComposable
internal fun problemText(problem: EditorProblem): String = stringResource(
    when (problem) {
        EditorProblem.ARABIC_REQUIRED -> R.string.editor_problem_arabic
        EditorProblem.ARABIC_TOO_LONG, EditorProblem.TEXT_TOO_LONG -> R.string.editor_problem_too_long
        EditorProblem.TITLE_REQUIRED -> R.string.editor_problem_title
        EditorProblem.QURAN_INVALID -> R.string.editor_problem_quran
        EditorProblem.QURAN_RANGE -> R.string.editor_problem_quran_range
        EditorProblem.REFERENCE_INVALID -> R.string.editor_problem_reference
        EditorProblem.KEPT_REFERENCE_INVALID -> R.string.editor_problem_kept_reference
        EditorProblem.TOO_MANY_REFERENCES -> R.string.editor_problem_references
        EditorProblem.LIMIT_REACHED -> R.string.editor_problem_limit
        EditorProblem.NOT_SAVED -> R.string.editor_problem_not_saved
    },
)

@Composable
@ReadOnlyComposable
internal fun audioErrorText(error: AudioImportError): String = stringResource(
    when (error) {
        AudioImportError.TOO_LARGE -> R.string.editor_audio_too_large
        AudioImportError.UNSUPPORTED_TYPE -> R.string.editor_audio_unsupported
        AudioImportError.UNREADABLE -> R.string.editor_audio_unreadable
    },
)

@Composable
@ReadOnlyComposable
internal fun recordingPlaceText(place: RecordingPlace): String = stringResource(
    when (place) {
        RecordingPlace.ACCOUNT -> R.string.editor_recording_account
        RecordingPlace.WAITING_TO_UPLOAD -> R.string.editor_recording_waiting
        RecordingPlace.PHONE_ONLY -> R.string.editor_recording_phone_only
        RecordingPlace.PHONE -> R.string.editor_recording_here
        RecordingPlace.OTHER_DEVICE -> R.string.editor_recording_elsewhere
    },
)

/** Why an uploaded recording couldn't be downloaded to play. */
@Composable
@ReadOnlyComposable
internal fun downloadErrorText(error: RecordingDownloadError): String = stringResource(
    when (error) {
        RecordingDownloadError.OFFLINE -> R.string.editor_download_offline
        RecordingDownloadError.NOT_SIGNED_IN -> R.string.editor_download_not_signed_in
        RecordingDownloadError.NOT_FOUND -> R.string.editor_download_not_found
        RecordingDownloadError.FAILED -> R.string.editor_download_failed
    },
)
