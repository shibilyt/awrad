import groovy.json.JsonSlurper
import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.Property
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.Internal
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction

/**
 * Bundles the shared city list (`contracts/places/v1/cities.json`, generated from GeoNames) into the app as a
 * committed asset, byte for byte, after checking that the app knows its whole shape ([CityListShape]): an unknown
 * key fails generation instead of being dropped, since the app's parser (`:core:domain`'s `CityList`) is strict.
 *
 * With [verifyOnly] false it (re)writes [asset]. With [verifyOnly] true it fails when [asset] isn't exactly the
 * contract's list, so a rebuilt list can't land without the bundled copy. Never copy the file by hand.
 */
abstract class CityListTask : DefaultTask() {

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val contract: RegularFileProperty

    @get:Internal
    abstract val asset: RegularFileProperty

    @get:Input
    abstract val verifyOnly: Property<Boolean>

    @get:Input
    abstract val regenerateCommand: Property<String>

    @TaskAction
    fun run() {
        val contractFile = contract.get().asFile
        val text = contractFile.readText()
        val problems = CityListShape.problems(JsonSlurper().parseText(text))
        if (problems.isNotEmpty()) {
            throw GradleException(
                "${contractFile.path} has what the app doesn't read (update CityListShape and the parser, " +
                    "Cities.kt, together):\n" + problems.take(MAX_LISTED).joinToString("\n") { "  - $it" },
            )
        }
        val file = asset.get().asFile
        if (!verifyOnly.get()) {
            file.parentFile.mkdirs()
            file.writeText(text)
        } else if (!file.isFile || file.readText() != text) {
            throw GradleException(
                "${file.path} is out of date with ${contractFile.path}.\n" +
                    "Regenerate it with: ${regenerateCommand.get()}",
            )
        }
    }

    private companion object {
        const val MAX_LISTED = 20
    }
}

/** The keys of `cities.json` the app's parser reads. Anything else is a problem the app must learn first. */
internal object CityListShape {

    private const val FORMAT = "awrad-cities/1"
    private val ROOT = setOf("format", "source", "license", "attribution", "thresholds", "cities")
    private val THRESHOLDS = setOf("default", "regions")
    private val CITY = setOf("id", "name", "country", "region", "latitude", "longitude", "population", "aliases")

    /** Every key in [json] the app doesn't know, or a missing one, by path. Empty when the app reads all of it. */
    fun problems(json: Any?): List<String> = buildList {
        val root = objectAt("cities.json", json, ROOT) ?: return@buildList
        if (root["format"] != FORMAT) add("format: expected '$FORMAT', got '${root["format"]}'")
        objectAt("thresholds", root["thresholds"], THRESHOLDS)
        (root["cities"] as? List<*>).orEmpty().forEachIndexed { index, city ->
            val id = (city as? Map<*, *>)?.get("id") ?: index
            objectAt("cities[$id]", city, CITY)
        }
    }

    /** [json] as an object with exactly [known]'s keys, noting each other or missing one; null if not an object. */
    private fun MutableList<String>.objectAt(path: String, json: Any?, known: Set<String>): Map<*, *>? {
        if (json !is Map<*, *>) {
            add("$path: expected an object")
            return null
        }
        json.keys.filter { it !in known }.forEach { add("$path: unknown key '$it'") }
        known.filter { it !in json.keys }.forEach { add("$path: missing '$it'") }
        return json
    }
}
