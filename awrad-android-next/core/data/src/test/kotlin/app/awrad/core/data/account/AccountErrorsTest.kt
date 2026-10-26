package app.awrad.core.data.account

import app.awrad.core.domain.account.AccountError
import app.awrad.core.domain.account.InputProblem
import app.awrad.core.network.api.ApiFailure
import app.awrad.core.network.api.ApiOperation
import app.awrad.core.network.api.FieldError
import app.awrad.core.network.api.Problem
import kotlinx.serialization.json.Json
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
        val spec = Json.parseToJsonElement(specFile().readText()).jsonObject
        val operations = spec.getValue("paths").jsonObject.values
            .flatMap { it.jsonObject.values }
            .filterIsInstance<JsonObject>()
            .associateBy { it.getValue("operationId").jsonPrimitive.content }
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
    fun `validation field codes become input problems and unknown ones are dropped`() {
        val error = accountErrorOf(
            problem(
                "validation_failed",
                "email_invalid",
                "password_too_short",
                "password_too_long",
                "password_too_common",
                "something_new",
            ),
            null,
        )

        assertEquals(AccountError.InvalidInput(InputProblem.entries.toSet() - InputProblem.CODE_INVALID), error)
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

    private fun specFile(): File {
        val relative = "contracts/api/openapi.bundled.json"
        val start = File(checkNotNull(System.getProperty("user.dir"))).absoluteFile
        val root = generateSequence(start) { it.parentFile }.firstOrNull { File(it, relative).isFile }
        return File(checkNotNull(root) { "No $relative found above $start" }, relative)
    }
}
