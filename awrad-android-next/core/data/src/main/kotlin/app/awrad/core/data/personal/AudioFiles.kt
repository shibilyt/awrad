package app.awrad.core.data.personal

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.net.toUri
import app.awrad.core.domain.personal.AudioImport
import app.awrad.core.domain.personal.AudioImportError
import app.awrad.core.domain.personal.CustomDhikrRepository
import java.io.File
import java.io.IOException
import java.io.InputStream

/**
 * Custom dhikr recordings, kept in the profile's private files (`audio/` under its directory). Imports accept only
 * an `.mp3` (`audio/mpeg`) or an `.m4a` (`audio/mp4`, or `audio/x-m4a` as some systems report it) up to 10 MB
 * (contracts/audio/v1/README.md, "Phones"); anything else, a raw `.aac` stream included, is refused, so it never
 * becomes a recording that can't upload.
 */
internal class AudioFiles(private val resolver: ContentResolver) {

    /**
     * Copies [source] into [profileDir]'s audio folder under a new [name], checking its type and size. A partial
     * copy is deleted.
     */
    fun import(source: String, profileDir: File, name: String): AudioImport {
        val uri = source.toUri()
        val extension = importExtension(resolver.getType(uri), nameOf(uri))
            ?: return AudioImport.Failed(AudioImportError.UNSUPPORTED_TYPE)
        val target = File(File(profileDir, AUDIO_DIR).apply { mkdirs() }, "$name.$extension")
        val error = try {
            val input = resolver.openInputStream(uri)
            when {
                input == null -> AudioImportError.UNREADABLE
                input.use { copyAtMost(it, target, CustomDhikrRepository.MAX_AUDIO_BYTES) } -> null
                else -> AudioImportError.TOO_LARGE
            }
        } catch (_: IOException) {
            AudioImportError.UNREADABLE
        } catch (_: SecurityException) {
            AudioImportError.UNREADABLE
        }
        if (error != null) target.delete()
        return error?.let(AudioImport::Failed) ?: AudioImport.Imported(target.toUri().toString())
    }

    /** The file path of a recording's [localUri] (`file://…`), or null when it isn't a local file. */
    fun pathOf(localUri: String): String? = localUri.toUri().takeIf { it.scheme == "file" }?.path

    /** The `file://` URI of the recording at [path]. */
    fun uriOf(path: String): String = File(path).toUri().toString()

    /** The picked file's display name, or the URI's last segment when the provider has none. */
    private fun nameOf(uri: Uri): String? {
        val displayName = try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (_: SecurityException) {
            null
        } catch (_: IllegalArgumentException) {
            null
        }
        return displayName ?: uri.lastPathSegment
    }

    /** Copies [input] to [target]; false (and nothing more read) once it passes [limit] bytes. */
    private fun copyAtMost(input: InputStream, target: File, limit: Long): Boolean {
        var total = 0L
        target.outputStream().use { output ->
            val buffer = ByteArray(BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) return true
                total += read
                if (total > limit) return false
                output.write(buffer, 0, read)
            }
        }
    }

    companion object {
        private const val AUDIO_DIR = "audio"
        private const val BUFFER_SIZE = 64 * 1024

        /** By the file's name: an `.mp3` is MP3, an `.m4a` is M4A. */
        private val EXTENSIONS = setOf("mp3", "m4a")

        /** By the type the system reports, when the name has no extension. */
        private val SYSTEM_TYPES = mapOf("audio/mpeg" to "mp3", "audio/mp4" to "m4a", "audio/x-m4a" to "m4a")

        /**
         * The extension an import is kept under (`mp3` or `m4a`): the file [name]'s own when it has one, else the
         * one for the [type] the system reports. Null refuses the import: any other extension (`.aac`, `.wav`…),
         * or no extension and another type.
         */
        fun importExtension(type: String?, name: String?): String? {
            val extension = name?.substringAfterLast('.', "")?.lowercase().orEmpty()
            if (extension.isNotEmpty()) return extension.takeIf { it in EXTENSIONS }
            return type?.substringBefore(';')?.trim()?.lowercase()?.let(SYSTEM_TYPES::get)
        }
    }
}
