package app.awrad.core.domain.personal

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.sync.runSyncFixture
import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlin.test.Test
import kotlin.test.assertEquals

class TagNameNormalizationFixtureTest {

    @Test
    fun `every tag_name_normalization fixture case passes`() {
        runSyncFixture("tag_name_normalization") { given ->
            when (val result = TagName.of(given.getValue("input").jsonPrimitive.content)) {
                is TagNameResult.Accepted -> buildJsonObject {
                    put("accepted", true)
                    put("name", result.name.display)
                    put("normalized_name", result.name.normalized)
                    put("reason", JsonNull)
                }
                is TagNameResult.Rejected -> buildJsonObject {
                    put("accepted", false)
                    put("name", JsonNull)
                    put("normalized_name", JsonNull)
                    put("reason", result.problem.wire)
                }
            }
        }
    }
}

class CustomDhikrValidityFixtureTest {

    @Test
    fun `every custom_dhikr_validity fixture case passes`() {
        runSyncFixture("custom_dhikr_validity") { given ->
            val errors = CustomDhikrValidity.errors(given.getValue("document").jsonObject)
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
        val documents = FixtureRunner.cases(FixtureModel.SYNC, "custom_dhikr_validity")
            .filter { it.expect.getValue("valid").jsonPrimitive.content == "true" }
            .map { it.given.getValue("document").jsonObject }
        val id = AwradId("0192f0d0-0000-7000-8000-000000000001")
        documents.forEach { document ->
            val dhikr = checkNotNull(CustomDhikrJson.decode(id, document)) { "$document didn't decode" }
            assertEquals(document, CustomDhikrJson.encode(dhikr))
        }
        assert(documents.size > 5)
    }
}
