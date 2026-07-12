package app.awrad.awrad_dhikrgoalstracker.data.repository

import android.content.Context
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.room.Room
import androidx.test.platform.app.InstrumentationRegistry
import app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalReminder
import app.awrad.awrad_dhikrgoalstracker.data.model.GoalSlotType
import app.awrad.awrad_dhikrgoalstracker.data.model.CountCapBehavior
import app.awrad.awrad_dhikrgoalstracker.data.model.Prayer
import app.awrad.awrad_dhikrgoalstracker.data.model.PrayerRelation
import app.awrad.awrad_dhikrgoalstracker.data.model.RecurrenceFrequency
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalCountPolicyUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalCountRuleMode
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalCountSetupUpdateFactory
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalScheduleUpdateFactory
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalSlotCountPolicyUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalUpdateWarning
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.PrayerSlotUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ScheduleTimingUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.TimeWindowSlotUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalCountSetupCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalCountSetupResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalScheduleCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalScheduleResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CapBehavior
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CompletionPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CountPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CreateGoalCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalFactory
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ProgressScope
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ScheduleSpec
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.Threshold
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.TimeWindowSpec
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.TimingSpec
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.GoalProgressUseCase
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.UpdateGoalCountSetupUseCase
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.UpdateGoalScheduleUseCase
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import java.io.File
import java.time.DayOfWeek
import java.time.LocalDate
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

class GoalRepositoryImplCountCapTest {

    private lateinit var context: Context
    private lateinit var database: AwradDatabase
    private lateinit var repository: GoalRepositoryImpl
    private lateinit var dateProvider: DateProvider
    private lateinit var updateGoalCountSetupUseCase: UpdateGoalCountSetupUseCase
    private lateinit var updateGoalScheduleUseCase: UpdateGoalScheduleUseCase
    private var dhikrId: Long = 0

