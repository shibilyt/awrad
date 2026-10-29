package app.awrad.core.data.audio

import androidx.core.net.toUri
import app.awrad.core.data.profile.OpenProfile
import app.awrad.core.data.profile.ProfileDatabases
import app.awrad.core.data.sync.parseDocument
import app.awrad.core.database.AudioUploadEntity
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.AccountRepository
import app.awrad.core.domain.account.SignInState
import app.awrad.core.domain.personal.AudioStorage
import app.awrad.core.domain.personal.AudioUploadNotice
import app.awrad.core.domain.personal.AudioUploadProblem
import app.awrad.core.domain.personal.AudioUsage
import app.awrad.core.domain.personal.CustomAudioJson
import app.awrad.core.domain.personal.CustomAudioService
import app.awrad.core.domain.personal.RecordingDownloadError
import app.awrad.core.domain.personal.RecordingPlayback
import app.awrad.core.domain.personal.RecordingUpload
import app.awrad.core.domain.personal.UploadedAudio
import app.awrad.core.network.api.ApiFailure
import app.awrad.core.network.api.ApiResult
import app.awrad.core.network.http.SignedLinkTransport
import app.awrad.core.network.http.TransferResult
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File

/**
 * [CustomAudioService] for the active profile. Uploads are the [AudioUploader]'s (part of each sync run); this
 * reports them from the profile's upload table, plays recordings and reads the account's storage.
 *
 * **The download cache.** An uploaded recording that isn't on this phone is downloaded on its first play
 * (`get_audio_download`, then a GET of the signed link, written to a temporary file and renamed into place) into
 * the profile's `audio/` folder, and becomes the dhikr's local file, so later plays need no network. It goes with
 * the dhikr's recording: when the document names another recording or none (a sync, or an edit here), or the dhikr
 * is deleted ([app.awrad.core.data.sync.RoomSyncStore]), and with the profile.
 */
