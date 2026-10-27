import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.ConfigurableFileCollection
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction

/**
 * Fails on a colour written as a literal (`Color(0x…)` in Kotlin, `#…` in resource XML). Colours come only
 * from the shared roles generated into `:core:designsystem` (ARCHITECTURE.md, "Colours"), so a screen can't
 * drift from the design with a hex value of its own. The generated files are excluded where this is wired up.
 */
abstract class ColorLiteralTask : DefaultTask() {

    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val sources: ConfigurableFileCollection

    @TaskAction
    fun verify() {
        val found = sources.files.sortedBy { it.path }.flatMap { file ->
            val pattern = when (file.extension) {
                "kt" -> KOTLIN
                "xml" -> XML
                else -> return@flatMap emptyList()
            }
            file.readLines().mapIndexedNotNull { index, line ->
                if (pattern.containsMatchIn(line)) "  - ${file.path}:${index + 1}: ${line.trim()}" else null
            }
        }
        if (found.isNotEmpty()) {
            throw GradleException(
                "Colour literals outside the generated design tokens. Use a role from AwradTheme.colors or " +
                    "MaterialTheme.colorScheme (or @color/awrad_… in XML) instead:\n" + found.joinToString("\n"),
            )
        }
    }

    private companion object {
        /** `Color(0xFF…)`, `Color(255, …)` or `Color(red = …)`. */
        val KOTLIN = Regex("""\bColor\(\s*(0[xX]|\d|red\s*=)""")

        /** A `#RGB`…`#AARRGGBB` value in an attribute or element. */
        val XML = Regex("""[">]\s*#[0-9A-Fa-f]{3,8}\s*[<"]""")
    }
}
