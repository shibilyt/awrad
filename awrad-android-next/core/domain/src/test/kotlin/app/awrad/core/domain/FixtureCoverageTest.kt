package app.awrad.core.domain

import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Guard: every shared rule file has a runner here, so a new fixture file can't go unrun on Android.
 * Adding a file to `contracts/<model>/v1/fixtures/` fails this test until a `…FixtureTest` runs it.
 */
class FixtureCoverageTest {

    @Test
    fun `every goal-model rule file has a runner`() {
        assertEquals(
            setOf(
                "effective_practice_day", // practice.EffectivePracticeDayFixtureTest
                "goal_is_due", // goal.rules.GoalIsDueFixtureTest
                "requirement_standing", // goal.rules.RequirementStandingFixtureTest
                "days_per_period", // goal.rules.DaysPerPeriodFixtureTest
                "goal_completion", // goal.rules.GoalCompletionFixtureTest
                "goal_streak", // goal.rules.GoalStreakFixtureTest
                "goal_validity", // goal.GoalValidityFixtureTest
            ),
            FixtureRunner.rules(FixtureModel.GOAL_MODEL),
        )
    }

    @Test
    fun `every hijri-calendar rule file has a runner`() {
        assertEquals(
            setOf(
                "hijri_date", // hijri.HijriDateFixtureTest
                "hijri_corrections_validity", // hijri.HijriCorrectionsValidityFixtureTest
            ),
            FixtureRunner.rules(FixtureModel.HIJRI_CALENDAR),
        )
    }
}
