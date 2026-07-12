package app.awrad.awrad_dhikrgoalstracker.data.wird

import app.awrad.awrad_dhikrgoalstracker.data.model.wird.HijriAnchor
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.SegmentKind
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdCadence
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdOccasion
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.WirdSession
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalTime

class WirdEngineTest {

    private fun engine(hijri: HijriCalendar = FakeHijriCalendar()) = WirdEngine(hijri)

    // §3.1 — effective target = repeat × blockRepeat.
    @Test
    fun effectiveTarget_multipliesBlockRepeat() {
        val e = engine()
        val seg = segment("s", count = 3)
        val p = part("p", blockRepeat = 4, segments = listOf(seg))
        assertEquals(12, e.effectiveTarget(seg, p))
    }

    @Test
    fun effectiveTarget_usesRangeMinAsTarget() {
        val e = engine()
        val seg = segment("s", min = 33, max = 100)
        val p = part("p", segments = listOf(seg))
        assertEquals(33, e.effectiveTarget(seg, p))
    }

    // §3.2 — only countable segments count; headings ignored.
    @Test
    fun completion_ignoresNonCountableSegments() {
        val e = engine()
        val heading = segment("h", kind = SegmentKind.HEADING)
        val dhikr = segment("d", count = 1)
        val p = part("p", segments = listOf(heading, dhikr))
        val session = WirdSession("w", "p", dateKey = "2026-06-14", segmentProgress = mapOf("d" to 1))
        assertEquals(1, e.progressSummary(p, session).totalItems)
        assertTrue(e.isPartComplete(p, session))
    }

    // §3.7 — counting is capped at effective target.
    @Test
    fun increment_capsAtEffectiveTarget() {
        val e = engine()
        val seg = segment("s", count = 2)
        val p = part("p", blockRepeat = 2, segments = listOf(seg)) // target = 4
        var session: WirdSession? = null
        var last = 0
        repeat(10) {
            val r = e.incrementSegment(p, seg, session, "w", "anytime", "2026-06-14", 1000L)
            session = r.session
            last = r.newCount
        }
        assertEquals(4, last)
        assertEquals(4, session!!.count("s"))
        assertTrue(session!!.isComplete)
        assertEquals(1000L, session!!.completedAt)
    }

    // §3.4 — daysOfWeek uses Sunday=1..Saturday=7.
    @Test
    fun isActive_daysOfWeek_sundayBased() {
        val e = engine()
        // 2026-06-15 is a Monday → sunday-based weekday 2.
        val monday = LocalDate.of(2026, 6, 15)
        val w = wird(cadence = WirdCadence.DaysOfWeek(setOf(2, 5)), parts = listOf(part("p", segments = listOf(segment("s")))))
        assertTrue(e.isActive(w, monday))
        assertFalse(e.isActive(w, monday.plusDays(1))) // Tuesday = 3
    }

    // §3.4 — interval cadence.
    @Test
    fun isActive_interval_everyTwoDays() {
        val e = engine()
        val w = wird(
            cadence = WirdCadence.Interval(days = 2, anchor = "2026-06-14"),
            parts = listOf(part("p", segments = listOf(segment("s")))),
        )
        assertTrue(e.isActive(w, LocalDate.of(2026, 6, 14)))
        assertFalse(e.isActive(w, LocalDate.of(2026, 6, 15)))
        assertTrue(e.isActive(w, LocalDate.of(2026, 6, 16)))
    }

    // §3.5 — rotation picks one part using the 2001-01-01 reference.
    @Test
    fun activeParts_rotation_usesReferenceDate() {
        val e = engine()
        val parts = listOf(
            part("a", segments = listOf(segment("s1"))),
            part("b", segments = listOf(segment("s2"))),
            part("c", segments = listOf(segment("s3"))),
        )
        val w = wird(cadence = WirdCadence.Rotation, parts = parts)
        // diff days from 2001-01-01 mod 3 determines index; verify determinism + single part.
        val day = LocalDate.of(2001, 1, 1)
        assertEquals(listOf("a"), e.activeParts(w, day).map { it.id })
        assertEquals(listOf("b"), e.activeParts(w, day.plusDays(1)).map { it.id })
        assertEquals(listOf("c"), e.activeParts(w, day.plusDays(2)).map { it.id })
        assertEquals(listOf("a"), e.activeParts(w, day.plusDays(3)).map { it.id })
    }

