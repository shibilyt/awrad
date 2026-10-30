package app.awrad.core.domain.places

import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.putJsonArray
import kotlin.test.Test
import kotlin.test.assertEquals

class CitySearchFixtureTest {

    private val list = CityList.parse(FixtureRunner.contractFile(FixtureModel.PLACES, "cities.json"))

    @Test
    fun `every city_search fixture case passes`() {
        val search = CitySearch(list.cities)
        val count = FixtureRunner.run(FixtureRunner.cases(FixtureModel.PLACES, "city_search")) { given ->
            val found = search.search(
                query = given.getValue("query").jsonPrimitive.content,
                limit = given.getValue("limit").jsonPrimitive.int,
            )
            buildJsonObject { putJsonArray("city_ids") { found.forEach { add(it.id) } } }
        }
        println("places/city_search: $count of $count cases passed")
    }

    @Test
    fun `the contract's list parses with its attribution`() {
        assertEquals("City data © GeoNames (geonames.org), CC BY 4.0", list.attribution)
        assertEquals(list.cities.size, list.cities.map { it.id }.toSet().size)
        assertEquals("Kozhikode", list.city(1_265_873)?.name)
    }
}
