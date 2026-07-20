package app.awrad.awrad_dhikrgoalstracker.ui.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AuthVerificationLinkTest {
    @Test
    fun parsesCustomLegacyAndMobileLinksForConfiguredHost() {
        assertEquals(
            "custom-token",
            AuthVerificationLink.token(
                "awrad://verify-email?token=custom-token",
                "api.awrad.app",
            ),
        )
        assertEquals(
            "legacy-token",
            AuthVerificationLink.token(
                "https://api.awrad.app/auth/verify-email/legacy-token",
                "api.awrad.app",
            ),
        )
        assertEquals(
            "mobile-token",
            AuthVerificationLink.token(
                "https://api.awrad.app/auth/mobile/verify-email/mobile-token",
                "api.awrad.app",
            ),
        )
    }

    @Test
    fun rejectsOtherHostsPathsAndMissingTokens() {
        assertNull(
            AuthVerificationLink.token(
                "https://attacker.example/auth/mobile/verify-email/token",
                "api.awrad.app",
            ),
        )
        assertNull(
            AuthVerificationLink.token(
                "https://api.awrad.app/users/reset-password/token",
                "api.awrad.app",
            ),
        )
        assertNull(
            AuthVerificationLink.token("awrad://verify-email", "api.awrad.app"),
        )
    }
}
