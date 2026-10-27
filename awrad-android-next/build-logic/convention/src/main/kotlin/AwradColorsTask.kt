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
 * Bundles the shared colour roles (`contracts/design-tokens/v1/colors.json`) into `:core:designsystem` as
 * committed source: the `AwradColors` class with the light and dark values ([source]), and the same roles as
 * Android colour resources for XML ([lightResource], [darkResource] in `values-night`).
 *
 * With [verifyOnly] false it (re)writes the three files. With [verifyOnly] true it fails when any of them isn't
 * exactly what the contract generates, so a colour can't change in one place only.
 */
abstract class AwradColorsTask : DefaultTask() {

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val contract: RegularFileProperty

    @get:Internal
    abstract val source: RegularFileProperty

    @get:Internal
    abstract val lightResource: RegularFileProperty

    @get:Internal
    abstract val darkResource: RegularFileProperty

    @get:Input
    abstract val packageName: Property<String>

    @get:Input
    abstract val verifyOnly: Property<Boolean>

    @get:Input
    abstract val regenerateCommand: Property<String>

    @TaskAction
    fun run() {
        val roles = parse(contract.get().asFile.readText())
        val expected = mapOf(
            source.get().asFile to renderKotlin(roles),
            lightResource.get().asFile to renderResources(roles, Role::light),
            darkResource.get().asFile to renderResources(roles, Role::dark),
        )
        if (!verifyOnly.get()) {
            expected.forEach { (file, text) ->
                file.parentFile.mkdirs()
                file.writeText(text)
            }
            return
        }
        val stale = expected.filter { (file, text) -> !file.isFile || file.readText() != text }.keys
        if (stale.isNotEmpty()) {
            throw GradleException(
                "Out of date with ${contract.get().asFile.path}:\n" +
                    stale.joinToString("\n") { "  - ${it.path}" } +
                    "\nRegenerate them with: ${regenerateCommand.get()}",
            )
        }
    }

    private class Role(val name: String, val use: String, val light: String, val dark: String)

    private fun parse(json: String): List<Role> {
        @Suppress("UNCHECKED_CAST")
        val tokens = JsonSlurper().parseText(json) as Map<String, Any?>

        @Suppress("UNCHECKED_CAST")
        val roles = tokens.getValue("roles") as Map<String, Map<String, String>>
        return roles.map { (name, role) ->
            if (!NAME.matches(name)) throw GradleException("colors.json: role name '$name' isn't lowerCamelCase")
            Role(
                name = name,
                use = role.getValue("use"),
                light = hex(name, "light", role["light"]),
                dark = hex(name, "dark", role["dark"]),
            )
        }
    }

    private fun hex(role: String, theme: String, value: String?): String {
        if (value == null || !HEX.matches(value)) {
            throw GradleException("colors.json: $role.$theme must be #RRGGBB or #RRGGBBAA, was $value")
        }
        return value.uppercase()
    }

    /** `#RRGGBB` or `#RRGGBBAA` as Android's `AARRGGBB`. */
    private fun argb(hex: String): String {
        val rgb = hex.substring(1, 7)
        val alpha = if (hex.length == 9) hex.substring(7, 9) else "FF"
        return alpha + rgb
    }

    private fun renderKotlin(roles: List<Role>): String = buildString {
        appendLine("// Generated from contracts/design-tokens/v1/colors.json. Don't edit by hand:")
        appendLine("// regenerate with `${regenerateCommand.get()}`. `verifyAwradColors` fails the")
        appendLine("// build when this file and the contract differ.")
        appendLine("@file:Suppress(\"LongParameterList\", \"MagicNumber\")")
        appendLine()
        appendLine("package ${packageName.get()}")
        appendLine()
        appendLine("import androidx.compose.runtime.Immutable")
        appendLine("import androidx.compose.ui.graphics.Color")
        appendLine()
        appendLine("/**")
        appendLine(" * The shared colour roles of one theme. Pick a colour by role, never by hex or by checking the theme:")
        appendLine(" * read these through [AwradTheme.colors] (or `MaterialTheme.colorScheme` for the roles Material has).")
        appendLine(" */")
        appendLine("@Immutable")
        appendLine("public class AwradColors internal constructor(")
        roles.forEach { role ->
            val doc = wrap(role.use + ".")
            if (doc.size == 1) {
                appendLine("    /** ${doc.single()} */")
            } else {
                appendLine("    /**")
                doc.forEach { appendLine("     * $it") }
                appendLine("     */")
            }
            appendLine("    public val ${role.name}: Color,")
        }
        appendLine(")")
        appendLine()
        appendTheme("Light", roles, Role::light)
        appendLine()
        appendTheme("Dark", roles, Role::dark)
    }

    private fun StringBuilder.appendTheme(theme: String, roles: List<Role>, value: (Role) -> String) {
        appendLine("internal val ${theme}AwradColors: AwradColors = AwradColors(")
        roles.forEach { role -> appendLine("    ${role.name} = Color(0x${argb(value(role))}),") }
        appendLine(")")
    }

    private fun renderResources(roles: List<Role>, value: (Role) -> String): String = buildString {
        appendLine("<?xml version=\"1.0\" encoding=\"utf-8\"?>")
        appendLine("<!-- Generated from contracts/design-tokens/v1/colors.json. Don't edit by hand:")
        appendLine("     regenerate with `${regenerateCommand.get()}`. -->")
        appendLine("<resources xmlns:tools=\"http://schemas.android.com/tools\" tools:ignore=\"UnusedResources\">")
        roles.forEach { role ->
            appendLine("    <color name=\"awrad_${snake(role.name)}\">#${argb(value(role))}</color>")
        }
        appendLine("</resources>")
    }

    private fun snake(name: String): String = name.replace(Regex("([A-Z])")) { "_" + it.value.lowercase() }

    /** Words of [text] in lines that fit the 120-column limit once indented as KDoc. */
    private fun wrap(text: String): List<String> = text.split(" ").fold(mutableListOf("")) { lines, word ->
        val last = lines.last()
        when {
            last.isEmpty() -> lines[lines.lastIndex] = word
            last.length + 1 + word.length > KDOC_WIDTH -> lines += word
            else -> lines[lines.lastIndex] = "$last $word"
        }
        lines
    }

    private companion object {
        val NAME = Regex("[a-z][A-Za-z0-9]*")
        val HEX = Regex("#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?")
        const val KDOC_WIDTH = 100
    }
}
