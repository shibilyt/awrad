package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.DayResetOption
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

data class EffectiveDayWindow(
    val startInclusive: Instant,
    val endExclusive: Instant,
    val effectiveDate: LocalDate,
    val zoneId: ZoneId,
)

object EffectiveDayWindowResolver {
    fun resolve(
        now: Instant,
        zoneId: ZoneId,
        dayReset: DayResetOption,
        maghribForCivilDate: (LocalDate) -> Instant?,
    ): EffectiveDayWindow {
        val civilDate = now.atZone(zoneId).toLocalDate()
        if (dayReset != DayResetOption.MAGHRIB) return midnightWindow(civilDate, zoneId)

        val todayMaghrib = maghribForCivilDate(civilDate) ?: return midnightWindow(civilDate, zoneId)
        val effectiveDate = if (now >= todayMaghrib) civilDate.plusDays(1) else civilDate
        val startCivilDate = if (now >= todayMaghrib) civilDate else civilDate.minusDays(1)
        val start = maghribForCivilDate(startCivilDate) ?: return midnightWindow(civilDate, zoneId)
        val end = maghribForCivilDate(startCivilDate.plusDays(1)) ?: return midnightWindow(civilDate, zoneId)
        if (end <= start) return midnightWindow(civilDate, zoneId)
        return EffectiveDayWindow(start, end, effectiveDate, zoneId)
    }

    private fun midnightWindow(date: LocalDate, zoneId: ZoneId): EffectiveDayWindow =
        EffectiveDayWindow(
            startInclusive = date.atStartOfDay(zoneId).toInstant(),
            endExclusive = date.plusDays(1).atStartOfDay(zoneId).toInstant(),
            effectiveDate = date,
            zoneId = zoneId,
        )
}
