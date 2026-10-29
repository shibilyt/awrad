package app.awrad.core.domain.personal

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.AudioContentType
import app.awrad.core.domain.audio.AudioUploadRules
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * A custom dhikr document's `audio` member (contracts/sync/v1/README.md, "Entities"): `null`, `{"local_only":
 * true}` (a recording kept on the phone that imported it), or `$defs/uploaded_audio`
 * `{asset_id, byte_size, content_type, duration_ms}` with every member present.
 */
public object CustomAudioJson {

    /** `{"local_only": true}`. */
    public val LOCAL_ONLY: JsonObject = buildJsonObject { put("local_only", true) }

    private val UPLOADED_MEMBERS = setOf("asset_id", "byte_size", "content_type", "duration_ms")

    /** Largest `duration_ms`: 2^53 - 1 (STYLE §5). */
    private const val MAX_DURATION_MS: Long = 9_007_199_254_740_991

    /** The `audio` member for [audio]: the uploaded recording when there is one, else the local marker. */
    public fun encode(audio: CustomAudio?): JsonElement = when {
        audio == null -> JsonNull
        audio.uploaded != null -> encode(audio.uploaded)
        else -> LOCAL_ONLY
    }

    public fun encode(uploaded: UploadedAudio): JsonObject = buildJsonObject {
        put("asset_id", uploaded.assetId.value)
        put("byte_size", uploaded.byteSize)
        put("content_type", uploaded.contentType.wire)
        put("duration_ms", uploaded.durationMs)
    }

    /** Whether [element] is a valid `audio` member: null, the local marker, or an uploaded recording. */
    public fun isValid(element: JsonElement): Boolean =
        element == JsonNull || isLocalOnly(element) || uploaded(element) != null

    /** The uploaded recording [element] names, or null when it's anything else (or malformed). */
    public fun uploaded(element: JsonElement?): UploadedAudio? {
        val audio = (element as? JsonObject)?.takeIf { it.keys == UPLOADED_MEMBERS } ?: return null
        val assetId = audio["asset_id"]?.stringOrNull()?.let(AwradId::parse)
        val byteSize = audio["byte_size"]?.integerOrNull()?.takeIf { it in 1..AudioUploadRules.MAX_FILE_BYTES }
        val contentType = audio["content_type"]?.stringOrNull()?.let(AudioContentType::fromWire)
        val duration = audio.getValue("duration_ms")
        val durationMs = duration.integerOrNull()?.takeIf { it in 1..MAX_DURATION_MS }
        val durationValid = duration == JsonNull || durationMs != null
        val members = if (durationValid) Triple(assetId, byteSize, contentType) else null
        return members?.let { (id, size, type) ->
            if (id != null && size != null && type != null) UploadedAudio(id, size, type, durationMs) else null
        }
    }

    /** Whether [element] is exactly `{"local_only": true}`. */
    public fun isLocalOnly(element: JsonElement?): Boolean =
        element is JsonObject && element.keys == setOf("local_only") &&
            (element["local_only"] as? JsonPrimitive)?.takeUnless { it.isString }?.booleanOrNull == true
}

/** The asset ID a custom dhikr [document]'s `audio` names, or null when it names none. */
public fun uploadedAssetOf(document: JsonObject): AwradId? = CustomAudioJson.uploaded(document["audio"])?.assetId
