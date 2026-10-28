package app.awrad.core.data.personal

import android.content.ContentResolver
import android.net.Uri
import android.webkit.MimeTypeMap
import androidx.core.net.toUri
import app.awrad.core.domain.personal.AudioImport
import app.awrad.core.domain.personal.AudioImportError
import app.awrad.core.domain.personal.CustomDhikrRepository
import java.io.File
import java.io.IOException
import java.io.InputStream

/**
 * Custom dhikr recordings, kept in the profile's private files (`audio/` under its directory) and never synced in
 * slice 3b. Imports accept MP3 and M4A/AAC up to 10 MB.
 */
internal class AudioFiles(private val resolver: ContentResolver) {

    /**
     * Copies [source] into [profileDir]'s audio folder under a new [name], checking its type and size. A partial
     * copy is deleted.
     */
    fun import(source: String, profileDir: File, name: String): AudioImport {
        val uri = source.toUri()
        val extension = extensionOf(uri) ?: return AudioImport.Failed(AudioImportError.UNSUPPORTED_TYPE)
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

    private fun extensionOf(uri: Uri): String? {
        val type = resolver.getType(uri)?.lowercase()
        val fromType = type?.let { MIME_TYPES[it] }
        val fromName = uri.lastPathSegment?.substringAfterLast('.', "")?.lowercase()?.takeIf { it in EXTENSIONS }
        val fromMap = type?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }?.takeIf { it in EXTENSIONS }
        return fromType ?: fromMap ?: fromName.takeIf { type == null || type == "application/octet-stream" }
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

    private companion object {
        const val AUDIO_DIR = "audio"
        const val BUFFER_SIZE = 64 * 1024
        val MIME_TYPES = mapOf(
            "audio/mpeg" to "mp3",
            "audio/mp3" to "mp3",
            "audio/mp4" to "m4a",
            "audio/x-m4a" to "m4a",
            "audio/m4a" to "m4a",
            "audio/aac" to "aac",
            "audio/aacp" to "aac",
        )
        val EXTENSIONS = setOf("mp3", "m4a", "aac")
    }
}
