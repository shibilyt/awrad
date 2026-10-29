package app.awrad.core.testing

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.personal.AudioUploadNotice
import app.awrad.core.domain.personal.AudioUsage
import app.awrad.core.domain.personal.CustomAudioService
import app.awrad.core.domain.personal.RecordingDownloadError
import app.awrad.core.domain.personal.RecordingPlayback
import app.awrad.core.domain.personal.RecordingUpload
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map

/**
 * A [CustomAudioService] whose answers tests set: uploads by dhikr, notices, the files [playable] hands out (a
 * dhikr missing from [files] fails with [downloadError]) and the storage [usage] reports. It records each call.
 */
public class FakeCustomAudioService(public var usageAnswer: AudioUsage = AudioUsage.NotSignedIn) : CustomAudioService {
    public val uploads: MutableStateFlow<Map<AwradId, RecordingUpload>> = MutableStateFlow(emptyMap())
    public val noticeState: MutableStateFlow<List<AudioUploadNotice>> = MutableStateFlow(emptyList())
    public val files: MutableMap<AwradId, String> = mutableMapOf()
    public var downloadError: RecordingDownloadError = RecordingDownloadError.OFFLINE
    public val playableCalls: MutableList<AwradId> = mutableListOf()
    public var usageCalls: Int = 0
        private set

    override fun upload(dhikrId: AwradId): Flow<RecordingUpload> =
        uploads.map { it[dhikrId] ?: RecordingUpload.NONE }

    override val uploadNotices: Flow<List<AudioUploadNotice>> = noticeState

    override suspend fun dismissUploadNotice(notice: AudioUploadNotice) {
        noticeState.value = noticeState.value - notice
    }

    override suspend fun playable(dhikrId: AwradId): RecordingPlayback {
        playableCalls += dhikrId
        return files[dhikrId]?.let(RecordingPlayback::Ready) ?: RecordingPlayback.Failed(downloadError)
    }

    override suspend fun usage(): AudioUsage {
        usageCalls++
        return usageAnswer
    }
}
