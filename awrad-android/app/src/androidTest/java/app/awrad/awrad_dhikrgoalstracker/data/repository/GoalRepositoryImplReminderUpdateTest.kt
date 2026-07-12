package app.awrad.awrad_dhikrgoalstracker.data.repository

import android.content.Context
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.room.Room
import androidx.test.platform.app.InstrumentationRegistry
import app.awrad.awrad_dhikrgoalstracker.data.database.AwradDatabase
import app.awrad.awrad_dhikrgoalstracker.data.database.entity.DhikrEntity
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.ReminderType
import app.awrad.awrad_dhikrgoalstracker.data.preferences.UserPreferences
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CapBehavior
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CompletionPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CountPolicy
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.CreateGoalCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalFactory
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.GoalReminderUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ProgressScope
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ScheduleSpec
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.ScheduleTimingUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.TimeWindowSpec
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.TimeWindowSlotUpdate
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalRemindersCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalRemindersResult
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalScheduleCommand
import app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.UpdateGoalScheduleResult
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.UpdateGoalRemindersUseCase
import app.awrad.awrad_dhikrgoalstracker.domain.usecase.UpdateGoalScheduleUseCase
import app.awrad.awrad_dhikrgoalstracker.util.DateProvider
import java.io.File
import java.time.LocalDate
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class GoalRepositoryImplReminderUpdateTest {

    private lateinit var context: Context
    private lateinit var database: AwradDatabase
    private lateinit var repository: GoalRepositoryImpl
    private lateinit var updateGoalRemindersUseCase: UpdateGoalRemindersUseCase
    private lateinit var updateGoalScheduleUseCase: UpdateGoalScheduleUseCase
    private var dhikrId: Long = 0

    @Before
    fun setUp() = runTest {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        database = Room.inMemoryDatabaseBuilder(context, AwradDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        val dataStoreFile = File(context.cacheDir, "goal-reminder-update-${System.nanoTime()}.preferences_pb")
        val userPreferences = UserPreferences(
            PreferenceDataStoreFactory.create { dataStoreFile },
        )
        val dateProvider = DateProvider(userPreferences, PrayerTimeRepository(context))
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
        updateGoalRemindersUseCase = UpdateGoalRemindersUseCase(repository)
        updateGoalScheduleUseCase = UpdateGoalScheduleUseCase(repository)
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
    fun reminderUpdateReplacesRemindersWithoutChangingCountHistory() = runTest {
        val goalId = createTimeWindowGoal()
        val goal = repository.getGoalById(goalId) ?: error("Missing goal")
        val morning = goal.slots.first { it.label == "Morning" }
        repository.addCount(goalId, slotId = morning.id, count = 7)

        val result = updateGoalRemindersUseCase(
            UpdateGoalRemindersCommand(
                goalId = goalId,
                reminders = listOf(
                    GoalReminderUpdate(
                        reminderType = ReminderType.FIXED_TIME,
                        hour = 8,
                        minute = 15,
                    ),
                    GoalReminderUpdate(
                        reminderType = ReminderType.TIME_WINDOW_START,
                        slotId = morning.id,
                    ),
                    GoalReminderUpdate(
                        reminderType = ReminderType.FIXED_TIME,
                        hour = 21,
                        minute = 0,
                        enabled = false,
                    ),
                ),
            )
        )

        assertTrue(result is UpdateGoalRemindersResult.Updated)
        val updated = repository.getGoalById(goalId) ?: error("Missing updated goal")
        assertEquals(listOf(0, 1, 2), updated.reminders.map { it.sortOrder })
        assertEquals(listOf(true, true, false), updated.reminders.map { it.enabled })
        assertEquals(0, updated.reminders.first { it.reminderType == ReminderType.TIME_WINDOW_START }.offsetMinutes)
        assertEquals(7L, repository.getTotalCount(goalId).first())
        assertEquals(morning.id, repository.getHistoryForGoal(goalId).first().single().slotId)
    }

    @Test
    fun reminderUpdateRejectsArchivedSlotTarget() = runTest {
        val goalId = createTimeWindowGoal()
        val goal = repository.getGoalById(goalId) ?: error("Missing goal")
        val morning = goal.slots.first { it.label == "Morning" }
        val evening = goal.slots.first { it.label == "Evening" }

        val scheduleResult = updateGoalScheduleUseCase(
            UpdateGoalScheduleCommand(
                goalId = goalId,
                schedule = ScheduleSpec.Daily,
                timing = ScheduleTimingUpdate.TimeWindows(
                    listOf(
                        TimeWindowSlotUpdate(
                            slotId = morning.id,
                            label = "Morning",
                            startMinute = 6 * 60,
                            endMinute = 7 * 60,
                        )
                    )
                ),
                archivedAtMillis = 1234L,
            )
        )
        assertTrue(scheduleResult is UpdateGoalScheduleResult.Updated)

        val reminderResult = updateGoalRemindersUseCase(
            UpdateGoalRemindersCommand(
                goalId = goalId,
                reminders = listOf(
                    GoalReminderUpdate(
                        reminderType = ReminderType.TIME_WINDOW_START,
                        slotId = evening.id,
                    )
                ),
            )
        )

        assertTrue(reminderResult is UpdateGoalRemindersResult.Invalid)
        assertTrue(repository.getGoalById(goalId)?.reminders.orEmpty().isEmpty())
    }

    @Test
    fun reminderUpdateRejectsDuplicateSlotTargetReminders() = runTest {
        val goalId = createTimeWindowGoal()
        val goal = repository.getGoalById(goalId) ?: error("Missing goal")
        val morning = goal.slots.first { it.label == "Morning" }

        val result = updateGoalRemindersUseCase(
            UpdateGoalRemindersCommand(
                goalId = goalId,
                reminders = listOf(
                    GoalReminderUpdate(reminderType = ReminderType.TIME_WINDOW_START, slotId = morning.id),
                    GoalReminderUpdate(reminderType = ReminderType.TIME_WINDOW_START, slotId = morning.id),
                ),
            )
        )

        assertTrue(result is UpdateGoalRemindersResult.Invalid)
        assertTrue(repository.getGoalById(goalId)?.reminders.orEmpty().isEmpty())
    }

    @Test
    fun reminderUpdateCanDeleteAllExistingReminders() = runTest {
        val goalId = createTimeWindowGoal()
        val goal = repository.getGoalById(goalId) ?: error("Missing goal")
        val morning = goal.slots.first { it.label == "Morning" }
        val addResult = updateGoalRemindersUseCase(
            UpdateGoalRemindersCommand(
                goalId = goalId,
                reminders = listOf(
                    GoalReminderUpdate(reminderType = ReminderType.FIXED_TIME, hour = 8, minute = 0),
                    GoalReminderUpdate(reminderType = ReminderType.TIME_WINDOW_START, slotId = morning.id),
                ),
            )
        )
        assertTrue(addResult is UpdateGoalRemindersResult.Updated)
        assertEquals(2, repository.getGoalById(goalId)?.reminders.orEmpty().size)

        val deleteResult = updateGoalRemindersUseCase(
            UpdateGoalRemindersCommand(goalId = goalId, reminders = emptyList())
        )

        assertTrue(deleteResult is UpdateGoalRemindersResult.Updated)
        assertTrue(repository.getGoalById(goalId)?.reminders.orEmpty().isEmpty())
    }

    private suspend fun createTimeWindowGoal(): Long {
        val validated = GoalFactory.requireValid(
            CreateGoalCommand(
                dhikrId = dhikrId,
                startDate = LocalDate.parse("2026-05-27"),
                schedule = ScheduleSpec.Daily,
                timing = app.awrad.awrad_dhikrgoalstracker.domain.model.goalcreation.TimingSpec.TimeWindows(
                    listOf(
                        TimeWindowSpec("Morning", 6 * 60, 7 * 60, CountPolicy(targetCount = 10)),
                        TimeWindowSpec("Evening", 18 * 60, 19 * 60, CountPolicy(targetCount = 10)),
                    )
                ),
                countPolicy = CountPolicy(
                    targetCount = 20,
                    capBehavior = CapBehavior.AllowOverTarget,
                ),
                progressScope = ProgressScope.DueDate,
                completionPolicy = CompletionPolicy.Never,
            )
        )
        return repository.createGoal(validated)
    }
}
