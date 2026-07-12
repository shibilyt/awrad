package app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation

import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate

class GoalFactoryTest {

    @Test
    fun `daily fixed goal creates per due date anytime target`() {
        val goal = validGoal(
            command = command(countPolicy = CountPolicy(targetCount = 100)),
        )

        assertEquals(TargetPolicy.PER_DUE_DATE, goal.targetPolicy)
        assertEquals(RecurrenceFrequency.DAILY, goal.recurrence.frequency)
        assertEquals(GoalSlotType.ANYTIME, goal.slots.single().slotType)
        assertEquals(100, goal.slots.single().targetCount)
    }

    @Test
    fun `tracker goal creates no target policy`() {
        val goal = validGoal(
            command = command(
                countPolicy = CountPolicy(
                    streakThreshold = Threshold.AnyPositive,
                    reminderThreshold = Threshold.AnyPositive,
                    completionThreshold = Threshold.AnyPositive,
                ),
            )
        )

        assertEquals(TargetPolicy.NONE, goal.targetPolicy)
        assertEquals(null, goal.slots.single().targetCount)
    }

    @Test
    fun `one time total creates lifetime cumulative auto completing goal`() {
        val goal = validGoal(
            command = command(
                countPolicy = CountPolicy(targetCount = 70_000),
                progressScope = ProgressScope.Lifetime,
                completionPolicy = CompletionPolicy.WhenTargetReached,
            )
        )

        assertEquals(TargetPolicy.CUMULATIVE_TOTAL, goal.targetPolicy)
        assertEquals(70_000, goal.slots.single().targetCount)
        assertTrue(goal.autoCompleteOnTarget)
    }

    @Test
    fun `prayer slots preserve per slot targets`() {
        val goal = validGoal(
            command = command(
                countPolicy = CountPolicy(targetCount = 33),
                timing = TimingSpec.PrayerBased(
                    listOf(
                        PrayerSlotSpec(Prayer.FAJR, PrayerRelation.AFTER, CountPolicy(targetCount = 33)),
                        PrayerSlotSpec(Prayer.DHUHR, PrayerRelation.AFTER, CountPolicy(targetCount = 100)),
                    )
                ),
            )
        )

        assertEquals(2, goal.slots.size)
        assertEquals(33, goal.slots.first { it.prayerName == Prayer.FAJR }.targetCount)
        assertEquals(100, goal.slots.first { it.prayerName == Prayer.DHUHR }.targetCount)
    }

    @Test
    fun `weekly and season schedules map to normalized recurrence`() {
        val weekly = validGoal(
            command = command(
                schedule = ScheduleSpec.Weekly(setOf(DayOfWeek.FRIDAY)),
                countPolicy = CountPolicy(targetCount = 1000),
                progressScope = ProgressScope.Period,
            )
        )
        val season = validGoal(
            command = command(
                schedule = ScheduleSpec.Season(SeasonTemplateCode.RAMADAN),
                countPolicy = CountPolicy(targetCount = 10_000),
                progressScope = ProgressScope.Period,
            )
        )

        assertEquals(TargetPolicy.PERIOD_TOTAL, weekly.targetPolicy)
        assertEquals(setOf(DayOfWeek.FRIDAY), weekly.recurrence.weekdays)
        assertEquals(RecurrenceFrequency.SEASON, season.recurrence.frequency)
        assertEquals(SeasonTemplateCode.RAMADAN, season.recurrence.seasonTemplateCode)
    }

    @Test
    fun `custom time windows validate and map targets`() {
        val goal = validGoal(
            command = command(
                countPolicy = CountPolicy(targetCount = 55),
                timing = TimingSpec.TimeWindows(
                    listOf(
                        TimeWindowSpec("Morning", 6 * 60, 8 * 60, CountPolicy(targetCount = 33)),
                        TimeWindowSpec("Evening", 18 * 60, 20 * 60, CountPolicy(targetCount = 66)),
                    )
                ),
            )
        )

        assertEquals(listOf(33, 66), goal.slots.map { it.targetCount })
        assertEquals(listOf("Morning", "Evening"), goal.slots.map { it.label })
    }