    @Test
    fun activeParts_partsByWeekday_canReturnMultipleParts() {
        val e = engine()
        val parts = listOf(
            part("a", segments = listOf(segment("s1"))),
            part("b", segments = listOf(segment("s2"))),
            part("c", segments = listOf(segment("s3"))),
        )
        val w = wird(
            cadence = WirdCadence.PartsByWeekday(
                mapOf(
                    2 to listOf(2, 0),
                    3 to listOf(1),
                ),
            ),
            parts = parts,
        )
        val monday = LocalDate.of(2026, 6, 15)

        assertTrue(e.isActive(w, monday))
        assertEquals(listOf("c", "a"), e.activeParts(w, monday).map { it.id })
        assertEquals(listOf("b"), e.activeParts(w, monday.plusDays(1)).map { it.id })
        assertFalse(e.isActive(w, monday.plusDays(2)))
        assertEquals(emptyList<String>(), e.activeParts(w, monday.plusDays(2)).map { it.id })
    }

    // §3.4 — hijri gate (ramadan = month 9).
    @Test
    fun isActive_hijriRamadanGate() {
        val ramadanDay = LocalDate.of(2026, 3, 20)
        val nonRamadan = LocalDate.of(2026, 6, 14)
        val hijri = FakeHijriCalendar(
            default = HijriDate(6, 10),
            byDate = mapOf(ramadanDay to HijriDate(9, 5)),
        )
        val e = engine(hijri)
        val w = wird(hijriAnchor = HijriAnchor.Ramadan, parts = listOf(part("p", segments = listOf(segment("s")))))
        assertTrue(e.isActive(w, ramadanDay))
        assertFalse(e.isActive(w, nonRamadan))
    }

    @Test
    fun isActive_lastTenNightsGate() {
        val e = engine(FakeHijriCalendar(default = HijriDate(9, 22)))
        val w = wird(hijriAnchor = HijriAnchor.LastTenNights, parts = listOf(part("p", segments = listOf(segment("s")))))
        assertTrue(e.isActive(w, LocalDate.of(2026, 3, 30)))

        val e2 = engine(FakeHijriCalendar(default = HijriDate(9, 15)))
        assertFalse(e2.isActive(w, LocalDate.of(2026, 3, 25)))
    }

    // §3.10 — streak: today pending doesn't break; inactive days skipped; gap breaks.
    @Test
    fun streak_todayPendingDoesNotBreak() {
        val e = engine()
        val w = wird(parts = listOf(part("p", segments = listOf(segment("s")))))
        val today = LocalDate.of(2026, 6, 14)
        val sessions = listOf(
            complete(w.id, "p", "2026-06-13"),
            complete(w.id, "p", "2026-06-12"),
        )
        // Today not yet complete, prior two days complete → streak 2.
        assertEquals(2, e.streak(w, sessions, today))
    }

    @Test
    fun streak_breaksOnMissedActiveDay() {
        val e = engine()
        val w = wird(parts = listOf(part("p", segments = listOf(segment("s")))))
        val today = LocalDate.of(2026, 6, 14)
        val sessions = listOf(
            complete(w.id, "p", "2026-06-14"),
            // 2026-06-13 missing
            complete(w.id, "p", "2026-06-12"),
        )
        assertEquals(1, e.streak(w, sessions, today))
    }

    @Test
    fun streak_skipsInactiveDays() {
        val e = engine()
        // Active only Sundays (weekday 1).
        val w = wird(
            cadence = WirdCadence.DaysOfWeek(setOf(1)),
            parts = listOf(part("p", segments = listOf(segment("s")))),
        )
        // 2026-06-14 is a Sunday.
        val today = LocalDate.of(2026, 6, 14)
        val sessions = listOf(
            complete(w.id, "p", "2026-06-14"),
            complete(w.id, "p", "2026-06-07"),
        )
        assertEquals(2, e.streak(w, sessions, today))
    }

    // §3.6 — occasion windows.
    @Test
    fun window_morningFallbackWhenNoPrayerTimes() {
        val e = engine()
        val w = e.window(WirdOccasion.Morning, emptyMap())
        assertEquals(LocalTime.of(4, 0), w.start)
        assertEquals(LocalTime.of(12, 0), w.end)
        assertTrue(w.isActiveNow(LocalTime.of(8, 0)))
        assertFalse(w.isActiveNow(LocalTime.of(13, 0)))
    }

    @Test
    fun window_afterPrayerUsesNextPrayer() {
        val e = engine()
        val times = mapOf(
            Prayer.FAJR to LocalTime.of(5, 0),
            Prayer.DHUHR to LocalTime.of(12, 30),
        )
        val w = e.window(WirdOccasion.AfterPrayer(Prayer.FAJR), times)
        assertEquals(LocalTime.of(5, 0), w.start)
        assertEquals(LocalTime.of(12, 30), w.end)
    }

    private fun complete(wirdID: String, partID: String, dateKey: String) =
        WirdSession(wirdID, partID, dateKey = dateKey, isComplete = true)
}
