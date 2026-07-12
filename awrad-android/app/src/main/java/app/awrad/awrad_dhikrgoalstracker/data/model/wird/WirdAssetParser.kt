package app.awrad.awrad_dhikrgoalstracker.data.model.wird

import app.awrad.awrad_dhikrgoalstracker.data.model.QuranRef
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.util.UUID

/**
 * Parses the bundled-asset wird format (§4.4 of the PRD): UPPER_SNAKE_CASE discriminators, distinct
 * from the in-memory polymorphic JSON. Part/segment IDs are NOT present in assets, so we derive
 * deterministic UUIDs from the wird slug + structural path. This keeps library IDs stable across
 * installs and reseeds (they only change if the content's position changes on a version bump).
 */
object WirdAssetParser {

    fun parse(text: String): Wird {
        val root = WirdSerialization.json.parseToJsonElement(text).jsonObject
        val slug = root.str("slug") ?: error("wird asset missing slug")
        val parts = (root["parts"]?.jsonArray ?: emptyList()).mapIndexed { i, el ->
            parsePart(el.jsonObject, slug, i)
        }
        return Wird(
            id = idFor(slug),
            slug = slug,
            isCustom = false,
            version = root.int("version") ?: 1,
            sortOrder = root.int("sortOrder") ?: 0,
            localizedName = root.localized("name"),
            localizedDescription = root.localized("description"),
            author = root.str("author") ?: "",
            sourceAttribution = root.str("sourceAttribution"),
            tags = (root["tags"]?.jsonArray ?: emptyList()).mapNotNull { parseTag(it.str()) },
            estimatedMinutes = root.int("estimatedMinutes"),
            schedule = parseSchedule(root["schedule"]?.jsonObject),
            parts = parts,
            reminders = emptyList(),
        )
    }

    private fun parsePart(obj: JsonObject, slug: String, index: Int): WirdPart = WirdPart(
        id = idFor("$slug/part/$index"),
        localizedTitle = obj.localized("title"),
        localizedSubtitle = obj.localized("subtitle"),
        occasion = obj["occasion"]?.let { parseOccasion(it.jsonObject) },
        blockRepeat = maxOf(obj.int("blockRepeat") ?: 1, 1),
        segments = (obj["segments"]?.jsonArray ?: emptyList()).mapIndexed { j, el ->
            parseSegment(el.jsonObject, slug, index, j)
        },
    )

    private fun parseSegment(obj: JsonObject, slug: String, partIndex: Int, index: Int): WirdSegment {
        return WirdSegment(
            id = idFor("$slug/part/$partIndex/seg/$index"),
            kind = parseKind(obj.str("kind")),
            arabic = obj.str("arabic") ?: "",
            transliteration = obj.localized("transliteration"),
            translation = obj.localized("translation"),
            localizedText = obj.localized("text"),
            repeatSpec = parseRepeat(obj["repeat"]?.jsonObject),
            fadl = obj.localized("fadl"),
            quranRef = obj["quran"]?.jsonObject?.let {
                QuranRef(
                    surah = it.int("surah") ?: 0,
                    ayahStart = it.int("ayahStart") ?: 0,
                    ayahEnd = it.int("ayahEnd"),
                )
            },
        )
    }

    private fun parseRepeat(obj: JsonObject?): RepeatSpec {
        if (obj == null) return RepeatSpec()
        val min = obj.int("min")
        val max = obj.int("max")
        val count = obj.int("count") ?: min ?: 1
        return RepeatSpec(count = count, min = min, max = max)
    }

    private fun parseSchedule(obj: JsonObject?): WirdSchedule {
        if (obj == null) return WirdSchedule()
        return WirdSchedule(
            cadence = parseCadence(obj),
            hijriAnchor = parseHijriAnchor(obj.str("hijriAnchor")),
            defaultOccasion = obj["defaultOccasion"]?.let { parseOccasion(it.jsonObject) }
                ?: WirdOccasion.Anytime,
        )
    }

