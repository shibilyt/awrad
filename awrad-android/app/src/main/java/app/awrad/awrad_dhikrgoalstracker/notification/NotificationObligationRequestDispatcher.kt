package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.di.ApplicationCoroutineScope
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import java.util.concurrent.atomic.AtomicBoolean
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch

/** Reasons are diagnostic only: no goal, count, or preference data crosses this boundary. */
enum class NotificationObligationRequestReason {
    STARTUP,
    GOAL_MUTATION,
    COUNT_MUTATION,
    SYNC_IMPORT,
    PREFERENCE,
    DAY_RESET_OR_LOCATION,
    BOOT_OR_TIME,
    WATCHDOG,
    PERMISSION_OR_LIFECYCLE,
}

/**
 * A committed local mutation signal. An empty [affectedGoalIds] means the writer cannot
 * authoritatively identify all affected goals, so post-reconciliation cleanup is conservative.
 */
data class NotificationObligationRequest(
    val reason: NotificationObligationRequestReason,
    val affectedGoalIds: Set<AwradId> = emptySet(),
)

interface NotificationObligationRequestSink {
    fun request(request: NotificationObligationRequest)

    fun request(
        reason: NotificationObligationRequestReason,
        affectedGoalIds: Set<AwradId> = emptySet(),
    ) = request(NotificationObligationRequest(reason, affectedGoalIds))
}

object NoopNotificationObligationRequestSink : NotificationObligationRequestSink {
    override fun request(request: NotificationObligationRequest) = Unit
}

/**
 * Process-wide, conflated reconciliation request bus.
 *
 * A request issued before [start] is retained. While the handler is working, a further request
 * becomes exactly one follow-up pass, which avoids lost commits without coupling mutation owners
 * to the planning repository graph.
 */
@Singleton
class NotificationObligationRequestDispatcher @Inject constructor(
    @ApplicationCoroutineScope private val scope: CoroutineScope,
) : NotificationObligationRequestSink {
    private val started = AtomicBoolean(false)
    private val requests = Channel<NotificationObligationRequest>(Channel.CONFLATED)
    private val pendingLock = Any()
    private val pending = linkedSetOf<NotificationObligationRequest>()

    override fun request(request: NotificationObligationRequest) {
        synchronized(pendingLock) {
            pending += request
        }
        requests.trySend(request)
    }

    fun start(reconcile: suspend (Set<NotificationObligationRequest>) -> Unit) {
        if (!started.compareAndSet(false, true)) return
        scope.launch {
            while (true) {
                requests.receive()
                val reasons = synchronized(pendingLock) {
                    pending.toSet().also { pending.clear() }
                }
                if (reasons.isNotEmpty()) reconcile(reasons)
            }
        }
    }
}
