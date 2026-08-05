package app.awrad.awrad_dhikrgoalstracker.service

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class MediaMetadataCustomDhikrAudioProbe @Inject constructor(
    @ApplicationContext private val context: Context,
) : CustomDhikrAudioProbe {
    override fun inspect(file: File): CustomDhikrAudioProbeResult {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(file.absolutePath)
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
                ?: throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.CORRUPT)
            val mime = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
                ?: "audio/mpeg"
            return CustomDhikrAudioProbeResult(mimeType = mime, durationMs = duration)
        } catch (error: CustomDhikrAudioException) {
            throw error
        } catch (_: Exception) {
            throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.CORRUPT)
        } finally {
            runCatching { retriever.release() }
        }
    }

    fun inspectUri(uri: Uri): CustomDhikrAudioProbeResult {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(context, uri)
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
                ?: throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.CORRUPT)
            val mime = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
                ?: context.contentResolver.getType(uri)
                ?: "audio/mpeg"
            return CustomDhikrAudioProbeResult(mimeType = mime, durationMs = duration)
        } catch (error: CustomDhikrAudioException) {
            throw error
        } catch (_: Exception) {
            throw CustomDhikrAudioException(CustomDhikrAudioException.Reason.CORRUPT)
        } finally {
            runCatching { retriever.release() }
        }
    }
}
