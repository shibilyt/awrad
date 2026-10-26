package app.awrad.core.network.api

import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.test.fail

/**
 * Drift protection for the hand-written API classes (root ADR-2026-10-16): every operation the app uses is
 * checked against `contracts/api/openapi.bundled.json`, and every request and response example of those
 * operations is decoded and re-encoded through the app's classes with no difference.
 */
class ApiContractTest {

    private val spec: JsonObject = Json.parseToJsonElement(specFile().toFile().readText()).jsonObject

    /** Unknown fields fail here (unlike in the app), so a field the classes miss shows up as a difference. */
    private val strictJson = Json(from = ApiJson) { ignoreUnknownKeys = false }

    /** The request body and success body classes of each operation the app uses; null = no body. */
    private val bodies: Map<ApiOperation, Pair<KSerializer<*>?, KSerializer<*>?>> = mapOf(
        ApiOperation.REGISTER_ACCOUNT to (RegisterAccountRequest.serializer() to null),
        ApiOperation.VERIFY_ACCOUNT_EMAIL to (VerifyAccountEmailRequest.serializer() to null),
        ApiOperation.RESEND_VERIFICATION_CODE to (EmailOnlyRequest.serializer() to null),
        ApiOperation.REQUEST_PASSWORD_RESET to (EmailOnlyRequest.serializer() to null),
        ApiOperation.RESET_PASSWORD to (ResetPasswordRequest.serializer() to null),
        ApiOperation.GET_CURRENT_ACCOUNT to (null to AccountResponse.serializer()),
        ApiOperation.CREATE_DEVICE_SESSION to
            (CreateDeviceSessionRequest.serializer() to DeviceSessionGrant.serializer()),
        ApiOperation.REFRESH_DEVICE_SESSION to
            (RefreshTokenRequest.serializer() to DeviceSessionGrant.serializer()),
        ApiOperation.SIGN_OUT_DEVICE_SESSION to (RefreshTokenRequest.serializer() to null),
        ApiOperation.LIST_ACCOUNT_SESSIONS to (null to AccountSessionPage.serializer()),
        ApiOperation.REVOKE_ACCOUNT_SESSION to (null to null),
        ApiOperation.REVOKE_OTHER_ACCOUNT_SESSIONS to (null to null),
        ApiOperation.CHANGE_PASSWORD to (ChangePasswordRequest.serializer() to null),
        ApiOperation.REQUEST_EMAIL_CHANGE to (RequestEmailChangeRequest.serializer() to null),
        ApiOperation.CONFIRM_EMAIL_CHANGE to (ConfirmEmailChangeRequest.serializer() to AccountResponse.serializer()),
        ApiOperation.DELETE_ACCOUNT to (CurrentPasswordRequest.serializer() to null),
    )

    @Test
    fun `every operation the app uses has its body classes listed`() {
        assertEquals(ApiOperation.entries.toSet(), bodies.keys)
    }

    @Test
    fun `every operation the app uses matches the spec`() {
        val failures = ApiOperation.entries.flatMap { operation ->
            val (method, path, spec) = find(operation.operationId)
            val parameters = spec["parameters"]?.jsonArray.orEmpty().map { resolve(it).jsonObject }
            val headers = parameters.filter { it.string("in") == "header" }.map { it.string("name") }.toSet()
            val security = spec.getValue("security").jsonArray.map { it.jsonObject.keys }
            listOfNotNull(
                "method $method".takeIf { method != operation.method.name.lowercase() },
                "path $path".takeIf { path != operation.path },
                "security $security".takeIf { operation.isPublic != security.isEmpty() },
                // The bearer token alone must be enough: mobile never sends a cookie or CSRF token.
                "no bearerAuth".takeIf { !operation.isPublic && security.none { it == setOf("bearerAuth") } },
                "Accept-Language".takeIf { operation.sendsLanguage != ("Accept-Language" in headers) },
                "Idempotency-Key".takeIf { operation.idempotent != ("Idempotency-Key" in headers) },
            ).map { "${operation.operationId}: $it differs from the spec" }
        }
        assertTrue(failures.isEmpty(), failures.joinToString("\n"))
    }

