package app.awrad.awrad_dhikrgoalstracker.ui.screens.counting

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SessionTargetPolicyTest {

    @Test
    fun `count session target cannot exceed full remaining goal target`() {
        val limit = SessionTargetPolicy.countLimit(targetCount = 70, currentCount = 0)

        assertEquals(70, limit)
        assertNull(SessionTargetPolicy.normalizeCountTarget(100, limit))
        assertEquals(70, SessionTargetPolicy.normalizeCountTarget(70, limit))
    }

    @Test
    fun `count session target cannot exceed partial remaining goal target`() {
        val limit = SessionTargetPolicy.countLimit(targetCount = 70, currentCount = 20)

        assertEquals(50, limit)
        assertNull(SessionTargetPolicy.normalizeCountTarget(70, limit))
        assertEquals(50, SessionTargetPolicy.normalizeCountTarget(50, limit))
    }

    @Test
    fun `count session target cannot start when no counts remain`() {
        val limit = SessionTargetPolicy.countLimit(targetCount = 70, currentCount = 70)

        assertEquals(0, limit)
        assertNull(SessionTargetPolicy.normalizeCountTarget(1, limit))
    }

    @Test
    fun `no target goal allows large count session target`() {
        val limit = SessionTargetPolicy.countLimit(targetCount = 0, currentCount = 20)

        assertNull(limit)
        assertEquals(1000, SessionTargetPolicy.normalizeCountTarget(1000, limit))
    }
}
