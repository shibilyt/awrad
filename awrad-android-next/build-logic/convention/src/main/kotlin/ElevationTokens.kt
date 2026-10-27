import TokenText.appendDoc
import TokenText.float
import TokenText.identifier
import TokenText.sentence
import TokenText.string

/**
 * Renders shape.json's `elevation` (AwradTokensTask): each level is a drop shadow, `y` and `blur` in dp, whose
 * `color` is a colour role. The role resolves per theme, so the generated `AwradElevation` takes one theme's
 * `AwradColors`; a role that is transparent in a theme (`shadow` in dark) gives that theme no shadow.
 */
internal object ElevationTokens {
    class Elevation(val name: String, val y: String, val blur: String, val color: String, val use: String)

    private val KEYS = setOf("y", "blur", "color", "use")

    fun parse(file: TokenFile, colorRoles: Set<String>): List<Elevation> = file.obj("elevation").map { (name, value) ->
        val path = "elevation.$name"
        @Suppress("UNCHECKED_CAST")
        val level = value as? Map<String, Any?> ?: file.fail("$path must be an object")
        (level.keys - KEYS).firstOrNull()?.let { file.fail("$path.$it isn't supported on Android yet") }
        val blur = level["blur"]
        if ((blur as? Number)?.toDouble()?.let { it >= 0 } != true) file.fail("$path.blur must be 0 or more, was $blur")
        val color = string(file, "$path.color", level["color"])
        if (color !in colorRoles) file.fail("$path.color: '$color' isn't a colour role in colors.json")
        Elevation(
            name = identifier(file, name),
            y = float(file, "$path.y", level["y"]).removeSuffix("f"),
            blur = float(file, "$path.blur", blur).removeSuffix("f"),
            color = color,
            use = string(file, "$path.use", level["use"]),
        )
    }

    fun StringBuilder.appendElevations(elevations: List<Elevation>) {
        appendLine("/**")
        appendLine(" * Elevation: the only shadows the design allows, with one theme's colours. Read them through")
        appendLine(" * `AwradTheme.elevation` and draw one with `Modifier.awradShadow`.")
        appendLine(" */")
        appendLine("@Immutable")
        appendLine("public class AwradElevation internal constructor(colors: AwradColors) {")
        elevations.forEachIndexed { index, level ->
            if (index > 0) appendLine()
            appendDoc("    ", "${sentence(level.use)} y ${level.y}, blur ${level.blur}, `${level.color}`.")
            appendLine(
                "    public val ${level.name}: AwradShadow = " +
                    "AwradShadow(y = ${level.y}.dp, blur = ${level.blur}.dp, color = colors.${level.color})",
            )
        }
        appendLine("}")
    }
}
