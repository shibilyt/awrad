package app.awrad.awrad_dhikrgoalstracker.util

import android.content.Context
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import java.time.LocalDate
import java.time.chrono.HijrahDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoField
import java.util.Locale

object DateUtils {

    private val hijriMonthNames = arrayOf(
        "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
        "Jumada al-Ula", "Jumada al-Thani", "Rajab", "Sha'ban",
        "Ramadan", "Shawwal", "Dhul Qa'dah", "Dhul Hijjah"
    )

    /** Localized month name for the given 1-based month in the chosen calendar system. */
    fun monthName(month: Int, calendarSystem: CalendarSystem): String = when (calendarSystem) {
        CalendarSystem.HIJRI -> hijriMonthNames[(month - 1).coerceIn(0, 11)]
        CalendarSystem.GREGORIAN ->
            java.time.Month.of(month.coerceIn(1, 12)).getDisplayName(java.time.format.TextStyle.FULL, Locale.getDefault())
    }

    fun getHijriDate(date: LocalDate = LocalDate.now()): String {
        val hijrahDate = HijrahDate.from(date)
        val day = hijrahDate.get(ChronoField.DAY_OF_MONTH)
        val month = hijrahDate.get(ChronoField.MONTH_OF_YEAR)
        val year = hijrahDate.get(ChronoField.YEAR)
        return "$day ${hijriMonthNames[month - 1]} $year AH"
    }

    fun getGregorianFormatted(date: LocalDate = LocalDate.now()): String {
        return date.format(DateTimeFormatter.ofPattern("EEEE, MMMM d, yyyy", Locale.ENGLISH))
    }

    /**
     * Returns the primary date display string based on the user's calendar system preference.
     */
    fun getPrimaryDate(calendarSystem: CalendarSystem, date: LocalDate = LocalDate.now()): String =
        when (calendarSystem) {
            CalendarSystem.HIJRI -> getHijriDate(date)
            CalendarSystem.GREGORIAN -> getGregorianFormatted(date)
        }

    /**
     * Returns the secondary date display string (the other calendar system).
     */
    fun getSecondaryDate(calendarSystem: CalendarSystem, date: LocalDate = LocalDate.now()): String =
        when (calendarSystem) {
            CalendarSystem.HIJRI -> getGregorianFormatted(date)
            CalendarSystem.GREGORIAN -> getHijriDate(date)
        }

    fun getGreetingForTimeOfDay(context: Context): String {
        val hour = java.time.LocalTime.now().hour
        return context.getString(when {
            hour < 12 -> R.string.greeting_morning
            hour < 17 -> R.string.greeting_afternoon
            else -> R.string.greeting_evening
        })
    }
}
