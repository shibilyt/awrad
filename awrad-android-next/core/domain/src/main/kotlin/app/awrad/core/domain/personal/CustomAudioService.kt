package app.awrad.core.domain.personal

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.AudioUploadError
import kotlinx.coroutines.flow.Flow

/** The account's audio storage: bytes in use (ready assets and pending uploads) and the limit. */
public data class AudioStorage(val usedBytes: Long, val limitBytes: Long)

/** Storage used, as Settings shows it. */
public sealed interface AudioUsage {
    public data class Known(val storage: AudioStorage) : AudioUsage

    /** Signed out, or the active profile isn't the signed-in account's: nothing to show, and nothing is asked. */
    public data object NotSignedIn : AudioUsage

    /** The server couldn't be reached, or answered with an error. */
    public data object Unavailable : AudioUsage
}

/** Where a custom dhikr's recording stands on its way to the account. */
public enum class RecordingUpload {
    /** Nothing waiting: it's uploaded, or it stays on this phone (no account). */
    NONE,

    /** Waiting to upload, or uploading: it runs while signed in as the profile's account and online. */
    QUEUED,

    /** It couldn't upload and stays on this phone; a notice says why. */
    FAILED,
}

/** Why a recording couldn't upload. It stays on the phone (`{"local_only": true}`), and the dhikr still syncs. */
public enum class AudioUploadProblem {
    UNSUPPORTED_TYPE,
    INVALID_SIZE,
    FILE_TOO_LARGE,
    STORAGE_FULL,

    /** The stored bytes didn't match the file, attempt after attempt; the server deleted them each time. */
    UPLOAD_MISMATCH,
    ;

    public companion object {
        public fun of(error: AudioUploadError): AudioUploadProblem = when (error) {
            AudioUploadError.UNSUPPORTED_AUDIO_TYPE -> UNSUPPORTED_TYPE
            AudioUploadError.INVALID_SIZE -> INVALID_SIZE
            AudioUploadError.FILE_TOO_LARGE -> FILE_TOO_LARGE
            AudioUploadError.STORAGE_FULL -> STORAGE_FULL
        }
    }
}

/**
 * "Audio couldn't be uploaded": the recording of [dhikrId] stays on this phone. [storage] is the account's use and
 * limit when it's full.
 */
public data class AudioUploadNotice(
    val dhikrId: AwradId,
    val problem: AudioUploadProblem,
    val storage: AudioStorage? = null,
)

/** A recording ready to play from this phone, or why not. */
public sealed interface RecordingPlayback {
    /** Play [localUri], the file in the profile's private storage. */
    public data class Ready(val localUri: String) : RecordingPlayback

    public data class Failed(val reason: RecordingDownloadError) : RecordingPlayback
}

/** Why an uploaded recording couldn't be downloaded for its first play. */
public enum class RecordingDownloadError {
    /** No connection. A recording plays offline only after its first download. */
    OFFLINE,

    /** Signed out, or signed in as another account than the profile's. */
    NOT_SIGNED_IN,

    /** The account no longer has it (replaced or cleaned up), or the dhikr has no recording to download. */
    NOT_FOUND,

    /** The server or storage failed. */
    FAILED,
}

/**
 * Port: custom dhikr recordings beyond this phone (slice 3c, contracts/audio/v1). Uploads run in the background
 * while signed in as the active profile's account; this reports them, plays uploaded recordings (downloading each
 * once into the profile's files) and reads the account's storage.
 */
public interface CustomAudioService {
    /** Where [dhikrId]'s recording stands on its way to the account. */
    public fun upload(dhikrId: AwradId): Flow<RecordingUpload>

    /** Recordings that couldn't upload, until the user dismisses them. */
    public val uploadNotices: Flow<List<AudioUploadNotice>>

    public suspend fun dismissUploadNotice(notice: AudioUploadNotice)

    /**
     * The local file to play [dhikrId]'s recording from: the one on this phone, or the uploaded one, downloaded on
     * its first play and kept for later plays, offline too.
     */
    public suspend fun playable(dhikrId: AwradId): RecordingPlayback

    /** The account's storage used, for Settings. */
    public suspend fun usage(): AudioUsage
}
