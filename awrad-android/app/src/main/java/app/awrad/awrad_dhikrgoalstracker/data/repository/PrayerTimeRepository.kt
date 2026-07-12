package app.awrad.awrad_dhikrgoalstracker.data.repository

import android.content.Context
import android.location.Geocoder
import app.awrad.awrad_dhikrgoalstracker.data.model.CalculationMethodPref
import app.awrad.awrad_dhikrgoalstracker.data.model.CityResult
import app.awrad.awrad_dhikrgoalstracker.data.model.MadhabPref
import com.batoulapps.adhan.CalculationMethod
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.Madhab
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.data.DateComponents
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

data class NextPrayer(
    val name: String,
    val time: Date,
    val timeFormatted: String,
    val countdown: String,
)

@Singleton
class PrayerTimeRepository @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val timeFormatter = SimpleDateFormat("h:mm a", Locale.getDefault())

    fun getPrayerTimes(
        latitude: Double,
        longitude: Double,
        method: CalculationMethodPref,
        madhab: MadhabPref,
        date: LocalDate = LocalDate.now(),
    ): PrayerTimes {
        val coords = Coordinates(latitude, longitude)
        val dateComponents = DateComponents(
            date.year,
            date.monthValue,
            date.dayOfMonth,
        )
        val params = method.toAdhanMethod().parameters
        params.madhab = madhab.toAdhanMadhab()
        return PrayerTimes(coords, dateComponents, params)
    }

    fun getNextPrayer(prayerTimes: PrayerTimes): NextPrayer? {
        val now = Date()
        val prayers = listOf(
            "Fajr" to prayerTimes.fajr,
            "Dhuhr" to prayerTimes.dhuhr,
            "Asr" to prayerTimes.asr,
            "Maghrib" to prayerTimes.maghrib,
            "Isha" to prayerTimes.isha,
        )
        val next = prayers.firstOrNull { (_, time) -> time != null && time.after(now) } ?: return null
        val (name, time) = next
        return NextPrayer(
            name = name,
            time = time,
            timeFormatted = timeFormatter.format(time),
            countdown = formatCountdown(now, time),
        )
    }

    fun getAllPrayerTimes(prayerTimes: PrayerTimes): List<Pair<String, String>> {
        return listOf(
            "Fajr" to prayerTimes.fajr,
            "Sunrise" to prayerTimes.sunrise,
            "Dhuhr" to prayerTimes.dhuhr,
            "Asr" to prayerTimes.asr,
            "Maghrib" to prayerTimes.maghrib,
            "Isha" to prayerTimes.isha,
        ).mapNotNull { (name, time) ->
            if (time != null) name to timeFormatter.format(time) else null
        }
    }

    suspend fun searchCity(query: String): List<CityResult> = withContext(Dispatchers.IO) {
        if (query.isBlank() || !Geocoder.isPresent()) return@withContext emptyList()
        val geocoder = Geocoder(context, Locale.getDefault())
        try {
            @Suppress("DEPRECATION")
            val addresses = geocoder.getFromLocationName(query, 5) ?: return@withContext emptyList()
            addresses.mapNotNull { addr ->
                val cityName = addr.locality ?: addr.subAdminArea ?: addr.adminArea ?: addr.countryName
                    ?: return@mapNotNull null
                val displayName = listOfNotNull(addr.locality, addr.adminArea, addr.countryName)
                    .filter { it.isNotBlank() }.distinct().joinToString(", ")
                CityResult(
                    name = cityName,
                    displayName = displayName.ifBlank { cityName },
                    latitude = addr.latitude,
                    longitude = addr.longitude,
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun reverseGeocode(latitude: Double, longitude: Double): String = withContext(Dispatchers.IO) {
        if (!Geocoder.isPresent()) return@withContext ""
        val geocoder = Geocoder(context, Locale.getDefault())
        try {
            @Suppress("DEPRECATION")
            val addresses = geocoder.getFromLocation(latitude, longitude, 1) ?: return@withContext ""
            val addr = addresses.firstOrNull() ?: return@withContext ""
            listOfNotNull(addr.locality, addr.adminArea, addr.countryName)
                .filter { it.isNotBlank() }.distinct().joinToString(", ")
        } catch (e: Exception) {
            ""
        }
    }

    private fun formatCountdown(now: Date, target: Date): String {
        val diffMs = target.time - now.time
        if (diffMs <= 0) return ""
        val totalMinutes = diffMs / (1000 * 60)
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60
        return if (hours > 0) "in ${hours}h ${minutes}m" else "in ${minutes}m"
    }

    private fun CalculationMethodPref.toAdhanMethod(): CalculationMethod = when (this) {
        CalculationMethodPref.KARACHI -> CalculationMethod.KARACHI
        CalculationMethodPref.NORTH_AMERICA -> CalculationMethod.NORTH_AMERICA
        CalculationMethodPref.MWL -> CalculationMethod.MUSLIM_WORLD_LEAGUE
        CalculationMethodPref.EGYPT -> CalculationMethod.EGYPTIAN
        CalculationMethodPref.UMM_AL_QURA -> CalculationMethod.UMM_AL_QURA
        CalculationMethodPref.MOON_SIGHTING -> CalculationMethod.MOON_SIGHTING_COMMITTEE
        CalculationMethodPref.DUBAI -> CalculationMethod.DUBAI
        CalculationMethodPref.KUWAIT -> CalculationMethod.KUWAIT
        CalculationMethodPref.QATAR -> CalculationMethod.QATAR
        CalculationMethodPref.SINGAPORE -> CalculationMethod.SINGAPORE
    }

    private fun MadhabPref.toAdhanMadhab(): Madhab = when (this) {
        MadhabPref.HANAFI -> Madhab.HANAFI
        MadhabPref.SHAFI -> Madhab.SHAFI
    }
}
