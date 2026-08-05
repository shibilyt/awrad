package app.awrad.awrad_dhikrgoalstracker.notification

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import app.awrad.awrad_dhikrgoalstracker.notification.workers.UrgencyNudgeWorker
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AndroidNotificationSchedulingEffects @Inject constructor(
    @ApplicationContext context: Context,
    alarmManager: AlarmManager,
    workManager: WorkManager,
) : NotificationSchedulingEffectGateway {
    private val orchestrator = AdaptiveNudgeSchedulingOrchestrator(
        nowMillis = System::currentTimeMillis,
        exactBackend = AndroidExactAlarmBackend(context, alarmManager),
        workBackend = AndroidWorkBackend(context, workManager),
    )
    private val notificationManager = context.getSystemService(NotificationManager::class.java)

    override suspend fun schedule(record: NotificationScheduleRecord): NotificationSchedulingEffectResult =
        when (val result = orchestrator.schedule(
            AdaptiveNudgeEnvelope(record.identity, record.triggerAtMillis, record.expiresAtMillis, record.kind),
        )) {
            is AdaptiveScheduleResult.Scheduled -> NotificationSchedulingEffectResult.Scheduled
            AdaptiveScheduleResult.Stale -> NotificationSchedulingEffectResult.Stale
        }

    override suspend fun cancelPending(identity: NotificationIdentity) {
        orchestrator.cancel(identity)
    }

    override suspend fun cancelVisible(identity: NotificationIdentity) {
        notificationManager.cancel(identity.notificationTag, identity.notificationId)
    }
}

private class AndroidExactAlarmBackend(
    private val context: Context,
    private val alarmManager: AlarmManager,
) : AdaptiveExactAlarmBackend {
    override fun isExactSchedulingAvailable(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()

    override fun schedule(envelope: AdaptiveNudgeEnvelope) {
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            envelope.triggerAtMillis,
            pendingIntent(envelope.identity, envelope.triggerAtMillis, envelope.expiresAtMillis, envelope.kind),
        )
    }

    override fun cancel(identity: NotificationIdentity) {
        alarmManager.cancel(pendingIntent(identity, null, null, null))
    }

    private fun pendingIntent(
        identity: NotificationIdentity,
        triggerAtMillis: Long?,
        expiresAtMillis: Long?,
        kind: NudgeKind?,
    ): PendingIntent = PendingIntent.getBroadcast(
        context,
        REQUEST_CODE,
        UrgencyNudgePlatformRequestBuilder.broadcastIntent(
            packageName = context.packageName,
            identity = identity,
            triggerAtMillis = triggerAtMillis,
            expiresAtMillis = expiresAtMillis,
            kind = kind,
        ),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private companion object {
        const val REQUEST_CODE = 0
    }
}

private class AndroidWorkBackend(
    private val context: Context,
    private val workManager: WorkManager,
) : AdaptiveWorkBackend {
    override fun enqueue(request: AdaptiveWorkRequest) {
        val built = UrgencyNudgePlatformRequestBuilder.workRequest(request)
        val work = OneTimeWorkRequestBuilder<UrgencyNudgeWorker>()
            .setInitialDelay(built.delayMillis, TimeUnit.MILLISECONDS)
            .setInputData(built.inputData)
            .addTag(built.workTag)
            .build()
        workManager.enqueueUniqueWork(built.uniqueWorkName, ExistingWorkPolicy.REPLACE, work)
    }

    override fun cancel(identity: NotificationIdentity) {
        workManager.cancelUniqueWork(AdaptiveNudgeWorkIdentity.uniqueWorkName(identity))
        workManager.cancelAllWorkByTag(AdaptiveNudgeWorkIdentity.workTag(identity))
    }
}

internal data class UrgencyNudgeWorkRequestSpec(
    val uniqueWorkName: String,
    val delayMillis: Long,
    val inputData: Data,
    val workTag: String,
)

internal data class UrgencyNudgeBroadcastRequest(
    val action: String,
    val packageName: String,
    val receiverClassName: String,
    val dataUri: String,
    val canonicalIdentity: String,
    val triggerAtMillis: Long?,
    val expiresAtMillis: Long?,
    val kind: NudgeKind?,
)

internal object UrgencyNudgePlatformRequestBuilder {
    fun broadcastRequest(
        packageName: String,
        identity: NotificationIdentity,
        triggerAtMillis: Long?,
        expiresAtMillis: Long?,
        kind: NudgeKind?,
    ): UrgencyNudgeBroadcastRequest = UrgencyNudgeBroadcastRequest(
        action = UrgencyNudgeEnvelopeContract.ACTION_URGENCY_NUDGE,
        packageName = packageName,
        receiverClassName = UrgencyNudgeReceiver::class.java.name,
        dataUri = identity.pendingIntentDataUri,
        canonicalIdentity = identity.canonicalKey,
        triggerAtMillis = triggerAtMillis,
        expiresAtMillis = expiresAtMillis,
        kind = kind,
    )

    fun broadcastIntent(
        packageName: String,
        identity: NotificationIdentity,
        triggerAtMillis: Long?,
        expiresAtMillis: Long?,
        kind: NudgeKind?,
    ): Intent {
        val request = broadcastRequest(packageName, identity, triggerAtMillis, expiresAtMillis, kind)
        return Intent(request.action).apply {
            setClassName(request.packageName, request.receiverClassName)
            data = android.net.Uri.parse(request.dataUri)
            putExtra(UrgencyNudgeEnvelopeContract.EXTRA_CANONICAL_IDENTITY, request.canonicalIdentity)
            request.triggerAtMillis?.let {
                putExtra(UrgencyNudgeEnvelopeContract.EXTRA_TRIGGER_AT_MILLIS, it)
            }
            request.expiresAtMillis?.let {
                putExtra(UrgencyNudgeEnvelopeContract.EXTRA_EXPIRES_AT_MILLIS, it)
            }
            request.kind?.let {
                putExtra(UrgencyNudgeEnvelopeContract.EXTRA_KIND, it.name)
            }
        }
    }

    fun workRequest(request: AdaptiveWorkRequest): UrgencyNudgeWorkRequestSpec =
        UrgencyNudgeWorkRequestSpec(
            uniqueWorkName = request.uniqueWorkName,
            delayMillis = request.delayMillis,
            inputData = UrgencyNudgeWorkInput.from(request.envelope).toData(),
            workTag = AdaptiveNudgeWorkIdentity.workTag(request.envelope.identity),
        )
}
