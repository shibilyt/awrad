package app.awrad.awrad_dhikrgoalstracker

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import app.awrad.awrad_dhikrgoalstracker.notification.ReminderScheduler
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationScheduleReconciler
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationEngine
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationRequestDispatcher
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationRequestReason
import app.awrad.awrad_dhikrgoalstracker.data.repository.DhikrRepository
import app.awrad.awrad_dhikrgoalstracker.data.sync.ProgressSyncScheduler
import app.awrad.awrad_dhikrgoalstracker.data.sync.ForegroundProgressSyncCoordinator
import app.awrad.awrad_dhikrgoalstracker.di.ApplicationCoroutineScope
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

@HiltAndroidApp
class AwradApplication : Application(), Configuration.Provider {

    @Inject lateinit var workerFactory: HiltWorkerFactory
    @Inject lateinit var reminderScheduler: ReminderScheduler
    @Inject lateinit var notificationScheduleReconciler: NotificationScheduleReconciler
    @Inject lateinit var notificationObligationEngine: NotificationObligationEngine
    @Inject lateinit var notificationObligationRequestDispatcher: NotificationObligationRequestDispatcher
    @Inject lateinit var progressSyncScheduler: ProgressSyncScheduler
    @Inject lateinit var foregroundProgressSyncCoordinator: ForegroundProgressSyncCoordinator
    @Inject lateinit var dhikrRepository: DhikrRepository
    @Inject @ApplicationCoroutineScope lateinit var applicationScope: CoroutineScope

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    override fun onCreate() {
        super.onCreate()
        reminderScheduler.initialize()
        notificationObligationEngine.start(notificationObligationRequestDispatcher)
        notificationObligationRequestDispatcher.request(NotificationObligationRequestReason.STARTUP)
        progressSyncScheduler.startPeriodic()
        progressSyncScheduler.enqueue()
        foregroundProgressSyncCoordinator.start()
        applicationScope.launch {
            runCatching { dhikrRepository.cleanupOwnedAudioOrphans() }
        }
    }
}
