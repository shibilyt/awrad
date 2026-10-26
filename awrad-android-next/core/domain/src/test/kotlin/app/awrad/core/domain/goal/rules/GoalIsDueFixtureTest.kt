package app.awrad.core.domain.goal.rules

import app.awrad.core.testing.fixtures.FixtureRunner
import app.awrad.core.testing.fixtures.date
import app.awrad.core.testing.fixtures.goal
import app.awrad.core.testing.fixtures.hijriCorrections
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.test.Test

class GoalIsDueFixtureTest {

    @Test
    fun `every goal_is_due fixture case passes`() {
        FixtureRunner.runGoalModel("goal_is_due") { given ->
            buildJsonObject { put("due", given.goal().isDueOn(given.date("date"), given.hijriCorrections())) }
        }
    }
}
