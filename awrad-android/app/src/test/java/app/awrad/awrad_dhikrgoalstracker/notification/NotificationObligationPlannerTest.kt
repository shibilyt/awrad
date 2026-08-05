package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.Threshold
import app.awrad.awrad_dhikrgoalstracker.testId
import java.time.Instant
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationObligationPlannerTest {
    private val planner = NotificationObligationPlanner()

    @Test
    fun `anytime due-date warning is exactly 150 minutes before midnight deadline`() {
        val deadline = millis("2026-07-16T00:00:00Z")

        val candidate = planner.plan(
            obligation(
                deadlineMillis = deadline,
                slots = listOf(slot(GoalSlotType.ANYTIME)),
                nowMillis = millis("2026-07-15T18:00:00Z"),
            ),
        ).single()

        assertEquals(deadline - 150 * 60_000L, candidate.triggerAtMillis)
        assertEquals(deadline, candidate.expiresAtMillis)
        assertEquals(NudgeKind.DEADLINE_WARNING, candidate.key.kind)
    }

    @Test
    fun `maghrib effective window supplies anytime deadline`() {
        val maghribDeadline = millis("2026-07-15T18:00:00Z")

        val candidate = planner.plan(
            obligation(
                deadlineMillis = maghribDeadline,
                slots = listOf(slot(GoalSlotType.ANYTIME)),
                nowMillis = millis("2026-07-15T12:00:00Z"),
            ),
        ).single()

        assertEquals(millis("2026-07-15T15:30:00Z"), candidate.triggerAtMillis)
    }

    @Test
    fun `two hour custom slot warns at minute 96`() {
        val start = millis("2026-07-15T08:00:00Z")
        val end = millis("2026-07-15T10:00:00Z")

        val candidate = planner.plan(
            obligation(
                slots = listOf(slot(GoalSlotType.TIME_WINDOW, start, end)),
                nowMillis = start - 1,
            ),
        ).single()

        assertEquals(start + 96 * 60_000L, candidate.triggerAtMillis)
        assertEquals(end, candidate.expiresAtMillis)
    }

    @Test
    fun `101 second slot keeps 800 millisecond warning precision`() {
        val start = millis("2026-07-15T08:00:00Z")
        val end = start + 101_000L

        val candidate = planner.plan(
            obligation(
                slots = listOf(slot(GoalSlotType.TIME_WINDOW, start, end)),
                nowMillis = start - 1,
            ),
        ).single()

        assertEquals(start + 80_800L, candidate.triggerAtMillis)
    }

    @Test
    fun `prayer slot warning uses supplied resolved dynamic interval`() {
        val start = millis("2026-07-15T12:30:00Z")
        val end = millis("2026-07-15T15:00:00Z")

        val candidate = planner.plan(
            obligation(
                slots = listOf(slot(GoalSlotType.PRAYER, start, end)),
                nowMillis = start - 1,
            ),
        ).single()

        assertEquals(millis("2026-07-15T14:30:00Z"), candidate.triggerAtMillis)
    }

    @Test
    fun `interval warning stays exact across the Long epoch range`() {
        val start = Long.MIN_VALUE + 10
        val end = Long.MAX_VALUE - 10

        val candidate = planner.plan(
            obligation(
                deadlineMillis = Long.MAX_VALUE,
                slots = listOf(slot(GoalSlotType.TIME_WINDOW, start, end)),
                nowMillis = Long.MIN_VALUE,
            ),
        ).single()

        assertEquals(5_534_023_222_112_865_478L, candidate.triggerAtMillis)
    }

    @Test
    fun `warning at or before planning now is omitted without retiming`() {
        val start = millis("2026-07-15T08:00:00Z")
        val end = start + 100_000L

        listOf(start + 80_000L, start + 80_001L).forEach { now ->
            assertTrue(
                planner.plan(
                    obligation(
                        slots = listOf(slot(GoalSlotType.TIME_WINDOW, start, end)),
                        nowMillis = now,
                    ),
                ).isEmpty(),
            )
        }
    }

    @Test
    fun `unavailable invalid and zero length intervals are omitted`() {
        val start = millis("2026-07-15T08:00:00Z")
        val cases = listOf(
            ResolvedObligationInterval(null, start + 1),
            ResolvedObligationInterval(start, null),
            ResolvedObligationInterval(start, start),
            ResolvedObligationInterval(start + 1, start),
        )

        cases.forEach { interval ->
            assertTrue(
                planner.plan(
                    obligation(
                        slots = listOf(
                            ResolvedObligationSlot(testId(11), GoalSlotType.TIME_WINDOW, interval),
                        ),
                        nowMillis = start - 1,
                    ),
                ).isEmpty(),
            )
        }
    }

    @Test
    fun `urgency lifecycle satisfaction and schedule gates omit warnings`() {
        val baseSlots = listOf(slot(GoalSlotType.ANYTIME))
        val satisfied = ObligationProgress(slotCounts = mapOf(testId(10) to 10))
        val now = millis("2026-07-15T12:00:00Z")
        val cases = listOf(
            obligation(baseSlots, now, urgencyEnabled = false, currentStreak = 3),
            obligation(baseSlots, now, progress = satisfied, currentStreak = 3),
            obligation(baseSlots, now, isScheduled = false, currentStreak = 3),
            obligation(baseSlots, now, completedAt = 1L, currentStreak = 3),
            obligation(baseSlots, now, endDate = LocalDate.parse("2026-07-14"), currentStreak = 3),
            obligation(baseSlots, now, deadlineMillis = now, currentStreak = 3),
        )

        cases.forEach { assertTrue(planner.plan(it).isEmpty()) }
    }

    @Test
    fun `slots keep distinct keys and own progress thresholds`() {
        val first = ResolvedObligationSlot(testId(11), GoalSlotType.ANYTIME)
        val second = ResolvedObligationSlot(testId(12), GoalSlotType.ANYTIME)
        val result = planner.plan(
            obligation(
                slots = listOf(first, second),
                nowMillis = millis("2026-07-15T12:00:00Z"),
                progress = ObligationProgress(slotCounts = mapOf(first.slotId to 10, second.slotId to 2)),
            ),
        )

        assertEquals(listOf(second.slotId), result.map { it.key.slotId })
        assertEquals(2L, result.single().progressCount)
        assertEquals(8L, result.single().remainingCount)
    }

    @Test
    fun `period total and undated cumulative do not invent deadline warnings`() {
        val slots = listOf(slot(GoalSlotType.ANYTIME))
        assertTrue(
            planner.plan(
                obligation(slots, millis("2026-07-15T12:00:00Z"), targetPolicy = TargetPolicy.PERIOD_TOTAL),
            ).none { it.key.kind == NudgeKind.DEADLINE_WARNING },
        )
        assertTrue(
            planner.plan(
                obligation(slots, millis("2026-07-15T12:00:00Z"), targetPolicy = TargetPolicy.CUMULATIVE_TOTAL),
            ).none { it.key.kind == NudgeKind.DEADLINE_WARNING },
        )
    }

    @Test
    fun `bounded cumulative end date warns at 80 percent with lifetime remaining`() {
        val start = millis("2026-07-01T00:00:00Z")
        val deadline = millis("2026-07-31T00:00:00Z")

        val candidate = planner.plan(
            obligation(
                slots = emptyList(),
                nowMillis = millis("2026-07-10T00:00:00Z"),
                deadlineMillis = deadline,
                startMillis = start,
                scopeDate = LocalDate.parse("2026-07-10"),
                targetPolicy = TargetPolicy.CUMULATIVE_TOTAL,
                endDate = LocalDate.parse("2026-07-31"),
                progress = ObligationProgress(lifetimeCount = 3),
            ),
        ).single()

        assertEquals(millis("2026-07-25T00:00:00Z"), candidate.triggerAtMillis)
        assertEquals(NudgeKind.DEADLINE_WARNING, candidate.key.kind)
        assertEquals(null, candidate.key.slotId)
        assertEquals(3L, candidate.progressCount)
        assertEquals(7L, candidate.remainingCount)
        assertEquals(deadline, candidate.expiresAtMillis)
    }

    @Test
    fun `bounded cumulative duration warns at proportional deadline without guardian`() {
        val start = millis("2026-07-01T00:00:00Z")
        val deadline = millis("2026-07-15T00:00:00Z")

        val candidates = planner.plan(
            obligation(
                slots = emptyList(),
                nowMillis = millis("2026-07-10T00:00:00Z"),
                deadlineMillis = deadline,
                startMillis = start,
                scopeDate = LocalDate.parse("2026-07-10"),
                targetPolicy = TargetPolicy.CUMULATIVE_TOTAL,
                durationDays = 14,
                currentStreak = 99,
            ),
        )

        assertEquals(listOf(NudgeKind.DEADLINE_WARNING), candidates.map { it.key.kind })
        assertEquals(millis("2026-07-12T04:48:00Z"), candidates.single().triggerAtMillis)
    }

    @Test
    fun `cumulative warnings require a valid future unsatisfied bounded lifetime`() {
        val start = millis("2026-07-01T00:00:00Z")
        val deadline = millis("2026-07-31T00:00:00Z")
        val warning = millis("2026-07-25T00:00:00Z")
        val base = obligation(
            slots = emptyList(),
            nowMillis = millis("2026-07-10T00:00:00Z"),
            deadlineMillis = deadline,
            startMillis = start,
            scopeDate = LocalDate.parse("2026-07-10"),
            targetPolicy = TargetPolicy.CUMULATIVE_TOTAL,
            endDate = LocalDate.parse("2026-07-31"),
            currentStreak = 99,
        )

        val suppressed = listOf(
            base.copy(window = base.window.copy(startMillis = null)),
            base.copy(window = base.window.copy(startMillis = deadline)),
            base.copy(window = base.window.copy(startMillis = deadline + 1)),
            base.copy(progress = ObligationProgress(lifetimeCount = 10)),
            base.copy(urgencyEnabled = false),
            base.copy(planningNowMillis = warning),
            base.copy(planningNowMillis = warning + 1),
        )

        suppressed.forEach { assertTrue(planner.plan(it).isEmpty()) }
        assertTrue(
            planner.plan(
                base.copy(goal = base.goal.copy(endDate = null, durationDays = null)),
            ).isEmpty(),
        )
        assertTrue(
            planner.plan(
                base.copy(goal = base.goal.copy(endDate = null, durationDays = 0)),
            ).isEmpty(),
        )
    }

    @Test
    fun `tracker has no numeric remaining and only emits guardian at streak threshold`() {
        val tracker = obligation(
            slots = emptyList(),
            nowMillis = millis("2026-07-15T12:00:00Z"),
            targetPolicy = TargetPolicy.NONE,
            currentStreak = 3,
            streakThreshold = Threshold.AnyPositive,
        )

        assertTrue(planner.plan(tracker.copy(currentStreak = 2)).isEmpty())
        val guardian = planner.plan(tracker).single()
        assertEquals(NudgeKind.STREAK_GUARDIAN, guardian.key.kind)
        assertNull(guardian.remainingCount)
        assertTrue(planner.plan(tracker.copy(progress = ObligationProgress(occurrenceCount = 1))).isEmpty())
    }

    @Test
    fun `tracker guardian honors its configured continuity threshold`() {
        val tracker = obligation(
            slots = emptyList(),
            nowMillis = millis("2026-07-15T12:00:00Z"),
            targetPolicy = TargetPolicy.NONE,
            currentStreak = 3,
            streakThreshold = Threshold.Custom(2),
            progress = ObligationProgress(occurrenceCount = 1),
        )

        assertEquals(NudgeKind.STREAK_GUARDIAN, planner.plan(tracker).single().key.kind)
        assertTrue(planner.plan(tracker.copy(progress = ObligationProgress(occurrenceCount = 2))).isEmpty())
    }

    @Test
    fun `guardian is occurrence level and deterministic`() {
        val slots = listOf(
            ResolvedObligationSlot(testId(12), GoalSlotType.ANYTIME),
            ResolvedObligationSlot(testId(11), GoalSlotType.ANYTIME),
        )
        val result = planner.plan(
            obligation(
                slots = slots,
                nowMillis = millis("2026-07-15T12:00:00Z"),
                currentStreak = 3,
            ),
        )

        assertEquals(3, result.size)
        assertEquals(1, result.count { it.key.kind == NudgeKind.STREAK_GUARDIAN })
        assertEquals(listOf(testId(11), testId(12), null), result.map { it.key.slotId })
        assertEquals(
            result,
            planner.plan(
                obligation(slots.reversed(), millis("2026-07-15T12:00:00Z"), currentStreak = 3),
            ),
        )
    }

    private fun obligation(
        slots: List<ResolvedObligationSlot>,
        nowMillis: Long,
        deadlineMillis: Long? = millis("2026-07-16T00:00:00Z"),
        targetPolicy: TargetPolicy = TargetPolicy.PER_DUE_DATE,
        progress: ObligationProgress = ObligationProgress(),
        currentStreak: Int = 0,
        urgencyEnabled: Boolean = true,
        isScheduled: Boolean = true,
        completedAt: Long? = null,
        endDate: LocalDate? = null,
        durationDays: Int? = null,
        streakThreshold: Threshold = Threshold.Target,
        startMillis: Long? = null,
        scopeDate: LocalDate = LocalDate.parse("2026-07-15"),
    ): NotificationObligation {
        val goalId = testId(1)
        val goal = Goal(
            id = goalId,
            dhikrId = testId(2),
            targetPolicy = targetPolicy,
            targetCount = 10,
            slots = slots.mapIndexed { index, resolved ->
                GoalSlot(
                    id = resolved.slotId,
                    goalId = goalId,
                    slotType = resolved.slotType,
                    targetCount = 10,
                    sortOrder = index,
                )
            },
            startDate = LocalDate.parse("2026-07-01"),
            completedAt = completedAt,
            endDate = endDate,
            durationDays = durationDays,
            streakThreshold = streakThreshold,
        )
        return NotificationObligation(
            goal = goal,
            window = ObligationWindow(ObligationScope(scopeDate), deadlineMillis, startMillis),
            isScheduled = isScheduled,
            resolvedSlots = slots,
            progress = progress,
            currentStreak = currentStreak,
            urgencyEnabled = urgencyEnabled,
            planningNowMillis = nowMillis,
        )
    }

    private fun slot(
        slotType: GoalSlotType,
        startMillis: Long? = null,
        endMillis: Long? = null,
    ): ResolvedObligationSlot = ResolvedObligationSlot(
        slotId = testId(if (slotType == GoalSlotType.ANYTIME) 10 else 11),
        slotType = slotType,
        interval = if (slotType == GoalSlotType.ANYTIME) null else ResolvedObligationInterval(startMillis, endMillis),
    )

    private fun millis(value: String): Long = Instant.parse(value).toEpochMilli()
}
