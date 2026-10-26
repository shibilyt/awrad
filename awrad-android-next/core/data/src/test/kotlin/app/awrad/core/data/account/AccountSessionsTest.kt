package app.awrad.core.data.account

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.account.AccountSession
import app.awrad.core.network.api.AccountSessionResponse
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class AccountSessionsTest {

    private val browser = AccountSessionResponse(
        id = "4c2e8f10-7b3a-4d5e-9f61-2a8b0c1d3e45",
        kind = "browser",
        name = "Firefox on Windows",
        platform = "web",
        createdAt = "2026-10-20T18:00:00Z",
        lastSeenAt = "2026-10-26T21:15:00Z",
        isCurrent = false,
    )

    @Test
    fun `a session maps field by field`() {
        assertEquals(
            AccountSession(
                id = AwradId("4c2e8f10-7b3a-4d5e-9f61-2a8b0c1d3e45"),
                kind = AccountSession.Kind.BROWSER,
                name = "Firefox on Windows",
                platform = AccountSession.Platform.WEB,
                createdAt = Instant.parse("2026-10-20T18:00:00Z"),
                lastSeenAt = Instant.parse("2026-10-26T21:15:00Z"),
                isCurrent = false,
            ),
            accountSessionOf(browser),
        )
    }

    @Test
    fun `unknown kinds and platforms are OTHER, and a blank name is no name`() {
        val session = accountSessionOf(browser.copy(kind = "watch", platform = "wearos", name = " "))

        assertEquals(AccountSession.Kind.OTHER, session?.kind)
        assertEquals(AccountSession.Platform.OTHER, session?.platform)
        assertNull(session?.name)
    }

    @Test
    fun `an unreadable timestamp makes the session unreadable`() {
        assertNull(accountSessionOf(browser.copy(lastSeenAt = "yesterday")))
    }
}
