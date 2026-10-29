package app.awrad.feature.practice

import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import app.awrad.core.domain.hijri.HijriCorrections
import app.awrad.core.domain.hijri.HijriDate
import app.awrad.core.domain.practice.CalculationMethod
import app.awrad.core.domain.practice.DayReset
import app.awrad.core.domain.practice.DeviceLocation
import app.awrad.core.domain.practice.Madhab
import app.awrad.core.domain.practice.WeekStart
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/* Every value the page shows, from the module's string resources (en, ar, ml). */

@StringRes
internal fun dayResetLabel(dayReset: DayReset): Int = when (dayReset) {
    DayReset.MIDNIGHT -> R.string.practice_day_reset_midnight
    DayReset.MAGHRIB -> R.string.practice_day_reset_maghrib
}

@StringRes
internal fun methodLabel(method: CalculationMethod): Int = when (method) {
    CalculationMethod.KARACHI -> R.string.practice_method_karachi
    CalculationMethod.NORTH_AMERICA -> R.string.practice_method_north_america
    CalculationMethod.MUSLIM_WORLD_LEAGUE -> R.string.practice_method_muslim_world_league
    CalculationMethod.EGYPTIAN -> R.string.practice_method_egyptian
    CalculationMethod.UMM_AL_QURA -> R.string.practice_method_umm_al_qura
    CalculationMethod.MOONSIGHTING_COMMITTEE -> R.string.practice_method_moonsighting_committee
    CalculationMethod.DUBAI -> R.string.practice_method_dubai
    CalculationMethod.KUWAIT -> R.string.practice_method_kuwait
    CalculationMethod.QATAR -> R.string.practice_method_qatar
    CalculationMethod.SINGAPORE -> R.string.practice_method_singapore
}

@StringRes
internal fun madhabLabel(madhab: Madhab): Int = when (madhab) {
    Madhab.SHAFI -> R.string.practice_madhab_shafi
    Madhab.HANAFI -> R.string.practice_madhab_hanafi
}

@StringRes
internal fun weekStartLabel(weekStart: WeekStart): Int = when (weekStart) {
    WeekStart.SATURDAY -> R.string.practice_week_saturday
    WeekStart.SUNDAY -> R.string.practice_week_sunday
    WeekStart.MONDAY -> R.string.practice_week_monday
}

/** An offset from the Umm al-Qura table, as when the month starts. */
@StringRes
internal fun offsetLabel(offsetDays: Int): Int = when {
    offsetDays <= -HijriCorrections.MAX_OFFSET_DAYS -> R.string.practice_offset_minus_2
    offsetDays < 0 -> R.string.practice_offset_minus_1
    offsetDays == 0 -> R.string.practice_offset_zero
    offsetDays < HijriCorrections.MAX_OFFSET_DAYS -> R.string.practice_offset_plus_1
    else -> R.string.practice_offset_plus_2
}

/** "Jumada al-Ula 1448". */
@Composable
internal fun monthYearText(year: Int, month: Int): String =
    stringResource(R.string.practice_month_year, stringArrayResource(R.array.practice_hijri_months)[month - 1], year)

/** "12 Jumada al-Ula 1448". */
@Composable
internal fun hijriDateText(date: HijriDate): String = stringResource(
    R.string.practice_hijri_date,
    date.day,
    stringArrayResource(R.array.practice_hijri_months)[date.month - 1],
    date.year,
)

/** A time in the app's language, short ("6:03 PM"). */
@Composable
internal fun timeText(time: ZonedDateTime): String {
    val locale = LocalConfiguration.current.locales[0] ?: Locale.getDefault()
    return DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale).format(time)
}

/** The chosen place: its name, or "Your current location" for a GPS reading. */
@Composable
internal fun locationText(location: DeviceLocation): String =
    location.name ?: stringResource(R.string.practice_location_gps)

/** A country's name in the app's language, from the platform's locale data. */
@Composable
internal fun countryName(country: String): String {
    val locale = LocalConfiguration.current.locales[0] ?: Locale.getDefault()
    val region = runCatching { Locale.Builder().setRegion(country).build() }.getOrNull()
    return region?.getDisplayCountry(locale)?.ifEmpty { null } ?: country
}
