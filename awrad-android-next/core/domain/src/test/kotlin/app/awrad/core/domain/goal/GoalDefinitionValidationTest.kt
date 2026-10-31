package app.awrad.core.domain.goal

import app.awrad.core.domain.AwradId
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
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
    fun `negative counts, zero log amounts and zero streak amounts are invalid`() {
        assertFailsWith<IllegalArgumentException> { CountEntry(start, sessionId = null, count = -1) }
        assertFailsWith<IllegalArgumentException> { Session.of(SessionKind.Anytime, target = -1) }
        assertFailsWith<IllegalArgumentException> { StreakThreshold.Amount(0) }
        val id = AwradId("0192f200-0000-7000-8000-000000000001")
        assertFailsWith<IllegalArgumentException> {
            CountLogEntry(id, id, start, sessionId = null, goalId = null, amount = 0, countedAt = Instant.EPOCH)
        }
    }

    @Test
    fun `session ids derive from their kind`() {
        assertEquals("anytime", SessionKind.Anytime.derivedId)
        assertEquals("before_isha", SessionKind.BeforePrayer(Prayer.ISHA).derivedId)
        assertEquals("after_fajr", SessionKind.AfterPrayer(Prayer.FAJR).derivedId)
        assertEquals("at_0630", SessionKind.AtTime(LocalTime.of(6, 30)).derivedId)
        assertEquals("between_2100_0030", SessionKind.Between(LocalTime.of(21, 0), LocalTime.of(0, 30)).derivedId)
    }

    @Test
    fun `an edit is validated with the rest of the timeline`() {
        val settings = GoalSettings(
            schedule = Schedule.EveryDay,
            activePeriod = ActivePeriod(start),
            countPolicy = CountPolicy(target = 100, streakThreshold = StreakThreshold.Target),
            requirement = Requirement.PerDueDate,
        )
        val timeline = (GoalTimeline.create(start, listOf(GoalVersion(start, settings))) as GoalTimelineResult.Valid)
            .timeline
        val noTarget = settings.copy(
            countPolicy = CountPolicy(target = null, streakThreshold = StreakThreshold.AnyCount),
        )
        val edited = timeline.withEdit(noTarget, start.plusDays(3))
        assertEquals(GoalTimelineResult.Invalid(setOf(GoalDefinitionError.TARGET_REQUIRED)), edited)
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
