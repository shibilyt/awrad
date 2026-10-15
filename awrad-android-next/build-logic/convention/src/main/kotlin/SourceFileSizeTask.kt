import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.ConfigurableFileCollection
import org.gradle.api.provider.Property
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction

/**
 * Fails when a production Kotlin file grows past [maxLines]. Large files are
 * where policy hides inside UI; split by responsibility before this trips.
 */
abstract class SourceFileSizeTask : DefaultTask() {

    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val sources: ConfigurableFileCollection

    @get:Input
    abstract val maxLines: Property<Int>

    @TaskAction
    fun verify() {
        val limit = maxLines.get()
        val oversized = sources.files
            .filter { it.extension == "kt" }
            .map { it to it.useLines { lines -> lines.count() } }
            .filter { (_, count) -> count > limit }
        if (oversized.isNotEmpty()) {
            throw GradleException(
                "Kotlin files over $limit lines:\n" +
                    oversized.joinToString("\n") { (file, count) -> "  - ${file.path} ($count)" },
            )
        }
    }
}
