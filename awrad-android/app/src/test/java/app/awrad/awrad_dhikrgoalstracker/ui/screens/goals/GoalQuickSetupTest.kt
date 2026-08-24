package app.awrad.awrad_dhikrgoalstracker.ui.screens.goals

import app.awrad.awrad_dhikrgoalstracker.testId
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalPreset
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSpecificDate
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.Threshold
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftDefaults
import app.awrad.awrad_dhikrgoalstracker.ui.screens.goals.model.GoalDraftMapper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class GoalQuickSetupTest {

    @Test
    fun dailyQuickSetupLeavesStreakRequirementOffByDefault() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.DAILY)
        val goal = GoalDraftMapper.toGoal(testId(1), draft, START_DATE)

        assertFalse(draft.extras.hasMinStreak)
        assertEquals("1", draft.extras.minStreakCount)
        assertNull(goal.minimumStreakCount)
    }

    @Test
    fun dailyQuickSetupAddsMinimumForStreakOfOneAfterOptIn() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.DAILY).copy(
            extras = GoalDraftDefaults.forPreset(GoalPreset.DAILY).extras.copy(hasMinStreak = true),
        )
        val goal = GoalDraftMapper.toGoal(testId(7), draft, START_DATE)

        assertEquals(1, goal.minimumStreakCount)
    }

    @Test
    fun oneTimeQuickSetupIsCumulativeWithoutImplicitDailyStreak() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.ONE_TIME)
        val goal = GoalDraftMapper.toGoal(testId(2), draft, START_DATE)

        assertFalse(draft.extras.hasMinStreak)
        assertEquals("1", draft.extras.minStreakCount)
        assertEquals(TargetPolicy.CUMULATIVE_TOTAL, goal.targetPolicy)
        assertTrue(goal.isOneTime)
        assertNull(goal.minimumStreakCount)
    }

    @Test
    fun oneTimeQuickSetupIsAnchoredToStartDateUnlessDailyStreakIsEnabled() {
        val oneTime = GoalDraftDefaults.forPreset(GoalPreset.ONE_TIME)
        val oneTimeGoal = GoalDraftMapper.toGoal(testId(5), oneTime, START_DATE)

        assertEquals(RecurrenceFrequency.SPECIFIC_DATES, oneTimeGoal.recurrence.frequency)
        assertEquals(
            setOf(GoalSpecificDate(date = START_DATE)),
            oneTimeGoal.recurrence.specificDates,
        )
        assertEquals(TargetPolicy.CUMULATIVE_TOTAL, oneTimeGoal.targetPolicy)

        val streakEnabled = oneTime.copy(
            extras = oneTime.extras.copy(hasMinStreak = true),
        )
        val streakGoal = GoalDraftMapper.toGoal(testId(6), streakEnabled, START_DATE)

        assertEquals(RecurrenceFrequency.DAILY, streakGoal.recurrence.frequency)
        assertEquals(TargetPolicy.CUMULATIVE_TOTAL, streakGoal.targetPolicy)
        assertEquals(1, streakGoal.minimumStreakCount)
    }

    @Test
    fun oneTimeQuickSetupAddsDailyStreakMinimumOnlyAfterOptIn() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.ONE_TIME).copy(
            extras = GoalDraftDefaults.forPreset(GoalPreset.ONE_TIME).extras.copy(hasMinStreak = true),
        )
        val goal = GoalDraftMapper.toGoal(testId(3), draft, START_DATE)

        assertEquals(TargetPolicy.CUMULATIVE_TOTAL, goal.targetPolicy)
        assertEquals(1, goal.minimumStreakCount)
        assertEquals(1, goal.slots.single().minimumCount)
        assertEquals(Threshold.Minimum, goal.streakThreshold)
    }

    @Test
    fun trackOnlyQuickSetupCanProtectStreakWithoutCreatingCompletionTarget() {
        val draft = GoalDraftDefaults.forPreset(GoalPreset.TRACKER).copy(
            extras = GoalDraftDefaults.forPreset(GoalPreset.TRACKER).extras.copy(
                hasMinStreak = true,
                minStreakCount = "1",
            ),
        )
        val goal = GoalDraftMapper.toGoal(testId(4), draft, START_DATE)

        assertEquals(TargetPolicy.NONE, goal.targetPolicy)
        assertTrue(goal.isTracker)
        assertEquals(1, goal.minimumStreakCount)
        assertEquals(1, goal.slots.single().minimumCount)
        assertNull(goal.slots.single().targetCount)
    }

    private companion object {
        val START_DATE: LocalDate = LocalDate.parse("2026-08-17")
    }
}
