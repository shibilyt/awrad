package app.awrad.awrad_dhikrgoalstracker.data.wird

import android.icu.util.IslamicCalendar
import android.icu.util.ULocale
import java.time.LocalDate
import java.util.GregorianCalendar
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Umm al-Qura Hijri conversion backed by Android's ICU (available at min SDK 26). Matches the iOS
 * `islamicUmmAlQura` calendar.
 */
@Singleton
class IcuHijriCalendar @Inject constructor() : HijriCalendar {

    override fun monthDay(date: LocalDate): HijriDate {
        val cal = IslamicCalendar(ULocale.US).apply {
            setCalculationType(IslamicCalendar.CalculationType.ISLAMIC_UMALQURA)
            // Anchor at local noon to avoid timezone day-boundary drift.
            val g = GregorianCalendar(date.year, date.monthValue - 1, date.dayOfMonth, 12, 0, 0)
            timeInMillis = g.timeInMillis
        }
        // ICU months are 0-based.
        return HijriDate(month = cal.get(IslamicCalendar.MONTH) + 1, day = cal.get(IslamicCalendar.DAY_OF_MONTH))
    }
}
