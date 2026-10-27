import TokenText.appendDoc
import TokenText.float
import TokenText.identifier
import TokenText.sentence
import TokenText.string

/*
 * Renderers for shape.json, spacing.json and typography.json (AwradTokensTask). Each parses its contract
 * strictly, failing on anything it can't express in Kotlin, and renders one committed source file.
 */

/** A `Dp` literal for a contract number: `20.dp`, `0.5.dp`. */
private fun TokenFile.dp(what: String, value: Any?): String = float(this, what, value).removeSuffix("f") + ".dp"

private fun TokenFile.sp(what: String, value: Any?): String = float(this, what, value).removeSuffix("f") + ".sp"

private fun TokenFile.number(what: String, value: Any?): String = float(this, what, value).removeSuffix("f")

internal object ShapeTokens {
    /** A scale step: its Kotlin name and radius, null for `full`. */
    class Step(val name: String, val radius: Any?)

    class Role(val name: String, val step: Step, val use: String)

    class Parsed(val file: TokenFile, val continuous: Boolean, val scale: List<Step>, val roles: List<Role>) {
        /** The scale step a role uses, for tokens elsewhere that name a shape role (a motion's `radius`). */
        fun role(name: String): Role = roles.firstOrNull { it.name == name } ?: file.fail("no shape role '$name'")
    }

    fun parse(file: TokenFile): Parsed {
        val continuous = when (val corners = file.json["corners"]) {
            "continuous" -> true
            "circular" -> false
            else -> file.fail("corners must be continuous or circular, was $corners")
        }
        val scale = file.obj("scale").map { (name, value) ->
            Step(identifier(file, name), if (value == "full") null else value.also { file.dp("scale.$name", it) })
        }
        val byContractName = file.obj("scale").keys.zip(scale).toMap()
        @Suppress("UNCHECKED_CAST")
        val roles = file.obj("roles").map { (name, role) ->
            role as Map<String, Any?>
            val step = string(file, "roles.$name.radius", role["radius"])
            Role(
                name = identifier(file, name),
                step = byContractName[step] ?: file.fail("roles.$name: no scale step '$step'"),
                use = string(file, "roles.$name.use", role["use"]),
            )
        }
        return Parsed(file, continuous, scale, roles)
    }

    fun render(shapes: Parsed, header: TokenHeader): String = buildString {
        with(header) {
            appendHeader("shape.json", listOf("androidx.compose.ui.unit.Dp", "androidx.compose.ui.unit.dp"))
        }
        appendLine("/** The corner-radius scale (without `full`). Screens use a role from [AwradShapes], not these. */")
        appendLine("public object AwradRadius {")
        shapes.scale.filter { it.radius != null }.forEachIndexed { index, step ->
            if (index > 0) appendLine()
            appendDoc("    ", shapes.file.number("scale", step.radius))
            appendLine("    public val ${step.name}: Dp = ${shapes.file.dp("scale.${step.name}", step.radius)}")
        }
        appendLine("}")
        appendLine()
        appendLine("/**")
        appendLine(" * Corner shapes by role, with ${if (shapes.continuous) "continuous" else "circular"} corners. " +
            "Read them through `AwradTheme.shapes`;")
        appendLine(" * Material's `Shapes` map onto them in `AwradTheme`.")
        appendLine(" */")
        appendLine("public object AwradShapes {")
        shapes.roles.forEachIndexed { index, role ->
            if (index > 0) appendLine()
            val radius = role.step.radius
            val size = if (radius == null) "fully rounded" else "`${role.step.name}`, ${shapes.file.number("", radius)}"
            appendDoc("    ", "${role.use}: $size.")
            val value = if (radius == null) {
                "SmoothCornerShape.full(CornerSmoothing)"
            } else {
                "SmoothCornerShape(AwradRadius.${role.step.name}, CornerSmoothing)"
            }
            appendLine("    public val ${role.name}: SmoothCornerShape = $value")
        }
        appendLine("}")
        appendLine()
        if (shapes.continuous) {
            appendLine("/** `corners: continuous`. */")
            appendLine("private const val CornerSmoothing: Float = SmoothCornerShape.CONTINUOUS")
        } else {
            appendLine("/** `corners: circular`. */")
            appendLine("private const val CornerSmoothing: Float = 0f")
        }
    }
}

internal object SpacingTokens {
    class Entry(val name: String, val value: String, val doc: String)

    class Parsed(val scale: List<Entry>, val roles: List<Entry>, val sizes: List<Entry>)

    fun parse(file: TokenFile): Parsed {
        val scale = file.obj("scale").map { (name, value) ->
            val id = identifier(file, name)
            Entry(id, file.dp("scale.$name", value), file.number("scale.$name", value))
        }
        val byContractName = file.obj("scale").keys.zip(scale).toMap()
        @Suppress("UNCHECKED_CAST")
        val roles = file.obj("roles").map { (name, role) ->
            role as Map<String, Any?>
            val space = string(file, "roles.$name.space", role["space"])
            val step = byContractName[space] ?: file.fail("roles.$name: no scale step '$space'")
            val use = string(file, "roles.$name.use", role["use"])
            Entry(identifier(file, name), step.name, "$use: `${step.name}`, ${step.doc}.")
        }
        @Suppress("UNCHECKED_CAST")
        val sizes = file.obj("sizes").map { (name, size) ->
            size as Map<String, Any?>
            val value = size["value"]
            Entry(
                identifier(file, name),
                file.dp("sizes.$name", value),
                "${string(file, "sizes.$name.use", size["use"])}: ${file.number("sizes.$name", value)}.",
            )
        }
        val clash = scale.map { it.name }.intersect(roles.map { it.name }.toSet())
        if (clash.isNotEmpty()) file.fail("role names clash with scale names: $clash")
        return Parsed(scale, roles, sizes)
    }

