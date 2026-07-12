package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.CalculationMethodPref
import app.awrad.awrad_dhikrgoalstracker.data.model.MadhabPref
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import app.awrad.awrad_dhikrgoalstracker.data.repository.PrayerTimeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import java.time.LocalDate
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DateProvider @Inject constructor(
    private val userPreferences: UserPreferences,
    private val prayerTimeRepository: PrayerTimeRepository,
) {
    /**
     * A Flow that emits the effective "today" date string whenever relevant preferences change.
     * When day reset is MAGHRIB and the current time is past Maghrib, the effective date
     * advances to the next Gregorian day.
     */
    val effectiveToday: Flow<String> = combine(
        userPreferences.dayResetTime,
        userPreferences.latitude,
        userPreferences.longitude,
        userPreferences.calculationMethod,
        userPreferences.madhab,
    ) { dayReset, lat, lng, methodStr, madhabStr ->
        computeEffectiveToday(dayReset, lat, lng, methodStr, madhabStr)
    }

    /**
     * Suspend function to get the effective today date string on-demand.
     */
    suspend fun getEffectiveToday(): String {
        val dayReset = userPreferences.dayResetTime.first()
        val lat = userPreferences.latitude.first()
        val lng = userPreferences.longitude.first()
        val methodStr = userPreferences.calculationMethod.first()
        val madhabStr = userPreferences.madhab.first()
        return computeEffectiveToday(dayReset, lat, lng, methodStr, madhabStr)
    }

    private fun computeEffectiveToday(
        dayReset: String,
        lat: Double?,
        lng: Double?,
        methodStr: String,
        madhabStr: String,
    ): String {
        val now = LocalDate.now()
        if (dayReset == "MAGHRIB" && lat != null && lng != null) {
            val method = try {
                CalculationMethodPref.valueOf(methodStr)
            } catch (e: IllegalArgumentException) {
                CalculationMethodPref.KARACHI
            }
            val madhab = try {
                MadhabPref.valueOf(madhabStr)
            } catch (e: IllegalArgumentException) {
                MadhabPref.SHAFI
            }
            val prayerTimes = prayerTimeRepository.getPrayerTimes(lat, lng, method, madhab)
            val maghrib = prayerTimes.maghrib
            if (maghrib != null && Date().after(maghrib)) {
                return now.plusDays(1).toString()
            }
        }
        return now.toString()
    }
}
