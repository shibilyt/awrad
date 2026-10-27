package app.awrad.core.domain.dhikr

import app.awrad.core.domain.AwradId
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Reads `catalog.json` (`urn:awrad:dhikr-catalog:1`) into the domain types. The JSON shapes below mirror the
 * schema; the decoder is strict, so a key, kind, style or reference type the app doesn't know fails instead of
 * being dropped (build-logic's `DhikrCatalogTask` fails the build on the same thing first).
 */
internal object CatalogJson {

    private const val VERSION = 1

    private val json = Json { ignoreUnknownKeys = false }

    fun parse(text: String): DhikrCatalog {
        val root = json.decodeFromString<CatalogDocument>(text)
        require(root.version == VERSION) { "Unsupported dhikr catalog version ${root.version}" }
        val tags = root.tags.map { CatalogTag(it.key, it.title.toDomain()) }
        val tagsByKey = tags.associateBy { it.key }
        val dhikrs = root.dhikrs.map { it.toDomain(tagsByKey) }
        val dhikrsByKey = dhikrs.associateBy { it.key }
        require(dhikrsByKey.size == dhikrs.size) { "Duplicate dhikr keys in the catalog" }
        val collections = root.collections.map { collection ->
            Collection(
                key = collection.key,
                title = collection.title.toDomain(),
                dhikrs = collection.dhikrs.map { key ->
                    requireNotNull(dhikrsByKey[key]) { "Collection ${collection.key} names unknown dhikr $key" }
                },
            )
        }
        return DhikrCatalog(root.contentRevision, dhikrs, collections, tags)
    }

    private fun DhikrDocument.toDomain(tagsByKey: Map<String, CatalogTag>): Dhikr {
        val references = references.map { it.toDomain() }
        val referencesById = references.associateBy { it.id }
        return Dhikr(
            id = AwradId(id),
            key = key,
            kind = kindOf(kind),
            arabic = arabic,
            title = title.toDomain(),
            transliteration = Transliteration(transliteration.en, transliteration.ml),
            translation = translation.toDomain(),
            aliases = buildMap {
                aliases?.en?.let { put(ContentLanguage.EN, it) }
                aliases?.ar?.let { put(ContentLanguage.AR, it) }
                aliases?.ml?.let { put(ContentLanguage.ML, it) }
            },
            tags = tags.map { requireNotNull(tagsByKey[it]) { "Dhikr $key has unknown tag $it" } },
            audio = audio?.toDomain(),
            references = references,
            virtues = virtues.map { virtue ->
                Virtue(
                    text = virtue.text.toDomain(),
                    references = virtue.references.map { id ->
                        requireNotNull(referencesById[id]) { "A virtue of $key cites unknown reference $id" }
                    },
                )
            },
        )
    }

    private fun kindOf(name: String): DhikrKind = when (name) {
        "quran" -> DhikrKind.QURAN
        "dhikr" -> DhikrKind.DHIKR
        "dua" -> DhikrKind.DUA
        "salawat" -> DhikrKind.SALAWAT
        "name_of_allah" -> DhikrKind.NAME_OF_ALLAH
        else -> throw IllegalArgumentException("Unknown dhikr kind $name")
    }

    private fun styleOf(name: String): AudioStyle = when (name) {
        "recitation" -> AudioStyle.RECITATION
        "melodic" -> AudioStyle.MELODIC
        "teaching" -> AudioStyle.TEACHING
        else -> throw IllegalArgumentException("Unknown audio style $name")
    }

    private fun TextDocument.toDomain() = LocalizedText(en = en, ar = ar, ml = ml)

    private fun AudioDocument.toDomain() = Audio(
        url = url,
        style = styleOf(style),
        repetitions = repetitions,
        reciter = reciter?.name?.toDomain(),
        durationMs = durationMs,
        byteSize = byteSize,
        mimeType = mimeType,
        sha256 = sha256,
        attribution = attribution,
    )

    private fun ReferenceDocument.toDomain(): Reference = when (this) {
        is ReferenceDocument.Quran -> Reference.Quran(id, surah, ayahStart, ayahEnd)
        is ReferenceDocument.Hadith -> Reference.Hadith(id, collection, number, narrator, grade)
        is ReferenceDocument.Book -> Reference.Book(id, title, author, volume, page)
        is ReferenceDocument.Shaykh -> Reference.Shaykh(id, name, note)
        is ReferenceDocument.Other -> Reference.Other(id, text, url)
    }
}

@Serializable
private class CatalogDocument(
    val version: Int,
    val contentRevision: Int,
    val dhikrs: List<DhikrDocument>,
    val collections: List<CollectionDocument>,
    val tags: List<TagDocument>,
)

@Serializable
private class TextDocument(val en: String, val ar: String? = null, val ml: String? = null)

@Serializable
private class TransliterationDocument(val en: String, val ml: String? = null)

@Serializable
private class AliasesDocument(
    val en: List<String>? = null,
    val ar: List<String>? = null,
    val ml: List<String>? = null,
)

@Serializable
@Suppress("LongParameterList") // One parameter per key of the schema's dhikr.
private class DhikrDocument(
    val id: String,
    val key: String,
    val kind: String,
    val arabic: String,
    val title: TextDocument,
    val transliteration: TransliterationDocument,
    val translation: TextDocument,
    val aliases: AliasesDocument? = null,
    val tags: List<String> = emptyList(),
    // Required, but may be null: the schema lists `audio` among the required keys.
    val audio: AudioDocument?,
    val references: List<ReferenceDocument>,
    val virtues: List<VirtueDocument>,
)

@Serializable
private class ReciterDocument(val name: TextDocument)

@Serializable
private class AudioDocument(
    val url: String,
    val style: String,
    val repetitions: Int,
    val reciter: ReciterDocument? = null,
    val durationMs: Long? = null,
    val byteSize: Long? = null,
    val mimeType: String? = null,
    val sha256: String? = null,
    val attribution: String? = null,
)

/** The schema's `oneOf` of reference shapes, told apart by `type` (kotlinx.serialization's discriminator). */
@Serializable
private sealed class ReferenceDocument {
    abstract val id: String

    @Serializable
    @SerialName("quran")
    class Quran(override val id: String, val surah: Int, val ayahStart: Int, val ayahEnd: Int) : ReferenceDocument()

    @Serializable
    @SerialName("hadith")
    class Hadith(
        override val id: String,
        val collection: String,
        val number: String? = null,
        val narrator: String? = null,
        val grade: String? = null,
    ) : ReferenceDocument()

    @Serializable
    @SerialName("book")
    class Book(
        override val id: String,
        val title: String,
        val author: String? = null,
        val volume: String? = null,
        val page: String? = null,
    ) : ReferenceDocument()

    @Serializable
    @SerialName("shaykh")
    class Shaykh(override val id: String, val name: String, val note: String? = null) : ReferenceDocument()

    @Serializable
    @SerialName("other")
    class Other(override val id: String, val text: String, val url: String? = null) : ReferenceDocument()
}

@Serializable
private class VirtueDocument(val text: TextDocument, val references: List<String>)

@Serializable
private class CollectionDocument(val key: String, val title: TextDocument, val dhikrs: List<String>)

@Serializable
private class TagDocument(val key: String, val title: TextDocument)
