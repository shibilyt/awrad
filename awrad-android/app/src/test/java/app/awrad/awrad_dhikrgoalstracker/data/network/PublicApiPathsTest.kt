package app.awrad.awrad_dhikrgoalstracker.data.network

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PublicApiPathsTest {
    @Test
    fun `community stats is classified public while sync remains authenticated`() {
        assertTrue(PublicApiPaths.isPublic("/api/community/stats"))
        assertFalse(PublicApiPaths.isPublic("/api/sync/v1/progress/commands"))
    }
}
