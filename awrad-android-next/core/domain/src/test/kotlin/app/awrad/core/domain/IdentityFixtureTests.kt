package app.awrad.core.domain

import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import kotlin.test.Test

class UuidFormatFixtureTest {

    @Test
    fun `every uuid_format fixture case passes`() {
        FixtureRunner.run(FixtureRunner.cases(FixtureModel.IDENTITY, "uuid_format")) { given ->
            val text = given.getValue("text").jsonPrimitive.content
            val parsed = AwradId.parse(text)
            check((parsed != null) == runCatching { AwradId(text) }.isSuccess) { "parse and the constructor disagree" }
            buildJsonObject { put("valid", parsed != null) }
        }
    }
}

class UuidV7LayoutFixtureTest {

    @Test
    fun `every uuid_v7_layout fixture case passes`() {
        FixtureRunner.run(FixtureRunner.cases(FixtureModel.IDENTITY, "uuid_v7_layout")) { given ->
            val unixMs = given.getValue("unix_ms").jsonPrimitive.long
            val random = given.getValue("random_hex").jsonPrimitive.content.chunked(2)
                .map { it.toInt(radix = 16).toByte() }
                .toByteArray()
            buildJsonObject { put("uuid", UuidV7.format(unixMs, random)) }
        }
    }
}
