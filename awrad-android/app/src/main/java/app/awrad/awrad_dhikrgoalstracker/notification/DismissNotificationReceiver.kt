package app.awrad.awrad_dhikrgoalstracker.notification

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class DismissNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != WorkerKeys.ACTION_DISMISS_NOTIFICATION) return
        val notificationId = intent.getIntExtra(WorkerKeys.EXTRA_NOTIFICATION_ID, -1)
        if (notificationId == -1) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.cancel(notificationId)
    }
}
