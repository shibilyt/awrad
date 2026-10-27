import TokenText.appendDoc
import TokenText.float
import TokenText.identifier
import TokenText.sentence
import TokenText.string

/*
 * Renderers for shape.json (radii and strokes), spacing.json and typography.json (AwradTokensTask). Each parses
 * its contract strictly, failing on anything it can't express in Kotlin, and renders one committed source file.
 */

/** A `Dp` literal for a contract number: `20.dp`, `0.5.dp`. */
private fun TokenFile.dp(what: String, value: Any?): String = float(this, what, value).removeSuffix("f") + ".dp"

private fun TokenFile.sp(what: String, value: Any?): String = float(this, what, value).removeSuffix("f") + ".sp"

private fun TokenFile.number(what: String, value: Any?): String = float(this, what, value).removeSuffix("f")

internal object ShapeTokens {
    /** A scale step: its Kotlin name and radius, null for `full`. */
    class Step(val name: String, val radius: Any?)

    class Role(val name: String, val step: Step, val use: String)

    /** A line the design allows: its width and, for a ring drawn outside the element, its offset. */
    class Stroke(val name: String, val width: Any?, val offset: Any?, val use: String)

    class Parsed(
        val file: TokenFile,
        val continuous: Boolean,
        val scale: List<Step>,
        val roles: List<Role>,
        val strokes: List<Stroke>,
    ) {
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
        return Parsed(file, continuous, scale, roles, parseStrokes(file))
    }

    private val STROKE_KEYS = setOf("width", "offset", "use")

    private fun parseStrokes(file: TokenFile): List<Stroke> {
        @Suppress("UNCHECKED_CAST")
        val strokes = file.obj("strokes").map { (name, value) ->
            val stroke = value as? Map<String, Any?> ?: file.fail("strokes.$name must be an object")
            (stroke.keys - STROKE_KEYS).firstOrNull()?.let {
                file.fail("strokes.$name.$it isn't supported on Android yet")
            }
            val width = stroke["width"].also { file.dp("strokes.$name.width", it) }
            val offset = stroke["offset"]?.also { file.dp("strokes.$name.offset", it) }
            Stroke(identifier(file, name), width, offset, string(file, "strokes.$name.use", stroke["use"]))
        }
        val names = strokes.flatMap { listOfNotNull(it.name, it.offset?.let { _ -> "${it.name}Offset" }) }
        names.groupBy { it }.filterValues { it.size > 1 }.keys.firstOrNull()?.let { file.fail("strokes: '$it' twice") }
        return strokes
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
        appendStrokes(shapes)
        appendLine()
        if (shapes.continuous) {
            appendLine("/** `corners: continuous`. */")
            appendLine("private const val CornerSmoothing: Float = SmoothCornerShape.CONTINUOUS")
        } else {
            appendLine("/** `corners: circular`. */")
            appendLine("private const val CornerSmoothing: Float = 0f")
        }
    }

    private fun StringBuilder.appendStrokes(shapes: Parsed) {
        val file = shapes.file
        appendLine("/**")
        appendLine(" * Line widths: every line the design allows, since it's built from filled shapes. Read them through")
        appendLine(" * `AwradTheme.strokes`.")
        appendLine(" */")
        appendLine("public object AwradStrokes {")
        shapes.strokes.forEachIndexed { index, stroke ->
            val path = "strokes.${stroke.name}"
            if (index > 0) appendLine()
            appendDoc("    ", "${stroke.use}: ${file.number("$path.width", stroke.width)}.")
            appendLine("    public val ${stroke.name}: Dp = ${file.dp("$path.width", stroke.width)}")
            if (stroke.offset != null) {
                appendLine()
                val offset = file.number("$path.offset", stroke.offset)
                appendDoc("    ", "How far `${stroke.name}` is drawn outside the element's edge: $offset.")
                appendLine("    public val ${stroke.name}Offset: Dp = ${file.dp("$path.offset", stroke.offset)}")
            }
        }
        appendLine("}")
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
        val fontFamily: String,
        val size: String,
        val lineHeight: String,
        val weight: String,
        val letterSpacing: String,
        val tabularNumbers: Boolean,
        val doc: String,
    )

    class Parsed(val styles: List<Style>)

    private val WEIGHTS = mapOf(400 to "Normal", 500 to "Medium", 600 to "SemiBold", 700 to "Bold")
    private val KEYS = setOf(
        "size",
        "lineHeight",
        "weight",
        "iosTextStyle",
        "tabularNumbers",
        "tracking",
        "fontFamily",
        "use",
    )

    /** The `FontFamily` value bundling the contract's [family], at [path]. */
    private fun fontFamily(file: TokenFile, path: String, family: Any?, fontFamilies: Map<String, String>): String {
        val name = string(file, path, family)
        return fontFamilies[name]
            ?: file.fail("$path '$name' isn't bundled in :core:designsystem (known: ${fontFamilies.keys})")
    }

    fun parse(file: TokenFile, fontFamilies: Map<String, String>): Parsed {
        val interfaceFamily = fontFamily(file, "fontFamily", file.json["fontFamily"], fontFamilies)
        @Suppress("UNCHECKED_CAST")
        val styles = file.obj("styles").map { (name, style) ->
            style as Map<String, Any?>
            (style.keys - KEYS).firstOrNull()?.let { file.fail("styles.$name.$it isn't supported on Android yet") }
            // A style with its own family (`quran`) overrides the interface font.
            val ownFamily = style["fontFamily"]?.let { string(file, "styles.$name.fontFamily", it) }
            val family = ownFamily?.let { fontFamily(file, "styles.$name.fontFamily", it, fontFamilies) }
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
                fontFamily = family ?: interfaceFamily,
                size = file.sp("styles.$name.size", style["size"]),
                lineHeight = file.sp("styles.$name.lineHeight", style["lineHeight"]),
                weight = weight,
                // `tracking` is in points on iOS, which are sp here.
                letterSpacing = file.sp("styles.$name.tracking", style["tracking"] ?: 0),
                tabularNumbers = tabular,
                doc = sentence(string(file, "styles.$name.use", style["use"])) +
                    (ownFamily?.let { " $it," } ?: "") +
                    " $size on $lineHeight, weight $weightValue" + (if (tabular) ", tabular numbers." else "."),
            )
        }
        return Parsed(styles)
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
        appendLine(" * The named text styles, in the interface font unless a style names its own. Read them through")
        appendLine(" * `AwradTheme.type`; Material's `Typography` maps onto them in `AwradTypography`.")
        appendLine(" */")
        appendLine("public object AwradType {")
        type.styles.forEachIndexed { index, style ->
            if (index > 0) appendLine()
            appendDoc("    ", style.doc)
            appendLine("    public val ${style.name}: TextStyle = TextStyle(")
            appendLine("        fontFamily = ${style.fontFamily},")
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
