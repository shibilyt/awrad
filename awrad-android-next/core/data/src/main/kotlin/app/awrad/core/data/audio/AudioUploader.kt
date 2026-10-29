package app.awrad.core.data.audio

import app.awrad.core.data.profile.ProfileDatabases
import app.awrad.core.data.sync.RoomSyncStore
import app.awrad.core.data.sync.SyncOutcome
import app.awrad.core.data.sync.parseDocument
import app.awrad.core.database.AudioUploadEntity
import app.awrad.core.database.SyncDao
import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.AudioContentType
import app.awrad.core.domain.audio.AudioUploadRules
import app.awrad.core.domain.personal.AudioStorage
import app.awrad.core.domain.personal.AudioUploadProblem
import app.awrad.core.domain.personal.CustomAudioJson
import app.awrad.core.domain.personal.CustomDhikrValidity
import app.awrad.core.domain.personal.UploadedAudio
import app.awrad.core.domain.sync.EntityKey
import app.awrad.core.domain.sync.EntityType
import app.awrad.core.domain.sync.LocalEdit
import app.awrad.core.domain.sync.Outbox
import app.awrad.core.domain.sync.SyncOp
import app.awrad.core.network.api.ApiFailure
import app.awrad.core.network.api.ApiResult
import app.awrad.core.network.api.AudioAsset
import app.awrad.core.network.api.AudioUploadRequest
import app.awrad.core.network.api.AudioUploadReservation
import app.awrad.core.network.http.SignedLinkTransport
import app.awrad.core.network.http.TransferResult
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject
import java.io.File
import java.time.Clock
import java.time.Duration

/**
 * Uploads a profile's queued recordings (contracts/audio/v1/README.md, "Uploading"), as the first step of each sync
 * run, so it only ever runs signed in, as the account that owns the profile ([app.awrad.core.data.sync.SyncEngine]).
 *
 * Each recording: reserve (`create_audio_upload`), PUT the file to the signed link with exactly its headers,
 * confirm (`complete_audio_upload`), then point the dhikr at the ready asset and queue its put, in one transaction,
 * so the run's send step carries it straight away. What can't succeed stays on the phone with a notice:
 * - `413`, `415` or `invalid_size` (or the same rules checked here first): until the recording changes;
 * - `storage_full`, with the account's use: until a later run reads the account's usage
 *   (`get_audio_usage`) and finds room for the file's size, then it's queued again ([requeueWhereRoom]);
 * - `upload_mismatch`: retried straight away, once, with a new asset ID and the file measured again; a second
 *   mismatch in a row ([MAX_MISMATCHES]) gives up.
 * `upload_incomplete` PUTs again; `asset_id_in_use` and a cleaned-up pending upload (`404`) start over with a new
 * asset ID. A failure of the network or server ends the run for backoff, like the change queue's.
 */
