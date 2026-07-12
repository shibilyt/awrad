package app.awrad.awrad_dhikrgoalstracker.data.wird

import java.time.LocalDate

/**
 * Converts a gregorian date to its Umm al-Qura Hijri month/day. Abstracted so [WirdEngine] stays
 * pure-JVM testable (the Android ICU implementation lives in [IcuHijriCalendar]; tests use a fake).
 */
interface HijriCalendar {
    /** @return (hijriMonth 1..12, hijriDay 1..30). */
    fun monthDay(date: LocalDate): HijriDate
}

data class HijriDate(val month: Int, val day: Int)
