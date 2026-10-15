package app.awrad.core.domain.goal

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class DailyTargetTest {

    @Test
    fun `clamps below the minimum and above the maximum`() {
        assertEquals(DailyTarget.MIN, DailyTarget.of(0).count)
        assertEquals(DailyTarget.MIN, DailyTarget.of(-50).count)
        assertEquals(DailyTarget.MAX, DailyTarget.of(DailyTarget.MAX + 1).count)
    }

    @Test
    fun `stepping stays inside the range`() {
        assertEquals(DailyTarget.MIN, (DailyTarget.of(DailyTarget.MIN) + -1).count)
        assertEquals(71, (DailyTarget.of(70) + 1).count)
    }

    @Test
    fun `stepper affordances follow the bounds`() {
        assertFalse(DailyTarget.of(DailyTarget.MIN).canDecrease)
        assertFalse(DailyTarget.of(DailyTarget.MAX).canIncrease)
        assertTrue(DailyTarget.of(70).canDecrease)
        assertTrue(DailyTarget.of(70).canIncrease)
    }
}
