package app.awrad.core.network.api

import app.awrad.core.network.FakeTransport
import app.awrad.core.network.Responses
import app.awrad.core.network.SequentialIds
import app.awrad.core.network.http.HttpMethod
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull

class AudioApiTest {

    private val transport = FakeTransport()
    private val api = AudioApi(transport, SequentialIds()) { "en" }
    private val account = "0192f0b0-0000-7000-8000-000000000001"
    private val assetId = "0192f0e0-0000-7000-8000-000000000001"
    private val request = AudioUploadRequest(assetId, 4_182_733, "audio/mpeg", "7959650f".repeat(8))

    @Test
    fun `every operation sends the bearer token, the account, its method and the filled path`() = runTest {
        transport.on(ApiOperation.CREATE_AUDIO_UPLOAD.path) { Responses.json(201, PENDING) }
        transport.on("/api/v1/audio_uploads/$assetId/complete") { Responses.json(200, READY) }
        transport.on("/api/v1/audio_assets/$assetId/download") {
            Responses.json(200, """{"url": "https://r2.example/get?sig=x", "expires_at": "2026-10-29T09:10:00Z"}""")
        }
        transport.on(ApiOperation.GET_AUDIO_USAGE.path) {
            Responses.json(200, """{"used_bytes": 120482733, "limit_bytes": 500000000}""")
        }

        api.createUpload("access", account, request)
        api.completeUpload("access", account, assetId)
        api.download("access", account, assetId)
        api.usage("access", account)

        assertEquals(
            listOf(
                HttpMethod.POST to "/api/v1/audio_uploads",
                HttpMethod.POST to "/api/v1/audio_uploads/$assetId/complete",
                HttpMethod.GET to "/api/v1/audio_assets/$assetId/download",
                HttpMethod.GET to "/api/v1/audio_assets/usage",
            ),
            transport.requests.map { it.method to it.path },
        )
        for (sent in transport.requests) {
            assertEquals("Bearer access", sent.headers["Authorization"])
            assertEquals(account, sent.headers["X-Awrad-Account"])
            assertNull(sent.headers["Accept-Language"])
        }
    }

    @Test
    fun `create sends the request as JSON`() = runTest {
        transport.on(ApiOperation.CREATE_AUDIO_UPLOAD.path) { Responses.json(201, PENDING) }

        api.createUpload("access", account, request)

        val body = Json.parseToJsonElement(transport.requests.single().body!!).jsonObject
        assertEquals(setOf("asset_id", "byte_size", "content_type", "sha256"), body.keys)
        assertEquals(assetId, body.getValue("asset_id").jsonPrimitive.content)
        assertEquals("4182733", body.getValue("byte_size").jsonPrimitive.content)
        assertEquals("audio/mpeg", body.getValue("content_type").jsonPrimitive.content)
    }

    @Test
    fun `a new upload decodes as pending with the headers to send`() = runTest {
        transport.on(ApiOperation.CREATE_AUDIO_UPLOAD.path) { Responses.json(201, PENDING) }

        val result = api.createUpload("access", account, request)

        val pending = assertIs<AudioUploadReservation.Pending>((result as ApiResult.Success).value)
        assertEquals(assetId, pending.link.assetId)
        assertEquals("https://r2.example/put?sig=x", pending.link.uploadUrl)
        assertEquals(
            mapOf("content-type" to "audio/mpeg", "x-amz-checksum-sha256" to CHECKSUM),
            pending.link.uploadHeaders,
        )
        assertEquals("2026-10-29T08:15:00Z", pending.link.expiresAt)
    }

    @Test
    fun `an upload that is already ready decodes as ready`() = runTest {
        transport.on(ApiOperation.CREATE_AUDIO_UPLOAD.path) { Responses.json(200, READY) }

        val result = api.createUpload("access", account, request)

        val ready = assertIs<AudioUploadReservation.Ready>((result as ApiResult.Success).value)
        assertEquals(AudioAsset(assetId, 4_182_733, "audio/mpeg", "ready", "2026-10-29T08:01:12Z"), ready.asset)
    }

    @Test
    fun `a body that is neither shape is an unexpected response`() = runTest {
        transport.on(ApiOperation.CREATE_AUDIO_UPLOAD.path) { Responses.json(200, """{"other": 1}""") }

        val result = api.createUpload("access", account, request)

        assertEquals(ApiFailure.UnexpectedResponse(200), (result as ApiResult.Failure).failure)
    }

