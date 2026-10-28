package app.awrad.core.domain.personal

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.dhikr.DhikrKind
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject

/** A user's own tag (CONTEXT.md, "Tag"), shown by [name]; two tags are the same when [normalizedName]s match. */
public data class UserTag(val id: AwradId, val name: String, val normalizedName: String) {
    public companion object {
        /** How many tags an account may have, and how many one dhikr may carry. */
        public const val LIMIT: Int = 100
        public const val PER_DHIKR: Int = 20
    }
}

/** `$defs/custom_dhikr_document` to and from [CustomDhikr]. The recording's file never leaves the phone. */
public object CustomDhikrJson {

    private val KIND_NAMES = mapOf(
        DhikrKind.QURAN to "quran",
        DhikrKind.DHIKR to "dhikr",
        DhikrKind.DUA to "dua",
        DhikrKind.SALAWAT to "salawat",
        DhikrKind.NAME_OF_ALLAH to "name_of_allah",
    )

    public fun encode(dhikr: CustomDhikr): JsonObject = buildJsonObject {
        put("kind", KIND_NAMES.getValue(dhikr.kind))
        put("arabic", dhikr.arabic)
        putJsonObject("title") {
            put("en", dhikr.title.en)
            put("ar", dhikr.title.ar)
            put("ml", dhikr.title.ml)
        }
        putJsonObject("transliteration") {
            put("en", dhikr.transliteration.en)
            put("ml", dhikr.transliteration.ml)
        }
        putJsonObject("translation") {
            put("en", dhikr.translation.en)
            put("ar", dhikr.translation.ar)
            put("ml", dhikr.translation.ml)
        }
        if (dhikr.audio == null) put("audio", JsonNull) else putJsonObject("audio") { put("local_only", true) }
        putJsonArray("references") { dhikr.references.forEach { add(ReferenceJson.encode(it)) } }
    }

    /**
     * The custom dhikr [document] describes, with [id] and the recording at [audioUri] (when the document says
     * there is one and it's on this phone); null when the document isn't valid.
     */
    public fun decode(id: AwradId, document: JsonObject, audioUri: String? = null): CustomDhikr? {
        if (!CustomDhikrValidity.isValid(document)) return null
        fun texts(member: String): OptionalTexts {
            val json = document.getValue(member) as JsonObject
            return OptionalTexts(json["en"]?.stringOrNull(), json["ar"]?.stringOrNull(), json["ml"]?.stringOrNull())
        }
        val transliteration = document.getValue("transliteration") as JsonObject
        return CustomDhikr(
            id = id,
            kind = KIND_NAMES.entries.first { it.value == document.getValue("kind").stringOrNull() }.key,
            arabic = document.getValue("arabic").stringOrNull()!!,
            title = texts("title"),
            transliteration = CustomTransliteration(
                transliteration["en"]?.stringOrNull(),
                transliteration["ml"]?.stringOrNull(),
            ),
            translation = texts("translation"),
            references = document.getValue("references").jsonArray.mapNotNull(ReferenceJson::decode),
            audio = if (document["audio"] is JsonObject) CustomAudio(audioUri) else null,
        )
    }
}

/** `$defs/user_tag_document`: `{name, normalized_name}`. */
public object UserTagJson {
    public fun encode(name: TagName): JsonObject = buildJsonObject {
        put("name", name.display)
        put("normalized_name", name.normalized)
    }

    public fun encode(tag: UserTag): JsonObject = buildJsonObject {
        put("name", tag.name)
        put("normalized_name", tag.normalizedName)
    }

    /** The tag [document] describes, or null when it lacks either name. */
    public fun decode(id: AwradId, document: JsonObject): UserTag? {
        val name = document["name"]?.stringOrNull()
        val normalized = document["normalized_name"]?.stringOrNull()
        return if (name != null && normalized != null) UserTag(id, name, normalized) else null
    }
}

/** `$defs/dhikr_personal_document`: a dhikr's personal record, for now its tag IDs in the user's order. */
public object PersonalDocument {
    public fun of(tagIds: List<AwradId>): JsonObject =
        JsonObject(mapOf("tag_ids" to JsonArray(tagIds.map { JsonPrimitive(it.value) })))

    /** The tag IDs in [document], skipping anything that isn't an ID. */
    public fun tagIds(document: JsonObject): List<AwradId> =
        (document["tag_ids"] as? JsonArray).orEmpty().mapNotNull { element ->
            element.stringOrNull()?.let(
                AwradId::parse,
            )
        }
}
