import groovy.json.JsonSlurper
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals

class CityListShapeTest {

    @Test
    fun `the shared city list has nothing the app doesn't read`() {
        val contract = generateSequence(File("").absoluteFile) { it.parentFile }
            .map { it.resolve("contracts/places/v1/cities.json") }
            .first { it.isFile }

        assertEquals(emptyList(), CityListShape.problems(JsonSlurper().parseText(contract.readText())))
    }

    @Test
    fun `unknown and missing keys fail, by path`() {
        assertEquals(listOf("cities.json: unknown key 'countries'"), problems(list(root = """"countries": [],""")))
        assertEquals(
            listOf("cities[1]: unknown key 'timezone'", "cities[1]: missing 'aliases'"),
            problems(list(city = """{"id": 1, "name": "A", "country": "IN", "region": null, "latitude": 1, "longitude": 2, "population": 3, "timezone": "Asia/Kolkata"}""")),
        )
    }

    @Test
    fun `another format fails`() {
        assertEquals(listOf("format: expected 'awrad-cities/1', got 'awrad-cities/2'"), problems(list(format = "awrad-cities/2")))
    }

    private fun problems(json: String) = CityListShape.problems(JsonSlurper().parseText(json))

    private fun list(
        root: String = "",
        format: String = "awrad-cities/1",
        city: String = """{"id": 1, "name": "A", "country": "IN", "region": null, "latitude": 1, "longitude": 2, "population": 3, "aliases": []}""",
    ) = """{$root "format": "$format", "source": "s", "license": "CC BY 4.0", "attribution": "a",
        "thresholds": {"default": 50000, "regions": {}}, "cities": [$city]}"""
}
