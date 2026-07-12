package app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation

import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import java.time.DayOfWeek
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalScheduleUpdateFactoryTest {

    @Test
    fun `valid schedule modes update recurrence`() {
        listOf(
            ScheduleSpec.Daily,
            ScheduleSpec.Weekly(setOf(DayOfWeek.MONDAY, DayOfWeek.THURSDAY)),
            ScheduleSpec.Monthly(CalendarSystem.GREGORIAN, setOf(1, 15)),
            ScheduleSpec.Interval(3),
            ScheduleSpec.Yearly(CalendarSystem.HIJRI, month = 9, daysOfMonth = setOf(1, 27)),
            ScheduleSpec.Season(SeasonTemplateCode.RAMADAN_LAST_10),
            ScheduleSpec.SpecificDates(setOf(LocalDate.parse("2026-06-10"))),
        ).forEach { schedule ->
            val update = validUpdate(command = command(schedule = schedule))
            assertEquals(schedule.expectedFrequency(), update.goal.recurrence.frequency)
        }
    }

    @Test
    fun `invalid empty weekly monthly and specific dates are rejected`() {
        listOf(
            ScheduleSpec.Weekly(emptySet()),
            ScheduleSpec.Monthly(daysOfMonth = emptySet()),
            ScheduleSpec.SpecificDates(emptySet()),
        ).forEach { schedule ->
            val result = GoalScheduleUpdateFactory.update(goal(), command(schedule = schedule))
            assertTrue(result is GoalUpdateResult.Invalid)
            assertTrue((result as GoalUpdateResult.Invalid).errors.contains(GoalUpdateError.InvalidSchedule))
        }
    }

    @Test
    fun `invalid interval and month day ranges are rejected`() {
        listOf(
            ScheduleSpec.Interval(0),
            ScheduleSpec.Monthly(daysOfMonth = setOf(0)),
            ScheduleSpec.Yearly(CalendarSystem.HIJRI, month = 13, daysOfMonth = setOf(1)),
            ScheduleSpec.Yearly(CalendarSystem.HIJRI, month = 9, daysOfMonth = setOf(32)),
        ).forEach { schedule ->
            val result = GoalScheduleUpdateFactory.update(goal(), command(schedule = schedule))
            assertTrue(result is GoalUpdateResult.Invalid)
        }
    }

    @Test
    fun `switching to prayer slots archives old active slot and creates inherited sessions`() {
        val existing = goal(
            slots = listOf(
                slot(
                    id = 10,
                    slotType = GoalSlotType.TIME_WINDOW,
                    targetCount = 33,
                    maximumCount = 50,
                    capBehavior = CountCapBehavior.BlockAtMaximum,
                    label = "Morning",
                )
            ),
            maximumCount = 50,
            capBehavior = CountCapBehavior.BlockAtMaximum,
        )
        val update = validUpdate(
            existingGoal = existing,
            command = command(
                timing = ScheduleTimingUpdate.PrayerBased(
                    listOf(
                        PrayerSlotUpdate(prayer = Prayer.FAJR, relation = PrayerRelation.AFTER),
                        PrayerSlotUpdate(prayer = Prayer.ISHA, relation = PrayerRelation.AFTER),
                    )
                )
            ),
        )

        assertEquals(2, update.goal.slots.size)
        assertTrue(update.goal.slots.all { it.slotType == GoalSlotType.PRAYER })
        assertEquals(listOf(10L), update.goal.archivedSlots.map { it.id })
        assertEquals(false, update.goal.archivedSlots.single().isActive)
        assertEquals(66, update.goal.slots.sumOf { it.targetCount ?: 0 })
        assertEquals(100, update.goal.maximumCount)
    }

    @Test
    fun `editing existing time windows preserves ids and count rules`() {
        val existing = goal(
            slots = listOf(
                slot(id = 10, startMinute = 6 * 60, endMinute = 8 * 60, label = "Morning"),
                slot(id = 11, startMinute = 18 * 60, endMinute = 20 * 60, label = "Evening"),
            )
        )
        val update = validUpdate(
            existingGoal = existing,
            command = command(
                timing = ScheduleTimingUpdate.TimeWindows(
                    listOf(
                        TimeWindowSlotUpdate(slotId = 11, label = "Night", startMinute = 20 * 60, endMinute = 22 * 60),
                        TimeWindowSlotUpdate(slotId = 10, label = "Morning", startMinute = 7 * 60, endMinute = 9 * 60),
                    )
                )
            ),
        )

        assertEquals(listOf(11L, 10L), update.goal.slots.map { it.id })
        assertEquals(listOf(0, 1), update.goal.slots.map { it.sortOrder })
        assertEquals(listOf(100, 100), update.goal.slots.map { it.targetCount })
        assertTrue(update.goal.archivedSlots.isEmpty())
    }

    @Test
    fun `adding time window to multi-session goal copies per-session count policy`() {
        val existing = goal(
            slots = listOf(
                slot(
                    id = 10,
                    targetCount = 100,
                    maximumCount = 150,
                    capBehavior = CountCapBehavior.WarnOverTarget,
                    startMinute = 6 * 60,
                    endMinute = 7 * 60,
                    label = "Morning",
                    sortOrder = 0,
                ),
                slot(
                    id = 11,
                    targetCount = 100,
                    maximumCount = 150,
                    capBehavior = CountCapBehavior.WarnOverTarget,
                    startMinute = 9 * 60,
                    endMinute = 10 * 60,
                    label = "Midday",
                    sortOrder = 1,
                ),
            ),
            maximumCount = 300,
            capBehavior = CountCapBehavior.WarnOverTarget,
        )
        val update = validUpdate(
            existingGoal = existing,
            command = command(
                timing = ScheduleTimingUpdate.TimeWindows(
                    listOf(
                        TimeWindowSlotUpdate(slotId = 10, label = "Morning", startMinute = 6 * 60, endMinute = 7 * 60),
                        TimeWindowSlotUpdate(slotId = 11, label = "Midday", startMinute = 9 * 60, endMinute = 10 * 60),
                        TimeWindowSlotUpdate(label = "Afternoon", startMinute = 12 * 60, endMinute = 13 * 60),
                    )
                )
            ),
        )

        assertEquals(listOf(100, 100, 100), update.goal.slots.map { it.targetCount })
        assertEquals(listOf(150, 150, 150), update.goal.slots.map { it.maximumCount })
        assertEquals(300, update.goal.slots.sumOf { it.targetCount ?: 0 })
        assertEquals(450, update.goal.maximumCount)
    }

    @Test
    fun `duplicate prayer slots and invalid windows are rejected`() {
        val duplicatePrayer = GoalScheduleUpdateFactory.update(
            goal(),
            command(
                timing = ScheduleTimingUpdate.PrayerBased(
                    listOf(
                        PrayerSlotUpdate(prayer = Prayer.FAJR, relation = PrayerRelation.AFTER),
                        PrayerSlotUpdate(prayer = Prayer.FAJR, relation = PrayerRelation.AFTER),
                    )
                )
            ),
        )
        val invalidWindow = GoalScheduleUpdateFactory.update(
            goal(),
            command(
                timing = ScheduleTimingUpdate.TimeWindows(
                    listOf(TimeWindowSlotUpdate(label = "Bad", startMinute = 10 * 60, endMinute = 9 * 60))
                )
            ),
        )

        assertTrue(duplicatePrayer is GoalUpdateResult.Invalid)
        assertTrue((duplicatePrayer as GoalUpdateResult.Invalid).errors.contains(GoalUpdateError.DuplicateSlotPolicy))
        assertTrue(invalidWindow is GoalUpdateResult.Invalid)
        assertTrue((invalidWindow as GoalUpdateResult.Invalid).errors.contains(GoalUpdateError.InvalidTiming))
    }

    @Test
    fun `slot reminders tied to archived slots are removed while fixed reminders remain`() {
        val existing = goal(
            slots = listOf(slot(id = 10), slot(id = 11, label = "Evening")),
            reminders = listOf(
                GoalReminder(id = 1, goalId = 1, reminderType = ReminderType.FIXED_TIME, hour = 6, minute = 0),
                GoalReminder(id = 2, goalId = 1, slotId = 11, reminderType = ReminderType.TIME_WINDOW_START),
            ),
        )
        val update = validUpdate(
            existingGoal = existing,
            command = command(
                timing = ScheduleTimingUpdate.Anytime(slotId = 10),
            ),
        )

        assertEquals(listOf(1L), update.goal.reminders.map { it.id })
        assertEquals(listOf(11L), update.goal.archivedSlots.map { it.id })
    }

    private fun validUpdate(
        existingGoal: Goal = goal(),
        command: UpdateGoalScheduleCommand,
    ): ValidatedGoalUpdate =
        (GoalScheduleUpdateFactory.update(existingGoal, command) as GoalUpdateResult.Valid).validatedGoalUpdate

    private fun command(
        schedule: ScheduleSpec = ScheduleSpec.Daily,
        timing: ScheduleTimingUpdate = ScheduleTimingUpdate.Anytime(slotId = 10),
    ) = UpdateGoalScheduleCommand(
        goalId = 1,
        schedule = schedule,
        timing = timing,
        archivedAtMillis = 1234L,
    )

    private fun goal(
        slots: List<GoalSlot> = listOf(slot(id = 10)),
        reminders: List<GoalReminder> = emptyList(),
        maximumCount: Int? = null,
        capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
    ) = Goal(
        id = 1,
        dhikrId = 1,
        slots = slots,
        reminders = reminders,
        startDate = LocalDate.parse("2026-05-27"),
        maximumCount = maximumCount,
        capBehavior = capBehavior,
    )

    private fun slot(
        id: Long,
        slotType: GoalSlotType = GoalSlotType.TIME_WINDOW,
        targetCount: Int? = 100,
        maximumCount: Int? = null,
        capBehavior: CountCapBehavior = CountCapBehavior.AllowOverTarget,
        startMinute: Int? = 6 * 60,
        endMinute: Int? = 9 * 60,
        label: String? = "Session",
        sortOrder: Int = 0,
    ) = GoalSlot(
        id = id,
        goalId = 1,
        slotType = slotType,
        targetCount = targetCount,
        maximumCount = maximumCount,
        capBehavior = capBehavior,
        startMinute = startMinute,
        endMinute = endMinute,
        label = label,
        sortOrder = sortOrder,
    )

    private fun ScheduleSpec.expectedFrequency(): RecurrenceFrequency =
        when (this) {
            ScheduleSpec.Daily -> RecurrenceFrequency.DAILY
            is ScheduleSpec.Weekly -> RecurrenceFrequency.WEEKLY
            is ScheduleSpec.Monthly -> RecurrenceFrequency.MONTHLY
            is ScheduleSpec.Interval -> RecurrenceFrequency.INTERVAL
            is ScheduleSpec.Yearly -> RecurrenceFrequency.YEARLY
            is ScheduleSpec.Season -> RecurrenceFrequency.SEASON
            is ScheduleSpec.SpecificDates -> RecurrenceFrequency.SPECIFIC_DATES
        }
}
