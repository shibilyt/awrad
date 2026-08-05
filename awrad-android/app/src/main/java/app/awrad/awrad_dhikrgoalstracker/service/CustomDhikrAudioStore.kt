package app.awrad.awrad_dhikrgoalstracker.service

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import java.io.InputStream
import java.security.DigestInputStream
import java.security.MessageDigest
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

enum class OwnedAudioAvailability {
    AVAILABLE,
    MISSING,
}

data class StagedOwnedAudio(
    val tempFile: File,
    val relativeFileName: String,
    val mimeType: String,
    val byteSize: Long,
    val durationMs: Long,
    val sha256: String,
)

data class OwnedAudioFile(
    val relativeFileName: String,
    val absoluteFile: File,
    val mimeType: String,
    val byteSize: Long,
    val durationMs: Long,
    val sha256: String,
)

data class CustomDhikrAudioProbeResult(
    val mimeType: String,
    val durationMs: Long,
)

fun interface CustomDhikrAudioProbe {
    fun inspect(file: File): CustomDhikrAudioProbeResult
}

class CustomDhikrAudioException(
    val reason: Reason,
    message: String = reason.name,
) : Exception(message) {
    enum class Reason {
        SIZE,
        MIME,
        DURATION,
        CORRUPT,
        IO,
    }
}

@Singleton
class CustomDhikrAudioStore(
    rootDir: File,
) {
    @Inject
    constructor(@ApplicationContext context: Context) : this(File(context.filesDir, ROOT_DIR_NAME))

    private val rootDir: File = rootDir.also { it.mkdirs() }
    private val ownedDir: File = File(this.rootDir, OWNED_DIR_NAME).also { it.mkdirs() }
    private val tmpDir: File = File(this.rootDir, TMP_DIR_NAME).also { it.mkdirs() }

    fun stageImport(
        input: InputStream,
        declaredByteSize: Long,
        mimeType: String?,
        durationMs: Long? = null,
        probe: CustomDhikrAudioProbe,
    ): StagedOwnedAudio {
        if (!CustomDhikrAudioLimits.isMimeTypeAllowed(mimeType)) {
            throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.MIME)
        }
        // declaredByteSize <= 0 means unknown; rely on streaming enforcement.
        if (declaredByteSize > 0L && !CustomDhikrAudioLimits.isByteSizeAllowed(declaredByteSize)) {
            throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.SIZE)
        }

        val assetId = UUID.randomUUID().toString()
        val relativeFileName = "$assetId.${extensionForMime(mimeType!!)}"
        val tempFile = File(tmpDir, relativeFileName)
        try {
            val digest = MessageDigest.getInstance("SHA-256")
            var copied = 0L
            DigestInputStream(input, digest).use { digestStream ->
                tempFile.outputStream().buffered().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    while (true) {
                        val read = digestStream.read(buffer)
                        if (read < 0) break
                        copied += read
                        if (copied >= CustomDhikrAudioLimits.MAX_BYTES_EXCLUSIVE) {
                            throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.SIZE)
                        }
                        output.write(buffer, 0, read)
                    }
                    output.flush()
                }
            }
            if (!CustomDhikrAudioLimits.isByteSizeAllowed(copied)) {
                throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.SIZE)
            }

            val probed = runCatching { probe.inspect(tempFile) }
                .getOrElse { throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.CORRUPT) }
            val resolvedMime = probed.mimeType.ifBlank { mimeType }.lowercase()
            if (!CustomDhikrAudioLimits.isMimeTypeAllowed(resolvedMime)) {
                throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.MIME)
            }
            val resolvedDuration = durationMs ?: probed.durationMs
            if (!CustomDhikrAudioLimits.isDurationAllowed(resolvedDuration)) {
                throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.DURATION)
            }

            return StagedOwnedAudio(
                tempFile = tempFile,
                relativeFileName = relativeFileName,
                mimeType = resolvedMime,
                byteSize = copied,
                durationMs = resolvedDuration,
                sha256 = digest.digest().joinToString("") { "%02x".format(it) },
            )
        } catch (error: CustomDhikrAudioException) {
            tempFile.delete()
            throw error
        } catch (error: Exception) {
            tempFile.delete()
            throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.IO, error.message ?: "io")
        }
    }

    fun commitStaged(
        staged: StagedOwnedAudio,
    ): OwnedAudioFile {
        val destination = File(ownedDir, staged.relativeFileName)
        if (!staged.tempFile.renameTo(destination)) {
            staged.tempFile.copyTo(destination, overwrite = true)
            staged.tempFile.delete()
        }
        return OwnedAudioFile(
            relativeFileName = staged.relativeFileName,
            absoluteFile = destination,
            mimeType = staged.mimeType,
            byteSize = staged.byteSize,
            durationMs = staged.durationMs,
            sha256 = staged.sha256,
        )
    }

    fun discardStaged(staged: StagedOwnedAudio) {
        staged.tempFile.delete()
    }

    fun deleteOwned(relativeFileName: String) {
        ownedFile(relativeFileName).delete()
    }

    fun resolveAvailability(relativeFileName: String): OwnedAudioAvailability {
        val file = ownedFile(relativeFileName)
        return if (file.isFile && file.length() > 0L) {
            OwnedAudioAvailability.AVAILABLE
        } else {
            OwnedAudioAvailability.MISSING
        }
    }

    fun ownedFile(relativeFileName: String): File {
        require(!relativeFileName.contains("..") && !relativeFileName.contains('/')) {
            "Invalid owned audio relative name"
        }
        return File(ownedDir, relativeFileName)
    }

    fun listTemporaryFiles(): List<File> =
        tmpDir.listFiles()?.toList().orEmpty()

    fun cleanupOrphans(
        referencedRelativeNames: Set<String>,
        ownedGraceMs: Long,
        tempGraceMs: Long,
        nowMs: Long,
    ) {
        ownedDir.listFiles()?.forEach { file ->
            if (file.isFile &&
                file.name !in referencedRelativeNames &&
                nowMs - file.lastModified() >= ownedGraceMs
            ) {
                file.delete()
            }
        }
        tmpDir.listFiles()?.forEach { file ->
            if (file.isFile && nowMs - file.lastModified() >= tempGraceMs) {
                file.delete()
            }
        }
    }

    private fun extensionForMime(mimeType: String): String = when (mimeType.lowercase()) {
        "audio/mpeg", "audio/mp3" -> "mp3"
        "audio/wav", "audio/x-wav", "audio/wave" -> "wav"
        "audio/aac" -> "aac"
        else -> "m4a"
    }

    companion object {
        const val ROOT_DIR_NAME = "dhikr_owned_audio"
        const val OWNED_DIR_NAME = "owned"
        const val TMP_DIR_NAME = "tmp"
    }
}
