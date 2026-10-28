package app.awrad.feature.library

import app.awrad.core.domain.sync.FieldError
import app.awrad.core.domain.sync.FieldErrorCode

/** What the editor checks or was told, mapped to text by the screen. */
internal enum class EditorProblem {
    ARABIC_REQUIRED,
    ARABIC_TOO_LONG,
    TITLE_REQUIRED,
    TEXT_TOO_LONG,
    QURAN_INVALID,

    /** The Qur'an reference ends before it starts (field error `range` on `ayah_end`). */
    QURAN_RANGE,

    /** A free-text reference the rules don't accept. */
    REFERENCE_INVALID,

    /** A reference of another type the dhikr already had (shown as it is, not edited) that the rules don't accept. */
    KEPT_REFERENCE_INVALID,
    TOO_MANY_REFERENCES,
    LIMIT_REACHED,

    /** The profile changed while saving (signing in as another account). */
    NOT_SAVED,
}

/**
 * The places a problem shows, top to bottom: the summary line above the form (for problems of the whole dhikr),
 * the Arabic text, the title, the Qur'an reference's three fields, the kept references and the other references.
 */
internal enum class EditorField { SUMMARY, ARABIC, TITLE, SURAH, AYAH_START, AYAH_END, KEPT_REFERENCE, OTHER_REFERENCE }

/** Where a problem shows: [field], and for a kept or other reference its [row] (its index in that list). */
internal data class ProblemSpot(val field: EditorField, val row: Int = 0) : Comparable<ProblemSpot> {
    override fun compareTo(other: ProblemSpot): Int = compareValuesBy(this, other, { it.field }, { it.row })

    companion object {
        val SUMMARY = ProblemSpot(EditorField.SUMMARY)
        val ARABIC = ProblemSpot(EditorField.ARABIC)
        val TITLE = ProblemSpot(EditorField.TITLE)

        fun kept(row: Int) = ProblemSpot(EditorField.KEPT_REFERENCE, row)

        fun other(row: Int) = ProblemSpot(EditorField.OTHER_REFERENCE, row)
    }
}

/** Where a failed save takes the reader: the topmost place showing one of [EditorUiState.problems]; null without. */
internal fun EditorUiState.firstProblemSpot(): ProblemSpot? = problems.keys.minOrNull()

/**
 * Where each of [errors] shows in this form, as it was saved. The errors are the shared validity rules'
 * (`custom_dhikr_validity`) or a `rejected` receipt's, which carry the same pointers under `/document`. A
 * `/references/N/…` error lands on the reference the document has at N: references are saved as the Qur'an
 * reference (when filled in), the kept ones, then the other references that aren't blank. Where two problems share
 * a place, the first in [EditorProblem]'s order shows.
 */
internal fun EditorUiState.problemsOf(errors: List<FieldError>): Map<ProblemSpot, EditorProblem> = errors
    .map { problemOf(it.field.withoutDocument().removePrefix("/").split("/"), it.code) }
    .groupBy({ it.first }, { it.second })
    .mapValues { (_, problems) -> problems.min() }

private fun EditorUiState.problemOf(path: List<String>, code: FieldErrorCode): Pair<ProblemSpot, EditorProblem> {
    val tooLong = code == FieldErrorCode.TOO_LONG
    return when (path.first()) {
        "arabic" -> ProblemSpot.ARABIC to if (tooLong) EditorProblem.ARABIC_TOO_LONG else EditorProblem.ARABIC_REQUIRED
        "title" -> ProblemSpot.TITLE to if (tooLong) EditorProblem.TEXT_TOO_LONG else EditorProblem.TITLE_REQUIRED
        "references" -> path.getOrNull(1)?.toIntOrNull()?.let { referenceProblem(it, path.getOrNull(2), code) }
            ?: (ProblemSpot.SUMMARY to EditorProblem.TOO_MANY_REFERENCES)
        else -> ProblemSpot.TITLE to EditorProblem.TEXT_TOO_LONG
    }
}

/** The problem with the document's reference at [index]; [member] is the reference's field the error names. */
private fun EditorUiState.referenceProblem(
    index: Int,
    member: String?,
    code: FieldErrorCode,
): Pair<ProblemSpot, EditorProblem> {
    val quranRows = if (quran.isEmpty) 0 else 1
    val keptRow = index - quranRows
    val otherRows = otherReferences.indices.filter { otherReferences[it].isNotBlank() }
    val otherRow = otherRows.getOrNull(keptRow - kept.size)
    return when {
        index < quranRows -> quranProblem(member, code)
        keptRow < kept.size -> ProblemSpot.kept(keptRow) to EditorProblem.KEPT_REFERENCE_INVALID
        otherRow != null -> ProblemSpot.other(otherRow) to
            if (code == FieldErrorCode.TOO_LONG) EditorProblem.TEXT_TOO_LONG else EditorProblem.REFERENCE_INVALID
        else -> ProblemSpot.SUMMARY to EditorProblem.REFERENCE_INVALID
    }
}

/** On the Qur'an field [member] names; for the reference as a whole, the first field whose number can't be right. */
private fun EditorUiState.quranProblem(member: String?, code: FieldErrorCode): Pair<ProblemSpot, EditorProblem> {
    val field = when (member) {
        "surah" -> EditorField.SURAH
        "ayah_start" -> EditorField.AYAH_START
        "ayah_end" -> EditorField.AYAH_END
        else -> quran.firstWrongField()
    }
    val problem = if (code == FieldErrorCode.RANGE) EditorProblem.QURAN_RANGE else EditorProblem.QURAN_INVALID
    return ProblemSpot(field) to problem
}

private fun QuranFields.firstWrongField(): EditorField {
    val start = ayahStart.trim()
    return when {
        surah.trim().toIntOrNull()?.let { it in 1..SURAHS } != true -> EditorField.SURAH
        start.toIntOrNull()?.let { it >= 1 } != true -> EditorField.AYAH_START
        ayahEnd.trim().ifEmpty { start }.toIntOrNull()?.let { it >= 1 } != true -> EditorField.AYAH_END
        else -> EditorField.SURAH
    }
}

/** A `rejected` receipt's pointer (`/document/…`) as a pointer into the document itself. */
private fun String.withoutDocument(): String =
    if (this == DOCUMENT || startsWith("$DOCUMENT/")) removePrefix(DOCUMENT) else this

private const val DOCUMENT = "/document"
private const val SURAHS = 114