@OptIn(ExperimentalCoroutinesApi::class)
internal class ProfileCustomAudioService(
    private val profiles: ProfileDatabases,
    private val accounts: AccountRepository,
    private val remote: AudioRemote,
    private val links: SignedLinkTransport,
    private val io: CoroutineDispatcher,
) : CustomAudioService {

    private val downloads = Mutex()

    private val uploads: Flow<List<AudioUploadEntity>> =
        profiles.active.flatMapLatest { it.database.syncDao().observeUploads() }

    override fun upload(dhikrId: AwradId): Flow<RecordingUpload> = uploads.map { rows ->
        when (rows.firstOrNull { it.dhikrId == dhikrId.value }?.state) {
            AudioUploadEntity.QUEUED -> RecordingUpload.QUEUED
            AudioUploadEntity.FAILED -> RecordingUpload.FAILED
            else -> RecordingUpload.NONE
        }
    }.distinctUntilChanged()

    override val uploadNotices: Flow<List<AudioUploadNotice>> = uploads.map { rows ->
        rows.filter { it.state == AudioUploadEntity.FAILED && !it.dismissed }.mapNotNull { row ->
            val problem = AudioUploadProblem.entries.firstOrNull { it.name == row.problem } ?: return@mapNotNull null
            val storage = row.usedBytes?.let { used -> row.limitBytes?.let { AudioStorage(used, it) } }
            AudioUploadNotice(AwradId(row.dhikrId), problem, storage)
        }
    }

    /**
     * A full account's upload stays, so it's still retried once there's room ([AudioUploader]); only its notice
     * goes. Any other failed upload goes with its notice.
     */
    override suspend fun dismissUploadNotice(notice: AudioUploadNotice) {
        profiles.write { profile ->
            val dao = profile.database.syncDao()
            if (notice.problem == AudioUploadProblem.STORAGE_FULL) {
                dao.dismissFailedUploadFor(notice.dhikrId.value)
            } else {
                dao.deleteFailedUploadFor(notice.dhikrId.value)
            }
        }
    }

    override suspend fun playable(dhikrId: AwradId): RecordingPlayback = downloads.withLock {
        val profile = profiles.current()
        val stored = profiles.write(profile.profileId) { it.database.syncDao().customDhikr(dhikrId.value) }
            ?: return@withLock RecordingPlayback.Failed(RecordingDownloadError.NOT_FOUND)
        stored.audioFile?.let(::File)?.takeIf { it.isFile }?.let { return@withLock ready(it) }
        val uploaded = CustomAudioJson.uploaded(parseDocument(stored.document)["audio"])
            ?: return@withLock RecordingPlayback.Failed(RecordingDownloadError.NOT_FOUND)
        val accountId = ownerSignedIn(profile)
            ?: return@withLock RecordingPlayback.Failed(RecordingDownloadError.NOT_SIGNED_IN)
        download(profile, dhikrId, accountId, uploaded)
    }

    /** Downloads [uploaded] into the profile's files and makes it the dhikr's recording, if it still is one. */
    @Suppress("ReturnCount") // The link, the transfer and the dhikr changing meanwhile can each end it.
    private suspend fun download(
        profile: OpenProfile,
        dhikrId: AwradId,
        accountId: AwradId,
        uploaded: UploadedAudio,
    ): RecordingPlayback {
        val link = when (val result = remote.download(accountId, uploaded.assetId)) {
            is ApiResult.Success -> result.value
            is ApiResult.Failure -> return RecordingPlayback.Failed(errorOf(result.failure))
        }
        val folder = File(profile.filesDir, AUDIO_DIR)
        val target = File(folder, RecordingFiles.cacheName(uploaded.assetId.value, uploaded.contentType))
        withContext(io) { folder.mkdirs() }
        when (val transfer = links.download(link.url, target)) {
            TransferResult.Done -> Unit
            TransferResult.NoConnection -> return RecordingPlayback.Failed(RecordingDownloadError.OFFLINE)
            is TransferResult.Refused -> return RecordingPlayback.Failed(
                if (transfer.status == NOT_FOUND) RecordingDownloadError.NOT_FOUND else RecordingDownloadError.FAILED,
            )
        }
        val kept = profiles.write(profile.profileId) { open ->
            val dao = open.database.syncDao()
            val dhikr = dao.customDhikr(dhikrId.value)?.takeIf {
                CustomAudioJson.uploaded(parseDocument(it.document)["audio"])?.assetId == uploaded.assetId
            }
            if (dhikr != null) {
                val existing = dhikr.audioFile?.takeIf { File(it).isFile }
                if (existing == null) dao.upsertCustomDhikr(dhikr.copy(audioFile = target.path))
                existing ?: target.path
            } else {
                null
            }
        }
        if (kept != target.path) withContext(io) { target.delete() }
        return kept?.let { ready(File(it)) } ?: RecordingPlayback.Failed(RecordingDownloadError.NOT_FOUND)
    }

    override suspend fun usage(): AudioUsage {
        val accountId = ownerSignedIn(profiles.current()) ?: return AudioUsage.NotSignedIn
        return when (val result = remote.usage(accountId)) {
            is ApiResult.Success -> AudioUsage.Known(AudioStorage(result.value.usedBytes, result.value.limitBytes))
            is ApiResult.Failure -> AudioUsage.Unavailable
        }
    }

    /** The signed-in account, when it owns [profile] (and still exists): the only one the API may be asked for. */
    private suspend fun ownerSignedIn(profile: OpenProfile): AwradId? {
        val account = (accounts.session.first() as? SignInState.SignedIn)?.account ?: return null
        return account.id.takeIf { profile.accountId == it && !profile.accountDeleted }
    }

    private fun ready(file: File) = RecordingPlayback.Ready(file.toUri().toString())

    private fun errorOf(failure: ApiFailure): RecordingDownloadError = when (failure) {
        ApiFailure.NoConnection -> RecordingDownloadError.OFFLINE
        ApiFailure.NotSignedIn -> RecordingDownloadError.NOT_SIGNED_IN
        is ApiFailure.ProblemResponse -> when (failure.status) {
            NOT_FOUND -> RecordingDownloadError.NOT_FOUND
            UNAUTHORIZED -> RecordingDownloadError.NOT_SIGNED_IN
            else -> RecordingDownloadError.FAILED
        }
        is ApiFailure.UnexpectedResponse -> RecordingDownloadError.FAILED
    }

    private companion object {
        const val AUDIO_DIR = "audio"
        const val NOT_FOUND = 404
        const val UNAUTHORIZED = 401
    }
}
