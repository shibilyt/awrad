import org.w3c.dom.Element
import org.w3c.dom.Node
import org.xml.sax.InputSource
import java.io.StringReader
import javax.xml.parsers.DocumentBuilderFactory

/** One icon in `icons.json`: its [name] (the key screens use), its SVG [file], what it's for, and RTL mirroring. */
internal class IconSpec(val name: String, val file: String, val use: String, val mirrorInRtl: Boolean) {
    /** `awrad_ic_<name>`, the name in snake case: `home` → `awrad_ic_home`. */
    val drawableName: String = "awrad_ic_" + name.replace(Regex("[A-Z]")) { "_" + it.value.lowercase() }

    /** The Kotlin accessor: `home` → `AwradIcons.Home`. */
    val propertyName: String = TokenText.typeName(name)
}

/** A path-only SVG: its size in px (dp on Android), its view box, and each path's `d`, as written. */
internal class SvgIcon(val width: String, val height: String, val viewBox: List<String>, val paths: List<String>)

/** Reads `icons.json` and its SVGs, failing on anything it would otherwise have to drop or guess. */
internal object IconContract {
    private val NAME = Regex("[a-z][A-Za-z]*")
    private val FILE = Regex("[a-z_]+\\.svg")
    private val ENTRY_KEYS = setOf("file", "use", "mirrorInRtl")

    fun parse(contract: TokenFile): List<IconSpec> {
        contract.requireKeys("source", "icons")
        if (contract.json["version"] != 1) contract.fail("version must be 1, was ${contract.json["version"]}")
        val icons = contract.obj("icons")
        if (icons.isEmpty()) contract.fail("'icons' lists no icons")
        return icons.map { (name, value) ->
            if (!NAME.matches(name)) contract.fail("icon '$name' must be lowerCamelCase letters")
            @Suppress("UNCHECKED_CAST")
            val entry = value as? Map<String, Any?> ?: contract.fail("icon '$name' must be an object")
            (entry.keys - ENTRY_KEYS).firstOrNull()?.let { contract.fail("icon '$name': '$it' isn't supported") }
            (ENTRY_KEYS - entry.keys).firstOrNull()?.let { contract.fail("icon '$name': '$it' is missing") }
            val file = TokenText.string(contract, "icon '$name' file", entry["file"])
            if (!FILE.matches(file)) contract.fail("icon '$name': '$file' isn't a lower_snake_case .svg name")
            val mirror = entry["mirrorInRtl"] as? Boolean
                ?: contract.fail("icon '$name': mirrorInRtl must be true or false")
            IconSpec(name, file, TokenText.string(contract, "icon '$name' use", entry["use"]), mirror)
        }
    }
}

/**
 * Parses the contract's SVGs: an `svg` root with only `xmlns`, `width`, `height` and `viewBox`, holding only
 * `path` elements with only a `d`. Anything else (a fill, a transform, a group, a stroke, a fill rule, another
 * shape) fails: the drawable couldn't reproduce it faithfully, and the README promises path-only files.
 */
internal object SvgIcons {
    private val ROOT_ATTRIBUTES = setOf("xmlns", "width", "height", "viewBox")
    private val NUMBER = Regex("-?(\\d+(\\.\\d*)?|\\.\\d+)")
    private val PATH_DATA = Regex("[MmLlHhVvCcSsQqTtAaZz0-9.,+\\-eE\\s]+")

    fun parse(file: TokenFile, svgName: String, text: String): SvgIcon {
        fun fail(message: String): Nothing = file.fail("$svgName: $message")
        val root = read(text) { fail("isn't well-formed XML (${it.message})") }
        if (root.tagName != "svg") fail("the root element must be <svg>, was <${root.tagName}>")
        attributeNames(root).firstOrNull { it !in ROOT_ATTRIBUTES }?.let { fail("<svg $it> isn't supported") }
        val width = number(root, "width", ::fail)
        val height = number(root, "height", ::fail)
        val viewBox = root.getAttribute("viewBox").trim().split(Regex("[\\s,]+"))
        if (viewBox.size != 4 || viewBox.any { !NUMBER.matches(it) }) fail("viewBox must be four numbers")
        if (viewBox[2].startsWith("-") || viewBox[3].startsWith("-")) fail("viewBox can't have a negative size")
        val paths = buildList {
            val children = root.childNodes
            for (index in 0 until children.length) {
                val child = children.item(index)
                when {
                    child.nodeType == Node.ELEMENT_NODE -> add(path(child as Element, ::fail))
                    child.nodeType == Node.TEXT_NODE && child.textContent.isBlank() -> Unit
                    child.nodeType == Node.COMMENT_NODE -> Unit
                    else -> fail("only <path> elements are supported inside <svg>")
                }
            }
        }
        if (paths.isEmpty()) fail("has no <path>")
        return SvgIcon(width, height, viewBox, paths)
    }

    private fun path(element: Element, fail: (String) -> Nothing): String {
        if (element.tagName != "path") fail("<${element.tagName}> isn't supported; only <path>")
        attributeNames(element).firstOrNull { it != "d" }?.let { fail("<path $it> isn't supported; only d") }
        if (element.hasChildNodes()) fail("<path> can't have content")
        val data = element.getAttribute("d").trim()
        if (data.isEmpty() || !PATH_DATA.matches(data)) fail("a path's d isn't plain path data")
        return data
    }

