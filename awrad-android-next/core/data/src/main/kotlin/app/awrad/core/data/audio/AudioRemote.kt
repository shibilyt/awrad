package app.awrad.core.data.audio

import app.awrad.core.domain.AwradId
import app.awrad.core.network.api.ApiResult
import app.awrad.core.network.api.AudioApi
import app.awrad.core.network.api.AudioAssetResult
import app.awrad.core.network.api.AudioDownloadLink
import app.awrad.core.network.api.AudioUploadRequest
import app.awrad.core.network.api.AudioUploadReservation
import app.awrad.core.network.session.DeviceSessionManager
import javax.inject.Inject
import app.awrad.core.network.api.AudioUsage as AudioUsageBody

/**
 * The server side of private audio (contracts/audio/v1), for one account: every call names it in
 * `X-Awrad-Account`. The app's is [NetworkAudioRemote]; tests use a fake server.
 */
internal interface AudioRemote {
    suspend fun createUpload(accountId: AwradId, request: AudioUploadRequest): ApiResult<AudioUploadReservation>

    suspend fun completeUpload(accountId: AwradId, assetId: AwradId): ApiResult<AudioAssetResult>

    suspend fun download(accountId: AwradId, assetId: AwradId): ApiResult<AudioDownloadLink>

    suspend fun usage(accountId: AwradId): ApiResult<AudioUsageBody>
}

/** [AudioRemote] over the API with this device's session (refreshing the access token as needed). */
internal class NetworkAudioRemote @Inject constructor(
    private val api: AudioApi,
    private val sessions: DeviceSessionManager,
) : AudioRemote {
    override suspend fun createUpload(
        accountId: AwradId,
        request: AudioUploadRequest,
    ): ApiResult<AudioUploadReservation> =
        sessions.authorized { token -> api.createUpload(token, accountId.value, request) }

    override suspend fun completeUpload(accountId: AwradId, assetId: AwradId): ApiResult<AudioAssetResult> =
        sessions.authorized { token -> api.completeUpload(token, accountId.value, assetId.value) }

    override suspend fun download(accountId: AwradId, assetId: AwradId): ApiResult<AudioDownloadLink> =
        sessions.authorized { token -> api.download(token, accountId.value, assetId.value) }

    override suspend fun usage(accountId: AwradId): ApiResult<AudioUsageBody> =
        sessions.authorized { token -> api.usage(token, accountId.value) }
}
