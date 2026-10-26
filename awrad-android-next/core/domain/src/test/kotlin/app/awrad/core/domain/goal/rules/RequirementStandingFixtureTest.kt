package app.awrad.core.domain.goal.rules

import app.awrad.core.testing.fixtures.FixtureRunner
import app.awrad.core.testing.fixtures.counts
import app.awrad.core.testing.fixtures.date
import app.awrad.core.testing.fixtures.goal
import app.awrad.core.testing.fixtures.hijriCorrections
import app.awrad.core.testing.fixtures.toFixtureName
import app.awrad.core.testing.fixtures.toJson
import app.awrad.core.testing.fixtures.weekStart
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlin.test.Test

class RequirementStandingFixtureTest {

    @Test
    fun `every requirement_standing fixture case passes`() {
        FixtureRunner.runGoalModel("requirement_standing") { given ->
            given.goal()
                .standingOn(given.date("date"), given.counts(), given.weekStart(), given.hijriCorrections())
                .toJson()
        }
    }

    private fun RequirementStanding.toJson(): JsonObject = buildJsonObject {
        put("status", status.toFixtureName())
        put("window", window.toJson())
        put("progress", progress)
        put("target", target)
        putJsonArray("sessions") {
            sessions.forEach { session ->
                addJsonObject {
                    put("id", session.id)
                    put("progress", session.progress)
                    put("target", session.target)
                    put("status", if (session.isMet) "met" else "not_met")
                }
            }
        }
    }
}
