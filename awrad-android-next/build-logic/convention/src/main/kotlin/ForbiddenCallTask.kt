import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.ConfigurableFileCollection
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction

/**
 * Fails on a call the app must not make, in any form (imported, static-imported or fully qualified), which
 * detekt's `ForbiddenMethodCall` can't promise without type resolution. Tests are not checked.
 *
 * - `UUID.randomUUID()` makes a UUIDv4. Every ID the app makes is a UUIDv7 (root ADR-2026-10-28), from
 *   `:core:domain`'s `UuidV7` (or `AwradId.random()`; in `:core:network`, its `IdGenerator`).
 */
abstract class ForbiddenCallTask : DefaultTask() {

    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val sources: ConfigurableFileCollection

    @TaskAction
    fun verify() {
        val found = sources.files.filter { it.extension == "kt" }.sortedBy { it.path }.flatMap { file ->
            file.readLines().flatMapIndexed { index, line ->
                RULES.filter { it.pattern.containsMatchIn(line) }
                    .map { "  - ${file.path}:${index + 1}: ${line.trim()}\n      ${it.use}" }
            }
        }
        if (found.isNotEmpty()) {
            throw GradleException("Forbidden calls (ARCHITECTURE.md, \"Identity\"):\n" + found.joinToString("\n"))
        }
    }

    /** What to use instead, and the pattern it rejects. */
    private class Rule(val use: String, val pattern: Regex)

    private companion object {
        val RULES = listOf(
            Rule(
                "UUID.randomUUID makes a UUIDv4; use UuidV7.generate() or AwradId.random() (ADR-2026-10-28)",
                Regex("""\brandomUUID\b"""),
            ),
        )
    }
}
