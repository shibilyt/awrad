package app.awrad.core.domain.dhikr

import app.awrad.core.testing.contractCatalog
import app.awrad.core.testing.fixtures.FixtureRunner
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlin.test.Test

class DhikrSearchNormalizationFixtureTest {

    @Test
    fun `every dhikr_search_normalization fixture case passes`() {
        FixtureRunner.runDhikrCatalog("dhikr_search_normalization") { given ->
            buildJsonObject {
                put("normalized", DhikrSearchText.normalize(given.getValue("text").jsonPrimitive.content))
            }
        }
    }
}

class DhikrSearchFixtureTest {

    private val search = DhikrSearch(contractCatalog.dhikrs)

    @Test
    fun `every dhikr_search fixture case passes`() {
        FixtureRunner.runDhikrCatalog("dhikr_search") { given ->
            val language = checkNotNull(ContentLanguage.fromCode(given.getValue("language").jsonPrimitive.content))
            val keys = search.search(given.getValue("query").jsonPrimitive.content, language).map { it.key }
            buildJsonObject { putJsonArray("keys") { keys.forEach { add(it) } } }
        }
    }
}
