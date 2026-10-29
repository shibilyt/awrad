package app.awrad.feature.practice

import app.awrad.core.domain.hijri.HijriAdjustment
import app.awrad.core.domain.hijri.HijriCalendar
import app.awrad.core.domain.hijri.HijriCorrection
import app.awrad.core.domain.hijri.HijriDate
import app.awrad.core.domain.practice.DayReset
import app.awrad.core.domain.practice.DeviceLocation
import app.awrad.core.domain.practice.EffectivePracticeDay
import app.awrad.core.domain.practice.Maghrib
import app.awrad.core.domain.practice.PracticePolicy
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/** Today's Maghrib as Settings shows it. */
internal sealed interface MaghribToday {
    /** No location: no Maghrib, and a Maghrib reset falls back to midnight. */
    data object NoLocation : MaghribToday

    /** The sun doesn't set (or rise) here today. */
    data object NoSunset : MaghribToday

    data class At(val time: ZonedDateTime) : MaghribToday
}

/** A month "Adjust" offers: its offset in force and the offsets the validity rule allows. */
internal data class AdjustableMonth(val year: Int, val month: Int, val offset: Int, val allowed: List<Int>)

/** A saved correction, and whether removing it leaves a valid set. */
internal data class CorrectionRow(val correction: HijriCorrection, val removable: Boolean)

/**
 * What the page shows for [instant]: the effective practice day's Hijri date (with the policy's corrections and
 * day reset), today's Maghrib at the location, the months that can be adjusted and the corrections saved.
 */
internal data class PracticeToday(
    val hijriDate: HijriDate?,
    val maghrib: MaghribToday,
    val adjustable: List<AdjustableMonth>,
    val corrections: List<CorrectionRow>,
    /** The Maghrib reset is chosen without a location: the day starts at midnight instead. */
    val showsMaghribHint: Boolean,
) {
    companion object {
        fun of(policy: PracticePolicy, location: DeviceLocation?, instant: Instant, zone: ZoneId): PracticeToday {
            val localDate = instant.atZone(zone).toLocalDate()
            val maghribAt = Maghrib.on(localDate, location, policy)
            val practiceDay = EffectivePracticeDay.of(instant, zone, policy.dayReset, maghribAt)
            val corrections = policy.hijriCorrections
            val calendar = HijriCalendar(corrections)
            return PracticeToday(
                hijriDate = calendar.dateOf(practiceDay),
                maghrib = when {
                    location == null -> MaghribToday.NoLocation
                    maghribAt == null -> MaghribToday.NoSunset
                    else -> MaghribToday.At(maghribAt.atZone(zone))
                },
                adjustable = HijriAdjustment.adjustableMonths(calendar, practiceDay).map { month ->
                    AdjustableMonth(
                        year = month.year,
                        month = month.month,
                        offset = HijriAdjustment.offsetInForce(corrections, month.year, month.month),
                        allowed = HijriAdjustment.allowedOffsets(corrections, month.year, month.month),
                    )
                },
                corrections = corrections.corrections
                    .sortedWith(compareBy({ it.year }, { it.month }))
                    .map { CorrectionRow(it, HijriAdjustment.without(corrections, it) != null) },
                showsMaghribHint = policy.dayReset == DayReset.MAGHRIB && location == null,
            )
        }
    }
}
