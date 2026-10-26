package app.awrad.core.testing.fixtures

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import kotlin.io.path.extension
import kotlin.io.path.listDirectoryEntries
import kotlin.io.path.nameWithoutExtension

/** One case of an `awrad-fixture/1` file (contracts/FIXTURES.md). */
public data class FixtureCase(
    val id: String,
    val description: String,
    val given: JsonObject,
    val expect: JsonObject,
)

/** A shared model in `contracts/` whose `v1/fixtures/` the Android domain runs. */
public enum class FixtureModel(public val directory: String) {
    GOAL_MODEL("goal-model"),
    HIJRI_CALENDAR("hijri-calendar"),
    ACCOUNT_MODEL("account-model"),
}

/**
 * Runs shared `awrad-fixture/1` cases against a platform implementation.
 *
 * A test maps each case's `given` to a domain call and returns the result encoded the same way as
 * `expect`. Every case runs; failures are collected and reported together, each named by its case id.
 */
public object FixtureRunner {

    private const val FORMAT = "awrad-fixture/1"

    /** Loads `contracts/goal-model/v1/fixtures/<rule>.json`, found by walking up from the working directory. */
    public fun goalModelCases(rule: String): List<FixtureCase> = cases(FixtureModel.GOAL_MODEL, rule)

    /** Runs every case of the goal-model [rule]; returns how many ran. Fails if any case fails. */
    public fun runGoalModel(rule: String, evaluate: (given: JsonObject) -> JsonObject): Int =
        run(FixtureModel.GOAL_MODEL, rule, evaluate)

    /** Runs every case of the hijri-calendar [rule]; returns how many ran. Fails if any case fails. */
    public fun runHijriCalendar(rule: String, evaluate: (given: JsonObject) -> JsonObject): Int =
        run(FixtureModel.HIJRI_CALENDAR, rule, evaluate)

    /** Runs every case of the account-model [rule]; returns how many ran. Fails if any case fails. */
    public fun runAccountModel(rule: String, evaluate: (given: JsonObject) -> JsonObject): Int =
        run(FixtureModel.ACCOUNT_MODEL, rule, evaluate)

    /** Loads `contracts/<model>/v1/fixtures/<rule>.json`. */
    public fun cases(model: FixtureModel, rule: String): List<FixtureCase> =
        load(fixturesDir(model).resolve("$rule.json"), rule)

    /** The rule of every fixture file in [model]'s `v1/fixtures/`, so a guard can require a runner for each. */
    public fun rules(model: FixtureModel): Set<String> = fixturesDir(model)
        .listDirectoryEntries()
        .filter { it.extension == "json" }
        .map { it.nameWithoutExtension }
        .toSet()

    /** Loads [file]; fails when it's missing, isn't [rule]'s `awrad-fixture/1` file, or has no cases. */
    public fun load(file: Path, rule: String): List<FixtureCase> {
        check(Files.isRegularFile(file)) { "Fixture file is missing: $file" }
        val root = Json.parseToJsonElement(Files.readString(file)).jsonObject
        check(root.string("format") == FORMAT) { "$file isn't $FORMAT" }
        check(root.string("rule") == rule) { "$file is for rule '${root.string("rule")}', expected '$rule'" }
        val cases = root.getValue("cases").jsonArray.map { element ->
            val case = element.jsonObject
            FixtureCase(
                id = case.string("id"),
                description = case.string("description"),
                given = case.getValue("given").jsonObject,
                expect = case.getValue("expect").jsonObject,
            )
        }
        check(cases.isNotEmpty()) { "$file has no cases" }
        return cases
    }

    /** Runs every case and returns how many ran. Throws [AssertionError] naming each failing case. */
    public fun run(cases: List<FixtureCase>, evaluate: (given: JsonObject) -> JsonObject): Int {
        check(cases.isNotEmpty()) { "No fixture cases to run" }
        val failures = cases.mapNotNull { case ->
            runCatching { evaluate(case.given) }.fold(
                onSuccess = { actual ->
                    if (actual == case.expect) null else "${case.id}: expected ${case.expect}, got $actual"
                },
                onFailure = { error -> "${case.id}: threw $error" },
            )
        }
        if (failures.isNotEmpty()) {
            throw AssertionError(
                "${failures.size} of ${cases.size} fixture cases failed:\n" + failures.joinToString("\n") { "  - $it" },
            )
        }
        return cases.size
    }

    private fun run(model: FixtureModel, rule: String, evaluate: (given: JsonObject) -> JsonObject): Int =
        run(cases(model, rule), evaluate).also { println("${model.directory}/$rule: $it of $it cases passed") }

    /** Gradle runs tests from the module directory, so walk up until the repository's contracts appear. */
    private fun fixturesDir(model: FixtureModel): Path {
        val modelDir = "contracts/${model.directory}"
        val start = Paths.get(System.getProperty("user.dir")).toAbsolutePath()
        val root = generateSequence(start) { it.parent }.firstOrNull { Files.isDirectory(it.resolve(modelDir)) }
        checkNotNull(root) { "No $modelDir found above $start" }
        return root.resolve("$modelDir/v1/fixtures")
    }

    private fun JsonObject.string(key: String): String = getValue(key).jsonPrimitive.content
}
