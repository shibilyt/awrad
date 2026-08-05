package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.DayResetOption
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.data.repository.GoalRepository
import app.awrad.awrad_dhikrgoalstracker.util.EffectiveDayWindowResolver
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.SlotTimingResolver
import com.batoulapps.adhan.PrayerTimes
import kotlinx.coroutines.flow.first
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import javax.inject.Inject

/**
 * Framework-effect-free bridge from persisted local goal/count state to the pure obligation planner.
 * The caller injects clock, zone, day-boundary, and prayer inputs; this service only reads data and
 * returns the desired canonical schedule manifest.
 */
data class NotificationObligationPlanInput(
    val now: Instant,
    val zoneId: ZoneId,
    val dayReset: DayResetOption,
    val urgencyEnabled: Boolean,
    val defaultPrayerLeadMinutes: Int,
    /** App language tag (`en`/`ar`/`ml`); explicit app locale wins over device Locale. */
    val appLanguage: String = "en",
    val maghribForCivilDate: (LocalDate) -> Instant? = { null },
    val prayerTimesForOccurrenceDate: (LocalDate) -> PrayerTimes? = { null },
)

interface NotificationObligationPlanGateway {
    suspend fun activeGoals(): List<Goal>
    suspend fun counts(
        goalIds: List<AwradId>,
        startDate: LocalDate,
        endDate: LocalDate,
    ): NotificationPlanCounts
}

data class NotificationPlanCounts(
    val dailyByGoal: Map<AwradId, Map<LocalDate, Long>>,
    val dailySlotByGoal: Map<AwradId, Map<LocalDate, Map<AwradId, Long>>>,
    val lifetimeByGoal: Map<AwradId, Long>,
)

data class PlannedUrgencyNudge(
    val record: NotificationScheduleRecord,
    val goalId: AwradId,
    val goalName: String,
    val slotId: AwradId?,
    val slotType: GoalSlotType?,
    val progressCount: Long,
    val remainingCount: Long?,
    val currentStreak: Int = 0,
    /** Filled only at the fire boundary from the original envelope and live clock. */
    val remainingDurationMillis: Long? = null,
)

/** Production repository adapter. It makes bounded grouped reads and deliberately contains no effects. */
class RepositoryNotificationObligationPlanGateway @Inject constructor(
    private val goalRepository: GoalRepository,
) : NotificationObligationPlanGateway {
    override suspend fun activeGoals(): List<Goal> = goalRepository.getActiveGoals().first()

    override suspend fun counts(
        goalIds: List<AwradId>,
        startDate: LocalDate,
        endDate: LocalDate,
    ): NotificationPlanCounts {
        if (goalIds.isEmpty()) return NotificationPlanCounts(emptyMap(), emptyMap(), emptyMap())
        val daily = linkedMapOf<AwradId, MutableMap<LocalDate, Long>>()
        val slots = linkedMapOf<AwradId, MutableMap<LocalDate, MutableMap<AwradId, Long>>>()
        val lifetime = linkedMapOf<AwradId, Long>()
        goalIds.distinct().chunked(MAX_SQLITE_BIND_IDS).forEach { chunk ->
            goalRepository.getDailyCountsForGoalsInRange(chunk, startDate, endDate).forEach { (goalId, days) ->
                val target = daily.getOrPut(goalId) { linkedMapOf() }
                days.forEach { (date, count) -> target.mergeExact(date, count) }
            }
            goalRepository.getDailySlotCountsForGoalsInRange(chunk, startDate, endDate).forEach { (goalId, days) ->
                val targetDays = slots.getOrPut(goalId) { linkedMapOf() }
                days.forEach { (date, slotCounts) ->
                    val targetSlots = targetDays.getOrPut(date) { linkedMapOf() }
                    slotCounts.forEach { (slotId, count) -> targetSlots.mergeExact(slotId, count) }
                }
            }
            goalRepository.getTotalCountsForGoals(chunk).forEach { (goalId, count) ->
                lifetime.mergeExact(goalId, count)
            }
        }
        return NotificationPlanCounts(daily, slots, lifetime)
    }

    private fun <K> MutableMap<K, Long>.mergeExact(key: K, value: Long) {
        this[key] = this[key]?.let { Math.addExact(it, value) } ?: value
    }

    private companion object {
        const val MAX_SQLITE_BIND_IDS = 900
    }
}

