package app.awrad.core.data.audio

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.audio.AudioUploadRules
import app.awrad.core.network.api.ApiFailure
import app.awrad.core.network.api.ApiResult
import app.awrad.core.network.api.AudioAsset
import app.awrad.core.network.api.AudioAssetResult
import app.awrad.core.network.api.AudioDownloadLink
import app.awrad.core.network.api.AudioUploadLink
import app.awrad.core.network.api.AudioUploadRequest
import app.awrad.core.network.api.AudioUploadReservation
import app.awrad.core.network.api.Problem
import app.awrad.core.network.http.SignedLinkTransport
import app.awrad.core.network.http.TransferResult
import java.io.File
import java.security.MessageDigest
import java.util.Base64
import app.awrad.core.network.api.AudioUsage as AudioUsageBody

/**
 * Object storage in memory, behind signed links: what was PUT under each asset ID with which headers. Tests make it
 * lose or change bytes, or refuse, to drive the upload's answers.
 */
@Suppress("ReturnCount") // A fake answers early for each scripted case.
internal class FakeObjectStore : SignedLinkTransport {
    class Stored(val bytes: ByteArray, val headers: Map<String, String>)

    val objects = mutableMapOf<String, Stored>()
    val puts = mutableListOf<Pair<String, Map<String, String>>>()
    val gets = mutableListOf<String>()

    /** Answers for the next PUTs, before storing normally. */
    val putResults = ArrayDeque<TransferResult>()

    /** The next PUTs report success but store nothing (storage lost them). */
    var dropPuts = 0

    /** The next PUTs store other bytes than were sent. */
    var corruptPuts = 0

    var offline = false

    override suspend fun upload(url: String, headers: Map<String, String>, file: File): TransferResult {
        puts += url to headers
        if (offline) return TransferResult.NoConnection
        putResults.removeFirstOrNull()?.let { return it }
        val asset = assetOf(url)
        when {
            dropPuts > 0 -> dropPuts--
            corruptPuts > 0 -> {
                corruptPuts--
                objects[asset] = Stored(file.readBytes() + 0, headers)
            }
            else -> objects[asset] = Stored(file.readBytes(), headers)
        }
        return TransferResult.Done
    }

    override suspend fun download(url: String, target: File): TransferResult {
        gets += url
        if (offline) return TransferResult.NoConnection
        val stored = objects[assetOf(url)] ?: return TransferResult.Refused(NOT_FOUND)
        target.writeBytes(stored.bytes)
        return TransferResult.Done
    }

    private fun assetOf(url: String) = url.substringAfterLast('/').substringBefore('?')

    private companion object {
        const val NOT_FOUND = 404
    }
}

/**
 * The four audio operations for one account, in memory, over [store]: reserving is idempotent by asset ID,
 * confirming compares the stored object's size, type and SHA-256, and ready assets go into [ready] (shared with the
 * fake change-queue server, which checks puts against it).
 */
