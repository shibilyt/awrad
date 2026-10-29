package app.awrad.core.network.api

import app.awrad.core.network.IdGenerator
import app.awrad.core.network.http.HttpTransport

/**
 * Private audio for custom dhikrs (tag `audio`, slice 3c). The bytes never pass through here: these four
 * operations only reserve, confirm and link, and `SignedLinkTransport` moves the file to and from storage.
 * Every operation needs the access token and the account the recordings belong to (`accountId`, sent as
 * `X-Awrad-Account`; the server answers `409 account_mismatch` for any other).
 */
public class AudioApi(transport: HttpTransport, ids: IdGenerator, language: AppLanguage) {
    private val caller = ApiCaller(transport, ids, language)

    /**
     * Reserves an upload of [request]'s file and answers with its signed PUT link ([AudioUploadReservation.Pending]),
     * or with the asset when the request's `assetId` is already ready ([AudioUploadReservation.Ready]).
     */
    public suspend fun createUpload(
        accessToken: String,
        accountId: String,
        request: AudioUploadRequest,
    ): ApiResult<AudioUploadReservation> = caller.send(
        ApiOperation.CREATE_AUDIO_UPLOAD,
        request,
        AudioUploadRequest.serializer(),
        AudioUploadReservationSerializer,
        CallOptions(accessToken = accessToken, accountId = accountId),
    )

    /** Confirms that the file for [assetId] is in storage; the server checks it and answers with the ready asset. */
    public suspend fun completeUpload(
        accessToken: String,
        accountId: String,
        assetId: String,
    ): ApiResult<AudioAssetResult> = caller.send<Unit, AudioAssetResult>(
        ApiOperation.COMPLETE_AUDIO_UPLOAD,
        Unit,
        null,
        AudioAssetResult.serializer(),
        CallOptions(accessToken = accessToken, accountId = accountId, pathParameters = mapOf(ASSET_ID to assetId)),
    )

    /** A signed GET link to the ready asset [assetId]. Ask for a new one each time; don't store it. */
    public suspend fun download(
        accessToken: String,
        accountId: String,
        assetId: String,
    ): ApiResult<AudioDownloadLink> = caller.send<Unit, AudioDownloadLink>(
        ApiOperation.GET_AUDIO_DOWNLOAD,
        Unit,
        null,
        AudioDownloadLink.serializer(),
        CallOptions(accessToken = accessToken, accountId = accountId, pathParameters = mapOf(ASSET_ID to assetId)),
    )

    /** The bytes the account's recordings use, and its limit. */
    public suspend fun usage(accessToken: String, accountId: String): ApiResult<AudioUsage> =
        caller.send<Unit, AudioUsage>(
            ApiOperation.GET_AUDIO_USAGE,
            Unit,
            null,
            AudioUsage.serializer(),
            CallOptions(accessToken = accessToken, accountId = accountId),
        )

    private companion object {
        const val ASSET_ID = "asset_id"
    }
}