    private fun parseCadence(obj: JsonObject): WirdCadence = when (obj.str("cadence")) {
        "DAYS_OF_WEEK" -> WirdCadence.DaysOfWeek(
            (obj["daysOfWeek"]?.jsonArray ?: emptyList()).mapNotNull { it.intOrNull() }.toSet(),
        )
        "INTERVAL" -> WirdCadence.Interval(
            days = obj.int("intervalDays") ?: 1,
            anchor = obj.str("intervalAnchor") ?: "",
        )
        "ROTATION" -> WirdCadence.Rotation
        "PARTS_BY_WEEKDAY" -> WirdCadence.PartsByWeekday(
            parsePartsByWeekday(obj["partsByWeekday"]?.jsonObject),
        )
        else -> WirdCadence.EveryDay
    }

    private fun parsePartsByWeekday(obj: JsonObject?): Map<Int, List<Int>> =
        obj?.mapNotNull { (dayKey, indexesElement) ->
            val day = dayKey.toIntOrNull()?.takeIf { it in 1..7 } ?: return@mapNotNull null
            val indexes = indexesElement.jsonArray
                .mapNotNull { it.intOrNull() }
                .filter { it >= 0 }
            if (indexes.isEmpty()) null else day to indexes
        }?.toMap().orEmpty()

    private fun parseHijriAnchor(raw: String?): HijriAnchor? {
        if (raw.isNullOrBlank()) return null
        val segs = raw.split(":")
        return when (segs[0]) {
            "RAMADAN" -> HijriAnchor.Ramadan
            "LAST_TEN_NIGHTS" -> HijriAnchor.LastTenNights
            "HIJRI_MONTH" -> segs.getOrNull(1)?.toIntOrNull()?.let { HijriAnchor.HijriMonth(it) }
            "HIJRI_DATE" -> {
                val m = segs.getOrNull(1)?.toIntOrNull()
                val d = segs.getOrNull(2)?.toIntOrNull()
                if (m != null && d != null) HijriAnchor.HijriDate(m, d) else null
            }
            else -> null
        }
    }

    private fun parseOccasion(obj: JsonObject): WirdOccasion = when (obj.str("type")) {
        "AFTER_PRAYER" -> Prayer.fromRaw(obj.str("prayer") ?: "")
            ?.let { WirdOccasion.AfterPrayer(it) } ?: WirdOccasion.Anytime
        "MORNING" -> WirdOccasion.Morning
        "EVENING" -> WirdOccasion.Evening
        "BEFORE_SLEEP" -> WirdOccasion.BeforeSleep
        "TIME_WINDOW" -> WirdOccasion.TimeWindow(
            startMinute = obj.int("startMinute") ?: 0,
            endMinute = obj.int("endMinute") ?: 0,
        )
        else -> WirdOccasion.Anytime
    }

    private fun parseKind(raw: String?): SegmentKind = when (raw?.lowercase()) {
        "heading" -> SegmentKind.HEADING
        "instruction" -> SegmentKind.INSTRUCTION
        "dua" -> SegmentKind.DUA
        "salah" -> SegmentKind.SALAH
        "quran" -> SegmentKind.QURAN
        else -> SegmentKind.DHIKR
    }

    private fun parseTag(raw: String?): WirdTag? = when (raw?.lowercase()) {
        "morning" -> WirdTag.MORNING
        "evening" -> WirdTag.EVENING
        "salawat" -> WirdTag.SALAWAT
        "protection" -> WirdTag.PROTECTION
        "quran" -> WirdTag.QURAN
        "forgiveness" -> WirdTag.FORGIVENESS
        "praise" -> WirdTag.PRAISE
        "general" -> WirdTag.GENERAL
        else -> null
    }

    /** Deterministic UUID from a structural seed string. */
    private fun idFor(seed: String): String =
        UUID.nameUUIDFromBytes("awrad-wird:$seed".toByteArray(Charsets.UTF_8)).toString()

    // --- JSON helpers ---
    private fun JsonObject.str(key: String): String? = this[key]?.str()

    private fun JsonObject.int(key: String): Int? = this[key]?.jsonPrimitive?.intOrNull

    private fun JsonObject.localized(key: String): LocalizedString =
        this[key]?.jsonObject?.mapValues { it.value.str() ?: "" }?.filterValues { it.isNotBlank() }
            ?: emptyMap()

    private fun JsonElement.str(): String? = jsonPrimitive.contentOrNull

    private fun JsonElement.intOrNull(): Int? = jsonPrimitive.intOrNull
}
