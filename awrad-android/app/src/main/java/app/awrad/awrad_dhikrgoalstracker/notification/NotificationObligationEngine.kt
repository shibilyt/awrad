package app.awrad.awrad_dhikrgoalstracker.notification

import android.util.Log
import java.io.IOException
import java.time.Clock
import java.time.ZoneId
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay

fun interface NotificationObligationEngineErrorReporter {
    fun report(reasons: Set<NotificationObligationRequestReason>, error: Throwable)
}

sealed interface NotificationObligationEngineResult {
    data object Reconciled : NotificationObligationEngineResult
    data class TransientFailure(val error: IOException) : NotificationObligationEngineResult
    data class FatalFailure(val error: Throwable) : NotificationObligationEngineResult
}

@Singleton
class AndroidNotificationObligationEngineErrorReporter @Inject constructor() :
    NotificationObligationEngineErrorReporter {
    override fun report(reasons: Set<NotificationObligationRequestReason>, error: Throwable) {
        Log.e(TAG, "Urgency schedule reconciliation failed for ${reasons.sortedBy { it.name }}", error)
    }

    private companion object {
        const val TAG = "NotificationObligationEngine"
    }
}

/**
 * Runtime owner for the obligation plan/reconcile pair. It intentionally has no mutation API;
 * authoritative writers only signal [NotificationObligationRequestDispatcher].
 */
@Singleton
class NotificationObligationEngine @Inject constructor(
    private val clock: Clock,
    private val contextProvider: NotificationObligationPlanningContextProvider,
    private val planService: NotificationObligationPlanService,
    private val reconciler: NotificationScheduleReconciler,
    private val coordinator: NotificationScheduleCoordinator,
    private val errorReporter: NotificationObligationEngineErrorReporter,
) {
    fun start(dispatcher: NotificationObligationRequestDispatcher) {
        dispatcher.start(::reconcileFromDispatcher)
    }

    suspend fun reconcileNow(reason: NotificationObligationRequestReason): NotificationObligationEngineResult =
        reconcileFor(setOf(reason)) { Unit }

    private suspend fun reconcile(): NotificationObligationPlanInput {
        val now = clock.instant()
        val input = contextProvider.create(now, ZoneId.systemDefault())
        val desired = planService.plan(input)
        reconciler.reconcile(desired)
        retainRecentDelivered(now.toEpochMilli())
        return input
    }

    private suspend fun reconcileFromDispatcher(requests: Set<NotificationObligationRequest>) {
        val reasons = requests.mapTo(linkedSetOf()) { it.reason }
        var lastTransient: IOException? = null
        repeat(MAX_TRANSIENT_ATTEMPTS) { attempt ->
            when (val result = reconcileFor(reasons) { input ->
                dismissDeliveredVisibleAfterCommittedMutation(requests, input)
            }) {
                NotificationObligationEngineResult.Reconciled -> return
                is NotificationObligationEngineResult.FatalFailure -> return
                is NotificationObligationEngineResult.TransientFailure -> {
                    lastTransient = result.error
                    if (attempt + 1 < MAX_TRANSIENT_ATTEMPTS) delay(RETRY_DELAYS_MILLIS[attempt])
                }
            }
        }
        lastTransient?.let { errorReporter.report(reasons, it) }
    }

    private suspend fun reconcileFor(
        reasons: Set<NotificationObligationRequestReason>,
        afterReconciled: suspend (NotificationObligationPlanInput) -> Unit,
    ): NotificationObligationEngineResult =
        try {
            afterReconciled(reconcile())
            NotificationObligationEngineResult.Reconciled
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: IOException) {
            NotificationObligationEngineResult.TransientFailure(error)
        } catch (error: Throwable) {
            errorReporter.report(reasons, error)
            NotificationObligationEngineResult.FatalFailure(error)
        }

    private suspend fun dismissDeliveredVisibleAfterCommittedMutation(
        requests: Set<NotificationObligationRequest>,
        input: NotificationObligationPlanInput,
    ) {
        if (!input.urgencyEnabled) {
            coordinator.dismissAllDeliveredVisible()
            return
        }

        val mutationRequests = requests.filter {
            it.reason in setOf(
                NotificationObligationRequestReason.GOAL_MUTATION,
                NotificationObligationRequestReason.COUNT_MUTATION,
                NotificationObligationRequestReason.SYNC_IMPORT,
            )
        }
        if (mutationRequests.any { it.affectedGoalIds.isEmpty() } ||
            requests.any { it.reason == NotificationObligationRequestReason.DAY_RESET_OR_LOCATION }
        ) {
            coordinator.dismissAllDeliveredVisible()
            return
        }
        coordinator.dismissDeliveredVisibleForGoals(
            mutationRequests.flatMapTo(linkedSetOf()) { it.affectedGoalIds },
        )
    }

    private suspend fun retainRecentDelivered(nowMillis: Long) {
        coordinator.pruneDelivered(nowMillis, DELIVERED_RETENTION_MILLIS)
    }

    private companion object {
        const val MAX_TRANSIENT_ATTEMPTS = 3
        val RETRY_DELAYS_MILLIS = longArrayOf(1_000L, 5_000L)
        const val DELIVERED_RETENTION_MILLIS = 48L * 60L * 60L * 1_000L
    }
}
