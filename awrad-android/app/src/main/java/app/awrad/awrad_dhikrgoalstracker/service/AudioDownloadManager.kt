package app.awrad.awrad_dhikrgoalstracker.service

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

data class DownloadProgress(
    val totalFiles: Int = 0,
    val completedFiles: Int = 0,
    val completedFileNames: Set<String> = emptySet(),
    val currentFileName: String = "",
    val isDownloading: Boolean = false,
    val isComplete: Boolean = false,
    val failedFiles: List<String> = emptyList(),
) {
    val overallProgress: Float
        get() = if (totalFiles == 0) 0f else completedFiles.toFloat() / totalFiles
}

@Singleton
class AudioDownloadManager @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val audioDir: File
        get() = File(context.filesDir, "dhikr_audio").also { it.mkdirs() }

    private val _downloadProgress = MutableStateFlow(DownloadProgress())
    val downloadProgress: StateFlow<DownloadProgress> = _downloadProgress.asStateFlow()

    suspend fun downloadAll(
        files: List<Pair<String, String>>,
        onFileDownloaded: suspend (String) -> Unit = {},
    ): List<String> =
        withContext(Dispatchers.IO) {
            if (files.isEmpty()) return@withContext emptyList()

            val successfulFileNames = mutableListOf<String>()
            val failedFileNames = mutableListOf<String>()

            _downloadProgress.value = DownloadProgress(
                totalFiles = files.size,
                isDownloading = true,
            )

            for ((index, pair) in files.withIndex()) {
                val (url, fileName) = pair
                _downloadProgress.value = _downloadProgress.value.copy(
                    currentFileName = fileName,
                )
                val success = downloadFile(url, fileName)
                if (success) {
                    successfulFileNames.add(fileName)
                    onFileDownloaded(fileName)
                } else {
                    failedFileNames.add(fileName)
                }
                _downloadProgress.value = _downloadProgress.value.copy(
                    completedFiles = index + 1,
                    completedFileNames = successfulFileNames.toSet(),
                    failedFiles = failedFileNames.toList(),
                )
            }

            _downloadProgress.value = _downloadProgress.value.copy(
                isDownloading = false,
                isComplete = true,
                currentFileName = "",
            )

            successfulFileNames
        }

    private fun downloadFile(urlString: String, fileName: String): Boolean {
        val url = AudioDownloadSecurity.validatedAudioUrl(urlString) ?: return false
        val outputFile = AudioDownloadSecurity.resolveOutputFile(audioDir, fileName) ?: return false
        var connection: HttpURLConnection? = null
        return try {
            connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.instanceFollowRedirects = false
            connection.connect()

            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                return false
            }
            if (!AudioDownloadSecurity.isAllowedContentLength(connection.contentLengthLong)) {
                return false
            }
            if (!AudioDownloadSecurity.isAllowedContentType(connection.contentType)) {
                return false
            }

            connection.inputStream.use { input ->
                FileOutputStream(outputFile).use { output ->
                    AudioDownloadSecurity.copyWithLimit(input, output)
                }
            }
            true
        } catch (_: Exception) {
            outputFile.delete()
            false
        } finally {
            connection?.disconnect()
        }
    }

    suspend fun downloadSingle(url: String, fileName: String): Boolean =
        withContext(Dispatchers.IO) {
            downloadFile(url, fileName)
        }

    fun getAudioFilePath(fileName: String): String? {
        val file = AudioDownloadSecurity.resolveOutputFile(audioDir, fileName) ?: return null
        return if (file.exists()) file.absolutePath else null
    }

    fun isFileDownloaded(fileName: String): Boolean =
        AudioDownloadSecurity.resolveOutputFile(audioDir, fileName)?.exists() == true

    fun resetProgress() {
        _downloadProgress.value = DownloadProgress()
    }
}

internal object AudioDownloadSecurity {
    const val MAX_AUDIO_BYTES: Long = 25L * 1024L * 1024L

    private val allowedHosts = setOf("dhikrs.awrad.app")
    private val allowedContentTypes = setOf(
        "audio/aac",
        "audio/mp4",
        "audio/mpeg",
        "audio/ogg",
        "audio/wav",
        "audio/webm",
        "audio/x-wav",
    )
    private val safeFileName = Regex("""[A-Za-z0-9._-]+""")

    fun validatedAudioUrl(urlString: String): URL? =
        runCatching { URL(urlString) }
            .getOrNull()
            ?.takeIf { it.protocol.equals("https", ignoreCase = true) }
            ?.takeIf { it.host.lowercase(Locale.US) in allowedHosts }

    fun resolveOutputFile(audioDir: File, fileName: String): File? {
        if (!safeFileName.matches(fileName)) return null
        val canonicalDir = audioDir.canonicalFile
        val outputFile = File(canonicalDir, fileName).canonicalFile
        return outputFile.takeIf { it.parentFile == canonicalDir }
    }

    fun isAllowedContentLength(contentLength: Long): Boolean =
        contentLength <= 0L || contentLength <= MAX_AUDIO_BYTES

    fun isAllowedContentType(contentType: String?): Boolean {
        if (contentType.isNullOrBlank()) return true
        val normalized = contentType.substringBefore(';').trim().lowercase(Locale.US)
        return normalized in allowedContentTypes
    }

    @Throws(IOException::class)
    fun copyWithLimit(
        input: InputStream,
        output: OutputStream,
        maxBytes: Long = MAX_AUDIO_BYTES,
    ): Long {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var total = 0L
        while (true) {
            val read = input.read(buffer)
            if (read == -1) return total
            total += read
            if (total > maxBytes) {
                throw IOException("Audio download exceeded $maxBytes bytes")
            }
            output.write(buffer, 0, read)
        }
    }
}