@Suppress(
    "TooManyFunctions", // One small step per answer of the upload protocol.
    "LongParameterList", // The seams it crosses: profiles, server, storage, the file probe, clock, IDs, IO.
    "ReturnCount", // Every step can end an upload: a switch of profile, an answer that settles it, a retry.
)
internal class AudioUploader(
    private val profiles: ProfileDatabases,
    private val remote: AudioRemote,
    private val links: SignedLinkTransport,
    private val probe: DurationProbe,
    private val clock: Clock,
    private val newId: () -> AwradId,
    private val io: CoroutineDispatcher,
) {
    /** Uploads every queued recording of [profileId] for [accountId]; [SyncOutcome.Done] when none is left to retry. */
    suspend fun uploadAll(profileId: AwradId, accountId: AwradId): SyncOutcome {
        requeueWhereRoom(profileId, accountId)
        val queued = profiles.write(profileId) { it.database.syncDao().queuedUploads() } ?: return SyncOutcome.Skipped
        var later = false
        for (row in queued) {
            when (val step = upload(profileId, accountId, row)) {
                Step.Next -> Unit
                Step.Later -> later = true
                is Step.Stop -> return step.outcome
            }
        }
        return if (later) SyncOutcome.Failed(retryAfter = null) else SyncOutcome.Done
    }

    /**
     * Queues again each `storage_full` failure the account now has room for, oldest first, counting each one's size
     * against the room left, its notice dismissed or not (a new failure shows a new notice). Only asks for the usage
     * when there's such a failure; without an answer, they wait.
     */
    private suspend fun requeueWhereRoom(profileId: AwradId, accountId: AwradId) {
        val full = profiles.write(profileId) { it.database.syncDao().failedUploads(STORAGE_FULL_PROBLEM) }
        if (full.isNullOrEmpty()) return
        val usage = (remote.usage(accountId) as? ApiResult.Success)?.value ?: return
        var used = usage.usedBytes
        val fitting = full.filter { row ->
            val size = row.byteSize ?: 0L
            (size > 0 && used + size <= usage.limitBytes).also { fits -> if (fits) used += size }
        }
        if (fitting.isEmpty()) return
        profiles.write(profileId) { open ->
            val dao = open.database.syncDao()
            fitting.mapNotNull { dao.upload(it.assetId) }
                .filter { it.state == AudioUploadEntity.FAILED && it.problem == STORAGE_FULL_PROBLEM }
                .forEach { stored ->
                    val queued = AudioUploadEntity.QUEUED
                    val cleared = stored.copy(problem = null, usedBytes = null, limitBytes = null, dismissed = false)
                    dao.upsertUpload(cleared.copy(state = queued))
                }
        }
    }

    /** Whether [profileId] has recordings waiting to upload. */
    suspend fun hasQueued(profileId: AwradId): Boolean =
        profiles.write(profileId) { it.database.syncDao().queuedUploads().isNotEmpty() } == true

    private suspend fun upload(profileId: AwradId, accountId: AwradId, queued: AudioUploadEntity): Step {
        var row = when (val prepared = prepare(profileId, queued)) {
            is Prepared.Ready -> prepared.row
            is Prepared.Finished -> return prepared.step
        }
        repeat(MAX_ATTEMPTS) {
            when (val attempt = attempt(profileId, accountId, row)) {
                is Attempt.Finished -> return attempt.step
                is Attempt.Again -> row = attempt.row
            }
        }
        return Step.Later
    }

    /**
     * Checks the upload still names the dhikr's recording on this phone (dropping it otherwise), measures the file
     * once (kept, so retries reserve the same body) and runs the upload rules on it.
     */
    private suspend fun prepare(profileId: AwradId, queued: AudioUploadEntity): Prepared {
        val waiting = profiles.write(profileId) { stillWaiting(it.database.syncDao(), queued) }
            ?: return Prepared.Finished(Step.Stop(SyncOutcome.Skipped))
        if (!waiting) return Prepared.Finished(Step.Next)
        val row = if (queued.sha256 != null) {
            queued
        } else {
            val facts = withContext(io) { RecordingFiles.measure(File(queued.audioFile), probe) }
                ?: return Prepared.Finished(drop(profileId, queued))
            queued.copy(
                sha256 = facts.sha256,
                byteSize = facts.byteSize,
                contentType = facts.contentType,
                durationMs = facts.durationMs,
            ).also { measured -> profiles.write(profileId) { it.database.syncDao().upsertUpload(measured) } }
        }
        val error = AudioUploadRules.check(checkNotNull(row.byteSize), checkNotNull(row.contentType), usedBytes = 0)
        return if (error == null) {
            Prepared.Ready(row)
        } else {
            Prepared.Finished(fail(profileId, row, AudioUploadProblem.of(error)))
        }
    }

    private suspend fun attempt(profileId: AwradId, accountId: AwradId, row: AudioUploadEntity): Attempt {
        val request = AudioUploadRequest(
            assetId = row.assetId,
            byteSize = checkNotNull(row.byteSize),
            contentType = checkNotNull(row.contentType),
            sha256 = checkNotNull(row.sha256),
        )
        val asset = when (val reserved = remote.createUpload(accountId, request)) {
            is ApiResult.Failure -> return reserveFailed(profileId, row, reserved.failure)
            is ApiResult.Success -> when (val reservation = reserved.value) {
                is AudioUploadReservation.Ready -> reservation.asset
                is AudioUploadReservation.Pending -> {
                    val link = reservation.link
                    when (links.upload(link.uploadUrl, link.uploadHeaders, File(row.audioFile))) {
                        TransferResult.Done -> Unit
                        TransferResult.NoConnection -> return Attempt.Finished(Step.Stop(RETRY))
                        // An expired link, or storage refusing the bytes: the next run reserves a fresh link.
                        is TransferResult.Refused -> return Attempt.Finished(Step.Later)
                    }
                    when (val completed = remote.completeUpload(accountId, AwradId(row.assetId))) {
                        is ApiResult.Failure -> return completeFailed(profileId, row, completed.failure)
                        is ApiResult.Success -> completed.value.asset
                    }
                }
            }
        }
        return Attempt.Finished(confirm(profileId, row, asset))
    }

    private suspend fun reserveFailed(profileId: AwradId, row: AudioUploadEntity, failure: ApiFailure): Attempt {
        val problem = (failure as? ApiFailure.ProblemResponse)?.problem
        val step = when (problem?.code) {
            FILE_TOO_LARGE -> fail(profileId, row, AudioUploadProblem.FILE_TOO_LARGE)
            UNSUPPORTED_AUDIO_TYPE -> fail(profileId, row, AudioUploadProblem.UNSUPPORTED_TYPE)
            INVALID_SIZE -> fail(profileId, row, AudioUploadProblem.INVALID_SIZE)
            STORAGE_FULL -> fail(
                profileId,
                row,
                AudioUploadProblem.STORAGE_FULL,
                storage = problem.usedBytes?.let { used -> problem.limitBytes?.let { AudioStorage(used, it) } },
            )
            ASSET_ID_IN_USE -> return renew(profileId, row, mismatch = false)
            else -> failed(failure)
        }
        return Attempt.Finished(step)
    }

    private suspend fun completeFailed(profileId: AwradId, row: AudioUploadEntity, failure: ApiFailure): Attempt {
        val response = failure as? ApiFailure.ProblemResponse
        return when {
            // Storage has no object yet: PUT again (reserving again gives a fresh link), then confirm again.
            response?.problem?.code == UPLOAD_INCOMPLETE -> Attempt.Again(row)
            response?.problem?.code == UPLOAD_MISMATCH -> if (row.mismatches + 1 >= MAX_MISMATCHES) {
                Attempt.Finished(fail(profileId, row, AudioUploadProblem.UPLOAD_MISMATCH))
            } else {
                renew(profileId, row, mismatch = true)
            }
            // The pending upload was cleaned up (24 hours unconfirmed): start over.
            response?.status == NOT_FOUND -> renew(profileId, row, mismatch = false)
            else -> Attempt.Finished(failed(failure))
        }
    }

    /** Starts the upload over under a new asset ID, measuring the file again. */
    private suspend fun renew(profileId: AwradId, row: AudioUploadEntity, mismatch: Boolean): Attempt {
        val renewed = AudioUploadEntity(
            assetId = newId().value,
            dhikrId = row.dhikrId,
            audioFile = row.audioFile,
            state = AudioUploadEntity.QUEUED,
            createdAt = row.createdAt,
            mismatches = if (mismatch) row.mismatches + 1 else row.mismatches,
        )
        val replaced = profiles.write(profileId) { open ->
            val dao = open.database.syncDao()
            (dao.upload(row.assetId) != null).also { if (it) dao.insertUpload(renewed) }
        } ?: return Attempt.Finished(Step.Stop(SyncOutcome.Skipped))
        if (!replaced) return Attempt.Finished(Step.Next)
        return when (val prepared = prepare(profileId, renewed)) {
            is Prepared.Ready -> Attempt.Again(prepared.row)
            is Prepared.Finished -> Attempt.Finished(prepared.step)
        }
    }

    /**
     * The upload is a ready asset: unless the dhikr's recording changed meanwhile, its `audio` names the asset (size
     * and type copied from it) and a put is queued, in one transaction with removing the upload.
     */
    private suspend fun confirm(profileId: AwradId, row: AudioUploadEntity, asset: AudioAsset): Step {
        val written = profiles.write(profileId) { open ->
            val dao = open.database.syncDao()
            dao.deleteUpload(row.assetId)
            val dhikr = dao.customDhikr(row.dhikrId)?.takeIf { it.audioFile == row.audioFile } ?: return@write
            val document = parseDocument(dhikr.document)
            val contentType = AudioContentType.fromWire(asset.contentType)
            if (!CustomAudioJson.isLocalOnly(document["audio"]) || contentType == null) return@write
            val uploaded = UploadedAudio(
                assetId = AwradId.parse(asset.assetId) ?: AwradId(row.assetId),
                byteSize = asset.byteSize,
                contentType = contentType,
                durationMs = row.durationMs,
            )
            val updated = JsonObject(document + ("audio" to CustomAudioJson.encode(uploaded)))
            if (!CustomDhikrValidity.isValid(updated)) return@write
            dao.upsertCustomDhikr(dhikr.copy(document = updated.toString()))
            if (open.queuesEdits) {
                val key = EntityKey(EntityType.CUSTOM_DHIKR, AwradId(row.dhikrId))
                Outbox.enqueue(RoomSyncStore(dao, now = clock::millis), LocalEdit(newId(), key, SyncOp.PUT, updated))
            }
        }
        return if (written == null) Step.Stop(SyncOutcome.Skipped) else Step.Next
    }

    /** Keeps the recording on the phone: the upload becomes a notice until it's dismissed. */
    private suspend fun fail(
        profileId: AwradId,
        row: AudioUploadEntity,
        problem: AudioUploadProblem,
        storage: AudioStorage? = null,
    ): Step {
        val failed = row.copy(
            state = AudioUploadEntity.FAILED,
            problem = problem.name,
            usedBytes = storage?.usedBytes,
            limitBytes = storage?.limitBytes,
            dismissed = false,
        )
        val written = profiles.write(profileId) { open ->
            val dao = open.database.syncDao()
            if (dao.upload(row.assetId) != null) dao.upsertUpload(failed)
        }
        return if (written == null) Step.Stop(SyncOutcome.Skipped) else Step.Next
    }

    /** The recording's file can't be read any more: there's nothing to upload. */
    private suspend fun drop(profileId: AwradId, row: AudioUploadEntity): Step {
        val written = profiles.write(profileId) { it.database.syncDao().deleteUpload(row.assetId) }
        return if (written == null) Step.Stop(SyncOutcome.Skipped) else Step.Next
    }

    /** Whether [queued] is still waiting and still names its dhikr's recording on this phone; drops it if not. */
    private fun stillWaiting(dao: SyncDao, queued: AudioUploadEntity): Boolean {
        val stored = dao.upload(queued.assetId) ?: return false
        val dhikr = dao.customDhikr(queued.dhikrId)
        val waiting = stored.state == AudioUploadEntity.QUEUED &&
            dhikr != null &&
            dhikr.audioFile == queued.audioFile &&
            CustomAudioJson.isLocalOnly(parseDocument(dhikr.document)["audio"]) &&
            File(queued.audioFile).isFile
        if (!waiting && stored.state == AudioUploadEntity.QUEUED) dao.deleteUpload(queued.assetId)
        return waiting
    }

    /** A failure every operation shares: the account, the session, or the network and server. */
    private fun failed(failure: ApiFailure): Step = when (failure) {
        is ApiFailure.ProblemResponse -> when {
            failure.problem.code == ACCOUNT_MISMATCH -> Step.Stop(SyncOutcome.AccountMismatch)
            failure.status == UNAUTHORIZED -> Step.Stop(SyncOutcome.Skipped)
            failure.status == TOO_MANY_REQUESTS || failure.status >= SERVER_ERROR ->
                Step.Stop(SyncOutcome.Failed(failure.retryAfterSeconds?.let(Duration::ofSeconds)))
            // Anything else refused this one upload; the others still go, and it's tried again next run.
            else -> Step.Later
        }
        ApiFailure.NotSignedIn -> Step.Stop(SyncOutcome.Skipped)
        ApiFailure.NoConnection, is ApiFailure.UnexpectedResponse -> Step.Stop(RETRY)
    }

    /** What one upload left for the run. */
    private sealed interface Step {
        /** Done with it: uploaded, failed for good (a notice), or no longer wanted. */
        data object Next : Step

        /** Not uploaded this run; the run backs off and tries again. */
        data object Later : Step

        /** The run stops here with [outcome]. */
        data class Stop(val outcome: SyncOutcome) : Step
    }

    private sealed interface Attempt {
        data class Finished(val step: Step) : Attempt

        /** Try again now with [row] (the same body to PUT again, or a new asset ID). */
        data class Again(val row: AudioUploadEntity) : Attempt
    }

    private sealed interface Prepared {
        data class Ready(val row: AudioUploadEntity) : Prepared

        data class Finished(val step: Step) : Prepared
    }

    companion object {
        /** Reserve, PUT and confirm rounds for one recording in one run. */
        const val MAX_ATTEMPTS = 3

        /** `upload_mismatch` answers in a row before the recording stays local with a notice: one retry. */
        const val MAX_MISMATCHES = 2

        private val RETRY = SyncOutcome.Failed(retryAfter = null)
        private const val FILE_TOO_LARGE = "file_too_large"
        private const val UNSUPPORTED_AUDIO_TYPE = "unsupported_audio_type"
        private const val INVALID_SIZE = "invalid_size"
        private const val STORAGE_FULL = "storage_full"
        private val STORAGE_FULL_PROBLEM = AudioUploadProblem.STORAGE_FULL.name
        private const val ASSET_ID_IN_USE = "asset_id_in_use"
        private const val UPLOAD_INCOMPLETE = "upload_incomplete"
        private const val UPLOAD_MISMATCH = "upload_mismatch"
        private const val ACCOUNT_MISMATCH = "account_mismatch"
        private const val UNAUTHORIZED = 401
        private const val NOT_FOUND = 404
        private const val TOO_MANY_REQUESTS = 429
        private const val SERVER_ERROR = 500
    }
}
