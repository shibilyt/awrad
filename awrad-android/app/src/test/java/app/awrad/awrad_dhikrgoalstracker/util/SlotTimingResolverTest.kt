package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.testId

import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import com.batoulapps.adhan.CalculationMethod
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.Madhab
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.data.DateComponents
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

class SlotTimingResolverTest {
    private val zoneId: ZoneId = ZoneId.systemDefault()
    private val friday: LocalDate = LocalDate.parse("2026-05-29")

    @Test
    fun `after prayer slot starts at prayer time`() {
        val prayerTimes = prayerTimes(friday)
        val slot = prayerSlot(PrayerRelation.AFTER)
        val dhuhr = prayerTimes.dhuhr.time

        assertFalse(
            SlotTimingResolver.isStarted(slot, friday, dhuhr - 1_000, prayerTimes, 30, zoneId),
        )
        assertTrue(
            SlotTimingResolver.isStarted(slot, friday, dhuhr, prayerTimes, 30, zoneId),
        )
    }

    @Test
    fun `before prayer slot uses global lead window`() {
        val prayerTimes = prayerTimes(friday)
        val slot = prayerSlot(PrayerRelation.BEFORE)

        val start = SlotTimingResolver.startInfo(slot, friday, prayerTimes, 30, zoneId)

        assertEquals(prayerTimes.dhuhr.time - 30 * 60_000L, start?.startsAtMillis)
    }

    @Test
    fun `before prayer slot override replaces global lead window`() {
        val prayerTimes = prayerTimes(friday)
        val slot = prayerSlot(PrayerRelation.BEFORE).copy(startLeadMinutesOverride = 10)

        val start = SlotTimingResolver.startInfo(slot, friday, prayerTimes, 30, zoneId)

        assertEquals(prayerTimes.dhuhr.time - 10 * 60_000L, start?.startsAtMillis)
    }

    @Test
    fun `time window slot starts at start minute`() {
        val slot = GoalSlot(
            goalId = testId(1),
            slotType = GoalSlotType.TIME_WINDOW,
            startMinute = 9 * 60,
            endMinute = 10 * 60,
            targetCount = 100,
        )
        val expected = friday.atTime(LocalTime.of(9, 0)).atZone(zoneId).toInstant().toEpochMilli()

        val start = SlotTimingResolver.startInfo(slot, friday, null, 30, zoneId)

        assertEquals(expected, start?.startsAtMillis)
    }

    @Test
    fun `time window slot resolves upcoming active and ended statuses`() {
        val slot = GoalSlot(
            goalId = testId(1),
            slotType = GoalSlotType.TIME_WINDOW,
            startMinute = 9 * 60,
            endMinute = 10 * 60,
            targetCount = 100,
        )

        assertEquals(
            SlotTimeStatus.UPCOMING,
            SlotTimingResolver.timingInfo(slot, friday, millisAt(8, 59), null, 30, zoneId).timeStatus,
        )
        assertEquals(
            SlotTimeStatus.ACTIVE,
            SlotTimingResolver.timingInfo(slot, friday, millisAt(9, 30), null, 30, zoneId).timeStatus,
        )
        assertEquals(
            SlotTimeStatus.ENDED,
            SlotTimingResolver.timingInfo(slot, friday, millisAt(10, 0), null, 30, zoneId).timeStatus,
        )
    }

    @Test
    fun `time window ending at day boundary displays midnight as clock zero`() {
        val slot = GoalSlot(
            goalId = testId(1),
            slotType = GoalSlotType.TIME_WINDOW,
            startMinute = 22 * 60,
            endMinute = 24 * 60,
            targetCount = 100,
        )

        val timing = SlotTimingResolver.timingInfo(slot, friday, millisAt(23, 0), null, 30, zoneId)

        assertEquals(SlotTimeStatus.ACTIVE, timing.timeStatus)
        assertEquals("10:00 PM", timing.startText)
        assertEquals("12:00 AM", timing.endText)
    }

    @Test
    fun `after prayer slot ends at next prayer`() {
        val prayerTimes = prayerTimes(friday)
        val slot = prayerSlot(PrayerRelation.AFTER)

        val timing = SlotTimingResolver.timingInfo(slot, friday, prayerTimes.asr.time - 1_000, prayerTimes, 30, zoneId)

        assertEquals(prayerTimes.dhuhr.time, timing.startsAtMillis)
        assertEquals(prayerTimes.asr.time, timing.endsAtMillis)
        assertEquals(SlotTimeStatus.ACTIVE, timing.timeStatus)
    }

    @Test
    fun `missing prayer times resolves unknown`() {
        val slot = prayerSlot(PrayerRelation.AFTER)

        val timing = SlotTimingResolver.timingInfo(slot, friday, millisAt(12, 0), null, 30, zoneId)

        assertEquals(SlotTimeStatus.UNKNOWN, timing.timeStatus)
    }

    @Test
    fun `anytime slot is always started`() {
        val slot = GoalSlot(goalId = testId(1), slotType = GoalSlotType.ANYTIME)

        assertTrue(SlotTimingResolver.isStarted(slot, friday, 0L, null, 30, zoneId))
    }

    private fun prayerSlot(relation: PrayerRelation): GoalSlot = GoalSlot(
        id = testId(10),
        goalId = testId(1),
        slotType = GoalSlotType.PRAYER,
        prayerName = Prayer.DHUHR,
        prayerRelation = relation,
        targetCount = 100,
    )

    private fun prayerTimes(date: LocalDate): PrayerTimes {
        val params = CalculationMethod.KARACHI.parameters
        params.madhab = Madhab.SHAFI
        return PrayerTimes(
            Coordinates(10.0, 76.0),
            DateComponents(date.year, date.monthValue, date.dayOfMonth),
            params,
        )
    }

    private fun millisAt(hour: Int, minute: Int): Long =
        friday.atTime(LocalTime.of(hour, minute)).atZone(zoneId).toInstant().toEpochMilli()
}
