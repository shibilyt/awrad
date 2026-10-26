package app.awrad.core.domain.goal.rules

import app.awrad.core.testing.fixtures.FixtureRunner
import app.awrad.core.testing.fixtures.counts
import app.awrad.core.testing.fixtures.date
import app.awrad.core.testing.fixtures.goal
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.test.Test

class GoalCompletionFixtureTest {

    @Test
    fun `every goal_completion fixture case passes`() {
        FixtureRunner.runGoalModel("goal_completion") { given ->
            buildJsonObject { put("completed", given.goal().isCompletedOn(given.date("date"), given.counts())) }
        }
    }
}