@Suppress("ReturnCount") // A fake answers early for each scripted case.
internal class FakeAudioServer(
    private val accountId: AwradId,
    private val store: FakeObjectStore,
    val ready: MutableMap<String, Pair<Long, String>>,
) : AudioRemote {
    val pending = mutableMapOf<String, AudioUploadRequest>()
    val calls = mutableListOf<String>()

    /** Bytes the account holds besides the recordings uploaded here. */
    var otherUsedBytes = 0L

    /** Failures to answer the next calls of each operation with. */
    val createFailures = ArrayDeque<ApiFailure>()
    val completeFailures = ArrayDeque<ApiFailure>()
    val downloadFailures = ArrayDeque<ApiFailure>()

    override suspend fun createUpload(
        accountId: AwradId,
        request: AudioUploadRequest,
    ): ApiResult<AudioUploadReservation> {
        calls += "create ${request.assetId}"
        mismatch(accountId)?.let { return it }
        createFailures.removeFirstOrNull()?.let { return ApiResult.Failure(it) }
        val asset = request.assetId
        ready[asset]?.let { (size, type) ->
            return if (size == request.byteSize && type == request.contentType) {
                ApiResult.Success(AudioUploadReservation.Ready(asset(asset, size, type)))
            } else {
                problem(CONFLICT, "asset_id_in_use")
            }
        }
        pending[asset]?.let { if (it != request) return problem(CONFLICT, "asset_id_in_use") }
        val used = if (asset in pending) usedBytes() - request.byteSize else usedBytes()
        AudioUploadRules.check(request.byteSize, request.contentType, used)?.let { error ->
            val status = when (error.wire) {
                "unsupported_audio_type" -> UNSUPPORTED
                "file_too_large" -> TOO_LARGE
                else -> UNPROCESSABLE
            }
            val full = error.wire == "storage_full"
            return ApiResult.Failure(
                ApiFailure.ProblemResponse(
                    Problem(
                        status = status,
                        code = error.wire,
                        usedBytes = used.takeIf { full },
                        limitBytes = AudioUploadRules.ACCOUNT_LIMIT_BYTES.takeIf { full },
                    ),
                    null,
                ),
            )
        }
        pending[asset] = request
        val checksum = Base64.getEncoder().encodeToString(hexBytes(request.sha256))
        val link = AudioUploadLink(
            assetId = asset,
            uploadUrl = "https://storage.test/awrad-private-dhikr/$asset?X-Amz-Signature=${calls.size}",
            uploadHeaders = mapOf("content-type" to request.contentType, "x-amz-checksum-sha256" to checksum),
            expiresAt = "2026-10-29T08:15:00Z",
        )
        return ApiResult.Success(AudioUploadReservation.Pending(link))
    }

    override suspend fun completeUpload(accountId: AwradId, assetId: AwradId): ApiResult<AudioAssetResult> {
        calls += "complete ${assetId.value}"
        mismatch(accountId)?.let { return it }
        completeFailures.removeFirstOrNull()?.let { return ApiResult.Failure(it) }
        val asset = assetId.value
        ready[asset]?.let { (size, type) -> return ApiResult.Success(AudioAssetResult(asset(asset, size, type))) }
        val request = pending[asset] ?: return problem(NOT_FOUND, "not_found")
        val stored = store.objects[asset] ?: return problem(CONFLICT, "upload_incomplete")
        val matches = stored.bytes.size.toLong() == request.byteSize &&
            stored.headers["content-type"] == request.contentType &&
            sha256(stored.bytes) == request.sha256
        if (!matches) {
            store.objects.remove(asset)
            pending.remove(asset)
            return problem(UNPROCESSABLE, "upload_mismatch")
        }
        pending.remove(asset)
        ready[asset] = request.byteSize to request.contentType
        return ApiResult.Success(AudioAssetResult(asset(asset, request.byteSize, request.contentType)))
    }

    override suspend fun download(accountId: AwradId, assetId: AwradId): ApiResult<AudioDownloadLink> {
        calls += "download ${assetId.value}"
        mismatch(accountId)?.let { return it }
        downloadFailures.removeFirstOrNull()?.let { return ApiResult.Failure(it) }
        if (assetId.value !in ready) return problem(NOT_FOUND, "not_found")
        val url = "https://storage.test/awrad-private-dhikr/${assetId.value}?X-Amz-Signature=get"
        return ApiResult.Success(AudioDownloadLink(url, "2026-10-29T09:10:00Z"))
    }

    override suspend fun usage(accountId: AwradId): ApiResult<AudioUsageBody> {
        calls += "usage"
        mismatch(accountId)?.let { return it }
        return ApiResult.Success(AudioUsageBody(usedBytes(), AudioUploadRules.ACCOUNT_LIMIT_BYTES))
    }

    /** Cleans up a ready asset, as the server's job does once nothing references it. */
    fun cleanUp(assetId: String) {
        ready.remove(assetId)
        store.objects.remove(assetId)
    }

    private fun usedBytes() = otherUsedBytes + ready.values.sumOf { it.first } + pending.values.sumOf { it.byteSize }

    private fun mismatch(accountId: AwradId): ApiResult.Failure? =
        if (accountId == this.accountId) null else problem(CONFLICT, "account_mismatch")

    private fun asset(id: String, size: Long, type: String) =
        AudioAsset(id, byteSize = size, contentType = type, status = "ready", createdAt = "2026-10-29T08:01:12Z")

    companion object {
        const val CONFLICT = 409
        const val NOT_FOUND = 404
        const val TOO_LARGE = 413
        const val UNSUPPORTED = 415
        const val UNPROCESSABLE = 422
        private const val HEX = 16

        fun problem(status: Int, code: String): ApiResult.Failure =
            ApiResult.Failure(ApiFailure.ProblemResponse(Problem(status = status, code = code), null))

        fun sha256(bytes: ByteArray): String =
            MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

        private fun hexBytes(hex: String) = hex.chunked(2).map { it.toInt(HEX).toByte() }.toByteArray()
    }
}
