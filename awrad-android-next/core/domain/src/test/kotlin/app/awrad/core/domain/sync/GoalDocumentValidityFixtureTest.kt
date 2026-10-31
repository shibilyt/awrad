package app.awrad.core.domain.sync

import app.awrad.core.domain.goal.GoalDocumentValidity
import app.awrad.core.domain.goal.GoalJson
import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class GoalDocumentValidityFixtureTest {

    @Test
    fun `every goal_document_validity fixture case passes`() {
        runSyncFixture("goal_document_validity") { given ->
            val errors = GoalDocumentValidity.errors(given.getValue("document").jsonObject)
            buildJsonObject {
                put("valid", errors.isEmpty())
                putJsonArray("errors") {
                    errors.forEach { error ->
                        addJsonObject {
                            put("field", error.field)
                            put("code", error.code.wire)
                        }
                    }
                }
            }
        }
    }

    @Test
    fun `every valid fixture document decodes and encodes back unchanged`() {
        val documents = FixtureRunner.cases(FixtureModel.SYNC, "goal_document_validity")
            .filter { it.expect.getValue("valid").jsonPrimitive.content == "true" }
            .map { it.given.getValue("document").jsonObject }
        documents.forEach { document ->
            val goal = checkNotNull(GoalJson.decodeDocument(document)) { "$document didn't decode" }
            assertEquals(document, GoalJson.encodeDocument(goal))
        }
        assertTrue(documents.size >= 4)
    }
}
