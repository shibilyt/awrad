package app.awrad.core.domain.dhikr

/** Where a dhikr's text or a virtue comes from. [id] is unique within its dhikr; virtues point at it. */
public sealed interface Reference {
    public val id: String

    /** Surah [surah], ayat [ayahStart] to [ayahEnd] (equal for one ayah). */
    public data class Quran(
        override val id: String,
        val surah: Int,
        val ayahStart: Int,
        val ayahEnd: Int,
    ) : Reference

    public data class Hadith(
        override val id: String,
        val collection: String,
        val number: String? = null,
        val narrator: String? = null,
        val grade: String? = null,
    ) : Reference

    public data class Book(
        override val id: String,
        val title: String,
        val author: String? = null,
        val volume: String? = null,
        val page: String? = null,
    ) : Reference

    public data class Shaykh(override val id: String, val name: String, val note: String? = null) : Reference

    public data class Other(override val id: String, val text: String, val url: String? = null) : Reference
}

/** A reference as it's shown: one line of [text], and a [url] to open when there is one. */
public data class ReferenceLabel(val text: String, val url: String? = null)

/** Left-to-right isolate: keeps "112:1–4" in order inside right-to-left text. */
private const val LTR_ISOLATE = '\u2066'
private const val POP_ISOLATE = '\u2069'
private const val SEPARATOR = " · "

/**
 * The citation for this reference, with [quranWord] being "Qur'an" in the app's language:
 * - Qur'an: "Qur'an 112:1–4", or "Qur'an 71:10" for one ayah;
 * - hadith: the collection and number, then the grade if there is one ("Sunan Abi Dawud 1518 · Da'if");
 * - book: the title, the author and volume:page, as far as they're known;
 * - shaykh: the name;
 * - other: the text, with its link.
 * Numbers sit in a left-to-right isolate, so they keep their order in Arabic.
 */
public fun Reference.label(quranWord: String): ReferenceLabel = when (this) {
    is Reference.Quran -> {
        val ayat = if (ayahStart == ayahEnd) "$ayahStart" else "$ayahStart–$ayahEnd"
        ReferenceLabel("$quranWord ${isolate("$surah:$ayat")}")
    }
    is Reference.Hadith -> ReferenceLabel(
        listOfNotNull(listOfNotNull(collection, number).joinToString(" "), grade).joinToString(SEPARATOR),
    )
    is Reference.Book -> {
        val location = listOfNotNull(volume, page).joinToString(":").takeIf { it.isNotEmpty() }?.let(::isolate)
        ReferenceLabel(listOfNotNull(title, author, location).joinToString(", "))
    }
    is Reference.Shaykh -> ReferenceLabel(name)
    is Reference.Other -> ReferenceLabel(text, url)
}

private fun isolate(text: String): String = "$LTR_ISOLATE$text$POP_ISOLATE"
