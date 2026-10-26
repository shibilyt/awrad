package app.awrad.core.domain.account

import app.awrad.core.testing.FakeAccountSettingsRepository
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals

class AccountSessionTest {

    @Test
    fun `this device comes first, then the most recently used`() {
        val (phone, browser) = FakeAccountSettingsRepository.SESSIONS
        val older = browser.copy(lastSeenAt = Instant.parse("2026-10-01T00:00:00Z"))
        val newest = browser.copy(lastSeenAt = Instant.parse("2026-10-28T00:00:00Z"))

        assertEquals(listOf(phone, newest, browser, older), listOf(older, browser, phone, newest).inListOrder())
    }
}
