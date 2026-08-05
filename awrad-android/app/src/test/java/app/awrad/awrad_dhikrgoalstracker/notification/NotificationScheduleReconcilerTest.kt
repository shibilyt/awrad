package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import java.util.UUID
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationScheduleReconcilerTest {
    @Test
    fun `candidate maps to manifest record using its semantic identity`() {
        val candidate = candidate(scope = "candidate", triggerAtMillis = 100L)

        val record = candidate.toNotificationScheduleRecord()

        assertEquals(
            NotificationIdentity.from(candidate.key).canonicalKey,
            record.identity.canonicalKey,
        )
        assertEquals(100L, record.triggerAtMillis)
        assertEquals(candidate.key.kind, record.kind)
    }

    @Test
    fun `reconciler requires explicit coordinator and cannot silently create one`() {
        val storeEffectsOnly = NotificationScheduleReconciler::class.java.constructors.filter { ctor ->
            ctor.parameterTypes.toList() == listOf(
                NotificationScheduleStore::class.java,
                NotificationSchedulingEffectGateway::class.java,
            )
        }
        assertTrue(
            "Store+effects-only constructor must not exist; it would silently create a private coordinator",
            storeEffectsOnly.isEmpty(),
        )
        assertTrue(
            NotificationScheduleReconciler::class.java.constructors.any { ctor ->
                ctor.parameterTypes.toList() == listOf(
                    NotificationScheduleStore::class.java,
                    NotificationSchedulingEffectGateway::class.java,
                    NotificationScheduleCoordinator::class.java,
                )
            },
        )
    }

    @Test
    fun `empty manifest reconciles desired records through effects then persists`() = runTest {
        val store = FakeStore()
        val effects = FakeEffects()
        val desired = listOf(record("first", 100L), record("second", 200L))

        val result = reconciler(store, effects).reconcile(desired)

        assertEquals(listOf("schedule:first", "schedule:second", "write"), effects.operationsWith(store))
        assertEquals(desired.map { it.identity.canonicalKey }.sorted(), result.scheduled)
        assertEquals(desired.toSet(), store.manifest)
    }

    @Test
    fun `identical reconcile is a no op`() = runTest {
        val desired = listOf(record("same", 100L))
        val store = FakeStore(manifest = desired.toSet())
        val effects = FakeEffects()

        val result = reconciler(store, effects).reconcile(desired)

        assertEquals(emptyList<String>(), effects.operations)
        assertEquals(listOf(desired.single().identity.canonicalKey), result.unchanged)
        assertEquals(0, store.replaceCalls)
    }

    @Test
    fun `independently reconstructed equal record reconciles unchanged`() = runTest {
        val stored = record("same", 100L)
        val reconstructed = NotificationScheduleRecord(
            NotificationIdentity.parse(stored.identity.canonicalKey)!!,
            100L,
            1_100L,
        )
        val store = FakeStore(manifest = setOf(stored))
        val effects = FakeEffects()

        val result = reconciler(store, effects).reconcile(listOf(reconstructed))

        assertEquals(listOf(stored.identity.canonicalKey), result.unchanged)
        assertTrue(effects.operations.isEmpty())
    }

    @Test
    fun `stale current record is cancelled and removed from manifest`() = runTest {
        val stale = record("stale", 100L)
        val retained = record("retained", 200L)
        val store = FakeStore(manifest = setOf(stale, retained))
        val effects = FakeEffects()

        val result = reconciler(store, effects).reconcile(listOf(retained))

        assertEquals(listOf("cancel:stale", "write"), effects.operationsWith(store))
        assertEquals(listOf(stale.identity.canonicalKey), result.cancelled)
        assertEquals(setOf(retained), store.manifest)
    }

    @Test
    fun `changed trigger cancels old record before scheduling replacement`() = runTest {
        val old = record("same", 100L)
        val replacement = record("same", 200L)
        val store = FakeStore(manifest = setOf(old))
        val effects = FakeEffects()

        val result = reconciler(store, effects).reconcile(listOf(replacement))

        assertEquals(listOf("cancel:same", "schedule:same", "write"), effects.operationsWith(store))
        assertEquals(listOf(replacement.identity.canonicalKey), result.rescheduled)
        assertEquals(setOf(replacement), store.manifest)
    }

    @Test
    fun `stale schedule result is excluded from manifest`() = runTest {
        val stale = record("late", 100L)
        val store = FakeStore()
        val effects = FakeEffects(scheduleResult = NotificationSchedulingEffectResult.Stale)

        val result = reconciler(store, effects).reconcile(listOf(stale))

        assertTrue(store.manifest.isEmpty())
        assertEquals(listOf(stale.identity.canonicalKey), result.stale)
    }

    @Test
    fun `mixed scheduled and stale effects report only persisted keys`() = runTest {
        val replaced = record("replace", 10L)
        val replacement = record("replace", 20L)
        val scheduled = record("scheduled", 30L)
        val staleNew = record("stale-new", 40L)
        val store = FakeStore(manifest = setOf(replaced))
        val effects = FakeEffects(
            scheduleResultFor = {
                if (it.identity.obligationScope.startsWith("stale") ||
                    it.identity.obligationScope == "replace"
                ) {
                    NotificationSchedulingEffectResult.Stale
                } else {
                    NotificationSchedulingEffectResult.Scheduled
                }
            },
        )

        val result = reconciler(store, effects).reconcile(listOf(replacement, scheduled, staleNew))

        assertEquals(listOf(scheduled.identity.canonicalKey), result.scheduled)
        assertEquals(emptyList<String>(), result.rescheduled)
        assertEquals(
            listOf(replacement.identity.canonicalKey, staleNew.identity.canonicalKey).sorted(),
            result.stale.sorted(),
        )
        assertEquals(setOf(scheduled), store.manifest)
        assertEquals(listOf("cancel:replace"), effects.operations.filter { it.startsWith("cancel:") })
    }

    @Test
    fun `delivered desired record is suppressed and never restored`() = runTest {
        val delivered = record("delivered", 100L)
        val other = record("other", 200L)
        val store = FakeStore(
            manifest = setOf(delivered),
            delivered = setOf(DeliveredNotificationStage(delivered.identity, 50L)),
        )
        val effects = FakeEffects()

        val result = reconciler(store, effects).reconcile(listOf(delivered, other))

        assertEquals(listOf("cancel:delivered", "schedule:other", "write"), effects.operationsWith(store))
        assertEquals(listOf(delivered.identity.canonicalKey), result.deliveredSuppressed)
        assertEquals(setOf(other), store.manifest)
    }

    @Test
    fun `mixed diff applies deterministic cancellations before deterministic schedules`() = runTest {
        val staleZ = record("z-stale", 1L)
        val staleA = record("a-stale", 1L)
        val changed = record("changed", 1L)
        val desiredChanged = record("changed", 2L)
        val newZ = record("z-new", 3L)
        val newA = record("a-new", 4L)
        val unchanged = record("unchanged", 5L)
        val events = mutableListOf<String>()
        val store = FakeStore(manifest = setOf(staleZ, staleA, changed, unchanged), eventLog = events)
        val effects = FakeEffects(eventLog = events)

        val result = reconciler(store, effects).reconcile(
            listOf(newZ, unchanged, desiredChanged, newA),
        )

        assertEquals(
            (listOf(staleZ, staleA)
                .sortedBy { it.identity.canonicalKey }
                .map { "cancel:${it.identity.obligationScope}" } +
                "cancel:changed" +
                listOf(newZ, desiredChanged, newA)
                    .sortedBy { it.identity.canonicalKey }
                    .map { "schedule:${it.identity.obligationScope}" } +
                "write"),
            events,
        )
        assertEquals(listOf(unchanged.identity.canonicalKey), result.unchanged)
        assertEquals(
            listOf(desiredChanged.identity.canonicalKey),
            result.rescheduled,
        )
    }

    @Test
    fun `duplicate desired identity is rejected before store or effects`() = runTest {
        val duplicate = record("duplicate", 100L)
        val store = FakeStore()
        val effects = FakeEffects()

        assertFailsSuspend<IllegalArgumentException> {
            reconciler(store, effects).reconcile(listOf(duplicate, duplicate.copy(triggerAtMillis = 200L)))
        }

        assertEquals(0, store.readCalls)
        assertEquals(0, store.replaceCalls)
        assertTrue(effects.operations.isEmpty())
    }

    @Test
    fun `read cancel schedule and manifest write failures propagate`() = runTest {
        val desired = record("desired", 100L)
        val stale = record("stale", 50L)
        val readFailure = IllegalStateException("read")
        assertFailsSuspend<IllegalStateException> {
            reconciler(FakeStore(readFailure = readFailure), FakeEffects()).reconcile(listOf(desired))
        }

        val cancelFailure = IllegalStateException("cancel")
        assertFailsSuspend<IllegalStateException> {
            reconciler(FakeStore(manifest = setOf(stale)), FakeEffects(cancelFailure = cancelFailure))
                .reconcile(emptyList())
        }

        val scheduleFailure = IllegalStateException("schedule")
        assertFailsSuspend<IllegalStateException> {
            reconciler(FakeStore(), FakeEffects(scheduleFailure = scheduleFailure))
                .reconcile(listOf(desired))
        }

        val writeFailure = IllegalStateException("write")
        assertFailsSuspend<IllegalStateException> {
            reconciler(FakeStore(writeFailure = writeFailure), FakeEffects())
                .reconcile(listOf(desired))
        }
    }

    @Test
    fun `partial effect failure keeps old manifest and idempotent retry converges`() = runTest {
        val old = record("old", 1L)
        val desired = record("desired", 2L)
        val store = FakeStore(manifest = setOf(old))
        val effects = FakeEffects(scheduleFailure = IllegalStateException("schedule"))
        val subject = reconciler(store, effects)

        assertFailsSuspend<IllegalStateException> { subject.reconcile(listOf(desired)) }
        assertEquals(setOf(old), store.manifest)

        effects.scheduleFailure = null
        subject.reconcile(listOf(desired))

        assertEquals(setOf(desired), store.manifest)
        assertEquals(1, effects.activeByIdentity.size)
        assertEquals(desired, effects.activeByIdentity[desired.identity.canonicalKey])
    }

    @Test
    fun `concurrent requests serialize and later request becomes final manifest`() = runTest {
        val events = mutableListOf<String>()
        val store = FakeStore(eventLog = events)
        val first = record("first", 1L)
        val second = record("second", 2L)
        val firstScheduleStarted = CompletableDeferred<Unit>()
        val releaseFirstSchedule = CompletableDeferred<Unit>()
        val effects = FakeEffects(
            eventLog = events,
            onSchedule = { record ->
                if (record == first) {
                    firstScheduleStarted.complete(Unit)
                    releaseFirstSchedule.await()
                }
            },
        )
        val subject = reconciler(store, effects)

        val firstJob = async { subject.reconcile(listOf(first)) }
        firstScheduleStarted.await()
        val secondJob = async { subject.reconcile(listOf(second)) }
        releaseFirstSchedule.complete(Unit)
        firstJob.await()
        secondJob.await()

        assertEquals(
            listOf("schedule:first", "write", "cancel:first", "schedule:second", "write"),
            events,
        )
        assertEquals(setOf(second), store.manifest)
    }

    @Test
    fun `shared coordinator serializes separate reconcilers and later request wins`() = runTest {
        val store = FakeStore()
        val first = record("first", 1L)
        val second = record("second", 2L)
        val started = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val effects = FakeEffects(onSchedule = {
            if (it == first) {
                started.complete(Unit)
                release.await()
            }
        })
        val coordinator = NotificationScheduleCoordinator(store, effects)
        val firstReconciler = NotificationScheduleReconciler(store, effects, coordinator)
        val secondReconciler = NotificationScheduleReconciler(store, effects, coordinator)

        val firstJob = async { firstReconciler.reconcile(listOf(first)) }
        started.await()
        val secondJob = async { secondReconciler.reconcile(listOf(second)) }
        assertTrue(!secondJob.isCompleted)
        release.complete(Unit)
        firstJob.await()
        secondJob.await()

        assertEquals(setOf(second), store.manifest)
    }

    @Test
    fun `recording delivery cancels pending without dismissing visible notification`() = runTest {
        val record = record("delivered", 1L)
        val store = FakeStore(manifest = setOf(record))
        val effects = FakeEffects()
        val coordinator = NotificationScheduleCoordinator(store, effects)

        coordinator.recordDelivered(record.identity, 2L)

        assertTrue(store.manifest.isEmpty())
        assertEquals(setOf(record.identity.canonicalKey), store.delivered.map { it.identity.canonicalKey }.toSet())
        assertEquals(listOf("cancel:delivered"), effects.operations)
        assertEquals(0, effects.visibleCancels)
    }

    @Test
    fun `dismissing delivered visible for one goal preserves all tombstones and other goals`() = runTest {
        val target = record("target", 1L)
        val other = candidate("other", 2L, UUID.fromString("00000000-0000-0000-0000-000000000099"))
            .toNotificationScheduleRecord()
        val store = FakeStore(
            delivered = setOf(
                DeliveredNotificationStage(target.identity, 10L),
                DeliveredNotificationStage(other.identity, 20L),
            ),
        )
        val effects = FakeEffects()

        NotificationScheduleCoordinator(store, effects)
            .dismissDeliveredVisibleForGoal(target.identity.goalId)

        assertEquals(listOf("visible:target"), effects.operations)
        assertEquals(
            setOf(target.identity.canonicalKey, other.identity.canonicalKey),
            store.delivered.map { it.identity.canonicalKey }.toSet(),
        )
    }

    @Test
    fun `dismissing all delivered visible preserves tombstones and pending reminders`() = runTest {
        val first = record("first", 1L)
        val second = candidate("second", 2L, UUID.fromString("00000000-0000-0000-0000-000000000099"))
            .toNotificationScheduleRecord()
        val pending = record("pending", 3L)
        val store = FakeStore(
            manifest = setOf(pending),
            delivered = setOf(
                DeliveredNotificationStage(first.identity, 10L),
                DeliveredNotificationStage(second.identity, 20L),
            ),
        )
        val effects = FakeEffects()

        NotificationScheduleCoordinator(store, effects).dismissAllDeliveredVisible()

        assertEquals(listOf("visible:second", "visible:first"), effects.operations)
        assertEquals(setOf(pending), store.manifest)
        assertEquals(2, store.delivered.size)
    }

    @Test
    fun `delivery racing reconcile serializes to delivered without a pending effect`() = runTest {
        val record = record("race", 1L)
        val store = FakeStore()
        val scheduled = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val effects = FakeEffects(onSchedule = {
            scheduled.complete(Unit)
            release.await()
        })
        val coordinator = NotificationScheduleCoordinator(store, effects)
        val subject = NotificationScheduleReconciler(store, effects, coordinator)

        val reconcile = async { subject.reconcile(listOf(record)) }
        scheduled.await()
        val delivery = async { coordinator.recordDelivered(record.identity, 2L) }
        assertTrue(!delivery.isCompleted)
        release.complete(Unit)
        reconcile.await()
        delivery.await()

        assertTrue(store.manifest.isEmpty())
        assertEquals(setOf(record.identity.canonicalKey), store.delivered.map { it.identity.canonicalKey }.toSet())
        assertTrue(effects.activeByIdentity.isEmpty())
        assertEquals(0, effects.visibleCancels)
    }

    @Test
    fun `clear exact cancels pending and visible before removing ledger`() = runTest {
        val record = record("clear", 1L)
        val store = FakeStore(manifest = setOf(record))
        val effects = FakeEffects()

        NotificationScheduleCoordinator(store, effects).clearExact(record.identity.canonicalKey)

        assertTrue(store.manifest.isEmpty())
        assertEquals(listOf("cancel:clear", "visible:clear"), effects.operations)
    }

    @Test
    fun `clear goal cancels only matching goal identities`() = runTest {
        val target = record("target", 1L)
        val other = candidate("other", 2L, UUID.fromString("00000000-0000-0000-0000-000000000099"))
            .toNotificationScheduleRecord()
        val store = FakeStore(manifest = setOf(target, other))
        val effects = FakeEffects()

        NotificationScheduleCoordinator(store, effects).clearGoal(target.identity.goalId)

        assertEquals(setOf(other), store.manifest)
        assertEquals(listOf("cancel:target", "visible:target"), effects.operations)
    }

    @Test
    fun `malformed cleanup count is surfaced in result`() = runTest {
        val store = FakeStore(discardedEntryCount = 3)
        val effects = FakeEffects()
        val result = reconciler(store, effects).reconcile(emptyList())

        assertEquals(3, result.malformedCleanedCount)
    }

    private fun reconciler(
        store: NotificationScheduleStore,
        effects: NotificationSchedulingEffectGateway,
    ): NotificationScheduleReconciler =
        NotificationScheduleReconciler(
            store,
            effects,
            NotificationScheduleCoordinator(store, effects),
        )

    private fun record(scope: String, triggerAtMillis: Long): NotificationScheduleRecord =
        candidate(scope = scope, triggerAtMillis = triggerAtMillis).toNotificationScheduleRecord()

    private fun candidate(
        scope: String,
        triggerAtMillis: Long,
        goalId: AwradId = UUID.fromString("00000000-0000-0000-0000-000000000001"),
    ): NudgeCandidate = NudgeCandidate(
        key = NudgeCandidateKey(goalId, scope, null, NudgeKind.DEADLINE_WARNING),
        triggerAtMillis = triggerAtMillis,
        expiresAtMillis = Math.addExact(triggerAtMillis, 1_000L),
        progressCount = 0,
        remainingCount = 1,
    )

    private suspend inline fun <reified T : Throwable> assertFailsSuspend(
        block: suspend () -> Unit,
    ): T {
        try {
            block()
        } catch (error: Throwable) {
            if (error is T) return error
            throw error
        }
        fail("Expected ${T::class.java.simpleName}")
        error("Unreachable")
    }

    private class FakeStore(
        manifest: Set<NotificationScheduleRecord> = emptySet(),
        delivered: Set<DeliveredNotificationStage> = emptySet(),
        private val discardedEntryCount: Int = 0,
        private val readFailure: Throwable? = null,
        private val writeFailure: Throwable? = null,
        private val eventLog: MutableList<String>? = null,
    ) : NotificationScheduleStore {
        var manifest: Set<NotificationScheduleRecord> = manifest
        var delivered: Set<DeliveredNotificationStage> = delivered
        var readCalls = 0
        var replaceCalls = 0
        val writes = mutableListOf<Set<NotificationScheduleRecord>>()

        override suspend fun read(): NotificationScheduleState {
            readCalls++
            readFailure?.let { throw it }
            return NotificationScheduleState(manifest, delivered, discardedEntryCount)
        }

        override suspend fun replaceManifest(records: Collection<NotificationScheduleRecord>) {
            replaceCalls++
            writeFailure?.let { throw it }
            manifest = records.toSet()
            writes += manifest
            eventLog?.add("write")
        }

        override suspend fun markDelivered(identity: NotificationIdentity, deliveredAtMillis: Long) {
            manifest = manifest.filterNot { it.identity == identity }.toSet()
            delivered = delivered + DeliveredNotificationStage(identity, deliveredAtMillis)
        }
        override suspend fun clearExact(canonicalKey: String) {
            manifest = manifest.filterNot { it.identity.canonicalKey == canonicalKey }.toSet()
            delivered = delivered.filterNot { it.identity.canonicalKey == canonicalKey }.toSet()
        }
        override suspend fun clearGoal(goalId: AwradId) {
            manifest = manifest.filterNot { it.identity.goalId == goalId }.toSet()
            delivered = delivered.filterNot { it.identity.goalId == goalId }.toSet()
        }
        override suspend fun retainDelivered(retainedCanonicalKeys: Set<String>) {
            delivered = delivered.filter { it.identity.canonicalKey in retainedCanonicalKeys }.toSet()
        }
    }

    private class FakeEffects(
        var cancelFailure: Throwable? = null,
        var scheduleFailure: Throwable? = null,
        var scheduleResult: NotificationSchedulingEffectResult = NotificationSchedulingEffectResult.Scheduled,
        private val scheduleResultFor: (NotificationScheduleRecord) -> NotificationSchedulingEffectResult = {
            scheduleResult
        },
        private val eventLog: MutableList<String>? = null,
        private val onSchedule: suspend (NotificationScheduleRecord) -> Unit = {},
    ) : NotificationSchedulingEffectGateway {
        val operations = mutableListOf<String>()
        val activeByIdentity = linkedMapOf<String, NotificationScheduleRecord>()
        var visibleCancels = 0

        override suspend fun cancelPending(identity: NotificationIdentity) {
            operations += "cancel:${identity.obligationScope}"
            eventLog?.add("cancel:${identity.obligationScope}")
            cancelFailure?.let { throw it }
            activeByIdentity.remove(identity.canonicalKey)
        }

        override suspend fun cancelVisible(identity: NotificationIdentity) {
            operations += "visible:${identity.obligationScope}"
            visibleCancels++
        }

        override suspend fun schedule(record: NotificationScheduleRecord): NotificationSchedulingEffectResult {
            operations += "schedule:${record.identity.obligationScope}"
            eventLog?.add("schedule:${record.identity.obligationScope}")
            scheduleFailure?.let { throw it }
            onSchedule(record)
            activeByIdentity[record.identity.canonicalKey] = record
            return scheduleResultFor(record)
        }

        fun operationsWith(store: FakeStore): List<String> =
            operations + List(store.replaceCalls) { "write" }
    }
}
