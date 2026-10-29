package app.awrad.core.domain.personal

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.AudioContentType
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
 * A custom dhikr's recording. [localUri] is its file in the profile's private storage (imported here, or
 * downloaded on first play), or null when it isn't on this phone. [uploaded] is the account's copy once the upload
 * is confirmed (slice 3c); null while the recording is only on the phone that imported it (`{"local_only": true}`).
 */
public data class CustomAudio(val localUri: String?, val uploaded: UploadedAudio? = null)

/**
 * A recording in the account's private storage (`$defs/uploaded_audio`): the ready asset's ID, size and type, and
 * the length the importing phone measured, or null when it couldn't.
 */
public data class UploadedAudio(
    val assetId: AwradId,
    val byteSize: Long,
    val contentType: AudioContentType,
    val durationMs: Long?,
)

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
 * missing languages fall back to any text there is, and the recording plays from its local file. An uploaded
 * recording that isn't on this phone yet has no URL here: it's downloaded on its first play.
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
