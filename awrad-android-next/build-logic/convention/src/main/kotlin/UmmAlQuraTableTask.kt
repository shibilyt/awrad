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
 * Bundles the shared Umm al-Qura table (`contracts/hijri-calendar/v1/umm-al-qura.json`) into
 * `:core:domain` as committed Kotlin source, so the app ships it offline and never reads `contracts/`
 * at runtime (root ADR-2026-10-26).
 *
 * With [verifyOnly] false it (re)writes [source]. With [verifyOnly] true it fails when [source] isn't
 * exactly what the contract generates, so a table change can't land without the bundled copy.
 */
abstract class UmmAlQuraTableTask : DefaultTask() {

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val contract: RegularFileProperty

    @get:Internal
    abstract val source: RegularFileProperty

    @get:Input
    abstract val packageName: Property<String>

    @get:Input
    abstract val verifyOnly: Property<Boolean>

    @get:Input
    abstract val regenerateCommand: Property<String>

    @TaskAction
    fun run() {
        val expected = render(contract.get().asFile.readText())
        val file = source.get().asFile
        if (!verifyOnly.get()) {
            file.parentFile.mkdirs()
            file.writeText(expected)
        } else if (!file.isFile || file.readText() != expected) {
            throw GradleException(
                "${file.path} is out of date with ${contract.get().asFile.path}.\n" +
                    "Regenerate it with: ${regenerateCommand.get()}",
            )
        }
    }

    private fun render(json: String): String {
        @Suppress("UNCHECKED_CAST")
        val table = JsonSlurper().parseText(json) as Map<String, Any?>
        val firstYear = table.getValue("first_year") as Int
        val lastYear = table.getValue("last_year") as Int
        val endExclusive = table.getValue("end_exclusive") as String

        @Suppress("UNCHECKED_CAST")
        val starts = table.getValue("month_starts") as Map<String, List<String>>
        val years = (firstYear..lastYear).flatMap { year ->
            val months = starts[year.toString()]
                ?: throw GradleException("umm-al-qura.json has no month starts for $year")
            if (months.size != MONTHS) throw GradleException("umm-al-qura.json: $year has ${months.size} months")
            months.chunked(MONTHS / 2).map { half -> "$year ${half.joinToString(" ")}" }
        }
        return buildString {
            appendLine("// Generated from contracts/hijri-calendar/v1/umm-al-qura.json. Don't edit by hand:")
            appendLine("// regenerate with `${regenerateCommand.get()}`. `verifyUmmAlQuraTable` fails the")
            appendLine("// build when this file and the contract differ.")
            appendLine("package ${packageName.get()}")
            appendLine()
            appendLine("/** The shared Umm al-Qura month table, 1 Muharram $firstYear to the end of $lastYear AH. */")
            appendLine("internal object UmmAlQuraTable {")
            appendLine("    const val FIRST_YEAR: Int = $firstYear")
            appendLine("    const val LAST_YEAR: Int = $lastYear")
            appendLine()
            appendLine("    /** The day after the table's last month ends. */")
            appendLine("    const val END_EXCLUSIVE: String = \"$endExclusive\"")
            appendLine()
            appendLine("    /** Gregorian start of every month: half a Hijri year per line, prefixed with the year. */")
            appendLine("    const val MONTH_STARTS: String = \"\"\"")
            years.forEach { appendLine(it) }
            appendLine("\"\"\"")
            appendLine("}")
        }
    }

    private companion object {
        const val MONTHS = 12
    }
}
