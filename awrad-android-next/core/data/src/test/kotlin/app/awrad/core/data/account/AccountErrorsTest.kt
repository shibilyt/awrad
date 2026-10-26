package app.awrad.core.data.account

import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.InputProblem
import app.awrad.core.network.api.ApiFailure
import app.awrad.core.network.api.ApiOperation
import app.awrad.core.network.api.FieldError
import app.awrad.core.network.api.Problem
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AccountErrorsTest {

    private fun problem(code: String, vararg fieldCodes: String) = Problem(
        status = 422,
        code = code,
        errors = fieldCodes.map { FieldError(field = "/password", code = it, detail = "") },
    )

    @Test
    fun `every error code the app's operations document has its own domain error`() {
        val operations = operations()
        val codes = ApiOperation.entries.flatMap { operation ->
            operations.getValue(operation.operationId)
                .getValue("x-error-codes")
                .jsonArray
                .map { it.jsonPrimitive.content }
        }.toSet()

        val unmapped = codes.filter { accountErrorOf(problem(it), null) == AccountError.Unexpected }

        assertTrue(codes.isNotEmpty())
        assertTrue(unmapped.isEmpty(), "Codes without their own error: $unmapped")
    }

    @Test
    fun `every field code the app's operations document becomes an input problem`() {
        val operations = operations()
        val fieldCodes = ApiOperation.entries.flatMap { operation ->
            val spec = operations.getValue(operation.operationId)
            val topLevel = spec.getValue("x-error-codes").jsonArray.map { it.jsonPrimitive.content }.toSet()
            val response = spec.getValue("responses").jsonObject["422"]?.let(::resolve)?.jsonObject
            val described = response?.get("description")?.jsonPrimitive?.content.orEmpty()
                .let { BACKTICKED.findAll(it).map { match -> match.groupValues[1] }.toList() }
            // The shared generic 422 example names a goal field; only fields of this request count.
            val fields = requestFieldsOf(spec)
            val examples = response?.let { examplesOf(it) }.orEmpty()
                .flatMap { it.jsonObject["errors"]?.jsonArray.orEmpty() }
                .map { it.jsonObject }
                .filter { error -> error.getValue("field").jsonPrimitive.content.split('/')[1] in fields }
                .map { it.getValue("code").jsonPrimitive.content }
            (described + examples).filterNot { it in topLevel }
        }.toSet()

        // Device details are set by the app, not typed by a person: those codes mean an app bug and stay generic.
        val unmapped = fieldCodes.filter { inputProblemOf(it) == null && it !in DEVICE_FIELD_CODES }

        assertTrue("current_password_incorrect" in fieldCodes && "email_unchanged" in fieldCodes, "$fieldCodes")
        assertTrue(unmapped.isEmpty(), "Field codes without an input problem: $unmapped")
    }

    @Test
    fun `validation field codes become input problems and unknown ones are dropped`() {
        val error = accountErrorOf(
            problem(
                "validation_failed",
                "email_invalid",
                "password_too_short",
                "password_too_long",
                "password_too_common",
                "code_invalid",
                "current_password_incorrect",
                "email_unchanged",
                "installation_id_invalid",
                "something_new",
            ),
            null,
        )

        assertEquals(AccountError.InvalidInput(InputProblem.entries.toSet()), error)
    }

    @Test
    fun `account settings problems have their own errors`() {
        assertEquals(AccountError.EmailChangeCodeInvalid, accountErrorOf(problem("email_change_code_invalid"), null))
        assertEquals(AccountError.EmailTaken, accountErrorOf(problem("email_taken"), null))
        assertEquals(AccountError.NotFound, accountErrorOf(problem("not_found"), null))
        assertEquals(AccountError.SessionEnded, accountErrorOf(ApiFailure.NotSignedIn))
    }

    @Test
    fun `codes decide, not statuses`() {
        val rateLimited = ApiFailure.ProblemResponse(problem("rate_limited"), retryAfterSeconds = 30)
        assertEquals(AccountError.RateLimited(30), accountErrorOf(rateLimited))
        assertEquals(AccountError.SessionEnded, accountErrorOf(problem("refresh_reuse_detected"), null))
        assertEquals(AccountError.Unexpected, accountErrorOf(problem("a_code_from_the_future"), null))
        assertEquals(AccountError.NoConnection, accountErrorOf(ApiFailure.NoConnection))
        assertEquals(AccountError.Unexpected, accountErrorOf(ApiFailure.UnexpectedResponse(502)))
    }

    private val spec: JsonObject by lazy { Json.parseToJsonElement(specFile().readText()).jsonObject }

    private fun operations(): Map<String, JsonObject> = spec.getValue("paths").jsonObject.values
        .flatMap { it.jsonObject.values }
        .filterIsInstance<JsonObject>()
        .associateBy { it.getValue("operationId").jsonPrimitive.content }

    /** Follows a local `$ref`. */
    private fun resolve(element: JsonElement): JsonElement {
        val ref = (element as? JsonObject)?.get("\$ref")?.jsonPrimitive?.content ?: return element
        val target = ref.removePrefix("#/").split('/')
            .fold<String, JsonElement>(spec) { node, key -> node.jsonObject.getValue(key) }
        return resolve(target)
    }

    /** The top-level property names of the operation's JSON request body. */
    private fun requestFieldsOf(operation: JsonObject): Set<String> = operation["requestBody"]
        ?.let { resolve(it).jsonObject["content"]?.jsonObject?.get("application/json")?.jsonObject?.get("schema") }
        ?.let { resolve(it).jsonObject["properties"]?.jsonObject?.keys }
        .orEmpty()

    private fun examplesOf(response: JsonObject): List<JsonElement> =
        response["content"]?.jsonObject.orEmpty().values.mapNotNull { it.jsonObject["example"] }

    private fun specFile(): File {
        val relative = "contracts/api/openapi.bundled.json"
        val start = File(checkNotNull(System.getProperty("user.dir"))).absoluteFile
        val root = generateSequence(start) { it.parentFile }.firstOrNull { File(it, relative).isFile }
        return File(checkNotNull(root) { "No $relative found above $start" }, relative)
    }

    private companion object {
        /** A snake_case code in backticks, as the spec's response descriptions name field codes. */
        val BACKTICKED = Regex("`([a-z_]+)`")

        /** Field codes for `device` details in `create_device_session`, which no person can correct. */
        val DEVICE_FIELD_CODES = setOf("installation_id_invalid", "device_name_invalid", "platform_invalid")
    }
}
