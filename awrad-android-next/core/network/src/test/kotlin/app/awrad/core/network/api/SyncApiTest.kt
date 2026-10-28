package app.awrad.core.network.api

import app.awrad.core.network.FakeTransport
import app.awrad.core.network.Responses
import app.awrad.core.network.SequentialIds
import app.awrad.core.network.http.HttpMethod
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

class SyncApiTest {

    private val transport = FakeTransport()
    private val api = SyncApi(transport, SequentialIds()) { "en" }
    private val account = "0192f0b0-0000-7000-8000-000000000001"

    @Test
    fun `both operations send the bearer token and the expected account`() = runTest {
        transport.on(ApiOperation.POST_SYNC_COMMANDS.path) {
            Responses.json(200, """{"receipts": [{"command_id": "c", "status": "gone"}], "head_revision": 3}""")
        }
        transport.on(ApiOperation.LIST_SYNC_CHANGES.path) {
            Responses.json(200, """{"changes": [], "next_after": 3, "has_more": false, "head_revision": 3}""")
        }

        api.postCommands("access", account, SyncCommandBatch(listOf(deleteCommand())))
        api.listChanges("access", account, after = 12, limit = 200)

        val (post, get) = transport.requests
        assertEquals(HttpMethod.POST, post.method)
        assertEquals(HttpMethod.GET, get.method)
        for (request in transport.requests) {
            assertEquals("Bearer access", request.headers["Authorization"])
            assertEquals(account, request.headers["X-Awrad-Account"])
        }
        assertEquals(mapOf("after" to "12", "limit" to "200"), get.query)
    }

    @Test
    fun `a delete is sent without a document and a put with one`() = runTest {
        transport.on(ApiOperation.POST_SYNC_COMMANDS.path) {
            Responses.json(200, """{"receipts": [{"command_id": "c", "status": "gone"}], "head_revision": 3}""")
        }
        val put = deleteCommand().copy(op = "put", document = Json.parseToJsonElement("""{"tag_ids": []}""").jsonObject)

        api.postCommands("access", account, SyncCommandBatch(listOf(deleteCommand(), put)))

        val body = Json.parseToJsonElement(transport.requests.single().body!!).jsonObject
        val commands = body.getValue("commands") as kotlinx.serialization.json.JsonArray
        val (delete, sentPut) = commands.map { it.jsonObject }
        assertTrue("document" !in delete)
        assertEquals(Json.parseToJsonElement("""{"tag_ids": []}"""), sentPut.getValue("document"))
    }

    @Test
    fun `account_mismatch is a problem response`() = runTest {
        transport.on(ApiOperation.LIST_SYNC_CHANGES.path) { Responses.problem(409, "account_mismatch") }

        val result = api.listChanges("access", account, after = 0, limit = 200)

        val failure = assertIs<ApiFailure.ProblemResponse>((result as ApiResult.Failure).failure)
        assertEquals("account_mismatch", failure.problem.code)
    }

    private fun deleteCommand() = SyncCommandBody(
        commandId = "0192f0c0-0000-7000-8000-000000000001",
        entityType = "user_tag",
        entityId = "0192f0a0-0000-7000-8000-000000000001",
        op = "delete",
        baseVersion = 2,
    )
}