    @Test
    fun `invalid empty weekly schedule is rejected`() {
        val result = GoalFactory.create(
            command(
                schedule = ScheduleSpec.Weekly(emptySet()),
                countPolicy = CountPolicy(targetCount = 100),
            )
        )

        assertTrue(result is GoalCreationResult.Invalid)
        assertEquals(listOf(GoalCreationError.InvalidSchedule), (result as GoalCreationResult.Invalid).errors)
    }

    @Test
    fun `invalid minimum target maximum ordering is rejected`() {
        val result = GoalFactory.create(
            command(
                countPolicy = CountPolicy(
                    minimumCount = 300,
                    targetCount = 100,
                    maximumCount = 500,
                )
            )
        )

        assertTrue(result is GoalCreationResult.Invalid)
        assertTrue((result as GoalCreationResult.Invalid).errors.contains(GoalCreationError.InvalidCountPolicy))
    }

    @Test
    fun `exact prescribed cap requires maximum count`() {
        val valid = GoalFactory.create(
            command(
                countPolicy = CountPolicy(
                    targetCount = 33,
                    maximumCount = 33,
                    capBehavior = CapBehavior.BlockAtMaximum,
                )
            )
        )
        val invalid = GoalFactory.create(
            command(
                countPolicy = CountPolicy(
                    targetCount = 33,
                    capBehavior = CapBehavior.BlockAtMaximum,
                )
            )
        )

        assertTrue(valid is GoalCreationResult.Valid)
        assertTrue(invalid is GoalCreationResult.Invalid)
    }

    @Test
    fun `exact prescribed count persists target maximum and block cap`() {
        val goal = validGoal(
            command(
                countPolicy = CountPolicy(
                    targetCount = 33,
                    maximumCount = 33,
                    capBehavior = CapBehavior.BlockAtMaximum,
                )
            )
        )

        assertEquals(33, goal.slots.single().targetCount)
        assertEquals(33, goal.maximumCount)
        assertEquals(CountCapBehavior.BlockAtMaximum, goal.capBehavior)
    }

    @Test
    fun `bounded count policy accepts ordered minimum target maximum`() {
        val goal = validGoal(
            command(
                countPolicy = CountPolicy(
                    minimumCount = 20,
                    targetCount = 33,
                    maximumCount = 40,
                    streakThreshold = Threshold.Minimum,
                    capBehavior = CapBehavior.BlockAtMaximum,
                )
            )
        )

        assertEquals(20, goal.minimumStreakCount)
        assertEquals(33, goal.slots.single().targetCount)
        assertEquals(40, goal.maximumCount)
        assertEquals(CountCapBehavior.BlockAtMaximum, goal.capBehavior)
    }

    @Test
    fun `multi slot bounded policy aggregates generated slot maximums`() {
        val goal = validGoal(
            command(
                timing = TimingSpec.TimeWindows(
                    windows = listOf(
                        TimeWindowSpec(label = "Morning", startMinute = 6 * 60, endMinute = 7 * 60),
                        TimeWindowSpec(label = "Evening", startMinute = 18 * 60, endMinute = 19 * 60),
                    )
                ),
                countPolicy = CountPolicy(
                    minimumCount = 20,
                    targetCount = 33,
                    maximumCount = 40,
                    streakThreshold = Threshold.Minimum,
                    capBehavior = CapBehavior.AllowOverTarget,
                )
            )
        )

        assertEquals(80, goal.maximumCount)
        assertEquals(CountCapBehavior.AllowOverTarget, goal.capBehavior)
        assertEquals(listOf(33, 33), goal.slots.map { it.targetCount })
        assertEquals(listOf(40, 40), goal.slots.map { it.maximumCount })
    }

    private fun validGoal(command: CreateGoalCommand) =
        (GoalFactory.create(command) as GoalCreationResult.Valid).validatedGoal.goal

    private fun command(
        schedule: ScheduleSpec = ScheduleSpec.Daily,
        timing: TimingSpec = TimingSpec.Anytime,
        countPolicy: CountPolicy = CountPolicy(),
        progressScope: ProgressScope = ProgressScope.DueDate,
        completionPolicy: CompletionPolicy = CompletionPolicy.Never,
    ) = CreateGoalCommand(
        dhikrId = 1,
        startDate = LocalDate.parse("2026-05-27"),
        schedule = schedule,
        timing = timing,
        countPolicy = countPolicy,
        progressScope = progressScope,
        completionPolicy = completionPolicy,
    )
}
