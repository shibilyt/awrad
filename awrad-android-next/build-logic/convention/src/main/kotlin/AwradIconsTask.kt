import groovy.json.JsonSlurper
import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.Property
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.Internal
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction
import java.io.File

/**
 * Bundles the shared icons (`contracts/design-tokens/v1/icons.json` and the SVGs in `icons/`) into `:core:designsystem`
 * as committed sources, the way [AwradTokensTask] bundles the other tokens:
 *
 * - one vector drawable per icon in [drawableDirectory], `awrad_ic_<name>.xml` (`autoMirrored` where the contract
 *   sets `mirrorInRtl`);
 * - [source]: `AwradIcons`, a typed `ImageVector` accessor per icon (`AwradIcons.Home`).
 *
 * With [verifyOnly] false it (re)writes them and deletes `awrad_ic_*` drawables the contract no longer names.
 * With [verifyOnly] true it fails when any file isn't exactly what the contract generates, or a stale
 * `awrad_ic_*` drawable is left. An unknown key in `icons.json`, or an SVG that isn't a plain path-only file
 * ([SvgIcons]), fails generation instead of being dropped.
 */
abstract class AwradIconsTask : DefaultTask() {

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val contract: RegularFileProperty

    /** `icons/`, next to [contract]. */
    @get:InputDirectory
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val svgDirectory: DirectoryProperty

    /** `res/drawable/`: only the `awrad_ic_*` files in it are this task's. */
    @get:Internal
    abstract val drawableDirectory: DirectoryProperty

    @get:Internal
    abstract val source: RegularFileProperty

    @get:Input
    abstract val packageName: Property<String>

    /** The module's namespace, for `R.drawable`. */
    @get:Input
    abstract val resourcePackage: Property<String>

    @get:Input
    abstract val verifyOnly: Property<Boolean>

    @get:Input
    abstract val regenerateCommand: Property<String>

    @TaskAction
    fun run() {
        val contractFile = contract.get().asFile
        @Suppress("UNCHECKED_CAST")
        val json = JsonSlurper().parseText(contractFile.readText()) as Map<String, Any?>
        val expected = AwradIconFiles.render(
            contract = TokenFile(contractFile.name, json),
            svgDirectory = svgDirectory.get().asFile,
            renderer = IconRenderer(regenerateCommand.get()),
            packageName = packageName.get(),
            resourcePackage = resourcePackage.get(),
        )
        val drawables = drawableDirectory.get().asFile
        val files = expected.drawables.mapKeys { (name, _) -> drawables.resolve("$name.xml") } +
            (source.get().asFile to expected.kotlin)
        val stale = AwradIconFiles.generatedDrawables(drawables) - files.keys
        if (!verifyOnly.get()) {
            files.forEach { (file, text) ->
                file.parentFile.mkdirs()
                file.writeText(text)
            }
            stale.forEach { it.delete() }
            return
        }
        val problems = files.filter { (file, text) -> !file.isFile || file.readText() != text }.keys
            .map { "  - ${it.path}" } +
            stale.map { "  - ${it.path} (not in the contract)" }
        if (problems.isNotEmpty()) {
            throw GradleException(
                "Out of date with ${contractFile.path}:\n" + problems.joinToString("\n") +
                    "\nRegenerate them with: ${regenerateCommand.get()}",
            )
        }
    }
}

/** What [AwradIconsTask] writes, without Gradle: the drawables by resource name, and `AwradIcons.kt`. */
internal object AwradIconFiles {
    class Expected(val drawables: Map<String, String>, val kotlin: String)

    fun render(
        contract: TokenFile,
        svgDirectory: File,
        renderer: IconRenderer,
        packageName: String,
        resourcePackage: String,
    ): Expected {
        val icons = IconContract.parse(contract)
        val drawables = icons.associate { icon ->
            val svgFile = svgDirectory.resolve(icon.file)
            if (!svgFile.isFile) contract.fail("icon '${icon.name}': ${icon.file} isn't in ${svgDirectory.path}")
            val svg = SvgIcons.parse(contract, icon.file, svgFile.readText())
            icon.drawableName to renderer.drawable(icon, svg)
        }
        return Expected(drawables, renderer.kotlin(icons, packageName, resourcePackage))
    }

    /** The `awrad_ic_*.xml` files in [directory]: everything this generator owns there. */
    fun generatedDrawables(directory: File): Set<File> = directory
        .listFiles { file -> file.name.startsWith("awrad_ic_") && file.extension == "xml" }
        .orEmpty()
        .toSet()
}
