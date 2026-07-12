package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdCadence
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdOccasion
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdTag

/** The active UI language ("ar", "en", …) for [app.awrad.awrad_dhikrgoalstracker.data.model.wird.resolve]. */
@Composable
fun currentLang(): String = LocalConfiguration.current.locales[0].language

@Composable
fun prayerName(prayer: Prayer): String = stringResource(
    when (prayer) {
        Prayer.FAJR -> R.string.prayer_fajr
        Prayer.DHUHR -> R.string.prayer_dhuhr
        Prayer.ASR -> R.string.prayer_asr
        Prayer.MAGHRIB -> R.string.prayer_maghrib
        Prayer.ISHA -> R.string.prayer_isha
    },
)

@Composable
fun occasionLabel(occasion: WirdOccasion): String = when (occasion) {
    WirdOccasion.Anytime -> stringResource(R.string.wird_occasion_anytime)
    WirdOccasion.Morning -> stringResource(R.string.wird_occasion_morning)
    WirdOccasion.Evening -> stringResource(R.string.wird_occasion_evening)
    WirdOccasion.BeforeSleep -> stringResource(R.string.wird_occasion_before_sleep)
    is WirdOccasion.TimeWindow -> stringResource(R.string.wird_occasion_time_window)
    is WirdOccasion.AfterPrayer -> stringResource(R.string.wird_occasion_after_prayer, prayerName(occasion.prayer))
}

/** Short catalog tag label (e.g. "Morning", "Ṣalawāt") for a wird's primary [WirdTag]. */
@Composable
fun wirdTagLabel(tag: WirdTag): String = stringResource(
    when (tag) {
        WirdTag.MORNING -> R.string.wird_occasion_morning
        WirdTag.EVENING -> R.string.wird_occasion_evening
        WirdTag.SALAWAT -> R.string.wird_tag_salawat
        WirdTag.PROTECTION -> R.string.wird_tag_protection
        WirdTag.QURAN -> R.string.wird_tag_quran
        WirdTag.FORGIVENESS -> R.string.wird_tag_forgiveness
        WirdTag.PRAISE -> R.string.wird_tag_praise
        WirdTag.GENERAL -> R.string.wird_tag_general
    },
)

@Composable
fun cadenceLabel(cadence: WirdCadence): String = when (cadence) {
    WirdCadence.EveryDay -> stringResource(R.string.wird_cadence_every_day)
    WirdCadence.Rotation -> stringResource(R.string.wird_cadence_rotation)
    is WirdCadence.DaysOfWeek -> stringResource(R.string.wird_cadence_specific_days)
    is WirdCadence.Interval -> stringResource(R.string.wird_cadence_interval, cadence.days)
    is WirdCadence.PartsByWeekday -> stringResource(R.string.wird_cadence_parts_by_weekday)
}
