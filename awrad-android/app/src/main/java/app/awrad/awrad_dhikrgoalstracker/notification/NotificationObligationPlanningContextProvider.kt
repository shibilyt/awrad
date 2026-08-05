package app.awrad.awrad_dhikrgoalstracker.notification

import androidx.appcompat.app.AppCompatDelegate
import app.awrad.awrad_dhikrgoalstracker.data.model.CalculationMethodPref
import app.awrad.awrad_dhikrgoalstracker.data.model.DayResetOption
import app.awrad.awrad_dhikrgoalstracker.data.model.MadhabPref
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import app.awrad.awrad_dhikrgoalstracker.data.repository.PrayerTimeRepository
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The single production assembly point for the planner's temporal and prayer inputs.
 * Delivery validation and background reconciliation must resolve the same preferences.
 */
fun interface NotificationObligationPlanningContextProvider {
    suspend fun create(now: Instant, zoneId: ZoneId): NotificationObligationPlanInput
}

/** Resolves the selected app language; only falls back to device Locale when none is explicit. */
object AppLanguageResolver {
    fun current(
        explicitLanguageTags: String = AppCompatDelegate.getApplicationLocales().toLanguageTags(),
        deviceLanguage: String = Locale.getDefault().language,
    ): String {
        val explicit = explicitLanguageTags
            .split(",")
            .map { it.trim() }
            .firstOrNull { it.isNotEmpty() }
        return AndroidNotificationGoalNameResolver.normalizeLanguage(
            explicit ?: deviceLanguage,
        )
    }
}

@Singleton
class ProductionNotificationObligationPlanningContextProvider @Inject constructor(
    private val preferences: UserPreferences,
    private val prayerTimes: PrayerTimeRepository,
) : NotificationObligationPlanningContextProvider {
    override suspend fun create(now: Instant, zoneId: ZoneId): NotificationObligationPlanInput {
        val latitude = preferences.latitude.first()
        val longitude = preferences.longitude.first()
        val method = preferences.calculationMethod.first().toCalculationMethod()
        val madhab = preferences.madhab.first().toMadhab()
        val dayReset = preferences.dayResetTime.first().toDayReset()
        val prayerTimesForDate: (LocalDate) -> com.batoulapps.adhan.PrayerTimes? = { date ->
            if (latitude == null || longitude == null) null
            else prayerTimes.getPrayerTimes(latitude, longitude, method, madhab, date)
        }
        return NotificationObligationPlanInput(
            now = now,
            zoneId = zoneId,
            dayReset = dayReset,
            urgencyEnabled = preferences.urgencyRemindersEnabled.first(),
            defaultPrayerLeadMinutes = preferences.prayerSlotDefaultLeadMinutes.first(),
            appLanguage = AppLanguageResolver.current(),
            maghribForCivilDate = { date -> prayerTimesForDate(date)?.maghrib?.toInstant() },
            prayerTimesForOccurrenceDate = prayerTimesForDate,
        )
    }

    private fun String.toCalculationMethod(): CalculationMethodPref =
        runCatching { CalculationMethodPref.valueOf(this) }.getOrDefault(CalculationMethodPref.KARACHI)

    private fun String.toMadhab(): MadhabPref =
        runCatching { MadhabPref.valueOf(this) }.getOrDefault(MadhabPref.SHAFI)

    private fun String.toDayReset(): DayResetOption =
        runCatching { DayResetOption.valueOf(this) }.getOrDefault(DayResetOption.MIDNIGHT)
}
