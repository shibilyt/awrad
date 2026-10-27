import groovy.json.JsonSlurper
import org.gradle.api.GradleException
import org.gradle.testfixtures.ProjectBuilder
import java.io.File
import java.nio.file.Files
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class AwradIconsTest {

    private val renderer = IconRenderer("./gradlew generate")

    @Test
    fun `a mirrored icon is autoMirrored and the others are not`() {
        val icons = IconContract.parse(contract(icon("back", "chevron_left.svg", mirror = true), icon("add", "add.svg")))

        val back = renderer.drawable(icons[0], SvgIcons.parse(FILE, "chevron_left.svg", SVG))
        val add = renderer.drawable(icons[1], SvgIcons.parse(FILE, "add.svg", SVG))

        assertContains(back, """android:autoMirrored="true"""")
        assertFalse(add.contains("autoMirrored"))
    }

    @Test
    fun `the view box origin moves to zero and the path data is the SVG's`() {
        val drawable = renderer.drawable(IconSpec("add", "add.svg", "Add", mirrorInRtl = false), SvgIcons.parse(FILE, "add.svg", SVG))

        assertContains(drawable, """android:width="24dp"""")
        assertContains(drawable, """android:viewportWidth="960"""")
        assertContains(drawable, """android:viewportHeight="960"""")
        assertContains(drawable, """<group android:translateY="960">""")
        assertContains(drawable, """android:pathData="$PATH" />""")
    }

    @Test
    fun `a view box at the origin needs no group`() {
        val svg = SVG.replace("0 -960 960 960", "0 0 24 24")

        val drawable = renderer.drawable(IconSpec("add", "add.svg", "Add", mirrorInRtl = false), SvgIcons.parse(FILE, "add.svg", svg))

        assertFalse(drawable.contains("<group"))
    }

    @Test
    fun `names become drawables and accessors`() {
        val icon = IconSpec("arrowForward", "arrow_forward.svg", "Arrow", mirrorInRtl = true)

        assertEquals("awrad_ic_arrow_forward", icon.drawableName)
        assertEquals("ArrowForward", icon.propertyName)
        val kotlin = renderer.kotlin(listOf(icon), "app.icons", "app")
        assertContains(kotlin, "public val ArrowForward: ImageVector")
        assertContains(kotlin, "ImageVector.vectorResource(R.drawable.awrad_ic_arrow_forward)")
        assertContains(kotlin, "Flips in right-to-left layouts.")
        assertContains(kotlin, "\"arrowForward\" to ArrowForward,")
    }

    @Test
    fun `an unknown top-level key fails`() {
        val failure = assertFailsWith<GradleException> {
            IconContract.parse(contract(icon("add", "add.svg"), extra = """"sizes": {},"""))
        }
        assertContains(failure.message.orEmpty(), "'sizes'")
    }

    @Test
    fun `an unknown key in an icon fails`() {
        val failure = assertFailsWith<GradleException> {
            IconContract.parse(contract(""""add": {"file": "add.svg", "use": "Add", "mirrorInRtl": false, "filled": true}"""))
        }
        assertContains(failure.message.orEmpty(), "'filled'")
    }

    @Test
    fun `a missing mirrorInRtl fails`() {
        val failure = assertFailsWith<GradleException> {
            IconContract.parse(contract(""""add": {"file": "add.svg", "use": "Add"}"""))
        }
        assertContains(failure.message.orEmpty(), "'mirrorInRtl'")
    }

    @Test
    fun `a name that isn't lowerCamelCase fails`() {
        assertFailsWith<GradleException> { IconContract.parse(contract(icon("arrow_forward", "arrow_forward.svg"))) }
    }

    @Test
    fun `an SVG with anything but plain paths fails`() {
        val unsupported = listOf(
            SVG.replace("<path d=", """<path fill-rule="evenodd" d="""),
            SVG.replace("<path d=", """<path transform="scale(2)" d="""),
            SVG.replace("<svg ", """<svg fill="red" """),
            SVG.replace("</svg>", """<circle cx="1" cy="1" r="1"/></svg>"""),
            SVG.replace("<path d=\"$PATH\"/>", "<g><path d=\"$PATH\"/></g>"),
            SVG.replace(PATH, "url(#a)"),
            SVG.replace("""<path d="$PATH"/>""", ""),
            SVG.replace("0 -960 960 960", "0 -960 960"),
        )
        unsupported.forEach { svg ->
            assertFailsWith<GradleException>(svg) { SvgIcons.parse(FILE, "add.svg", svg) }
        }
    }

    @Test
    fun `the shared contract converts`() {
        val directory = generateSequence(File("").absoluteFile) { it.parentFile }
            .map { it.resolve("contracts/design-tokens/v1") }
            .first { it.resolve("icons.json").isFile }
        @Suppress("UNCHECKED_CAST")
        val json = JsonSlurper().parse(directory.resolve("icons.json")) as Map<String, Any?>

        val expected = AwradIconFiles.render(TokenFile("icons.json", json), directory.resolve("icons"), renderer, "app.icons", "app")

        assertEquals(json.let { (it["icons"] as Map<*, *>).size }, expected.drawables.size)
        assertContains(expected.drawables.getValue("awrad_ic_back"), "autoMirrored")
        assertContains(expected.drawables.getValue("awrad_ic_forward"), "autoMirrored")
        assertFalse(expected.drawables.getValue("awrad_ic_home").contains("autoMirrored"))
    }

    @Test
    fun `verification fails on a changed or a stale drawable and passes after generating`() {
        val root = Files.createTempDirectory("awrad-icons").toFile()
        val icons = root.resolve("contract/icons").apply { mkdirs() }
        icons.resolve("add.svg").writeText(SVG)
        val contractFile = root.resolve("contract/icons.json").apply { writeText(contractText(icon("add", "add.svg"))) }
        val drawables = root.resolve("res/drawable")
        val project = ProjectBuilder.builder().withProjectDir(root).build()
        fun task(verify: Boolean) = project.tasks.register("icons${System.nanoTime()}", AwradIconsTask::class.java).get().apply {
            contract.set(contractFile)
            svgDirectory.set(icons)
            drawableDirectory.set(drawables)
            source.set(root.resolve("AwradIcons.kt"))
            packageName.set("app.icons")
            resourcePackage.set("app")
            verifyOnly.set(verify)
            regenerateCommand.set("./gradlew generate")
        }

        assertFailsWith<GradleException> { task(verify = true).run() }
        task(verify = false).run()
        task(verify = true).run()
        assertTrue(drawables.resolve("awrad_ic_add.xml").isFile)

        drawables.resolve("awrad_ic_old.xml").writeText("<vector/>")
        val stale = assertFailsWith<GradleException> { task(verify = true).run() }
        assertContains(stale.message.orEmpty(), "awrad_ic_old.xml (not in the contract)")
        task(verify = false).run()
        assertFalse(drawables.resolve("awrad_ic_old.xml").exists())

        drawables.resolve("awrad_ic_add.xml").appendText(" ")
        assertFailsWith<GradleException> { task(verify = true).run() }
        root.deleteRecursively()
    }

    private companion object {
        val FILE = TokenFile("icons.json", emptyMap())
        const val PATH = "M450-450H250q-12.75 0-21.37-8.63Z"
        const val SVG =
            """<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 -960 960 960" width="24"><path d="$PATH"/></svg>"""
        fun icon(name: String, file: String, mirror: Boolean = false) =
            """"$name": {"file": "$file", "use": "Use", "mirrorInRtl": $mirror}"""

        fun contractText(vararg icons: String, extra: String = "") =
            """{"version": 1, "description": "d", "source": "s", $extra "icons": {${icons.joinToString()}}}"""

        @Suppress("UNCHECKED_CAST")
        fun contract(vararg icons: String, extra: String = ""): TokenFile =
            TokenFile("icons.json", JsonSlurper().parseText(contractText(*icons, extra = extra)) as Map<String, Any?>)
    }
}