    private fun number(root: Element, name: String, fail: (String) -> Nothing): String {
        val value = root.getAttribute(name).trim()
        if (!NUMBER.matches(value) || value.startsWith("-")) fail("$name must be a number of px, was '$value'")
        return value
    }

    private fun attributeNames(element: Element): List<String> =
        (0 until element.attributes.length).map { element.attributes.item(it).nodeName }

    private fun read(text: String, fail: (Exception) -> Nothing): Element {
        val factory = DocumentBuilderFactory.newInstance().apply {
            // The SVGs are data: no DTDs, so no external entities.
            setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
            isNamespaceAware = false
        }
        return try {
            factory.newDocumentBuilder().parse(InputSource(StringReader(text))).documentElement
        } catch (exception: org.xml.sax.SAXException) {
            fail(exception)
        }
    }
}

/** Renders the icons as Android vector drawables and the `AwradIcons` accessors. */
internal class IconRenderer(private val regenerateCommand: String) {

    /**
     * A vector drawable drawing [svg]'s paths: the same size in dp, the view box as the viewport, and a group that
     * moves the view box's origin to 0 (Material Symbols use `0 -960 960 960`), so the path data stays exactly
     * the SVG's. The fill is a placeholder: every icon is tinted by its component. [IconSpec.mirrorInRtl] sets
     * `autoMirrored`.
     */
    fun drawable(icon: IconSpec, svg: SvgIcon): String = buildString {
        appendLine("""<?xml version="1.0" encoding="utf-8"?>""")
        appendLine("<!--")
        appendLine("  Generated from contracts/design-tokens/v1/icons/${icon.file} (\"${icon.name}\" in icons.json).")
        appendLine("  Don't edit by hand: regenerate with `$regenerateCommand`.")
        appendLine("  `verifyAwradIcons` fails the build when this file and the contract differ.")
        appendLine("-->")
        appendLine("""<vector xmlns:android="http://schemas.android.com/apk/res/android"""")
        appendLine("""    android:width="${svg.width}dp"""")
        appendLine("""    android:height="${svg.height}dp"""")
        if (icon.mirrorInRtl) appendLine("""    android:autoMirrored="true"""")
        appendLine("""    android:viewportWidth="${svg.viewBox[2]}"""")
        appendLine("""    android:viewportHeight="${svg.viewBox[3]}">""")
        val translateX = negate(svg.viewBox[0])
        val translateY = negate(svg.viewBox[1])
        val grouped = translateX != "0" || translateY != "0"
        val indent = if (grouped) "        " else "    "
        if (grouped) {
            append("    <group")
            if (translateX != "0") append(""" android:translateX="$translateX"""")
            if (translateY != "0") append(""" android:translateY="$translateY"""")
            appendLine(">")
        }
        svg.paths.forEach { data ->
            appendLine("$indent<path")
            appendLine("""$indent    android:fillColor="@android:color/black"""")
            appendLine("""$indent    android:pathData="$data" />""")
        }
        if (grouped) appendLine("    </group>")
        appendLine("</vector>")
    }

    /** `AwradIcons`: one `@Composable` [ImageVector] accessor per icon, in the contract's order, and `all`. */
    fun kotlin(icons: List<IconSpec>, packageName: String, resourcePackage: String): String = buildString {
        appendLine("// Generated from contracts/design-tokens/v1/icons.json. Don't edit by hand:")
        appendLine("// regenerate with `$regenerateCommand`. `verifyAwradIcons` fails the")
        appendLine("// build when this file, the awrad_ic_* drawables and the contract differ.")
        appendLine()
        appendLine("package $packageName")
        appendLine()
        appendLine("import androidx.compose.runtime.Composable")
        appendLine("import androidx.compose.ui.graphics.vector.ImageVector")
        appendLine("import androidx.compose.ui.res.vectorResource")
        appendLine("import $resourcePackage.R")
        appendLine()
        with(TokenText) {
            appendDoc(
                "",
                "The shared icons (contracts/design-tokens/v1/icons.json): Material Symbols Rounded, outline, " +
                    "weight 300. Use one by name; never a platform icon set. The colour comes from the component " +
                    "(`Icon`'s tint). Icons marked as mirrored flip in right-to-left layouts (`autoMirrored`).",
            )
        }
        appendLine("public object AwradIcons {")
        icons.forEach { icon ->
            val mirror = if (icon.mirrorInRtl) " Flips in right-to-left layouts." else ""
            with(TokenText) { appendDoc("    ", sentence(icon.use) + mirror) }
            appendLine("    public val ${icon.propertyName}: ImageVector")
            appendLine("        @Composable get() = ImageVector.vectorResource(R.drawable.${icon.drawableName})")
            appendLine()
        }
        appendLine("    /** Every icon by its name in icons.json, in the contract's order (the component gallery). */")
        appendLine("    public val all: List<Pair<String, ImageVector>>")
        appendLine("        @Composable get() = listOf(")
        icons.forEach { appendLine("            \"${it.name}\" to ${it.propertyName},") }
        appendLine("        )")
        appendLine("}")
    }

    private fun negate(number: String): String =
        java.math.BigDecimal(number).negate().stripTrailingZeros().toPlainString()
}
