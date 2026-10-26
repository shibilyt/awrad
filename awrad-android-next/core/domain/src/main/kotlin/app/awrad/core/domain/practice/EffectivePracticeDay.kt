package app.awrad.core.domain.practice

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Rule: the effective practice day (fixture `effective_practice_day`).
 *
 * - With a midnight reset it's the local calendar date in [zone].
 * - With a Maghrib reset it's the next calendar date from that day's Maghrib onwards.
 *   The Maghrib instant itself belongs to the new day.
 * - With a Maghrib reset but no known Maghrib (no location) it falls back to midnight.
 */
public object EffectivePracticeDay {

    /**
     * @param maghrib Maghrib on [instant]'s local calendar date in [zone], or null when unknown.
     *   Prayer times are an input; computing them is a separate adapter.
     */
    public fun of(instant: Instant, zone: ZoneId, dayReset: DayReset, maghrib: Instant?): LocalDate {
        val localDate = instant.atZone(zone).toLocalDate()
        val afterMaghrib = dayReset == DayReset.MAGHRIB && maghrib != null && !instant.isBefore(maghrib)
        return if (afterMaghrib) localDate.plusDays(1) else localDate
    }
}
