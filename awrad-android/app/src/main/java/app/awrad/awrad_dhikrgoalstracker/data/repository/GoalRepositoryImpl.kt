package app.awrad.awrad_dhikrgoalstracker.data.repository

import androidx.room.withTransaction
import app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.CountEntryDao
import java.time.LocalDate
import java.time.DayOfWeek
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.DhikrDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalRecurrenceDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalReminderDao
import app.awrad.awrad_dhikrgoalstracker.data.database.dao.GoalSlotDao
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.CountEntryEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceDateEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceMonthDayEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalRecurrenceWeekdayEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalReminderEntity
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.GoalSlotEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.CountEntry
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.Dhikr
import app.awrad.awrad_dhikrgoalstracker.data.model.Goal
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalRecurrence
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlot
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSpecificDate
import app.awrad.awrad_dhikrgoalstracker.data.model.QuranRef
import app.awrad.awrad_dhikrgoalstracker.data.model.TargetPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ValidatedGoal
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ValidatedGoalUpdate
import app.awrad.awrad_dhikrgoalstracker.util.CountCapCalculator
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import app.awrad.awrad_dhikrgoalstracker.util.GoalProgressCalculator
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateFromEpochMillis
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOr
import app.awrad.awrad_dhikrgoalstracker.util.toLocalDateOrNull
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class GoalRepositoryImpl @Inject constructor(
    private val database: AwradDatabase,
    private val goalDao: GoalDao,
    private val goalRecurrenceDao: GoalRecurrenceDao,
    private val goalSlotDao: GoalSlotDao,
    private val goalReminderDao: GoalReminderDao,
    private val countEntryDao: CountEntryDao,
    private val dhikrDao: DhikrDao,
    private val dateProvider: DateProvider,
) : GoalRepository {

    override fun getActiveGoals(): Flow<List<Goal>> =
        goalDao.getActiveGoals().map { entities -> entities.withSlots() }

    override fun getCompletedGoals(): Flow<List<Goal>> =
        goalDao.getCompletedGoals().map { entities -> entities.withSlots() }

    override fun getAllGoals(): Flow<List<Goal>> =
        goalDao.getAllGoals().map { entities -> entities.withSlots() }

    override fun getGoalByIdFlow(id: AwradId): Flow<Goal?> =
        goalDao.getGoalByIdFlow(id).map { entity ->
            entity ?: return@map null
            entity.toDomainWithChildren()
        }

    override suspend fun getGoalById(id: AwradId): Goal? {
        val entity = goalDao.getGoalById(id) ?: return null
        val dhikrEntity = dhikrDao.getDhikrById(entity.dhikrId)
        val dhikr = dhikrEntity?.toGoalDhikr()
        return entity.toDomainWithChildren(dhikr = dhikr)
    }

    override suspend fun createGoal(validatedGoal: ValidatedGoal): AwradId = database.withTransaction {
        val goal = validatedGoal.goal
        goal.requirePersistable()
        val goalId = goal.id
        goalDao.insert(goal.toEntity())
        replaceRecurrence(goalId, goal.recurrence)
        val slotEntities = goal.slots.map { it.toEntity(goalId) }
        if (slotEntities.isNotEmpty()) goalSlotDao.insertAll(slotEntities)
        val reminderEntities = goal.reminders.map { reminder ->
            reminder.toEntity(
                goalId = goalId,
                slotId = GoalPersistenceMapper.normalizedReminderSlotId(
                    reminder = reminder,
                    slots = goal.slots,
                ),
            )
        }
        if (reminderEntities.isNotEmpty()) {
            goalReminderDao.insertAll(reminderEntities)
        }
        goalId
    }

    override suspend fun updateGoal(goal: Goal) = database.withTransaction {
        updateGoalAggregate(goal)
    }

    override suspend fun updateGoal(validatedGoalUpdate: ValidatedGoalUpdate): Goal = database.withTransaction {
        val goal = validatedGoalUpdate.goal
        updateGoalAggregate(goal)
        recomputeCompletionAfterCountSetupUpdate(goal.id)
        getGoalById(goal.id) ?: goal
    }

    override suspend fun updateGoalSchedule(validatedGoalUpdate: ValidatedGoalUpdate): Goal = database.withTransaction {
        val goal = validatedGoalUpdate.goal
        updateGoalAggregate(goal)
        getGoalById(goal.id) ?: goal
    }

    override suspend fun updateGoalReminders(validatedGoalUpdate: ValidatedGoalUpdate): Goal = database.withTransaction {
        val goal = validatedGoalUpdate.goal
        updateGoalAggregate(goal)
        getGoalById(goal.id) ?: goal
    }

    private suspend fun updateGoalAggregate(goal: Goal) {
        goal.requirePersistable()
        goalDao.update(goal.toEntity())
        replaceRecurrence(goal.id, goal.recurrence)

        val existingSlotIds = goalSlotDao.getSlotsForGoal(goal.id).mapTo(mutableSetOf()) { it.id }
        val retainedSlotIds = goal.slots.map { slot ->
            if (slot.id in existingSlotIds) {
                goalSlotDao.update(slot.toEntity(goal.id))
            } else {
                goalSlotDao.insert(slot.toEntity(goal.id))
            }
            slot.id
        }

        val existingReminderIds = goalReminderDao.getRemindersForGoal(goal.id).mapTo(mutableSetOf()) { it.id }
        val retainedReminderIds = goal.reminders.map { reminder ->
            val entity = reminder.toEntity(
                goalId = goal.id,
                slotId = GoalPersistenceMapper.normalizedReminderSlotId(
                    reminder = reminder,
                    slots = goal.slots,
                ),
            )
            if (entity.id in existingReminderIds) {
                goalReminderDao.update(entity)
            } else {
                goalReminderDao.insert(entity)
            }
            entity.id
        }
        if (retainedReminderIds.isEmpty()) {
            goalReminderDao.deleteForGoal(goal.id)
        } else {
            goalReminderDao.deleteForGoalExcept(goal.id, retainedReminderIds)
        }

        if (retainedSlotIds.isEmpty()) {
            goalSlotDao.deleteForGoal(goal.id)
        } else {
            goalSlotDao.deleteForGoalExcept(goal.id, retainedSlotIds)
        }
    }

    private suspend fun recomputeCompletionAfterCountSetupUpdate(goalId: AwradId) {
        val updatedGoal = getGoalById(goalId) ?: return
        val now = System.currentTimeMillis()
        if (updatedGoal.targetPolicy != TargetPolicy.CUMULATIVE_TOTAL) {
            if (updatedGoal.completedAt != null) {
                goalDao.reopenGoal(goalId, now)
            }
            return
        }

        val target = GoalProgressCalculator.getTargetCount(updatedGoal)
        val targetReached = target > 0 && updatedGoal.totalCompletedCount >= target
        when {
            updatedGoal.autoCompleteOnTarget && targetReached && updatedGoal.completedAt == null ->
                goalDao.markCompleted(goalId, now)
            (!updatedGoal.autoCompleteOnTarget || !targetReached) && updatedGoal.completedAt != null ->
                goalDao.reopenGoal(goalId, now)
        }
    }

    override suspend fun deleteGoal(id: AwradId) {
        goalDao.deleteById(id)
    }

    override suspend fun addCount(goalId: AwradId, slotId: AwradId?, count: Long): Long = database.withTransaction {
        val today = dateProvider.getEffectiveToday()
        // Counting hot path: load only the goal fields + slots + recurrence the cap/completion
        // logic reads (no dhikr, no reminders), and load them exactly once per tap.
        val goal = loadGoalForCounting(goalId) ?: return@withTransaction 0L
        val normalizedSlotId = goal.normalizedCountSlotId(slotId)
        val before = countEntryDao.getCountValueForSlot(goalId, normalizedSlotId, today) ?: 0L
        val appliedDelta = if (count > 0L) {
            val slot = goal.slots.firstOrNull { it.id == normalizedSlotId }
            val currentForCap = currentCountForCap(goal, normalizedSlotId, before, today)
            val targetForCap = slot?.targetCount ?: GoalProgressCalculator.getTargetCount(goal).takeIf { it > 0 }
            val maximumForCap = slot?.maximumCount ?: goal.maximumCount
            val capBehavior = slot?.capBehavior ?: goal.capBehavior
            CountCapCalculator.applyDelta(
                currentCount = currentForCap,
                requestedDelta = count,
                targetCount = targetForCap,
                maximumCount = maximumForCap,
                capBehavior = capBehavior,
            ).appliedDelta
        } else {
            (before + count).coerceAtLeast(0) - before
        }
        if (appliedDelta == 0L) return@withTransaction 0L
        val now = System.currentTimeMillis()
        countEntryDao.upsertCount(goalId, normalizedSlotId, today, appliedDelta, now)
        goalDao.incrementTotalCount(goalId, appliedDelta, now)
        // Auto-completion only reads totalCompletedCount (just changed) + already-loaded fields,
        // so recompute from `goal` instead of a second full re-fetch. The clamp mirrors the
        // `incrementTotalCount` CASE so the in-memory value matches the persisted row exactly.
        if (goal.autoCompleteOnTarget) {
            val recomputedGoal = goal.copy(
                totalCompletedCount = (goal.totalCompletedCount + appliedDelta).coerceAtLeast(0),
            )
            val isComplete = GoalProgressCalculator.isGoalComplete(recomputedGoal)
            when {
                isComplete && goal.completedAt == null -> goalDao.markCompleted(goalId, now)
                !isComplete && goal.completedAt != null -> goalDao.reopenGoal(goalId, now)
            }
        }
        appliedDelta
    }

    override fun getTotalCountForDate(goalId: AwradId, date: String): Flow<Long?> =
        countEntryDao.getTotalCountForDate(goalId, date)

    override fun getTotalCount(goalId: AwradId): Flow<Long?> =
        countEntryDao.getTotalCount(goalId)

    override suspend fun getCountForSlotAndDate(goalId: AwradId, slotId: AwradId, date: String): Long =
        countEntryDao.getCountForSlotAndDate(goalId, slotId, date).first() ?: 0L

    override fun getProgressMapForDate(date: String): Flow<Map<AwradId, Long>> =
        countEntryDao.getProgressMapForDate(date).map { list ->
            list.associate { it.goalId to it.total }
        }

    override fun getHistoryForGoal(goalId: AwradId): Flow<List<CountEntry>> =
        countEntryDao.getHistoryForGoal(goalId).map { entities -> entities.map { it.toDomain() } }

    override fun getDailyCountsByGoal(): Flow<Map<AwradId, Map<LocalDate, Long>>> =
        countEntryDao.getDailyCountsByGoal().map { rows ->
            rows.groupBy { it.goalId }.mapValues { (_, goalRows) ->
                goalRows.mapNotNull { row ->
                    row.date.toLocalDateOrNull()?.let { it to row.total }
                }.toMap()
            }
        }

    override fun getDailySlotCountsByGoal(): Flow<Map<AwradId, Map<LocalDate, Map<AwradId, Long>>>> =
        countEntryDao.getDailySlotCountsByGoal().map { rows ->
            rows.groupBy { it.goalId }.mapValues { (_, goalRows) ->
                goalRows.groupBy { it.date }.mapNotNull { (dateString, dateRows) ->
                    dateString.toLocalDateOrNull()?.let { date ->
                        date to dateRows.associate { it.slotId to it.total }
                    }
                }.toMap()
            }
        }

    override fun getDailySlotCountsForGoal(goalId: AwradId): Flow<Map<LocalDate, Map<AwradId, Long>>> =
        countEntryDao.getDailySlotCountsForGoal(goalId).map { rows ->
            rows.groupBy { it.date }.mapNotNull { (dateString, dateRows) ->
                dateString.toLocalDateOrNull()?.let { date ->
                    date to dateRows.associate { it.slotId to it.total }
                }
            }.toMap()
        }

    override suspend fun getSlotCountsForGoalAndDate(goalId: AwradId, date: String): Map<AwradId, Long> =
        countEntryDao.getSlotCountsForGoalAndDate(goalId, date).associate { it.slotId to it.total }

    override suspend fun getTotalCountBetween(goalId: AwradId, startDate: String, endDate: String): Long =
        countEntryDao.getTotalCountBetween(goalId, startDate, endDate) ?: 0L

    override suspend fun getActiveGoalsWithNotifications(): List<Goal> =
        goalDao.getActiveGoalsWithNotifications().withChildren()

    override suspend fun deleteAllProgress() {
        countEntryDao.deleteAll()
        goalDao.resetAllGoalProgress(System.currentTimeMillis())
    }

    override suspend fun deleteAllGoalsAndProgress() {
        countEntryDao.deleteAll()
        goalDao.deleteAllGoals()
    }

    override fun getActiveGoalsByDhikrId(dhikrId: AwradId): Flow<List<Goal>> =
        goalDao.getActiveGoalsByDhikrId(dhikrId).map { entities -> entities.withSlots() }

    override fun getDailyCountsForGoal(goalId: AwradId): Flow<Map<LocalDate, Long>> =
        countEntryDao.getDailyCountsForGoal(goalId).map { list ->
            list.mapNotNull { dateCount ->
                dateCount.date.toLocalDateOrNull()?.let { date -> date to dateCount.total }
            }.toMap()
        }

    /** Fetches slots for all entities in a single batch query and joins them in memory. */
    private suspend fun List<GoalEntity>.withSlots(): List<Goal> = withChildren()

    private suspend fun List<GoalEntity>.withChildren(): List<Goal> {
        if (isEmpty()) return emptyList()
        val goalIds = map { it.id }
        val slotsByGoal = goalSlotDao.getSlotsForGoals(goalIds)
            .groupBy { it.goalId }
        val remindersByGoal = goalReminderDao.getRemindersForGoals(goalIds)
            .groupBy { it.goalId }
        val recurrencesByGoal = goalRecurrenceDao.getForGoals(goalIds)
            .associateBy { it.goalId }
        val weekdaysByGoal = goalRecurrenceDao.getWeekdaysForGoals(goalIds)
            .groupBy { it.goalId }
        val monthDaysByGoal = goalRecurrenceDao.getMonthDaysForGoals(goalIds)
            .groupBy { it.goalId }
        val datesByGoal = goalRecurrenceDao.getDatesForGoals(goalIds)
            .groupBy { it.goalId }
        return map { entity ->
            val allSlots = (slotsByGoal[entity.id] ?: emptyList()).map { it.toDomain() }
            val recurrence = recurrencesByGoal[entity.id].toDomain(
                weekdays = weekdaysByGoal[entity.id] ?: emptyList(),
                monthDays = monthDaysByGoal[entity.id] ?: emptyList(),
                dates = datesByGoal[entity.id] ?: emptyList(),
            )
            val reminders = (remindersByGoal[entity.id] ?: emptyList()).map { it.toDomain() }
            entity.toDomain(
                recurrence = recurrence,
                slots = allSlots,
                reminders = reminders,
            )
        }
    }

    private suspend fun GoalEntity.toDomainWithChildren(dhikr: Dhikr? = null): Goal {
        val recurrence = goalRecurrenceDao.getForGoal(id).toDomain(
            weekdays = goalRecurrenceDao.getWeekdaysForGoal(id),
            monthDays = goalRecurrenceDao.getMonthDaysForGoal(id),
            dates = goalRecurrenceDao.getDatesForGoal(id),
        )
        val allSlots = goalSlotDao.getSlotsForGoal(id).map { it.toDomain() }
        val reminders = goalReminderDao.getRemindersForGoal(id).map { it.toDomain() }
        return toDomain(
            dhikr = dhikr,
            recurrence = recurrence,
            slots = allSlots,
            reminders = reminders,
        )
    }

    /**
     * Loads only what [addCount] needs: goal core fields, active/archived slots, and recurrence
     * (for cap windows). Skips the dhikr lookup and reminder query that [getGoalById] performs,
     * keeping the per-tap hot path to a single lightweight fetch.
     */
    private suspend fun loadGoalForCounting(goalId: AwradId): Goal? {
        val entity = goalDao.getGoalById(goalId) ?: return null
        val recurrence = goalRecurrenceDao.getForGoal(entity.id).toDomain(
            weekdays = goalRecurrenceDao.getWeekdaysForGoal(entity.id),
            monthDays = goalRecurrenceDao.getMonthDaysForGoal(entity.id),
            dates = goalRecurrenceDao.getDatesForGoal(entity.id),
        )
        val allSlots = goalSlotDao.getSlotsForGoal(entity.id).map { it.toDomain() }
        return entity.toDomain(
            recurrence = recurrence,
            slots = allSlots,
        )
    }

    private fun GoalEntity.toDomain(
        dhikr: Dhikr? = null,
        recurrence: GoalRecurrence = GoalRecurrence(goalId = id),
        slots: List<GoalSlot> = emptyList(),
        reminders: List<GoalReminder> = emptyList(),
    ): Goal {
        val sanitizedSlots = slots.map { it.withReadableCapBehavior() }
        return Goal(
            id = id,
            dhikrId = dhikrId,
            dhikr = dhikr,
            targetPolicy = targetPolicy,
            slotCountingPolicy = slotCountingPolicy,
            recurrence = recurrence,
            slots = sanitizedSlots,
            reminders = reminders,
            startDate = startDate.toLocalDateOr(createdAt.toLocalDateFromEpochMillis()),
            endDate = endDate.toLocalDateOrNull(),
            durationDays = durationDays,
            minimumStreakCount = minimumStreakCount,
            targetCount = targetCount,
            maximumCount = maximumCount,
            capBehavior = capBehavior.sanitizedFor(
                targetCount = sanitizedSlots.sumOf { it.targetCount ?: 0 }.takeIf { it > 0 },
                maximumCount = maximumCount,
            ),
            streakThreshold = streakThreshold,
            reminderThreshold = reminderThreshold,
            completionThreshold = completionThreshold,
            autoCompleteOnTarget = autoCompleteOnTarget,
            completionPolicy = completionPolicy,
            totalCompletedCount = totalCompletedCount,
            isActive = isActive,
            completedAt = completedAt,
            createdAt = createdAt,
            updatedAt = updatedAt,
        )
    }

    private fun Goal.toEntity() = GoalEntity(
        id = id,
        dhikrId = dhikrId,
        targetPolicy = targetPolicy,
        slotCountingPolicy = slotCountingPolicy,
        startDate = startDate.toString(),
        endDate = endDate?.toString(),
        durationDays = durationDays,
        minimumStreakCount = minimumStreakCount,
        targetCount = targetCount,
        maximumCount = maximumCount,
        capBehavior = capBehavior,
        streakThreshold = streakThreshold,
        reminderThreshold = reminderThreshold,
        completionThreshold = completionThreshold,
        autoCompleteOnTarget = autoCompleteOnTarget,
        completionPolicy = completionPolicy,
        totalCompletedCount = totalCompletedCount,
        isActive = isActive,
        completedAt = completedAt,
        createdAt = createdAt,
        updatedAt = System.currentTimeMillis(),
    )

    private suspend fun currentCountForCap(goal: Goal, slotId: AwradId?, currentEntryCount: Long, today: String): Long {
        val slot = slotId?.let { id -> goal.slots.firstOrNull { it.id == id } }
        if (slot != null && goal.slots.size > 1) return currentEntryCount
        if (slot != null && slot.slotType != GoalSlotType.ANYTIME) return currentEntryCount
        return when (goal.targetPolicy) {
            TargetPolicy.CUMULATIVE_TOTAL -> goal.totalCompletedCount
            TargetPolicy.PERIOD_TOTAL -> GoalProgressCalculator.currentProgressWindow(
                goal = goal,
                today = today.toLocalDateOr(goal.startDate),
            )?.let { window ->
                countEntryDao.getTotalCountBetween(goal.id, window.start.toString(), window.endInclusive.toString()) ?: 0L
            } ?: currentEntryCount
            TargetPolicy.PER_DUE_DATE,
            TargetPolicy.NONE -> currentEntryCount
        }
    }

    private suspend fun replaceRecurrence(goalId: AwradId, recurrence: GoalRecurrence) {
        goalRecurrenceDao.deleteWeekdaysForGoal(goalId)
        goalRecurrenceDao.deleteMonthDaysForGoal(goalId)
        goalRecurrenceDao.deleteDatesForGoal(goalId)
        goalRecurrenceDao.insert(recurrence.copy(goalId = goalId).toEntity())
        recurrence.weekdays.map {
            GoalRecurrenceWeekdayEntity(goalId = goalId, dayOfWeek = it.value)
        }.takeIf { it.isNotEmpty() }?.let { goalRecurrenceDao.insertWeekdays(it) }
        recurrence.monthDays.map {
            GoalRecurrenceMonthDayEntity(goalId = goalId, dayOfMonth = it)
        }.takeIf { it.isNotEmpty() }?.let { goalRecurrenceDao.insertMonthDays(it) }
        recurrence.specificDates.map {
            GoalRecurrenceDateEntity(
                goalId = goalId,
                date = it.date?.toString(),
                calendar = it.calendar,
                month = it.month,
                dayOfMonth = it.dayOfMonth,
            )
        }.takeIf { it.isNotEmpty() }?.let { goalRecurrenceDao.insertDates(it) }
    }

    private fun GoalSlot.toEntity(goalId: AwradId) = GoalPersistenceMapper.toEntity(this, goalId)

    private fun GoalReminder.toEntity(goalId: AwradId, slotId: AwradId?) =
        GoalPersistenceMapper.toEntity(this, goalId, slotId)

    private fun GoalSlotEntity.toDomain() = GoalSlot(
        id = id,
        goalId = goalId,
        slotType = slotType,
        minimumCount = minimumCount,
        targetCount = targetCount,
        maximumCount = maximumCount,
        capBehavior = capBehavior,
        streakThreshold = streakThreshold,
        reminderThreshold = reminderThreshold,
        completionThreshold = completionThreshold,
        prayerName = prayerName,
        prayerRelation = prayerRelation,
        startMinute = startMinute,
        endMinute = endMinute,
        startLeadMinutesOverride = startLeadMinutesOverride,
        label = label,
        sortOrder = sortOrder,
        isActive = isActive,
        archivedAt = archivedAt,
    )

    private fun GoalRecurrenceEntity?.toDomain(
        weekdays: List<GoalRecurrenceWeekdayEntity>,
        monthDays: List<GoalRecurrenceMonthDayEntity>,
        dates: List<GoalRecurrenceDateEntity>,
    ): GoalRecurrence {
        val entity = requireNotNull(this) { "Every persisted goal must have recurrence state" }
        return GoalRecurrence(
            goalId = entity.goalId,
            frequency = entity.frequency,
            calendar = entity.calendar,
            intervalDays = entity.intervalDays,
            anchorDate = entity.anchorDate.toLocalDateOrNull(),
            month = entity.month,
            seasonTemplateCode = entity.seasonTemplateCode,
            weekdays = weekdays.map { DayOfWeek.of(it.dayOfWeek) }.toSet(),
            monthDays = monthDays.map { it.dayOfMonth }.toSet(),
            specificDates = dates.map {
                GoalSpecificDate(
                    date = it.date.toLocalDateOrNull(),
                    calendar = it.calendar,
                    month = it.month,
                    dayOfMonth = it.dayOfMonth,
                )
            }.toSet(),
        )
    }

    private fun GoalRecurrence.toEntity() = GoalRecurrenceEntity(
        goalId = goalId,
        frequency = frequency,
        calendar = calendar,
        intervalDays = intervalDays,
        anchorDate = anchorDate?.toString(),
        month = month,
        seasonTemplateCode = seasonTemplateCode,
    )

    private fun GoalReminderEntity.toDomain() = GoalReminder(
        id = id,
        goalId = goalId,
        slotId = slotId,
        reminderType = reminderType,
        hour = hour,
        minute = minute,
        offsetMinutes = offsetMinutes,
        enabled = enabled,
        sortOrder = sortOrder,
    )

    private fun CountEntryEntity.toDomain() = CountEntry(
        id = id,
        goalId = goalId,
        slotId = slotId,
        count = count,
        date = date,
        lastUpdated = lastUpdated,
    )

    private fun Goal.normalizedCountSlotId(requestedSlotId: AwradId?): AwradId {
        if (requestedSlotId != null) {
            require(activeSlots.any { it.id == requestedSlotId }) {
                "Count slot $requestedSlotId is not active for goal $id"
            }
            return requestedSlotId
        }

        val countableSlots = activeSlots
        val singleAnytimeSlot = countableSlots.singleOrNull()?.takeIf { it.slotType == GoalSlotType.ANYTIME }
        if (singleAnytimeSlot != null) return singleAnytimeSlot.id

        error("Goal $id requires an explicit slot for count writes")
    }

    private fun Goal.requirePersistable() {
        val target = GoalProgressCalculator.getTargetCount(this).takeIf { it > 0 }
        requireCountRule(
            minimumCount = minimumStreakCount,
            targetCount = target,
            maximumCount = maximumCount,
            capBehavior = capBehavior,
            owner = "goal",
        )
        slots.forEach { slot ->
            requireCountRule(
                minimumCount = slot.minimumCount,
                targetCount = slot.targetCount,
                maximumCount = slot.maximumCount,
                capBehavior = slot.capBehavior,
                owner = "slot ${slot.id}",
            )
        }
    }

    private fun requireCountRule(
        minimumCount: Int?,
        targetCount: Int?,
        maximumCount: Int?,
        capBehavior: CountCapBehavior,
        owner: String,
    ) {
        require(listOfNotNull(minimumCount, targetCount, maximumCount).all { it > 0 }) {
            "Invalid non-positive count rule for $owner"
        }
        require(minimumCount == null || targetCount == null || minimumCount <= targetCount) {
            "Invalid count rule for $owner: minimum must be <= target"
        }
        require(targetCount == null || maximumCount == null || targetCount <= maximumCount) {
            "Invalid count rule for $owner: target must be <= maximum"
        }
        require(minimumCount == null || maximumCount == null || minimumCount <= maximumCount) {
            "Invalid count rule for $owner: minimum must be <= maximum"
        }
        require(capBehavior != CountCapBehavior.BlockAtTarget || targetCount != null) {
            "Invalid count rule for $owner: BlockAtTarget requires a target"
        }
        require(capBehavior != CountCapBehavior.BlockAtMaximum || maximumCount != null) {
            "Invalid count rule for $owner: BlockAtMaximum requires a maximum"
        }
    }

    private fun GoalSlot.withReadableCapBehavior(): GoalSlot =
        copy(capBehavior = capBehavior.sanitizedFor(targetCount = targetCount, maximumCount = maximumCount))

    private fun CountCapBehavior.sanitizedFor(targetCount: Int?, maximumCount: Int?): CountCapBehavior =
        when (this) {
            CountCapBehavior.BlockAtTarget -> if (targetCount == null) CountCapBehavior.AllowOverTarget else this
            CountCapBehavior.BlockAtMaximum -> if (maximumCount == null) CountCapBehavior.AllowOverTarget else this
            CountCapBehavior.AllowOverTarget,
            CountCapBehavior.WarnOverTarget -> this
        }
}

