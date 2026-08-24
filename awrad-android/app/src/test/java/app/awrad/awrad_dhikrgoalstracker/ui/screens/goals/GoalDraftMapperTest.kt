package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import app.awrad.awrad_dhikrgoalstracker.testId

import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.TimingType
import app.awrad.awrad_dhikrgoalstracker.data.model.Threshold
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CapBehavior
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ProgressScope
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.TimingSpec
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.CountRuleDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.CountRuleMode
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.FrequencyDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftDefaults
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftMapper
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftSection
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalTimeSlotDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalTimingDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalValidationMessage
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.PrayerSlotTargetKey
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.SlotTargetMode
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.TargetDraft
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.syncedWithTargetDraft
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class GoalDraftMapperTest {

    @Test
    fun `curated templates include all redesigned entry cards`() {
        assertEquals(
            listOf(
                GoalPreset.DAILY,
                GoalPreset.PRAYER_BASED,
                GoalPreset.ONE_TIME,
                GoalPreset.WEEKLY,
                GoalPreset.ISLAMIC_SEASON,
                GoalPreset.MORNING_EVENING,
                GoalPreset.TRACKER,
                GoalPreset.CUSTOM,
            ),
            GoalDraftDefaults.curatedPresets,
        )
    }

    @Test
    fun `daily template maps to per due date anytime goal`() {
        val goal = GoalDraftMapper.toGoal(
            dhikrId = testId(1),
            draft = GoalDraftDefaults.forPreset(GoalPreset.DAILY),
            startDate = LocalDate.parse("2026-05-27"),
        )

        assertEquals(TargetPolicy.PER_DUE_DATE, goal.targetPolicy)
        assertEquals(RecurrenceFrequency.DAILY, goal.recurrence.frequency)
        assertEquals(GoalSlotType.ANYTIME, goal.slots.single().slotType)
        assertEquals(100, goal.slots.single().targetCount)
    }

    @Test
    fun `daily template maps to create command instead of persisted model`() {
        val command = GoalDraftMapper.toCommand(
            dhikrId = testId(1),
            draft = GoalDraftDefaults.forPreset(GoalPreset.DAILY),
            startDate = LocalDate.parse("2026-05-27"),
        )

        assertEquals(testId(1), command.dhikrId)
        assertEquals(ProgressScope.DueDate, command.progressScope)
        assertTrue(command.timing is TimingSpec.Anytime)
        assertEquals(100, command.countPolicy.targetCount)
    }

    @Test
    fun `daily prayer slots map selected prayers to per prayer targets`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.DAILY).copy(
            timingType = TimingType.PRAYER_BASED,
            targetDraft = TargetDraft.PrayerBased(
                timing = PrayerTiming.AFTER,
                selectedPrayers = setOf(Prayer.FAJR, Prayer.DHUHR),
                uniformCount = "33",
                perPrayerCounts = mapOf(
                    Prayer.FAJR to "33",
                    Prayer.DHUHR to "100",
                ),
            ),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(TargetPolicy.PER_DUE_DATE, goal.targetPolicy)
        assertEquals(2, goal.slots.size)
        assertTrue(goal.slots.all { it.slotType == GoalSlotType.PRAYER && it.prayerRelation == PrayerRelation.AFTER })
        assertEquals(33, goal.slots.first { it.prayerName == Prayer.FAJR }.targetCount)
        assertEquals(100, goal.slots.first { it.prayerName == Prayer.DHUHR }.targetCount)
    }

    @Test
    fun `daily time slots map custom windows to per slot targets`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.DAILY).copy(
            timingType = TimingType.TIME_BASED,
            timeSlots = listOf(
                GoalTimeSlotDraft(
                    id = "morning",
                    label = "Morning",
                    startHour = 6,
                    startMinute = 30,
                    durationMinutes = 90,
                    targetCount = "33",
                ),
                GoalTimeSlotDraft(
                    id = "evening",
                    label = "Evening",
                    startHour = 18,
                    startMinute = 0,
                    durationMinutes = 60,
                    targetCount = "100",
                ),
            ),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(TargetPolicy.PER_DUE_DATE, goal.targetPolicy)
        assertEquals(2, goal.slots.size)
        assertTrue(goal.slots.all { it.slotType == GoalSlotType.TIME_WINDOW })
        assertEquals("Morning", goal.slots[0].label)
        assertEquals(6 * 60 + 30, goal.slots[0].startMinute)
        assertEquals(8 * 60, goal.slots[0].endMinute)
        assertEquals(33, goal.slots[0].targetCount)
        assertEquals("Evening", goal.slots[1].label)
        assertEquals(100, goal.slots[1].targetCount)
    }

    @Test
    fun `prayer template maps to five prayer slots and prayer offset reminder`() {
        val goal = GoalDraftMapper.toGoal(
            dhikrId = testId(1),
            draft = GoalDraftDefaults.forPreset(GoalPreset.PRAYER_BASED),
            startDate = LocalDate.parse("2026-05-27"),
        )

        assertEquals(TargetPolicy.PER_DUE_DATE, goal.targetPolicy)
        assertEquals(5, goal.slots.size)
        assertTrue(goal.slots.all { it.slotType == GoalSlotType.PRAYER && it.targetCount == 33 })
        assertEquals(ReminderType.PRAYER_OFFSET, goal.reminders.single().reminderType)
    }

    @Test
    fun `total template maps to cumulative auto complete goal`() {
        val goal = GoalDraftMapper.toGoal(
            dhikrId = testId(1),
            draft = GoalDraftDefaults.forPreset(GoalPreset.ONE_TIME),
            startDate = LocalDate.parse("2026-05-27"),
        )

        assertEquals(TargetPolicy.CUMULATIVE_TOTAL, goal.targetPolicy)
        assertTrue(goal.autoCompleteOnTarget)
        assertEquals(70000, goal.slots.single().targetCount)
    }

    @Test
    fun `weekly template maps to period total weekly goal`() {
        val goal = GoalDraftMapper.toGoal(
            dhikrId = testId(1),
            draft = GoalDraftDefaults.forPreset(GoalPreset.WEEKLY),
            startDate = LocalDate.parse("2026-05-27"),
        )

        assertEquals(TargetPolicy.PERIOD_TOTAL, goal.targetPolicy)
        assertEquals(RecurrenceFrequency.WEEKLY, goal.recurrence.frequency)
        assertTrue(goal.recurrence.weekdays.isNotEmpty())
    }

    @Test
    fun `season template maps to Ramadan season goal`() {
        val goal = GoalDraftMapper.toGoal(
            dhikrId = testId(1),
            draft = GoalDraftDefaults.forPreset(GoalPreset.ISLAMIC_SEASON),
            startDate = LocalDate.parse("2026-05-27"),
        )

        assertEquals(TargetPolicy.PERIOD_TOTAL, goal.targetPolicy)
        assertEquals(RecurrenceFrequency.SEASON, goal.recurrence.frequency)
        assertEquals(SeasonTemplateCode.RAMADAN, goal.recurrence.seasonTemplateCode)
    }

    @Test
    fun `morning evening template maps to two time window slots`() {
        val goal = GoalDraftMapper.toGoal(
            dhikrId = testId(1),
            draft = GoalDraftDefaults.forPreset(GoalPreset.MORNING_EVENING),
            startDate = LocalDate.parse("2026-05-27"),
        )

        assertEquals(2, goal.slots.size)
        assertTrue(goal.slots.all { it.slotType == GoalSlotType.TIME_WINDOW })
        assertEquals(50, goal.slots[0].targetCount)
        assertEquals(50, goal.slots[1].targetCount)
        assertEquals(ReminderType.TIME_WINDOW_START, goal.reminders.single().reminderType)
    }

    @Test
    fun `tracker template maps to no target tracker goal`() {
        val goal = GoalDraftMapper.toGoal(
            dhikrId = testId(1),
            draft = GoalDraftDefaults.forPreset(GoalPreset.TRACKER),
            startDate = LocalDate.parse("2026-05-27"),
        )

        assertEquals(TargetPolicy.NONE, goal.targetPolicy)
        assertEquals(null, goal.slots.single().targetCount)
    }

    @Test
    fun `tracker template command uses any positive count thresholds`() {
        val command = GoalDraftMapper.toCommand(
            dhikrId = testId(1),
            draft = GoalDraftDefaults.forPreset(GoalPreset.TRACKER),
            startDate = LocalDate.parse("2026-05-27"),
        )

        assertEquals(null, command.countPolicy.targetCount)
        assertEquals(Threshold.AnyPositive, command.countPolicy.streakThreshold)
        assertEquals(Threshold.AnyPositive, command.countPolicy.reminderThreshold)
    }

    @Test
    fun `minimum only count rule maps to minimum policy and persisted denominator`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            countRule = CountRuleDraft(
                mode = CountRuleMode.Minimum,
                minimumCount = "40",
                targetCount = "",
            ),
            targetDraft = TargetDraft.Fixed("40"),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val command = GoalDraftMapper.toCommand(
            dhikrId = testId(1),
            draft = draft,
            startDate = LocalDate.parse("2026-05-27"),
        )
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(40, command.countPolicy.minimumCount)
        assertEquals(null, command.countPolicy.targetCount)
        assertEquals(Threshold.Minimum, command.countPolicy.streakThreshold)
        assertEquals(Threshold.Minimum, command.countPolicy.reminderThreshold)
        assertEquals(40, goal.minimumStreakCount)
        assertEquals(40, goal.slots.single().targetCount)
    }

    @Test
    fun `minimum prayer count rule creates valid slot minimum policies`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            timingType = TimingType.PRAYER_BASED,
            advancedTiming = GoalTimingDraft.PrayerBased,
            slotTargetMode = SlotTargetMode.Same,
            countRule = CountRuleDraft(
                mode = CountRuleMode.Minimum,
                minimumCount = "16",
                targetCount = "",
            ),
            targetDraft = TargetDraft.PrayerBased(
                timing = PrayerTiming.AFTER,
                selectedPrayers = setOf(Prayer.FAJR, Prayer.DHUHR),
                uniformCount = "16",
            ),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val command = GoalDraftMapper.toCommand(testId(1), draft, LocalDate.parse("2026-05-27"))
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertTrue(command.timing is TimingSpec.PrayerBased)
        assertEquals(Threshold.Minimum, command.countPolicy.streakThreshold)
        assertEquals(Threshold.Minimum, (command.timing as TimingSpec.PrayerBased).slots.first().countPolicy.streakThreshold)
        assertEquals(listOf(16, 16), goal.slots.map { it.minimumCount })
        assertEquals(listOf(16, 16), goal.slots.map { it.targetCount })
    }

    @Test
    fun `stretch count rule maps minimum and target with target completion threshold`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            countRule = CountRuleDraft(
                mode = CountRuleMode.Stretch,
                minimumCount = "40",
                targetCount = "100",
            ),
            targetDraft = TargetDraft.Fixed("100"),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val command = GoalDraftMapper.toCommand(
            dhikrId = testId(1),
            draft = draft,
            startDate = LocalDate.parse("2026-05-27"),
        )
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(40, command.countPolicy.minimumCount)
        assertEquals(100, command.countPolicy.targetCount)
        assertEquals(Threshold.Minimum, command.countPolicy.streakThreshold)
        assertEquals(Threshold.Target, command.countPolicy.reminderThreshold)
        assertEquals(Threshold.Target, command.countPolicy.completionThreshold)
        assertEquals(40, goal.minimumStreakCount)
        assertEquals(100, goal.slots.single().targetCount)
    }

    @Test
    fun `exact count rule maps target maximum and block at maximum cap`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            countRule = CountRuleDraft(
                mode = CountRuleMode.Exact,
                maximumCount = "33",
            ),
            targetDraft = TargetDraft.Fixed("33"),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val command = GoalDraftMapper.toCommand(
            dhikrId = testId(1),
            draft = draft,
            startDate = LocalDate.parse("2026-05-27"),
        )
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(33, command.countPolicy.targetCount)
        assertEquals(33, command.countPolicy.maximumCount)
        assertEquals(CapBehavior.BlockAtMaximum, command.countPolicy.capBehavior)
        assertEquals(CountCapBehavior.BlockAtMaximum, goal.capBehavior)
        assertEquals(33, goal.maximumCount)
        assertEquals(33, goal.slots.single().targetCount)
    }

    @Test
    fun `bounded count rule maps minimum target maximum and selected cap behavior`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            countRule = CountRuleDraft(
                mode = CountRuleMode.Bounded,
                minimumCount = "20",
                targetCount = "33",
                maximumCount = "40",
                capBehavior = CapBehavior.BlockAtMaximum,
            ),
            targetDraft = TargetDraft.Fixed("33"),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val command = GoalDraftMapper.toCommand(
            dhikrId = testId(1),
            draft = draft,
            startDate = LocalDate.parse("2026-05-27"),
        )
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(20, command.countPolicy.minimumCount)
        assertEquals(33, command.countPolicy.targetCount)
        assertEquals(40, command.countPolicy.maximumCount)
        assertEquals(CapBehavior.BlockAtMaximum, command.countPolicy.capBehavior)
        assertEquals(20, goal.minimumStreakCount)
        assertEquals(40, goal.maximumCount)
        assertEquals(CountCapBehavior.BlockAtMaximum, goal.capBehavior)
        assertEquals(33, goal.slots.single().targetCount)
    }

    @Test
    fun `shared bounded prayer rule with allow over aggregates goal maximum`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            timingType = TimingType.PRAYER_BASED,
            advancedTiming = GoalTimingDraft.PrayerBased,
            slotTargetMode = SlotTargetMode.Same,
            countRule = CountRuleDraft(
                mode = CountRuleMode.Bounded,
                minimumCount = "20",
                targetCount = "33",
                maximumCount = "40",
                capBehavior = CapBehavior.AllowOverTarget,
            ),
            targetDraft = TargetDraft.PrayerBased(
                timing = PrayerTiming.AFTER,
                selectedPrayers = setOf(Prayer.FAJR, Prayer.DHUHR),
                uniformCount = "33",
            ),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(80, goal.maximumCount)
        assertEquals(CountCapBehavior.AllowOverTarget, goal.capBehavior)
        assertEquals(listOf(20, 20), goal.slots.map { it.minimumCount })
        assertEquals(listOf(33, 33), goal.slots.map { it.targetCount })
        assertEquals(listOf(40, 40), goal.slots.map { it.maximumCount })
        assertTrue(goal.slots.all { it.capBehavior == CountCapBehavior.AllowOverTarget })
    }

    @Test
    fun `shared bounded morning evening rule aggregates goal maximum`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.MORNING_EVENING).copy(
            slotTargetMode = SlotTargetMode.Same,
            countRule = CountRuleDraft(
                mode = CountRuleMode.Bounded,
                minimumCount = "10",
                targetCount = "20",
                maximumCount = "30",
                capBehavior = CapBehavior.AllowOverTarget,
            ),
            targetDraft = TargetDraft.Fixed("20"),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(60, goal.maximumCount)
        assertEquals(listOf(20, 20), goal.slots.map { it.targetCount })
        assertEquals(listOf(30, 30), goal.slots.map { it.maximumCount })
    }

    @Test
    fun `bounded count rule maps per custom slot minimum target maximum and cap`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            timingType = TimingType.TIME_BASED,
            advancedTiming = GoalTimingDraft.CustomSlots,
            slotTargetMode = SlotTargetMode.PerSlot,
            countRule = CountRuleDraft(
                mode = CountRuleMode.Bounded,
                minimumCount = "10",
                targetCount = "20",
                maximumCount = "30",
                capBehavior = CapBehavior.BlockAtMaximum,
            ),
            targetDraft = TargetDraft.Fixed("20"),
            timeSlots = listOf(
                GoalTimeSlotDraft(
                    id = "a",
                    label = "Early",
                    mode = CountRuleMode.Bounded,
                    minimumCount = "5",
                    targetCount = "10",
                    maximumCount = "12",
                    capBehavior = CapBehavior.BlockAtMaximum,
                ),
                GoalTimeSlotDraft(
                    id = "b",
                    label = "Late",
                    mode = CountRuleMode.Bounded,
                    minimumCount = "7",
                    targetCount = "11",
                    maximumCount = "15",
                    capBehavior = CapBehavior.BlockAtTarget,
                ),
            ),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val command = GoalDraftMapper.toCommand(testId(1), draft, LocalDate.parse("2026-05-27"))
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertTrue(command.timing is TimingSpec.TimeWindows)
        assertEquals(27, goal.maximumCount)
        assertEquals(listOf(5, 7), goal.slots.map { it.minimumCount })
        assertEquals(listOf(10, 11), goal.slots.map { it.targetCount })
        assertEquals(listOf(12, 15), goal.slots.map { it.maximumCount })
        assertEquals(listOf(CountCapBehavior.BlockAtMaximum, CountCapBehavior.BlockAtTarget), goal.slots.map { it.capBehavior })
    }

    @Test
    fun `shared exact prayer rule aggregates goal maximum`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            timingType = TimingType.PRAYER_BASED,
            advancedTiming = GoalTimingDraft.PrayerBased,
            slotTargetMode = SlotTargetMode.Same,
            countRule = CountRuleDraft(
                mode = CountRuleMode.Exact,
                maximumCount = "33",
            ),
            targetDraft = TargetDraft.PrayerBased(
                timing = PrayerTiming.AFTER,
                selectedPrayers = setOf(Prayer.FAJR, Prayer.DHUHR),
                uniformCount = "33",
            ),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(66, goal.maximumCount)
        assertEquals(listOf(33, 33), goal.slots.map { it.targetCount })
        assertEquals(listOf(33, 33), goal.slots.map { it.maximumCount })
        assertTrue(goal.slots.all { it.capBehavior == CountCapBehavior.BlockAtMaximum })
    }

    @Test
    fun `exact count rule maps per prayer slot maximum and block cap`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            timingType = TimingType.PRAYER_BASED,
            advancedTiming = GoalTimingDraft.PrayerBased,
            slotTargetMode = SlotTargetMode.PerSlot,
            countRule = CountRuleDraft(
                mode = CountRuleMode.Exact,
                maximumCount = "33",
            ),
            targetDraft = TargetDraft.PrayerBased(
                timing = PrayerTiming.AFTER,
                selectedPrayers = setOf(Prayer.FAJR, Prayer.DHUHR),
                uniformCount = "33",
                perPrayerRelationMaximumCounts = mapOf(
                    PrayerSlotTargetKey(Prayer.FAJR, PrayerRelation.AFTER) to "11",
                    PrayerSlotTargetKey(Prayer.DHUHR, PrayerRelation.AFTER) to "22",
                ),
            ),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(33, goal.maximumCount)
        assertEquals(11, goal.slots.first { it.prayerName == Prayer.FAJR }.targetCount)
        assertEquals(11, goal.slots.first { it.prayerName == Prayer.FAJR }.maximumCount)
        assertEquals(22, goal.slots.first { it.prayerName == Prayer.DHUHR }.targetCount)
        assertEquals(22, goal.slots.first { it.prayerName == Prayer.DHUHR }.maximumCount)
        assertTrue(goal.slots.all { it.capBehavior == CountCapBehavior.BlockAtMaximum })
    }

    @Test
    fun `count rule tracker maps custom draft to no target thresholds`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            countRule = CountRuleDraft.tracker(),
            targetDraft = TargetDraft.None,
            customTargetPolicy = TargetPolicy.NONE,
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val command = GoalDraftMapper.toCommand(
            dhikrId = testId(1),
            draft = draft,
            startDate = LocalDate.parse("2026-05-27"),
        )
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(TargetPolicy.NONE, goal.targetPolicy)
        assertEquals(null, command.countPolicy.minimumCount)
        assertEquals(null, command.countPolicy.targetCount)
        assertEquals(Threshold.AnyPositive, command.countPolicy.streakThreshold)
        assertEquals(null, goal.slots.single().targetCount)
    }

    @Test
    fun `advanced no target prayer slots validate and map nullable targets`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            customTargetPolicy = TargetPolicy.NONE,
            timingType = TimingType.PRAYER_BASED,
            targetDraft = TargetDraft.PrayerBased(
                timing = PrayerTiming.BOTH,
                selectedPrayers = setOf(Prayer.FAJR),
                uniformCount = "33",
            ),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(TargetPolicy.NONE, goal.targetPolicy)
        assertEquals(2, goal.slots.size)
        assertTrue(goal.slots.all { it.slotType == GoalSlotType.PRAYER && it.targetCount == null })
    }

    @Test
    fun `advanced no target time slots validate and map nullable targets`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            customTargetPolicy = TargetPolicy.NONE,
            timingType = TimingType.TIME_BASED,
            timeSlots = listOf(
                GoalTimeSlotDraft(
                    id = "slot",
                    label = "Custom",
                    startHour = 9,
                    startMinute = 0,
                    durationMinutes = 60,
                    targetCount = "300",
                ),
            ),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(TargetPolicy.NONE, goal.targetPolicy)
        assertEquals(GoalSlotType.TIME_WINDOW, goal.slots.single().slotType)
        assertEquals(null, goal.slots.single().targetCount)
    }

    @Test
    fun `custom specific dates validate when dates are parseable`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            frequencyDraft = FrequencyDraft.SpecificDates("2026-06-01, 2026-06-02"),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(RecurrenceFrequency.SPECIFIC_DATES, goal.recurrence.frequency)
        assertEquals(2, goal.recurrence.specificDates.size)
    }

    @Test
    fun `advanced recurrence options map all supported schedule drafts`() {
        val startDate = LocalDate.parse("2026-05-27")
        val weekly = GoalDraftMapper.toGoal(
            testId(1),
            GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
                frequencyDraft = FrequencyDraft.Weekly(setOf(java.time.DayOfWeek.MONDAY, java.time.DayOfWeek.FRIDAY)),
            ),
            startDate,
        ).recurrence
        val monthly = GoalDraftMapper.toGoal(
            testId(1),
            GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
                frequencyDraft = FrequencyDraft.Monthly(daysOfMonth = setOf(3, 15), calendar = "hijri"),
            ),
            startDate,
        ).recurrence
        val interval = GoalDraftMapper.toGoal(
            testId(1),
            GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
                frequencyDraft = FrequencyDraft.Interval("5"),
            ),
            startDate,
        ).recurrence
        val yearly = GoalDraftMapper.toGoal(
            testId(1),
            GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
                frequencyDraft = FrequencyDraft.Yearly(month = 9, days = setOf(1, 27), calendar = "hijri"),
            ),
            startDate,
        ).recurrence
        val season = GoalDraftMapper.toGoal(
            testId(1),
            GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
                frequencyDraft = FrequencyDraft.Season(SeasonTemplateCode.DHUL_HIJJAH_1_10),
            ),
            startDate,
        ).recurrence
        val specificDates = GoalDraftMapper.toGoal(
            testId(1),
            GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
                frequencyDraft = FrequencyDraft.SpecificDates("2026-06-01 2026-06-02"),
            ),
            startDate,
        ).recurrence

        assertEquals(RecurrenceFrequency.WEEKLY, weekly.frequency)
        assertEquals(setOf(java.time.DayOfWeek.MONDAY, java.time.DayOfWeek.FRIDAY), weekly.weekdays)
        assertEquals(RecurrenceFrequency.MONTHLY, monthly.frequency)
        assertEquals(CalendarSystem.HIJRI, monthly.calendar)
        assertEquals(setOf(3, 15), monthly.monthDays)
        assertEquals(RecurrenceFrequency.INTERVAL, interval.frequency)
        assertEquals(5, interval.intervalDays)
        assertEquals(RecurrenceFrequency.YEARLY, yearly.frequency)
        assertEquals(9, yearly.month)
        assertEquals(setOf(1, 27), yearly.monthDays)
        assertEquals(RecurrenceFrequency.SEASON, season.frequency)
        assertEquals(SeasonTemplateCode.DHUL_HIJJAH_1_10, season.seasonTemplateCode)
        assertEquals(RecurrenceFrequency.SPECIFIC_DATES, specificDates.frequency)
        assertEquals(2, specificDates.specificDates.size)
    }

    @Test
    fun `advanced same target custom slots map shared count to every slot`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            timingType = TimingType.TIME_BASED,
            advancedTiming = GoalTimingDraft.CustomSlots,
            slotTargetMode = SlotTargetMode.Same,
            targetDraft = TargetDraft.Fixed("55"),
            timeSlots = listOf(
                GoalTimeSlotDraft(id = "a", label = "Early", startHour = 5, startMinute = 0, durationMinutes = 90, targetCount = "11"),
                GoalTimeSlotDraft(id = "b", label = "Late", startHour = 21, startMinute = 0, durationMinutes = 60, targetCount = "22"),
            ),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(listOf(55, 55), goal.slots.map { it.targetCount })
    }

    @Test
    fun `advanced per slot custom slots preserve label start end and target`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            timingType = TimingType.TIME_BASED,
            advancedTiming = GoalTimingDraft.CustomSlots,
            slotTargetMode = SlotTargetMode.PerSlot,
            timeSlots = listOf(
                GoalTimeSlotDraft(id = "morning", label = "Morning", startHour = 6, startMinute = 15, durationMinutes = 105, targetCount = "33"),
                GoalTimeSlotDraft(id = "night", label = "Late night", startHour = 21, startMinute = 0, durationMinutes = 120, targetCount = "66"),
            ),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals("Morning", goal.slots[0].label)
        assertEquals(6 * 60 + 15, goal.slots[0].startMinute)
        assertEquals(8 * 60, goal.slots[0].endMinute)
        assertEquals(33, goal.slots[0].targetCount)
        assertEquals("Late night", goal.slots[1].label)
        assertEquals(23 * 60, goal.slots[1].endMinute)
        assertEquals(66, goal.slots[1].targetCount)
    }

    @Test
    fun `advanced prayer before after targets can differ by relation`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            timingType = TimingType.PRAYER_BASED,
            advancedTiming = GoalTimingDraft.PrayerBased,
            slotTargetMode = SlotTargetMode.PerSlot,
            targetDraft = TargetDraft.PrayerBased(
                timing = PrayerTiming.BOTH,
                selectedPrayers = setOf(Prayer.FAJR),
                uniformCount = "33",
                perPrayerRelationCounts = mapOf(
                    PrayerSlotTargetKey(Prayer.FAJR, PrayerRelation.BEFORE) to "11",
                    PrayerSlotTargetKey(Prayer.FAJR, PrayerRelation.AFTER) to "22",
                ),
            ),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(2, goal.slots.size)
        assertEquals(11, goal.slots.first { it.prayerRelation == PrayerRelation.BEFORE }.targetCount)
        assertEquals(22, goal.slots.first { it.prayerRelation == PrayerRelation.AFTER }.targetCount)
    }

    @Test
    fun `advanced morning evening same target applies same count to both slots`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            timingType = TimingType.TIME_BASED,
            advancedTiming = GoalTimingDraft.MorningEvening,
            slotTargetMode = SlotTargetMode.Same,
            targetDraft = TargetDraft.Fixed("40"),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(listOf(40, 40), goal.slots.map { it.targetCount })
        assertEquals(5 * 60, goal.slots[0].startMinute)
        assertEquals(11 * 60, goal.slots[0].endMinute)
        assertEquals(17 * 60, goal.slots[1].startMinute)
        assertEquals(22 * 60, goal.slots[1].endMinute)
    }

    @Test
    fun `advanced morning evening per slot targets map separate counts`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            timingType = TimingType.TIME_BASED,
            advancedTiming = GoalTimingDraft.MorningEvening,
            slotTargetMode = SlotTargetMode.PerSlot,
            morningTargetCount = "33",
            eveningTargetCount = "66",
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertTrue(validation.isValid)
        assertEquals(listOf(33, 66), goal.slots.map { it.targetCount })
    }

    @Test
    fun `simple every day flow with edited target maps to that per due date count`() {
        // Mirrors SimpleTargetPane: choose the Daily goal type, then set a custom count.
        val target = TargetDraft.Fixed("313")
        val draft = GoalDraftDefaults.forPreset(GoalPreset.DAILY).let {
            it.copy(targetDraft = target, countRule = it.countRule.syncedWithTargetDraft(target))
        }

        val command = GoalDraftMapper.toCommand(testId(1), draft, LocalDate.parse("2026-05-27"))
        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertEquals(ProgressScope.DueDate, command.progressScope)
        assertEquals(313, command.countPolicy.targetCount)
        assertEquals(CapBehavior.BlockAtTarget, command.countPolicy.capBehavior)
        assertEquals(313, goal.slots.single().targetCount)
        assertEquals(CountCapBehavior.BlockAtTarget, goal.capBehavior)
        assertEquals(CountCapBehavior.BlockAtTarget, goal.slots.single().capBehavior)
    }

    @Test
    fun `simple one time flow with edited total maps to cumulative auto complete`() {
        val target = TargetDraft.Fixed("5000")
        val draft = GoalDraftDefaults.forPreset(GoalPreset.ONE_TIME).let {
            it.copy(targetDraft = target, countRule = it.countRule.syncedWithTargetDraft(target))
        }

        val goal = GoalDraftMapper.toGoal(testId(1), draft, LocalDate.parse("2026-05-27"))

        assertEquals(TargetPolicy.CUMULATIVE_TOTAL, goal.targetPolicy)
        assertTrue(goal.autoCompleteOnTarget)
        assertEquals(5000, goal.slots.single().targetCount)
        assertEquals(CountCapBehavior.BlockAtTarget, goal.capBehavior)
        assertEquals(CountCapBehavior.BlockAtTarget, goal.slots.single().capBehavior)
    }

    @Test
    fun `invalid weekly draft reports schedule error`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.WEEKLY).copy(
            frequencyDraft = FrequencyDraft.Weekly(emptySet()),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)

        assertFalse(validation.isValid)
        assertTrue(validation.errors.containsKey(GoalDraftSection.Schedule))
    }

    @Test
    fun `tracker with target reports target error`() {
        val draft = GoalDraft(
            preset = GoalPreset.TRACKER,
            targetDraft = TargetDraft.Fixed("10"),
            timingType = TimingType.ANYTIME,
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)

        assertFalse(validation.isValid)
        assertTrue(validation.errors.containsKey(GoalDraftSection.Target))
    }

    @Test
    fun `invalid stretch count rule reports target error`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            countRule = CountRuleDraft(
                mode = CountRuleMode.Stretch,
                minimumCount = "100",
                targetCount = "100",
            ),
            targetDraft = TargetDraft.Fixed("100"),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)

        assertFalse(validation.isValid)
        assertEquals(
            GoalValidationMessage.TargetMustExceedMinimum,
            validation.errors[GoalDraftSection.Target],
        )
    }

    @Test
    fun `invalid bounded count ordering reports target error`() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.CUSTOM).copy(
            countRule = CountRuleDraft(
                mode = CountRuleMode.Bounded,
                minimumCount = "40",
                targetCount = "33",
                maximumCount = "39",
            ),
            targetDraft = TargetDraft.Fixed("33"),
        )

        val validation = GoalDraftMapper.validate(draft, hasDhikr = true)

        assertFalse(validation.isValid)
        assertEquals(
            GoalValidationMessage.BoundedCountsOrdered,
            validation.errors[GoalDraftSection.Target],
        )
    }
}
