package app.awrad.core.domain.dhikr

import app.awrad.core.domain.AwradId

/*
 * The dhikr model (contracts/dhikr-catalog/v1, docs/slices/03a-dhikr-catalog.md): one text, recited as a unit.
 * It holds no sequences, occasions or counts; practices, wirds and goals build on it.
 */

/** A language the catalog carries text in, which is also a language the app ships. */
public enum class ContentLanguage(public val code: String) {
    EN("en"),
    AR("ar"),
    ML("ml"),
    ;

    public companion object {
        /** The language for [code] (`en`, `ar`, `ml`), or null when the catalog has none. */
        public fun fromCode(code: String): ContentLanguage? = entries.firstOrNull { it.code == code }

        /**
         * The language the app shows for the configured [languageCodes] (most preferred first): the first one the
         * app ships, else English, as Android resolves `values`, `values-ar` and `values-ml`.
         */
        public fun of(languageCodes: List<String>): ContentLanguage =
            languageCodes.firstNotNullOfOrNull(::fromCode) ?: EN
    }
}

/** Text in English and, optionally, Arabic and Malayalam. Missing languages fall back to English. */
public data class LocalizedText(
    val en: String,
    val ar: String? = null,
    val ml: String? = null,
) {
    /** The text in [language] only, or null when it has none. */
    public operator fun get(language: ContentLanguage): String? = when (language) {
        ContentLanguage.EN -> en
        ContentLanguage.AR -> ar
        ContentLanguage.ML -> ml
    }

    /** The text in [language], else English. */
    public fun localized(language: ContentLanguage): String = this[language] ?: en

    /** Every language's text, English first. */
    public val all: List<String> get() = listOfNotNull(en, ar, ml)
}

/** How a dhikr is rendered. */
public enum class DhikrKind {
    /** Qur'an: one ayah per line, with its reference label. */
    QURAN,
    DHIKR,
    DUA,
    SALAWAT,

    /** One of the Asma-ul Husna: the name large, then its meaning. */
    NAME_OF_ALLAH,
}

/**
 * The transliteration in each language's script: [en] is Latin, [ml] Malayalam. Arabic has none, since the
 * Arabic is the text itself.
 */
public data class Transliteration(val en: String, val ml: String? = null) {
    public val all: List<String> get() = listOfNotNull(en, ml)
}

/** A catalog topic tag, such as `debt` (separate from the tags users make for themselves). */
public data class CatalogTag(val key: String, val title: LocalizedText)

/** How a recording is performed. */
public enum class AudioStyle { RECITATION, MELODIC, TEACHING }

/**
 * A dhikr's one recording, streamed from [url]. [repetitions] is how many recitations one play contains.
 */
public data class Audio(
    val url: String,
    val style: AudioStyle,
    val repetitions: Int,
    val reciter: LocalizedText? = null,
    val durationMs: Long? = null,
    val byteSize: Long? = null,
    val mimeType: String? = null,
    val sha256: String? = null,
    val attribution: String? = null,
)

/** A virtue of a dhikr, always citing at least one of the dhikr's own [references]. */
public data class Virtue(val text: LocalizedText, val references: List<Reference>)

/**
 * One dhikr. [id] and [key] are immutable identity (ADR-2026-07-13); goals and wirds reference [id]. [arabic] is
 * the recited text with harakat; its line breaks are meaningful (one ayah per line for Qur'an). [aliases] are
 * extra search terms, never shown as text.
 */
public data class Dhikr(
    val id: AwradId,
    val key: String,
    val kind: DhikrKind,
    val arabic: String,
    val title: LocalizedText,
    val transliteration: Transliteration,
    val translation: LocalizedText,
    val aliases: Map<ContentLanguage, List<String>> = emptyMap(),
    val tags: List<CatalogTag> = emptyList(),
    val audio: Audio? = null,
    val references: List<Reference> = emptyList(),
    val virtues: List<Virtue> = emptyList(),
) {
    /** The Arabic, one line (one ayah, for Qur'an) per entry. */
    public val arabicLines: List<String> get() = arabic.lines().filter { it.isNotBlank() }

    /** The Qur'an reference a Qur'an dhikr shows in its Arabic card, under the ayahs; null for other kinds. */
    public val cardReference: Reference.Quran?
        get() = references.filterIsInstance<Reference.Quran>().firstOrNull().takeIf { kind == DhikrKind.QURAN }

    /**
     * The detail page's "Sources" (components.md, "Dhikr detail screen"): the references not already shown, in
     * the dhikr's order. That leaves out those a virtue cites and the [cardReference]. A custom dhikr has no
     * virtues, so it lists all of its own.
     */
    public val sources: List<Reference>
        get() {
            val shown = virtues.flatMapTo(HashSet()) { virtue -> virtue.references.map { it.id } }
            val card = cardReference
            return references.filter { it.id !in shown && it != card }
        }
}

/** An ordered list of dhikrs with a title. A dhikr can be in several collections. */
public data class Collection(val key: String, val title: LocalizedText, val dhikrs: List<Dhikr>)

/**
 * The built-in dhikrs and collections shipped with the app (contracts/dhikr-catalog/v1/catalog.json), read-only
 * and in memory. [contentRevision] goes up with every change to what users see.
 */
public class DhikrCatalog(
    public val contentRevision: Int,
    public val dhikrs: List<Dhikr>,
    public val collections: List<Collection>,
    public val tags: List<CatalogTag>,
) {
    private val dhikrsByKey = dhikrs.associateBy { it.key }
    private val dhikrsById = dhikrs.associateBy { it.id }
    private val collectionsByKey = collections.associateBy { it.key }

    /** The dhikr with [key], or null. */
    public fun dhikr(key: String): Dhikr? = dhikrsByKey[key]

    /** The dhikr with [id], or null. */
    public fun dhikr(id: AwradId): Dhikr? = dhikrsById[id]

    /** The collection with [key], or null. */
    public fun collection(key: String): Collection? = collectionsByKey[key]

    public companion object {
        /**
         * Parses `catalog.json`. Fails on anything the app doesn't know (an unknown key, kind or reference type)
         * and on a broken link: a collection, tag or virtue naming something that isn't there.
         */
        public fun parse(json: String): DhikrCatalog = CatalogJson.parse(json)
    }
}