    @Test
    fun `storage_full carries the used bytes and the limit`() = runTest {
        transport.on(ApiOperation.CREATE_AUDIO_UPLOAD.path) {
            Responses.json(
                422,
                """{"type":"urn:awrad:problem:storage_full","title":"Storage full","status":422,"code":"storage_full",
                    |"detail":"d","errors":[],"used_bytes":497300000,"limit_bytes":500000000}
                """.trimMargin(),
            )
        }

        val result = api.createUpload("access", account, request)

        val problem = assertIs<ApiFailure.ProblemResponse>((result as ApiResult.Failure).failure).problem
        assertEquals("storage_full", problem.code)
        assertEquals(497_300_000L, problem.usedBytes)
        assertEquals(500_000_000L, problem.limitBytes)
    }

    @Test
    fun `other create problems decode by code and status`() = runTest {
        transport.on(ApiOperation.CREATE_AUDIO_UPLOAD.path) { Responses.problem(413, "file_too_large") }
        assertProblem(413, "file_too_large", api.createUpload("access", account, request))

        transport.on(ApiOperation.CREATE_AUDIO_UPLOAD.path) { Responses.problem(415, "unsupported_audio_type") }
        assertProblem(415, "unsupported_audio_type", api.createUpload("access", account, request))

        transport.on(ApiOperation.CREATE_AUDIO_UPLOAD.path) { Responses.problem(422, "invalid_size") }
        val invalid = api.createUpload("access", account, request)
        assertProblem(422, "invalid_size", invalid)
        val problem = ((invalid as ApiResult.Failure).failure as ApiFailure.ProblemResponse).problem
        assertNull(problem.usedBytes)
        assertNull(problem.limitBytes)

        transport.on(ApiOperation.CREATE_AUDIO_UPLOAD.path) { Responses.problem(409, "asset_id_in_use") }
        assertProblem(409, "asset_id_in_use", api.createUpload("access", account, request))
    }

    @Test
    fun `complete sends no body and decodes the ready asset`() = runTest {
        transport.on("/api/v1/audio_uploads/$assetId/complete") { Responses.json(200, READY) }

        val result = api.completeUpload("access", account, assetId)

        assertNull(transport.requests.single().body)
        assertEquals(assetId, (result as ApiResult.Success).value.asset.assetId)
        assertEquals("ready", result.value.asset.status)
    }

    @Test
    fun `complete problems decode`() = runTest {
        val path = "/api/v1/audio_uploads/$assetId/complete"
        transport.on(path) { Responses.problem(409, "upload_incomplete") }
        assertProblem(409, "upload_incomplete", api.completeUpload("access", account, assetId))

        transport.on(path) { Responses.problem(422, "upload_mismatch") }
        assertProblem(422, "upload_mismatch", api.completeUpload("access", account, assetId))

        transport.on(path) { Responses.problem(404, "not_found") }
        assertProblem(404, "not_found", api.completeUpload("access", account, assetId))
    }

    @Test
    fun `download and usage decode their answers`() = runTest {
        transport.on("/api/v1/audio_assets/$assetId/download") {
            Responses.json(200, """{"url": "https://r2.example/get?sig=x", "expires_at": "2026-10-29T09:10:00Z"}""")
        }
        transport.on(ApiOperation.GET_AUDIO_USAGE.path) {
            Responses.json(200, """{"used_bytes": 120482733, "limit_bytes": 500000000}""")
        }

        val link = api.download("access", account, assetId)
        val usage = api.usage("access", account)

        val expectedLink = AudioDownloadLink("https://r2.example/get?sig=x", "2026-10-29T09:10:00Z")
        assertEquals(expectedLink, (link as ApiResult.Success).value)
        assertEquals(AudioUsage(120_482_733, 500_000_000), (usage as ApiResult.Success).value)
        assertNull(transport.requests.first().body)
    }

    private fun assertProblem(status: Int, code: String, result: ApiResult<*>) {
        val failure = assertIs<ApiFailure.ProblemResponse>((result as ApiResult.Failure).failure)
        assertEquals(code, failure.problem.code)
        assertEquals(status, failure.status)
    }

    private companion object {
        const val CHECKSUM = "eVllD5+mm2J5s2lOJQYFnLZwYswPfprSejRlKNNB5bw="
        const val PENDING = """{"asset_id":"0192f0e0-0000-7000-8000-000000000001",
            "upload_url":"https://r2.example/put?sig=x",
            "upload_headers":{"content-type":"audio/mpeg","x-amz-checksum-sha256":"$CHECKSUM"},
            "expires_at":"2026-10-29T08:15:00Z"}"""
        const val READY = """{"asset":{"asset_id":"0192f0e0-0000-7000-8000-000000000001","byte_size":4182733,
            "content_type":"audio/mpeg","status":"ready","created_at":"2026-10-29T08:01:12Z"}}"""
    }
}
