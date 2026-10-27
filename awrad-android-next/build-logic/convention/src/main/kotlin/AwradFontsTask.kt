import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction
import java.io.File
import java.security.MessageDigest

/**
 * Fails when the bundled fonts ([fontDirectory], `res/font/`) aren't exactly the shared ones: the files listed in
 * the contract's `SHA256SUMS` ([checksums]), with the same names and the same SHA-256. A missing, extra or
 * modified font file fails, so the app can't drift from `contracts/design-tokens/v1/fonts/`.
 */
abstract class AwradFontsTask : DefaultTask() {

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val checksums: RegularFileProperty

    @get:InputDirectory
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val fontDirectory: DirectoryProperty

    @TaskAction
    fun run() {
        val sumsFile = checksums.get().asFile
        val expected = parse(sumsFile)
        val bundled = fontDirectory.get().asFile.listFiles { file -> file.extension == "ttf" || file.extension == "otf" }
            .orEmpty()
            .associateBy { it.name }

        val problems = buildList {
            (expected.keys - bundled.keys).sorted().forEach { add("missing: $it") }
            (bundled.keys - expected.keys).sorted().forEach { add("not in the contract: $it") }
            expected.keys.intersect(bundled.keys).sorted().forEach { name ->
                if (sha256(bundled.getValue(name)) != expected.getValue(name)) add("differs from the contract: $name")
            }
        }
        if (problems.isNotEmpty()) {
            val contractDirectory = sumsFile.parentFile
            throw GradleException(
                "Bundled fonts in ${fontDirectory.get().asFile.path} don't match ${sumsFile.path}:\n" +
                    problems.joinToString("\n") { "  - $it" } +
                    "\nCopy them from ${contractDirectory.path} (same file names).",
            )
        }
    }

    /** `shasum -a 256` output: `<hex>  <name>` per line. */
    private fun parse(file: File): Map<String, String> = file.readLines()
        .filter { it.isNotBlank() }
        .associate { line ->
            val match = LINE.matchEntire(line.trim())
                ?: throw GradleException("${file.path}: can't read line '$line'")
            match.groupValues[2] to match.groupValues[1].lowercase()
        }
        .also { if (it.isEmpty()) throw GradleException("${file.path} lists no fonts") }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private companion object {
        val LINE = Regex("""([0-9a-fA-F]{64}) [ *](\S+)""")
        const val BUFFER_SIZE = 64 * 1024
    }
}
