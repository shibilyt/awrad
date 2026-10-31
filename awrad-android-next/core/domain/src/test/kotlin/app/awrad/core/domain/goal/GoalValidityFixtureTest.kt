package app.awrad.core.domain.goal

import app.awrad.core.testing.fixtures.FixtureRunner
import app.awrad.core.testing.fixtures.goalResult
import app.awrad.core.testing.fixtures.timelineResult
import app.awrad.core.testing.fixtures.toFixtureName
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlin.test.Test

class GoalValidityFixtureTest {

    @Test
    fun `every goal_validity fixture case passes`() {
        FixtureRunner.runGoalModel("goal_validity") { given ->
            val errors = if ("document" in given) {
                when (val result = given.timelineResult("document")) {
                    is GoalTimelineResult.Valid -> emptySet()
                    is GoalTimelineResult.Invalid -> result.errors
                }
            } else {
                when (val result = given.goalResult()) {
                    is GoalDefinitionResult.Valid -> emptySet()
                    is GoalDefinitionResult.Invalid -> result.errors
                }
            }
            val codes = errors.map { it.toFixtureName() }.sorted()
            buildJsonObject {
                put("valid", codes.isEmpty())
                putJsonArray("errors") { codes.forEach { add(it) } }
            }
        }
    }
}
