package app.awrad.core.domain.goal.rules

import app.awrad.core.testing.fixtures.FixtureRunner
import app.awrad.core.testing.fixtures.counts
import app.awrad.core.testing.fixtures.date
import app.awrad.core.testing.fixtures.goal
import app.awrad.core.testing.fixtures.hijriCorrections
import app.awrad.core.testing.fixtures.weekStart
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.test.Test

class GoalStreakFixtureTest {

    @Test
    fun `every goal_streak fixture case passes`() {
        FixtureRunner.runGoalModel("goal_streak") { given ->
            val streak = given.goal()
                .streakOn(given.date("date"), given.counts(), given.weekStart(), given.hijriCorrections())
            buildJsonObject { put("current", streak) }
        }
    }
}
