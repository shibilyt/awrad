import groovy.json.JsonSlurper
import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.MapProperty
import org.gradle.api.provider.Property
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.Internal
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction

/**
 * Bundles the shared shape, spacing, type and motion tokens (`contracts/design-tokens/v1/{shape,spacing,
 * typography,motion}.json`) into `:core:designsystem` as committed Kotlin source, the same way [AwradColorsTask]
 * bundles the colours:
 *
 * - [shapeSource]: `AwradRadius` (the scale), `AwradShapes` (roles, continuous corners), `AwradStrokes` (the
 *   line widths the design allows) and `AwradElevation` (the shadows, each colour a role from [colorsContract]
 *   resolved per theme);
 * - [spacingSource]: `AwradSpacing` (scale and roles) and `AwradSizes`;
 * - [typeSource]: `AwradType`, one `TextStyle` per named style, in the interface font or the style's own
 *   `fontFamily`;
 * - [motionSource]: `AwradEasing`, `AwradDurations`, `AwradSprings`, `AwradHaptic` and `AwradMotions` (the named
 *   motions Android uses, and reduced motion).
 *
 * With [verifyOnly] false it (re)writes the files. With [verifyOnly] true it fails when any of them isn't exactly
 * what the contracts generate. A token the generator doesn't understand (a new top-level key in a contract, a
 * new key in a named motion, a stroke, an elevation or a text style, a font family missing from [fontFamilies], a
 * colour role missing from [colorsContract]) fails generation instead of being dropped, so the app can't silently
 * drift from the contract.
 */
abstract class AwradTokensTask : DefaultTask() {

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val shapeContract: RegularFileProperty

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val spacingContract: RegularFileProperty

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val typographyContract: RegularFileProperty

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val motionContract: RegularFileProperty

    /** `colors.json`, read only for its role names: an elevation's colour must be one of them. */
    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val colorsContract: RegularFileProperty

    @get:Internal
    abstract val shapeSource: RegularFileProperty

    @get:Internal
    abstract val spacingSource: RegularFileProperty

    @get:Internal
    abstract val typeSource: RegularFileProperty

    @get:Internal
    abstract val motionSource: RegularFileProperty

    @get:Input
    abstract val packageName: Property<String>

    /** Each `fontFamily` name in the contract (the interface font's, and any style's own) → the Kotlin `FontFamily`. */
    @get:Input
    abstract val fontFamilies: MapProperty<String, String>

    @get:Input
    abstract val verifyOnly: Property<Boolean>

    @get:Input
    abstract val regenerateCommand: Property<String>

    @TaskAction
    fun run() {
        val shape = read(shapeContract)
        val spacing = read(spacingContract)
        val typography = read(typographyContract)
        val motion = read(motionContract)
        val colorRoles = read(colorsContract).obj("roles").keys
        val header = TokenHeader(regenerateCommand.get(), packageName.get())
        val shapes = ShapeTokens.parse(shape, colorRoles)
        val expected = mapOf(
            shapeSource.get().asFile to ShapeTokens.render(shapes, header),
            spacingSource.get().asFile to SpacingTokens.render(SpacingTokens.parse(spacing), header),
            typeSource.get().asFile to TypeTokens.render(TypeTokens.parse(typography, fontFamilies.get()), header),
            motionSource.get().asFile to MotionTokens(motion, shapes).render(header),
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
                "Out of date with contracts/design-tokens/v1:\n" +
                    stale.joinToString("\n") { "  - ${it.path}" } +
                    "\nRegenerate them with: ${regenerateCommand.get()}",
            )
        }
    }

    private fun read(file: RegularFileProperty): TokenFile {
        val path = file.get().asFile
        @Suppress("UNCHECKED_CAST")
        val json = JsonSlurper().parseText(path.readText()) as Map<String, Any?>
        return TokenFile(path.name, json)
    }
}

/** One parsed contract file; [name] prefixes every error so a bad token is easy to find. */
internal class TokenFile(val name: String, val json: Map<String, Any?>) {
    @Suppress("UNCHECKED_CAST")
    fun obj(key: String): Map<String, Any?> = json[key] as? Map<String, Any?> ?: fail("'$key' must be an object")

    /** Fails on a top-level key outside [known] (besides `version` and `description`), so none is dropped. */
    fun requireKeys(vararg known: String) {
        (json.keys - known.toSet() - setOf("version", "description")).firstOrNull()?.let {
            fail("'$it' isn't supported on Android yet")
        }
    }

    fun fail(message: String): Nothing = throw GradleException("$name: $message")
}

/** The comment and package line every generated file starts with. */
internal class TokenHeader(private val regenerateCommand: String, val packageName: String) {
    fun StringBuilder.appendHeader(contract: String, imports: List<String>) {
        appendLine("// Generated from contracts/design-tokens/v1/$contract. Don't edit by hand:")
        appendLine("// regenerate with `$regenerateCommand`. `verifyAwradTokens` fails the")
        appendLine("// build when this file and the contract differ.")
        appendLine("@file:Suppress(\"MagicNumber\")")
        appendLine()
        appendLine("package $packageName")
        appendLine()
        imports.sorted().forEach { appendLine("import $it") }
        appendLine()
    }
}

/** Shared helpers for the renderers. */
internal object TokenText {
    private val NAME = Regex("[a-z][A-Za-z0-9]*")
    private const val KDOC_WIDTH = 100
    private const val MAX_LINE = 120

    /** A contract name as a Kotlin identifier: scale names like `2xl` become `xl2`. */
    fun identifier(file: TokenFile, name: String): String {
        val id = name.replace(Regex("^(\\d+)([a-z]+)$"), "$2$1")
        if (!NAME.matches(id)) file.fail("'$name' can't be a Kotlin name")
        return id
    }

    fun typeName(name: String): String = name.replaceFirstChar { it.uppercase() }

    /** A JSON number as a Kotlin Float literal: `0.96f`, `380f`. */
    fun float(file: TokenFile, what: String, value: Any?): String {
        val number = value as? Number ?: file.fail("$what must be a number, was $value")
        val text = java.math.BigDecimal(number.toString()).stripTrailingZeros().toPlainString()
        return "${text}f"
    }

    fun int(file: TokenFile, what: String, value: Any?): Int {
        val number = value as? Number ?: file.fail("$what must be a number, was $value")
        val decimal = java.math.BigDecimal(number.toString())
        if (decimal.stripTrailingZeros().scale() > 0) file.fail("$what must be a whole number, was $value")
        return decimal.toInt()
    }

    fun string(file: TokenFile, what: String, value: Any?): String =
        value as? String ?: file.fail("$what must be a string, was $value")

    /** Writes [text] as KDoc at [indent], on one line when it fits the 120-column limit. */
    fun StringBuilder.appendDoc(indent: String, text: String) {
        val single = "$indent/** $text */"
        if (single.length <= MAX_LINE) {
            appendLine(single)
            return
        }
        val lines = text.split(" ").fold(mutableListOf("")) { lines, word ->
            val last = lines.last()
            when {
                last.isEmpty() -> lines[lines.lastIndex] = word
                last.length + 1 + word.length > KDOC_WIDTH -> lines += word
                else -> lines[lines.lastIndex] = "$last $word"
            }
            lines
        }
        appendLine("$indent/**")
        lines.forEach { appendLine("$indent * $it") }
        appendLine("$indent */")
    }

    fun sentence(text: String): String = if (text.endsWith(".")) text else "$text."
}
