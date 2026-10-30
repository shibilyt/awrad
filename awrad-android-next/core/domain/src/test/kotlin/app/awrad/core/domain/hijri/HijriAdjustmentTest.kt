package app.awrad.core.domain.hijri

import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class HijriAdjustmentTest {

    private val months = (1447..1449).flatMap { year -> (1..12).map { year to it } }

    @Test
    fun `from the table, a month moves one day, in the one direction the month before allows`() {
        months.forEach { (year, month) ->
            val allowed = HijriAdjustment.allowedOffsets(HijriCorrections.NONE, year, month)
            assertTrue(allowed == listOf(-1, 0) || allowed == listOf(0, 1), "$year-$month: $allowed")
            (-2..2).forEach { offset ->
                val result = HijriAdjustment.withOffset(HijriCorrections.NONE, year, month, offset)
                assertEquals(offset in allowed, result != null, "$year-$month $offset")
            }
        }
    }

    @Test
    fun `the carried offset needs no correction of its own`() {
        val (year, month, moved) = movedMonth()
        val offset = moved.corrections.single().offsetDays
        val (nextYear, nextMonth) = if (month == 12) year + 1 to 1 else year to month + 1
        assertEquals(offset, HijriAdjustment.offsetInForce(moved, nextYear, nextMonth))
        assertEquals(moved, HijriAdjustment.withOffset(moved, nextYear, nextMonth, offset))
        assertEquals(HijriCorrections.NONE, HijriAdjustment.withOffset(moved, year, month, 0))
    }

    @Test
    fun `two days takes two months in a row, and the first can't be removed alone`() {
        val (first, second) = months.zipWithNext().firstNotNullOf { (a, b) ->
            val one = HijriAdjustment.withOffset(HijriCorrections.NONE, a.first, a.second, 1)
            one?.let { HijriAdjustment.withOffset(it, b.first, b.second, 2) }?.let { a to b }
        }
        val set = checkNotNull(
            HijriAdjustment.withOffset(HijriCorrections.NONE, first.first, first.second, 1)
                ?.let { HijriAdjustment.withOffset(it, second.first, second.second, 2) },
        )
        val firstCorrection = HijriCorrection(first.first, first.second, 1)
        val secondCorrection = HijriCorrection(second.first, second.second, 2)
        assertNull(HijriAdjustment.without(set, firstCorrection))
        assertNotNull(HijriAdjustment.without(set, secondCorrection))
    }

    @Test
    fun `the next month is offered from day 29`() {
        val calendar = HijriCalendar(HijriCorrections.NONE)
        val day28 = generateSequence(LocalDate.of(2026, 10, 29)) { it.plusDays(1) }
            .first { calendar.dateOf(it)?.day == 28 }
        assertEquals(1, HijriAdjustment.adjustableMonths(calendar, day28).size)
        assertEquals(2, HijriAdjustment.adjustableMonths(calendar, day28.plusDays(1)).size)
    }

    /** The first month in range that can move a day later, moved. */
    private fun movedMonth(): Triple<Int, Int, HijriCorrections> = months.firstNotNullOf { (year, month) ->
        HijriAdjustment.withOffset(HijriCorrections.NONE, year, month, 1)?.let { Triple(year, month, it) }
    }
}
