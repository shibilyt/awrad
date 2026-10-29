package app.awrad.core.domain.practice

import com.batoulapps.adhan2.CalculationParameters
import com.batoulapps.adhan2.Coordinates
import com.batoulapps.adhan2.PrayerTimes
import com.batoulapps.adhan2.data.DateComponents
import java.time.Instant
import java.time.LocalDate
import com.batoulapps.adhan2.CalculationMethod as AdhanMethod
import com.batoulapps.adhan2.Madhab as AdhanMadhab

/**
 * Maghrib on a local date at a place (fixture `maghrib_time`), from the adhan library (adhan-kotlin, the batoulapps
 * `adhan2` artifact) with the policy's method and madhab: sunset plus the method's Maghrib adjustment, rounded to
 * the minute as adhan rounds. The server never computes it (API STYLE §6).
 */
public object Maghrib {

    /**
     * Maghrib on [date] (the local calendar date in the device's time zone) at [latitude], [longitude], or null
     * where the sun doesn't set or doesn't rise that day; then the Maghrib reset falls back to midnight.
     */
    public fun on(
        date: LocalDate,
        latitude: Double,
        longitude: Double,
        method: CalculationMethod,
        madhab: Madhab = Madhab.SHAFI,
    ): Instant? {
        val parameters = parametersOf(method).copy(madhab = madhabOf(madhab))
        // adhan2 throws when it can't place every prayer, which happens exactly when there's no sunrise or sunset.
        val times = runCatching {
            PrayerTimes(
                Coordinates(latitude, longitude),
                DateComponents(date.year, date.monthValue, date.dayOfMonth),
                parameters,
            )
        }.getOrNull() ?: return null
        return Instant.ofEpochMilli(times.maghrib.toEpochMilliseconds())
    }

    /** Maghrib for [policy] at [location] on [date], or null without a location or a sunset. */
    public fun on(date: LocalDate, location: DeviceLocation?, policy: PracticePolicy): Instant? =
        location?.let { on(date, it.latitude, it.longitude, policy.calculationMethod, policy.madhab) }

    private fun parametersOf(method: CalculationMethod): CalculationParameters = when (method) {
        CalculationMethod.KARACHI -> AdhanMethod.KARACHI
        CalculationMethod.NORTH_AMERICA -> AdhanMethod.NORTH_AMERICA
        CalculationMethod.MUSLIM_WORLD_LEAGUE -> AdhanMethod.MUSLIM_WORLD_LEAGUE
        CalculationMethod.EGYPTIAN -> AdhanMethod.EGYPTIAN
        CalculationMethod.UMM_AL_QURA -> AdhanMethod.UMM_AL_QURA
        CalculationMethod.MOONSIGHTING_COMMITTEE -> AdhanMethod.MOON_SIGHTING_COMMITTEE
        CalculationMethod.DUBAI -> AdhanMethod.DUBAI
        CalculationMethod.KUWAIT -> AdhanMethod.KUWAIT
        CalculationMethod.QATAR -> AdhanMethod.QATAR
        CalculationMethod.SINGAPORE -> AdhanMethod.SINGAPORE
    }.parameters

    private fun madhabOf(madhab: Madhab): AdhanMadhab = when (madhab) {
        Madhab.SHAFI -> AdhanMadhab.SHAFI
        Madhab.HANAFI -> AdhanMadhab.HANAFI
    }
}
