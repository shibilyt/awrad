import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.ConfigurableFileCollection
import org.gradle.api.provider.ListProperty
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction

/**
 * Fails on a raw design value outside `:core:designsystem`: a non-zero `dp` or `sp` literal, a corner shape built
 * from a number, a `tween` with a literal (or default) duration, a raw `spring(…)`, or Material's type and shape
 * slots. Screens use the generated tokens by name instead (`AwradTheme.spacing`, `.sizes`, `.shapes`, `.type`,
 * `.motion`; ARCHITECTURE.md, "Design tokens"), so a screen can't drift from `contracts/design-tokens/` with a
 * number of its own.
 *
 * `0.dp` is allowed: it's the absence of space, not a value. A genuinely structural number goes in [allowed] as
 * `<path suffix>: <the matched text>`, with a comment saying why, where this is wired up (`AwradBuild.kt`).
 */
abstract class DesignLiteralTask : DefaultTask() {

    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val sources: ConfigurableFileCollection

    @get:Input
    abstract val allowed: ListProperty<String>

    @TaskAction
    fun verify() {
        val allowList = allowed.get().map { entry ->
            val (path, text) = entry.split(": ", limit = 2).also {
                if (it.size != 2) throw GradleException("Allowed design literal '$entry' isn't '<path>: <text>'")
            }
            path to text
        }
        val found = sources.files.filter { it.extension == "kt" }.sortedBy { it.path }.flatMap { file ->
            val path = file.invariantSeparatorsPath
            fun isAllowed(text: String) = allowList.any { (suffix, allowedText) ->
                path.endsWith(suffix) && text == allowedText
            }
            file.readLines().flatMapIndexed { index, line ->
                findDesignLiterals(line)
                    .filterNot { (_, text) -> isAllowed(text) }
                    .map { (rule, text) -> "  - ${file.path}:${index + 1}: ${line.trim()}\n      `$text`: $rule" }
            }
        }
        if (found.isNotEmpty()) {
            throw GradleException(
                "Raw design values outside :core:designsystem. Use a token by name instead (AwradTheme.spacing, " +
                    ".sizes, .shapes, .strokes, .type, .motion; ARCHITECTURE.md, \"Design tokens\"):\n" +
                    found.joinToString("\n"),
            )
        }
    }
}

/** What a rule says to use instead, and the pattern it rejects. */
private class DesignLiteralRule(val use: String, val pattern: Regex)

private val RULES = listOf(
    DesignLiteralRule("use AwradTheme.spacing, .sizes or .strokes", Regex("""(?<![\w.])\d+(\.\d+)?\.dp\b""")),
    DesignLiteralRule("use AwradTheme.spacing, .sizes or .strokes", Regex("""\bDp\(\s*\d""")),
    DesignLiteralRule("use an AwradTheme.type style", Regex("""(?<![\w.])\d+(\.\d+)?\.sp\b""")),
    DesignLiteralRule(
        "use an AwradTheme.shapes role",
        Regex("""\b(Absolute)?(RoundedCornerShape|CutCornerShape)\s*\([^)]*\d"""),
    ),
    DesignLiteralRule(
        "use AwradTheme.motion (a named spec, or tween with AwradDurations)",
        Regex("""\btween\s*(<[^>]*>)?\(\s*(\)|\d)"""),
    ),
    DesignLiteralRule("use AwradDurations", Regex("""\b(durationMillis|delayMillis)\s*=\s*\d""")),
    DesignLiteralRule("use AwradTheme.motion (springs from AwradSprings)", Regex("""(?<![.\w])spring\s*(<[^>]*>)?\(""")),
    DesignLiteralRule("use AwradTheme.type", Regex("""\bMaterialTheme\.typography\b""")),
    DesignLiteralRule("use AwradTheme.shapes", Regex("""\bMaterialTheme\.shapes\b""")),
)

/** Zero, written any way, is no space at all. */
private val ZERO = Regex("""^0+(\.0+)?\.dp$""")

/** The raw design values on [line] (comments excepted), as (what to use instead, the matched text). */
internal fun findDesignLiterals(line: String): List<Pair<String, String>> {
    val code = line.substringBefore("//").trim()
    if (code.startsWith("*") || code.startsWith("/*")) return emptyList()
    return RULES.flatMap { rule ->
        rule.pattern.findAll(code).map { it.value.trim() }.filterNot { ZERO.matches(it) }.map { rule.use to it }
    }
}
