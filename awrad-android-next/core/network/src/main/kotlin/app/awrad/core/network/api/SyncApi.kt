package app.awrad.core.network.api

import app.awrad.core.network.IdGenerator
import app.awrad.core.network.http.HttpTransport

/**
 * The change queue's two operations (tag `sync`). Both need the access token and the account the data belongs to
 * ([accountId], sent as `X-Awrad-Account`): the server refuses a request for any other account with
 * `409 account_mismatch`, reading and writing nothing.
 */
public class SyncApi(transport: HttpTransport, ids: IdGenerator, language: AppLanguage) {
    private val caller = ApiCaller(transport, ids, language)

    /** Sends 1 to 100 commands; the receipts come back in the same order. */
    public suspend fun postCommands(
        accessToken: String,
        accountId: String,
        batch: SyncCommandBatch,
    ): ApiResult<SyncReceiptBatch> = caller.send(
        ApiOperation.POST_SYNC_COMMANDS,
        batch,
        SyncCommandBatch.serializer(),
        SyncReceiptBatch.serializer(),
        CallOptions(accessToken = accessToken, accountId = accountId),
    )

    /** One page of the changes after revision [after] (0 for a full download). */
    public suspend fun listChanges(
        accessToken: String,
        accountId: String,
        after: Long,
        limit: Int,
    ): ApiResult<SyncChangesPage> = caller.send<Unit, SyncChangesPage>(
        ApiOperation.LIST_SYNC_CHANGES,
        Unit,
        null,
        SyncChangesPage.serializer(),
        CallOptions(
            accessToken = accessToken,
            accountId = accountId,
            query = mapOf("after" to after.toString(), "limit" to limit.toString()),
        ),
    )
}