internal fun DhikrEntity.toGoalDhikr(): Dhikr = Dhikr(
    id = id,
    catalogKey = catalogKey,
    title = title,
    arabic = arabic,
    transliteration = transliteration,
    translation = translation,
    audioUrl = audioUrl,
    audioFileName = audioFileName,
    category = category,
    isDownloaded = isDownloaded,
    isCustom = isCustom,
    audioCountPerPlay = audioCountPerPlay,
    quranRef = if (quranSurah != null && quranAyahStart != null) {
        QuranRef(quranSurah, quranAyahStart, quranAyahEnd).takeIf { it.isValid }
    } else {
        null
    },
    benefits = runCatching { Json.decodeFromString<List<String>>(benefitsJson) }.getOrDefault(emptyList()),
)

internal object GoalPersistenceMapper {
    fun toEntity(slot: GoalSlot, goalId: AwradId) = GoalSlotEntity(
        id = slot.id,
        goalId = goalId,
        slotType = slot.slotType,
        minimumCount = slot.minimumCount,
        targetCount = slot.targetCount,
        maximumCount = slot.maximumCount,
        capBehavior = slot.capBehavior,
        streakThreshold = slot.streakThreshold,
        reminderThreshold = slot.reminderThreshold,
        completionThreshold = slot.completionThreshold,
        prayerName = slot.prayerName,
        prayerRelation = slot.prayerRelation,
        startMinute = slot.startMinute,
        endMinute = slot.endMinute,
        startLeadMinutesOverride = slot.startLeadMinutesOverride,
        label = slot.label,
        sortOrder = slot.sortOrder,
        isActive = slot.isActive,
        archivedAt = slot.archivedAt,
    )

    fun toEntity(reminder: GoalReminder, goalId: AwradId, slotId: AwradId?) = GoalReminderEntity(
        id = reminder.id,
        goalId = goalId,
        slotId = slotId,
        reminderType = reminder.reminderType,
        hour = reminder.hour,
        minute = reminder.minute,
        offsetMinutes = reminder.offsetMinutes,
        enabled = reminder.enabled,
        sortOrder = reminder.sortOrder,
    )

    fun normalizedReminderSlotId(
        reminder: GoalReminder,
        slots: List<GoalSlot>,
    ): AwradId? {
        val slotId = reminder.slotId ?: return null
        return slotId.takeIf { id -> slots.any { it.id == id } }
    }
}
