package app.awrad.core.domain.goal.rules

import app.awrad.core.testing.fixtures.FixtureRunner
import app.awrad.core.testing.fixtures.counts
import app.awrad.core.testing.fixtures.date
import app.awrad.core.testing.fixtures.goal
import app.awrad.core.testing.fixtures.toFixtureName
import app.awrad.core.testing.fixtures.toJson
import app.awrad.core.testing.fixtures.weekStart
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.test.Test

class DaysPerPeriodFixtureTest {

    @Test
    fun `every days_per_period fixture case passes`() {
        FixtureRunner.runGoalModel("days_per_period") { given ->
            val standing = given.goal().daysPerPeriodOn(given.date("date"), given.counts(), given.weekStart())
            buildJsonObject {
                put("status", standing.status.toFixtureName())
                put("window", standing.window.toJson())
                put("qualifying_days", standing.qualifyingDays)
                put("required_days", standing.requiredDays)
            }
        }
    }
}
