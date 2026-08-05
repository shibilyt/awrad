package app.awrad.awrad_dhikrgoalstracker.util

import app.awrad.awrad_dhikrgoalstracker.data.model.CalendarSystem
import app.awrad.awrad_dhikrgoalstracker.data.model.DayResetOption
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSpecificDate
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.SeasonTemplateCode
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.model.Threshold
import app.awrad.awrad_dhikrgoalstracker.data.model.newAwradId
import app.awrad.awrad_dhikrgoalstracker.notification.ContinuityUnit
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligation
import app.awrad.awrad_dhikrgoalstracker.notification.NotificationObligationPlanner
import app.awrad.awrad_dhikrgoalstracker.notification.NudgeKind
import app.awrad.awrad_dhikrgoalstracker.notification.ObligationProgress
import app.awrad.awrad_dhikrgoalstracker.notification.ObligationScope
import app.awrad.awrad_dhikrgoalstracker.notification.ObligationSemantics
import app.awrad.awrad_dhikrgoalstracker.notification.ObligationWindow
import app.awrad.awrad_dhikrgoalstracker.notification.ResolvedObligationInterval
import app.awrad.awrad_dhikrgoalstracker.notification.ResolvedObligationSlot
import java.io.File
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BehaviorFixtureParityTest {
    private val planner = NotificationObligationPlanner()

    @Test
    fun sharedFixtureCoversEveryCalculatorFamilyAndDrivesRecurrence() {
        val document = Json.parseToJsonElement(fixture().readText()).jsonObject
        val required = setOf(
            "effective_day", "recurrence", "count_limits", "slot_selection",
            "counting_availability", "streaks", "reminder_plans", "wird_cadence",
            "notification_obligations",
        )
        required.forEach { section -> assertTrue(document.getValue(section).jsonArray.isNotEmpty()) }

        document.getValue("recurrence").jsonArray.forEach { element ->
            val case = element.jsonObject
            val id = case.getValue("id").jsonPrimitive.content
            val date = LocalDate.parse(case.getValue("date").jsonPrimitive.content)
            val expected = case.getValue("expected").jsonPrimitive.boolean
            assertEquals(id, expected, GoalProgressCalculator.isDueToday(goalFor(id), date))
        }
    }

    @Test
    fun sharedFixtureNotificationObligationsExecuteProduction() {
        val cases = Json.parseToJsonElement(fixture().readText()).jsonObject
            .getValue("notification_obligations").jsonArray
            .map { it.jsonObject }
        val ids = cases.map { it.getValue("id").jsonPrimitive.content }

        assertEquals(
            "duplicate notification obligation ids",
            ids.size,
            ids.toSet().size,
        )
        assertEquals(EXPECTED_NOTIFICATION_OBLIGATION_IDS.size, ids.size)
        assertEquals(EXPECTED_NOTIFICATION_OBLIGATION_IDS, ids.toSet())

        cases.forEach { case ->
            when (val id = case.getValue("id").jsonPrimitive.content) {
                "target_policies_and_recurrence" -> assertTargetPoliciesAndRecurrence(case)
                "per_due_date_anytime_warning",
                "time_window_warning",
                "prayer_slot_warning",
                "odd_millisecond_time_window_warning",
                -> assertPlannerWarning(case, id)
                "warning_suppression" -> assertWarningSuppression(case)
                "cumulative_urgency_requires_end" -> assertCumulativeUrgencyRequiresEnd(case)
                "none_has_no_remaining_count" -> assertNoneHasNoRemainingCount(case)
                "global_urgency_toggle" -> assertGlobalUrgencyToggle(case)
                "streak_guardian_threshold" -> assertStreakGuardianThreshold(case)
                "goal_completion_and_recurring_satisfaction" -> assertGoalCompletionAndRecurringSatisfaction(case)
                "conjunctive_active_slot_continuity" -> assertConjunctiveActiveSlotContinuity(case)
                "effective_day_boundaries" -> assertEffectiveDayBoundaries(case)
                "slice_one_non_goals" -> assertSliceOneNonGoals(case)
                else -> error("Unknown notification obligation fixture id: $id")
            }
        }
    }

    private fun assertTargetPoliciesAndRecurrence(case: JsonObject) {
        val date = LocalDate.parse("2026-07-13")
        case.getValue("policies").jsonArray.map { it.jsonObject }.forEach { policy ->
            val targetPolicy = targetPolicyOf(policy.getValue("target_policy").jsonPrimitive.content)
            val goal = policyGoal(
                targetPolicy = targetPolicy,
                recurrence = policy.getValue("recurrence").jsonPrimitive.content,
            )
            val due = GoalProgressCalculator.isDueToday(goal, date)
            val window = GoalProgressCalculator.currentProgressWindow(goal, date)
            val continuity = ObligationSemantics.continuityUnit(goal.targetPolicy)
            val scheduledUnit = derivedScheduledUnit(targetPolicy, continuity, window)

            assertTrue("recurrence must schedule $targetPolicy on $date", due)
            assertEquals(true, policy.getValue("recurrence_aware").jsonPrimitive.boolean)
            assertEquals(
                policy.getValue("scheduled_unit").jsonPrimitive.content,
                scheduledUnit,
            )
        }
    }

    /**
     * Maps production continuity/window semantics onto the fixture ledger's scheduled_unit wire.
     * Cumulative has no progress window but still schedules occurrence days via recurrence.
     * Tracker (`none`) is recurrence-aware with continuity occurrence, but the ledger unit is none.
     */
    private fun derivedScheduledUnit(
        targetPolicy: TargetPolicy,
        continuity: ContinuityUnit,
        window: DateWindow?,
    ): String = when (continuity) {
        ContinuityUnit.COMPLETED_PERIOD -> {
            requireNotNull(window) { "period_total must expose a progress window" }
            "period"
        }
        ContinuityUnit.SCHEDULED_OCCURRENCE ->
            if (targetPolicy == TargetPolicy.NONE) "none" else "occurrence"
        ContinuityUnit.NONE -> {
            assertNull(window)
            "occurrence"
        }
    }

    private fun assertPlannerWarning(case: JsonObject, id: String) {
        val expected = Instant.parse(case.getValue("expected_warning_at").jsonPrimitive.content).toEpochMilli()
        assertEquals(id, expected, plannerWarningFor(case))
    }

    private fun assertWarningSuppression(case: JsonObject) {
        case.getValue("examples").jsonArray.map { it.jsonObject }.forEach { example ->
            val reason = example.getValue("reason").jsonPrimitive.content
            assertNull(example.getValue("expected_warning_at").jsonPrimitive.contentOrNull)
            val candidates = planner.plan(suppressedObligation(reason))
            assertTrue(reason, candidates.isEmpty())
            if (reason == "warning_at_not_after_planning_now") {
                assertFalse(example.getValue("retime_to_now").jsonPrimitive.boolean)
            }
        }
    }

    private fun assertCumulativeUrgencyRequiresEnd(case: JsonObject) {
        val withoutEnd = case.getValue("without_end").jsonObject
        assertNull(withoutEnd.getValue("expected_urgency").jsonPrimitive.contentOrNull)
        assertTrue(
            planner.plan(
                cumulativeObligation(
                    start = Instant.parse("2026-07-01T00:00:00Z").toEpochMilli(),
                    deadline = Instant.parse("2026-07-31T00:00:00Z").toEpochMilli(),
                    endDate = null,
                    durationDays = null,
                ),
            ).isEmpty(),
        )

        listOf("with_end_date", "with_duration").forEach { key ->
            val variant = case.getValue(key).jsonObject
            val expected = Instant.parse(variant.getValue("expected_warning_at").jsonPrimitive.content)
                .toEpochMilli()
            assertEquals(key, expected, plannerCumulativeWarningFor(variant))
        }
    }

    private fun assertNoneHasNoRemainingCount(case: JsonObject) {
        assertNull(case.getValue("expected_remaining_count").jsonPrimitive.contentOrNull)
        val candidate = planner.plan(
            trackerObligation(currentStreak = 3),
        ).single()
        assertEquals(NudgeKind.STREAK_GUARDIAN, candidate.key.kind)
        assertNull(candidate.remainingCount)
    }

    private fun assertGlobalUrgencyToggle(case: JsonObject) {
        val disabled = case.getValue("urgency_enabled_false").jsonObject
        val enabled = case.getValue("urgency_enabled_true").jsonObject
        assertEquals(false, disabled.getValue("global_urgency_enabled").jsonPrimitive.boolean)
        assertEquals(true, enabled.getValue("global_urgency_enabled").jsonPrimitive.boolean)
        assertNull(disabled.getValue("expected_urgency").jsonPrimitive.contentOrNull)
        assertEquals("eligible", enabled.getValue("expected_urgency").jsonPrimitive.content)

        assertTrue(planner.plan(anytimeWarningObligation(urgencyEnabled = false)).isEmpty())
        assertTrue(planner.plan(anytimeWarningObligation(urgencyEnabled = true)).isNotEmpty())
    }

    private fun assertStreakGuardianThreshold(case: JsonObject) {
        val below = case.getValue("below_threshold").jsonObject
        val at = case.getValue("at_threshold").jsonObject
        assertEquals(2, below.getValue("current_streak").jsonPrimitive.int)
        assertEquals(3, at.getValue("current_streak").jsonPrimitive.int)
        assertEquals(false, below.getValue("eligible").jsonPrimitive.boolean)
        assertEquals(true, at.getValue("eligible").jsonPrimitive.boolean)

        assertFalse(
            planner.plan(trackerObligation(currentStreak = 2))
                .any { it.key.kind == NudgeKind.STREAK_GUARDIAN },
        )
        assertTrue(
            planner.plan(trackerObligation(currentStreak = 3))
                .any { it.key.kind == NudgeKind.STREAK_GUARDIAN },
        )
    }

    private fun assertGoalCompletionAndRecurringSatisfaction(case: JsonObject) {
        val recurring = case.getValue("recurring_occurrence_satisfied").jsonObject
        val completed = case.getValue("goal_lifecycle_completed").jsonObject
        assertLifecycle(recurring, goalCompleted = false)
        assertLifecycle(completed, goalCompleted = true)
    }

    private fun assertLifecycle(fixture: JsonObject, goalCompleted: Boolean) {
        val satisfied = fixture.getValue("occurrence_satisfied").jsonPrimitive.boolean
        val goal = policyGoal(
            targetPolicy = TargetPolicy.PER_DUE_DATE,
            recurrence = "weekly",
            completedAt = if (goalCompleted) Instant.parse("2026-07-13T00:00:00Z").toEpochMilli() else null,
        )
        val state = ObligationSemantics.lifecycle(
            goal = goal,
            now = Instant.parse("2026-07-13T12:00:00Z"),
            window = null,
            satisfied = satisfied,
        )
        assertEquals(satisfied, state.obligationSatisfied)
        assertEquals(
            fixture.getValue("goal_completed").jsonPrimitive.boolean,
            state.goalCompleted,
        )
    }

    private fun assertConjunctiveActiveSlotContinuity(case: JsonObject) {
        assertSlotContinuity(case.getValue("all_active_slots_at_threshold").jsonObject)
        assertSlotContinuity(case.getValue("overcounted_other_slot").jsonObject)
    }

    private fun assertSlotContinuity(fixture: JsonObject) {
        val thresholdsMet = fixture.getValue("active_slot_thresholds_met").jsonArray
            .map { it.jsonPrimitive.boolean }
        val goalId = newAwradId()
        val slots = thresholdsMet.map {
            GoalSlot(
                id = newAwradId(),
                goalId = goalId,
                slotType = GoalSlotType.TIME_WINDOW,
                targetCount = 10,
            )
        }
        val goal = Goal(
            id = goalId,
            dhikrId = newAwradId(),
            targetPolicy = TargetPolicy.PER_DUE_DATE,
            targetCount = 10,
            slots = slots,
            startDate = LocalDate.parse("2026-07-01"),
        )
        val counts = slots.zip(thresholdsMet).associate { (slot, met) ->
            slot.id to if (met) 10L else 0L
        }
        assertEquals(
            fixture.getValue("continuous").jsonPrimitive.boolean,
            ObligationSemantics.isOccurrenceContinuous(goal, counts),
        )

        val start = Instant.parse("2026-07-15T08:00:00Z").toEpochMilli()
        val end = Instant.parse("2026-07-15T13:00:00Z").toEpochMilli()
        val candidates = planner.plan(
            NotificationObligation(
                goal = goal,
                window = ObligationWindow(
                    ObligationScope(LocalDate.parse("2026-07-15")),
                    deadlineMillis = end,
                    startMillis = start,
                ),
                isScheduled = true,
                resolvedSlots = slots.map { slot ->
                    ResolvedObligationSlot(
                        slotId = slot.id,
                        slotType = GoalSlotType.TIME_WINDOW,
                        interval = ResolvedObligationInterval(start, end),
                    )
                },
                progress = ObligationProgress(slotCounts = counts),
                currentStreak = 0,
                urgencyEnabled = true,
                planningNowMillis = start - 1,
            ),
        )
        val warnedSlotIds = candidates
            .filter { it.key.kind == NudgeKind.DEADLINE_WARNING }
            .map { it.key.slotId }
            .toSet()
        val unmet = slots.zip(thresholdsMet).filterNot { it.second }.map { it.first.id }.toSet()
        assertEquals(unmet, warnedSlotIds)
    }

    private fun assertEffectiveDayBoundaries(case: JsonObject) {
        assertEffectiveDay(case.getValue("midnight").jsonObject)
        assertEffectiveDay(case.getValue("maghrib").jsonObject)
    }

    private fun assertEffectiveDay(fixture: JsonObject) {
        val dayReset = when (fixture.getValue("day_reset").jsonPrimitive.content) {
            "midnight" -> DayResetOption.MIDNIGHT
            "maghrib" -> DayResetOption.MAGHRIB
            else -> error("Unknown day_reset")
        }
        val now = Instant.parse(fixture.getValue("now").jsonPrimitive.content)
        val maghrib = fixture["maghrib"]?.jsonPrimitive?.contentOrNull?.let(Instant::parse)
        val maghribCivil = maghrib?.atZone(ZoneOffset.UTC)?.toLocalDate()
        val window = DateProvider.effectiveDayWindow(
            now = now,
            zoneId = ZoneOffset.UTC,
            dayReset = dayReset,
            maghribForCivilDate = { date ->
                when {
                    maghrib == null || maghribCivil == null -> null
                    date == maghribCivil -> maghrib
                    // Resolver needs the next civil Maghrib to close the end-exclusive window.
                    date == maghribCivil.plusDays(1) -> maghrib.plusSeconds(86_400)
                    else -> null
                }
            },
        )
        assertEquals(
            LocalDate.parse(fixture.getValue("expected_date").jsonPrimitive.content),
            window.effectiveDate,
        )
    }

    private fun assertSliceOneNonGoals(case: JsonObject) {
        assertEquals(
            listOf("pacing", "adaptive_budget", "collision", "exact_delivery"),
            case.getValue("excluded").jsonArray.map { it.jsonPrimitive.content },
        )
    }

    private fun plannerWarningFor(case: JsonObject): Long {
        val goalId = newAwradId()
        val slotType = when (case.getValue("slot_type").jsonPrimitive.content) {
            "anytime" -> GoalSlotType.ANYTIME
            "time_window" -> GoalSlotType.TIME_WINDOW
            "prayer" -> GoalSlotType.PRAYER
            else -> error("Unknown fixture slot type")
        }
        val slotId = newAwradId()
        val start = case["slot_start"]?.jsonPrimitive?.contentOrNull?.let(Instant::parse)?.toEpochMilli()
        val end = case["slot_end"]?.jsonPrimitive?.contentOrNull?.let(Instant::parse)?.toEpochMilli()
        val deadline = case["obligation_deadline"]?.jsonPrimitive?.contentOrNull?.let(Instant::parse)?.toEpochMilli()
            ?: end
        val goal = Goal(
            id = goalId,
            dhikrId = newAwradId(),
            targetPolicy = TargetPolicy.PER_DUE_DATE,
            targetCount = 10,
            slots = listOf(GoalSlot(id = slotId, goalId = goalId, slotType = slotType, targetCount = 10)),
            startDate = LocalDate.parse("2026-01-01"),
        )
        return planner.plan(
            NotificationObligation(
                goal = goal,
                window = ObligationWindow(ObligationScope(LocalDate.parse("2026-07-15")), deadline),
                isScheduled = true,
                resolvedSlots = listOf(
                    ResolvedObligationSlot(
                        slotId = slotId,
                        slotType = slotType,
                        interval = if (slotType == GoalSlotType.ANYTIME) null else ResolvedObligationInterval(start, end),
                    ),
                ),
                progress = ObligationProgress(),
                currentStreak = 0,
                urgencyEnabled = true,
                planningNowMillis = start?.minus(1) ?: deadline!!.minus(151 * 60_000L),
            ),
        ).single().triggerAtMillis
    }

    private fun plannerCumulativeWarningFor(case: JsonObject): Long {
        val start = Instant.parse(case.getValue("start").jsonPrimitive.content).toEpochMilli()
        val deadline = Instant.parse(case.getValue("deadline").jsonPrimitive.content).toEpochMilli()
        return planner.plan(
            cumulativeObligation(
                start = start,
                deadline = deadline,
                endDate = case["end_date"]?.jsonPrimitive?.contentOrNull?.let(LocalDate::parse),
                durationDays = case["duration_days"]?.jsonPrimitive?.contentOrNull?.toInt(),
            ),
        ).single().triggerAtMillis
    }

    private fun cumulativeObligation(
        start: Long,
        deadline: Long,
        endDate: LocalDate?,
        durationDays: Int?,
    ): NotificationObligation {
        val goalId = newAwradId()
        return NotificationObligation(
            goal = Goal(
                id = goalId,
                dhikrId = newAwradId(),
                targetPolicy = TargetPolicy.CUMULATIVE_TOTAL,
                targetCount = 10,
                startDate = LocalDate.parse("2026-07-01"),
                endDate = endDate,
                durationDays = durationDays,
            ),
            window = ObligationWindow(
                scope = ObligationScope(LocalDate.parse("2026-07-02")),
                deadlineMillis = deadline,
                startMillis = start,
            ),
            isScheduled = true,
            resolvedSlots = emptyList(),
            progress = ObligationProgress(),
            currentStreak = 99,
            urgencyEnabled = true,
            planningNowMillis = start + 1,
        )
    }

    private fun anytimeWarningObligation(urgencyEnabled: Boolean): NotificationObligation {
        val goalId = newAwradId()
        val slotId = newAwradId()
        val deadline = Instant.parse("2026-07-15T18:00:00Z").toEpochMilli()
        return NotificationObligation(
            goal = Goal(
                id = goalId,
                dhikrId = newAwradId(),
                targetPolicy = TargetPolicy.PER_DUE_DATE,
                targetCount = 10,
                slots = listOf(
                    GoalSlot(id = slotId, goalId = goalId, slotType = GoalSlotType.ANYTIME, targetCount = 10),
                ),
                startDate = LocalDate.parse("2026-07-01"),
            ),
            window = ObligationWindow(ObligationScope(LocalDate.parse("2026-07-15")), deadline),
            isScheduled = true,
            resolvedSlots = listOf(
                ResolvedObligationSlot(slotId = slotId, slotType = GoalSlotType.ANYTIME, interval = null),
            ),
            progress = ObligationProgress(),
            currentStreak = 0,
            urgencyEnabled = urgencyEnabled,
            planningNowMillis = Instant.parse("2026-07-15T12:00:00Z").toEpochMilli(),
        )
    }

    private fun trackerObligation(currentStreak: Int): NotificationObligation {
        val goalId = newAwradId()
        val deadline = Instant.parse("2026-07-16T00:00:00Z").toEpochMilli()
        return NotificationObligation(
            goal = Goal(
                id = goalId,
                dhikrId = newAwradId(),
                targetPolicy = TargetPolicy.NONE,
                streakThreshold = Threshold.AnyPositive,
                startDate = LocalDate.parse("2026-07-01"),
            ),
            window = ObligationWindow(ObligationScope(LocalDate.parse("2026-07-15")), deadline),
            isScheduled = true,
            resolvedSlots = emptyList(),
            progress = ObligationProgress(),
            currentStreak = currentStreak,
            urgencyEnabled = true,
            planningNowMillis = Instant.parse("2026-07-15T12:00:00Z").toEpochMilli(),
        )
    }

    private fun suppressedObligation(reason: String): NotificationObligation {
        val goalId = newAwradId()
        val slotId = newAwradId()
        val start = Instant.parse("2026-07-15T08:00:00Z").toEpochMilli()
        val end = start + 100_000L
        val goal = Goal(
            id = goalId,
            dhikrId = newAwradId(),
            targetPolicy = TargetPolicy.PER_DUE_DATE,
            targetCount = 10,
            slots = listOf(
                GoalSlot(id = slotId, goalId = goalId, slotType = GoalSlotType.TIME_WINDOW, targetCount = 10),
            ),
            startDate = LocalDate.parse("2026-07-01"),
        )
        fun base(
            interval: ResolvedObligationInterval,
            now: Long,
            progress: ObligationProgress = ObligationProgress(),
        ) = NotificationObligation(
            goal = goal,
            window = ObligationWindow(ObligationScope(LocalDate.parse("2026-07-15")), end, start),
            isScheduled = true,
            resolvedSlots = listOf(
                ResolvedObligationSlot(slotId = slotId, slotType = GoalSlotType.TIME_WINDOW, interval = interval),
            ),
            progress = progress,
            currentStreak = 0,
            urgencyEnabled = true,
            planningNowMillis = now,
        )
        return when (reason) {
            "invalid_slot_duration" ->
                base(ResolvedObligationInterval(end, start), start - 1)
            "unavailable_slot_duration" ->
                base(ResolvedObligationInterval(null, end), start - 1)
            "non_positive_slot_duration" ->
                base(ResolvedObligationInterval(start, start), start - 1)
            "already_satisfied" ->
                base(
                    ResolvedObligationInterval(start, end),
                    start - 1,
                    ObligationProgress(slotCounts = mapOf(slotId to 10L)),
                )
            "already_closed" ->
                base(ResolvedObligationInterval(start, end), end)
            "warning_at_not_after_planning_now" ->
                base(ResolvedObligationInterval(start, end), start + 80_000L)
            else -> error("Unknown suppression reason: $reason")
        }
    }

    private fun policyGoal(
        targetPolicy: TargetPolicy,
        recurrence: String,
        completedAt: Long? = null,
    ): Goal {
        val goalId = newAwradId()
        val frequency = when (recurrence) {
            "daily" -> RecurrenceFrequency.DAILY
            "weekly" -> RecurrenceFrequency.WEEKLY
            "monthly" -> RecurrenceFrequency.MONTHLY
            else -> error("Unknown recurrence: $recurrence")
        }
        return Goal(
            id = goalId,
            dhikrId = newAwradId(),
            targetPolicy = targetPolicy,
            targetCount = 10,
            recurrence = GoalRecurrence(
                goalId = goalId,
                frequency = frequency,
                weekdays = if (frequency == RecurrenceFrequency.WEEKLY) setOf(DayOfWeek.MONDAY) else emptySet(),
                monthDays = if (frequency == RecurrenceFrequency.MONTHLY) setOf(13) else emptySet(),
            ),
            startDate = LocalDate.parse("2026-07-01"),
            completedAt = completedAt,
        )
    }

    private fun targetPolicyOf(wire: String): TargetPolicy = when (wire) {
        "per_due_date" -> TargetPolicy.PER_DUE_DATE
        "period_total" -> TargetPolicy.PERIOD_TOTAL
        "cumulative_total" -> TargetPolicy.CUMULATIVE_TOTAL
        "none" -> TargetPolicy.NONE
        else -> error("Unknown target policy: $wire")
    }

    private fun goalFor(id: String): Goal {
        val goalId = newAwradId()
        val recurrence = when (id) {
            "cumulative_weekly_due" -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.WEEKLY,
                weekdays = setOf(DayOfWeek.MONDAY),
            )
            "hijri_month_day_9" -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.MONTHLY,
                calendar = CalendarSystem.HIJRI,
                monthDays = setOf(9, 10),
            )
            "hijri_yearly_1_10" -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.YEARLY,
                calendar = CalendarSystem.HIJRI,
                month = 1,
                monthDays = setOf(10),
            )
            "fixed_specific_date" -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.SPECIFIC_DATES,
                specificDates = setOf(GoalSpecificDate(date = LocalDate.parse("2026-07-15"))),
            )
            "ashura_9", "ashura_10" -> GoalRecurrence(
                goalId = goalId,
                frequency = RecurrenceFrequency.SEASON,
                calendar = CalendarSystem.HIJRI,
                seasonTemplateCode = SeasonTemplateCode.ASHURA,
            )
            else -> error("Unknown recurrence fixture $id")
        }
        return Goal(
            id = goalId,
            dhikrId = newAwradId(),
            targetPolicy = if (id == "cumulative_weekly_due") TargetPolicy.CUMULATIVE_TOTAL else TargetPolicy.PER_DUE_DATE,
            recurrence = recurrence,
            startDate = LocalDate.parse("2026-01-01"),
        )
    }

    private fun fixture(): File =
        generateSequence(File(checkNotNull(System.getProperty("user.dir")))) { it.parentFile }
            .map { File(it, "contracts/behavior-model/v1/fixtures/behavior-cases.json") }
            .first(File::isFile)

    private companion object {
        val EXPECTED_NOTIFICATION_OBLIGATION_IDS = setOf(
            "target_policies_and_recurrence",
            "per_due_date_anytime_warning",
            "time_window_warning",
            "prayer_slot_warning",
            "odd_millisecond_time_window_warning",
            "warning_suppression",
            "cumulative_urgency_requires_end",
            "none_has_no_remaining_count",
            "global_urgency_toggle",
            "streak_guardian_threshold",
            "goal_completion_and_recurring_satisfaction",
            "conjunctive_active_slot_continuity",
            "effective_day_boundaries",
            "slice_one_non_goals",
        )
    }
}
