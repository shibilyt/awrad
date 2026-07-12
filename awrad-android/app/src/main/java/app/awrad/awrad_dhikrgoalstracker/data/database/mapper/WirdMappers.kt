package app.awrad.awrad_dhikrgoalstracker.data.database.mapper

import app.awrad.awrad_dhikrgoalstracker.data.database.entity.WirdEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.WirdSessionEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.LANG_AR
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.LANG_EN
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSerialization
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSession
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.decodedFromLegacyEncoding
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.resolve
import java.util.UUID

fun WirdEntity.toDomain(): Wird {
    val wird = WirdSerialization.decodeWird(definitionJson)
    // Self-heal names that a removed legacy path stored URL-encoded.
    return wird.copy(
        localizedName = wird.localizedName.decodedFromLegacyEncoding(),
        localizedDescription = wird.localizedDescription.decodedFromLegacyEncoding(),
        parts = wird.parts.map { part ->
            part.copy(
                localizedTitle = part.localizedTitle.decodedFromLegacyEncoding(),
                localizedSubtitle = part.localizedSubtitle.decodedFromLegacyEncoding(),
            )
        },
    )
}

fun Wird.toEntity(): WirdEntity = WirdEntity(
    id = id,
    slug = slug,
    isCustom = isCustom,
    version = version,
    sortOrder = sortOrder,
    nameEn = localizedName.resolve(LANG_EN),
    nameAr = localizedName.resolve(LANG_AR),
    estimatedMinutes = estimatedMinutes,
    definitionJson = WirdSerialization.encodeWird(this),
)

fun WirdSessionEntity.toDomain(): WirdSession = WirdSession(
    wirdID = wirdID,
    partID = partID,
    occasionKey = occasionKey,
    dateKey = dateKey,
    segmentProgress = WirdSerialization.decodeSegmentProgress(segmentProgressJson),
    lastSegmentID = lastSegmentID,
    isComplete = isComplete,
    startedAt = startedAt,
    completedAt = completedAt,
)

fun WirdSession.toEntity(): WirdSessionEntity = WirdSessionEntity(
    id = sessionId(wirdID, partID, occasionKey, dateKey),
    wirdID = wirdID,
    partID = partID,
    occasionKey = occasionKey,
    dateKey = dateKey,
    segmentProgressJson = WirdSerialization.encodeSegmentProgress(segmentProgress),
    lastSegmentID = lastSegmentID,
    isComplete = isComplete,
    startedAt = startedAt,
    completedAt = completedAt,
)

/** Deterministic primary key from the session identity tuple, so REPLACE acts as upsert. */
fun sessionId(wirdID: String, partID: String, occasionKey: String, dateKey: String): String =
    UUID.nameUUIDFromBytes("$wirdID|$partID|$occasionKey|$dateKey".toByteArray(Charsets.UTF_8)).toString()
