package app.awrad.core.domain.dhikr

/**
 * The text of a dhikr for an app showing one language: [title], [transliteration] (null when there's none to
 * show) and [translation].
 */
public data class DhikrText(
    val title: String,
    val transliteration: String?,
    val translation: String,
)

/**
 * What a dhikr shows in [language] (docs/slices/03a-dhikr-catalog.md, "Display language"): the title,
 * transliteration and translation in that language, else in English. Arabic shows no transliteration, since the
 * Arabic text is already there.
 */
public fun Dhikr.textIn(language: ContentLanguage): DhikrText = DhikrText(
    title = title.localized(language),
    transliteration = when (language) {
        ContentLanguage.AR -> null
        ContentLanguage.EN -> transliteration.en
        ContentLanguage.ML -> transliteration.ml ?: transliteration.en
    },
    translation = translation.localized(language),
)
