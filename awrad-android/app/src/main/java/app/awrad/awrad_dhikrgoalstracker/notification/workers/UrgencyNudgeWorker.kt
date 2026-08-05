package app.awrad.awrad_dhikrgoalstracker.notification.workers

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationScheduleCoordinator
import app.awrad.awrad_dhikrgoalstracker.notification.UrgencyNudgeDeliveryProcessor
import app.awrad.awrad_dhikrgoalstracker.notification.UrgencyNudgeRejectionReason
import app.awrad.awrad_dhikrgoalstracker.notification.UrgencyNudgeWorkInput
import app.awrad.awrad_dhikrgoalstracker.notification.UrgencyNudgeWorkerOutcomeMapper
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject

@HiltWorker
class UrgencyNudgeWorker @AssistedInject constructor(
    @Assisted private val appContext: Context,
    @Assisted workerParams: WorkerParameters,
    private val processor: UrgencyNudgeDeliveryProcessor,
    private val coordinator: NotificationScheduleCoordinator,
) : CoroutineWorker(appContext, workerParams) {
    override suspend fun doWork(): Result {
        val envelope = UrgencyNudgeWorkInput.from(inputData)?.toEnvelope() ?: return Result.failure()
        return UrgencyNudgeWorkerOutcomeMapper.toWorkerResult(
            outcome = processor.process(envelope),
            envelope = envelope,
            nowMillis = System.currentTimeMillis(),
            onExpiredCleanup = {
                coordinator.handleRejectedDelivery(
                    envelope,
                    UrgencyNudgeRejectionReason.EXPIRED,
                )
            },
        )
    }
}
