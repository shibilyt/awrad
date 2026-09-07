package app.awrad.awrad_dhikrgoalstracker.data.repository

import org.junit.Assert.assertEquals
import org.junit.Test

class AuthRepositoryTest {
    @Test
    fun `password setup error maps to a recoverable mobile login state`() {
        val result = mapLoginError(
            email = "person@example.com",
            message = "password setup required",
            errorCode = "password_setup_required",
        )

        assertEquals(
            AuthResult.PasswordSetupRequired("person@example.com"),
            result,
        )
    }

    @Test
    fun `unknown login errors remain ordinary credential errors`() {
        val result = mapLoginError(
            email = "person@example.com",
            message = "invalid email or password",
            errorCode = null,
        )

        assertEquals(AuthResult.Error("invalid email or password"), result)
    }
}
