import groovy.json.JsonSlurper
import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.Property
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.Internal
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction

/**
 * Bundles the shared dhikr catalog (`contracts/dhikr-catalog/v1/catalog.json`) into the app as a committed asset,
 * byte for byte, after checking that the app knows its whole shape ([DhikrCatalogShape]): an unknown key, kind,
 * audio style or reference type fails generation instead of being dropped by the app's parser.
 *
 * With [verifyOnly] false it (re)writes [asset]. With [verifyOnly] true it fails when [asset] isn't exactly the
 * contract's catalog, so a catalog change can't land without the bundled copy.
 */
abstract class DhikrCatalogTask : DefaultTask() {

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val contract: RegularFileProperty

    @get:Internal
    abstract val asset: RegularFileProperty

    @get:Input
    abstract val verifyOnly: Property<Boolean>

    @get:Input
    abstract val regenerateCommand: Property<String>

    @TaskAction
    fun run() {
        val contractFile = contract.get().asFile
        val text = contractFile.readText()
        val problems = DhikrCatalogShape.problems(JsonSlurper().parseText(text))
        if (problems.isNotEmpty()) {
            throw GradleException(
                "${contractFile.path} has what the app doesn't read (update DhikrCatalogShape and the parser, " +
                    "CatalogJson.kt, together):\n" + problems.joinToString("\n") { "  - $it" },
            )
        }
        val file = asset.get().asFile
        if (!verifyOnly.get()) {
            file.parentFile.mkdirs()
            file.writeText(text)
        } else if (!file.isFile || file.readText() != text) {
            throw GradleException(
                "${file.path} is out of date with ${contractFile.path}.\n" +
                    "Regenerate it with: ${regenerateCommand.get()}",
            )
        }
    }
}

/**
 * The keys and values of `catalog.json` that the app's parser (`:core:domain`'s `CatalogJson`) reads. Anything
 * else is a problem: the contract has grown, and the app must learn it before it ships the new catalog.
 */
internal object DhikrCatalogShape {

    private val ROOT = setOf("version", "contentRevision", "dhikrs", "collections", "tags")
    private val DHIKR = setOf(
        "id", "key", "kind", "arabic", "title", "transliteration", "aliases", "tags", "translation", "audio",
        "references", "virtues",
    )
    private val TEXT = setOf("en", "ar", "ml")
    private val TRANSLITERATION = setOf("en", "ml")
    private val AUDIO = setOf(
        "url", "reciter", "style", "repetitions", "durationMs", "byteSize", "mimeType", "sha256", "attribution",
    )
    private val RECITER = setOf("name")
    private val VIRTUE = setOf("text", "references")
    private val COLLECTION = setOf("key", "title", "dhikrs")
    private val TAG = setOf("key", "title")
    private val REFERENCES = mapOf(
        "quran" to setOf("id", "type", "surah", "ayahStart", "ayahEnd"),
        "hadith" to setOf("id", "type", "collection", "number", "narrator", "grade"),
        "book" to setOf("id", "type", "title", "author", "volume", "page"),
        "shaykh" to setOf("id", "type", "name", "note"),
        "other" to setOf("id", "type", "text", "url"),
    )
    private val KINDS = setOf("quran", "dhikr", "dua", "salawat", "name_of_allah")
    private val STYLES = setOf("recitation", "melodic", "teaching")

    /** Every key or value in [json] the app doesn't know, by path. Empty when the app reads all of it. */
    fun problems(json: Any?): List<String> = buildList {
        val root = objectAt("catalog", json, ROOT) ?: return@buildList
        (root["dhikrs"] as? List<*>).orEmpty().forEachIndexed { index, dhikr ->
            val key = (dhikr as? Map<*, *>)?.get("key") ?: index
            dhikr("dhikrs[$key]", dhikr)
        }
        (root["collections"] as? List<*>).orEmpty().forEachIndexed { index, collection ->
            val path = "collections[$index]"
            objectAt(path, collection, COLLECTION)?.let { text("$path.title", it["title"]) }
        }
        (root["tags"] as? List<*>).orEmpty().forEachIndexed { index, tag ->
            objectAt("tags[$index]", tag, TAG)?.let { text("tags[$index].title", it["title"]) }
        }
    }

    private fun MutableList<String>.dhikr(path: String, json: Any?) {
        val dhikr = objectAt(path, json, DHIKR) ?: return
        if (dhikr["kind"] !in KINDS) add("$path.kind: unknown kind '${dhikr["kind"]}'")
        listOf("title", "translation").forEach { text("$path.$it", dhikr[it]) }
        objectAt("$path.transliteration", dhikr["transliteration"], TRANSLITERATION)
        dhikr["aliases"]?.let { objectAt("$path.aliases", it, TEXT) }
        dhikr["audio"]?.let { audio -> audio("$path.audio", audio) }
        (dhikr["references"] as? List<*>).orEmpty().forEachIndexed { index, reference ->
            reference("$path.references[$index]", reference)
        }
        (dhikr["virtues"] as? List<*>).orEmpty().forEachIndexed { index, virtue ->
            objectAt("$path.virtues[$index]", virtue, VIRTUE)?.let { text("$path.virtues[$index].text", it["text"]) }
        }
    }

    private fun MutableList<String>.audio(path: String, json: Any?) {
        val audio = objectAt(path, json, AUDIO) ?: return
        if (audio["style"] !in STYLES) add("$path.style: unknown style '${audio["style"]}'")
        audio["reciter"]?.let { reciter ->
            objectAt("$path.reciter", reciter, RECITER)?.let { text("$path.reciter.name", it["name"]) }
        }
    }

    private fun MutableList<String>.reference(path: String, json: Any?) {
        val type = (json as? Map<*, *>)?.get("type")
        val keys = REFERENCES[type]
        if (keys == null) add("$path.type: unknown reference type '$type'") else objectAt(path, json, keys)
    }

    private fun MutableList<String>.text(path: String, json: Any?) {
        objectAt(path, json, TEXT)
    }

    /** [json] as an object, noting each key outside [known]; null (and a problem) when it isn't an object. */
    private fun MutableList<String>.objectAt(path: String, json: Any?, known: Set<String>): Map<*, *>? {
        if (json !is Map<*, *>) {
            add("$path: expected an object")
            return null
        }
        json.keys.filter { it !in known }.forEach { add("$path: unknown key '$it'") }
        return json
    }
}
