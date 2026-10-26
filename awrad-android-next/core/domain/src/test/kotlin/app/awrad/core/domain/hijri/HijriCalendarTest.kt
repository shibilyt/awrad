package app.awrad.core.domain.hijri

import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull

/** Properties of the bundled table the fixtures sample but don't sweep. */
class HijriCalendarTest {

    private val calendar = HijriCalendar(HijriCorrections.NONE)

    @Test
    fun `every day of the table has the next Hijri date`() {
        var expected = HijriDate(1400, 1, 1)
        var day = calendar.firstDay
        while (!day.isAfter(calendar.lastDay)) {
            val month = checkNotNull(calendar.monthOf(day)) { "No Hijri date for $day" }
            assertEquals(expected, month.dateOf(day), "On $day")
            expected = if (day == month.lastDay) month.firstOfNext() else expected.copy(day = expected.day + 1)
            day = day.plusDays(1)
        }
        assertEquals(HijriDate(1501, 1, 1), expected)
    }

    @Test
    fun `the table runs from 1 Muharram 1400 to the end of 1500`() {
        assertEquals(LocalDate.of(1979, 11, 21), calendar.firstDay)
        assertEquals(LocalDate.of(2077, 11, 16), calendar.lastDay)
        assertNull(calendar.monthOf(calendar.firstDay.minusDays(1)))
        assertNull(calendar.monthOf(calendar.lastDay.plusDays(1)))
    }

    @Test
    fun `a valid set is the same whatever its order`() {
        val ramadan = HijriCorrection(1447, 9, 1)
        val shawwal = HijriCorrection(1447, 10, 0)
        val first = assertIs<HijriCorrectionsResult.Valid>(HijriCorrections.create(listOf(ramadan, shawwal)))
        val second = assertIs<HijriCorrectionsResult.Valid>(HijriCorrections.create(listOf(shawwal, ramadan)))
        assertEquals(first.corrections, second.corrections)
        assertEquals(HijriCalendar(first.corrections), HijriCalendar(second.corrections))
    }

    private fun HijriMonth.firstOfNext(): HijriDate =
        if (month < HijriDate.MONTHS_PER_YEAR) HijriDate(year, month + 1, 1) else HijriDate(year + 1, 1, 1)
}
