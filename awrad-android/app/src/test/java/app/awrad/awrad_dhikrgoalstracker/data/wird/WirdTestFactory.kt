package app.awrad.awrad_dhikrgoalstracker.data.wird

import app.awrad.awrad_dhikrgoalstracker.data.model.wird.HijriAnchor
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.RepeatSpec
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.SegmentKind
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Wird
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdCadence
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdOccasion
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdPart
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSchedule
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSegment
import java.time.LocalDate

/** Deterministic Hijri fake: returns a fixed value, or a per-date lookup. */
class FakeHijriCalendar(
    private val default: HijriDate = HijriDate(1, 1),
    private val byDate: Map<LocalDate, HijriDate> = emptyMap(),
) : HijriCalendar {
    override fun monthDay(date: LocalDate): HijriDate = byDate[date] ?: default
}

fun segment(
    id: String,
    kind: SegmentKind = SegmentKind.DHIKR,
    count: Int = 1,
    min: Int? = null,
    max: Int? = null,
): WirdSegment = WirdSegment(
    id = id,
    kind = kind,
    arabic = "نص",
    repeatSpec = RepeatSpec(count = count, min = min, max = max),
)

fun part(
    id: String,
    blockRepeat: Int = 1,
    occasion: WirdOccasion? = null,
    segments: List<WirdSegment>,
): WirdPart = WirdPart(id = id, blockRepeat = blockRepeat, occasion = occasion, segments = segments)

fun wird(
    id: String = "w1",
    slug: String = "w1",
    cadence: WirdCadence = WirdCadence.EveryDay,
    hijriAnchor: HijriAnchor? = null,
    defaultOccasion: WirdOccasion = WirdOccasion.Anytime,
    parts: List<WirdPart>,
): Wird = Wird(
    id = id,
    slug = slug,
    schedule = WirdSchedule(cadence = cadence, hijriAnchor = hijriAnchor, defaultOccasion = defaultOccasion),
    parts = parts,
)
