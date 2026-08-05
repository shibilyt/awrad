package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.DayResetOption
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import java.io.IOException
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class NotificationObligationEngineTest {

    @Test
    fun reconcileNowUsesProductionPlanAndReconcilePathThenPrunesDeliveredState() = runTest {
        val store = MemoryStore(
            delivered = setOf(
                DeliveredNotificationStage(identity("expired"), deliveredAtMillis = Long.MIN_VALUE, expiresAtMillis = 1L),
            ),
        )
        val gateway = RecordingPlanGateway()
        val context = RecordingContext(urgencyEnabled = true)
        val effects = RecordingEffects()
        val engine = engine(context, gateway, store, effects)

        val result = engine.reconcileNow(NotificationObligationRequestReason.WATCHDOG)

        assertEquals(NotificationObligationEngineResult.Reconciled, result)
        assertEquals(1, context.calls)
        assertEquals(1, gateway.activeGoalReads)
        assertEquals(1, store.pruneCalls)
        assertTrue(store.delivered.isEmpty())
        assertTrue(effects.scheduled.isEmpty())
    }

    @Test
    fun urgencyDisabledReconcilesEmptyDesiredRecords() = runTest {
        val record = NotificationScheduleRecord(identity("existing"), 10L, 20L)
        val store = MemoryStore(manifest = setOf(record))
        val gateway = RecordingPlanGateway()
        val effects = RecordingEffects()
        val engine = engine(RecordingContext(urgencyEnabled = false), gateway, store, effects)

        val result = engine.reconcileNow(NotificationObligationRequestReason.PREFERENCE)

        assertEquals(NotificationObligationEngineResult.Reconciled, result)
        assertEquals(0, gateway.activeGoalReads)
        assertEquals(listOf(record.identity), effects.cancelledPending)
        assertTrue(store.manifest.isEmpty())
    }

    @Test
    fun reconcileNowClassifiesTransientAndFatalFailures() = runTest {
        val transient = engine(FailingContext(IOException("offline")), RecordingPlanGateway(), MemoryStore(), RecordingEffects())
        val reporter = RecordingReporter()
        val fatal = engine(FailingContext(IllegalStateException("corrupt")), RecordingPlanGateway(), MemoryStore(), RecordingEffects(), reporter)

        assertTrue(
            transient.reconcileNow(NotificationObligationRequestReason.WATCHDOG)
                is NotificationObligationEngineResult.TransientFailure,
        )
        assertTrue(
            fatal.reconcileNow(NotificationObligationRequestReason.WATCHDOG)
                is NotificationObligationEngineResult.FatalFailure,
        )
        assertEquals(1, reporter.errors.size)
    }

    @Test
    fun fatalFailureReportsWithoutInvokingProcessHandler() = runTest {
        val originalHandler = Thread.getDefaultUncaughtExceptionHandler()
        var processHandlerCalls = 0
        Thread.setDefaultUncaughtExceptionHandler { _, _ -> processHandlerCalls++ }
        val reporter = RecordingReporter()
        try {
            val result = engine(
                FailingContext(IllegalStateException("corrupt")),
                RecordingPlanGateway(),
                MemoryStore(),
                RecordingEffects(),
                reporter,
            ).reconcileNow(NotificationObligationRequestReason.WATCHDOG)
            assertTrue(result is NotificationObligationEngineResult.FatalFailure)
            assertEquals(1, reporter.errors.size)
        } finally {
            Thread.setDefaultUncaughtExceptionHandler(originalHandler)
        }

        assertEquals(0, processHandlerCalls)
    }

    @Test
    fun cancellationPropagatesFromReconciliation() = runTest {
        val engine = engine(
            FailingContext(CancellationException("cancelled")),
            RecordingPlanGateway(),
            MemoryStore(),
            RecordingEffects(),
        )

        var propagated = false
        try {
            engine.reconcileNow(NotificationObligationRequestReason.WATCHDOG)
        } catch (_: CancellationException) {
            propagated = true
        }

        assertTrue(propagated)
    }

    @Test
    fun dispatcherRemainsLiveAfterFatalResultAndProcessesLaterRequest() = runTest {
        val context = EventuallyAvailableContext(failuresBeforeSuccess = 1, failure = IllegalStateException("corrupt"))
        val engine = engine(context, RecordingPlanGateway(), MemoryStore(), RecordingEffects())
        val dispatcher = NotificationObligationRequestDispatcher(
            CoroutineScope(StandardTestDispatcher(testScheduler)),
        )
        engine.start(dispatcher)

        dispatcher.request(NotificationObligationRequestReason.STARTUP)
        advanceUntilIdle()
        dispatcher.request(NotificationObligationRequestReason.COUNT_MUTATION)
        advanceUntilIdle()

        assertEquals(2, context.calls)
    }

    private fun engine(
        context: NotificationObligationPlanningContextProvider,
        gateway: RecordingPlanGateway,
        store: MemoryStore,
        effects: RecordingEffects,
        reporter: RecordingReporter = RecordingReporter(),
    ): NotificationObligationEngine {
        val coordinator = NotificationScheduleCoordinator(store, effects)
        return NotificationObligationEngine(
            clock = Clock.fixed(Instant.ofEpochMilli(100L), ZoneOffset.UTC),
            contextProvider = context,
            planService = NotificationObligationPlanService(gateway) { dhikr, _ -> dhikr.title },
            reconciler = NotificationScheduleReconciler(store, effects, coordinator),
            coordinator = coordinator,
            errorReporter = reporter,
        )
    }

    private class RecordingContext(
        private val urgencyEnabled: Boolean,
    ) : NotificationObligationPlanningContextProvider {
        var calls = 0
        override suspend fun create(now: Instant, zoneId: java.time.ZoneId): NotificationObligationPlanInput {
            calls++
            return planInput(urgencyEnabled)
        }
    }

    private class FailingContext(
        private val error: Throwable,
    ) : NotificationObligationPlanningContextProvider {
        override suspend fun create(now: Instant, zoneId: java.time.ZoneId): NotificationObligationPlanInput = throw error
    }

    private class EventuallyAvailableContext(
        private var failuresBeforeSuccess: Int,
        private val failure: Throwable = IOException("offline"),
    ) : NotificationObligationPlanningContextProvider {
        var calls = 0
        override suspend fun create(now: Instant, zoneId: java.time.ZoneId): NotificationObligationPlanInput {
            calls++
            if (failuresBeforeSuccess-- > 0) throw failure
            return planInput(true)
        }
    }

    private class RecordingPlanGateway : NotificationObligationPlanGateway {
        var activeGoalReads = 0
        override suspend fun activeGoals(): List<Goal> {
            activeGoalReads++
            return emptyList()
        }

        override suspend fun counts(
            goalIds: List<app.awrad.awrad_dhikrgoalstracker.data.model.AwradId>,
            startDate: java.time.LocalDate,
            endDate: java.time.LocalDate,
        ): NotificationPlanCounts = error("No goals means no count query")
    }

    private class RecordingEffects : NotificationSchedulingEffectGateway {
        val scheduled = mutableListOf<NotificationScheduleRecord>()
        val cancelledPending = mutableListOf<NotificationIdentity>()
        override suspend fun schedule(record: NotificationScheduleRecord): NotificationSchedulingEffectResult {
            scheduled += record
            return NotificationSchedulingEffectResult.Scheduled
        }

        override suspend fun cancelPending(identity: NotificationIdentity) {
            cancelledPending += identity
        }

        override suspend fun cancelVisible(identity: NotificationIdentity) = Unit
    }

    private class RecordingReporter : NotificationObligationEngineErrorReporter {
        val errors = mutableListOf<Throwable>()
        override fun report(reasons: Set<NotificationObligationRequestReason>, error: Throwable) {
            errors += error
        }
    }

    private class MemoryStore(
        manifest: Set<NotificationScheduleRecord> = emptySet(),
        delivered: Set<DeliveredNotificationStage> = emptySet(),
    ) : NotificationScheduleStore {
        var manifest = manifest
        var delivered = delivered
        var pruneCalls = 0
        override suspend fun read() = NotificationScheduleState(manifest, delivered, 0)
        override suspend fun replaceManifest(records: Collection<NotificationScheduleRecord>) {
            manifest = records.filterNot { record -> delivered.any { it.identity == record.identity } }.toSet()
        }

        override suspend fun markDelivered(identity: NotificationIdentity, deliveredAtMillis: Long) = Unit
        override suspend fun clearExact(canonicalKey: String) = Unit
        override suspend fun clearGoal(goalId: app.awrad.awrad_dhikrgoalstracker.data.model.AwradId) = Unit
        override suspend fun retainDelivered(retainedCanonicalKeys: Set<String>) = Unit
        override suspend fun pruneDelivered(nowMillis: Long, retentionMillis: Long) {
            pruneCalls++
            delivered = delivered.filterNot {
                it.deliveredAtMillis < nowMillis - retentionMillis &&
                    (it.expiresAtMillis == null || it.expiresAtMillis <= nowMillis)
            }.toSet()
        }
    }

    private fun identity(scope: String): NotificationIdentity = NotificationIdentity.create(
        goalId = java.util.UUID.fromString("00000000-0000-0000-0000-000000000001"),
        obligationScope = scope,
        slotId = null,
        kind = NudgeKind.DEADLINE_WARNING,
    )

    private companion object {
        fun planInput(urgencyEnabled: Boolean) = NotificationObligationPlanInput(
            now = Instant.ofEpochMilli(100L),
            zoneId = ZoneOffset.UTC,
            dayReset = DayResetOption.MIDNIGHT,
            urgencyEnabled = urgencyEnabled,
            defaultPrayerLeadMinutes = 30,
        )
    }
}
