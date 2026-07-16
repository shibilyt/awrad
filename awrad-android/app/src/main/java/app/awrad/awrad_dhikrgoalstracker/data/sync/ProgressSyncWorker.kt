package app.awrad.awrad_dhikrgoalstracker.data.sync

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.IOException
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

@HiltWorker
class ProgressSyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val engine: ProgressSyncEngine,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = try {
        engine.synchronize()
        Result.success()
    } catch (error: SyncAccountMismatchException) {
        record(error)
        Result.failure()
    } catch (error: IOException) {
        record(error)
        Result.retry()
    } catch (error: Exception) {
        record(error)
        if (runAttemptCount < 3) Result.retry() else Result.failure()
    }

    private suspend fun record(error: Throwable) {
        Log.e(TAG, "Progress synchronization failed", error)
        runCatching { engine.recordFailure(error) }
    }

    companion object {
        private const val TAG = "ProgressSyncWorker"
    }
}

@Singleton
class ProgressSyncScheduler @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val workManager: WorkManager get() = WorkManager.getInstance(context)
    private val network = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .build()

    fun enqueue() {
        val request = OneTimeWorkRequestBuilder<ProgressSyncWorker>()
            .setConstraints(network)
            .build()
        // Mutations set a durable 0->1 syncRequested edge before enqueueing.
        // APPEND_OR_REPLACE preserves the one follow-up edge when a worker is
        // already running; repeated taps coalesce because they do not create
        // another 0->1 transition.
        workManager.enqueueUniqueWork(IMMEDIATE_WORK, ExistingWorkPolicy.APPEND_OR_REPLACE, request)
    }

    fun startPeriodic() {
        val request = PeriodicWorkRequestBuilder<ProgressSyncWorker>(6, TimeUnit.HOURS)
            .setConstraints(network)
            .build()
        workManager.enqueueUniquePeriodicWork(PERIODIC_WORK, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    companion object {
        // Version the unique name when a shipped worker can remain backed off
        // after an interoperability fix; the upgrade must get one fresh run.
        private const val IMMEDIATE_WORK = "progress-sync-immediate-v3"
        private const val PERIODIC_WORK = "progress-sync-periodic-v1"
    }
}
