package app.awrad.core.domain.personal

import app.awrad.core.domain.dhikr.Reference
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.net.URI
import java.net.URISyntaxException

/**
 * A reference in the catalog's shape (`urn:awrad:dhikr-catalog:1#/$defs/reference`), as custom dhikr documents
 * carry it: Qur'an references are `{id, type, surah, ayah_start, ayah_end}`.
 */
internal object ReferenceJson {

    private const val MAX_SURAH = 114L
    private val KEY = Regex("^[a-z0-9]+(-[a-z0-9]+)*$")

    /** Each type's members: required first, then optional. */
    private val SHAPES: Map<String, Pair<Set<String>, Set<String>>> = mapOf(
        "quran" to (setOf("id", "type", "surah", "ayah_start", "ayah_end") to emptySet()),
        "hadith" to (setOf("id", "type", "collection") to setOf("number", "narrator", "grade")),
        "book" to (setOf("id", "type", "title") to setOf("author", "volume", "page")),
        "shaykh" to (setOf("id", "type", "name") to setOf("note")),
        "other" to (setOf("id", "type", "text") to setOf("url")),
    )

    fun isValid(element: JsonElement): Boolean {
        val reference = element as? JsonObject
        val shape = reference?.get("type")?.stringOrNull()?.let(SHAPES::get)
        return reference != null && shape != null &&
            reference.keys.containsAll(shape.first) &&
            (shape.first + shape.second).containsAll(reference.keys) &&
            reference.getValue("id").stringOrNull()?.let(KEY::matches) == true &&
            reference.all { (member, value) -> isValidMember(member, value) }
    }

    private fun isValidMember(member: String, value: JsonElement): Boolean = when (member) {
        "id", "type" -> true
        "surah" -> value.integerOrNull()?.let { it in 1..MAX_SURAH } == true
        "ayah_start", "ayah_end" -> value.integerOrNull()?.let { it >= 1 } == true
        "url" -> value.stringOrNull()?.let(::isUri) == true
        else -> value.stringOrNull()?.let { !isBlank(it) } == true
    }

    private fun isUri(text: String): Boolean = try {
        URI(text).isAbsolute
    } catch (_: URISyntaxException) {
        false
    }

    /** [reference] in the catalog's shape; a missing optional member is left out. */
    fun encode(reference: Reference): JsonObject {
        val members: List<Pair<String, JsonPrimitive?>> = when (reference) {
            is Reference.Quran -> listOf(
                "type" to text("quran"),
                "surah" to JsonPrimitive(reference.surah),
                "ayah_start" to JsonPrimitive(reference.ayahStart),
                "ayah_end" to JsonPrimitive(reference.ayahEnd),
            )
            is Reference.Hadith -> listOf(
                "type" to text("hadith"),
                "collection" to text(reference.collection),
                "number" to text(reference.number),
                "narrator" to text(reference.narrator),
                "grade" to text(reference.grade),
            )
            is Reference.Book -> listOf(
                "type" to text("book"),
                "title" to text(reference.title),
                "author" to text(reference.author),
                "volume" to text(reference.volume),
                "page" to text(reference.page),
            )
            is Reference.Shaykh ->
                listOf("type" to text("shaykh"), "name" to text(reference.name), "note" to text(reference.note))
            is Reference.Other ->
                listOf("type" to text("other"), "text" to text(reference.text), "url" to text(reference.url))
        }
        return JsonObject(
            (listOf("id" to text(reference.id)) + members)
                .mapNotNull { (member, value) -> value?.let { member to it } }
                .toMap(),
        )
    }

    private fun text(value: String?): JsonPrimitive? = value?.let(::JsonPrimitive)

    /** The reference [element] is, or null when it isn't a valid one. */
    fun decode(element: JsonElement): Reference? {
        if (!isValid(element)) return null
        val json = element as JsonObject
        fun text(member: String): String? = json[member]?.stringOrNull()
        fun int(member: String): Int = json.getValue(member).integerOrNull()!!.toInt()
        val id = text("id")!!
        return when (text("type")) {
            "quran" -> Reference.Quran(id, int("surah"), int("ayah_start"), int("ayah_end"))
            "hadith" -> Reference.Hadith(id, text("collection")!!, text("number"), text("narrator"), text("grade"))
            "book" -> Reference.Book(id, text("title")!!, text("author"), text("volume"), text("page"))
            "shaykh" -> Reference.Shaykh(id, text("name")!!, text("note"))
            "other" -> Reference.Other(id, text("text")!!, text("url"))
            else -> null
        }
    }
}
