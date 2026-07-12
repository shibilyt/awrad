package app.awrad.awrad_dhikrgoalstracker.data.model.wird

import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json

/**
 * Canonical JSON used for the in-memory / DB-blob representation of a [Wird] definition and for
 * the import/export snapshot. Sum types ([WirdCadence], [WirdOccasion], [HijriAnchor]) are encoded
 * polymorphically with a `type` discriminator.
 *
 * NOTE: this is NOT the bundled-asset format. Library assets use the UPPER_SNAKE_CASE shape and are
 * decoded by [WirdAssetParser]. Keep the two formats separate.
 */
object WirdSerialization {
    val json: Json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        classDiscriminator = "type"
    }

    fun encodeWird(wird: Wird): String = json.encodeToString(Wird.serializer(), wird)

    fun decodeWird(text: String): Wird = json.decodeFromString(Wird.serializer(), text)

    private val segmentProgressSerializer =
        MapSerializer(String.serializer(), Int.serializer())

    fun encodeSegmentProgress(progress: Map<String, Int>): String =
        json.encodeToString(segmentProgressSerializer, progress)

    fun decodeSegmentProgress(text: String): Map<String, Int> =
        if (text.isBlank()) emptyMap() else json.decodeFromString(segmentProgressSerializer, text)
}
