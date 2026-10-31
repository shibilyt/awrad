package app.awrad.core.domain.goal

import app.awrad.core.domain.AwradId
import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** The goal document codec the sync layer stores and sends: every fixture document survives a round trip. */
class GoalJsonTest {

    private val documents: List<JsonObject> = listOf("goal_version_on_day", "goal_validity")
        .flatMap { FixtureRunner.cases(FixtureModel.GOAL_MODEL, it) }
        .mapNotNull { it.given["document"]?.jsonObject }

    @Test
    fun `every valid fixture document encodes back to itself`() {
        val valid = documents.mapNotNull { json -> GoalJson.decodeDocument(json)?.let { json to it } }
        assertTrue(valid.size >= 10, "found ${valid.size} valid documents")
        valid.forEach { (json, document) -> assertEquals(json, GoalJson.encodeDocument(document)) }
    }

    @Test
    fun `an invalid or malformed document doesn't decode`() {
        val invalid = documents.filter { (GoalJson.decodeTimeline(it) as? GoalTimelineResult.Invalid) != null }
        assertTrue(invalid.isNotEmpty())
        invalid.forEach { assertNull(GoalJson.decodeDocument(it)) }
        val malformed = JsonObject(documents.first() + ("created_on" to JsonPrimitive(7)))
        assertNull(GoalJson.decodeDocument(malformed))
        assertNull(GoalJson.decodeTimeline(malformed))
    }

    @Test
    fun `a goal order round-trips and rejects repeats`() {
        val id = "0192f300-0000-7000-8000-000000000001"
        val order = assertNotNull(GoalOrderJson.decode(GoalOrderJson.encode(GoalOrder(listOf(AwradId(id))))))
        assertEquals(listOf(id), order.goalIds.map { it.value })
        val repeated = JsonObject(mapOf("goal_ids" to JsonArray(listOf(JsonPrimitive(id), JsonPrimitive(id)))))
        assertNull(GoalOrderJson.decode(repeated))
    }
}