    @Before
    fun setUp() = runTest {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        database = Room.inMemoryDatabaseBuilder(context, AwradDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        val dataStoreFile = File(context.cacheDir, "goal-repository-${System.nanoTime()}.preferences_pb")
        val userPreferences = UserPreferences(
            PreferenceDataStoreFactory.create { dataStoreFile },
        )
        dateProvider = DateProvider(userPreferences, PrayerTimeRepository(context))
        repository = GoalRepositoryImpl(
            database = database,
            goalDao = database.goalDao(),
            goalRecurrenceDao = database.goalRecurrenceDao(),
            goalSlotDao = database.goalSlotDao(),
            goalReminderDao = database.goalReminderDao(),
            countEntryDao = database.countEntryDao(),
            dhikrDao = database.dhikrDao(),
            dateProvider = dateProvider,
        )
        updateGoalCountSetupUseCase = UpdateGoalCountSetupUseCase(
            goalRepository = repository,
            dateProvider = dateProvider,
            goalProgressUseCase = GoalProgressUseCase(),
        )
        updateGoalScheduleUseCase = UpdateGoalScheduleUseCase(goalRepository = repository)
        dhikrId = database.dhikrDao().insert(
            DhikrEntity(
                title = "SubhanAllah",
                arabic = "Subhan Allah",
                transliteration = "SubhanAllah",
                translation = "Glory be to Allah",
                audioUrl = null,
                audioFileName = null,
                category = DhikrCategory.PRAISE,
            )
        )
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun exactGoalCannotExceedMaximumAndNullSlotNormalizesToAnytimeSlot() = runTest {
        val goalId = createGoal(
            countPolicy = CountPolicy(
                targetCount = 3,
                maximumCount = 3,
                capBehavior = CapBehavior.BlockAtMaximum,
            ),
        )
        val goal = repository.getGoalById(goalId) ?: error("Missing goal")
        val slotId = goal.slots.single().id

        assertEquals(3L, repository.addCount(goalId, slotId = null, count = 5))
        assertEquals(0L, repository.addCount(goalId, slotId = null, count = 1))

        assertEquals(3L, repository.getTotalCount(goalId).first())
        val history = repository.getHistoryForGoal(goalId).first()
        assertEquals(1, history.size)
        assertEquals(slotId, history.single().slotId)
    }

    @Test
    fun boundedGoalCanPassTargetButNotMaximum() = runTest {
        val goalId = createGoal(
            countPolicy = CountPolicy(
                minimumCount = 2,
                targetCount = 3,
                maximumCount = 5,
                streakThreshold = Threshold.Minimum,
                capBehavior = CapBehavior.BlockAtMaximum,
            ),
        )

        assertEquals(4L, repository.addCount(goalId, slotId = null, count = 4))
        assertEquals(1L, repository.addCount(goalId, slotId = null, count = 4))
        assertEquals(5L, repository.getTotalCount(goalId).first())
    }

    @Test
    fun allowAndWarnOverTargetGoalsCanPersistCountsAboveTarget() = runTest {
        val allowGoalId = createGoal(
            countPolicy = CountPolicy(
                targetCount = 3,
                capBehavior = CapBehavior.AllowOverTarget,
            ),
        )
        val warnGoalId = createGoal(
            countPolicy = CountPolicy(
                targetCount = 3,
                capBehavior = CapBehavior.WarnOverTarget,
            ),
        )

        assertEquals(5L, repository.addCount(allowGoalId, slotId = null, count = 5))
        assertEquals(5L, repository.addCount(warnGoalId, slotId = null, count = 5))
        assertEquals(5L, repository.getTotalCount(allowGoalId).first())
        assertEquals(5L, repository.getTotalCount(warnGoalId).first())
    }

    @Test
    fun perSlotCapsUseSlotSpecificRules() = runTest {
        val goalId = createGoal(
            countPolicy = CountPolicy(targetCount = 2),
            timing = TimingSpec.TimeWindows(
                listOf(
                    TimeWindowSpec(
                        label = "Morning",
                        startMinute = 9 * 60,
                        endMinute = 10 * 60,
                        countPolicy = CountPolicy(
                            targetCount = 2,
                            maximumCount = 3,
                            capBehavior = CapBehavior.BlockAtMaximum,
                        ),
                    ),
                    TimeWindowSpec(
                        label = "Evening",
                        startMinute = 18 * 60,
                        endMinute = 19 * 60,
                        countPolicy = CountPolicy(
                            targetCount = 2,
                            maximumCount = 5,
                            capBehavior = CapBehavior.BlockAtMaximum,
                        ),
                    ),
                )
            ),
        )
        val goal = repository.getGoalById(goalId) ?: error("Missing goal")
        val morning = goal.slots.first { it.label == "Morning" }
        val evening = goal.slots.first { it.label == "Evening" }

        assertEquals(3L, repository.addCount(goalId, morning.id, 5))
        assertEquals(5L, repository.addCount(goalId, evening.id, 5))

        val today = LocalDate.now().toString()
        assertEquals(3L, repository.getCountForSlotAndDate(goalId, morning.id, today))
        assertEquals(5L, repository.getCountForSlotAndDate(goalId, evening.id, today))
    }

    @Test
    fun addCountRejectsSlotFromDifferentGoal() = runTest {
        val firstGoalId = createGoal(countPolicy = CountPolicy(targetCount = 3))
        val secondGoalId = createGoal(countPolicy = CountPolicy(targetCount = 3))
        val foreignSlotId = repository.getGoalById(secondGoalId)?.slots?.single()?.id
            ?: error("Missing second goal slot")

        try {
            repository.addCount(firstGoalId, foreignSlotId, 1)
            fail("Expected foreign slot write to fail")
        } catch (_: IllegalArgumentException) {
            assertEquals(0L, repository.getTotalCount(firstGoalId).first() ?: 0L)
        }
    }

    @Test
    fun decrementAfterAutoCompletionReopensCumulativeGoal() = runTest {
        val goalId = createGoal(
            countPolicy = CountPolicy(targetCount = 3),
            progressScope = ProgressScope.Lifetime,
            completionPolicy = CompletionPolicy.WhenTargetReached,
        )

        assertEquals(3L, repository.addCount(goalId, slotId = null, count = 3))
        assertNotNull(repository.getGoalById(goalId)?.completedAt)

        assertEquals(-1L, repository.addCount(goalId, slotId = null, count = -1))
        assertNull(repository.getGoalById(goalId)?.completedAt)
    }

    @Test
    fun countSetupUpdateChangesSingleAnytimeGoalAndSlotTogether() = runTest {
        val goalId = createGoal(countPolicy = CountPolicy(targetCount = 100))
        val existing = repository.getGoalById(goalId) ?: error("Missing goal")

        repository.updateGoal(
            validatedUpdate(
                existingGoal = existing,
                command = UpdateGoalCountSetupCommand(
                    goalId = goalId,
                    ruleMode = GoalCountRuleMode.Target,
                    countPolicy = GoalCountPolicyUpdate(
                        targetCount = 200,
                        capBehavior = CountCapBehavior.WarnOverTarget,
                    ),
                ),
            )
        )

        val updated = repository.getGoalById(goalId) ?: error("Missing updated goal")
        assertEquals(200, updated.slots.single().targetCount)
        assertEquals(CountCapBehavior.WarnOverTarget, updated.capBehavior)
        assertEquals(CountCapBehavior.WarnOverTarget, updated.slots.single().capBehavior)
    }

    @Test
    fun countSetupUpdateChangesExistingSlotsAndRecalculatesAggregateMaximum() = runTest {
        val goalId = createGoal(
            countPolicy = CountPolicy(targetCount = 10),
            timing = TimingSpec.TimeWindows(
                listOf(
                    TimeWindowSpec("Morning", 9 * 60, 10 * 60, CountPolicy(targetCount = 10)),
                    TimeWindowSpec("Evening", 18 * 60, 19 * 60, CountPolicy(targetCount = 10)),
                )
            ),
        )
        val existing = repository.getGoalById(goalId) ?: error("Missing goal")
        val morning = existing.slots.first { it.label == "Morning" }
        val evening = existing.slots.first { it.label == "Evening" }

        repository.updateGoal(
            validatedUpdate(
                existingGoal = existing,
                command = UpdateGoalCountSetupCommand(
                    goalId = goalId,
                    ruleMode = GoalCountRuleMode.Bounded,
                    slotPolicies = listOf(
                        GoalSlotCountPolicyUpdate(
                            morning.id,
                            GoalCountPolicyUpdate(5, 10, 15, CountCapBehavior.BlockAtMaximum),
                        ),
                        GoalSlotCountPolicyUpdate(
                            evening.id,
                            GoalCountPolicyUpdate(10, 20, 25, CountCapBehavior.BlockAtMaximum),
                        ),
                    ),
                ),
            )
        )

        val updated = repository.getGoalById(goalId) ?: error("Missing updated goal")
        assertEquals(40, updated.maximumCount)
        assertEquals(listOf(15, 25), updated.slots.sortedBy { it.sortOrder }.map { it.maximumCount })
    }

    @Test
    fun countSetupUpdateDoesNotRewriteCountHistory() = runTest {
        val goalId = createGoal(countPolicy = CountPolicy(targetCount = 100))
        assertEquals(50L, repository.addCount(goalId, slotId = null, count = 50))
        val existing = repository.getGoalById(goalId) ?: error("Missing goal")

        repository.updateGoal(
            validatedUpdate(
                existingGoal = existing,
                command = UpdateGoalCountSetupCommand(
                    goalId = goalId,
                    ruleMode = GoalCountRuleMode.Exact,
                    countPolicy = GoalCountPolicyUpdate(maximumCount = 20),
                    currentProgressCount = 50,
                ),
            )
        )

        assertEquals(50L, repository.getTotalCount(goalId).first())
        assertEquals(0L, repository.addCount(goalId, slotId = null, count = 1))
        assertEquals(50L, repository.getTotalCount(goalId).first())
    }

    @Test
    fun lifetimeGoalCompletesWhenEditedTargetIsAlreadyReached() = runTest {
        val goalId = createGoal(
            countPolicy = CountPolicy(targetCount = 100),
            progressScope = ProgressScope.Lifetime,
            completionPolicy = CompletionPolicy.WhenTargetReached,
        )
        assertEquals(50L, repository.addCount(goalId, slotId = null, count = 50))
        val existing = repository.getGoalById(goalId) ?: error("Missing goal")

        repository.updateGoal(
            validatedUpdate(
                existingGoal = existing,
                command = UpdateGoalCountSetupCommand(
                    goalId = goalId,
                    ruleMode = GoalCountRuleMode.Target,
                    countPolicy = GoalCountPolicyUpdate(targetCount = 40),
                    autoCompleteOnTarget = true,
                    currentProgressCount = 50,
                ),
            )
        )

        assertNotNull(repository.getGoalById(goalId)?.completedAt)
    }

    @Test
    fun lifetimeGoalReopensWhenEditedTargetIsNoLongerReached() = runTest {
        val goalId = createGoal(
            countPolicy = CountPolicy(targetCount = 3),
            progressScope = ProgressScope.Lifetime,
            completionPolicy = CompletionPolicy.WhenTargetReached,
        )
        assertEquals(3L, repository.addCount(goalId, slotId = null, count = 3))
        val existing = repository.getGoalById(goalId) ?: error("Missing goal")

        repository.updateGoal(
            validatedUpdate(
                existingGoal = existing,
                command = UpdateGoalCountSetupCommand(
                    goalId = goalId,
                    ruleMode = GoalCountRuleMode.Target,
                    countPolicy = GoalCountPolicyUpdate(targetCount = 5),
                    autoCompleteOnTarget = true,
                    currentProgressCount = 3,
                ),
            )
        )

        val updated = repository.getGoalById(goalId) ?: error("Missing updated goal")
        assertNull(updated.completedAt)
        assertEquals(true, updated.isActive)
    }

    @Test
    fun recurringGoalEditDoesNotCompleteWholeGoal() = runTest {
        val goalId = createGoal(countPolicy = CountPolicy(targetCount = 100))
        assertEquals(100L, repository.addCount(goalId, slotId = null, count = 100))
        val existing = repository.getGoalById(goalId) ?: error("Missing goal")

        repository.updateGoal(
            validatedUpdate(
                existingGoal = existing,
                command = UpdateGoalCountSetupCommand(
                    goalId = goalId,
                    ruleMode = GoalCountRuleMode.Target,
                    countPolicy = GoalCountPolicyUpdate(targetCount = 50),
                    autoCompleteOnTarget = true,
                    currentProgressCount = 100,
                ),
            )
        )

        val updated = repository.getGoalById(goalId) ?: error("Missing updated goal")
        assertNull(updated.completedAt)
        assertEquals(true, updated.isActive)
    }

    @Test
    fun updateUseCaseReturnsOverCapWarningAndPreservesHistory() = runTest {
        val goalId = createGoal(countPolicy = CountPolicy(targetCount = 100))
        assertEquals(50L, repository.addCount(goalId, slotId = null, count = 50))

        val result = updateGoalCountSetupUseCase(
            UpdateGoalCountSetupCommand(
                goalId = goalId,
                ruleMode = GoalCountRuleMode.Exact,
                countPolicy = GoalCountPolicyUpdate(maximumCount = 20),
            )
        )

        assertTrue(result is UpdateGoalCountSetupResult.Updated)
        val warnings = (result as UpdateGoalCountSetupResult.Updated).updatedGoal.warnings
        assertEquals(
            listOf(GoalUpdateWarning.ProgressAlreadyAboveMaximum(currentCount = 50, maximumCount = 20)),
            warnings,
        )
        assertEquals(50L, repository.getTotalCount(goalId).first())
        assertEquals(20, repository.getGoalById(goalId)?.maximumCount)
    }

    @Test
    fun scheduleUpdateChangesRecurrenceRowsTransactionally() = runTest {
        val goalId = createGoal(countPolicy = CountPolicy(targetCount = 100))
        val slotId = repository.getGoalById(goalId)?.slots?.single()?.id ?: error("Missing slot")

        val result = updateGoalScheduleUseCase(
            UpdateGoalScheduleCommand(
                goalId = goalId,
                schedule = ScheduleSpec.Weekly(setOf(DayOfWeek.MONDAY, DayOfWeek.THURSDAY)),
                timing = ScheduleTimingUpdate.Anytime(slotId = slotId),
            )
        )

        assertTrue(result is UpdateGoalScheduleResult.Updated)
        val updated = repository.getGoalById(goalId) ?: error("Missing updated goal")
        assertEquals(RecurrenceFrequency.WEEKLY, updated.recurrence.frequency)
        assertEquals(setOf(DayOfWeek.MONDAY, DayOfWeek.THURSDAY), updated.recurrence.weekdays)
        assertEquals(slotId, updated.slots.single().id)
    }

    @Test
    fun scheduleUpdateArchivesRemovedSlotsAndPreservesSlotHistory() = runTest {
        val goalId = createGoal(
            countPolicy = CountPolicy(targetCount = 10),
            timing = TimingSpec.TimeWindows(
                listOf(
                    TimeWindowSpec("Morning", 6 * 60, 7 * 60, CountPolicy(targetCount = 10)),
                    TimeWindowSpec("Evening", 18 * 60, 19 * 60, CountPolicy(targetCount = 10)),
                )
            ),
        )
        val existing = repository.getGoalById(goalId) ?: error("Missing goal")
        val morning = existing.slots.first { it.label == "Morning" }
        val evening = existing.slots.first { it.label == "Evening" }
        assertEquals(5L, repository.addCount(goalId, morning.id, 5))
        assertEquals(7L, repository.addCount(goalId, evening.id, 7))

        val result = updateGoalScheduleUseCase(
            UpdateGoalScheduleCommand(
                goalId = goalId,
                schedule = ScheduleSpec.Daily,
                timing = ScheduleTimingUpdate.TimeWindows(
                    listOf(
                        TimeWindowSlotUpdate(
                            slotId = morning.id,
                            label = "Morning",
                            startMinute = 7 * 60,
                            endMinute = 8 * 60,
                        )
                    )
                ),
                archivedAtMillis = 2222L,
            )
        )

        assertTrue(result is UpdateGoalScheduleResult.Updated)
        val updated = repository.getGoalById(goalId) ?: error("Missing updated goal")
        assertEquals(listOf(morning.id), updated.slots.map { it.id })
        assertEquals(7 * 60, updated.slots.single().startMinute)
        assertEquals(listOf(evening.id), updated.archivedSlots.map { it.id })
        assertEquals(false, updated.archivedSlots.single().isActive)
        assertEquals(2222L, updated.archivedSlots.single().archivedAt)

        val today = LocalDate.now().toString()
        assertEquals(5L, repository.getCountForSlotAndDate(goalId, morning.id, today))
        assertEquals(7L, repository.getCountForSlotAndDate(goalId, evening.id, today))
        assertEquals(setOf(morning.id, evening.id), repository.getHistoryForGoal(goalId).first().mapNotNull { it.slotId }.toSet())
    }

    @Test
    fun scheduleUpdateDropsArchivedSlotRemindersAndKeepsFixedReminders() = runTest {
        val goalId = createGoal(
            countPolicy = CountPolicy(targetCount = 10),
            timing = TimingSpec.TimeWindows(
                listOf(
                    TimeWindowSpec("Morning", 6 * 60, 7 * 60, CountPolicy(targetCount = 10)),
                    TimeWindowSpec("Evening", 18 * 60, 19 * 60, CountPolicy(targetCount = 10)),
                )
            ),
        )
        val existing = repository.getGoalById(goalId) ?: error("Missing goal")
        val morning = existing.slots.first { it.label == "Morning" }
        val evening = existing.slots.first { it.label == "Evening" }
        repository.updateGoal(
            existing.copy(
                reminders = listOf(
                    GoalReminder(
                        goalId = goalId,
                        reminderType = ReminderType.FIXED_TIME,
                        hour = 6,
                        minute = 0,
                    ),
                    GoalReminder(
                        goalId = goalId,
                        slotId = evening.id,
                        reminderType = ReminderType.TIME_WINDOW_START,
                        offsetMinutes = 0,
                    ),
                )
            )
        )

        val result = updateGoalScheduleUseCase(
            UpdateGoalScheduleCommand(
                goalId = goalId,
                schedule = ScheduleSpec.Daily,
                timing = ScheduleTimingUpdate.TimeWindows(
                    listOf(TimeWindowSlotUpdate(slotId = morning.id, label = "Morning", startMinute = 6 * 60, endMinute = 7 * 60))
                ),
            )
        )

        assertTrue(result is UpdateGoalScheduleResult.Updated)
        val updated = repository.getGoalById(goalId) ?: error("Missing updated goal")
        assertEquals(listOf(ReminderType.FIXED_TIME), updated.reminders.map { it.reminderType })
        assertNull(updated.reminders.single().slotId)
    }

    private suspend fun createGoal(
        countPolicy: CountPolicy,
        timing: TimingSpec = TimingSpec.Anytime,
        progressScope: ProgressScope = ProgressScope.DueDate,
        completionPolicy: CompletionPolicy = CompletionPolicy.Never,
    ): Long {
        val validated = GoalFactory.requireValid(
            CreateGoalCommand(
                dhikrId = dhikrId,
                startDate = LocalDate.parse("2026-05-27"),
                schedule = ScheduleSpec.Daily,
                timing = timing,
                countPolicy = countPolicy,
                progressScope = progressScope,
                completionPolicy = completionPolicy,
            )
        )
        return repository.createGoal(validated)
    }

    private fun validatedUpdate(
        existingGoal: app.awrad.awrad_dhikrgoalstracker.data.model.Goal,
        command: UpdateGoalCountSetupCommand,
    ) = (GoalCountSetupUpdateFactory.update(existingGoal, command) as GoalUpdateResult.Valid).validatedGoalUpdate
}
