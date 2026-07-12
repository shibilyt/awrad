package app.awrad.awrad_dhikrgoalstracker.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import androidx.core.content.ContextCompat
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.service.DhikrCountingService
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Tests that notification channels and icons are configured correctly.
 * These are plain instrumented tests with no Hilt dependency.
 */
@RunWith(AndroidJUnit4::class)
class NotificationChannelTest {

    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val manager get() = context.getSystemService(NotificationManager::class.java)

    @Test
    fun goalRemindersChannel_createsWithHighImportance() {
        val channel = NotificationChannel(
            WorkerKeys.CHANNEL_GOAL_REMINDERS,
            "Reminders",
            NotificationManager.IMPORTANCE_HIGH,
        )
        manager.createNotificationChannel(channel)

        val retrieved = manager.getNotificationChannel(WorkerKeys.CHANNEL_GOAL_REMINDERS)
        assertNotNull("Reminders channel should exist", retrieved)
        assertEquals(WorkerKeys.CHANNEL_GOAL_REMINDERS, retrieved!!.id)
        assertEquals(NotificationManager.IMPORTANCE_HIGH, retrieved.importance)
    }

    @Test
    fun dhikrCountingChannel_createsWithLowImportance() {
        val channel = NotificationChannel(
            DhikrCountingService.CHANNEL_ID,
            "Counting",
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)

        val retrieved = manager.getNotificationChannel(DhikrCountingService.CHANNEL_ID)
        assertNotNull("Counting channel should exist", retrieved)
        assertEquals(DhikrCountingService.CHANNEL_ID, retrieved!!.id)
        assertEquals(NotificationManager.IMPORTANCE_LOW, retrieved.importance)
    }

    @Test
    fun notificationIcon_isValidMonochromeDrawable() {
        val drawable = ContextCompat.getDrawable(context, R.drawable.ic_notification)
        assertNotNull("ic_notification drawable must exist and be loadable", drawable)
    }

    @Test
    fun notificationActionIcons_areValidMonochromeDrawables() {
        val countDrawable = ContextCompat.getDrawable(context, R.drawable.ic_action_count)
        val dismissDrawable = ContextCompat.getDrawable(context, R.drawable.ic_action_dismiss)

        assertNotNull("ic_action_count drawable must exist and be loadable", countDrawable)
        assertNotNull("ic_action_dismiss drawable must exist and be loadable", dismissDrawable)
    }
}
