package app.awrad.core.domain.personal

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.dhikr.Audio
import app.awrad.core.domain.dhikr.AudioStyle
import app.awrad.core.domain.dhikr.ContentLanguage
import app.awrad.core.domain.dhikr.Dhikr
import app.awrad.core.domain.dhikr.DhikrKind
import app.awrad.core.domain.dhikr.LocalizedText
import app.awrad.core.domain.dhikr.Reference
import app.awrad.core.domain.dhikr.Transliteration

/** Text in each of the app's languages, any of which may be missing. */
public data class OptionalTexts(val en: String? = null, val ar: String? = null, val ml: String? = null) {
    public operator fun get(language: ContentLanguage): String? = when (language) {
        ContentLanguage.EN -> en
        ContentLanguage.AR -> ar
        ContentLanguage.ML -> ml
    }

    /** The text in [language], then English, then any language; null when there's none. */
    public fun preferred(language: ContentLanguage): String? = this[language] ?: en ?: ar ?: ml

    /** Every text there is, English first. */
    public val all: List<String> get() = listOfNotNull(en, ar, ml)
}

/** A transliteration in Latin ([en]) and Malayalam ([ml]) script. Arabic has none. */
public data class CustomTransliteration(val en: String? = null, val ml: String? = null)

/**
 * A custom dhikr's recording. In slice 3b it never leaves the phone that imported it: [localUri] is the file in
 * the profile's private storage, or null when the recording was made on another device.
 */
public data class CustomAudio(val localUri: String?)

/**
 * A user's own dhikr (CONTEXT.md, "Custom dhikr"): the built-in dhikr's shape (ADR-2026-10-27), with its kind,
 * Arabic text, per-language title, transliteration and translation, and references, but no key, aliases, catalog
 * tags or virtues. Its user tags live in its personal record. The document it syncs as is
 * `$defs/custom_dhikr_document` ([CustomDhikrJson]).
 */
public data class CustomDhikr(
    val id: AwradId,
    val kind: DhikrKind,
    val arabic: String,
    val title: OptionalTexts,
    val transliteration: CustomTransliteration = CustomTransliteration(),
    val translation: OptionalTexts = OptionalTexts(),
    val references: List<Reference> = emptyList(),
    val audio: CustomAudio? = null,
) {
    public companion object {
        /** How many custom dhikrs an account may have. */
        public const val LIMIT: Int = 1_000

        /** How many references one may cite. */
        public const val MAX_REFERENCES: Int = 20

        /** Code points per title, and per Arabic text, transliteration and translation. */
        public const val MAX_TITLE: Int = 120
        public const val MAX_TEXT: Int = 5_000
    }
}

/** What a custom dhikr shows in one language: the title, and the transliteration and translation if any. */
public data class CustomDhikrText(val title: String, val transliteration: String?, val translation: String?)

/**
 * The text in [language]: the title and translation in it, then English, then any; the transliteration in it
 * (Malayalam falls back to Latin script), and none in Arabic, whose text is already there.
 */
public fun CustomDhikr.textIn(language: ContentLanguage): CustomDhikrText = CustomDhikrText(
    title = title.preferred(language).orEmpty(),
    transliteration = when (language) {
        ContentLanguage.AR -> null
        ContentLanguage.EN -> transliteration.en
        ContentLanguage.ML -> transliteration.ml ?: transliteration.en
    },
    translation = translation.preferred(language),
)

/**
 * This dhikr as the library shows dhikrs, so it lists, searches and plays like a built-in. Its key is its ID;
 * missing languages fall back to any text there is, and the recording plays from its local file.
 */
public fun CustomDhikr.asDhikr(): Dhikr = Dhikr(
    id = id,
    key = id.value,
    kind = kind,
    arabic = arabic,
    title = LocalizedText(en = title.preferred(ContentLanguage.EN).orEmpty(), ar = title.ar, ml = title.ml),
    transliteration = Transliteration(en = transliteration.en.orEmpty(), ml = transliteration.ml),
    translation = LocalizedText(
        en = translation.preferred(ContentLanguage.EN).orEmpty(),
        ar = translation.ar,
        ml = translation.ml,
    ),
    audio = audio?.localUri?.let { Audio(url = it, style = AudioStyle.RECITATION, repetitions = 1) },
    references = references,
)
