package app.awrad.core.domain.goal

import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

/** Slice 1 inventory rows 4 and 7: invalid shapes are rejected at the boundary, not read as "every day". */
class GoalDefinitionValidationTest {

    private val start = LocalDate.of(2026, 10, 1)

    @Test
    fun `empty weekday, month-day and date sets are invalid`() {
        assertFailsWith<IllegalArgumentException> { Schedule.Weekdays(emptySet()) }
        assertFailsWith<IllegalArgumentException> { Schedule.MonthDays(emptySet()) }
        assertFailsWith<IllegalArgumentException> { Schedule.SpecificDates(emptySet()) }
    }

    @Test
    fun `out-of-range intervals and month days are invalid`() {
        assertFailsWith<IllegalArgumentException> { Schedule.EveryNDays(every = 0, anchorDate = null) }
        assertFailsWith<IllegalArgumentException> { Schedule.MonthDays(setOf(0)) }
        assertFailsWith<IllegalArgumentException> { Schedule.MonthDays(setOf(32)) }
    }

    @Test
    fun `a duration of zero or less is invalid`() {
        assertFailsWith<IllegalArgumentException> { ActivePeriod(start, durationDays = 0) }
        assertFailsWith<IllegalArgumentException> { ActivePeriod(start, durationDays = -1) }
    }

    @Test
    fun `the earlier of end date and duration is the last day`() {
        assertEquals(LocalDate.of(2026, 10, 3), ActivePeriod(start, LocalDate.of(2026, 10, 31), 3).lastDay)
        assertEquals(LocalDate.of(2026, 10, 5), ActivePeriod(start, LocalDate.of(2026, 10, 5), 30).lastDay)
        assertNull(ActivePeriod(start).lastDay)
    }

    @Test
    fun `negative counts and duplicate session ids are invalid`() {
        assertFailsWith<IllegalArgumentException> { CountEntry(start, sessionId = null, count = -1) }
        val policy = CountPolicy(target = 33, streakThreshold = StreakThreshold.TARGET)
        assertFailsWith<IllegalArgumentException> {
            GoalDefinition.create(
                schedule = Schedule.EveryDay,
                activePeriod = ActivePeriod(start),
                countPolicy = policy,
                sessions = listOf(Session("fajr", policy), Session("fajr", policy)),
                requirement = Requirement.PerDueDate,
            )
        }
    }

    @Test
    fun `empty and out-of-range Hijri month days are invalid`() {
        assertFailsWith<IllegalArgumentException> { Schedule.HijriMonthDays(emptySet()) }
        assertFailsWith<IllegalArgumentException> { Schedule.HijriMonthDays(setOf(0)) }
        assertFailsWith<IllegalArgumentException> { Schedule.HijriMonthDays(setOf(31)) }
    }

    @Test
    fun `impossible yearly days are invalid, 29 February is not`() {
        fun yearly(calendar: CalendarSystem, month: Int, day: Int) =
            Schedule.Yearly(calendar, listOf(YearlyRange(YearlyDay(month, day), YearlyDay(month, day))))

        assertFailsWith<IllegalArgumentException> { Schedule.Yearly(CalendarSystem.HIJRI, emptyList()) }
        assertFailsWith<IllegalArgumentException> { yearly(CalendarSystem.GREGORIAN, 2, 30) }
        assertFailsWith<IllegalArgumentException> { yearly(CalendarSystem.GREGORIAN, 4, 31) }
        assertFailsWith<IllegalArgumentException> { yearly(CalendarSystem.HIJRI, 9, 31) }
        assertFailsWith<IllegalArgumentException> { YearlyDay(13, 1) }
        assertFailsWith<IllegalArgumentException> { YearlyDay(1, 0) }
        yearly(CalendarSystem.GREGORIAN, 2, 29)
        yearly(CalendarSystem.HIJRI, 12, 30)
    }
}
