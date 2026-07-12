package app.awrad.awrad_dhikrgoalstracker.data.model.wird

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class SegmentKind {
    @SerialName("heading") HEADING,
    @SerialName("instruction") INSTRUCTION,
    @SerialName("dhikr") DHIKR,
    @SerialName("dua") DUA,
    @SerialName("salah") SALAH,
    @SerialName("quran") QURAN;

    /** Only countable kinds count toward completion/progress. */
    val isCountable: Boolean
        get() = this == DHIKR || this == DUA || this == SALAH || this == QURAN
}

@Serializable
enum class WirdTag {
    @SerialName("morning") MORNING,
    @SerialName("evening") EVENING,
    @SerialName("salawat") SALAWAT,
    @SerialName("protection") PROTECTION,
    @SerialName("quran") QURAN,
    @SerialName("forgiveness") FORGIVENESS,
    @SerialName("praise") PRAISE,
    @SerialName("general") GENERAL,
}

@Serializable
enum class Prayer {
    @SerialName("fajr") FAJR,
    @SerialName("dhuhr") DHUHR,
    @SerialName("asr") ASR,
    @SerialName("maghrib") MAGHRIB,
    @SerialName("isha") ISHA;

    /** Lowercase raw value used in occasion keys (e.g. `after-fajr`). */
    val raw: String get() = name.lowercase()

    companion object {
        /** Canonical order used for occasion windows. */
        val order: List<Prayer> = listOf(FAJR, DHUHR, ASR, MAGHRIB, ISHA)

        fun fromRaw(raw: String): Prayer? = entries.firstOrNull { it.raw == raw.lowercase() }
    }
}

@Serializable
enum class ReminderType {
    @SerialName("fixed_time") FIXED_TIME,
    @SerialName("prayer_offset") PRAYER_OFFSET,
    @SerialName("time_window_start") TIME_WINDOW_START,
}
