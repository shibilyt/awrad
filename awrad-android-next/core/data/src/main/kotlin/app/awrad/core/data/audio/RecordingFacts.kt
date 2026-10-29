package app.awrad.core.data.audio

import android.media.MediaMetadataRetriever
import app.awrad.core.domain.audio.AudioContentType
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.security.MessageDigest

/** What an upload declares about a recording's file: its SHA-256 (64 lowercase hex digits), size and type. */
internal data class RecordingFacts(
    val sha256: String,
    val byteSize: Long,
    val contentType: String,
    val durationMs: Long?,
)

/** Measures a recording's length, or null when it can't (the server never decodes audio, so this is display only). */
internal fun interface DurationProbe {
    fun durationMs(file: File): Long?
}

/** [DurationProbe] with Android's [MediaMetadataRetriever]. */
internal class MediaDurationProbe : DurationProbe {
    override fun durationMs(file: File): Long? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.path)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()?.takeIf { it > 0 }
        } catch (_: IllegalArgumentException) {
            null
        } catch (_: IllegalStateException) {
            null
        } finally {
            runCatching { retriever.release() }
        }
    }
}

internal object RecordingFiles {

    private const val BUFFER_SIZE = 64 * 1024

    /**
     * The facts of [file], or null when it can't be read. The type comes from the extension the import gave it
     * (contracts/audio/v1/README.md, "Media types on import"): `.mp3` is `audio/mpeg` and `.m4a` is `audio/mp4`.
     * Imports take nothing else now; a raw `.aac` stream imported before that isn't an M4A container, so it keeps
     * `audio/aac`, which the upload rules refuse.
     */
    fun measure(file: File, probe: DurationProbe): RecordingFacts? = try {
        val digest = MessageDigest.getInstance("SHA-256")
        val size = file.inputStream().use { digestInto(digest, it) }
        RecordingFacts(
            sha256 = digest.digest().joinToString("") { "%02x".format(it) },
            byteSize = size,
            contentType = contentTypeOf(file),
            durationMs = probe.durationMs(file),
        )
    } catch (_: IOException) {
        null
    }

    /** Feeds all of [input] to [digest]; returns how many bytes it read. */
    private fun digestInto(digest: MessageDigest, input: InputStream): Long {
        val buffer = ByteArray(BUFFER_SIZE)
        var size = 0L
        var read = input.read(buffer)
        while (read >= 0) {
            digest.update(buffer, 0, read)
            size += read
            read = input.read(buffer)
        }
        return size
    }

    fun contentTypeOf(file: File): String = when (file.extension.lowercase()) {
        "mp3" -> AudioContentType.MPEG.wire
        "m4a" -> AudioContentType.MP4.wire
        else -> "audio/${file.extension.lowercase()}"
    }

    /** The file name a downloaded recording is cached under in the profile's `audio/` folder. */
    fun cacheName(assetId: String, contentType: AudioContentType): String = when (contentType) {
        AudioContentType.MPEG -> "$assetId.mp3"
        AudioContentType.MP4 -> "$assetId.m4a"
    }
}
