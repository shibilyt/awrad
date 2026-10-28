package app.awrad.core.domain.personal

import app.awrad.core.domain.sync.FieldError
import app.awrad.core.domain.sync.FieldErrorCode
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.longOrNull

/**
 * Which custom dhikr documents are valid (fixture `custom_dhikr_validity`): exactly those matching
 * `urn:awrad:sync:1#/$defs/custom_dhikr_document` whose Qur'an references also end at or after they start (`range`
 * on `ayah_end`, the one rule the schema can't express). Errors are `{field, code}`, the field a JSON Pointer into the
 * document, sorted by field and then code. The phone checks before saving; the server checks every put.
 */
public object CustomDhikrValidity {

    private val KINDS = setOf("quran", "dhikr", "dua", "salawat", "name_of_allah")
    private val MEMBERS = setOf("kind", "arabic", "title", "transliteration", "translation", "audio", "references")
    private val LANGUAGES = listOf("en", "ar", "ml")
    private val TRANSLITERATION_LANGUAGES = listOf("en", "ml")

    /** Every problem with [document]; empty when it's valid. */
    public fun errors(document: JsonObject): List<FieldError> {
        val errors = mutableListOf<FieldError>()
        document.keys.filterNot { it in MEMBERS }.forEach { errors += FieldError("/$it", FieldErrorCode.NOT_ALLOWED) }
        when (val kind = document["kind"]) {
            null -> errors += FieldError("/kind", FieldErrorCode.REQUIRED)
            else -> if (kind.stringOrNull() !in KINDS) errors += FieldError("/kind", FieldErrorCode.INVALID)
        }
        when (val arabic = document["arabic"]) {
            null -> errors += FieldError("/arabic", FieldErrorCode.REQUIRED)
            else -> textError(arabic, CustomDhikr.MAX_TEXT)?.let { errors += FieldError("/arabic", it) }
        }
        languageObject(document, "title", LANGUAGES, CustomDhikr.MAX_TITLE, errors, needsOne = true)
        languageObject(document, "transliteration", TRANSLITERATION_LANGUAGES, CustomDhikr.MAX_TEXT, errors)
        languageObject(document, "translation", LANGUAGES, CustomDhikr.MAX_TEXT, errors)
        audioError(document)?.let { errors += FieldError("/audio", it) }
        errors += referenceErrors(document)
        return errors.sortedWith(compareBy({ it.field }, { it.code.wire }))
    }

    /** `audio` is required, and null or exactly `{"local_only": true}`. */
    private fun audioError(document: JsonObject): FieldErrorCode? = when (val audio = document["audio"]) {
        null -> FieldErrorCode.REQUIRED
        JsonNull -> null
        else -> FieldErrorCode.INVALID.takeUnless { isLocalOnlyMarker(audio) }
    }

    /** `references` is a required array of at most 20 references in the catalog's shape. */
    private fun referenceErrors(document: JsonObject): List<FieldError> = when (
        val references = document["references"]
    ) {
        null -> listOf(FieldError("/references", FieldErrorCode.REQUIRED))
        !is JsonArray -> listOf(FieldError("/references", FieldErrorCode.INVALID))
        else -> listOfNotNull(
            FieldError("/references", FieldErrorCode.TOO_MANY).takeIf { references.size > CustomDhikr.MAX_REFERENCES },
        ) + references.mapIndexedNotNull { index, reference ->
            when {
                !ReferenceJson.isValid(reference) -> FieldError("/references/$index", FieldErrorCode.INVALID)
                isReversedRange(reference) -> FieldError("/references/$index/ayah_end", FieldErrorCode.RANGE)
                else -> null
            }
        }
    }

    /** A Qur'an reference whose `ayah_end` is below its `ayah_start`: the one rule the schema can't express. */
    private fun isReversedRange(reference: JsonElement): Boolean {
        val quran = (reference as? JsonObject)?.takeIf { it["type"]?.stringOrNull() == "quran" }
        val start = quran?.get("ayah_start")?.integerOrNull()
        val end = quran?.get("ayah_end")?.integerOrNull()
        return start != null && end != null && end < start
    }

    /** Whether [document] is a valid custom dhikr document. */
    public fun isValid(document: JsonObject): Boolean = errors(document).isEmpty()

    /**
     * An object of [languages], each present, null or a text of at most [maxLength] code points. With
     * [needsOne], at least one must be a string (the title).
     */
    @Suppress("LongParameterList") // The schema's per-member settings, named at the call sites.
    private fun languageObject(
        document: JsonObject,
        member: String,
        languages: List<String>,
        maxLength: Int,
        errors: MutableList<FieldError>,
        needsOne: Boolean = false,
    ) {
        val value = document[member]
        if (value == null) {
            errors += FieldError("/$member", FieldErrorCode.REQUIRED)
            return
        }
        if (value !is JsonObject) {
            errors += FieldError("/$member", FieldErrorCode.INVALID)
            return
        }
        value.keys.filterNot { it in languages }
            .forEach { errors += FieldError("/$member/$it", FieldErrorCode.NOT_ALLOWED) }
        languages.forEach { language ->
            when (val text = value[language]) {
                null -> errors += FieldError("/$member/$language", FieldErrorCode.REQUIRED)
                JsonNull -> Unit
                else -> textError(text, maxLength)?.let { errors += FieldError("/$member/$language", it) }
            }
        }
        val hasText = languages.any { (value[it] as? JsonPrimitive)?.isString == true }
        if (needsOne && !hasText) errors += FieldError("/$member", FieldErrorCode.REQUIRED)
    }

    /** What's wrong with a required text: not a string, blank, or longer than [maxLength] code points. */
    private fun textError(element: JsonElement, maxLength: Int): FieldErrorCode? {
        val text = element.stringOrNull() ?: return FieldErrorCode.INVALID
        return when {
            isBlank(text) -> FieldErrorCode.BLANK
            text.codePointCount(0, text.length) > maxLength -> FieldErrorCode.TOO_LONG
            else -> null
        }
    }

    private fun isLocalOnlyMarker(element: JsonElement): Boolean =
        element is JsonObject && element.keys == setOf("local_only") &&
            (element["local_only"] as? JsonPrimitive)?.takeUnless { it.isString }?.booleanOrNull == true
}

/** The text of a JSON string, or null for anything else. */
internal fun JsonElement.stringOrNull(): String? = (this as? JsonPrimitive)?.takeIf { it.isString }?.content

/** A JSON integer (not a string), or null. */
internal fun JsonElement.integerOrNull(): Long? = (this as? JsonPrimitive)?.takeUnless { it.isString }?.longOrNull

/** The catalog's `text` (`"\\S"`): blank when it has no character outside white space. */
internal fun isBlank(text: String): Boolean = text.all {
    it.isWhitespace() || Character.isSpaceChar(it) || it == '\uFEFF'
}
