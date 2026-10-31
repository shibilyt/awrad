package app.awrad.core.domain.goal.rules

import app.awrad.core.testing.fixtures.FixtureRunner
import app.awrad.core.testing.fixtures.counts
import app.awrad.core.testing.fixtures.date
import app.awrad.core.testing.fixtures.goalInput
import app.awrad.core.testing.fixtures.hijriCorrections
import app.awrad.core.testing.fixtures.toFixtureName
import app.awrad.core.testing.fixtures.weekStart
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.test.Test

class GoalStreakFixtureTest {

    @Test
    fun `every goal_streak fixture case passes`() {
        FixtureRunner.runGoalModel("goal_streak") { given ->
            val streak = given.goalInput()
                .streakOn(given.date("date"), given.counts(), given.weekStart(), given.hijriCorrections())
            buildJsonObject {
                put("current", streak.current)
                put("unit", streak.unit.toFixtureName())
                put("weekday", streak.weekday?.toFixtureName())
                put("pending_make_up", JsonArray(streak.pendingMakeUp.map { JsonPrimitive(it.toString()) }))
            }
        }
    }
}
