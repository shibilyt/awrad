package app.awrad.core.domain.goal.rules

import app.awrad.core.testing.fixtures.FixtureRunner
import java.nio.file.Files
import java.nio.file.Path
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/** The runner is what makes the fixtures binding, so it must fail loudly rather than pass vacuously. */
class FixtureRunnerTest {

    private val dir: Path = Files.createTempDirectory("fixtures")

    @Test
    fun `a missing fixture file fails`() {
        val error = assertFailsWith<IllegalStateException> { FixtureRunner.load(dir.resolve("absent.json"), "absent") }
        assertContains(error.message.orEmpty(), "missing")
    }

    @Test
    fun `a fixture file with no cases fails`() {
        val file = write("empty", cases = "")
        val error = assertFailsWith<IllegalStateException> { FixtureRunner.load(file, "empty") }
        assertContains(error.message.orEmpty(), "no cases")
    }

    @Test
    fun `a file for another rule fails`() {
        val file = write("streak", cases = CASES)
        assertFailsWith<IllegalStateException> { FixtureRunner.load(file, "completion") }
    }

    @Test
    fun `a failing case is reported by its id`() {
        val cases = FixtureRunner.load(write("echo", cases = CASES), "echo")
        val error = assertFailsWith<AssertionError> { FixtureRunner.run(cases) { given -> given } }
        assertContains(error.message.orEmpty(), "second_case")
        assertContains(error.message.orEmpty(), "1 of 2")
    }

    @Test
    fun `a throwing case is reported by its id`() {
        val cases = FixtureRunner.load(write("echo", cases = CASES), "echo")
        val error = assertFailsWith<AssertionError> { FixtureRunner.run(cases) { error("boom") } }
        assertContains(error.message.orEmpty(), "first_case: threw")
    }

    @Test
    fun `passing cases are counted`() {
        val cases = FixtureRunner.load(write("echo", cases = CASES), "echo")
        val passing = cases.map { it.copy(expect = it.given) }
        assertEquals(2, FixtureRunner.run(passing) { given -> given })
    }

    @Test
    fun `the shared goal model fixtures are found from the module directory`() {
        val ids = FixtureRunner.goalModelCases("effective_practice_day").map { it.id }
        assertContains(ids, "maghrib_instant_starts_the_new_day")
    }

    private fun write(rule: String, cases: String): Path {
        val file = dir.resolve("$rule.json")
        Files.writeString(file, """{"format": "awrad-fixture/1", "rule": "$rule", "cases": [$cases]}""")
        return file
    }

    private companion object {
        // The second case expects 3 for an input of 2, so an echo implementation fails only it.
        const val CASES = """
            {"id": "first_case", "description": "d", "given": {"value": 1}, "expect": {"value": 1}},
            {"id": "second_case", "description": "d", "given": {"value": 2}, "expect": {"value": 3}}
        """
    }
}
