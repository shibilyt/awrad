package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.DayResetOption
import java.time.ZoneOffset
import java.util.UUID
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UrgencyNudgeFireValidatorTest {
    @Test
    fun `valid manifest stage replans immediately before original trigger`() = runBlocking {
        val stage = stage(goalSuffix = "001")
        var plannedAt: Long? = null
        val harness = harness(
            stage = stage,
            planProvider = CountingPlanProvider {
                plannedAt = it.nowMillis
                listOf(stage.planned)
            },
        )

        val result = harness.validator.validate(stage.envelope, context(nowMillis = stage.trigger))

        assertEquals(stage.trigger - 1L, plannedAt)
        assertEquals(
            UrgencyNudgeValidationOutcome.Valid(stage.planned, remainingDurationMillis = 1_000L),
            result,
        )
    }

    @Test
    fun `successful validated handler tombstones stage after callback`() = runBlocking {
        val stage = stage(goalSuffix = "002")
        val harness = harness(stage)

        val result = harness.validator.validateAndPost(
            envelope = stage.envelope,
            context = context(nowMillis = stage.trigger),
            postingAction = UrgencyNudgePostingAction { nudge ->
                assertEquals(8L, nudge.remainingCount)
            },
        )

        assertEquals(UrgencyNudgeValidationOutcome.Valid::class, result::class)
        assertEquals(emptySet<NotificationScheduleRecord>(), harness.store.read().manifest)
        assertEquals(setOf(stage.identity), harness.store.read().delivered.map { it.identity }.toSet())
    }

    @Test
    fun `remaining duration saturates across epoch range`() = runBlocking {
        val stage = stage(
            goalSuffix = "003",
            scope = "scope",
            trigger = Long.MIN_VALUE + 1L,
            expires = Long.MAX_VALUE,
            progressCount = 0L,
            remainingCount = 1L,
        )
        val harness = harness(stage)

        val result = harness.validator.validate(
            stage.envelope,
            context(nowMillis = stage.trigger),
        ) as UrgencyNudgeValidationOutcome.Valid

        assertEquals(Long.MAX_VALUE, result.remainingDurationMillis)
    }

    @Test
    fun `failing handler keeps manifest retryable`() = runBlocking {
        val stage = stage(goalSuffix = "004", scope = "scope", progressCount = 0L, remainingCount = 1L)
        val harness = harness(stage)

        val failure = runCatching {
            harness.validator.validateAndPost(
                stage.envelope,
                context(nowMillis = stage.trigger),
                UrgencyNudgePostingAction { error("posting failed") },
            )
        }.exceptionOrNull()

        assertEquals("posting failed", failure?.message)
        assertEquals(setOf(stage.record), harness.store.read().manifest)
        assertEquals(emptySet<DeliveredNotificationStage>(), harness.store.read().delivered)
    }

    @Test
    fun `posting action reentering scheduling fails fast`() = runBlocking {
        val stage = stage(goalSuffix = "005", scope = "scope", progressCount = 0L, remainingCount = 1L)
        val harness = harness(stage)

        val failure = runCatching {
            harness.validator.validateAndPost(
                stage.envelope,
                context(nowMillis = stage.trigger),
                UrgencyNudgePostingAction { harness.coordinator.clearExact(stage.identity.canonicalKey) },
            )
        }.exceptionOrNull()

        assertTrue(failure is IllegalStateException)
        assertEquals(setOf(stage.record), harness.store.read().manifest)
        assertEquals(emptySet<DeliveredNotificationStage>(), harness.store.read().delivered)
    }

    @Test
    fun `store failure after post remains retryable and posts again`() = runBlocking {
        val stage = stage(goalSuffix = "006", scope = "scope", progressCount = 0L, remainingCount = 1L)
        val store = FakeStore(setOf(stage.record), markFailure = IllegalStateException("DataStore unavailable"))
        val harness = harness(stage, store = store)
        var postCount = 0
        val action = UrgencyNudgePostingAction { postCount++ }

        val firstFailure = runCatching {
            harness.validator.validateAndPost(stage.envelope, context(nowMillis = stage.trigger), action)
        }.exceptionOrNull()
        assertEquals("DataStore unavailable", firstFailure?.message)
        assertEquals(1, postCount)
        assertEquals(setOf(stage.record), store.read().manifest)
        assertEquals(emptySet<DeliveredNotificationStage>(), store.read().delivered)

        store.markFailure = null
        harness.validator.validateAndPost(stage.envelope, context(nowMillis = stage.trigger), action)

        assertEquals(2, postCount)
        assertEquals(emptySet<NotificationScheduleRecord>(), store.read().manifest)
        assertEquals(setOf(stage.identity), store.read().delivered.map { it.identity }.toSet())
    }

    @Test
    fun `TOO_EARLY rejects before trigger without posting`() = runBlocking {
        val stage = stage(goalSuffix = "010")
        assertRejected(
            stage = stage,
            nowMillis = stage.trigger - 1L,
            expected = UrgencyNudgeRejectionReason.TOO_EARLY,
        )
    }

    @Test
    fun `EXPIRED rejects at expiry equality and after without posting`() = runBlocking {
        val stage = stage(goalSuffix = "011")
        assertRejected(
            stage = stage,
            nowMillis = stage.expires,
            expected = UrgencyNudgeRejectionReason.EXPIRED,
        )
        assertRejected(
            stage = stage,
            nowMillis = stage.expires + 1L,
            expected = UrgencyNudgeRejectionReason.EXPIRED,
        )
    }

    @Test
    fun `ALREADY_DELIVERED rejects without posting`() = runBlocking {
        val stage = stage(goalSuffix = "012")
        assertRejected(
            stage = stage,
            nowMillis = stage.trigger,
            expected = UrgencyNudgeRejectionReason.ALREADY_DELIVERED,
            store = FakeStore(
                manifest = setOf(stage.record),
                delivered = setOf(DeliveredNotificationStage(stage.identity, stage.trigger)),
            ),
        )
    }

    @Test
    fun `missing manifest rejects as NOT_SCHEDULED_OR_REPLACED without posting`() = runBlocking {
        val stage = stage(goalSuffix = "013")
        assertRejected(
            stage = stage,
            nowMillis = stage.trigger,
            expected = UrgencyNudgeRejectionReason.NOT_SCHEDULED_OR_REPLACED,
            store = FakeStore(manifest = emptySet()),
        )
    }

    @Test
    fun `manifest changed trigger rejects as NOT_SCHEDULED_OR_REPLACED without posting`() = runBlocking {
        val stage = stage(goalSuffix = "014")
        assertRejected(
            stage = stage,
            nowMillis = stage.trigger,
            expected = UrgencyNudgeRejectionReason.NOT_SCHEDULED_OR_REPLACED,
            store = FakeStore(
                manifest = setOf(stage.record.copy(triggerAtMillis = stage.trigger + 50L)),
            ),
        )
    }

    @Test
    fun `manifest changed expiry rejects as NOT_SCHEDULED_OR_REPLACED without posting`() = runBlocking {
        val stage = stage(goalSuffix = "015")
        assertRejected(
            stage = stage,
            nowMillis = stage.trigger,
            expected = UrgencyNudgeRejectionReason.NOT_SCHEDULED_OR_REPLACED,
            store = FakeStore(
                manifest = setOf(stage.record.copy(expiresAtMillis = stage.expires + 50L)),
            ),
        )
    }

    @Test
    fun `identity kind envelope mismatch fails at parser seam without posting`() {
        val stage = stage(goalSuffix = "016")
        val validInput = UrgencyNudgeWorkInput.from(stage.envelope)

        assertNull(
            "kind mismatch must not form a fireable envelope",
            validInput.copy(kind = NudgeKind.STREAK_GUARDIAN).toEnvelope(),
        )
        assertNull(
            "malformed identity must not form a fireable envelope",
            validInput.copy(canonicalIdentity = "not-a-canonical-identity").toEnvelope(),
        )
        // AdaptiveNudgeEnvelope construction itself rejects kind/identity divergence.
        val constructionFailure = runCatching {
            AdaptiveNudgeEnvelope(stage.identity, stage.trigger, stage.expires, NudgeKind.STREAK_GUARDIAN)
        }.exceptionOrNull()
        assertTrue(constructionFailure is IllegalArgumentException)
    }

    @Test
    fun `DISABLED rejects without querying plan provider or posting`() = runBlocking {
        val stage = stage(goalSuffix = "017")
        val planProvider = CountingPlanProvider { listOf(stage.planned) }
        val harness = harness(
            stage = stage,
            planProvider = planProvider,
            urgencyEnabled = false,
        )
        var postCount = 0

        val result = harness.validator.validateAndPost(
            stage.envelope,
            context(nowMillis = stage.trigger),
            UrgencyNudgePostingAction { postCount++ },
        )

        assertEquals(UrgencyNudgeValidationOutcome.Rejected(UrgencyNudgeRejectionReason.DISABLED), result)
        assertEquals(0, postCount)
        assertEquals(0, planProvider.calls)
    }

    @Test
    fun `trigger underflow rejects without posting`() = runBlocking {
        val stage = stage(
            goalSuffix = "018",
            trigger = Long.MIN_VALUE,
            expires = Long.MIN_VALUE + 1_000L,
            progressCount = 0L,
            remainingCount = 1L,
        )
        assertRejected(
            stage = stage,
            nowMillis = stage.trigger,
            expected = UrgencyNudgeRejectionReason.TRIGGER_UNDERFLOW,
        )
    }

    @Test
    fun `NO_LONGER_RELEVANT rejects labeled live-replan absences without posting`() = runBlocking {
        val stage = stage(goalSuffix = "020")
        val thresholdChanged = stage.planned.copy(
            record = stage.record.copy(triggerAtMillis = 1_100L, expiresAtMillis = 2_100L),
        )
        val invalidSlotIdentity = NotificationIdentity.create(
            goalId = stage.identity.goalId,
            obligationScope = stage.identity.obligationScope,
            slotId = UUID.fromString("00000000-0000-0000-0000-000000000099"),
            kind = stage.identity.kind,
        )
        val invalidSlot = PlannedUrgencyNudge(
            record = NotificationScheduleRecord(invalidSlotIdentity, stage.trigger, stage.expires),
            goalId = invalidSlotIdentity.goalId,
            goalName = "Goal",
            slotId = invalidSlotIdentity.slotId,
            slotType = null,
            progressCount = 2L,
            remainingCount = 8L,
        )
        val cases = listOf(
            "completed" to emptyList(),
            "paused" to emptyList(),
            "deleted" to emptyList(),
            "unscheduled" to emptyList(),
            "satisfied" to emptyList(),
            "threshold changed" to listOf(thresholdChanged),
            "invalid slot" to listOf(invalidSlot),
        )

        for ((semanticReason, livePlan) in cases) {
            assertRejected(
                stage = stage,
                nowMillis = stage.trigger,
                expected = UrgencyNudgeRejectionReason.NO_LONGER_RELEVANT,
                planProvider = CountingPlanProvider { livePlan },
                message = "semantic reason=$semanticReason",
            )
        }
    }

    @Test
    fun `dependency read plan and preference failures do not post`() = runBlocking {
        val stage = stage(goalSuffix = "019", progressCount = 0L, remainingCount = 1L)
        var postCount = 0
        val action = UrgencyNudgePostingAction { postCount++ }

        val readFailure = runCatching {
            harness(
                stage = stage,
                store = FakeStore(setOf(stage.record), readFailure = IllegalStateException("store read failed")),
            ).validator.validateAndPost(stage.envelope, context(nowMillis = stage.trigger), action)
        }.exceptionOrNull()
        assertEquals("store read failed", readFailure?.message)

        val preferenceFailure = runCatching {
            harness(
                stage = stage,
                urgencyEnabledProvider = UrgencyEnabledProvider { error("preference read failed") },
            ).validator.validateAndPost(stage.envelope, context(nowMillis = stage.trigger), action)
        }.exceptionOrNull()
        assertEquals("preference read failed", preferenceFailure?.message)

        val planFailure = runCatching {
            harness(
                stage = stage,
                planProvider = CountingPlanProvider { error("plan failed") },
            ).validator.validateAndPost(stage.envelope, context(nowMillis = stage.trigger), action)
        }.exceptionOrNull()
        assertEquals("plan failed", planFailure?.message)

        assertEquals(0, postCount)
    }

    private data class StageFixture(
        val identity: NotificationIdentity,
        val trigger: Long,
        val expires: Long,
        val record: NotificationScheduleRecord,
        val envelope: AdaptiveNudgeEnvelope,
        val planned: PlannedUrgencyNudge,
    )

    private data class Harness(
        val store: FakeStore,
        val coordinator: NotificationScheduleCoordinator,
        val validator: UrgencyNudgeFireValidator,
        val planProvider: CountingPlanProvider,
    )

    private fun stage(
        goalSuffix: String,
        scope: String = "2026-07-15",
        slotId: AwradId? = null,
        kind: NudgeKind = NudgeKind.DEADLINE_WARNING,
        trigger: Long = 1_000L,
        expires: Long = 2_000L,
        progressCount: Long = 2L,
        remainingCount: Long? = 8L,
    ): StageFixture {
        require(goalSuffix.length == 3 && goalSuffix.all { it.isDigit() }) {
            "goalSuffix must be a 3-digit decimal fragment"
        }
        val identity = NotificationIdentity.create(
            goalId = UUID.fromString("00000000-0000-0000-0000-000000000$goalSuffix"),
            obligationScope = scope,
            slotId = slotId,
            kind = kind,
        )
        val record = NotificationScheduleRecord(identity, trigger, expires)
        return StageFixture(
            identity = identity,
            trigger = trigger,
            expires = expires,
            record = record,
            envelope = AdaptiveNudgeEnvelope(identity, trigger, expires),
            planned = PlannedUrgencyNudge(
                record = record,
                goalId = identity.goalId,
                goalName = "Goal",
                slotId = slotId,
                slotType = null,
                progressCount = progressCount,
                remainingCount = remainingCount,
            ),
        )
    }

    private fun context(nowMillis: Long) = UrgencyNudgeValidationContext(
        nowMillis = nowMillis,
        zoneId = ZoneOffset.UTC,
        dayReset = DayResetOption.MIDNIGHT,
        defaultPrayerLeadMinutes = 30,
    )

    private fun harness(
        stage: StageFixture,
        store: FakeStore = FakeStore(setOf(stage.record)),
        planProvider: CountingPlanProvider = CountingPlanProvider { listOf(stage.planned) },
        urgencyEnabled: Boolean = true,
        urgencyEnabledProvider: UrgencyEnabledProvider = UrgencyEnabledProvider { urgencyEnabled },
    ): Harness {
        val coordinator = NotificationScheduleCoordinator(store, FakeEffects())
        return Harness(
            store = store,
            coordinator = coordinator,
            planProvider = planProvider,
            validator = UrgencyNudgeFireValidator(
                planProvider = planProvider,
                scheduleStore = store,
                urgencyEnabledProvider = urgencyEnabledProvider,
                coordinator = coordinator,
            ),
        )
    }

    private suspend fun assertRejected(
        stage: StageFixture,
        nowMillis: Long,
        expected: UrgencyNudgeRejectionReason,
        store: FakeStore = FakeStore(setOf(stage.record)),
        planProvider: CountingPlanProvider = CountingPlanProvider { listOf(stage.planned) },
        urgencyEnabled: Boolean = true,
        message: String? = null,
    ) {
        val harness = harness(
            stage = stage,
            store = store,
            planProvider = planProvider,
            urgencyEnabled = urgencyEnabled,
        )
        var postCount = 0

        val result = harness.validator.validateAndPost(
            stage.envelope,
            context(nowMillis = nowMillis),
            UrgencyNudgePostingAction { postCount++ },
        )

        if (message == null) {
            assertEquals(UrgencyNudgeValidationOutcome.Rejected(expected), result)
            assertEquals(0, postCount)
        } else {
            assertEquals(message, UrgencyNudgeValidationOutcome.Rejected(expected), result)
            assertEquals(message, 0, postCount)
        }
    }

    private class CountingPlanProvider(
        private val block: suspend (UrgencyNudgeReplanInput) -> List<PlannedUrgencyNudge>,
    ) : UrgencyNudgeLivePlanProvider {
        var calls: Int = 0
            private set

        override suspend fun plan(input: UrgencyNudgeReplanInput): List<PlannedUrgencyNudge> {
            calls++
            return block(input)
        }
    }

    private class FakeStore(
        manifest: Set<NotificationScheduleRecord>,
        delivered: Set<DeliveredNotificationStage> = emptySet(),
        var markFailure: Throwable? = null,
        var readFailure: Throwable? = null,
    ) : NotificationScheduleStore {
        private var manifest = manifest
        private var delivered = delivered

        override suspend fun read(): NotificationScheduleState {
            readFailure?.let { throw it }
            return NotificationScheduleState(manifest, delivered, 0)
        }

        override suspend fun replaceManifest(records: Collection<NotificationScheduleRecord>) {
            manifest = records.toSet()
        }

        override suspend fun markDelivered(identity: NotificationIdentity, deliveredAtMillis: Long) {
            markFailure?.let { throw it }
            manifest = manifest.filterNot { it.identity == identity }.toSet()
            delivered += DeliveredNotificationStage(identity, deliveredAtMillis)
        }

        override suspend fun clearExact(canonicalKey: String) = Unit
        override suspend fun clearGoal(goalId: AwradId) = Unit
        override suspend fun retainDelivered(retainedCanonicalKeys: Set<String>) = Unit
    }

    private class FakeEffects : NotificationSchedulingEffectGateway {
        override suspend fun schedule(record: NotificationScheduleRecord) =
            NotificationSchedulingEffectResult.Scheduled
        override suspend fun cancelPending(identity: NotificationIdentity) = Unit
        override suspend fun cancelVisible(identity: NotificationIdentity) = Unit
    }
}
