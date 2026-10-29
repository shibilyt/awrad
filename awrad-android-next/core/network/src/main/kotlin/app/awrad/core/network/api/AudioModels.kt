package app.awrad.core.network.api

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonObject

/*
 * Private audio's wire shapes (contracts/api/paths/audio.yaml; contracts/audio/v1/audio.schema.json), written by
 * hand like the rest of the client (ADR 0005). ApiContractTest round-trips every example of the four operations.
 */

/** `create_audio_upload`'s body: a new UUIDv7 [assetId] per recording, and the file's size, type and SHA-256 (hex). */
@Serializable
public data class AudioUploadRequest(
    @SerialName("asset_id") val assetId: String,
    @SerialName("byte_size") val byteSize: Long,
    @SerialName("content_type") val contentType: String,
    val sha256: String,
)

/**
 * A pending upload's signed `PUT` link (`AudioUpload`). Send the file unchanged to [uploadUrl] with exactly
 * [uploadHeaders] (lowercase names, all of them) before [expiresAt].
 */
@Serializable
public data class AudioUploadLink(
    @SerialName("asset_id") val assetId: String,
    @SerialName("upload_url") val uploadUrl: String,
    @SerialName("upload_headers") val uploadHeaders: Map<String, String>,
    @SerialName("expires_at") val expiresAt: String,
) {
    override fun toString(): String = "AudioUploadLink(assetId=$assetId, expiresAt=$expiresAt)"
}

/** A confirmed recording (`AudioAsset`). [status] is a string so an unknown value doesn't fail decoding. */
@Serializable
public data class AudioAsset(
    @SerialName("asset_id") val assetId: String,
    @SerialName("byte_size") val byteSize: Long,
    @SerialName("content_type") val contentType: String,
    val status: String,
    @SerialName("created_at") val createdAt: String,
)

/** `AudioAssetResult`: `complete_audio_upload`'s answer. */
@Serializable
public data class AudioAssetResult(val asset: AudioAsset)

/**
 * Every success body of `create_audio_upload`, told apart by its members ([AudioUploadReservationSerializer]):
 * [Pending] is a signed link (`201`, or `200` for a repeat while pending), [Ready] is `{asset}` (`200` for a repeat
 * once the asset is ready: skip the PUT and the completion).
 */
@Serializable(with = AudioUploadReservationSerializer::class)
public sealed interface AudioUploadReservation {
    public data class Pending(val link: AudioUploadLink) : AudioUploadReservation

    public data class Ready(val asset: AudioAsset) : AudioUploadReservation
}

/** Reads and writes both shapes as the spec has them: a flat link, or `{asset}`. An unknown shape fails. */
internal object AudioUploadReservationSerializer : KSerializer<AudioUploadReservation> {
    override val descriptor: SerialDescriptor = AudioUploadLink.serializer().descriptor

    override fun deserialize(decoder: Decoder): AudioUploadReservation {
        val json = (decoder as? JsonDecoder)?.json ?: throw SerializationException("Audio uploads are JSON")
        val body = decoder.decodeJsonElement() as? JsonObject ?: throw SerializationException("Expected an object")
        return when {
            "upload_url" in body ->
                AudioUploadReservation.Pending(json.decodeFromJsonElement(AudioUploadLink.serializer(), body))
            "asset" in body ->
                AudioUploadReservation.Ready(json.decodeFromJsonElement(AudioAssetResult.serializer(), body).asset)
            else -> throw SerializationException("Neither an upload link nor an asset")
        }
    }

    override fun serialize(encoder: Encoder, value: AudioUploadReservation) {
        val json = (encoder as? JsonEncoder)?.json ?: throw SerializationException("Audio uploads are JSON")
        encoder.encodeJsonElement(
            when (value) {
                is AudioUploadReservation.Pending -> json.encodeToJsonElement(AudioUploadLink.serializer(), value.link)
                is AudioUploadReservation.Ready ->
                    json.encodeToJsonElement(AudioAssetResult.serializer(), AudioAssetResult(value.asset))
            },
        )
    }
}

/** `get_audio_download`'s answer: a signed `GET` link valid until [expiresAt] (10 minutes). Don't store it. */
@Serializable
public data class AudioDownloadLink(
    val url: String,
    @SerialName("expires_at") val expiresAt: String,
) {
    override fun toString(): String = "AudioDownloadLink(expiresAt=$expiresAt)"
}

/** `get_audio_usage`'s answer: bytes the account's recordings use (ready and pending) and its limit. */
@Serializable
public data class AudioUsage(
    @SerialName("used_bytes") val usedBytes: Long,
    @SerialName("limit_bytes") val limitBytes: Long,
)
