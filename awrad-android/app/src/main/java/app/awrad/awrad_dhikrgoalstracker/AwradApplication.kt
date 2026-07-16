package app.awrad.awrad_dhikrgoalstracker

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.data.sync.ProgressSyncScheduler
import app.awrad.awrad_dhikrgoalstracker.data.sync.ForegroundProgressSyncCoordinator
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class AwradApplication : Application(), Configuration.Provider {

    @Inject lateinit var workerFactory: HiltWorkerFactory
    @Inject lateinit var reminderScheduler: ReminderScheduler
    @Inject lateinit var progressSyncScheduler: ProgressSyncScheduler
    @Inject lateinit var foregroundProgressSyncCoordinator: ForegroundProgressSyncCoordinator

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    override fun onCreate() {
        super.onCreate()
        reminderScheduler.initialize()
        progressSyncScheduler.startPeriodic()
        progressSyncScheduler.enqueue()
        foregroundProgressSyncCoordinator.start()
    }
}
