package app.awrad.awrad_dhikrgoalstracker.data.model.wird

import app.awrad.awrad_dhikrgoalstracker.data.model.QuranRef
import kotlinx.serialization.Serializable

@Serializable
data class RepeatSpec(
    val count: Int = 1,
    val min: Int? = null,
    val max: Int? = null,
) {
    /** The count required to mark the segment complete. */
    val target: Int get() = maxOf(min ?: count, 1)

    val isRange: Boolean get() = min != null && max != null && max > min

    fun displayText(): String = if (isRange) "$min–$max" else "$target"
}

@Serializable
data class WirdSegment(
    val id: String,
    val kind: SegmentKind = SegmentKind.DHIKR,
    val arabic: String = "",
    val transliteration: LocalizedString = emptyMap(),
    val translation: LocalizedString = emptyMap(),
    /** Primary text for `heading`/`instruction` kinds. */
    val localizedText: LocalizedString = emptyMap(),
    val repeatSpec: RepeatSpec = RepeatSpec(),
    /** Link to a library Dhikr; the text is denormalized (copied) into this segment. */
    val sourceDhikrID: String? = null,
    val quranRef: QuranRef? = null,
    /** Benefit/virtue note. */
    val fadl: LocalizedString = emptyMap(),
    val audioFileName: String? = null,
    val audioURL: String? = null,
) {
    val isCountable: Boolean get() = kind.isCountable

    val hasAudio: Boolean get() = !audioURL.isNullOrBlank() || !audioFileName.isNullOrBlank()
}

@Serializable
data class WirdPart(
    val id: String,
    val localizedTitle: LocalizedString = emptyMap(),
    val localizedSubtitle: LocalizedString = emptyMap(),
    /** Overrides the wird's `defaultOccasion` when set. */
    val occasion: WirdOccasion? = null,
    /** Repeat the whole part N times (multiplies every segment's target). */
    val blockRepeat: Int = 1,
    val segments: List<WirdSegment> = emptyList(),
) {
    val countableSegments: List<WirdSegment> get() = segments.filter { it.isCountable }
}

@Serializable
data class WirdSchedule(
    val cadence: WirdCadence = WirdCadence.EveryDay,
    val hijriAnchor: HijriAnchor? = null,
    val defaultOccasion: WirdOccasion = WirdOccasion.Anytime,
)

@Serializable
data class WirdReminder(
    val id: String,
    val reminderType: ReminderType = ReminderType.FIXED_TIME,
    val hour: Int? = null,
    val minute: Int? = null,
    val prayer: Prayer? = null,
    val offsetMinutes: Int? = null,
    val enabled: Boolean = true,
)

@Serializable
data class Wird(
    val id: String,
    val slug: String,
    val isCustom: Boolean = false,
    val version: Int = 1,
    val sortOrder: Int = 0,
    val localizedName: LocalizedString = emptyMap(),
    val localizedDescription: LocalizedString = emptyMap(),
    val author: String = "",
    /** Book / compiler; shown in preference to [author]. */
    val sourceAttribution: String? = null,
    val tags: List<WirdTag> = emptyList(),
    val estimatedMinutes: Int? = null,
    val schedule: WirdSchedule = WirdSchedule(),
    val parts: List<WirdPart> = emptyList(),
    val reminders: List<WirdReminder> = emptyList(),
) {
    fun displayName(lang: String): String = localizedName.resolve(lang)

    fun displayDescription(lang: String): String = localizedDescription.resolve(lang)

    /** Arabic display name (falls back via resolution). */
    val arabicName: String get() = localizedName.resolve(LANG_AR)

    /** The effective occasion for [part] — its own occasion or the schedule default. */
    fun occasionFor(part: WirdPart): WirdOccasion = part.occasion ?: schedule.defaultOccasion

    fun part(id: String): WirdPart? = parts.firstOrNull { it.id == id }
}