    @Test
    fun `every example of the operations the app uses round-trips unchanged`() {
        var checked = 0
        val failures = ApiOperation.entries.flatMap { operation ->
            val (_, _, spec) = find(operation.operationId)
            val (requestBody, successBody) = bodies.getValue(operation)
            val request = spec["requestBody"]?.let { resolve(it).jsonObject }
            val requestFailures = when {
                request == null && requestBody == null -> emptyList()
                request == null || requestBody == null -> listOf("request body: spec and app disagree")
                else -> examples(request).map { (media, example) ->
                    checked++
                    roundTrip("request $media", requestBody, example)
                }
            }
            val responseFailures = spec.getValue("responses").jsonObject.flatMap { (status, value) ->
                val response = resolve(value).jsonObject
                val isSuccess = status.startsWith("2")
                val serializer = if (isSuccess) successBody else Problem.serializer()
                val content = examples(response)
                when {
                    content.isEmpty() && serializer != null && isSuccess -> listOf("$status: the spec has no body")
                    content.isNotEmpty() && serializer == null -> listOf("$status: the app ignores a body")
                    else -> content.map { (media, example) ->
                        checked++
                        roundTrip("$status $media", serializer!!, example)
                    }
                }
            }
            (requestFailures + responseFailures).filterNotNull().map { "${operation.operationId} $it" }
        }
        assertTrue(failures.isEmpty(), failures.joinToString("\n"))
        println("contracts/api: $checked examples round-tripped")
    }

    /** Every media type's example; fails when one has none (STYLE §15 requires examples). */
    private fun examples(body: JsonObject): List<Pair<String, JsonElement>> =
        body["content"]?.jsonObject.orEmpty().map { (media, value) ->
            media to (value.jsonObject["example"] ?: fail("$media has no example"))
        }

    @Suppress("UNCHECKED_CAST")
    private fun roundTrip(label: String, serializer: KSerializer<*>, example: JsonElement): String? {
        val typed = serializer as KSerializer<Any?>
        val encoded = runCatching {
            strictJson.encodeToJsonElement(typed, strictJson.decodeFromJsonElement(typed, example))
        }
        return encoded.fold(
            onSuccess = { if (it == example) null else "$label: expected $example, got $it" },
            onFailure = { "$label: $it" },
        )
    }

    private fun find(operationId: String): Triple<String, String, JsonObject> {
        spec.getValue("paths").jsonObject.forEach { (path, item) ->
            item.jsonObject.forEach { (method, operation) ->
                if ((operation as? JsonObject)?.get("operationId")?.jsonPrimitive?.content == operationId) {
                    return Triple(method, path, operation)
                }
            }
        }
        fail("$operationId isn't in the spec")
    }

    /** Follows a local `$ref` (`#/components/...`). */
    private fun resolve(element: JsonElement): JsonElement {
        val ref = (element as? JsonObject)?.get("\$ref")?.jsonPrimitive?.content ?: return element
        check(ref.startsWith("#/")) { "Only local refs are bundled: $ref" }
        val target = ref.removePrefix("#/").split('/')
            .fold<String, JsonElement>(spec) { node, key -> node.jsonObject.getValue(key) }
        return resolve(target)
    }

    private fun JsonObject.string(key: String): String = getValue(key).jsonPrimitive.content

    private fun specFile(): Path {
        val relative = "contracts/api/openapi.bundled.json"
        val start = Paths.get(System.getProperty("user.dir")).toAbsolutePath()
        val root = generateSequence(start) { it.parent }.firstOrNull { Files.isRegularFile(it.resolve(relative)) }
        return checkNotNull(root) { "No $relative found above $start" }.resolve(relative)
    }
}
