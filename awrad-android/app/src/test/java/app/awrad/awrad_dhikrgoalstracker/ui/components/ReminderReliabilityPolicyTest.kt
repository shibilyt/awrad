package app.awrad.awrad_dhikrgoalstracker.ui.components

import app.awrad.awrad_dhikrgoalstracker.notification.OemBatteryInfo
import app.awrad.awrad_dhikrgoalstracker.notification.OemBatteryType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReminderReliabilityPolicyTest {

    @Test
    fun `no required actions when exact alarms and battery exemption are already allowed`() {
        val state = ReminderReliabilityUiState(
            canScheduleExactAlarms = true,
            isIgnoringBatteryOptimizations = true,
            oemBatteryInfo = null,
        )

        assertEquals(emptyList<ReminderReliabilityAction>(), ReminderReliabilityPolicy.requiredSystemActions(state))
        assertFalse(ReminderReliabilityPolicy.hasRequiredSystemActions(state))
        assertFalse(ReminderReliabilityPolicy.shouldShowOemGuide(state))
    }

    @Test
    fun `exact alarm action is only required when exact scheduling is unavailable`() {
        val state = ReminderReliabilityUiState(
            canScheduleExactAlarms = false,
            isIgnoringBatteryOptimizations = true,
        )

        assertEquals(
            listOf(ReminderReliabilityAction.ExactAlarmSettings),
            ReminderReliabilityPolicy.requiredSystemActions(state),
        )
    }

    @Test
    fun `battery action is only required when Android is optimizing the app`() {
        val state = ReminderReliabilityUiState(
            canScheduleExactAlarms = true,
            isIgnoringBatteryOptimizations = false,
        )

        assertEquals(
            listOf(ReminderReliabilityAction.BatteryOptimizationSettings),
            ReminderReliabilityPolicy.requiredSystemActions(state),
        )
    }

    @Test
    fun `OEM guidance is advisory and does not add a system settings action`() {
        val state = ReminderReliabilityUiState(
            canScheduleExactAlarms = true,
            isIgnoringBatteryOptimizations = true,
            oemBatteryInfo = OemBatteryInfo(
                type = OemBatteryType.SAMSUNG,
                dontKillMyAppUrl = "https://dontkillmyapp.com/samsung",
            ),
        )

        assertEquals(emptyList<ReminderReliabilityAction>(), ReminderReliabilityPolicy.requiredSystemActions(state))
        assertTrue(ReminderReliabilityPolicy.shouldShowOemGuide(state))
    }
}