class NotificationObligationPlanService @Inject constructor(
    private val gateway: NotificationObligationPlanGateway,
    private val goalNameResolver: NotificationGoalNameResolver,
) {
    private val planner = NotificationObligationPlanner()

    suspend fun plan(input: NotificationObligationPlanInput): List<NotificationScheduleRecord> =
        planDetailed(input).map(PlannedUrgencyNudge::record)

    suspend fun planDetailed(input: NotificationObligationPlanInput): List<PlannedUrgencyNudge> {
        if (!input.urgencyEnabled) return emptyList()

        val effectiveWindow = EffectiveDayWindowResolver.resolve(
            now = input.now,
            zoneId = input.zoneId,
            dayReset = input.dayReset,
            maghribForCivilDate = input.maghribForCivilDate,
        )
        val occurrenceDate = effectiveWindow.effectiveDate
        val goals = gateway.activeGoals()
            .asSequence()
            .filter { it.isActive && !it.isCompleted }
            .filter { !ObligationSemantics.isGoalExpired(it, occurrenceDate) }
            .filter { GoalProgressCalculator.isDueToday(it, occurrenceDate) }
            .sortedBy { it.id.toString() }
            .toList()
        if (goals.isEmpty()) return emptyList()

        val countStart = goals
            .map { historyStartFor(it, occurrenceDate) }
            .minOrNull() ?: occurrenceDate
        val counts = gateway.counts(goals.map { it.id }, countStart, occurrenceDate)

        return goals.flatMap { goal ->
            val resolvedSlots = goal.activeSlots.mapNotNull { slot ->
                resolveSlot(slot, effectiveWindow, input)
            }
            if (goal.activeSlots.isNotEmpty() && resolvedSlots.isEmpty()) {
                return@flatMap emptyList()
            }
            val daily = counts.dailyByGoal[goal.id].orEmpty()
            val dailySlots = counts.dailySlotByGoal[goal.id].orEmpty()
            val progress = ObligationProgress(
                occurrenceCount = daily[occurrenceDate] ?: 0L,
                periodCount = GoalProgressCalculator.currentProgressWindow(goal, occurrenceDate)?.let { window ->
                    daily.entries.sumOf { (date, count) ->
                        if (!date.isBefore(window.start) && !date.isAfter(window.endInclusive)) count else 0L
                    }
                } ?: 0L,
                lifetimeCount = counts.lifetimeByGoal[goal.id] ?: 0L,
                slotCounts = dailySlots[occurrenceDate].orEmpty(),
            )
            planner.plan(
                NotificationObligation(
                    goal = goal,
                    window = obligationWindow(goal, effectiveWindow, input),
                    isScheduled = true,
                    resolvedSlots = resolvedSlots,
                    progress = progress,
                    // Period continuity cannot be derived safely from day counts: a period may span
                    // arbitrary recurrence semantics, so do not emit a guardian until a pure
                    // completed-period streak calculator exists.
                    currentStreak = if (goal.targetPolicy == TargetPolicy.PERIOD_TOTAL) 0 else
                        occurrenceStreak(goal, occurrenceDate, daily, dailySlots),
                    urgencyEnabled = true,
                    planningNowMillis = input.now.toEpochMilli(),
                ),
            ).map { candidate -> goal to candidate }
        }.map { (goal, candidate) ->
            val slot = goal.activeSlots.firstOrNull { it.id == candidate.key.slotId }
            PlannedUrgencyNudge(
                record = NotificationScheduleRecord(
                    identity = NotificationIdentity.from(candidate.key),
                    triggerAtMillis = candidate.triggerAtMillis,
                    expiresAtMillis = candidate.expiresAtMillis,
                    kind = candidate.key.kind,
                ),
                goalId = goal.id,
                goalName = goal.dhikr?.let { goalNameResolver.resolve(it, input.appLanguage) }.orEmpty(),
                slotId = candidate.key.slotId,
                slotType = slot?.slotType,
                progressCount = candidate.progressCount,
                remainingCount = candidate.remainingCount,
                currentStreak = candidate.currentStreak,
            )
        }.sortedWith(compareBy<PlannedUrgencyNudge>({ it.record.triggerAtMillis }, { it.record.identity.canonicalKey }))
    }

    private fun historyStartFor(goal: Goal, occurrenceDate: LocalDate): LocalDate {
        val streakStart = occurrenceDate.minusDays(MAX_STREAK_HISTORY_DAYS)
        val periodStart = GoalProgressCalculator.currentProgressWindow(goal, occurrenceDate)?.start
        return listOfNotNull(streakStart, periodStart).minOrNull() ?: streakStart
    }

    private fun resolveSlot(
        slot: app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot,
        effectiveWindow: app.awrad.awrad_dhikrgoalstracker.util.EffectiveDayWindow,
        input: NotificationObligationPlanInput,
    ): ResolvedObligationSlot? {
        if (slot.slotType == GoalSlotType.ANYTIME) {
            return ResolvedObligationSlot(slot.id, slot.slotType)
        }
        val prayerDate = if (
            input.dayReset == DayResetOption.MAGHRIB &&
            slot.slotType == GoalSlotType.PRAYER &&
            slot.prayerRelation == PrayerRelation.AFTER &&
            slot.prayerName in setOf(Prayer.MAGHRIB, Prayer.ISHA)
        ) {
            effectiveWindow.effectiveDate.minusDays(1)
        } else {
            effectiveWindow.effectiveDate
        }
        val interval = SlotTimingResolver.resolveInterval(
            slot = slot,
            occurrenceDate = prayerDate,
            prayerTimes = input.prayerTimesForOccurrenceDate(prayerDate),
            defaultPrayerLeadMinutes = input.defaultPrayerLeadMinutes,
            zoneId = input.zoneId,
        ) ?: return null
        val windowStart = effectiveWindow.startInclusive.toEpochMilli()
        val windowEnd = effectiveWindow.endExclusive.toEpochMilli()
        if (interval.endMillis <= windowStart || interval.startMillis >= windowEnd) return null
        return ResolvedObligationSlot(
            slot.id,
            slot.slotType,
            ResolvedObligationInterval(interval.startMillis, interval.endMillis),
        )
    }

    private fun obligationWindow(
        goal: Goal,
        effectiveWindow: app.awrad.awrad_dhikrgoalstracker.util.EffectiveDayWindow,
        input: NotificationObligationPlanInput,
    ): ObligationWindow {
        val deadline = if (goal.targetPolicy == TargetPolicy.CUMULATIVE_TOTAL) {
            cumulativeEndDate(goal)?.let { effectiveEndMillis(it, input) }
        } else {
            effectiveWindow.endExclusive.toEpochMilli()
        }
        val start = if (goal.targetPolicy == TargetPolicy.CUMULATIVE_TOTAL) {
            effectiveStartMillis(goal.startDate, input)
        } else {
            effectiveWindow.startInclusive.toEpochMilli()
        }
        val scope = if (goal.targetPolicy == TargetPolicy.CUMULATIVE_TOTAL && deadline != null) {
            ObligationScope(
                effectiveDate = effectiveWindow.effectiveDate,
                identifier = "cumulative/v1/$start/$deadline",
            )
        } else {
            ObligationScope(effectiveWindow.effectiveDate)
        }
        return ObligationWindow(
            scope = scope,
            deadlineMillis = deadline,
            startMillis = start,
        )
    }

    private fun cumulativeEndDate(goal: Goal): LocalDate? {
        val durationEnd = goal.durationDays?.takeIf { it > 0 }?.let { goal.startDate.plusDays(it.toLong() - 1) }
        return listOfNotNull(goal.endDate, durationEnd).minOrNull()
    }

    private fun effectiveStartMillis(date: LocalDate, input: NotificationObligationPlanInput): Long =
        if (input.dayReset == DayResetOption.MAGHRIB) {
            input.maghribForCivilDate(date.minusDays(1))?.toEpochMilli()
                ?: date.atStartOfDay(input.zoneId).toInstant().toEpochMilli()
        } else {
            date.atStartOfDay(input.zoneId).toInstant().toEpochMilli()
        }

    private fun effectiveEndMillis(date: LocalDate, input: NotificationObligationPlanInput): Long =
        if (input.dayReset == DayResetOption.MAGHRIB) {
            input.maghribForCivilDate(date)?.toEpochMilli()
                ?: date.plusDays(1).atStartOfDay(input.zoneId).toInstant().toEpochMilli()
        } else {
            date.plusDays(1).atStartOfDay(input.zoneId).toInstant().toEpochMilli()
        }

    private fun occurrenceStreak(
        goal: Goal,
        occurrenceDate: LocalDate,
        daily: Map<LocalDate, Long>,
        dailySlots: Map<LocalDate, Map<AwradId, Long>>,
    ): Int {
        var streak = 0
        var date = if (daily.containsKey(occurrenceDate) || dailySlots.containsKey(occurrenceDate)) {
            occurrenceDate
        } else {
            occurrenceDate.minusDays(1)
        }
        repeat(MAX_STREAK_HISTORY_DAYS.toInt() + 1) {
            if (GoalProgressCalculator.isDueToday(goal, date)) {
                val progress = ObligationProgress(
                    occurrenceCount = daily[date] ?: 0L,
                    slotCounts = dailySlots[date].orEmpty(),
                )
                val satisfied = if (goal.activeSlots.isNotEmpty()) {
                    ObligationSemantics.isOccurrenceContinuous(goal, progress.slotCounts)
                } else {
                    ObligationSemantics.isObligationSatisfied(
                        goal,
                        date,
                        progress,
                        ObligationThreshold.STREAK,
                    )
                }
                if (!satisfied) {
                    // A partial or empty active occurrence must not erase a completed prior
                    // scheduled-occurrence streak before the guardian gets a chance to protect it.
                    if (date == occurrenceDate) {
                        date = date.minusDays(1)
                        return@repeat
                    }
                    return streak
                }
                streak++
            }
            date = date.minusDays(1)
        }
        return streak
    }

    private companion object {
        const val MAX_STREAK_HISTORY_DAYS = 366L
    }
}