    fun render(spacing: Parsed, header: TokenHeader): String = buildString {
        with(header) {
            appendHeader("spacing.json", listOf("androidx.compose.ui.unit.Dp", "androidx.compose.ui.unit.dp"))
        }
        appendLine("/**")
        appendLine(" * Spacing: the scale (`none` to `xl5`; the contract's `2xl` is `xl2`) and the named roles. Prefer a")
        appendLine(" * role. Read it through `AwradTheme.spacing`.")
        appendLine(" */")
        appendLine("public object AwradSpacing {")
        spacing.scale.forEachIndexed { index, entry ->
            if (index > 0) appendLine()
            appendDoc("    ", entry.doc)
            appendLine("    public val ${entry.name}: Dp = ${entry.value}")
        }
        spacing.roles.forEach { entry ->
            appendLine()
            appendDoc("    ", entry.doc)
            appendLine("    public val ${entry.name}: Dp = ${entry.value}")
        }
        appendLine("}")
        appendLine()
        appendLine("/** Standard sizes. Read them through `AwradTheme.sizes`. */")
        appendLine("public object AwradSizes {")
        spacing.sizes.forEachIndexed { index, entry ->
            if (index > 0) appendLine()
            appendDoc("    ", entry.doc)
            appendLine("    public val ${entry.name}: Dp = ${entry.value}")
        }
        appendLine("}")
    }
}

internal object TypeTokens {
    class Style(
        val name: String,
        val size: String,
        val lineHeight: String,
        val weight: String,
        val letterSpacing: String,
        val tabularNumbers: Boolean,
        val doc: String,
    )

    class Parsed(val fontFamily: String, val styles: List<Style>)

    private val WEIGHTS = mapOf(400 to "Normal", 500 to "Medium", 600 to "SemiBold", 700 to "Bold")
    private val KEYS = setOf("size", "lineHeight", "weight", "iosTextStyle", "tabularNumbers", "tracking", "use")

    fun parse(file: TokenFile, fontFamilies: Map<String, String>): Parsed {
        val family = string(file, "fontFamily", file.json["fontFamily"])
        val fontFamily = fontFamilies[family]
            ?: file.fail("fontFamily '$family' isn't bundled in :core:designsystem (known: ${fontFamilies.keys})")
        @Suppress("UNCHECKED_CAST")
        val styles = file.obj("styles").map { (name, style) ->
            style as Map<String, Any?>
            (style.keys - KEYS).firstOrNull()?.let { file.fail("styles.$name.$it isn't supported on Android yet") }
            val weightValue = TokenText.int(file, "styles.$name.weight", style["weight"])
            val weight = WEIGHTS[weightValue] ?: file.fail("styles.$name.weight $weightValue isn't bundled")
            val tabular = when (val value = style["tabularNumbers"]) {
                null, false -> false
                true -> true
                else -> file.fail("styles.$name.tabularNumbers must be a boolean, was $value")
            }
            val size = file.number("styles.$name.size", style["size"])
            val lineHeight = file.number("styles.$name.lineHeight", style["lineHeight"])
            Style(
                name = identifier(file, name),
                size = file.sp("styles.$name.size", style["size"]),
                lineHeight = file.sp("styles.$name.lineHeight", style["lineHeight"]),
                weight = weight,
                // `tracking` is in points on iOS, which are sp here.
                letterSpacing = file.sp("styles.$name.tracking", style["tracking"] ?: 0),
                tabularNumbers = tabular,
                doc = sentence(string(file, "styles.$name.use", style["use"])) +
                    " $size on $lineHeight, weight $weightValue" + (if (tabular) ", tabular numbers." else "."),
            )
        }
        return Parsed(fontFamily, styles)
    }

    fun render(type: Parsed, header: TokenHeader): String = buildString {
        with(header) {
            appendHeader(
                "typography.json",
                listOf(
                    "androidx.compose.ui.text.TextStyle",
                    "androidx.compose.ui.text.font.FontWeight",
                    "androidx.compose.ui.unit.sp",
                ),
            )
        }
        appendLine("/**")
        appendLine(" * The named text styles, in the interface font. Read them through `AwradTheme.type`; Material's")
        appendLine(" * `Typography` maps onto them in `AwradTypography`.")
        appendLine(" */")
        appendLine("public object AwradType {")
        type.styles.forEachIndexed { index, style ->
            if (index > 0) appendLine()
            appendDoc("    ", style.doc)
            appendLine("    public val ${style.name}: TextStyle = TextStyle(")
            appendLine("        fontFamily = ${type.fontFamily},")
            appendLine("        fontWeight = FontWeight.${style.weight},")
            appendLine("        fontSize = ${style.size},")
            appendLine("        lineHeight = ${style.lineHeight},")
            appendLine("        letterSpacing = ${style.letterSpacing},")
            appendLine("        lineHeightStyle = AwradLineHeightStyle,")
            if (style.tabularNumbers) appendLine("        fontFeatureSettings = \"tnum\",")
            appendLine("    )")
        }
        appendLine("}")
    }
}
