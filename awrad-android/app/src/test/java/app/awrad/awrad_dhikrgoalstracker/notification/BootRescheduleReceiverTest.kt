package app.awrad.awrad_dhikrgoalstracker.notification

import android.content.Intent
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BootRescheduleReceiverTest {

    @Test
    fun trustedSystemActionsCanReschedule() {
        val actions = listOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            BootRescheduleReceiver.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
        )

        actions.forEach { action ->
            assertTrue(BootRescheduleReceiver.isTrustedRescheduleAction(action))
        }
    }

    @Test
    fun arbitraryActionsCannotReschedule() {
        assertFalse(BootRescheduleReceiver.isTrustedRescheduleAction("app.attacker.RESCHEDULE"))
        assertFalse(BootRescheduleReceiver.isTrustedRescheduleAction("com.htc.intent.action.QUICKBOOT_POWERON"))
    }
}
