package app.awrad.core.domain.account

import app.awrad.core.testing.fixtures.FixtureRunner
import app.awrad.core.testing.fixtures.toFixtureName
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlin.test.Test

class EmailInputFixtureTest {

    @Test
    fun `every email_input fixture case passes`() {
        FixtureRunner.runAccountModel("email_input") { given ->
            val email = EmailAddress.parse(given.getValue("input").jsonPrimitive.content)
            buildJsonObject {
                put("valid", email != null)
                put("email", email?.value?.let(::JsonPrimitive) ?: JsonNull)
            }
        }
    }
}

class PasswordPolicyFixtureTest {

    @Test
    fun `every password_policy fixture case passes`() {
        FixtureRunner.runAccountModel("password_policy") { given ->
            val errors = PasswordPolicy.errors(given.getValue("password").jsonPrimitive.content)
                .map { it.toFixtureName() }
                .sorted()
            buildJsonObject {
                put("valid", errors.isEmpty())
                putJsonArray("errors") { errors.forEach { add(it) } }
            }
        }
    }
}

class EmailCodeInputFixtureTest {

    @Test
    fun `every email_code_input fixture case passes`() {
        FixtureRunner.runAccountModel("email_code_input") { given ->
            val code = EmailCode.parse(given.getValue("input").jsonPrimitive.content)
            buildJsonObject {
                put("code", code?.value?.let(::JsonPrimitive) ?: JsonNull)
            }
        }
    }
}
